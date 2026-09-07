# LOAM design philosophy

## Build a keeper, not a compatibility museum

LOAM is allowed to be unusually ambitious because it does not currently carry the normal burden of protecting a large installed base. HRA is currently the day-to-day household authority while LOAM is rebuilt in parallel with real household dogfood. HRA therefore supplies operational continuity and research pressure without becoming a compatibility target or an ontology that LOAM must preserve. The same household reality can keep serving as a demanding test track while LOAM pursues a cleaner design, including destructive changes to its own canonical data and authority layout.

The current HRA / LOAM relationship is fixed in [`docs/HOUSEHOLD_OPERATING_MODE.md`](docs/HOUSEHOLD_OPERATING_MODE.md). A future return of LOAM to operational authority requires an explicit cutover rather than an implicit change of assumptions.

The aspiration is closer to a focused, enduring machine than to a feature catalogue: the compactness and purpose of a Roadster, the concentrated engineering of a GR Yaris, or the uncompromising specialization of a Stratos. The analogy is about focus, not imitation. A memorable product is not memorable because it contains everything. It is memorable because its decisions reinforce one another.

For LOAM, that means optimizing for:

```text
coherence
minimal canonical evidence
semantic clarity
directness
reconstructability
strong checking laws
human-operable simplicity
```

rather than for preserving every earlier LOAM decision.

## Earlier LOAM is evidence, not authority

An existing type, command, persistence format, identifier, or document may encode valuable observations. It does not become correct merely by existing.

When later work exposes a smaller or more coherent model, LOAM may:

- replace public-looking APIs;
- change persistence formats;
- rename or remove concepts;
- rewrite migration fixtures;
- restructure canonical dogfood data;
- delete entire implementation paths;
- discard an earlier Practical Core abstraction.

Historical work should survive when the information or law it discovered still matters. Its concrete implementation does not receive the same protection.

## LOAM canonical dogfood data is part of the experiment

Real household data is not a museum specimen for an old LOAM schema. It is a pressure source for the current model.

During the current operating mode, `canonical` inside LOAM means selected authority for the current LOAM experiment, not final operational authority for household reality. HRA currently carries the day-to-day operational record. LOAM canonical data, identifiers, manifests, provenance structures, and publication boundaries may therefore be redesigned or regenerated when that produces a better model.

If a better representation is earned, LOAM dogfood data may be migrated or rewritten to that representation. The important distinction is semantic:

```text
change of representation
    may rewrite data shape

identity / alias normalization
    may rewrite naming when identity is intentionally unified

correction of what actually happened
    remains a different claim and needs evidence appropriate to that claim
```

Do not retain obsolete spellings, identifiers, fields, authority layouts, or compatibility records solely to avoid a migration.

When conversion is needed, prefer a disposable, explicit migration or reconstruction step over a permanent compatibility subsystem. When an experiment claims parity with HRA or a particular historical fact, preserve or reconstruct only the evidence needed to support that claim rather than treating every earlier LOAM byte as sacred provenance.

## The central compression rule

LOAM should repeatedly ask:

> What is the smallest independently observable information from which the household answers can still be reconstructed?

The current research has repeatedly found a useful boundary:

```text
share algebra and mechanics
preserve semantic authority
```

Equal data shape is evidence for implementation reuse, not proof that two meanings are the same.

Likewise, a familiar household noun does not automatically deserve canonical storage. `Commitment`, `Remaining`, `Headroom`, report sections, status labels, and similar answers should remain projections when their upstream evidence is sufficient.

## Breakage budget

During the present phase, breakage is cheap and accidental complexity is expensive.

Therefore:

```text
compatibility layer
    requires justification

destructive simplification
    is permitted by default when it preserves the desired household meaning

migration avoidance
    is not an architectural objective
```

This does not license churn. A destructive change should buy something substantial: a clearer information boundary, fewer primitives, stronger laws, a simpler operation, or removal of an abstraction that no longer earns its cost.

## Formal methods serve the design

LOAM does not exist to demonstrate Alloy, TLA+, Lean, category theory, or any other formal technique. Those tools are used when they reveal distinctions that ordinary implementation makes easy to blur.

A healthy order is:

```text
household question
    -> competing representations
    -> observation / counterexample
    -> minimum surviving information
    -> practical Lean type or function
    -> proof only where the law deserves permanence
```

If a mathematical structure repeatedly appears after this process, name it then. Do not force the household model into an attractive theory in advance.

## What quality means here

Before keeping a new primitive or abstraction, ask:

1. Which household answer becomes impossible without it?
2. Can that answer be derived from evidence already retained?
3. Does the abstraction share mechanics while accidentally merging semantic authority?
4. Is this state, or only a projection that is convenient to display?
5. Would deleting this make the system easier to explain without losing meaning?
6. Are we preserving it for design reasons, or only because earlier LOAM already used it?

A good LOAM design should increasingly feel inevitable: fewer pieces, stronger relationships between them, and less code whose only purpose is to defend yesterday's shape.

## Compatibility can be earned later

If LOAM eventually becomes a product with external users, long-lived files, integrations, or a public data contract, backward compatibility may become a first-class requirement.

That would be a new phase with a new constraint. At that point compatibility should be designed deliberately around a mature core.

Until then, do not make the experimental chassis heavier in anticipation of passengers who are not yet aboard.
