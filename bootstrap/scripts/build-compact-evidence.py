#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

SCHEMA = "atlas.evidence.v1"

def load_json(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default

def read_text(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""

def parse_tsv(text):
    return [line.split("\t") for line in text.splitlines() if line.strip()]

def entity_ids(manifest):
    ids = {"host"}
    ids.update(f"service:{x['unit']}" for x in manifest["services"])
    ids.update(f"container:{x['name']}" for x in manifest["docker"]["containers"])
    for row in manifest["docker"]["networks"]:
        name = row.get("Name") or row.get("name")
        if name:
            ids.add(f"network:{name}")
    for row in manifest["docker"]["volumes"]:
        name = row.get("Name") or row.get("name")
        if name:
            ids.add(f"volume:{name}")
    for row in manifest["repositories"]:
        ids.add(f"repo:{row.get('repository') or row.get('path')}")
    ids.update(f"path:{x}" for x in manifest["directories"])
    return sorted(ids)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()
    root = Path(args.evidence)

    summary = load_json(root / "docker-containers.json", [])
    inspected = load_json(root / "docker-safe-inspect.json", [])
    inspected_by_name = {x.get("name"): x for x in inspected if x.get("name")}
    containers = []
    for row in summary:
        name = row.get("Names") or row.get("Name") or "unknown"
        ins = inspected_by_name.get(name, {})
        networks = ins.get("networks")
        if not networks:
            networks = [x for x in str(row.get("Networks") or "").split(",") if x]
        containers.append({
            "name": name,
            "image": ins.get("image") or row.get("Image"),
            "state": row.get("State") or ins.get("status"),
            "status": row.get("Status"),
            "published_ports": row.get("Ports") or "",
            "networks": sorted(networks),
            "mounts": ins.get("mounts") or [],
            "compose": ins.get("compose") or {},
            "restart_policy": ins.get("restart_policy"),
            "configured_user": ins.get("configured_user", ""),
            "privileged": bool(ins.get("privileged", False)),
            "cap_add": ins.get("cap_add") or [],
            "cap_drop": ins.get("cap_drop") or [],
            "security_opt": ins.get("security_opt") or [],
            "read_only_rootfs": bool(ins.get("read_only_rootfs", False)),
            "environment_variable_names": sorted(ins.get("environment_variable_names") or []),
        })
    containers.sort(key=lambda x: x["name"])

    services = []
    for parts in parse_tsv(read_text(root / "running-services.tsv")):
        services.append({"unit": parts[0], "state": parts[1] if len(parts) > 1 else "running"})
    services.sort(key=lambda x: x["unit"])

    sockets = []
    for parts in parse_tsv(read_text(root / "listening-sockets.tsv")):
        sockets.append({
            "protocol": parts[0] if parts else "",
            "local": parts[1] if len(parts) > 1 else "",
            "process": parts[2] if len(parts) > 2 else "",
        })

    directories = []
    for filename in ("srv-directories.txt", "opt-directories.txt"):
        directories.extend(x.strip() for x in read_text(root / filename).splitlines() if x.strip())
    directories = sorted(dict.fromkeys(directories))[:1000]

    repositories = load_json(root / "git-repositories.json", [])
    if not isinstance(repositories, list):
        repositories = []

    manifest = {
        "schema_version": SCHEMA,
        "host": load_json(root / "host.json", {}),
        "resources": {
            "filesystems": read_text(root / "filesystems.txt").strip(),
            "memory": read_text(root / "memory.txt").strip(),
        },
        "services": services,
        "sockets": sockets,
        "docker": {
            "version": load_json(root / "docker-version.json", {}),
            "containers": containers,
            "networks": sorted(load_json(root / "docker-networks.json", []), key=lambda x: x.get("Name") or x.get("name") or ""),
            "volumes": sorted(load_json(root / "docker-volumes.json", []), key=lambda x: x.get("Name") or x.get("name") or ""),
            "compose_projects": load_json(root / "docker-compose-projects.json", []),
        },
        "directories": directories,
        "repositories": repositories,
        "source_files": sorted(p.name for p in root.iterdir() if p.is_file()),
        "evidence_rules": {
            "confirmed_requires_source": True,
            "dns_mapping_available": False,
            "secret_values_available": False,
            "container_effective_user_available": False,
            "internet_reachability_proven_by_bind": False,
        },
    }
    manifest["entity_ids"] = entity_ids(manifest)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
