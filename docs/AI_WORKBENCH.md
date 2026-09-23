# LOAM AI Workbench

Status: **repository entrance for AI-assisted analysis and development**

This document is the index for the instruments LOAM has accumulated to help an
AI system, a human reviewer, or both understand the repository without reasoning
over the entire codebase unaided.

It is a **menu, not a pipeline**.

Use the smallest instrument set that produces a distinct answer. Do not run
DRAKON, D2, Alloy, TLA+, Lean, and every audit merely because they exist.

The tools below produce evidence. They do not become semantic authority merely
because they are formal, visual, deterministic, or AI-generated.

## First orientation

For a non-trivial semantic or architectural task, begin with these questions:

```text
What meaning must remain stable?
    -> Semantic Blueprint

Is the question broad or cross-cutting?
    -> Obligation Scaffold (D / P / R)

Is the difficulty procedural?
    -> DRAKON

Is the difficulty structural?
    -> D2 / dependency DAG / repository audits

Is current evidence too small?
    -> Falsification Atlas / Alloy / bounded probes

Is temporal behavior the issue?
    -> TLA+ / Apalache / SPIN

Is there a general law worth retaining?
    -> Lean

Is this already known?
    -> Evidence Atlas / Observation Map / research checkpoints
```

Before modifying production semantics, also read `DESIGN_PHILOSOPHY.md`,
`AGENTS.md`, and `docs/HOUSEHOLD_OPERATING_MODE.md`.

## Core coordination surfaces

| Question | Instrument | Entrance | Output / role |
| --- | --- | --- | --- |
| What meaning should remain stable across many sessions and PRs? | Semantic Blueprint | `docs/SEMANTIC_BLUEPRINT.md` | Small long-horizon semantic map and drift review card |
| What still has to be shown for this concrete change? | Obligation Scaffold | `docs/OBLIGATION_SCAFFOLD_METHOD.md` | DAG split into deterministic (D), previously earned (P), and residual (R) obligations |
| What evidence supported earlier production decisions? | Evidence Atlas | `docs/EVIDENCE_ATLAS.md` | Public index from production question to evidence and KEEP / SIMPLIFY / REPAIR result |
| What has LOAM learned over time? | Observation Map | `OBSERVATION_MAP.md` | Compressed map into observation history |
| Where are current research checkpoints and catalogs? | Research index | `docs/research/README.md` | Navigation into household, external-pressure, falsification, interaction, audit, and checkpoint material |

### Semantic Blueprint

**Use when:** a change could alter authority, retained meaning, unknown handling,
projection boundaries, lifecycle semantics, or other long-horizon commitments.

**Do not use as:** a second specification, persistence authority, or replacement
for the detailed owner of a law.

**Expected action:** use the review card after local qualification to detect
semantic drift.

### Obligation Scaffold

**Use when:** a feature, audit, correction, or proof request crosses several
semantic boundaries or would otherwise invite a broad AI prompt.

**Method:**

```text
question
   |
   v
obligation DAG
   |
   +--> D  deterministic repository evidence
   +--> P  previously qualified boundary
   `--> R  genuinely residual question
             |
             +--> proof
             +--> policy
             +--> empirical
             `--> unknown
```

Remove D and P work before asking AI or a formal tool to solve the residual.

## Visual and structural instruments

### DRAKON

**Use when:** the question is about execution order, decisions, refusal paths,
retry/recovery, publication order, or similar control-flow structure.

**Do not use when:** topology or ownership is the main question and procedure is
incidental. Prefer D2 for that.

Entrances:

- `docs/drakon/README.md`
- `docs/drakon/READ_PATH_ATLAS.md`
- `docs/drakon/ARCHITECTURE_LAWS.md`

Build and inspect:

```sh
python3 docs/drakon/build_map.py
python3 docs/drakon/inspect_map.py --diagram "09 Write Path Comparison"
python3 docs/drakon/inspect_map.py --all --json
```

The text inspector is intentionally an AI/human bridge: it exposes semantic icon
text, branches, source metadata, and optional geometry without requiring a
screenshot.

Generated `.drn` files are projections. They are not production authority or a
code-generation source.

### D2

**Use when:** the question is about structural topology, dependency, ownership,
authority, shared roots, divergent consumers, or proof-obligation shape.

