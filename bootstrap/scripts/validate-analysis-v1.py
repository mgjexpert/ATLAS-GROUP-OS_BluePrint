#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

SCHEMA = "atlas.dev.analysis.v1"
PHASES = [
    "DISCOVER", "BACKUP", "DOCUMENT", "CLASSIFY", "FREEZE",
    "CONSOLIDATE", "REDUCE COST", "BUILD CORE", "REACTIVATE BY PRIORITY",
]
CONFIDENCE = {"confirmed", "inferred", "unknown"}
SEVERITY = {"critical", "high", "medium", "low", "info"}
CATEGORIES = {"cost", "complexity", "security", "reliability", "governance"}
REVERSIBILITY = {"reversible", "requires_backup", "unknown"}
BLAST_RADIUS = {"low", "medium", "high", "unknown"}
APPROVAL = {"human", "required_after_backup", "none"}

def validate(data, evidence):
    errors = []
    sources = set(evidence.get("source_files", []))
    if data.get("schema_version") != SCHEMA:
        errors.append("schema_version mismatch")

    item_ids = []
    for section in ("risks", "opportunities", "unknowns"):
        items = data.get(section)
        if not isinstance(items, list):
            errors.append(f"{section} must be a list")
            continue
        for item in items:
            if not isinstance(item, dict):
                errors.append(f"{section} contains a non-object")
                continue

            item_id = item.get("id")
            if not item_id:
                errors.append(f"{section} item missing id")
            else:
                item_ids.append(item_id)

            evidence_refs = item.get("evidence_refs", [])
            if not isinstance(evidence_refs, list):
                errors.append(f"{item_id or section}: evidence_refs must be a list")
                evidence_refs = []
            invalid_refs = [ref for ref in evidence_refs if ref not in sources]
            if invalid_refs:
                errors.append(f"{item_id or section}: invalid evidence refs {invalid_refs}")

            if section in ("risks", "opportunities"):
                confidence = item.get("confidence")
                if confidence not in CONFIDENCE:
                    errors.append(f"{item_id}: invalid confidence")
                if confidence == "confirmed" and not evidence_refs:
                    errors.append(f"{item_id}: confirmed item lacks evidence")

            if section == "risks":
                if item.get("severity") not in SEVERITY:
                    errors.append(f"{item_id}: invalid severity")
                if not item.get("statement") or not item.get("recommended_next_step"):
                    errors.append(f"{item_id}: incomplete risk")
                if not isinstance(item.get("requires_human_approval"), bool):
                    errors.append(f"{item_id}: requires_human_approval must be boolean")

            elif section == "opportunities":
                if item.get("category") not in CATEGORIES:
                    errors.append(f"{item_id}: invalid opportunity category")
                if item.get("reversibility") not in REVERSIBILITY:
                    errors.append(f"{item_id}: invalid reversibility")
                if item.get("blast_radius") not in BLAST_RADIUS:
                    errors.append(f"{item_id}: invalid blast_radius")
                if not item.get("statement") or not item.get("recommended_next_step"):
                    errors.append(f"{item_id}: incomplete opportunity")
                if not isinstance(item.get("requires_human_approval"), bool):
                    errors.append(f"{item_id}: requires_human_approval must be boolean")

            elif section == "unknowns":
                if not item.get("question") or not item.get("why_it_matters"):
                    errors.append(f"{item_id}: incomplete unknown")

    if len(item_ids) != len(set(item_ids)):
        errors.append("duplicate analysis id")

    plan = data.get("reset_plan")
    if not isinstance(plan, list):
        errors.append("reset_plan must be a list")
        plan = []
    phases = [phase.get("phase") for phase in plan if isinstance(phase, dict)]
    if phases != PHASES:
        errors.append("reset_plan phases or order invalid")

    action_ids = []
    for phase in plan:
        if not isinstance(phase, dict):
            continue
        actions = phase.get("actions", [])
        if not isinstance(actions, list):
            errors.append(f"{phase.get('phase')}: actions must be a list")
            continue
        for action in actions:
            if not isinstance(action, dict):
                errors.append(f"{phase.get('phase')}: action must be an object")
                continue

            action_id = action.get("id")
            if not action_id:
                errors.append(f"{phase.get('phase')}: action missing id")
            else:
                action_ids.append(action_id)

            evidence_refs = action.get("evidence_refs", [])
            if not isinstance(evidence_refs, list):
                errors.append(f"{action_id}: evidence_refs must be a list")
                evidence_refs = []
            invalid_refs = [ref for ref in evidence_refs if ref not in sources]
            if invalid_refs:
                errors.append(f"{action_id}: invalid evidence refs {invalid_refs}")

            if not action.get("action") or not action.get("basis"):
                errors.append(f"{action_id}: incomplete action")
            if action.get("reversibility") not in REVERSIBILITY:
                errors.append(f"{action_id}: invalid reversibility")
            if action.get("blast_radius") not in BLAST_RADIUS:
                errors.append(f"{action_id}: invalid blast_radius")
            if action.get("approval") not in APPROVAL:
                errors.append(f"{action_id}: invalid approval")
            if action.get("blast_radius") in {"medium", "high"} and action.get("approval") == "none":
                errors.append(f"{action_id}: approval required for medium/high blast radius")
            if action.get("reversibility") == "requires_backup" and action.get("approval") == "none":
                errors.append(f"{action_id}: approval required when backup is required")

    if len(action_ids) != len(set(action_ids)):
        errors.append("duplicate action id")

    summary = data.get("executive_summary", {})
    if not isinstance(summary, dict) or not summary.get("assessment"):
        errors.append("executive_summary missing assessment")
        summary = summary if isinstance(summary, dict) else {}

    risk_ids = {x.get("id") for x in data.get("risks", []) if isinstance(x, dict)}
    if any(x not in risk_ids for x in summary.get("top_risks", [])):
        errors.append("executive_summary references unknown risk")

    known_actions = set(action_ids)
    if any(x not in known_actions for x in summary.get("top_next_actions", [])):
        errors.append("executive_summary references unknown action")

    return errors

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--analysis", required=True)
    ap.add_argument("--report", required=True)
    args = ap.parse_args()

    evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8"))
    analysis = json.loads(Path(args.analysis).read_text(encoding="utf-8"))
    errors = validate(analysis, evidence)

    report = {
        "schema_version": "atlas.validation.v1",
        "valid": not errors,
        "errors": errors,
        "analysis_schema": analysis.get("schema_version"),
        "source_files": evidence.get("source_files", []),
    }
    Path(args.report).write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    if errors:
        raise SystemExit("Atlas.Dev V1 validation failed")

if __name__ == "__main__":
    main()
