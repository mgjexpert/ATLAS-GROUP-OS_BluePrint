#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUNTIME="$ROOT/runtime-v2-slice1"
RUNTIME_TOOLS="$ROOT/runtime-v2-slice2-tools-policy"
RUNTIME_APPROVAL="$ROOT/runtime-v2-slice3-approval-engine"
RUNTIME_MODEL_TOOLS="$ROOT/runtime-v2-slice4-model-tools"
RUNTIME_EXECUTION="$ROOT/runtime-v2-slice5-execution-layer"
RUNTIME_KNOWLEDGE="$ROOT/runtime-v2-slice6-knowledge-memory"
AGENT_PACKS="$ROOT/agent-packs-v1"
ATLAS_EXECUTIVE="$ROOT/atlas-executive-v1"
GROUP_OS="$ROOT/group-os-foundation"
GROUP_OS_API="$ROOT/group-os-control-plane"

PINNED_SHA="f47dc6a31db118e0047decd1ea50e6a97a30df48"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 /path/to/atendimento.center-backend" >&2
  exit 2
fi

TARGET="$(cd "$TARGET" && pwd)"

if [[ ! -d "$TARGET/.git" ]]; then
  echo "Target is not a Git checkout: $TARGET" >&2
  exit 3
fi

if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
  echo "Refusing to modify a dirty checkout." >&2
  exit 4
fi

CURRENT_SHA="$(git -C "$TARGET" rev-parse HEAD)"
if [[ "$CURRENT_SHA" != "$PINNED_SHA" ]]; then
  echo "Atlas V2 foundation overlay is pinned to:" >&2
  echo "  $PINNED_SHA" >&2
  echo "Current checkout is:" >&2
  echo "  $CURRENT_SHA" >&2
  echo "Review/rebase the overlay before applying." >&2
  exit 5
fi

REQUIRED_FILES=(
  "$RUNTIME/src/runtime/runtime.module.ts"
  "$RUNTIME/database/migrations/20261001_atlas_runtime_v2_slice1.sql"
  "$RUNTIME_TOOLS/database/migrations/20261001_atlas_runtime_v2_slice2_tools_policy.sql"
  "$RUNTIME_TOOLS/prisma/runtime-v2-slice2-models.prisma"
  "$RUNTIME_TOOLS/patches/runtime.module.patch"
  "$RUNTIME_APPROVAL/src/runtime/approval/approval-engine.service.ts"
  "$RUNTIME_APPROVAL/patches/runtime.module.patch"
  "$RUNTIME_MODEL_TOOLS/src/runtime/runtime-run.service.ts"
  "$RUNTIME_MODEL_TOOLS/src/runtime/model/model.types.ts"
  "$RUNTIME_MODEL_TOOLS/src/runtime/model/providers/openrouter.provider.ts"
  "$RUNTIME_MODEL_TOOLS/src/runtime/tools/tool-registry.service.ts"
  "$RUNTIME_MODEL_TOOLS/src/runtime/approval/approval-engine.service.ts"
  "$RUNTIME_MODEL_TOOLS/database/migrations/20261001_atlas_runtime_v2_slice4_model_tools.sql"
  "$RUNTIME_EXECUTION/database/migrations/20261001_atlas_runtime_v2_slice5_execution_jobs.sql"
  "$RUNTIME_EXECUTION/prisma/runtime-v2-slice5-models.prisma"
  "$RUNTIME_EXECUTION/patches/app.module.patch"
  "$RUNTIME_EXECUTION/patches/package.json.patch"
  "$RUNTIME_EXECUTION/patches/docker-compose.patch"
  "$RUNTIME_EXECUTION/patches/deploy.sh.patch"
  "$RUNTIME_EXECUTION/patches/env.example.patch"
  "$RUNTIME_EXECUTION/patches/production-env.example.patch"
  "$RUNTIME_KNOWLEDGE/database/migrations/20261001_atlas_runtime_v2_slice6_knowledge.sql"
  "$RUNTIME_KNOWLEDGE/prisma/runtime-v2-slice6-models.prisma"
  "$RUNTIME_KNOWLEDGE/patches/prisma-datasource.patch"
  "$RUNTIME_KNOWLEDGE/patches/runtime.module.patch"
  "$RUNTIME_KNOWLEDGE/patches/app.module.patch"
  "$AGENT_PACKS/database/migrations/20261001_atlas_agent_packs_v1.sql"
  "$AGENT_PACKS/prisma/agent-pack-models.prisma"
  "$AGENT_PACKS/patches/runtime.module.patch"
  "$AGENT_PACKS/patches/app.module.patch"
  "$ATLAS_EXECUTIVE/src/executive/executive.module.ts"
  "$ATLAS_EXECUTIVE/patches/runtime.module.patch"
  "$ATLAS_EXECUTIVE/patches/app.module.patch"
  "$GROUP_OS/database/migrations/20261001_atlas_group_os_foundation_v1.sql"
  "$GROUP_OS/database/seeds/20261001_atlas_internal_org_v1.sql"
  "$GROUP_OS/prisma/group-os-models.prisma"
  "$GROUP_OS_API/src/group-os/group-os.module.ts"
  "$GROUP_OS_API/patches/app.module-after-runtime.patch"
)

