# LOAM design philosophy

## Keep the system small and understandable

LOAM is the current day-to-day household system and is still under active development. It has no external compatibility obligation, but its operational household data now deserves explicit continuity and migration care.

HRA is no longer the parallel operational authority. It remains historical implementation, migration provenance, and comparison material where useful. The current relationship is defined in [`docs/HOUSEHOLD_OPERATING_MODE.md`](docs/HOUSEHOLD_OPERATING_MODE.md).

LOAM aims for a small set of concepts and mechanisms that are easy to explain, test, and operate. In practice that means preferring:

```text
coherence
minimal canonical evidence
semantic clarity
directness
reconstructability
strong checking laws
human-operable simplicity
```

A larger implementation is acceptable when those properties are clearer than they would be after premature compression.

## Earlier LOAM is evidence, not authority

An existing type, command, persistence format, identifier, or document may encode useful observations. It does not become permanent merely by existing.

When later work supports a simpler model, LOAM may:

- replace internal or public-looking APIs;
- rename or remove concepts;
- change persistence formats through an explicit migration;
- remove obsolete implementation paths;
- discard an abstraction that no longer earns its cost.

Historical research should remain available when the result or evidence still matters. The current implementation does not need to preserve every earlier shape.

## Operational data is not disposable

Current `loam-data` objects, manifests, and configuration carry day-to-day household meaning.

A representation may still change, but operational data changes need an explicit migration, reconstruction, or other qualified transition. The goal is to preserve the household facts while allowing the representation to improve.

Keep these cases distinct:

```text
change of implementation
    may replace code without changing household facts

change of representation
    may migrate stored data while preserving household meaning

identity / alias normalization
    may rewrite naming when identity is intentionally unified

correction of what actually happened
    is a separate claim and needs appropriate evidence
```

Do not keep obsolete fields or compatibility structures solely to avoid a migration. Also do not delete or regenerate current household data merely because a new representation is cleaner.

When conversion is needed, prefer an explicit migration or reconstruction step over a permanent compatibility subsystem.

## Compression is a means, not a target

A useful recurring question is:

> What information must be retained independently, and what can be reconstructed when needed?

A practical boundary used throughout LOAM is:

```text
share algebra and mechanics
preserve semantic authority
```

Equal data shape can justify implementation reuse, but it does not by itself show that two meanings are the same.

Likewise, a familiar household noun does not automatically require canonical storage. `Commitment`, `Remaining`, `Headroom`, report sections, status labels, and similar answers should remain projections when existing evidence is sufficient.

Code size, file count, and declaration count are useful audit signals, not design goals on their own.

## Compatibility during active development

Internal compatibility is secondary to a clearer design when LOAM itself is the only consumer.

Operational household data is different: if a change affects its stored representation, provide an explicit migration or reconstruction path and qualify the result before treating the new representation as authoritative.

A compatibility layer therefore requires a concrete reason. So does a destructive change. Neither is preferred by default.

## Formal methods serve the design

LOAM does not exist to demonstrate Alloy, TLA+, Lean, category theory, or any other formal technique. Use those tools when they make an information boundary, counterexample, state transition, or law clearer.

A useful order is:

```text
household question
    -> competing representations
    -> observation / counterexample
    -> minimum surviving information
    -> practical Lean type or function
    -> proof where the law is worth retaining
```

If a mathematical structure repeatedly appears after this process, name it then. Do not choose the household model to fit an attractive theory in advance.

## What quality means here

Before keeping a new primitive or abstraction, ask:

1. Which household answer becomes unavailable without it?
2. Can that answer be derived from evidence already retained?
3. Does the abstraction share mechanics while accidentally merging semantic authority?
4. Is this durable state, or only a convenient projection?
5. Would removing it make the system easier to explain without losing meaning?
6. Are we preserving it for a current reason, or only because an earlier LOAM version used it?

A good change should leave the system easier to explain, operate, or verify. Fewer pieces are useful when they actually produce that result.

## External compatibility

LOAM currently has no external user or public data-contract obligation.

If that changes, backward compatibility should become an explicit product requirement. Until then, avoid compatibility machinery for hypothetical consumers, while continuing to protect current household data through explicit migrations and evidence-backed transitions.
