#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

def canonicalize_refs(refs, aliases, source_files):
    result = []
    for ref in refs:
        mapped = aliases.get(ref, [ref])
        for item in mapped:
            if item not in result:
                result.append(item)
    return result

def walk(value, aliases, source_files):
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            if key == "evidence_refs" and isinstance(item, list):
                out[key] = canonicalize_refs(item, aliases, source_files)
            else:
                out[key] = walk(item, aliases, source_files)
        return out
    if isinstance(value, list):
        return [walk(item, aliases, source_files) for item in value]
    return value

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--analysis", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8"))
    analysis = json.loads(Path(args.analysis).read_text(encoding="utf-8"))

    aliases = evidence.get("evidence_aliases", {})
    source_files = set(evidence.get("source_files", []))

    for alias, targets in aliases.items():
        if not isinstance(alias, str) or not isinstance(targets, list) or not targets:
            raise SystemExit("Invalid evidence alias declaration")
        missing = [target for target in targets if target not in source_files]
        if missing:
            raise SystemExit(f"Evidence alias {alias!r} points to missing source files: {missing}")

    normalized = walk(analysis, aliases, source_files)
    Path(args.output).write_text(
        json.dumps(normalized, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

if __name__ == "__main__":
    main()
