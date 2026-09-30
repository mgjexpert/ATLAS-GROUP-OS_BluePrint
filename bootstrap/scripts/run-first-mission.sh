#!/usr/bin/env bash
set -euo pipefail
umask 027

ATLAS_USER="atlas"
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
  echo "Run through systemd/root; the agent itself will execute as user atlas." >&2
  exit 1
fi

[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE" >&2; exit 2; }
[[ -d "$EVIDENCE" ]] || { echo "Missing sanitized evidence snapshot" >&2; exit 3; }
[[ -f "$PROMPT" ]] || { echo "Missing first-mission prompt" >&2; exit 4; }

# Fail closed if placeholders remain.
if grep -Eq 'CHANGE_ME' "$ENV_FILE"; then
  echo "Environment file still contains CHANGE_ME placeholders." >&2
  exit 5
fi

rm -rf "$MISSION"
install -d -o "$ATLAS_USER" -g "$ATLAS_USER" -m 0750 "$MISSION"

sudo -u "$ATLAS_USER" -H git clone --depth 1   https://github.com/mgjexpert/ATLAS-GROUP-OS_BluePrint.git   "$MISSION/blueprint"

install -d -o "$ATLAS_USER" -g "$ATLAS_USER" -m 0750 "$MISSION/evidence"
cp -a "$EVIDENCE/." "$MISSION/evidence/"
chown -R "$ATLAS_USER:$ATLAS_USER" "$MISSION/evidence"

install -d -o "$ATLAS_USER" -g "$ATLAS_USER" -m 0750 "$MISSION/output"

# The V0 agent gets no Bash, no web and no edit tool. It may read the blueprint
# and sanitized evidence and create report files under the mission workspace.
sudo -u "$ATLAS_USER" -H bash -lc "
  set -a
  source '$ENV_FILE'
  set +a
  export HOME='$ATLAS_HOME'
  cd '$MISSION'
  '$UV' run --project '$ENGINE' fcc-claude -p     "$(cat '$PROMPT')"     --output-format json     --max-turns 30     --allowedTools 'Read,Glob,Grep,Write'     --disallowedTools 'Bash,Edit,WebFetch,WebSearch'
" > "$LOG_DIR/atlas-dev-first-mission.json"

chown "$ATLAS_USER:$ATLAS_USER" "$LOG_DIR/atlas-dev-first-mission.json"
chmod 0640 "$LOG_DIR/atlas-dev-first-mission.json"

echo "Atlas.Dev-00 first mission completed. Review:"
echo "  $MISSION/output"
echo "  $LOG_DIR/atlas-dev-first-mission.json"
