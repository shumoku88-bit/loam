# Observation 326 — split interpretation carrier is sufficient at the implementation boundary

Status: **QUALIFIED BOUNDED ALLOY OBSERVATION — IMPLEMENTATION BOUNDARY ONLY**

Baseline: stacked on qualified Observation 325.

## Trigger

Observations 320–325 have now frozen the current field discovery:

```text
interpretive text
subject -> household Fact
recordedAt
optional attributedAt
```

Observation 324 showed that one zero-effect Event + EventDescription + one time
coordinate cannot carry the whole meaning losslessly.

The smallest remaining implementation candidate is a split representation:

```text
existing/reused carrier:
  zero-effect Event identity
  EventDescription text

new explicit metadata:
  note EventId -> subject EventId
  recordedAt
  attributedAt : optional
```

This observation tests the boundary only. It adds no production Lean type.

## Admission obligations

A future implementation should admit the split image only when:

1. every metadata note identity resolves to a retained note Event;
2. every retained interpretation note has exactly one EventDescription;
3. every retained interpretation note has exactly one subject;
4. every subject resolves to a retained household Fact/Event;
5. every interpretation note has exactly one recordedAt;
6. attributedAt is optional;
7. when attributedAt exists, it is not later than recordedAt.

The Alloy carrier models those closure laws directly.

## Qualified matrix

GitHub Actions run `35893927917`, Alloy 6.2.0 / Sat4j:

```text
completeSingleInterpretationCarrierExists  SAT
unknownAttributionCarrierExists            SAT
rawOrphanSubjectExists                     SAT
rawOrphanNoteMetadataExists                SAT
rawMissingDescriptionExists                SAT

RepresentationIsFieldFaithful              UNSAT counterexample
AdmittedCarrierClosesSubjects              UNSAT counterexample
AdmittedCarrierClosesNoteMetadata          UNSAT counterexample
```

The three raw malformed runs are expected SAT because malformed representations
can be constructed; the important point is that `admitted` rejects them.

## Qualified-query coverage

The split representation contains exactly the information needed by the
previous observations:

- Observation 321: select notes by subject;
- Observation 322: select notes known/recorded by cutoff;
- Observation 323: select notes explicitly attributed by cutoff;
- Observation 325: distinguish absent attributedAt from explicit times.

No mutable current-interpretation field is required.

## Production-shape hypothesis

If this boundary qualifies, the first production slice should remain narrow.

Candidate metadata only:

```text
structure InterpretationEvidence (Time : Type) where
  note : EventId
  subject : EventId
  recordedAt : Time
  attributedAt : Option Time
```

Important: this is a design sketch, not yet production code.

The text remains in EventDescription. Note identity remains an EventId. The
metadata does not repeat the text.

## Do not reuse the wrong semantics

- do not use ActualValidity for recordedAt;
- do not use EventCorrection for changing interpretations;
- do not use RelationUnit as a generic subject edge;
- do not derive attributedAt from prose;
- do not default missing attributedAt;
- do not make Attention lifecycle the interpretation lifecycle.

## Remaining question before implementation

One important semantic pressure remains:

> What happens when the **subject household Event is corrected/replaced**?

The retained subject reference is provenance. A current-view query may need to
project that subject through EventCorrection, but the stored interpretation
should not silently rewrite its historical subject.

That correction correspondence should be qualified before production code.
