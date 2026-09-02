# Observation 109: Can Scheduled and Attention share lifecycle shape without sharing lifecycle meaning?

## Question

The whole-household evidence graph leaves `Attention` / Issue as the largest practical HRA / h-kernel capability not yet structurally observed in LOAM.

At first glance it resembles Scheduled evidence:

```text
Scheduled
  stable identity
  future-oriented coordinate
  relation to later evidence
  eventually no longer open

Attention
  stable identity
  optional due meaning
  relation to Plan / Movement / later Attention
  eventually no longer open
```

That similarity creates an attractive compression pressure:

> Can Attention simply reuse the Scheduled lifecycle relation shape from Observation 105?

Current h-kernel reality pressure says this question is dangerous. An Issue relation such as `IssueRealizedAs Actual` or `IssueContinuedAs Issue` is append-only provenance, but recording that relation does **not** close the Issue by itself. Issue lifecycle is independent. h-kernel also distinguishes `Resolved` from `Dropped`, and distinguishes `NoDueDate` from `DueUndetermined`.

Observation 109 therefore tests structural reuse while actively seeking counterexamples to semantic collapse.

## Candidate shared structure

The model deliberately gives Scheduled and Attention the same relation record shape:

```text
RelationEvidence
  source
  target?
  knownOn
```

Source kind constrains the admissible target shape:

```text
Scheduled -> Movement    possible
Scheduled -> Scheduled   possible
Scheduled -> none        possible

Attention -> Movement    possible
Attention -> Attention   possible
```

For Scheduled, a visible relation is interpreted as terminal lifecycle evidence, following the pressure already explored by Observation 105.

For Attention, relation provenance is deliberately **not** lifecycle closure. Attention closure is separate:

```text
AttentionClosureEvidence
  attention
  knownOn
  kind = Resolved | Dropped
```

Attention due meaning is also separate:

```text
DueOn day
NoDueDate
DueUndetermined
```

## Executed result

Alloy 6.2.0 / Sat4j executed the exact PR #242 model on head `9dd591b0b86a76462c0475ac847923dbf8f06065`.

All representative witnesses were SAT:

```text
representativeSharedShape                    SAT
sameAttentionRelationsDifferentLifecycle     SAT
sameClosedAttentionDifferentDisposition      SAT
sameOptionalDueDateDifferentMeaning          SAT
attentionRelationToMovementDoesNotClose      SAT
attentionContinuationDoesNotClose            SAT
```

The deliberately over-compressed checks all had SAT counterexamples:

```text
GenericTargetRelationClosesAttention         SAT counterexample
AttentionRelationsDetermineLifecycle         SAT counterexample
ClosedAttentionDeterminesDisposition         SAT counterexample
OptionalDueDateDeterminesDueMeaning          SAT counterexample
```

The candidate positive boundaries had no counterexample:

```text
ExplicitAttentionClosureAndDueDetermineAttentionView UNSAT counterexample
ScheduledRelationTargetIsTerminal                    UNSAT counterexample
```

The GitHub Actions qualification required both Alloy execution and the explicit expected-result checker to succeed. Both completed successfully.

## Finding

The shared source-target-time record shape does **not** imply one shared lifecycle semantics.

Within this bounded vocabulary:

```text
shared relation mechanics
  source / target / known-through
      can be reused structurally

Scheduled relation
      may be terminal lifecycle evidence

Attention relation
      is provenance and does not itself close Attention
```

The SAT witnesses make the distinction concrete. An Attention item can relate to a Movement and remain open. It can also continue as a later Attention identity while the earlier item remains open. Therefore relation endpoint shape alone cannot decide Attention closure.

Attention also retains two independently visible distinctions that generic optional summaries erase:

```text
closed
  does not determine
Resolved vs Dropped

Maybe Day
  does not determine
NoDueDate vs DueUndetermined
```

Explicit Attention closure evidence together with explicit due meaning was sufficient for the selected bounded Attention lifecycle/due view.

The resulting compression boundary is:

```text
shared structural helper for
  source / target / known-through relation evidence
        yes, within the selected mechanics

one universal target-decoded lifecycle algebra
        no

Attention relation provenance
        independent from Attention closure

Attention closed boolean only
        too small

Attention optional due date only
        too small
```

This repeats the pattern from Observations 106 and 107: implementation mechanics can be shared without erasing semantic partitions that change household answers.

## Why this matters for compactness

A syntactically tiny design such as:

```text
Thing
  target?
  date?
  closed?
```

is too small in the information-theoretic sense used by these observations. It identifies worlds that the admitted household UI must distinguish.

The stronger compact design is instead:

```text
shared identity / relation / temporal machinery

Scheduled semantic rules
Attention semantic rules
```

Compactness comes from removing duplicated mechanics, not from merging independently observable meanings.

## Important boundaries

Observation 109 does not establish:

- a Practical Core Attention or Issue type;
- text/details storage;
- amount semantics for Attention;
- Plan-oriented relations such as `planned-as` / `planning-withdrawn`;
- funding provenance;
- whether continuation should normally close the earlier Attention item in a future LOAM UI;
- edit/correction identity for Attention;
- recurrence or notification behavior;
- generic relation persistence;
- whether the names `Resolved` and `Dropped` are final LOAM vocabulary.

It asks only what information must remain distinct for the selected lifecycle, relation, and due questions.

## Next step

Observation 109 closes the last large semantic-plane comparison in the current whole-household compression pass.

The next step is not another feature-shaped observation by default. It is to place Observations 105–109 back onto the whole-household evidence graph and ask:

> What is the smallest independently observable vocabulary now justified, which mechanics can be shared beneath it, and which familiar HRA / h-kernel nouns remain projections rather than canonical facts?

Only after that reduction should practical Lean ownership and persistence boundaries be chosen.
