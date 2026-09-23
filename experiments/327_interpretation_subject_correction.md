# Observation 327 — interpretation subject provenance and current correction view

Status: **QUALIFIED BOUNDED ALLOY OBSERVATION — FINAL PRE-IMPLEMENTATION PRESSURE**

Baseline: stacked on qualified Observations 325–326.

## Trigger

Observation 326 qualified the split implementation boundary:

```text
note identity/text  -> zero-effect Event + EventDescription
metadata            -> subject EventId + recordedAt + optional attributedAt
```

One semantic question remains before implementation.

> If the household Event named by `subject` is later corrected/replaced, should
> retained interpretation evidence be rewritten to the replacement Event?

LOAM already separates retained EventCorrection provenance from current frontier
projection. This observation applies the same discipline.

## Candidate law

Store the exact subject EventId selected when the interpretation was retained.

Never mutate that stored subject merely because later EventCorrection evidence
appears.

For a current-view query only, project the stored subject through the admitted
correction chain to its terminal Event.

```text
stored subject:  E0
corrections:     E0 -> E1 -> E2

historical subject query -> E0
current subject query    -> E2
```

## Fail-closed boundary

Current projection is available only after the correction relation is admitted.

Branching/merging ambiguity or cycles must not cause the interpretation metadata
to be rewritten or guessed.

Production LOAM already has stronger correction-frontier admission and indexed
`terminalFrom` machinery. The Alloy model only checks the conceptual seam.

## Qualified matrix

GitHub Actions run `35894375361`, Alloy 6.2.0 / Sat4j:

```text
untouchedSubjectStaysItself              SAT
correctedSubjectProjectsToTerminal       SAT
malformedMergeExists                     SAT
malformedCycleExists                     SAT

AdmittedCurrentSubjectIsUnique           UNSAT counterexample
ProjectionNeverRewritesStoredSubject     UNSAT counterexample
CurrentSubjectIsReachableFromStoredSubject UNSAT counterexample
```

## Implementation correspondence

A future read adapter can reuse current LOAM correction machinery:

```text
buildCorrectionFrontierIndex(events, corrections)
  -> require index.admissible
  -> require stored subject Event is present
  -> index.terminalFrom(fuel, storedSubject)
```

The canonical interpretation row remains unchanged.

## Qualified conclusion

The interpretation experiment is ready for a first production implementation
slice with no unresolved semantic field questions.

Frozen first-slice meaning:

```text
note EventId
EventDescription text
subject EventId            // historical retained subject
recordedAt                 // required
attributedAt : optional    // no default

currentSubject             // derived, never persisted
```

## Explicitly deferred

- subjects other than Actual/Event identity;
- automatic AI extraction from conversation;
- mutable/current interpretation authority;
- confidence scores;
- causal or psychological inference;
- note correction/edit lifecycle;
- deletion;
- TUI diary prompts;
- real or complex-valued semantics.

After this observation, the next artifact should be an implementation checkpoint,
not another field-discovery experiment.
