# Observation 206 — Does discrepancy repair require mutating historical evidence?

Status: **OBSERVING concept-pressure probe**

Source: **F088 — missing history can be padded or left unknown**

## Question

Observation 201 / F086 established that reconstructed history and an independent physical/external quantity assertion can disagree without either evidence family determining the other.

F088 asks the next epistemic question:

```text
same reconstructed quantity
+ same external assertion

can still differ on

history completeness
+ repair policy
```

The selected query is a repaired reconstruction view, not authoritative truth.

## Observation-local candidate

```text
reconstructed : Quantity
asserted      : Quantity
status        : Complete | Incomplete
repair        : LeaveUnknown | PadToAssertion
```

`repair` exists only for incomplete history.

Selected reconstruction:

```text
Complete
  -> retain reconstructed quantity

Incomplete + LeaveUnknown
  -> no selected reconstructed quantity

Incomplete + PadToAssertion
  -> use external assertion as a padded reconstruction view
```

This does not create or modify an Event. `PadToAssertion` is an observation-local query policy, not canonical historical fact.

## Attacks

1. Same reconstructed quantity and external assertion, different completeness.
2. Same incomplete evidence, different repair policy, producing unknown vs padded quantity.
3. Same selected scalar quantity with different provenance: complete reconstruction vs padded incomplete reconstruction.
4. Fix all additive evidence and ask whether the selected view still differs.
5. Check that LeaveUnknown never silently selects a quantity.
6. Check that PadToAssertion selects the assertion only as the repair view.

Expected matrix:

```text
representativeLeaveUnknownVsPad                    SAT
sameEvidenceDifferentCompleteness                   SAT
sameSelectedDifferentProvenance                    SAT
ReconstructionAndAssertionDetermineCompleteness    SAT counterexample
IncompleteEvidenceDeterminesRepairOutcome          SAT counterexample
SelectedReconstructionDeterminesProvenance         SAT counterexample
ExplicitAdditiveEvidenceDeterminesSelectedView     UNSAT counterexample
LeaveUnknownHasNoSelectedReconstruction             UNSAT counterexample
PadToAssertionSelectsAssertion                      UNSAT counterexample
```

## Architectural interpretation under test

If this matrix holds, F088 demonstrates independently observable completeness and repair-policy information, but not Core-shape failure.

A conservative additive/query-local representation would survive while retained Events and reconstructed history remain unchanged.

The architectural classification would remain:

```text
B / CONSERVATIVE EXTENSION
```

It would also show that materializing only the repaired scalar is too small because the same scalar may come from complete history or from padding incomplete history.

## Deliberate boundaries

Observation 206 does not establish:

- a production `HistoryCompleteness`, `RepairPolicy`, `Adjustment`, or `OpeningBalance` type;
- that an external assertion is authoritative truth;
- automatic balancing or synthetic Actual creation;
- an algorithm for discovering missing Events;
- source trust ranking;
- multi-assertion conflict resolution;
- historical mutation;
- persistence, CLI/TUI, or canonical household-data behavior.

Runtime remains research-only.
