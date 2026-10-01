#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def ensure_ts_import(path: Path, import_line: str) -> None:
    text = read(path)
    if import_line in text:
        return
    lines = text.splitlines()
    import_indexes = [i for i, line in enumerate(lines) if line.startswith("import ")]
    if not import_indexes:
        raise RuntimeError(f"No TypeScript imports found in {path}")
    lines.insert(import_indexes[-1] + 1, import_line)
    write(path, "\n".join(lines) + "\n")


def ensure_array_item(path: Path, array_marker: str, item: str) -> None:
    text = read(path)
    if re.search(rf"^\s*{re.escape(item)},?\s*$", text, flags=re.M):
        return
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if array_marker in line), None)
    if start is None:
        raise RuntimeError(f"Array marker {array_marker!r} not found in {path}")

    depth = 0
    close = None
    for i in range(start, len(lines)):
        line = lines[i]
        depth += line.count("[")
        depth -= line.count("]")
        if i > start and depth == 0:
            close = i
            break

    if close is None:
        raise RuntimeError(f"Array closing bracket not found in {path}")

    indent = re.match(r"^(\s*)", lines[close]).group(1) + "  "
    lines.insert(close, f"{indent}{item},")
    write(path, "\n".join(lines) + "\n")


def update_package_json(target: Path) -> None:
    path = target / "package.json"
    data = json.loads(read(path))
    scripts = data.setdefault("scripts", {})
    scripts["start:agent-worker"] = "node dist/agent-worker.js"
    scripts["start:agent-worker:dev"] = (
        "ts-node -r tsconfig-paths/register src/agent-worker.ts"
    )

    deps = data.setdefault("dependencies", {})
    deps["bullmq"] = "^6.3.11"
    deps["ioredis"] = "^6.0.0"

    write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def update_prisma_schemas(target: Path) -> None:
    path = target / "prisma/schema.prisma"
    text = read(path)
    match = re.search(r'schemas\s*=\s*\[(.*?)\]', text, flags=re.S)
    if not match:
        raise RuntimeError("Prisma datasource schemas list not found")

    existing = re.findall(r'"([^"]+)"', match.group(1))
    for schema in ("portfolio", "governance", "finops", "knowledge"):
        if schema not in existing:
            existing.append(schema)

    replacement = "schemas  = [" + ", ".join(json.dumps(x) for x in existing) + "]"
    line_start = text.rfind("\n", 0, match.start()) + 1
    line_end = text.find("\n", match.end())
    if line_end == -1:
        line_end = len(text)
    current_line = text[line_start:line_end]
    prefix = re.match(r"^\s*", current_line).group(0)
    new_line = prefix + replacement
    write(path, text[:line_start] + new_line + text[line_end:])


def update_app_module(target: Path) -> None:
    path = target / "src/app.module.ts"
    imports = [
        "import { ExecutionModule } from './execution-v2/execution.module';",
        "import { GroupOsModule } from './group-os/group-os.module';",
        "import { KnowledgeModule } from './knowledge/knowledge.module';",
        "import { AgentPacksModule } from './agent-packs/agent-packs.module';",
        "import { ExecutiveModule } from './executive/executive.module';",
    ]
    for line in imports:
        ensure_ts_import(path, line)

    for item in (
        "ExecutionModule",
        "GroupOsModule",
        "KnowledgeModule",
        "AgentPacksModule",
        "ExecutiveModule",
    ):
        ensure_array_item(path, "imports: [", item)


def update_runtime_module(target: Path) -> None:
    path = target / "src/runtime/runtime.module.ts"
    imports = [
        "import { ExecutiveModule } from '../executive/executive.module';",
        "import { ExecutiveBriefTool } from './tools/builtin/executive-brief.tool';",
        "import { KnowledgeSearchTool } from './tools/builtin/knowledge-search.tool';",
        "import { ToolAuthorizationService } from './tools/tool-authorization.service';",
    ]
    for line in imports:
        ensure_ts_import(path, line)

    ensure_array_item(path, "imports: [", "ExecutiveModule")
    for item in (
        "ExecutiveBriefTool",
        "KnowledgeSearchTool",
        "ToolAuthorizationService",
    ):
        ensure_array_item(path, "providers: [", item)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f"Anchor not found for {label}")
    return text.replace(old, new, 1)


