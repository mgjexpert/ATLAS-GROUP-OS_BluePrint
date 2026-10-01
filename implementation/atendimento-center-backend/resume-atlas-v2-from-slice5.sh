#!/usr/bin/env bash
set -Eeuo pipefail

TARGET="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINNED_SHA="f47dc6a31db118e0047decd1ea50e6a97a30df48"

RUNTIME_EXECUTION="$ROOT/runtime-v2-slice5-execution-layer"
RUNTIME_KNOWLEDGE="$ROOT/runtime-v2-slice6-knowledge-memory"
AGENT_PACKS="$ROOT/agent-packs-v1"
ATLAS_EXECUTIVE="$ROOT/atlas-executive-v1"
GROUP_OS="$ROOT/group-os-foundation"
GROUP_OS_API="$ROOT/group-os-control-plane"
CONFIG_INTEGRATOR="$ROOT/scripts/integrate-atlas-v2-config.py"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 /path/to/partial-atlas-v2-checkout" >&2
  exit 2
fi

TARGET="$(cd "$TARGET" && pwd)"

if [[ ! -d "$TARGET/.git" ]]; then
  echo "Target is not a Git checkout: $TARGET" >&2
  exit 3
fi

CURRENT_SHA="$(git -C "$TARGET" rev-parse HEAD)"
if [[ "$CURRENT_SHA" != "$PINNED_SHA" ]]; then
  echo "Unexpected backend baseline:" >&2
  echo "  expected: $PINNED_SHA" >&2
  echo "  current:  $CURRENT_SHA" >&2
  exit 4
fi

if ! grep -q '^model RuntimeRun {' "$TARGET/prisma/schema.prisma"; then
  echo "This does not look like the partial Atlas V2 integration checkout." >&2
  echo "RuntimeRun is missing; use apply-atlas-v2-foundation.sh on a clean checkout." >&2
  exit 5
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SAFETY_PATCH="/tmp/atlas-v2-partial-${STAMP}.patch"
git -C "$TARGET" diff --binary > "$SAFETY_PATCH"

echo "=== SAFETY SNAPSHOT ==="
echo "$SAFETY_PATCH"

copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  cp -a "$src/." "$dst/"
}

append_models_once() {
  local marker="$1"
  local snippet="$2"
  local begin="$3"
  local end="$4"

  if ! grep -q "$marker" "$TARGET/prisma/schema.prisma"; then
    {
      printf '\n%s\n' "$begin"
      cat "$snippet"
      printf '%s\n' "$end"
    } >> "$TARGET/prisma/schema.prisma"
  fi
}

echo "=== SLICE 5 — EXECUTION LAYER ==="
copy_tree "$RUNTIME_EXECUTION/src/execution-v2" "$TARGET/src/execution-v2"
cp "$RUNTIME_EXECUTION/src/agent-worker.ts" "$TARGET/src/agent-worker.ts"
cp   "$RUNTIME_EXECUTION/database/migrations/20261001_atlas_runtime_v2_slice5_execution_jobs.sql"   "$TARGET/database/migrations/20261001_atlas_runtime_v2_slice5_execution_jobs.sql"

append_models_once   '^model ExecutionJob {'   "$RUNTIME_EXECUTION/prisma/runtime-v2-slice5-models.prisma"   '// BEGIN ATLAS RUNTIME V2 SLICE 5'   '// END ATLAS RUNTIME V2 SLICE 5'

echo "=== GROUP OS FOUNDATION ==="
mkdir -p "$TARGET/database/seeds"
cp   "$GROUP_OS/database/migrations/20261001_atlas_group_os_foundation_v1.sql"   "$TARGET/database/migrations/20261001_atlas_group_os_foundation_v1.sql"
cp   "$GROUP_OS/database/seeds/20261001_atlas_internal_org_v1.sql"   "$TARGET/database/seeds/20261001_atlas_internal_org_v1.sql"

append_models_once   '^model BusinessUnit {'   "$GROUP_OS/prisma/group-os-models.prisma"   '// BEGIN ATLAS GROUP OS FOUNDATION V1'   '// END ATLAS GROUP OS FOUNDATION V1'

