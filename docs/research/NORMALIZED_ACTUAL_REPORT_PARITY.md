# Normalized Actual report-boundary parity

This checkpoint follows the white-sheet Actual model and normalized-wire experiments.
It asks whether compressing current selected Actual evidence into the normalized
representation changes higher household observations that also compose policy,
Capacity, Scheduled pressure, funding selection, and physical balances.

This is research-only differential evidence. It does not authorize a canonical
cutover and does not make the normalized-to-current test bridge permanent.

## Input

The private `loam-data` experiment is based on canonical household main
`169450fc1b85fe998070b91da16af1e4dccd25ca` and changes only its experimental
workflow.

The selected real Actual contains 593 Events.

`current_to_normalized_actual.py` projects that selected Actual into:

```text
57,771 bytes
```

The current three-family Event / ActualValidity / EventDescription representation
measured 74,301 bytes in the preceding compact-Actual experiment.

## Differential protocol

`tools/check-normalized-actual-dogfood` performs only test scaffolding:

```text
original current household root
  -> project selected Actual into normalized actual.loam
  -> copy all other current policy / Scheduled / configuration evidence
  -> materialize normalized Actual into a disposable current-format fixture
  -> compare production observations original vs rebuilt
```

The bridge-generated eager Effect keys are fixture vocabulary only. They are not
part of the normalized canonical proposal and are not included in retained semantic
identity unless Relation evidence requires a durable Effect key.

## Production observation surfaces

The comparison deliberately reuses existing production observers rather than
reimplementing household arithmetic.

### HOBS1

`loamHouseholdObservation` compares:

- Balance;
- Budget;
- Capacity.

### CycleBudgetReview

`Loam/Tests/ThreeStreamCycleObservation.lean` calls
`Loam.CycleBudgetReview.loadSnapshotAt` and compares the deterministic production
snapshot for:

- cycle window;
- CurrentCoverage and Scheduled commitment/headroom pressure;
- physical balances;
- explicit funding selection;
- funding result.

## Real-data result

Private `loam-data` workflow run `34679803903` completed SUCCESS against LOAM head
`a0a37c1a80bb6646396c10efc1758fb4e276c246`.

The decisive log is:

```text
== project current Actual into normalized wire ==
projected 593 current Events into 57771 normalized bytes
normalized bytes: 57771
== materialize normalized Actual into disposable current fixture ==
differential bridge materialized 593 normalized TXs into current production persistence fixtures
== HOBS1 original ==
== HOBS1 rebuilt ==
== HOBS1 diff ==
== CycleBudget original ==
== CycleBudget rebuilt ==
== CycleBudget diff ==
normalized Actual report parity passed
  HOBS1: Balance / Budget / Capacity identical
  CycleBudgetReview: Funding / CurrentCoverage / Scheduled pressure / physical balances identical
```

The same run also retained the lower-level normalized/current production semantic
observation parity before the report comparison.

## Verdict

For the current real household world, the tested higher observations do not require
the current physical Actual-family topology or eager Effect identity allocation.

The normalized shape can carry the selected Actual meaning while the unchanged
policy / Capacity / Scheduled evidence produces exactly the same tested household
answers.

This strengthens the interpretation that the current persistence split is an
implementation topology rather than independently earned household semantics.

## What this does not prove

It does not yet prove:

- filesystem power-loss durability of a production normalized generation writer;
- concurrency or writer serialization for a cutover implementation;
- a production Lean normalized codec;
- that the current Core `Effect` type should become optional-keyed;
- that a permanent compatibility adapter should exist.

The disposable bridge should be deleted once migration qualification is complete.

## Next architectural gate

Do not productionize the bridge.

The next production-oriented design should make persistence representations feed one
semantic Actual read boundary, so HOBS1, CycleBudget, reports, CLI and TUI consume
meaning rather than Event/ActualValidity/EventDescription file topology.

Only after that boundary is qualified should a one-time migration and atomic
selected-generation cutover be designed.