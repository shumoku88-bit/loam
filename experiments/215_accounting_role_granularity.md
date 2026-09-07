# Observation 215 — AccountingRole granularity under legacy mixed-use pressure

Status: **PROBE — migration/runtime boundary / RESEARCH_ONLY**

## Trigger

Observation 214 showed that a one-to-one Locus re-key can preserve selected accounting reports when AccountingRole is transported explicitly, while many-to-one merging is a separate semantic decision.

The complete household migration inventory in `loam-data` then exposed a sharper case. The sealed historical source contains at least one entry described as `smbc→現金` whose positive posting was stored at `expenses:予備`. Other records at the same source coordinate behave like ordinary expense-shaped activity.

That means a legacy source Account/Locus name may have bundled more than one household meaning.

The question is therefore not merely:

```text
Locus spelling vs AccountingRole
```

but:

> If one legacy Locus is semantically mixed, must production AccountingRole live at Effect granularity forever, or can a destructive migration split the old evidence into clean new Loci and keep a simpler post-migration `Locus -> AccountingRole` relation?

Canonical household data may be rewritten if the rewrite is qualified, so migration-time repair is a real candidate rather than a theoretical escape hatch.

## Prior evidence

Observation 049 established that physical placement does not determine accounting role.
Observation 062 showed representative bookkeeping shapes can be recognized from signed Effects plus AccountingRole without restoring conventional Account identity.
Observation 110 separated derived debit/credit closure from accounting explanation.
Observation 214 qualified one-to-one Locus re-key plus role transport, but deliberately did not establish that every real Locus has one permanent role.

Observation 215 targets only that remaining granularity question.

## Observation-local specimen

The model uses two legacy coordinates.

### Stable legacy coordinate

Two Effects at one legacy Locus are both intended to be Expense-classified.
This represents the ordinary case where one stable role may be enough.

### Mixed legacy coordinate

Two Effects share one legacy Locus but require different selected accounting interpretations:

```text
Effect A -> Asset
Effect B -> Expense
```

This abstracts the concrete migration pressure without copying private descriptions or quantities into the public model.

The relation `intendedRole` is observation scaffolding representing the selected household accounting answer we want a migration candidate to preserve. It is not proposed as canonical production evidence.

## Candidate representations

### A. Permanent role on the legacy Locus

```text
LegacyLocus -> one AccountingRole
```

For a role-homogeneous coordinate this should work.
For the mixed coordinate it should fail because one value cannot equal two different intended roles.

### B. Effect-relative role

```text
Effect -> AccountingRole
```

This is expected to preserve the whole specimen. The important question is whether it is **necessary**, not merely sufficient.

### C. Migration-time Effect split followed by stable new-Locus role

```text
legacy Effect
    -> migration-selected new Locus

new Locus
    -> one AccountingRole
```

The mixed source Effects may be sent to two distinct new Loci, while role-homogeneous source evidence can still use an ordinary one-Locus re-key.

If this succeeds, mixed legacy data does not by itself force a permanent runtime `Effect -> AccountingRole` relation.

## Expected matrix

```text
stableLegacyPermanentRoleWorks                    SAT
mixedLegacyPermanentRoleWorks                     UNSAT
effectRelativeRoleCanPreserveWholeSpecimen        SAT
oneTargetLegacyRekeyCanRepairMixedSpecimen         UNSAT
effectSplitMigrationCanRepairWholeSpecimen        SAT
stableLegacyRekeyWorks                             SAT
SplitTargetsPlusNewRolesDetermineClassification   UNSAT counterexample
MixedLegacyForcesMixedNewLocus                     SAT counterexample
```

The first UNSAT is the pressure result: a genuinely mixed legacy coordinate cannot be faithfully represented by one permanent role on that same identity.

The second UNSAT distinguishes ordinary re-keying from splitting: mapping the mixed legacy Locus as a whole to one new Locus does not repair the semantic bundle.

The split witness is the conservative escape: migration can translate retained Effects separately into clean new coordinates, after which new-Locus role is sufficient for the selected bounded answer.

## Interpretation if qualified

The intended boundary is:

```text
role-homogeneous Locus
    -> Locus-level AccountingRole may be sufficient

mixed legacy Locus
    -> one old-Locus role is too coarse

but

mixed legacy Locus
    does NOT by itself imply
permanent Effect-level AccountingRole in production

because

migration-time Effect split
+ clean new Locus identities
+ new-Locus AccountingRole
    may preserve the selected answer
```

This keeps two different questions separate:

```text
What granularity did the dirty imported/source vocabulary use?
What granularity should clean LOAM production evidence use after migration?
```

The former need not dictate the latter.

## Production implications if the matrix survives

Before production AccountingRole persistence is designed, the migration inventory's `SPLIT_OR_RECLASSIFY` rows should be reviewed at Event + description level.

For each mixed source coordinate, classify retained Effects into candidate clean identities. Only after that review can LOAM test whether every resulting production Locus is role-homogeneous enough for a small Locus-level relation.

This also suggests that a canonical cutover tool, if eventually built, may need a finer migration map than Observation 214's:

```text
OldLocus -> NewLocus
```

For mixed coordinates it may need an explicit, finite, reviewed mapping such as:

```text
EffectKey -> NewLocus
```

as **migration scaffolding only**. That mapping need not survive as ordinary runtime authority after the new canonical generation is published, provided provenance and reference closure are retained safely.

## Deliberate boundaries

Even a successful Observation 215 does **not** establish:

- production `Locus -> AccountingRole` persistence;
- production `Effect -> AccountingRole` persistence;
- a permanent five-role taxonomy;
- that every mixed legacy row can be repaired from description text alone;
- that descriptions are authority rather than review evidence;
- the final mapping for `expenses:予備`, refunds, reimbursements, communication, or subscriptions;
- role history or effective-date semantics;
- recognition-time/accrual policy;
- that a source Account must become exactly one LOAM Locus;
- that a migration split may change Event/Effect identity without a separately qualified identity/provenance rule.

## Next gate

If migration-time splitting survives, review the concrete `SPLIT_OR_RECLASSIFY` rows from `loam-data` and ask:

> After a reviewed split, are the resulting candidate Loci role-homogeneous across the retained household history?

Only then is it sensible to choose production AccountingRole persistence and proceed toward canonical vocabulary cutover.
