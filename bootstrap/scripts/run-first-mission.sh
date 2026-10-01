#!/usr/bin/env bash
set -euo pipefail
umask 027

ATLAS_USER="atlas-agent"
ATLAS_HOME="/srv/atlas/home"
ENGINE="/srv/atlas/vendor/claude-code"
WORK="/srv/atlas/workspaces/atlas-dev-00"
MISSION="$WORK/mission"
EVIDENCE="/var/lib/atlas/inventory/current"
PROMPT="/usr/local/share/atlas/atlas-dev-first-mission.md"
ENV_FILE="/etc/atlas/atlas-agent-engine.env"
UV="$ATLAS_HOME/.local/bin/uv"
LOG_DIR="/var/log/atlas"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run through systemd/root; the model process itself executes as user atlas-agent." >&2
  exit 1
fi

[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE" >&2; exit 2; }
[[ -d "$EVIDENCE" ]] || { echo "Missing sanitized evidence snapshot" >&2; exit 3; }
[[ -f "$PROMPT" ]] || { echo "Missing first-mission prompt" >&2; exit 4; }

if grep -Eq 'CHANGE_ME' "$ENV_FILE"; then
  echo "Environment file still contains CHANGE_ME placeholders." >&2
  exit 5
fi

rm -rf "$MISSION"
install -d -o root -g atlas-agent -m 0750 "$MISSION"

# Deterministic preparation, outside model control.
git clone --depth 1   https://github.com/mgjexpert/ATLAS-GROUP-OS_BluePrint.git   "$MISSION/blueprint"

install -d -o root -g atlas-agent -m 0750 "$MISSION/evidence"
cp -a "$EVIDENCE/." "$MISSION/evidence/"

# Enforce blueprint/evidence as filesystem read-only for the atlas group.
chown -R root:atlas-agent "$MISSION/blueprint" "$MISSION/evidence"
find "$MISSION/blueprint" "$MISSION/evidence" -type d -exec chmod 0750 {} +
find "$MISSION/blueprint" "$MISSION/evidence" -type f -exec chmod 0640 {} +

# The only intended writable mission path for the agent.
install -d -o "$ATLAS_USER" -g "$ATLAS_USER" -m 0750 "$MISSION/output"

# V0 fail-closed MCP policy: no MCP servers are allowed in the first mission.
# Claude Code must support strict MCP configuration before we proceed.
CLAUDE_BIN="$ATLAS_HOME/.local/bin/claude"
if ! "$CLAUDE_BIN" --help 2>&1 | grep -q -- '--strict-mcp-config'; then
  echo "Claude Code does not expose --strict-mcp-config; refusing V0 mission." >&2
  exit 6
fi
if ! "$CLAUDE_BIN" --help 2>&1 | grep -q -- '--mcp-config'; then
  echo "Claude Code does not expose --mcp-config; refusing V0 mission." >&2
  exit 7
fi

cat > "$MISSION/mcp-empty.json" <<'JSON'
{"mcpServers":{}}
JSON
chown root:atlas-agent "$MISSION/mcp-empty.json"
chmod 0640 "$MISSION/mcp-empty.json"

# Execute the harness as the non-root atlas user.
# The V0 agent gets no Bash, web or Edit tools, and the service user has no sudo/docker membership.
runuser -u "$ATLAS_USER" -- bash -c '
  set -euo pipefail
  ENV_FILE="$1"
  ATLAS_HOME="$2"
  MISSION="$3"
  UV="$4"
  ENGINE="$5"
  PROMPT="$6"

  set -a
  source "$ENV_FILE"
  set +a

  export HOME="$ATLAS_HOME"
  export PATH="$ATLAS_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  cd "$MISSION"

  exec "$UV" run --project "$ENGINE" fcc-claude \
    --setting-sources local \
    --no-session-persistence \
    -p "$(cat "$PROMPT")" \
    --output-format json \
    --max-turns 30 \
    --mcp-config "$MISSION/mcp-empty.json" \
    --strict-mcp-config \
    --allowedTools "Read,Glob,Grep,Write" \
    --disallowedTools "Bash,Edit,WebFetch,WebSearch"
' _ "$ENV_FILE" "$ATLAS_HOME" "$MISSION" "$UV" "$ENGINE" "$PROMPT"   > "$LOG_DIR/atlas-dev-first-mission.json"

chown "$ATLAS_USER:$ATLAS_USER" "$LOG_DIR/atlas-dev-first-mission.json"
chmod 0640 "$LOG_DIR/atlas-dev-first-mission.json"

echo "Atlas.Dev-00 first mission completed. Review:"
echo "  $MISSION/output"
echo "  $LOG_DIR/atlas-dev-first-mission.json"
