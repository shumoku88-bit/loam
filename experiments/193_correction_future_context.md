# Observation 193 — Correction as a real future context

## Question

Observation 192 showed with a synthetic `reveal` operation that current observational equivalence can be strictly weaker than future-context equivalence.

This observation asks whether the same distinction appears using already-existing LOAM semantics rather than a toy transition.

## Existing LOAM boundary used

The field trial reuses:

- `EventMemory` as retained Event evidence;
- `EventCorrectionMemory.add?` as raw Correction-fact retention;
- explicit `EventCorrection` identity / target / replacement endpoints;
- `Loam.Application.CorrectionFrontier` for fail-closed frontier admission;
- `quantityAtCorrectionFrontier?` as the effective quantity question.

No new production semantic primitive is introduced.

## Witness

Two synthetic Event worlds currently answer the selected wallet/JPY question identically:

```text
left:  target -100, replacement -80, buffer +180  => 0
right: target -120, replacement -80, buffer +200  => 0
```

Both begin with empty Correction memory.

The same explicit future relation is then appended in both worlds:

```text
correction-1: target -> replacement
```

The existing Correction frontier removes the target Event while retaining the replacement and untouched buffer Event:

```text
left effective answer  = 100
right effective answer = 120
```

Thus the worlds are equal under the current selected question but not under Observation 192 future-context equivalence.

## Why this is not merely additive change

The distinguishing transition does not mutate `EventMemory` at all. It adds relation evidence only.

The difference appears because explicit Correction authority changes which already-retained Event evidence belongs to the effective frontier.

So the observed shape is:

```text
retained evidence
+ future relation fact
+ effective-frontier observation
    -> stricter future-context quotient
```

not:

```text
new quantity Event
-> changed quantity
```

## Sufficiency pressure

Retaining only the current correction-effective wallet quantity is sufficient for the current one-question vocabulary.

It is not sufficient for future contexts containing Correction publication, because the two witness worlds encode to the same current summary but diverge after the same future relation.

## Boundary

This observation deliberately does not model:

- physical Correction writer publication order;
- partial publication / retry / crash behavior;
- branching Resolution;
- ActualValidity correction;
- routing or time;
- generation-manifest authority;
- a generic state-machine framework;
- a whole-LOAM transition algebra;
- a new mathematical theorem.

The result is one narrow bridge from Observation 192 into an existing production semantic boundary.