Entrance:

- `docs/d2/README.md`

Render:

```sh
sh docs/d2/render.sh
```

D2 and DRAKON have deliberately different jobs:

```text
DRAKON
  execution order
  decisions / refusal
  retry / recovery

D2
  topology
  ownership / authority
  shared roots / divergent consumers
  obligation / dependency shape
```

Do not generate both mechanically. A second view must answer a distinct question.

### Module dependency DAG and granularity audit

**Use when:** a question concerns module boundaries, fragmentation, ownership,
one-consumer chains, fan-in/fan-out, or whether a physical file boundary has a
separate reason to exist.

Entrance:

- `docs/research/MODULE_GRANULARITY_AUDIT.md`
- `docs/research/MODULE_GRANULARITY_AUDIT_LEDGER.md`

Inventory:

```sh
python3 tools/module_granularity_audit.py
python3 tools/module_granularity_audit.py \
  --tsv /tmp/loam-module-granularity.tsv \
  --dot /tmp/loam-module-imports.dot \
  --markdown /tmp/loam-module-granularity.md
```

The generated DAG and metrics select candidates. They do not decide merges or
deletions.

## Repository-local audit instruments

Run these from the repository root when their question is active.

### Production reachability

```sh
./tools/audit-production-reachability
```

**Answers:** which practical Lean modules are reachable from current executable
and practical-library roots, and which candidates are unreachable.

Use it before treating a file as live production merely because it exists.

### Production surface

```sh
./tools/audit-production-surface
```

**Answers:** descriptive source-shape counts by Core, Application, Persistence,
writer/top-level, CLI, TUI, tests, and observations.

Physical size is not semantic complexity.

### Semantic candidates

```sh
./tools/audit-semantic-candidates
```

**Answers:** shallow executable-reachable vocabulary and module inventory for
human/AI classification.

It exposes candidate semantic surface. It does not infer ontology from names.

### Mechanics patterns

```sh
./tools/audit-mechanics-patterns
```

**Answers:** textual pressure indicators for repeated mechanics such as writer
ownership, staging/rename, fresh identity, replacement frontiers, routing
history, and collection laws.

Hits are investigation candidates, not duplication verdicts.

### Repository hygiene

```sh
./tools/audit-repository-hygiene
```

**Answers:** whether local/generated roots and common interpreter/OS artifacts
remain outside tracked repository state.

### Performance probes

Use focused benchmark scripts such as `tools/benchmark-actual-read.py` only
when the residual question is empirical performance. Measure rather than proving
a surrogate property.

## Falsification and pressure catalogs

### Domain Falsification Atlas

Entrance:

- `docs/research/falsification/LOAM_FALSIFICATION_ATLAS.md`
- `docs/research/falsification/LOAM_FALSIFICATION_PROGRESS.md`

**Use when:** the question is whether current retained evidence is too small.

The criterion is:

```text
current LOAM canonical evidence is identical
but
a legitimate household/accounting query must return different answers
```

A counterexample does not automatically earn a production type. First identify
the missing independently observable information and then wait for the smallest
qualified boundary and, where production is concerned, real operational pressure.

### Structural falsification

Entrance:

- `docs/research/falsification/structural/`

Use when the target is a structural law or representation claim rather than a
household-domain distinction.

## Formal and executable instruments

The `Method` section of `README.md` and the formal-tool section of
`AGENTS.md` own selection policy.

### Alloy

**Use for:** bounded structural possibility, distinguishability, sufficiency,
and counterexamples.

**Good question:** can two small worlds agree on one representation but require
different answers?

**Boundary:** bounded success is not a universal proof.

### J

**Use for:** finite arrays, projection/loss, quotient geometry, exhaustive shape,
and representation experiments.

Use it when the geometry of a finite observation is itself useful evidence.

### Lean 4

**Use for:** general laws worth retaining and current Practical Core/Application
semantics.

Do not create a theorem merely because a D obligation can be expressed in Lean.

Live proof obligations belong under `Loam/Observations/` only when they still
justify an active boundary. Historical proof apparatus may graduate to prose and
Git history.

### TLA+ / TLC

**Use for:** temporal behavior, reachable histories, state transitions, and
operation order.

