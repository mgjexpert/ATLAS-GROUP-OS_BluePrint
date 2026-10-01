#!/usr/bin/env python3
import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

def md(value):
    return str(value).replace("|", "\\|")

def refs(values):
    return ", ".join(f"`{v}`" for v in values) if values else "—"

def network_members(evidence):
    result = defaultdict(list)
    for container in evidence["docker"]["containers"]:
        for network in container.get("networks", []):
            result[network].append(container["name"])
    return {k: sorted(v) for k, v in sorted(result.items())}

def compose_report(evidence):
    groups = defaultdict(list)
    for container in evidence["docker"]["containers"]:
        project = (container.get("compose") or {}).get("project") or "UNCLASSIFIED"
        groups[project].append(container)
    out = ["# Docker Compose Map", "", "Generated deterministically from normalized evidence.", ""]
    for project in sorted(groups):
        out += [f"## {project}", "", "| Container | Service | State | Networks | Published ports |", "|---|---|---|---|---|"]
        for c in sorted(groups[project], key=lambda x: x["name"]):
            service = (c.get("compose") or {}).get("service") or "—"
            out.append(
                f"| `{md(c['name'])}` | `{md(service)}` | {md(c.get('state') or '')} | "
                f"{md(', '.join(c.get('networks', [])) or '—')} | {md(c.get('published_ports') or '—')} |"
            )
        out.append("")
    return "\n".join(out) + "\n"

def networks_report(evidence):
    members = network_members(evidence)
    out = ["# Networks and Storage", "", "## Docker networks", "", "| Network | Members |", "|---|---|"]
    for row in evidence["docker"]["networks"]:
        name = row.get("Name") or row.get("name") or "unknown"
        out.append(f"| `{md(name)}` | {md(', '.join(members.get(name, [])) or '—')} |")
    out += ["", "## Volumes", "", "| Volume | Driver |", "|---|---|"]
    for row in evidence["docker"]["volumes"]:
        name = row.get("Name") or row.get("name") or "unknown"
        driver = row.get("Driver") or row.get("driver") or "—"
        out.append(f"| `{md(name)}` | {md(driver)} |")
    out += ["", "## Mounts by container", ""]
    for c in evidence["docker"]["containers"]:
        if not c.get("mounts"):
            continue
        out.append(f"### {c['name']}")
        for mount in c["mounts"]:
            out.append(
                f"- `{mount.get('type')}` `{mount.get('source')}` → "
                f"`{mount.get('destination')}` (rw={mount.get('rw')})"
            )
        out.append("")
    return "\n".join(out) + "\n"

def repos_report(evidence):
    out = ["# Repositories and Deployments", "", "Repository metadata is sanitized; raw remote URLs and credentials are not retained.", ""]
    repos = evidence.get("repositories", [])
    if not repos:
        out += ["**UNKNOWN:** no sanitized repository mapping is present in this snapshot.", ""]
    else:
        out += ["| Path | Repository | Branch | HEAD |", "|---|---|---|---|"]
        for row in repos:
            out.append(
                f"| `{md(row.get('path'))}` | `{md(row.get('repository') or 'UNKNOWN')}` | "
                f"`{md(row.get('branch') or 'UNKNOWN')}` | `{md(row.get('head') or 'UNKNOWN')}` |"
            )
        out.append("")
    return "\n".join(out) + "\n"

def database_type(container):
    value = ((container.get("image") or "") + " " + container.get("name", "")).lower()
    if "postgres" in value or "pgvector" in value:
        return "PostgreSQL/pgvector"
    if "redis" in value:
        return "Redis"
    return None

def databases_report(evidence):
    out = [
        "# Databases", "",
        "Services are identified from container names/images. Contents, credentials, backup validity and consolidation suitability remain UNKNOWN unless separately evidenced.",
        "", "| Container | Type | Image | Networks | Mounts |", "|---|---|---|---|---:|",
    ]
    for c in evidence["docker"]["containers"]:
        kind = database_type(c)
        if kind:
            out.append(
                f"| `{c['name']}` | {kind} | `{md(c.get('image') or '')}` | "
                f"{md(', '.join(c.get('networks', [])))} | {len(c.get('mounts', []))} |"
            )
    return "\n".join(out) + "\n"

def endpoints_report(evidence):
    out = [
        "# Domains and Endpoints", "",
        "Listening sockets prove local bind state only; they do not prove public reachability or DNS routing.",
        "", "| Protocol | Local bind | Process evidence |", "|---|---|---|",
    ]
    for socket in evidence.get("sockets", []):
        out.append(
            f"| {md(socket.get('protocol'))} | `{md(socket.get('local'))}` | "
            f"`{md(socket.get('process'))}` |"
        )
    out += [
        "", "## DNS / reverse proxy routing", "",
        "**UNKNOWN:** authoritative DNS records and reverse-proxy route configuration are not included in this evidence manifest.", "",
    ]
    return "\n".join(out) + "\n"

def node_id(prefix, name):
    return re.sub(r"[^A-Za-z0-9_]", "_", f"{prefix}_{name}")

def mermaid_report(evidence):
    out = ["flowchart LR"]
    members = network_members(evidence)

    for container in sorted(evidence["docker"]["containers"], key=lambda x: x["name"]):
        container_id = node_id("ctr", container["name"])
        out.append(f'  {container_id}["{container["name"]}"]')

    for network in sorted(members):
        network_id = node_id("net", network)
        out.append(f'  {network_id}["network: {network}"]')

    for network, names in members.items():
        network_id = node_id("net", network)
        for name in names:
            container_id = node_id("ctr", name)
            out.append(f"  {container_id} --- {network_id}")

    return "\n".join(out) + "\n"

