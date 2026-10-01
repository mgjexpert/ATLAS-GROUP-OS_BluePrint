#!/usr/bin/env bash
set -euo pipefail
umask 027

ATLAS_USER="atlas-agent"
ATLAS_HOME="/srv/atlas/home"
ENGINE="/srv/atlas/vendor/claude-code"
WORK="/srv/atlas/workspaces/atlas-dev-eval-v1"
RUN="$WORK/run"
EVIDENCE="/var/lib/atlas/inventory/current"
ENV_FILE="/etc/atlas/atlas-agent-engine.env"
SHARE="/usr/local/share/atlas/v1"
LOG_DIR="/var/log/atlas"
PYTHON="$ENGINE/.venv/bin/python"

persist_diagnostics() {
  local src
  src="$RUN/model-work/usage.json"
  if [[ -f "$src" ]]; then
    cp "$src" "$LOG_DIR/atlas-dev-evaluation-v1-usage.json" || true
    chmod 0640 "$LOG_DIR/atlas-dev-evaluation-v1-usage.json" || true
  fi
  src="$RUN/work/validation-report.json"
  if [[ -f "$src" ]]; then
    cp "$src" "$LOG_DIR/atlas-dev-evaluation-v1-validation.json" || true
    chmod 0640 "$LOG_DIR/atlas-dev-evaluation-v1-validation.json" || true
  fi
}
trap persist_diagnostics EXIT

[[ "$(id -un)" == "$ATLAS_USER" ]] || { echo "Run as $ATLAS_USER through systemd." >&2; exit 1; }
[[ -d "$EVIDENCE" ]] || { echo "Missing sanitized evidence snapshot." >&2; exit 2; }
[[ -f "$ENV_FILE" ]] || { echo "Missing engine environment file." >&2; exit 3; }

for f in build-compact-evidence.py atlas-dev-analysis-v1.py normalize-analysis-refs-v1.py validate-analysis-v1.py materialize-reports-v1.py atlas-dev-evaluation-v1.md; do
  [[ -f "$SHARE/$f" ]] || { echo "Missing $SHARE/$f" >&2; exit 4; }
done

rm -rf "$RUN"
install -d -m 0750 "$RUN" "$RUN/evidence" "$RUN/work" "$RUN/output"
cp -a --no-preserve=ownership "$EVIDENCE/." "$RUN/evidence/"
find "$RUN/evidence" -type d -exec chmod 0750 {} +
find "$RUN/evidence" -type f -exec chmod 0640 {} +

/usr/bin/python3 "$SHARE/build-compact-evidence.py"   --evidence "$RUN/evidence"   --output "$RUN/work/compact-evidence.json"
chmod 0640 "$RUN/work/compact-evidence.json"

install -d -m 0750 "$RUN/model-work"
[[ -x "$PYTHON" ]] || { echo "Missing FCC Python runtime at $PYTHON" >&2; exit 5; }

set -a
source "$ENV_FILE"
set +a

export HOME="$ATLAS_HOME"
export PATH="$ATLAS_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PYTHONDONTWRITEBYTECODE=1

cd "$RUN/model-work"
"$PYTHON" "$SHARE/atlas-dev-analysis-v1.py"   --evidence "$RUN/work/compact-evidence.json"   --prompt "$SHARE/atlas-dev-evaluation-v1.md"   --output "$RUN/model-work/raw-analysis.json"   --usage-output "$RUN/model-work/usage.json"
cd /

/usr/bin/python3 "$SHARE/normalize-analysis-refs-v1.py"   --evidence "$RUN/work/compact-evidence.json"   --analysis "$RUN/model-work/raw-analysis.json"   --output "$RUN/model-work/analysis.json"

/usr/bin/python3 "$SHARE/validate-analysis-v1.py"   --evidence "$RUN/work/compact-evidence.json"   --analysis "$RUN/model-work/analysis.json"   --report "$RUN/work/validation-report.json"

/usr/bin/python3 "$SHARE/materialize-reports-v1.py"   --evidence "$RUN/work/compact-evidence.json"   --analysis "$RUN/model-work/analysis.json"   --usage "$RUN/model-work/usage.json"   --output-dir "$RUN/output"

find "$RUN/output" "$RUN/work" "$RUN/model-work" -type d -exec chmod 0750 {} +
find "$RUN/output" "$RUN/work" "$RUN/model-work" -type f -exec chmod 0640 {} +

echo "Atlas.Dev evaluation V1 completed and validated."
echo "Output: $RUN/output"
echo "Validation: $RUN/work/validation-report.json"
