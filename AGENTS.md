# LOAM development policy

Read `DESIGN_PHILOSOPHY.md` and `docs/HOUSEHOLD_OPERATING_MODE.md` before making architectural, persistence, canonical-data, or household-authority decisions.

LOAM is an experimental household system whose current job is to discover the smallest coherent design that survives real household use. It is not currently constrained by third-party users or by backward compatibility with its own earlier shapes.

## Standing rules

- **HRA is the current day-to-day household authority.** Ordinary household recording continues there while LOAM is rebuilt in parallel. LOAM does not silently become operational authority because a feature starts working.
- **LOAM remains real-data dogfood.** Real household events may also be recorded in LOAM through the user or explicit AI-assisted entrances. Exact HRA ↔ LOAM mirroring is required only when a named experiment or reconciliation claims it.
- **Design quality outranks backward compatibility.** Existing APIs, types, file formats, commands, names, and persistence shapes have no preservation privilege. Replace or delete them when a clearer model is earned.
- **Destructive redesign is allowed.** Do not add indirection merely to keep an obsolete representation alive.
- **LOAM canonical dogfood data may be migrated, regenerated, rewritten, or deleted when the model improves.** `Canonical` currently means selected for the LOAM experiment, not operational household authority. Preserve or reconstruct the evidence needed for the claim being made; do not preserve an old encoding merely because it already exists.
- **Prefer one-time reconstruction or migration over permanent compatibility machinery.** A temporary conversion, replay, or parity script is usually better than a compatibility layer that becomes part of the product.
- **Do not turn HRA into LOAM ontology.** HRA supplies operational continuity, real events, comparison answers, and reconstruction pressure. Its package boundaries, file shapes, concepts, reports, and vocabulary are not automatically LOAM Core concepts or compatibility targets.
- **Do not design for hypothetical external consumers.** LOAM still has no external compatibility obligation merely because HRA is operationally active in parallel.
- **Every retained primitive must earn its place.** If a household answer can be reconstructed without storing another fact, prefer the reconstruction.
- **Share mechanics without erasing meaning.** Reuse algebra, relation shape, routing history, or temporal machinery when possible, but preserve semantic partitions whenever removing one changes an independently observable answer.
- **Keep projections as projections.** Reports, labels, statuses, summaries, and convenience views should not become canonical state unless an observation demonstrates that the upstream evidence is insufficient.
- **Formal tools are observational instruments.** Alloy, TLA+, Lean, and other tools should expose information boundaries and laws. Do not promote an unqualified hypothesis into production vocabulary merely because it is elegant.
- **The repository is project memory.** If an insight should affect future development, record it in the repository before relying on it. Standing policy belongs in policy or philosophy docs, qualified findings belong in observation records, and executable expectations belong in tests or CI. Conversation memory is not project state.
- **Check semantic neighbors after each change.** After adding or changing a practical capability, follow its consequences through the nearest relevant semantic boundaries rather than qualifying the edited function in isolation. Prefer a focused one- or two-hop composition check over a speculative whole-system audit.
- **Delete freely.** Code volume, abstraction count, historical implementation effort, LOAM-local canonical shape, and compatibility are not reasons to keep a weaker design.

## Formal tool selection

Read the `Method` section of `README.md` as the full tool-selection policy. When choosing an instrument for a new observation, use the smallest subset that gives a distinct answer:

- **Alloy** for structural possibility, distinguishability, sufficiency, and bounded counterexamples.
- **J** for finite arrays, quotient geometry, projection/loss, exhaustive shape, and representation experiments.
- **Lean 4** for general laws worth retaining and for production semantics in the Practical Core/Application path.
- **TLA+ / TLC** for temporal behavior, state transitions, reachable histories, and operation-order questions.
- **Apalache** only when symbolic TLA+ checking or an inductive-invariant argument adds a distinct result.
- **SPIN / Promela** for concrete process interleavings and protocol-order races where scheduling is the pressure point.
- **miniKanren** only for genuinely relational or backwards-search questions that the active core cannot express clearly enough.

Do not introduce an optional tool merely because it is available or has been used before. State what the current toolset cannot answer clearly enough and what distinct result the added tool should provide. If two tools answer the same question in the same way, prefer the smaller combination.

## Decision preference

When two designs answer the same household questions, prefer in this order:

1. clearer semantic authority;
2. fewer independently retained facts;
3. smaller and more direct mechanisms;
4. easier reconstruction and checking;
5. simpler human operation;
6. compatibility with an earlier LOAM shape.

Compatibility is intentionally last during the present research phase.

## Change discipline

Freedom to break things is not freedom to change them arbitrarily.

A destructive change should be explainable by a stronger model, a real dogfood observation, a qualified formal result, or a substantial simplification. Do not churn names and formats for novelty alone.

For claims about real household history or HRA parity, qualify the specific observable being claimed. Full-system equivalence is never implied by a narrower parity result.

If LOAM later gains external users or a stable public data contract, compatibility must be introduced as a newly explicit product requirement. If LOAM is to become the day-to-day household authority again, perform the explicit cutover described in `docs/HOUSEHOLD_OPERATING_MODE.md`. Do not assume either transition in advance.

## Local composition discipline

A change may be implemented locally, but qualification should follow the household meaning far enough to catch nearby seams.

For each practical change:

1. name the household answer or evidence boundary that changed;
2. trace one or two meaningful hops through whichever adjacent concerns actually apply, such as correction or lifecycle, temporal evidence, routing or classification, persistence and recovery, or downstream projections;
3. ask whether the new path bypasses an existing correction frontier, creates a second source of semantic authority, turns a projection into stored state, or leaves writer and recovery behavior inconsistent with the derived answer;
4. when a concrete seam appears, record it in the repository and qualify it with the smallest appropriate observation, test, or CI specimen before fixing it in a focused change;
5. stop when no concrete ambiguity remains. Do not restart a broad inventory merely because more relationships could theoretically be inspected.

The intended rhythm is:

```text
small practical change
    -> nearby composition check
    -> concrete seam, if any
    -> focused observation or executable test
    -> small correction
```

This keeps LOAM attentive to whole-system coherence without turning every change into an endless audit.