echo "=== GROUP OS CONTROL PLANE ==="
copy_tree "$GROUP_OS_API/src/group-os" "$TARGET/src/group-os"

echo "=== SLICE 6 — KNOWLEDGE / OPERATIONAL MEMORY ==="
copy_tree "$RUNTIME_KNOWLEDGE/src/knowledge" "$TARGET/src/knowledge"
copy_tree "$RUNTIME_KNOWLEDGE/src/runtime" "$TARGET/src/runtime"
cp   "$RUNTIME_KNOWLEDGE/database/migrations/20261001_atlas_runtime_v2_slice6_knowledge.sql"   "$TARGET/database/migrations/20261001_atlas_runtime_v2_slice6_knowledge.sql"

append_models_once   '^model KnowledgeSource {'   "$RUNTIME_KNOWLEDGE/prisma/runtime-v2-slice6-models.prisma"   '// BEGIN ATLAS RUNTIME V2 SLICE 6'   '// END ATLAS RUNTIME V2 SLICE 6'

echo "=== AGENT PACKS V1 ==="
copy_tree "$AGENT_PACKS/src/agent-packs" "$TARGET/src/agent-packs"
copy_tree "$AGENT_PACKS/src/runtime" "$TARGET/src/runtime"
cp   "$AGENT_PACKS/database/migrations/20261001_atlas_agent_packs_v1.sql"   "$TARGET/database/migrations/20261001_atlas_agent_packs_v1.sql"

append_models_once   '^model AgentPack {'   "$AGENT_PACKS/prisma/agent-pack-models.prisma"   '// BEGIN ATLAS AGENT PACKS V1'   '// END ATLAS AGENT PACKS V1'

echo "=== ATLAS EXECUTIVE V1 ==="
copy_tree "$ATLAS_EXECUTIVE/src/executive" "$TARGET/src/executive"
copy_tree "$ATLAS_EXECUTIVE/src/runtime" "$TARGET/src/runtime"

echo "=== SEMANTIC CONFIG INTEGRATION ==="
/usr/bin/python3 "$CONFIG_INTEGRATOR" --target "$TARGET"

echo "=== STAGED RESULT ==="
git -C "$TARGET" status --short
echo
git -C "$TARGET" diff --stat

if [[ "${ATLAS_SKIP_BUILD:-0}" == "1" ]]; then
  echo
  echo "Build skipped by ATLAS_SKIP_BUILD=1."
  exit 0
fi

LOG_DIR="/tmp/atlas-v2-build-${STAMP}"
mkdir -p "$LOG_DIR"

BUILD_DATABASE_URL="${DATABASE_URL:-postgresql://atlas_build:atlas_build@127.0.0.1:5432/atlas_build}"

run_stage() {
  local stage="$1"
  shift

  local log="$LOG_DIR/${stage}.log"

  echo "=== ${stage^^} ==="

  set +e
  (
    cd "$TARGET"
    "$@"
  ) 2>&1 | tee "$log"

  local rc=${PIPESTATUS[0]}
  set -e

  if [[ "$rc" -ne 0 ]]; then
    echo
    echo "ATLAS V2 BUILD STAGE FAILED: $stage"
    echo "Exit code: $rc"
    echo "Log: $log"
    echo
    echo "=== LAST 160 LOG LINES ==="
    tail -n 160 "$log" || true
    echo
    echo "All build logs: $LOG_DIR"
    exit "$rc"
  fi
}

run_stage   dependencies   env     PRISMA_SKIP_POSTINSTALL_GENERATE=1     DATABASE_URL="$BUILD_DATABASE_URL"     npm install

run_stage   prisma_validate   env     DATABASE_URL="$BUILD_DATABASE_URL"     ./node_modules/.bin/prisma validate

run_stage   prisma_generate   env     DATABASE_URL="$BUILD_DATABASE_URL"     npm run prisma:generate

run_stage   typescript_build   npm run build

echo
echo "ATLAS V2 INTEGRATION BUILD: SUCCESS"
echo "Target: $TARGET"
echo "Safety patch: $SAFETY_PATCH"
echo "Build logs: $LOG_DIR"
