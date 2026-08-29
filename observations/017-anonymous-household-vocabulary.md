# Observation 017 — Anonymous Household Vocabulary

## Question

Can useful household operations avoid naming resource Units while still preserving the distinctions needed for commitment, release, reassignment, and availability?

Observation 016 established a static boundary. In a four-Unit, two-Purpose universe, per-Purpose counts preserve fewer distinctions than named Unit permission.

Observation 017 asks the temporal version:

> if two concrete worlds have the same anonymous household projection but different Unit identities, can they continue to evolve indistinguishably under repeated anonymous household operations?

This is a behavior question, so TLA+ is the only new instrument used.

## Concrete worlds

There are four Units and two Purposes.

```text
P0: U0 U1
P1: U2 U3
```

The two worlds begin with identical placement and identical committed counts per Purpose, but different committed identities.

```text
left committed:  U0 U2
right committed: U1 U3
```

Therefore both worlds initially expose the same anonymous projection:

```text
Purpose -> (total Units, committed Units)
```

while a vocabulary that can name U0 can already distinguish them.

## Anonymous household vocabulary

The experiment deliberately gives operations only Purpose names, never Unit names.

```text
commit(Purpose)
release(Purpose)
reassign(SourcePurpose, TargetPurpose)
```

Each concrete world still contains persistent Unit identity internally. An anonymous operation nondeterministically chooses an eligible concrete Unit.

The paired TLA+ transition allows the left and right worlds to choose different concrete Units for the same anonymous operation.

The observation checks two properties over all reachable paired states:

1. the anonymous projection remains equal;
2. commit, release, and reassign enabledness remains equal for every Purpose parameter.

Because the concrete choices on the two sides are independent, preservation must hold for every paired choice of eligible identities, not only for one hand-selected correspondence.

## Executed positive result

TLC 2.19 from TLA+ tools 1.7.4 completed exhaustive breadth-first model checking with no invariant violation.

```text
1 initial state
24,577 states generated
2,716 distinct states found
0 states left on queue
complete state graph depth: 11
```

The checked invariants were:

```text
TypeOK
SameAnonymousProjection
AnonymousEnabledAgreement
```

So, in this finite model, two identity-distinct concrete worlds that share the anonymous projection remain behaviorally indistinguishable to this operation vocabulary through every reachable matched sequence of commit, release, and reassignment.

This is stronger than the static result of Observation 016. The coarser state is not merely enough to answer a report query at one instant; it is closed under the chosen transition vocabulary.

## Executed negative result

A second TLC run adds no new transition. It only asks whether named reassignment permission agrees:

```text
reassign(Unit, TargetPurpose)
```

TLC rejects the invariant in the initial state itself:

```text
Invariant NamedPermissionAgreement is violated by the initial state

leftCommitted  = {U0, U2}
rightCommitted = {U1, U3}
```

The physical placement and anonymous counts are identical, but U0 is committed on the left and movable on the right.

Identity therefore becomes observable exactly when the vocabulary is allowed to name it.

## Finding

For this household vocabulary, persistent resource Unit identity is not required at the observable state boundary.

A concise reading is:

> Anonymous household operations can remain closed over anonymous household state.

The important qualification is **for this vocabulary**.

Observation 016 showed that vocabulary determines the state quotient statically. Observation 017 shows that the same quotient can also be stable under repeated operations when those operations respect the quotient.

This moves the aggregate / Purpose-local representation closer to a plausible production semantics rather than a report-only projection.

## Why TLA+ mattered here

Alloy or J could enumerate current-state collisions again, but that was already known from Observation 016.

The new question was whether the distinction survives transition sequences. TLA+ directly explored the reachable behavior graph and checked that anonymous enabledness and projection equality were preserved at every reachable state.

No Alloy, J, Lean, or miniKanren was added because none was needed to answer this behavior question.

## Consequence for the implementation-language question

This result weakens one argument for an identity-heavy production core.

If the eventual household vocabulary remains close to:

```text
how much is available for Purpose P?
commit some capacity to Purpose P
release some committed capacity from P
move some movable capacity from P to Q
```

then a production representation may not need persistent resource Unit identity at all.

That makes array- and quantity-oriented implementations more plausible than they looked after Observation 015.

It does not yet select J, Haskell, Ada/SPARK, Lean, or another implementation language. It changes the semantic terrain on which that decision should be made.

## Boundary of the claim

The model is deliberately small and anonymous:

- four indivisible Units;
- two Purposes;
- no magnitude beyond repeated one-Unit actions;
- no provenance or explanation history;
- no undo or reversal of a particular past event;
- no due dates or temporal commitments;
- no concurrent actors;
- no operation that names a resource Unit;
- no claim that every useful household operation belongs to this vocabulary.

In particular, household explanation may reintroduce identity through a different route. A user may not care which abstract money Unit moved, yet may care which commitment event, purchase, plan, or source caused a restriction.

That would be **event/provenance identity**, not necessarily resource Unit identity.

## Next pressure point

Ask whether explanation requires resource identity or only provenance identity.

Can the household system answer questions such as:

```text
why is only this much available?
what commitment is consuming this capacity?
what changed this amount?
undo that commitment
```

while keeping resource Units anonymous and naming only events or reasons?

If yes, the emerging production ontology may contain Purpose, quantity, time, and provenance without persistent money-like Units.
