# Application 022: Manifest writer amortization

## Pressure

Application 021 established a narrow but real result: once one Movement has already
been admitted, its writer-specific physical publication tail becomes much smaller
when five typed family images are prepared off-authority and selected by one
manifest replacement.

That result was not yet a whole-system compression result because the shared
manifest/object infrastructure is itself substantial.

Application 022 asks the next practical question:

> If the same physical publication primitive is reused across the five current
> writer families that carry multi-stream publication protocol, does the shared
> infrastructure amortize against their aggregate writer-specific publication
> tails?

This application is intentionally stacked on Application 021 / PR #392.

## Compared current writers

The source measurement fixes five current publication shapes:

1. Movement: ActualValidity, optional EventDescription, RelationUnit,
   RelationDischarge, then Event;
2. Scheduled completion: ScheduledCompletion, optional ActualValidity,
   optional EventDescription, then Event;
3. Event correction: EventCorrection, optional replacement ActualValidity, then
   replacement Event;
4. Capacity: CapacityEffective, then Capacity;
5. QuantityBasis correction: QuantityBasisCorrection, then replacement
   QuantityBasis.

The measurement starts at the first physical family save in each already-admitted
writer path and stops at that writer's next operation boundary. It therefore does
not claim that manifest publication replaces interactive input, identity
allocation, domain admission, or all recovery logic.

## Scratch shared primitive

The probe extends the generation manifest to twelve explicitly named families:

```text
Event
ActualValidity
EventDescription
RelationUnit
RelationDischarge
ActualRouting
ScheduledCompletion
EventCorrection
Capacity
CapacityEffective
QuantityBasis
QuantityBasisCorrection
```

Each family remains a separately named content-addressed object. A generic
`publishChanges` helper accepts only explicit `(Family, bytes)` changes, prepares
those objects off-authority, updates exactly those manifest references in memory,
and atomically replaces `CURRENT` once.

Five small writer adapters then state only which typed families that operation
changes. The physical helper does not infer a household meaning from byte shape.

## Runtime qualification

The Lean probe starts with one complete twelve-family manifest and executes all
five adapters in sequence.

For every operation it checks that exactly the intended family references change:

```text
Movement                 5 families
Scheduled completion     4 families
Event correction         3 families
Capacity                 2 families
QuantityBasis correction 2 families
                         ----------
                         16 prepared changed-family objects
```

Each adapter performs one manifest authority switch. The final selected manifest
must digest-check every referenced object, and the initial immutable objects must
still exist.

## Source measurement

The dedicated source script reports:

- lines and bytes for each of the five current physical-publication tails;
- their aggregate lines and bytes;
- shared manifest/object infrastructure lines and bytes, counted once;
- five scratch adapter lines and bytes;
- the aggregate scratch/current ratio and raw delta;
- the expected sixteen current cross-family save calls and five generic scratch
  authority call sites.

No ratio is asserted in advance. A negative result is useful: it would show that
manifest indirection improves temporal shape without yet reducing source at this
boundary.

## Smallness criterion

Smallness is counted only under retained constraints:

```text
explicit family identity
fail-closed manifest parsing
content-addressed immutable objects
one coherent authority selector
unchanged-family locality
inspectable old objects
existing writer ownership outside the probe
```

Moving domain distinctions behind an untyped blob or dropping recovery/safety
requirements would not count as compression.

## Boundary

No production source, persistence format, canonical path, executable behavior,
identity rule, migration, or household data changes.

Even a favorable aggregate result would still be a source-boundary observation,
not production migration authority. Reader integration, migration cost, garbage
collection, and exact crash/retry behavior would remain separate adoption gates.
