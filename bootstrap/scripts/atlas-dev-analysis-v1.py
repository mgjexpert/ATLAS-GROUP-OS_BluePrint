#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path

import httpx
from free_claude_code.config.loader import get_settings
from free_claude_code.config.server_urls import local_proxy_root_url

EXPECTED_SCHEMA = "atlas.dev.analysis.v1"

def extract_json(text):
    text = text.strip()
    candidates = [text]
    candidates.extend(
        m.group(1)
        for m in re.finditer(r"```(?:json)?\s*(\{.*?\})\s*```", text, flags=re.S | re.I)
    )
    if "{" in text and "}" in text:
        candidates.append(text[text.find("{"):text.rfind("}") + 1])
    last = None
    for candidate in candidates:
        try:
            return json.loads(candidate)
        except json.JSONDecodeError as exc:
            last = exc
    raise ValueError(f"Model response did not contain valid JSON: {last}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--usage-output", required=True)
    args = ap.parse_args()

    evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8"))
    system_prompt = Path(args.prompt).read_text(encoding="utf-8")
    settings = get_settings()
    base = local_proxy_root_url(settings).rstrip("/")
    logical_model = "claude-sonnet-4-5"

    payload = {
        "model": logical_model,
        "max_tokens": 12000,
        "temperature": 0,
        "system": system_prompt,
        "messages": [{
            "role": "user",
            "content": "EVIDENCE MANIFEST JSON:\n" + json.dumps(evidence, separators=(",", ":"), sort_keys=True),
        }],
    }
    headers = {
        "x-api-key": settings.proxy_auth_token,
        "content-type": "application/json",
        "anthropic-version": "2023-06-01",
    }
    with httpx.Client(timeout=300.0) as client:
        response = client.post(f"{base}/v1/messages", headers=headers, json=payload)
    if response.status_code >= 400:
        raise SystemExit(f"FCC analysis request failed HTTP {response.status_code}: {response.text[:2000]}")

    raw = response.json()
    text_parts = [
        block["text"]
        for block in raw.get("content", [])
        if isinstance(block, dict)
        and block.get("type") == "text"
        and isinstance(block.get("text"), str)
    ]
    if not text_parts:
        raise SystemExit("FCC returned no text content for Atlas.Dev analysis")
    analysis = extract_json("\n".join(text_parts))
    if analysis.get("schema_version") != EXPECTED_SCHEMA:
        raise SystemExit(f"Unexpected analysis schema: {analysis.get('schema_version')!r}")

    Path(args.output).write_text(json.dumps(analysis, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    usage = {
        "configured_route": settings.model,
        "logical_model": logical_model,
        "response_model": raw.get("model"),
        "stop_reason": raw.get("stop_reason"),
        "usage": raw.get("usage", {}),
    }
    Path(args.usage_output).write_text(json.dumps(usage, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
