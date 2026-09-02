# LOAM development policy

Read `DESIGN_PHILOSOPHY.md` before making architectural or persistence decisions.

LOAM is an experimental household system whose current job is to discover the smallest coherent design that survives real household use. It is not currently constrained by third-party users or by backward compatibility with its own earlier shapes.

## Standing rules

- **Design quality outranks backward compatibility.** Existing APIs, types, file formats, commands, names, and persistence shapes have no preservation privilege. Replace or delete them when a clearer model is earned.
- **Destructive redesign is allowed.** Do not add indirection merely to keep an obsolete representation alive.
- **Canonical dogfood data may be migrated or rewritten when the model improves.** Preserve semantic truth and provenance that still matter; do not preserve an old encoding merely because it already exists.
- **Prefer one-time migration over permanent compatibility machinery.** A temporary conversion script is usually better than a compatibility layer that becomes part of the product.
- **Do not design for hypothetical external consumers.** HRA and h-kernel remain available as operational household systems while LOAM experiments with stronger redesigns.
- **Every retained primitive must earn its place.** If a household answer can be reconstructed without storing another fact, prefer the reconstruction.
- **Share mechanics without erasing meaning.** Reuse algebra, relation shape, routing history, or temporal machinery when possible, but preserve semantic partitions whenever removing one changes an independently observable answer.
- **Keep projections as projections.** Reports, labels, statuses, summaries, and convenience views should not become canonical state unless an observation demonstrates that the upstream evidence is insufficient.
- **Formal tools are observational instruments.** Alloy, TLA+, Lean, and other tools should expose information boundaries and laws. Do not promote an unqualified hypothesis into production vocabulary merely because it is elegant.
- **Delete freely.** Code volume, abstraction count, historical implementation effort, and compatibility are not reasons to keep a weaker design.

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

If LOAM later gains external users or a stable public data contract, compatibility must be introduced as a newly explicit product requirement. Do not assume that requirement in advance.
