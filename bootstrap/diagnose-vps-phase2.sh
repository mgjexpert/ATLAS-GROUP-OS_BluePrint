#!/usr/bin/env bash
set -euo pipefail
umask 077

OUT="/tmp/atlas-vps-phase2-$(date -u +%Y%m%dT%H%M%SZ).txt"

section() {
  printf '\n\n===== %s =====\n' "$1" | tee -a "$OUT"
}

echo "ATLAS VPS PHASE 2 READ-ONLY DIAGNOSTIC" | tee "$OUT"
echo "Generated: $(date -u +%FT%TZ)" | tee -a "$OUT"
echo "No environment values, database contents, application file contents or secret files are intentionally read." | tee -a "$OUT"

section "DOCKER RESOURCE USAGE"
docker stats --no-stream   --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}'   2>&1 | tee -a "$OUT" || true

section "DOCKER DISK USAGE"
docker system df 2>&1 | tee -a "$OUT" || true

section "PROJECT DIRECTORY SIZES"
for dir in   /srv/platform/atendimento-center   /srv/platform/atendimento-flow   /srv/apps/autohub360   /srv/apps/mypets   /opt/atlaswallet   /opt/levelab-lia   /opt/pixbrasil
do
  if [[ -d "$dir" ]]; then
    du -sh "$dir" 2>/dev/null | tee -a "$OUT" || true
  fi
done

section "TOP HOST PROCESSES WITH CWD"
mapfile -t pids < <(ps -eo pid= --sort=-%mem | head -n 30)
printf 'PID\tUSER\tCPU%%\tMEM%%\tCOMM\tCWD\tCGROUP\n' | tee -a "$OUT"
for pid in "${pids[@]}"; do
  [[ -d "/proc/$pid" ]] || continue
  user="$(ps -o user= -p "$pid" 2>/dev/null | xargs || true)"
  cpu="$(ps -o %cpu= -p "$pid" 2>/dev/null | xargs || true)"
  mem="$(ps -o %mem= -p "$pid" 2>/dev/null | xargs || true)"
  comm="$(cat "/proc/$pid/comm" 2>/dev/null | tr '\t\n' '  ' | xargs || true)"
  cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || echo '?')"
  cgroup="$(awk -F: 'END{print $3}' "/proc/$pid/cgroup" 2>/dev/null | tr '\t\n' '  ' | xargs || true)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$user" "$cpu" "$mem" "$comm" "$cwd" "$cgroup" | tee -a "$OUT"
done

section "N8N DISCOVERY — PATHS/NAMES ONLY"
find /opt /srv /var/lib /home /root   -maxdepth 5   \( -type d -o -type f \)   \( -iname '*n8n*' -o -iname '*workflow*' \)   -printf '%p\n' 2>/dev/null   | sort | sed -n '1,250p' | tee -a "$OUT" || true

section "N8N PROCESS / SERVICE DISCOVERY"
ps -eo pid,user,comm 2>/dev/null   | grep -Ei 'n8n|workflow'   | grep -v grep   | tee -a "$OUT" || true
systemctl list-unit-files --type=service --no-pager 2>/dev/null   | grep -Ei 'n8n|workflow'   | tee -a "$OUT" || true

section "GIT WORKTREES — REMOTES REDACTED"
for root in /opt /srv; do
  find "$root" -maxdepth 5 -type d -name .git -print0 2>/dev/null |
  while IFS= read -r -d '' gitdir; do
    repo="${gitdir%/.git}"
    branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
    head="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || true)"
    remote="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
    # Strip URL credentials/userinfo if present.
    remote="$(printf '%s' "$remote" | sed -E 's#(https?://)[^/@]+@#\1[REDACTED]@#')"
    printf '%s | branch=%s | head=%s | origin=%s\n' "$repo" "$branch" "$head" "$remote"
  done
done | sort | tee -a "$OUT"

section "COMPOSE FILE OWNERSHIP"
docker compose ls --format json 2>/dev/null   | jq -r '.[] | [.Name,.Status,.ConfigFiles] | @tsv'   | tee -a "$OUT" || true

section "FINISH"
echo "Diagnostic written to: $OUT" | tee -a "$OUT"
echo "No production state was intentionally changed." | tee -a "$OUT"
