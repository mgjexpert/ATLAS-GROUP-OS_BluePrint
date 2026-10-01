#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root. This script creates the Atlas service account and systemd units."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATLAS_USER="atlas-agent"
ATLAS_GROUP="atlas-agent"
ATLAS_HOME="/srv/atlas/home"
ATLAS_ROOT="/srv/atlas"
VENDOR_DIR="/srv/atlas/vendor"
ENGINE_DIR="/srv/atlas/vendor/claude-code"
WORKSPACE_DIR="/srv/atlas/workspaces/atlas-dev-00"
INVENTORY_DIR="/var/lib/atlas/inventory"
LOG_DIR="/var/log/atlas"
ENV_DIR="/etc/atlas"

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo "Cannot identify Linux distribution."
  exit 1
fi

case "${ID:-}" in
  ubuntu|debian) ;;
  *)
    echo "V0 bootstrap currently supports Debian/Ubuntu-family systems only. Found: ${ID:-unknown}"
    exit 1
    ;;
esac

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y   ca-certificates curl git jq rsync unzip xz-utils

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js >=18 is required for ECC. Install/review Node.js separately, then rerun."
  exit 2
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if (( NODE_MAJOR < 18 )); then
  echo "Node.js >=18 required. Current: $(node --version)"
  exit 2
fi

if ! getent group "$ATLAS_GROUP" >/dev/null 2>&1; then
  groupadd --system "$ATLAS_GROUP"
fi

if ! id "$ATLAS_USER" >/dev/null 2>&1; then
  useradd     --system     --gid "$ATLAS_GROUP"     --create-home     --home-dir "$ATLAS_HOME"     --shell /bin/bash     "$ATLAS_USER"
fi

# Fail closed if the dedicated service user ever acquires privileged groups.
if id -nG "$ATLAS_USER" | tr ' ' '\n' | grep -Eq '^(sudo|docker|adm|root)$'; then
  echo "Refusing bootstrap: $ATLAS_USER belongs to a privileged group."
  id "$ATLAS_USER"
  exit 4
fi

install -d -o "$ATLAS_USER" -g "$ATLAS_GROUP" -m 0750   "$ATLAS_ROOT" "$ATLAS_HOME" "$VENDOR_DIR" "$WORKSPACE_DIR"
install -d -o root -g "$ATLAS_GROUP" -m 0750   "$INVENTORY_DIR" "$INVENTORY_DIR/current"
install -d -o "$ATLAS_USER" -g "$ATLAS_GROUP" -m 0750 "$LOG_DIR"
install -d -o root -g "$ATLAS_GROUP" -m 0750 "$ENV_DIR"

if [[ ! -f "$ENV_DIR/atlas-agent-engine.env" ]]; then
  install -o root -g "$ATLAS_GROUP" -m 0640     "$ROOT_DIR/atlas-dev.env.example"     "$ENV_DIR/atlas-agent-engine.env"
  echo
  echo "Created $ENV_DIR/atlas-agent-engine.env"
  echo "Populate OPENROUTER_API_KEY and replace ANTHROPIC_AUTH_TOKEN before starting the engine."
fi

if [[ ! -x "$ATLAS_HOME/.local/bin/uv" ]]; then
  echo "Installing uv for the dedicated Atlas service account from the official Astral installer..."
  runuser -u "$ATLAS_USER" -- bash -lc     'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

UV="$ATLAS_HOME/.local/bin/uv"

if [[ ! -d "$ENGINE_DIR/.git" ]]; then
  runuser -u "$ATLAS_USER" --     git clone https://github.com/atlashub-digital/claude-code.git "$ENGINE_DIR"
else
  runuser -u "$ATLAS_USER" -- git -C "$ENGINE_DIR" fetch --all --prune
fi

echo "Installing pinned Python runtime and FCC dependencies from the fork lockfile..."
runuser -u "$ATLAS_USER" -- "$UV" python install 3.14.7
runuser -u "$ATLAS_USER" -- bash -lc   "cd '$ENGINE_DIR' && '$UV' sync --frozen"

# Claude Code is required by the V0 ECC profile. External installer execution
# requires an explicit bootstrap flag so it cannot happen silently.
if ! runuser -u "$ATLAS_USER" -- bash -lc   'command -v claude >/dev/null 2>&1'; then
  if [[ "${ATLAS_ALLOW_REMOTE_INSTALLERS:-0}" == "1" ]]; then
    echo "Installing Claude Code from Anthropic's official installer..."
    runuser -u "$ATLAS_USER" -- bash -lc       'curl -fsSL https://claude.ai/install.sh | bash'
  else
    echo
    echo "Claude Code is not installed."
    echo "Review the official installer first, then rerun with:"
    echo "  ATLAS_ALLOW_REMOTE_INSTALLERS=1 $0"
    exit 3
  fi
fi

echo "Installing ECC 2.2.2 native plugin for the dedicated Atlas service user (Claude harness, standard hooks)..."
runuser -u "$ATLAS_USER" -- env PATH="$ATLAS_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" bash -lc   'npx --yes ecc-universal@2.2.2 install --guided --harness claude --claude-scope user --claude-hooks standard --yes'

echo "Installing systemd units and collector..."
install -o root -g root -m 0755   "$ROOT_DIR/scripts/atlas-host-snapshot.sh"   /usr/local/sbin/atlas-host-snapshot
install -o root -g root -m 0755   "$ROOT_DIR/scripts/run-first-mission.sh"   /usr/local/sbin/atlas-dev-first-mission
install -o root -g root -m 0644   "$ROOT_DIR/systemd/atlas-agent-engine.service"   /etc/systemd/system/atlas-agent-engine.service
install -o root -g root -m 0644   "$ROOT_DIR/systemd/atlas-host-snapshot.service"   /etc/systemd/system/atlas-host-snapshot.service
install -o root -g root -m 0644   "$ROOT_DIR/systemd/atlas-host-snapshot.timer"   /etc/systemd/system/atlas-host-snapshot.timer
install -o root -g root -m 0644   "$ROOT_DIR/systemd/atlas-dev-first-mission.service"   /etc/systemd/system/atlas-dev-first-mission.service

install -d -o root -g "$ATLAS_GROUP" -m 0750 /usr/local/share/atlas
install -o root -g "$ATLAS_GROUP" -m 0640   "$ROOT_DIR/prompts/atlas-dev-first-mission.md"   /usr/local/share/atlas/atlas-dev-first-mission.md

systemctl daemon-reload
systemctl enable atlas-host-snapshot.timer

echo
echo "Bootstrap files installed."
echo "NEXT:"
echo "1) Edit /etc/atlas/atlas-agent-engine.env"
echo "2) Run: systemctl start atlas-host-snapshot.service"
echo "3) Run: runuser -u atlas-agent -- npx --yes ecc-agentshield scan --format json"
echo "4) Run: systemctl enable --now atlas-agent-engine.service"
echo "5) Verify: curl -fsS http://127.0.0.1:8082/admin >/dev/null"
echo "6) Run: systemctl start atlas-dev-first-mission.service"
echo
echo "Do not grant additional production privileges until the first mission is reviewed."
