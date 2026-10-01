#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
OVERLAY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  echo "Refusing to apply overlay to a dirty checkout." >&2
  exit 4
fi

CURRENT_SHA="$(git -C "$TARGET" rev-parse HEAD)"
if [[ "$CURRENT_SHA" != "$PINNED_SHA" ]]; then
  echo "Pinned upstream: $PINNED_SHA" >&2
  echo "Current target:  $CURRENT_SHA" >&2
  echo "Rebase/review the overlay before applying to a different upstream." >&2
  exit 5
fi

mkdir -p "$TARGET/src/runtime"
cp -a "$OVERLAY_ROOT/src/runtime/." "$TARGET/src/runtime/"

MIGRATION_NAME="20261001_atlas_runtime_v2_slice1.sql"
if [[ -e "$TARGET/database/migrations/$MIGRATION_NAME" ]]; then
  echo "Migration already exists: $MIGRATION_NAME" >&2
  exit 6
fi
cp "$OVERLAY_ROOT/database/migrations/$MIGRATION_NAME"   "$TARGET/database/migrations/$MIGRATION_NAME"

if ! grep -q '^model RuntimeRun {' "$TARGET/prisma/schema.prisma"; then
  {
    printf '\n// BEGIN ATLAS RUNTIME V2 SLICE 1\n'
    cat "$OVERLAY_ROOT/prisma/runtime-v2-models.prisma"
    printf '// END ATLAS RUNTIME V2 SLICE 1\n'
  } >> "$TARGET/prisma/schema.prisma"
fi

if ! grep -q "RuntimeModule" "$TARGET/src/app.module.ts"; then
  git -C "$TARGET" apply --check "$OVERLAY_ROOT/patches/app.module.patch"
  git -C "$TARGET" apply "$OVERLAY_ROOT/patches/app.module.patch"
fi

echo "Overlay applied. Changed files:"
git -C "$TARGET" status --short

if [[ -d "$TARGET/node_modules" ]]; then
  (
    cd "$TARGET"
    npm run prisma:generate
    npm run build
  )
else
  echo
  echo "node_modules not present; skipped prisma:generate/build."
  echo "Run dependency installation in the normal development environment, then:"
  echo "  npm run prisma:generate"
  echo "  npm run build"
fi
