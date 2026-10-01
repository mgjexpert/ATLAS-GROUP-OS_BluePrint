#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUNTIME="$ROOT/runtime-v2-slice1"
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

echo "Applying Atlas Group OS foundation schema..."
mkdir -p "$TARGET/database/seeds"

cp   "$GROUP_OS/database/migrations/20261001_atlas_group_os_foundation_v1.sql"   "$TARGET/database/migrations/20261001_atlas_group_os_foundation_v1.sql"

cp   "$GROUP_OS/database/seeds/20261001_atlas_internal_org_v1.sql"   "$TARGET/database/seeds/20261001_atlas_internal_org_v1.sql"

if ! grep -q '"portfolio"' "$TARGET/prisma/schema.prisma"; then
  git -C "$TARGET" apply --check     "$GROUP_OS/patches/prisma-datasource.patch"
  git -C "$TARGET" apply     "$GROUP_OS/patches/prisma-datasource.patch"
fi

if ! grep -q '^model BusinessUnit {' "$TARGET/prisma/schema.prisma"; then
  {
    printf '\n// BEGIN ATLAS GROUP OS FOUNDATION V1\n'
    cat "$GROUP_OS/prisma/group-os-models.prisma"
    printf '// END ATLAS GROUP OS FOUNDATION V1\n'
  } >> "$TARGET/prisma/schema.prisma"
fi

echo "Applying Atlas Group OS control-plane API..."
mkdir -p "$TARGET/src/group-os"
cp -a "$GROUP_OS_API/src/group-os/." "$TARGET/src/group-os/"

if ! grep -q "GroupOsModule" "$TARGET/src/app.module.ts"; then
  git -C "$TARGET" apply --check     "$GROUP_OS_API/patches/app.module-after-runtime.patch"
  git -C "$TARGET" apply     "$GROUP_OS_API/patches/app.module-after-runtime.patch"
fi

echo
echo "Atlas V2 foundation staged in target checkout."
echo
git -C "$TARGET" status --short

if [[ -d "$TARGET/node_modules" ]]; then
  echo
  echo "Running Prisma generation and TypeScript build..."
  (
    cd "$TARGET"
    npm run prisma:generate
    npm run build
  )
else
  echo
  echo "node_modules is absent, so build verification was not run."
  echo "In the normal development environment run:"
  echo "  npm run prisma:generate"
  echo "  npm run build"
fi

cat <<'EOF'

Database migrations were copied but NOT applied.
The Atlas internal organization seed was copied but NOT applied.
No production service was restarted or deployed.
EOF
