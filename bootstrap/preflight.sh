#!/usr/bin/env bash
set -euo pipefail

fail=0

ok() { printf '[OK] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
bad() { printf '[FAIL] %s\n' "$1"; fail=1; }

if [[ "$(uname -s)" == "Linux" ]]; then ok "Linux host"; else bad "Linux required"; fi

if command -v systemctl >/dev/null 2>&1; then ok "systemd available"; else bad "systemd not available"; fi
if command -v git >/dev/null 2>&1; then ok "git available"; else bad "git missing"; fi
if command -v curl >/dev/null 2>&1; then ok "curl available"; else bad "curl missing"; fi
if command -v jq >/dev/null 2>&1; then ok "jq available"; else warn "jq missing; installer will add it"; fi

if command -v docker >/dev/null 2>&1; then
  ok "Docker available"
  docker version --format '{{.Server.Version}}' >/dev/null 2>&1 || warn "Docker CLI exists but daemon is not readable by current user"
else
  warn "Docker not found; Docker inventory will be skipped"
fi

if command -v node >/dev/null 2>&1; then
  major="$(node -p 'process.versions.node.split(".")[0]')"
  if (( major >= 18 )); then ok "Node.js $(node --version)"; else bad "Node.js >=18 required; found $(node --version)"; fi
else
  bad "Node.js >=18 is required before ECC installation"
fi

if command -v npm >/dev/null 2>&1; then ok "npm available"; else bad "npm missing"; fi

if curl -fsS --max-time 10 https://github.com >/dev/null; then ok "Outbound HTTPS to GitHub"; else bad "Cannot reach GitHub"; fi
if curl -fsS --max-time 10 https://openrouter.ai >/dev/null; then ok "Outbound HTTPS to OpenRouter"; else warn "Cannot reach OpenRouter right now"; fi

printf '\n'
if (( fail )); then
  echo "Preflight failed. Correct the FAIL items before bootstrap."
  exit 1
fi

echo "Preflight passed."