### Apalache

**Use for:** symbolic checking of selected TLA+ transition systems or an
inductive-invariant question when that adds a distinct result.

### SPIN / Promela

**Use for:** concrete process interleavings and protocol-order races when
scheduling is the pressure point.

### miniKanren

**Use for:** genuinely relational or backwards search when the active toolset
cannot express the question clearly enough.

Its previous presence does not justify permanent use. The question must earn it
again.

### Dafny and other one-off probes

Historical application experiments may introduce a tool for one bounded
question without making it a production dependency. Inspect the corresponding
experiment record before reusing one.

## Proof-review and checker-boundary instruments

### Comparator

Experimental material lives under `verification/` and related observation
records.

**Use for:** statement comparison, selected axiom-policy checking, and replay
questions in an independently packaged proof task.

**Important limit:** Comparator does not establish that the reviewed theorem
statement corresponds to LOAM production implementation or to human intent.
Observation 238 records this boundary explicitly.

### Nanoda

Used experimentally as independent kernel diversity for a selected proof
environment.

**Limit:** a second checker strengthens checker diversity for that artifact; it
does not close model-to-production correspondence.

Do not make Comparator or Nanoda mandatory infrastructure without new concrete
pressure.

## Historical evidence and project memory

Use the narrowest owner that can answer the historical question:

| Need | Look here |
| --- | --- |
| Current compressed research terrain | `OBSERVATION_MAP.md` |
| Individual historical/executable probes | `experiments/`, `observations/`, `Loam/Observations/`, `tla/`, `verification/` |
| Current research catalogs/checkpoints | `docs/research/` |
| Production-question examples | `docs/EVIDENCE_ATLAS.md` |
| Long-horizon semantic commitments | `docs/SEMANTIC_BLUEPRINT.md` |
| Current household operating authority | `docs/HOUSEHOLD_OPERATING_MODE.md` |

Do not repeat an old investigation before checking whether its finding already
has a current owner or an explicit closure/reopening rule.

## Suggested decision tree for AI agents

```text
1. Is this only a small local/presentation change?
      yes -> inspect the direct owner and nearby semantic neighbors
      no  -> continue

2. Could repository meaning drift?
      -> read Semantic Blueprint

3. Is the question broad or cross-boundary?
      -> build/read an Obligation Scaffold

4. What kind of uncertainty remains?
      control flow / refusal / retry
          -> DRAKON

      topology / ownership / dependency
          -> D2 or module dependency DAG

      "is this code actually live?"
          -> production reachability audit

      duplication / unnecessary mechanism
          -> mechanics patterns + source inspection

      vocabulary / retained semantic surface
          -> semantic candidates + Evidence/Observation maps

      current model may be too small
          -> Falsification Atlas + smallest bounded probe

      structural counterexample
          -> Alloy

      temporal/interleaving question
          -> TLA+ / Apalache / SPIN

      finite projection / geometry
          -> J

      backwards/relational search
          -> miniKanren

      reusable general law
          -> Lean

      performance/usability
          -> measurement

5. After a production change:
      -> ordinary build/tests/qualification
      -> review against Semantic Blueprint
      -> record only the smallest evidence worth keeping
```

## Authority rule

No item in this workbench is automatically production authority.

```text
AI reasoning
diagram
DAG
audit script
model checker
proof assistant
test
benchmark
        |
        v
      evidence
        |
        v
reviewed production decision / qualified boundary
```

A theorem proves its proposition under its assumptions. A diagram exposes a
projection. A model checker answers the model and scope it was given. An audit
script reports the repository facts it was written to collect.

Always state the boundary of the evidence.

## Maintenance

Keep this page as an **index**, not a duplicate manual.

When LOAM gains a durable new AI-facing instrument:

1. add one entry here;
2. point to its real owner/documentation;
3. state when to use it and when not to;
4. state whether it is evidence, qualification machinery, or authority;
5. avoid copying detailed semantics that already have a narrower owner.

Retire an entry when the instrument no longer exists or no longer answers a
distinct live question. Git history remains the archive.

The purpose of this workbench is not to preserve every tool forever. It is to
make the tools that still matter discoverable to the next AI or human entering
LOAM.