def update_compose(target: Path) -> None:
    path = target / "deploy/production/docker-compose.yml"
    text = read(path)

    backend_anchor = (
        "      OPENROUTER_MODEL: ${OPENROUTER_MODEL:-openai/gpt-4.1-mini}\n"
        "      XPAYMENTS_BASE_URL:"
    )
    backend_new = (
        "      OPENROUTER_MODEL: ${OPENROUTER_MODEL:-openai/gpt-4.1-mini}\n"
        "      ATLAS_REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/2\n"
        "      XPAYMENTS_BASE_URL:"
    )
    text = replace_once(
        text, backend_anchor, backend_new, "backend ATLAS_REDIS_URL"
    )

    if "  atlas_agent_worker:" not in text:
        marker = "\n  atlas_worker:\n"
        if marker not in text:
            raise RuntimeError("atlas_worker service anchor not found")
        block = """
  atlas_agent_worker:
    build:
      context: ../..
      dockerfile: Dockerfile
    restart: unless-stopped
    command: ["node", "dist/agent-worker.js"]
    environment:
      NODE_ENV: production
      DATABASE_URL: ${SUPABASE_DATABASE_URL}
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:-}
      OPENROUTER_MODEL: ${OPENROUTER_MODEL:-openai/gpt-4.1-mini}
      ATLAS_REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/2
      ATLAS_AGENT_WORKER_CONCURRENCY: ${ATLAS_AGENT_WORKER_CONCURRENCY:-1}
    networks:
      - atendimento_internal
    depends_on:
      redis:
        condition: service_healthy
"""
        text = text.replace(marker, "\n" + block + marker, 1)

    write(path, text)


def update_deploy(target: Path) -> None:
    path = target / "deploy/production/deploy.sh"
    text = read(path)
    text = replace_once(
        text,
        "docker compose build --pull backend atlas_worker atlas_signals_worker frontend",
        "docker compose build --pull backend atlas_worker atlas_signals_worker atlas_agent_worker frontend",
        "deploy build services",
    )
    if "docker compose logs -f atlas_agent_worker" not in text:
        anchor = "  docker compose logs -f atlas_worker atlas_signals_worker\n"
        if anchor not in text:
            raise RuntimeError("deploy log anchor not found")
        text = text.replace(
            anchor,
            anchor + "  docker compose logs -f atlas_agent_worker\n",
            1,
        )
    write(path, text)


def update_envs(target: Path) -> None:
    env_path = target / ".env.example"
    env_text = read(env_path)
    if "ATLAS_REDIS_URL=" not in env_text:
        anchor = "OPENROUTER_MODEL=openai/gpt-4.1-mini\n"
        if anchor not in env_text:
            raise RuntimeError(".env.example OpenRouter anchor not found")
        env_text = env_text.replace(
            anchor,
            anchor
            + "\n# Atlas Intelligence execution queue\n"
            + "# Use a dedicated Redis logical DB; production uses /2.\n"
            + "ATLAS_REDIS_URL=redis://:PASSWORD@127.0.0.1:6379/2\n",
            1,
        )
        write(env_path, env_text)

    prod_path = target / "deploy/production/.env.example"
    prod_text = read(prod_path)
    if "ATLAS_AGENT_WORKER_CONCURRENCY=" not in prod_text:
        anchor = "ATLAS_SIGNALS_WORKER_INTERVAL_MS=5000\n"
        if anchor not in prod_text:
            raise RuntimeError("production env worker anchor not found")
        prod_text = prod_text.replace(
            anchor,
            anchor + "ATLAS_AGENT_WORKER_CONCURRENCY=1\n",
            1,
        )
        write(prod_path, prod_text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    args = parser.parse_args()

    target = Path(args.target).resolve()
    required = [
        target / "package.json",
        target / "prisma/schema.prisma",
        target / "src/app.module.ts",
        target / "src/runtime/runtime.module.ts",
        target / "deploy/production/docker-compose.yml",
        target / "deploy/production/deploy.sh",
        target / ".env.example",
        target / "deploy/production/.env.example",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit("Missing integration targets: " + ", ".join(missing))

    update_package_json(target)
    update_prisma_schemas(target)
    update_app_module(target)
    update_runtime_module(target)
    update_compose(target)
    update_deploy(target)
    update_envs(target)

    print("Atlas V2 semantic configuration integration: OK")


if __name__ == "__main__":
    main()
