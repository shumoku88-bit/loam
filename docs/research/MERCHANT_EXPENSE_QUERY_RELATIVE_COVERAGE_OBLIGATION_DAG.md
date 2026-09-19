# Merchant Expense — query-relative coverage obligation scaffold

Status: **focused D/P/R audit — over-conservative refusal reduced**

Date: 2026-09-19

Baseline:

```text
deda4a21772c48ebd8e693e918ce00797a2d563c
fix(pta-export): reject aliased authority targets (#1083)
```

Method: `docs/OBLIGATION_SCAFFOLD_METHOD.md`

## Root question

Does the production Merchant Expense query require exactly the evidence needed
for one Merchant / Measure / window answer, or does it import unrelated
classification uncertainty into that answer?

## D / deterministic

The following remain mechanically determined:

- current Event selection and dates come from the existing Actual/TransactionsFlow
  projection;
- retained Merchant disposition is Event-scoped and remains partial;
- a Merchant amount is never stored;
- one known target-Merchant Event contributes only the signed quantities of
  Effects in the requested Measure whose Loci have explicit `expense`
  AccountingRole;
- known other-Merchant and explicit `nonmerchant` Events cannot contribute to
  the target Merchant;
- an Event with no nonzero Effect in the requested Measure cannot change the
  answer;
- an Event whose requested-Measure Effects all have explicit non-Expense roles
  cannot change the Merchant Expense answer regardless of its Merchant identity.

## P / previously earned

This audit does not reopen:

- EventMerchant identity and the merchant/nonmerchant/unresolved distinction
  qualified by Observations 266–269;
- normalized Actual Merchant referential closure;
- correction-aware current Event selection;
- AccountingRole authority;
- signed refund/reversal contribution semantics;
- the rule that missing AccountingRole on a known target Merchant remains an
  independent exactness blocker.

Correction does not inherit Merchant evidence automatically. A corrected
replacement Event may therefore become unresolved until explicitly classified.
That remains a policy consequence of Event-scoped evidence, not a gap addressed
here.

## R / residual

### R1 — production over-refusal

Before this audit, `merchantCoverageGaps` treated every unclassified Event in
the selected window as an exactness blocker:

```text
unclassified Event in window
    -> Merchant coverage gap
```

This was stronger than the query semantics require.

Counterexample:

```text
query Measure = points

window contains:
  Event A: only JPY Effects
  Merchant disposition: unresolved

there are no points Effects anywhere
```

The exact Merchant Expense total in `points` is deterministically zero. Event A
cannot change that answer, yet the previous implementation returned incomplete
solely because Event A lacked Merchant classification.

The same pressure appears for a JPY self-transfer whose JPY Loci are explicitly
classified as non-Expense roles. Merchant identity is irrelevant to that query,
but the previous implementation still required it.

This is not an unsafe acceptance bug. It is unnecessary uncertainty propagation.

## Minimal repair

Merchant coverage is now query-relative.

An unclassified Event blocks exactness only when it contains a nonzero Effect in
the requested Measure whose AccountingRole is either:

```text
expense
or
unresolved
```

Known non-Expense roles prove that Effect cannot contribute. No Effect in the
requested Measure also proves irrelevance.

The conservative unresolved case remains:

```text
Merchant unresolved
+
requested-Measure Effect role unresolved
    -> still a coverage gap
```

so the change never infers `nonmerchant`, never invents a role, and never hides
a possible target-Merchant Expense contribution.

## Regression witnesses

The focused Merchant Expense test now retains:

1. an unresolved JPY Event with Expense pressure, which must still block;
2. an unresolved JPY self-transfer with only explicit Asset roles, which must not
   block;
3. a `points` query over a window whose unresolved Merchant Events have no
   points Effects, which must expose exact zero without unrelated Merchant
   classification.

## D/P/R result

```text
D
├─ measure filtering
├─ explicit AccountingRole
├─ known Merchant selection
└─ signed contribution derivation

P
├─ EventMerchant semantics
├─ Actual current frontier
├─ AccountingRole authority
└─ refund/reversal signed semantics

R
└─ all-window Merchant completeness was too strong
      -> narrowed to Events that could affect this query
```

## Stop point

Do not use this change to:

- infer Merchant identity from AccountingRole;
- infer `nonmerchant` from a non-Expense Event;
- inherit Merchant automatically across Correction;
- weaken role completeness on known target-Merchant Effects;
- introduce Effect-level Merchant attribution;
- generalize Merchant into a Party-role framework.

The change removes only classification obligations that are provably irrelevant
to the exact query being asked.
