# Observation 374 — settlement commitment correction targeting

Status: **BOUNDED SEMANTIC OBSERVATION — identity/version representation under test; no production change selected**

Baseline:

```text
#1434  Observation 373 — plain untyped cancel collapse falsified
main   c3cf3f00af225080b8a9be62a8fc802b822c295b
```

## Trigger

Observation 373 established that commitment lifecycle cannot collapse to one
untyped terminal `cancel`.

It left two residual questions:

1. the smallest representation for correction/retraction versus real-world
   extinguishment;
2. whether commitment correction needs a separate logical commitment identity
   and version identity.

This observation isolates the second question first because representation
choices for correction depend on how existing settlement evidence keeps its
target.

Production currently has:

```text
SettlementCommitmentId
SettlementCommitment

SettlementEffectCorrespondence.target : SettlementCommitmentId
SettlementNettingMember.target        : SettlementCommitmentId
```

Correspondence/member rows already have independent version-capable identities,
but commitment rows do not.

## Competing target strategies

### Candidate A — exact row binding

A dependent row keeps pointing to exactly the retained commitment row it named.

After:

```text
C1 -> C2
```

a correspondence targeting `C1` remains historical evidence for `C1` only.

This is mechanically simple, but may lose valid attribution after an ordinary
commitment typo correction.

### Candidate B — blind replacement following

A dependent row targeting `C1` automatically follows the commitment replacement
chain to current `C2`.

This preserves attribution, but may silently reinterpret old settlement evidence
after a correction changes:

- settlement Measure;
- debtor/creditor direction;
- quantity below already-attributed settlement.

### Candidate C — frontier following plus current re-admission

A retained dependent row keeps its original target identity.

Read/admission resolves:

```text
historical target
-> commitment replacement frontier
-> one current descendant
-> re-run all dependent semantic checks against that current commitment
```

This candidate stores no additional logical commitment identity.

The replacement lineage itself supplies continuity.

## Bounded model

The Alloy model uses:

```text
Commitment
  quantity
  measure
  direction

CommitmentRevision
  target
  replacement

CommitmentRetraction
  target

SettlementUse
  historical target
  quantity
  measure
  direction
```

`SettlementUse` is a small stand-in for the compatibility pressures already
present in production correspondence/member admission.

It is not a proposed new production type.

## Witness 1 — compatible correction preserves historical target

```text
C1  quantity 10, Measure A, debit-like
 |
 revision
 v
C2  quantity 7, Measure A, debit-like

existing settlement use:
  target C1
  quantity 3
```

Exact-row projection sees:

```text
C2 outstanding = 7
```

because the use still names C1.

Frontier-following plus re-admission sees:

```text
C2 outstanding = 4
```

without rewriting the settlement row.

Expected: **SAT**.

This is pressure against exact version binding as the read semantics.

## Witness 2 — multi-version lineage

```text
C1 -> C2 -> C3

settlement use still targets C1
```

If the lineage is linear and current admission succeeds, `C1` can resolve to
current `C3` without a separately stored logical commitment ID.

Expected: **SAT**.

This does not prove a logical ID can never become useful.

It tests whether one is forced by the currently qualified correction capability.

## Witness 3 — Measure-changing correction

```text
C1  Measure A
 |
 revision
 v
C2  Measure B

old settlement use targets C1 / Measure A
```

Blind following would carry the quantity into C2.

Qualified following must reject the candidate because current settlement
semantics no longer agree.

Expected: **SAT witness with admission failure**.

## Witness 4 — direction-changing correction

The same rule applies when the corrected debtor/creditor direction changes.

An old physical/direct settlement cannot silently flip semantic direction merely
because commitment lineage was followed.

Expected: **SAT witness with admission failure**.

## Witness 5 — correction below already settled quantity

```text
C1 quantity 10
settled 3
C1 -> C2 quantity 2
```

Current candidate must fail rather than publish:

```text
outstanding = -1
```

Expected: **SAT witness with admission failure**.

## Witness 6 — retraction with dependent current evidence

```text
C1
settlement use -> C1
retract C1
```

The historical target resolves to no current commitment.

Current settlement evidence may not silently survive the retraction.

The atomic candidate must either also correct/retract the dependent evidence or
fail closed.

Expected: **SAT witness with admission failure**.

## Assertions under test

### ExactTargetingAlwaysPreservesCompatibleAttribution

Expected: **SAT counterexample**.

Exact row identity loses dependent attribution across a compatible correction.

### BlindReplacementFollowingIsAlwaysSafe

Expected: **SAT counterexample**.

Replacement lineage alone is not semantic authority.

### QualifiedFollowNeverProducesNegativeOutstanding

Expected: **UNSAT counterexample**.

Whole-image re-admission plus conservation prevents negative outstanding.

### QualifiedFollowClosesCurrentTargets

Expected: **UNSAT counterexample**.

Every admitted dependent row resolves to exactly one current target and is
compatible with it.

## Provisional interpretation if the matrix holds

The bounded capability would not yet force:

```text
LogicalSettlementCommitmentId
SettlementCommitmentVersionId
```

A smaller representation may suffice:

```text
SettlementCommitmentId
  retained version-row identity

SettlementCommitmentRevision
  old id -> replacement id

SettlementCommitmentRetraction
  target id

dependent settlement rows
  keep their originally recorded target id

Application admission
  resolve target through current commitment frontier
  then revalidate against current commitment
```

This preserves three useful properties simultaneously:

```text
append-only provenance
no fan-out rewrite after a typo
fail-closed reinterpretation
```

The old target is never mutated.

The dependent row is never silently retargeted in storage.

Only the current semantic projection follows the correction lineage.

## What this observation does not decide

It does not yet select the concrete production correction/retraction row shape.

It also does not decide whether future workflows may eventually require a
separately named logical obligation identity for reasons beyond correction, for
example:

- external protocol identifiers;
- legal obligation identity;
- explicit contract lifecycle grouping;
- user-visible stable references independent of correction lineage.

Those pressures are not present in the current Settlement capability and should
not be preemptively promoted.

## Next question if qualified

If Candidate C survives, the remaining design question from Observation 373
becomes narrower:

> Can commitment correction and explicit retraction share one family-specific
> revision authority while non-settlement extinguishment remains a separate
> quantity-bearing real-world authority?

That should be tested before production code or TUI editing is added.

## Stop condition

If the expected matrix holds:

1. reject exact-row-only target semantics;
2. reject blind replacement following;
3. retain frontier-follow + whole-image re-admission as the smallest current
   candidate;
4. do not add a separate logical/version identity pair yet;
5. move to the minimum correction/retraction/extinguishment representation
   question.