for required in "${REQUIRED_FILES[@]}"; do
  [[ -f "$required" ]] || {
    echo "Missing overlay source: $required" >&2
    exit 6
  }
done

echo "Applying Atlas Intelligence Runtime V2 Slice 1..."
mkdir -p "$TARGET/src/runtime"
cp -a "$RUNTIME/src/runtime/." "$TARGET/src/runtime/"
cp   "$RUNTIME/database/migrations/20261001_atlas_runtime_v2_slice1.sql"   "$TARGET/database/migrations/20261001_atlas_runtime_v2_slice1.sql"

if ! grep -q '^model RuntimeRun {' "$TARGET/prisma/schema.prisma"; then
  {
    printf '\n// BEGIN ATLAS RUNTIME V2 SLICE 1\n'
    cat "$RUNTIME/prisma/runtime-v2-models.prisma"
    printf '// END ATLAS RUNTIME V2 SLICE 1\n'
  } >> "$TARGET/prisma/schema.prisma"
fi

if ! grep -q "RuntimeModule" "$TARGET/src/app.module.ts"; then
  git -C "$TARGET" apply --check     "$RUNTIME/patches/app.module.patch"
  git -C "$TARGET" apply     "$RUNTIME/patches/app.module.patch"
fi

echo "Applying Runtime V2 Slice 2 tools/policy..."
cp -a "$RUNTIME_TOOLS/src/runtime/." "$TARGET/src/runtime/"
cp   "$RUNTIME_TOOLS/database/migrations/20261001_atlas_runtime_v2_slice2_tools_policy.sql"   "$TARGET/database/migrations/20261001_atlas_runtime_v2_slice2_tools_policy.sql"

if ! grep -q '^model ToolDefinitionRecord {' "$TARGET/prisma/schema.prisma"; then
  {
    printf '\n// BEGIN ATLAS RUNTIME V2 SLICE 2\n'
    cat "$RUNTIME_TOOLS/prisma/runtime-v2-slice2-models.prisma"
    printf '// END ATLAS RUNTIME V2 SLICE 2\n'
  } >> "$TARGET/prisma/schema.prisma"
fi

git -C "$TARGET" apply --check   "$RUNTIME_TOOLS/patches/runtime.module.patch"
git -C "$TARGET" apply   "$RUNTIME_TOOLS/patches/runtime.module.patch"

echo "Applying Runtime V2 Slice 3 ApprovalEngine..."
cp -a "$RUNTIME_APPROVAL/src/runtime/." "$TARGET/src/runtime/"

git -C "$TARGET" apply --check   "$RUNTIME_APPROVAL/patches/runtime.module.patch"
git -C "$TARGET" apply   "$RUNTIME_APPROVAL/patches/runtime.module.patch"

echo "Applying Runtime V2 Slice 4 model tool-calling..."
cp -a "$RUNTIME_MODEL_TOOLS/src/runtime/." "$TARGET/src/runtime/"
cp   "$RUNTIME_MODEL_TOOLS/database/migrations/20261001_atlas_runtime_v2_slice4_model_tools.sql"   "$TARGET/database/migrations/20261001_atlas_runtime_v2_slice4_model_tools.sql"

echo "Applying Atlas V2 remaining foundation via semantic integrator..."
ATLAS_SKIP_BUILD=1 \
  "$ROOT/resume-atlas-v2-from-slice5.sh" "$TARGET"

echo
echo "Atlas V2 foundation staged in target checkout."
echo
git -C "$TARGET" status --short

if [[ -d "$TARGET/node_modules" ]] && (
  cd "$TARGET" &&
  node -e "require.resolve('bullmq'); require.resolve('ioredis')"
) >/dev/null 2>&1; then
  echo
  echo "Running Prisma generation and TypeScript build..."
  (
    cd "$TARGET"
    npm run prisma:generate
    npm run build
  )
else
  echo
  echo "Dependencies for the updated package are not installed."
  echo "In the normal development environment run:"
  echo "  npm install"
  echo "  npm run prisma:generate"
  echo "  npm run build"
fi

cat <<'EOF'

Database migrations were copied but NOT applied.
The Atlas internal organization seed was copied but NOT applied.
No production service was restarted or deployed.
EOF
