# Atlas.Dev-00 V0 → V1 Evaluation Benchmark — 2026-10-01

## Outcome

Atlas.Dev-00 V1 completed its first structured evaluation call through FCC with the configured route `open_router/openrouter/free`.

The first V1 attempt correctly failed closed because the model used three logical evidence aliases rather than exact source filenames. After deterministic alias normalization, the same model output was revalidated without a second model call and passed with:

- validation: `valid: true`
- validation errors: 0
- stop reason: `end_turn`
- required reports materialized: 10/10
- additional executive summary: present

This is a structural/pipeline pass. It is **not yet a Level 1 autonomy promotion**; qualitative human review of V1 conclusions remains required.

## Efficiency comparison

| Metric | V0 first mission | V1 evaluation | Change |
|---|---:|---:|---:|
| Model calls/turns | 31 turns | 1 request | materially reduced |
| Input tokens | 1,213,275 cumulative | 14,276 | ~98.8% reduction |
| Output tokens | 28,104 | 5,719 | ~79.7% reduction |
| Terminal state | `max_turns` | `end_turn` | clean completion |
| Model filesystem tools | Read/Glob/Grep/Write | none | removed |
| Model topology generation | free-form | none | deterministic |
| Report writes by model | yes | no | trusted materializer |
| Structural validation before reports | no | yes | fail closed |

The V0 and V1 token counters come from different execution shapes: V0 reports cumulative multi-turn context usage, while V1 is a single request. The comparison is therefore operational rather than a per-token model-quality benchmark, but it directly measures the architectural objective of removing repeated context.

## Security / architecture result

V1 evaluation runs as `atlas-agent` with:

- no root identity;
- no sudo/docker group authority;
- empty capability bounding set;
- Docker sockets inaccessible;
- external networking denied to the evaluation unit;
- loopback access retained for the local FCC gateway;
- Atlas filesystem read-only by default;
- write access limited to the V1 workspace, Atlas logs and required FCC managed state.

The model has no Claude Code filesystem tools, MCP tools or web tools for this infrastructure evaluation.

## Evidence-reference gate finding

The model returned otherwise schema-valid analysis but referenced:

- `directories.json`
- `srv-directories.json`
- `opt-directories.json`

The actual source files were:

- `srv-directories.txt`
- `opt-directories.txt`

The validator correctly rejected those references.

The fix does **not** accept arbitrary alternate filenames. The compact evidence manifest now declares deterministic aliases and a trusted normalizer expands only those aliases to exact source files before validation. Undeclared references continue to fail closed.

## Topology result

V0 contained material topology contradictions.

V1 `dependencies.mmd` is generated from observed Docker network membership. The validated output correctly showed:

- `mypets-api` attached to `mypets_edge`;
- `mypets-api` attached to `mypets_internal`;
- `levelab-lia-core` attached to `levelab-lia_lia-net`;
- `platform_edge` membership derived directly from Docker evidence rather than model synthesis;
- `atlaswallet-caddy-1` attached to both `mypets_edge` and `platform_edge`, matching the observed shared-edge role.

The materializer was subsequently tightened to declare each Mermaid container/network node once and emit membership edges separately.

## What V1 proved

V1 demonstrated that Atlas can separate:

1. deterministic collection;
2. deterministic normalization;
3. bounded model judgment;
4. structural/evidence validation;
5. deterministic report materialization.

A model formatting/evidence-reference error was caught before report publication and repaired without another inference request.

This is the intended fail-closed behavior.

## Remaining gate before Level 1

V1 still requires qualitative review for:

- unsupported causal/security interpretations;
- overstatement of sensitive environment-variable-name evidence;
- recommendations whose business/dependency assumptions exceed the snapshot;
- cost/consolidation suggestions that increase coupling or blast radius;
- correct CONFIRMED / INFERRED / UNKNOWN use;
- safety and reversibility of proposed Atlas Reset actions.

Only after those reports pass qualitative review should a Level 1 evaluation mission be designed.

## Status

- Atlas.Dev Level 0 runtime: **PASS**
- V1 structural validation: **PASS**
- V1 evidence-reference gate: **PASS after deterministic normalization**
- V1 topology generation: **PASS**
- V1 efficiency objective: **PASS**
- V1 qualitative output review: **PENDING**
- Level 1 promotion: **NOT YET APPROVED**