def security_report(analysis):
    out = ["# Security Observations", "", "Model analysis validated against the evidence manifest. Missing evidence remains an explicit unknown.", ""]
    for risk in analysis["risks"]:
        out += [
            f"## {risk['id']} — {risk['severity'].upper()}", "", risk["statement"], "",
            f"- Confidence: **{risk['confidence']}**",
            f"- Evidence: {refs(risk['evidence_refs'])}",
            f"- Next step: {risk['recommended_next_step']}",
            f"- Human approval: {risk['requires_human_approval']}", "",
        ]
    out += ["## Explicit unknowns", ""]
    for item in analysis["unknowns"]:
        out.append(
            f"- **{item['id']}** {item['question']} — {item['why_it_matters']} "
            f"(evidence context: {refs(item['evidence_refs'])})"
        )
    return "\n".join(out) + "\n"

def cost_report(analysis):
    out = ["# Cost and Complexity Opportunities", "", "Recommendations remain subject to Atlas approval and recovery gates.", ""]
    for item in analysis["opportunities"]:
        out += [
            f"## {item['id']} — {item['category']}", "", item["statement"], "",
            f"- Confidence: **{item['confidence']}**",
            f"- Evidence: {refs(item['evidence_refs'])}",
            f"- Reversibility: **{item['reversibility']}**",
            f"- Blast radius: **{item['blast_radius']}**",
            f"- Next step: {item['recommended_next_step']}",
            f"- Human approval: {item['requires_human_approval']}", "",
        ]
    return "\n".join(out) + "\n"

def reset_report(analysis):
    out = ["# ATLAS RESET 2026 — Validated V1 Plan", "", "Actions are descriptions, not execution instructions.", ""]
    for phase in analysis["reset_plan"]:
        out += [f"## {phase['phase']}", ""]
        for item in phase["actions"]:
            out += [
                f"### {item['id']}", item["action"], "",
                f"- Basis: {item['basis']}",
                f"- Evidence: {refs(item['evidence_refs'])}",
                f"- Reversibility: **{item['reversibility']}**",
                f"- Blast radius: **{item['blast_radius']}**",
                f"- Approval: **{item['approval']}**", "",
            ]
    return "\n".join(out) + "\n"

def executive_report(analysis, usage, evidence):
    risks = {x["id"]: x for x in analysis["risks"]}
    actions = {x["id"]: x for p in analysis["reset_plan"] for x in p["actions"]}
    facts = evidence.get("facts", {})
    state_counts = facts.get("container_state_counts", {})
    out = [
        "# Atlas.Dev-00 Evaluation V1 — Executive Summary", "",
        "## Deterministic footprint", "",
        f"- Containers: **{facts.get('container_count', 'UNKNOWN')}**",
        f"- Running containers: **{state_counts.get('running', 0)}**",
        f"- Exited/stopped containers: **{state_counts.get('exited', 0) + state_counts.get('stopped', 0)}**",
        f"- Compose projects: **{facts.get('compose_project_count', 'UNKNOWN')}**",
        f"- Docker networks: **{facts.get('network_count', 'UNKNOWN')}**",
        f"- Docker volumes: **{facts.get('volume_count', 'UNKNOWN')}**",
        "", "## Model assessment", "",
        analysis["executive_summary"]["assessment"], "", "## Top risks", "",
    ]
    for item_id in analysis["executive_summary"]["top_risks"]:
        if item_id in risks:
            out.append(f"- **{item_id}** {risks[item_id]['statement']}")
    out += ["", "## Top next actions", ""]
    for item_id in analysis["executive_summary"]["top_next_actions"]:
        if item_id in actions:
            out.append(f"- **{item_id}** {actions[item_id]['action']}")
    out += [
        "", "## Runtime", "",
        f"- Configured route: `{usage.get('configured_route', 'UNKNOWN')}`",
        f"- Logical model: `{usage.get('logical_model', 'UNKNOWN')}`",
        f"- Stop reason: `{usage.get('stop_reason', 'UNKNOWN')}`",
    ]
    if usage.get("usage"):
        out.append(f"- Usage: `{json.dumps(usage['usage'], sort_keys=True)}`")
    return "\n".join(out) + "\n"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--analysis", required=True)
    ap.add_argument("--usage", required=True)
    ap.add_argument("--output-dir", required=True)
    args = ap.parse_args()
    evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8"))
    analysis = json.loads(Path(args.analysis).read_text(encoding="utf-8"))
    usage = json.loads(Path(args.usage).read_text(encoding="utf-8"))
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    inventory = {
        "schema_version": "atlas.inventory.v1",
        "host": evidence["host"],
        "resources": evidence["resources"],
        "services": evidence["services"],
        "sockets": evidence["sockets"],
        "docker": evidence["docker"],
        "repositories": evidence.get("repositories", []),
        "source_files": evidence["source_files"],
    }
    (out / "vps-services.json").write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n")
    (out / "docker-compose-map.md").write_text(compose_report(evidence))
    (out / "networks-storage.md").write_text(networks_report(evidence))
    (out / "repos-and-deployments.md").write_text(repos_report(evidence))
    (out / "databases.md").write_text(databases_report(evidence))
    (out / "domains-endpoints.md").write_text(endpoints_report(evidence))
    (out / "dependencies.mmd").write_text(mermaid_report(evidence))
    (out / "security-observations.md").write_text(security_report(analysis))
    (out / "cost-opportunities.md").write_text(cost_report(analysis))
    (out / "ATLAS-RESET-2026.md").write_text(reset_report(analysis))
    (out / "executive-summary.md").write_text(executive_report(analysis, usage, evidence))

if __name__ == "__main__":
    main()
