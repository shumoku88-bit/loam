# LOAM development policy

Read `DESIGN_PHILOSOPHY.md` and `docs/HOUSEHOLD_OPERATING_MODE.md` before making architectural, persistence, canonical-data, or household-authority decisions.

LOAM is the current day-to-day household system and is still under active development. It has no external compatibility obligation, but its operational household data must be preserved through explicit, qualified transitions when representations change.

## Standing rules

- **LOAM is the current household authority.** Ordinary household recording happens in LOAM.
- **HRA is historical reference.** Use it for migration evidence, comparison, or interaction ideas when a concrete task needs it. Do not maintain parallel day-to-day authority or automatic synchronization.
- **Operational data is not disposable.** Current `loam-data`, manifests, and configuration carry household meaning. A representation change needs an explicit migration, reconstruction, or other qualified transition.
- **Do not invent or silently alter household facts.** If evidence required for a migration, correction, or historical claim is unavailable, fail closed.
- **Internal compatibility requires a reason.** Existing APIs, types, commands, and implementation shapes may change when a clearer design justifies it. Do not keep obsolete wrappers or aliases without a current caller or contract.
- **Prefer explicit migration over permanent compatibility machinery.** A one-time conversion or reconstruction is usually better than keeping two long-lived representations.
- **Do not turn HRA into LOAM ontology.** HRA package boundaries, file shapes, concepts, reports, and vocabulary are not automatically LOAM Core concepts.
- **Do not design for hypothetical external consumers.** If external users or a public data contract appear later, add compatibility as an explicit requirement then.
- **Every retained primitive must earn its place.** If a household answer can be reconstructed from existing evidence, prefer the reconstruction.
- **Share mechanics without erasing meaning.** Reuse algebra, relation shape, routing history, or temporal machinery where useful, but preserve semantic partitions when removing one would change an independently observable answer.
- **Keep projections as projections.** Reports, labels, statuses, summaries, and convenience views should not become canonical state unless upstream evidence is insufficient.
- **Formal tools are instruments, not goals.** Alloy, TLA+, Lean, and other tools should clarify information boundaries and laws. Do not promote a hypothesis into production vocabulary merely because it is mathematically attractive.
- **The repository is project memory.** Standing policy belongs in policy or philosophy docs, qualified findings belong in observation records, and executable expectations belong in tests or CI.
- **Check semantic neighbors after practical changes.** Follow a changed capability through the nearest relevant correction, temporal, routing, persistence, or projection boundaries rather than qualifying one function in isolation.
- **Delete when evidence supports deletion.** Code volume, old effort, and earlier implementation shape are not reasons to keep an unused or weaker mechanism. Current operational data is a separate concern and must be migrated rather than casually discarded.

## Formal tool selection

Read the `Method` section of `README.md` as the full tool-selection policy. Use the smallest subset that gives a distinct answer:

- **Alloy** for structural possibility, distinguishability, sufficiency, and bounded counterexamples.
- **J** for finite arrays, quotient geometry, projection/loss, exhaustive shape, and representation experiments.
- **Lean 4** for general laws worth retaining and for production semantics in the Practical Core/Application path.
- **TLA+ / TLC** for temporal behavior, state transitions, reachable histories, and operation-order questions.
- **Apalache** only when symbolic TLA+ checking or an inductive-invariant argument adds a distinct result.
- **SPIN / Promela** for concrete process interleavings and protocol-order races where scheduling is the pressure point.
- **miniKanren** only for relational or backwards-search questions that the active core cannot express clearly enough.

Do not introduce an optional tool merely because it is available or has been used before. State what the current toolset cannot answer clearly enough and what distinct result the added tool should provide. If two tools answer the same question in the same way, prefer the smaller combination.

## Decision preference

When two designs answer the same household questions, prefer in this order:

1. clearer semantic authority;
2. fewer independently retained facts;
3. smaller and more direct mechanisms;
4. easier reconstruction and checking;
5. simpler human operation;
6. compatibility with an earlier internal LOAM shape.

This ordering does not override the requirement to preserve current operational household meaning during data migrations.

## Change discipline

A structural change should be explainable by a concrete need, a qualified observation, or a meaningful simplification. Do not churn names and formats for novelty alone.

For claims about real household history or HRA parity, qualify the specific observable being claimed. A narrow parity result does not imply full-system equivalence.

If LOAM later gains external users or a stable public data contract, compatibility becomes an explicit product requirement. Until then, distinguish internal API freedom from operational-data continuity.

## Local composition discipline

For each practical change:

1. name the household answer or evidence boundary that changed;
2. trace one or two meaningful hops through whichever adjacent concerns actually apply, such as correction or lifecycle, temporal evidence, routing or classification, persistence and recovery, or downstream projections;
3. ask whether the new path bypasses an existing correction frontier, creates a second source of semantic authority, turns a projection into stored state, or leaves writer and recovery behavior inconsistent with the derived answer;
4. when a concrete seam appears, record it and qualify it with the smallest appropriate observation, test, or CI specimen;
5. stop when no concrete ambiguity remains.

The intended rhythm is:

```text
small practical change
    -> nearby composition check
    -> concrete seam, if any
    -> focused observation or executable test
    -> small correction
```

This keeps qualification local enough to stay practical while still checking the nearest semantic consequences.
