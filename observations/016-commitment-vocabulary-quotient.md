# Observation 016 — Commitment Vocabulary Quotients

## Question

Is `committed : set Unit` essential retained state, or is it one coordinate system for the distinctions exposed by a chosen operation vocabulary?

Observation 015 showed that committed Unit identity is sufficient for the current named reassignment and release vocabulary, while the commitment Purpose coordinate can be recovered from current physical placement.

Observation 016 asks a different question:

> if the future vocabulary becomes coarser or finer, how much of committed membership must remain distinguishable?

The experiment deliberately does not search for another clever encoding. It first asks which committed-membership states the vocabulary itself can distinguish.

## Fixed finite universe

There are four Units and two Purposes.

```text
P0: U0 U1
P1: U2 U3
```

Physical placement is fixed. The only varying information is which subset of the four Units is committed, giving all 16 possible committed-membership states.

Three vocabularies are compared.

### Total vocabulary

It can ask only for total movable capacity.

It cannot ask where that capacity is or which Unit is movable.

A sufficient summary is therefore the total number of committed Units.

### Purpose vocabulary

It can ask for movable capacity separately for each Purpose.

It still cannot name a Unit.

A sufficient summary is the pair:

```text
(committed in P0, committed in P1)
```

### Named vocabulary

It can ask whether a particular Unit may be reassigned to another Purpose.

This vocabulary can distinguish committed identity directly.

## Executed Alloy result

Alloy 6.2.0 with Sat4j produced:

```text
sameTotalDifferentPurposeProfile                   SAT
samePurposeProfileDifferentIdentity                 SAT
TotalCountDeterminesTotalMovable                    UNSAT
TotalCountDeterminesPurposeAnonymousPermission      SAT
PurposeProfileDeterminesPurposeAnonymousPermission  UNSAT
PurposeProfileDeterminesNamedPermission              SAT
MembershipDeterminesNamedPermission                  UNSAT
NamedPermissionDeterminesMembership                  UNSAT
```

The SAT checks are counterexamples to the corresponding determinability claims.

The first witness shows that two states can have the same total committed count while distributing those commitments differently between P0 and P1. Therefore total count is enough for total capacity but not for Purpose-local capacity.

The second witness preserves the per-Purpose commitment profile while changing committed Unit identity. Alloy exposes a named permission difference involving U0 and P1. Therefore the Purpose profile is sufficient for anonymous Purpose-local capacity but not for a vocabulary that can name U0.

With fixed physical placement, equal committed membership gives equal named reassignment permission, and equal named reassignment permission recovers equal committed membership in this model.

## Executed J result

J enumerated all 16 committed-membership states and projected them through the three vocabularies.

```text
                     quotient classes

total count                   5
Purpose counts                9
Unit identity                16
```

The sorted collision-class sizes were:

```text
total count:
1 1 4 4 6

Purpose counts:
1 1 1 1 2 2 2 2 4

Unit identity:
1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
```

The refinements are strict:

```text
16 membership states
        |
        v
9 Purpose-profile classes
        |
        v
5 total-count classes
```

The direction is information loss. Each coarser vocabulary merges states that the finer vocabulary can distinguish.

## Finding

`committed : set Unit` is not a canonical form of commitment state.

It is an identity-bearing coordinate system that is sufficient for the current named operation vocabulary.

If the vocabulary asks only about total capacity, five equivalence classes are enough in this four-Unit universe. If it asks about capacity per Purpose, nine classes are needed. Only when the vocabulary can name Units do all sixteen membership distinctions remain visible.

A concise reading is:

> Identity becomes retained state when the vocabulary is allowed to name it.

This sharpens Observation 005 and Observation 008 in the commitment setting. The state boundary is induced by observable distinctions; a representation such as `set Unit` is one way to coordinatize those distinctions, not the distinctions themselves.

## Why J mattered here

Alloy established the collisions and non-collisions between neighboring vocabularies.

J exposed the complete quotient geometry of the finite universe at once: 5, 9, and 16 observable classes.

This does not imply that J should be the final implementation language. It does show that J is particularly natural for asking how much state survives a projection or vocabulary change.

## Boundary of the claim

This is a deliberately small universe:

- four Units;
- two Purposes with two Units each;
- fixed physical placement;
- three hand-chosen operation vocabularies;
- only current reassignment permission is compared;
- no temporal preservation claim is made here.

The observation does not prove that these are the vocabularies a household system should expose, that `set Unit` is globally minimal for every identity-sensitive vocabulary, or that identity can always be discarded from aggregate household semantics.

TLA+ is not used because no claim is made about preservation through transitions. Lean is not used because Observation 008 already provides the general sufficiency/recoverability law; Observation 016 is a concrete application that discovers which distinctions the chosen vocabularies expose.

## Consequence for the implementation-language question

The final implementation language should not be chosen from the current representation alone.

If the eventual household vocabulary remains mostly aggregate or Purpose-local, much identity-bearing state may disappear and an array-oriented representation becomes more plausible.

If the household vocabulary must routinely name persistent Units and make permission decisions about them, a language that naturally represents identity and typed relations becomes more attractive.

The language decision therefore depends partly on a prior semantic decision:

> what must the household vocabulary be able to ask and do?

## Next pressure point

Instead of immediately compressing the state again, ask which vocabulary a household system actually needs.

Can useful household operations avoid naming resource Units while still preserving the distinctions required for commitment, reassignment, and explanation?

If yes, identity may be an observational tool rather than a production primitive. If no, Observation 016 explains why identity survives into the implementation boundary.
