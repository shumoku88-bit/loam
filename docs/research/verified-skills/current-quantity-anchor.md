# Skill: CurrentQuantityAnchor change audit

Status: **Trialed**

## Trigger

Use this skill when a change touches the construction, publication, persistence,
reading, correction interaction, or semantic interpretation of
`CurrentQuantityAnchor` or a directly adjacent retained-quantity authority.

Do not use it for a presentation-only change that consumes an unchanged qualified
answer.

## Protected answer

The current quantity answer must remain backed by the intended retained evidence.
A convenient current value must not silently become a second authority, and
unknown / incomplete origin evidence must not be collapsed into zero.

Relevant long-horizon review points are Semantic Blueprint B1, B4, B5, and B6.

## Procedure

1. **Name the exact answer that changes.**
   State the Locus / Measure quantity question and whether this is a read,
   publication, correction, persistence, or migration change.

2. **Find the narrow current owner.**
   Use repository search, the Evidence Atlas, existing observations, and the
   current publisher / reader boundary before reasoning from type names.

3. **Trace retained evidence to current image.**
   Identify which retained Events, Corrections, anchors, coverage evidence, or
   configuration are independently authoritative and which values are derived.

4. **Trace one or two semantic neighbors.**
   Check the nearest correction / lifecycle frontier and the nearest
   persistence / recovery or downstream projection boundary that can change the
   answer.

5. **Try the falsifiers below before adding machinery.**

6. **Qualify the concrete seam only.**
   Choose the smallest test, Lean obligation, audit, or migration check that
   demonstrates the actual boundary. A passing build alone is insufficient.

7. **Review for new authority.**
   Ask whether the change stored a value that was previously reconstructable,
   invented a default, bypassed correction, or let a projection write back.

## Falsifiers

Try to construct at least the relevant cases:

- identical displayed current quantity, different retained provenance;
- missing origin evidence versus explicit zero;
- correction after the evidence used to derive a current quantity;
- stale retained anchor versus a newer qualified current frontier;
- same numeric quantity under a different Measure / scale assumption;
- recovery or publication failure that leaves one sibling authority newer than
  another.

A falsifier is useful only when it matches the changed path.

## Qualification evidence

A successful use should leave evidence that:

- the named household answer is unchanged or intentionally changed;
- no second quantity authority was introduced accidentally;
- unknown remains distinguishable from justified zero where required;
- correction / recovery semantics still reach the current answer;
- any representation change has an explicit migration or reconstruction path.

## Stop / retire conditions

Stop using this skill when inspection shows the change is presentation-local and
cannot affect retained quantity meaning.

Retire or rewrite the skill if repository ownership changes enough that these
steps route agents to obsolete files or duplicate a stronger current instrument.

## Trial evidence

Trial 03 is the first paired measurement for this skill:

- [Presence-only support to exact current quantity](trials/03-presence-to-exact-anchor.md)
- paired result: **BETTER**;
- promotion wins: **1**;
- semantic regressions: **0**;
- skill mutation: **none**.

The improvement was one avoided material ownership/topology backtrack, not a
different final semantic answer.

Trial 04 attempted a held-out sibling measurement, but the skill-arm session had
prior inherited exposure to the baseline's decisive result. That pair is recorded
as **UNSCORED** and contributes **0** promotion wins. Its source audit remains
exploratory evidence only.

Trial 05 is the first clean held-out sibling measurement for this skill:

- [Partial re-observation from a legacy v1 anchor](trials/05-v1-partial-reobservation.md)
- paired result: **SAME**;
- promotion wins from Trial 05: **0**;
- semantic regressions: **0**;
- skill mutation: **none**.

Both arms independently preserved the unobserved coordinate's older reflected-root
cut, derived the same current quantities, and selected the same focused executable
regression as the smallest missing direct qualification.

Trial 06 is the final planned paired measurement for this skill:

- [Bounded history versus same stored scalar](trials/06-bounded-history-same-stored-scalar.md)
- paired result: **SAME**;
- promotion wins from Trial 06: **0**;
- semantic regressions: **0**;
- skill mutation: **none**.

Both clean arms independently compared the fresh observation with the
correction-aware current answer rather than the old stored scalar and selected
the same focused executable regression as the smallest missing direct
qualification.

Final counted status:

- scored comparable paired trials: **3** (Trial 03, Trial 05, Trial 06);
- clean held-out sibling trials: **2** (Trial 05, Trial 06);
- promotion wins: **1**;
- scored semantic regressions: **0**;
- skill mutation: **none**.

The skill remains **Trialed**. Its evaluation is **closed** because the promotion
rule requires at least two material improvements and only one was observed.

No further promotion trials are planned. Reopen only if repository ownership
changes materially, a new concrete failure exposes a reusable missing step, or a
substantially different evaluation protocol creates a new question worth
measuring.
