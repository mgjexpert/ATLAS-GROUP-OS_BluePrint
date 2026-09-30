#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root. This script creates the atlas service account and systemd units."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git jq rsync unzip xz-utils

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js >=18 is required for ECC. Install/review Node.js separately, then rerun."
  exit 2
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if (( NODE_MAJOR < 18 )); then
  echo "Node.js >=18 required. Current: $(node --version)"
  exit 2
fi

if ! id atlas >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "$ATLAS_HOME" --shell /bin/bash atlas
fi

install -d -o atlas -g atlas -m 0750 "$ATLAS_ROOT" "$ATLAS_HOME" "$VENDOR_DIR" "$WORKSPACE_DIR"
install -d -o root -g atlas -m 0750 "$INVENTORY_DIR" "$INVENTORY_DIR/current"
install -d -o atlas -g atlas -m 0750 "$LOG_DIR"
install -d -o root -g atlas -m 0750 "$ENV_DIR"

if [[ ! -f "$ENV_DIR/atlas-agent-engine.env" ]]; then
  install -o root -g atlas -m 0640 "$ROOT_DIR/atlas-dev.env.example" "$ENV_DIR/atlas-agent-engine.env"
  echo
  echo "Created $ENV_DIR/atlas-agent-engine.env"
  echo "Populate OPENROUTER_API_KEY and replace ANTHROPIC_AUTH_TOKEN before starting the engine."
fi

if [[ ! -x "$ATLAS_HOME/.local/bin/uv" ]]; then
  echo "Installing uv for atlas service account from the official Astral installer..."
  sudo -u atlas -H bash -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

UV="$ATLAS_HOME/.local/bin/uv"

if [[ ! -d "$ENGINE_DIR/.git" ]]; then
  sudo -u atlas -H git clone https://github.com/atlashub-digital/claude-code.git "$ENGINE_DIR"
else
  sudo -u atlas -H git -C "$ENGINE_DIR" fetch --all --prune
fi

echo "Installing pinned Python runtime and FCC dependencies from the fork lockfile..."
sudo -u atlas -H "$UV" python install 3.14.7
sudo -u atlas -H bash -lc "cd '$ENGINE_DIR' && '$UV' sync --frozen"

# Claude Code is required by the V0 ECC profile. We intentionally keep the
# remote installer behind an explicit flag so bootstrap cannot silently execute
# external installer code.
if ! sudo -u atlas -H bash -lc 'command -v claude >/dev/null 2>&1'; then
  if [[ "${ATLAS_ALLOW_REMOTE_INSTALLERS:-0}" == "1" ]]; then
    echo "Installing Claude Code from Anthropic's official installer..."
    sudo -u atlas -H bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
  else
    echo
    echo "Claude Code is not installed."
    echo "Review the official installer first, then rerun with:"
    echo "  ATLAS_ALLOW_REMOTE_INSTALLERS=1 $0"
    exit 3
  fi
fi

echo "Installing ECC 2.2.2 for the atlas user (Claude harness, core profile)..."
sudo -u atlas -H bash -lc   'npx --yes ecc-universal@2.2.2 install --guided --harness claude --claude-scope user --claude-hooks standard --profile core --yes'

echo "Installing systemd units and collector..."
install -o root -g root -m 0755 "$ROOT_DIR/scripts/atlas-host-snapshot.sh" /usr/local/sbin/atlas-host-snapshot
install -o root -g root -m 0755 "$ROOT_DIR/scripts/run-first-mission.sh" /usr/local/sbin/atlas-dev-first-mission
install -o root -g root -m 0644 "$ROOT_DIR/systemd/atlas-agent-engine.service" /etc/systemd/system/atlas-agent-engine.service
install -o root -g root -m 0644 "$ROOT_DIR/systemd/atlas-host-snapshot.service" /etc/systemd/system/atlas-host-snapshot.service
install -o root -g root -m 0644 "$ROOT_DIR/systemd/atlas-host-snapshot.timer" /etc/systemd/system/atlas-host-snapshot.timer
install -o root -g root -m 0644 "$ROOT_DIR/systemd/atlas-dev-first-mission.service" /etc/systemd/system/atlas-dev-first-mission.service
install -d -o root -g atlas -m 0750 /usr/local/share/atlas
install -o root -g atlas -m 0640 "$ROOT_DIR/prompts/atlas-dev-first-mission.md" /usr/local/share/atlas/atlas-dev-first-mission.md

systemctl daemon-reload
systemctl enable atlas-host-snapshot.timer

echo
echo "Bootstrap files installed."
echo "NEXT:"
echo "1) Edit /etc/atlas/atlas-agent-engine.env"
echo "2) Run: systemctl start atlas-host-snapshot.service"
echo "3) Run: sudo -u atlas -H npx --yes ecc-agentshield scan --format json"
echo "4) Run: systemctl enable --now atlas-agent-engine.service"
echo "5) Verify: curl -fsS http://127.0.0.1:8082/admin >/dev/null"
echo "6) Run: systemctl start atlas-dev-first-mission.service"
echo
echo "Do not grant additional production privileges until the first mission is reviewed."
