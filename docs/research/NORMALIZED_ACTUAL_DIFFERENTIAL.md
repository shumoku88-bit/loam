# Normalized Actual vs current production differential

This experiment follows #749's standalone normalized `actual.loam` qualification.
It asks the next gate:

> Does the normalized model return the same semantic observations as today's
> production persistence decoders and Application frontiers for one world that
> exercises the rare Actual semantics?

The answer for the synthetic qualification is **yes**.

## Boundary

The bridge in `tools/normalized_to_current_fixture.py` is deliberately test-only.
It is not a migration API, production codec, compatibility layer, or second writer.
It exists only to place one normalized synthetic world into today's physical fixture
shape so the existing production readers can observe it.

Keyless ordinary normalized Effects receive generated current-fixture keys because
today's in-memory `Effect` requires one. Those generated keys are hidden from the
semantic comparison; only EffectKeys actually retained as RelationUnit sources are
observable as durable identity.

## Production observation path

`Loam/Tests/NormalizedActualProductionObservation.lean` delegates semantic work to
current production boundaries:

- `MovementManifestAuthority.loadSelectedEvidence?` for selected Movement evidence;
- `Application.correctionFrontierMemory?` for Event-correction admission;
- `Application.admittedActualValidityMemory?` for current occurrence dates;
- `Application.relationOutstandingQuantity?` for RelationUnit + discharge state;
- current EventDescription, RelationUnit, RelationDischarge, EventCorrection, and
  ActualReversal persistence decoders for raw retained provenance.

It does not implement replacement/frontier arithmetic itself.

ActualReversal exact-inverse admission currently belongs to the production reversal
publisher rather than a read frontier. This differential therefore compares reversal
identity plus the physical Effect evidence; the existing publisher remains the
operation-specific guard for creating reversals.

## Synthetic world

The shared fixture `tools/normalized_actual_fixture.loam` contains eight Events and
exercises:

- Event correction chain `correction-0 -> correction-1 -> correction-2`;
- two-step occurrence-date revision for `correction-2`;
- explicit `payment -> payment-reversal` relation with inverse Effects;
- RelationUnit `relation-1` anchored to stable `source-effect`;
- an additional ordinary Effect at the same `bank/jpy` coordinate;
- two later partial discharges, leaving exact outstanding quantity 150;
- descriptions and no-description Events.

## Result

Workflow `Normalized Actual Differential`, run `34679127513`, completed SUCCESS at
head `3744aa381370c1d047306a094b793fcc819eb53c`.

The CI sequence was:

```text
build current production Lean boundary                      PASS
publish EmptyMovementManifest fixture                       PASS
materialize 8 normalized TXs into current persistence       PASS
read normalized semantic observation                        PASS
read current production semantic observation                PASS
compare observations as row multisets                       PASS
```

The final receipt was:

```text
normalized/current production semantic observation parity PASS
```

The compared observation surface includes:

- every Event identity;
- current occurrence date;
- description presence/text;
- every physical Effect payload;
- stable EffectKey only when independently retained as relation source;
- complete date-revision rows and predecessor edges;
- Event correction edges;
- explicit reversal edges;
- RelationUnit source Event/Effect, endpoints, quantity, and outstanding quantity;
- partial discharge Event/target/quantity provenance.

Row order is intentionally excluded because current LOAM already treats Event/Effect
collection order as representation rather than household meaning.

## What this establishes

The normalized model is no longer only a white-sheet Alloy model or a self-consistent
new codec. One nontrivial admitted world is observationally equivalent through
current production read semantics.

That is evidence for **representation compression**, not permission to migrate.

## What remains

1. Scale the same comparison across the current real household Actual data.
2. Keep production reversal creation guarded by its existing publisher or prove an
   equivalent operation-specific admission for any future normalized writer.
3. Compare physical balance / HOBS1 / CycleBudget on real data after normalized
   projection. Previous #743/#744/#746 experiments already cover related projection
   changes, but the final normalized shape should receive its own end-to-end receipt.
4. Only after these are green should a production migration/cutover be designed.

A future production implementation should not retain the test-only bridge. The old
families are evidence inputs for one migration, not permanent architecture.
