# Observation 206 — Does discrepancy repair require mutating historical evidence?

Status: **COMPLETE / B — CONSERVATIVE EXTENSION; C NOT DEMONSTRATED**

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

## Mechanical result

Dedicated Observation 206 Alloy CI completed SUCCESS on executable PR head:

```text
73505b3d46efabe5f0fa61bb6654c5f5d47ac709
```

Workflow run:

```text
34009588777
```

Job:

```text
101422945040
```

Alloy 6.2.0 + Sat4j produced exactly the selected matrix:

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

## What the witnesses show

### Reconstruction + assertion do not determine completeness

The bounded witness keeps both quantities fixed:

```text
Left
  reconstructed = Q10
  asserted      = Q8
  status        = Complete

Right
  reconstructed = Q10
  asserted      = Q8
  status        = Incomplete
  repair        = LeaveUnknown
```

So the same numeric discrepancy does not say whether retained history is believed complete.

### Incompleteness does not determine repair policy

With the same reconstructed quantity, same assertion, and the same `Incomplete` status:

```text
Left   LeaveUnknown   -> no selected reconstruction
Right  PadToAssertion -> selected reconstruction Q8
```

Therefore epistemic status and repair policy are independently observable dimensions in the selected query.

### The repaired scalar does not preserve provenance

Observation 206 also found worlds with the same selected scalar but different provenance:

```text
Complete history -> Q8

vs

Incomplete history
+ PadToAssertion -> Q8
```

Therefore:

```text
selected repaired scalar
  -/->
complete-vs-padded provenance
```

Materializing only the scalar would erase information relevant to explaining how that quantity was obtained.

### Explicit additive evidence closes the selected gap

Once reconstructed quantity, external assertion, completeness status, and repair policy are all fixed, Alloy found no counterexample to the selected repaired reconstruction / unresolved view in scope.

This is bounded sufficiency only. It does not establish these observation-local names as a universal or production representation.

## Architectural result

F088 exposes real additional information, but no Core-shape failure.

```text
reconstructed + asserted
  -/-> completeness

reconstructed + asserted + completeness
  -/-> repair outcome

repaired scalar
  -/-> repair provenance

explicit additive completeness + repair evidence
  -> selected bounded repair view
```

Current classification:

```text
B / CONSERVATIVE EXTENSION
```

Retained Events and historical reconstruction can stay unchanged. A repair/padding view can remain additive and query-local rather than silently publishing a synthetic Actual or mutating historical evidence.

This is exactly the architectural null hypothesis under test: missing epistemic/policy evidence can live beside existing facts without broadening their meaning.

## What is not earned

Observation 206 does **not** earn a production:

- `HistoryCompleteness`;
- `RepairPolicy`;
- `Adjustment`;
- `OpeningBalance`;
- synthetic Actual;
- generic uncertainty framework.

It also does not establish that an external assertion is authoritative truth, how missing Events are discovered, source trust ranking, multi-assertion conflict resolution, or persistence / CLI / TUI behavior.

Runtime remains `RESEARCH_ONLY`.
