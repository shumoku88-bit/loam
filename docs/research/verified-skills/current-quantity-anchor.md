# Skill: CurrentQuantityAnchor change audit

Status: **Candidate**

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
