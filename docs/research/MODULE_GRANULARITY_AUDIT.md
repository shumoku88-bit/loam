# Module Granularity Audit

Status: **EXPERIMENTAL INVENTORY — no merge/split verdict authorized yet**

## Question

Has LOAM's physical Lean module structure become finer than its actual semantic,
mechanical, proof, or effect boundaries require?

This audit is deliberately different from LOC reduction. A tiny module may be the
right boundary when it owns a reusable identity, law, authority, protocol order,
proof obligation, effect shell, or independently changing policy.

The governing question is:

> If two neighboring modules were one file, what independent reason to change,
> reuse, prove, qualify, or own would be lost? Conversely, if no such independent
> reason exists, is the physical boundary making the program harder to see?

## Non-goals

- no target file count;
- no target LOC count;
- no automatic merging of small modules;
- no assumption that one-consumer modules are redundant;
- no broad refactor while Generation-2 semantic audit slices are active;
- no ontology inferred from aggregation barrels such as `Loam/Core.lean`.

## Instruments

The first pass uses three primary instruments.

1. **Module dependency DAG**
   - exact local imports;
   - fan-in and fan-out;
   - one-consumer chains;
   - barrels and broad dependency edges.
2. **Git co-change evidence**
   - recent commits in which modules move together;
   - used as evidence of coupling, never as proof of sameness.
3. **Source responsibility inspection**
   - declarations owned by each file;
   - semantic authority;
   - read/write/effect boundary;
   - proof or qualification ownership.

DRAKON is a second-stage instrument for a suspicious cluster, not the global
module map. Lean build/tests establish compile and behavioral preservation after
an actual boundary change. Alloy/TLA+ are reserved for candidates whose physical
split may correspond to a real state-space or temporal distinction.

## Inventory tool

`tools/module_granularity_audit.py` emits descriptive evidence only.

```text
python3 tools/module_granularity_audit.py \
  --tsv /tmp/loam-module-granularity.tsv \
  --dot /tmp/loam-module-imports.dot \
  --markdown /tmp/loam-module-granularity.md
```

For each Lean module it records:

- path and coarse physical layer;
- line and byte counts;
- top-level declaration count;
- local dependency fan-in/fan-out;
- exact sole consumer, when one exists;
- recent co-change count with that sole consumer.

These fields select candidates. They do not decide them.

## Candidate decision test

A candidate boundary is classified only after answering all five questions:

| Lens | Keep the boundary when... | Inspect for collapse when... |
|---|---|---|
| semantic ownership | it owns a distinct household concept/law | it only names an intermediate step of its consumer |
| reuse topology | multiple independent consumers need it | it has one consumer and no plausible independent use |
| change reason | it changes under a separate requirement | it almost always changes only with its consumer |
| effect/authority | it isolates I/O, ownership, persistence, or terminal effects | both sides have the same effect/authority reason |
| proof/qualification | it carries an independently useful theorem or qualification seam | split adds navigation without an independent obligation |

A merge requires positive evidence from this table. File size alone can never
satisfy the criterion.

## Initial calibration cases

The first experiment deliberately includes known small modules that should stop
false-positive heuristics.

### Expected KEEP controls

- `Loam.Core.Purpose`: tiny shared semantic coordinate used by Capacity,
  Historical Routing, and Purpose presentation/catalog surfaces.
- `Loam.FreshNumberedToken`: tiny shared total allocation mechanic used by
  multiple independent write families.
- `Loam.ScheduledActualOwnership`: tiny shared ownership-order mechanic used by
  multiple publishers.
- `Loam.SparseEffectIdentity`: small normalization law used by Movement,
  Correction, and Scheduled completion paths.

If an automated ranking puts these at the top merely because they are small, the
ranking is wrong.

### Deliberate inspection control

- `Loam.Tui.CompletionPrompt`: very small, TUI-local recognition projection with
  a narrow consumer surface. It is worth inspecting, but its prior move under
  `Tui/` and the already-large `Tui/Cli` consumer mean collapse is not presumed.

This gives the audit both negative and positive calibration instead of starting
with a deletion hunt.

## Pass order

1. **Core + Application + Persistence**: calibrate semantic/mechanical boundaries.
2. **Root production modules**: publishers, authorities, reviews, configs, shared
   mechanics.
3. **CLI**: inspect legacy/specialized executable boundaries and thin wrappers.
4. **TUI**: inspect `Foo` / `FooSession` pairs, administration surfaces, helpers,
   and the large `Cli` / `Reports` files separately.
5. **Tests and historical Observations**: use primarily as qualification and
   history evidence, not as production-module merge targets.

The active Generation-2 audit remains authoritative for semantic subtraction.
This audit asks a different question: whether physical module boundaries still
match the independent reasons LOAM has to change.

## First stop condition

The inventory pass ends with a small candidate ledger, not code movement.
Each candidate receives one of:

```text
KEEP_BOUNDARY
COLLAPSE_CANDIDATE
MOVE_LAYER_CANDIDATE
SPLIT_CANDIDATE
NEEDS_DRAKON
NEEDS_HISTORY
```

Only a `COLLAPSE_CANDIDATE` with source and history evidence graduates to a
separate, narrow implementation PR.
