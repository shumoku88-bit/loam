# Observation 240 — semantic activation point

Status: **QUALIFIED by the Selected Lean Observations umbrella on PR #692**

Research baseline: LOAM `9d11b5413bc353d1e596aa7e839ee281cd28e613`

## Question

Several current production publishers retain auxiliary evidence before publishing
the artifact that makes that evidence semantically live. Is that repetition only
an implementation habit, or is there one smaller publication law underneath it?

The candidate law is:

```text
required dependent evidence
        ↓
activation anchor last
```

A crash may occur after any publication step. Once the anchor is visible, every
piece of evidence required by its meaning must already be visible.

## Current production pressure

The pattern appears in distinct semantic families without making those families
the same thing:

- `CapacityPublisher`: effective evidence is published before the Capacity
  movement whose presence makes it effective.
- `ScheduledTerminalPublisher`: completion relation is published before the
  Actual Event endpoint becomes selected Movement authority.
- `ActualReversalPublisher`: reversal relation is published before the inverse
  Event becomes selected Movement authority.
- `CorrectionPublisher`: correction relation is published before the replacement
  Event becomes selected Movement authority.

These remain separate publishers and separate authorities. Observation 240 does
not propose a generic publisher framework.

## Distinction from Observation 055

Observation 055 studied referential closure: a relation that names an Event cannot
be considered closed before its Event endpoint exists. That can require
`Event -> relation` publication.

Observation 240 studies activation closure: some already-retained evidence remains
inert until a later anchor makes it semantically live. That requires
`dependent evidence -> activation anchor` publication.

The directions differ because the dependency questions differ. There is no single
universal physical order for every LOAM artifact.

## Lean model

`Loam.Observations.Observation240` deliberately forgets storage formats and
publisher names.

Each artifact has a publication rank:

```text
rank : Artifact -> Nat
```

A crash cut exposes exactly artifacts whose rank is before the cut.

For one anchor and a finite list of required evidence, semantic closure means:

```text
anchor visible -> every required evidence visible
```

The observation proves two statements.

1. **Activation-last is sufficient for every crash prefix.**
   If every required evidence item ranks before the anchor, any prefix that can
   see the anchor can already see all required evidence.
2. **Anchor-before-evidence has a concrete crash counterexample.**
   If the anchor ranks before one required evidence item, the cut immediately
   after the anchor exposes live meaning without that evidence.

The first theorem is polymorphic in artifact type and independent of the number of
required evidence items, so no one-to-four dependency bound is needed.

## Qualification

PR #692 ran the existing `Selected Lean Observations` workflow. The selected live
observation umbrella compiled Observation 240 successfully. No dedicated workflow
or new formal runtime was added.

## Boundary

This observation does **not** prove mechanically that every current production
publisher follows the law. The code correspondence above remains a review fact.
It also does not prove atomic filesystem behavior, retry convergence, lock-order
acyclicity, or cross-process fairness.

Those are separate questions. In particular, lock ordering should be tested as a
separate small model rather than folded into this law.

## Decision

Keep the semantic families separate. Reuse the law, not necessarily the code.

The durable design rule becomes:

> When publication of an anchor activates previously inert dependent evidence,
> publish all required evidence before the anchor so every crash prefix remains
> semantically closed.

A generic Publisher abstraction is not earned by this observation.
