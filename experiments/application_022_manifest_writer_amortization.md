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

## Qualified result

The exact-head Application 022 workflow on
`cb1bea509699ec1e40c343b306bf3926d8925ba2` completed successfully after one
same-day probe-only IO return typo was corrected.

The Lean runtime probe executed all five writer adapters and reported:

```text
Application 022 manifest writer amortization PASS
writers=5
changed_object_preparations=16
authority_switches=5
```

For every operation it checked that exactly the intended family references changed:

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
digest-checks every referenced object, and the initial immutable objects remain
present.

The exact source-boundary measurement was:

```text
current Movement publication tail                 58 lines   3949 bytes
current Scheduled completion publication tail     38 lines   3330 bytes
current Event correction publication tail         23 lines   1249 bytes
current Capacity publication tail                 22 lines   1605 bytes
current QuantityBasis correction publication tail 23 lines   1646 bytes
                                                   --------   -----------
current five-writer total                         164 lines  11779 bytes

scratch shared manifest/object infrastructure     168 lines   6239 bytes
scratch five writer adapters                       33 lines   1426 bytes
                                                   --------   ----------
scratch shared + five adapters                    201 lines   7665 bytes
```

So at this deliberately narrow physical-publication boundary:

```text
line ratio   = 1.226   -> scratch is 37 lines / 22.6% larger
byte ratio   = 0.651   -> scratch is 4114 bytes / 34.9% smaller
```

The current tails contain sixteen writer-specific cross-family persistence save
calls. The scratch side has five writer adapters and five calls into one shared
`publishChanges` authority primitive.

## Interpretation

This is partial amortization, not a decisive source-size win.

The five writer-specific manifest adapters together are only 33 lines. The
remaining line-count cost is the 168-line shared manifest/object mechanism. Five
writers therefore do not yet repay that fixed cost when source lines alone are
the measure.

The byte result points in the other direction: even after paying the shared
infrastructure once, the scratch boundary is already about one third smaller in
raw source bytes. The difference arises partly because current publication tails
encode operation-specific nested failure and inert-residue explanations, while
the shared primitive centralizes the physical transition.

Neither metric alone earns migration. The comparison is intentionally
conservative in one direction and incomplete in the other:

- scratch includes its shared reader/manifest/digest mechanism in the measured
  cost;
- current counts only writer publication tails, not all recovery and identity
  reservation machinery induced by partial authority-store residue;
- scratch does not yet include migration, garbage collection, production reader
  integration, or compatibility cost.

The strongest earned statement is therefore:

```text
one explicit shared physical publication mechanism
can replace sixteen writer-specific cross-family save sites
with five small operation adapters,
while preserving typed family identity and changed-family locality;
but five writers alone do not yet prove a smaller production architecture.
```

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

## Next pressure

The next comparison should not add more cosmetic adapters. Application 018
identified recovery and identity-reservation protocol as a major production cost,
and Applications 019-022 now show why that protocol exists physically.

The smallest useful follow-up is to compare the five current writers against the
manifest topology at the **whole mutation/recovery boundary**:

- which orphan-residue branches disappear when unselected objects are never
  authority;
- which semantic identity-reservation scans are no longer required merely to
  avoid rebinding interrupted physical residue;
- which retry branches remain because they express actual household semantics
  rather than storage topology;
- whether shared manifest infrastructure plus the retained semantic branches is
  smaller than the current five writer protocols in both lines and bytes.

## Boundary

No production source, persistence format, canonical path, executable behavior,
identity rule, migration, or household data changes.

This remains a source-boundary observation, not production migration authority.
Reader integration, migration cost, garbage collection, and exact crash/retry
behavior remain separate adoption gates.
