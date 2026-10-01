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

def parse_docker_ports(value):
    host_bindings = []
    container_ports = []
    for token in (value or "").split(","):
        token = token.strip()
        if not token:
            continue
        if "->" in token:
            host_bindings.append(token)
        else:
            container_ports.append(token)
    return {
        "host_bindings": host_bindings,
        "container_exposed_ports": container_ports,
    }

def has_no_new_privileges(options):
    return any(str(x).lower().startswith("no-new-privileges") for x in (options or []))

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
        port_semantics = parse_docker_ports(row.get("Ports") or "")
        containers.append({
            "name": name,
            "image": ins.get("image") or row.get("Image"),
            "state": row.get("State") or ins.get("status"),
            "status": row.get("Status"),
            "published_ports": row.get("Ports") or "",
            "host_bindings": port_semantics["host_bindings"],
            "container_exposed_ports": port_semantics["container_exposed_ports"],
            "networks": sorted(networks),
            "mounts": ins.get("mounts") or [],
            "compose": ins.get("compose") or {},
            "restart_policy": ins.get("restart_policy"),
            "configured_user": ins.get("configured_user", ""),
            "privileged": bool(ins.get("privileged", False)),
            "cap_add": ins.get("cap_add") or [],
            "cap_drop": ins.get("cap_drop") or [],
            "security_opt": ins.get("security_opt") or [],
            "no_new_privileges": has_no_new_privileges(ins.get("security_opt") or []),
            "drops_all_capabilities": "ALL" in (ins.get("cap_drop") or []),
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

    state_counts = {}
    for container in containers:
        state = container.get("state") or "unknown"
        state_counts[state] = state_counts.get(state, 0) + 1

    compose_projects = load_json(root / "docker-compose-projects.json", [])
    compose_project_names = sorted(
        row.get("Name") for row in compose_projects
        if isinstance(row, dict) and row.get("Name")
    )
    docker_networks = sorted(
        load_json(root / "docker-networks.json", []),
        key=lambda x: x.get("Name") or x.get("name") or "",
    )
    docker_volumes = sorted(
        load_json(root / "docker-volumes.json", []),
        key=lambda x: x.get("Name") or x.get("name") or "",
    )

    manifest = {
        "schema_version": SCHEMA,
        "host": load_json(root / "host.json", {}),
        "resources": {
            "filesystems": read_text(root / "filesystems.txt").strip(),
            "memory": read_text(root / "memory.txt").strip(),
        },
        "services": services,
        "sockets": sockets,
        "facts": {
            "container_count": len(containers),
            "container_state_counts": state_counts,
            "compose_project_count": len(compose_project_names),
            "compose_project_names": compose_project_names,
            "network_count": len(docker_networks),
            "volume_count": len(docker_volumes),
            "host_bound_containers": sorted(
                c["name"] for c in containers if c.get("host_bindings")
            ),
        },
        "docker": {
            "version": load_json(root / "docker-version.json", {}),
            "containers": containers,
            "networks": docker_networks,
            "volumes": docker_volumes,
            "compose_projects": compose_projects,
        },
        "directories": directories,
        "repositories": repositories,
        "source_files": sorted(p.name for p in root.iterdir() if p.is_file()),
        "evidence_aliases": {
            "directories.json": ["srv-directories.txt", "opt-directories.txt"],
            "srv-directories.json": ["srv-directories.txt"],
            "opt-directories.json": ["opt-directories.txt"]
        },
        "evidence_rules": {
            "confirmed_requires_source": True,
            "dns_mapping_available": False,
            "secret_values_available": False,
            "container_effective_user_available": False,
            "internet_reachability_proven_by_bind": False,
            "firewall_policy_available": False,
            "reverse_proxy_intent_available": False,
            "dependency_graph_available": False,
            "per_service_resource_usage_available": False,
            "volume_usage_classification_available": False,
        },
    }
    manifest["entity_ids"] = entity_ids(manifest)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
