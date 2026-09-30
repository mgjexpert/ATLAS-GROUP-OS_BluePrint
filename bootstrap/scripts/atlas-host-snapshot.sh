#!/usr/bin/env bash
set -euo pipefail
umask 027

BASE="/var/lib/atlas/inventory"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BASE/$STAMP"
CURRENT="$BASE/current"

mkdir -p "$OUT"
chown root:atlas "$OUT"
chmod 0750 "$OUT"

json_escape() { jq -Rs .; }

{
  echo "{"
  printf '  "captured_at": %s,\n' "$(date -u +%FT%TZ | json_escape)"
  printf '  "hostname": %s,\n' "$(hostname -f 2>/dev/null || hostname | json_escape)"
  printf '  "kernel": %s,\n' "$(uname -srmo | json_escape)"
  printf '  "uptime": %s\n' "$(uptime -p 2>/dev/null || true | json_escape)"
  echo "}"
} > "$OUT/host.json"

df -hT > "$OUT/filesystems.txt"
free -h > "$OUT/memory.txt" 2>/dev/null || true
systemctl list-units --type=service --state=running --no-pager --no-legend   | awk '{print $1 "\t" $4}' > "$OUT/running-services.tsv" || true
ss -lntupH 2>/dev/null   | awk '{print $1 "\t" $5 "\t" $7}' > "$OUT/listening-sockets.tsv" || true

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker version --format '{{json .}}' | jq '{
    Client: {Version: .Client.Version},
    Server: {Version: .Server.Version, Os: .Server.Os, Arch: .Server.Arch}
  }' > "$OUT/docker-version.json"

  docker ps -a --no-trunc     --format '{{json .}}' | jq -s '[.[] | {
      ID, Names, Image, State, Status, Ports, Networks
    }]' > "$OUT/docker-containers.json"

  docker network ls --format '{{json .}}'     | jq -s '[.[] | {ID,Name,Driver,Scope}]' > "$OUT/docker-networks.json"

  docker volume ls --format '{{json .}}'     | jq -s '[.[] | {Name,Driver,Scope}]' > "$OUT/docker-volumes.json"

  docker inspect $(docker ps -aq) 2>/dev/null | jq '[.[] | {
    name: (.Name | ltrimstr("/")),
    image: .Config.Image,
    status: .State.Status,
    restart_policy: .HostConfig.RestartPolicy.Name,
    networks: (.NetworkSettings.Networks | keys),
    mounts: [.Mounts[]? | {type: .Type, source: .Source, destination: .Destination, rw: .RW}],
    compose: {
      project: .Config.Labels["com.docker.compose.project"],
      service: .Config.Labels["com.docker.compose.service"],
      working_dir: .Config.Labels["com.docker.compose.project.working_dir"],
      config_files: .Config.Labels["com.docker.compose.project.config_files"]
    },
    environment_variable_names: [
      .Config.Env[]? | split("=")[0]
    ]
  }]' > "$OUT/docker-safe-inspect.json" || true

  docker compose ls --format json > "$OUT/docker-compose-projects.json" 2>/dev/null || true
fi

# Directory names only; no file contents.
for dir in /srv /opt; do
  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 2 -mindepth 1 -type d -printf '%p\n' 2>/dev/null       | sort > "$OUT/$(basename "$dir")-directories.txt"
  fi
done

# Defensive scan: quarantine snapshot if common secret signatures or URI credentials appear.
if grep -RIEq   '(sk-(ant|proj)-[A-Za-z0-9_-]{12,}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-|postgres(ql)?://[^[:space:]]+:[^[:space:]]+@|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)'   "$OUT"; then
  mv "$OUT" "$BASE/QUARANTINED-$STAMP"
  echo "Potential secret material detected; snapshot quarantined." >&2
  exit 10
fi

rm -rf "$CURRENT"
mkdir -p "$CURRENT"
cp -a "$OUT/." "$CURRENT/"
chown -R root:atlas "$CURRENT"
chmod -R g-rwx,o-rwx "$CURRENT"
find "$CURRENT" -type d -exec chmod 0750 {} +
find "$CURRENT" -type f -exec chmod 0640 {} +

printf '%s\n' "$STAMP" > "$BASE/LATEST"
chown root:atlas "$BASE/LATEST"
chmod 0640 "$BASE/LATEST"

echo "Sanitized Atlas snapshot written: $OUT"
