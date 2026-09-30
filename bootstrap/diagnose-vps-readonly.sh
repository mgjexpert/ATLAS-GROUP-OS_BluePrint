#!/usr/bin/env bash
set -euo pipefail
umask 077

OUT="/tmp/atlas-vps-diagnostic-$(date -u +%Y%m%dT%H%M%SZ).txt"

section() {
  printf '\n\n===== %s =====\n' "$1" | tee -a "$OUT"
}

run() {
  printf '\n$ %s\n' "$*" | tee -a "$OUT"
  "$@" 2>&1 | tee -a "$OUT" || true
}

echo "ATLAS VPS READ-ONLY DIAGNOSTIC" | tee "$OUT"
echo "Generated: $(date -u +%FT%TZ)" | tee -a "$OUT"
echo "This collector intentionally avoids reading file contents, environment values, Docker secrets and application databases." | tee -a "$OUT"

section "HOST"
run hostnamectl
run uname -a
run uptime
run who
run df -hT
run free -h

section "OS / RESTART / UPDATES"
run cat /etc/os-release
if [[ -f /var/run/reboot-required ]]; then
  echo "REBOOT_REQUIRED=yes" | tee -a "$OUT"
else
  echo "REBOOT_REQUIRED=no" | tee -a "$OUT"
fi
if command -v apt >/dev/null 2>&1; then
  run bash -lc "apt list --upgradable 2>/dev/null | sed -n '1,80p'"
fi

section "CORE TOOLING"
for cmd in git node npm npx python3 pip3 uv docker docker-compose jq curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%-18s %s\n' "$cmd" "$(command -v "$cmd")" | tee -a "$OUT"
  else
    printf '%-18s MISSING\n' "$cmd" | tee -a "$OUT"
  fi
done
run git --version
run node --version
run npm --version
run npx --version
run python3 --version
run docker --version
run docker compose version

section "DOCKER SUMMARY"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  run docker info --format 'Server={{.ServerVersion}} Containers={{.Containers}} Running={{.ContainersRunning}} Paused={{.ContainersPaused}} Stopped={{.ContainersStopped}} Images={{.Images}}'
  run docker compose ls
  run docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}'
  run docker network ls
  run docker volume ls
  echo | tee -a "$OUT"
  echo "Compose labels (names only; no environment values):" | tee -a "$OUT"
  docker ps -aq | while read -r id; do
    [[ -n "$id" ]] || continue
    docker inspect "$id" --format '{{.Name}} | project={{index .Config.Labels "com.docker.compose.project"}} | service={{index .Config.Labels "com.docker.compose.service"}} | workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} | config={{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>/dev/null
  done | sed 's#^/##' | tee -a "$OUT" || true
else
  echo "Docker daemon unavailable to current user." | tee -a "$OUT"
fi

section "SYSTEMD"
run systemctl --failed --no-pager
run bash -lc "systemctl list-units --type=service --state=running --no-pager --no-legend | sed -n '1,120p'"

section "LISTENING PORTS"
if command -v ss >/dev/null 2>&1; then
  run bash -lc "ss -lntupH | sed -n '1,160p'"
fi

section "TOP RESOURCE USERS"
run bash -lc "ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | sed -n '1,25p'"

section "KNOWN PROJECT PATHS (PATHS ONLY)"
for root in /opt /srv /var/www /root; do
  if [[ -d "$root" ]]; then
    echo "-- $root" | tee -a "$OUT"
    find "$root" -maxdepth 3 -type f \( -name 'compose.yml' -o -name 'compose.yaml' -o -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'package.json' -o -name 'pyproject.toml' \) -printf '%p\n' 2>/dev/null       | sort | sed -n '1,200p' | tee -a "$OUT"
  fi
done

section "FIREWALL SUMMARY"
if command -v ufw >/dev/null 2>&1; then
  run ufw status verbose
fi
if command -v nft >/dev/null 2>&1; then
  run bash -lc "nft list ruleset 2>/dev/null | sed -n '1,220p'"
fi

section "ATLAS-SPECIFIC CHECKS"
if id atlas >/dev/null 2>&1; then
  run id atlas
else
  echo "atlas service account: NOT CREATED" | tee -a "$OUT"
fi
if [[ -d /srv/atlas ]]; then
  run find /srv/atlas -maxdepth 2 -type d -printf '%p\n'
else
  echo "/srv/atlas: NOT PRESENT" | tee -a "$OUT"
fi
if systemctl list-unit-files 2>/dev/null | grep -q '^atlas-'; then
  run bash -lc "systemctl list-unit-files 'atlas-*' --no-pager"
else
  echo "Atlas systemd units: NOT INSTALLED" | tee -a "$OUT"
fi

section "FINISH"
echo "Diagnostic written to: $OUT" | tee -a "$OUT"
echo "No changes were intentionally made to Docker, systemd services, firewall, DNS, databases, application files or secrets." | tee -a "$OUT"
