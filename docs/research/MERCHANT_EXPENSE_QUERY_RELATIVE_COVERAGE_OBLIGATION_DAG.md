# Merchant Expense — query-relative coverage obligation scaffold

Status: **CURRENT PRODUCTION BOUNDARY / focused D/P/R audit**

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

## Durable external-party boundary inherited from Observations 263–265

The detailed prose for Observations 263–265 has graduated to Git history. Their
three Alloy models remain live independent witnesses.

Those observations earned the identity and interpretation boundary on which the
later Merchant relation depends:

- `ExternalPartyId` is shared role-free outside-actor identity;
- debtor / creditor meaning belongs to each OpenRelation, not to the identity;
- Merchant meaning belongs to EventMerchant, not to the identity;
- external Party identity and Locus identity are orthogonal;
- an OpenRelation endpoint does not determine an Event Merchant;
- one Event may involve several semantically relevant outside actors, so one
  Event-scoped Merchant is a query-specific relation rather than a universal
  participation ontology;
- creditor, direct payment recipient, commercial provider, and other outside
  roles may differ and must not be collapsed merely because they sometimes name
  the same actor;
- EventDescription remains human recognition evidence, not stable Party
  identity authority;
- equal descriptions need not imply equal Parties, one Party may appear under
  different descriptions, and description presence need not imply any external
  Party at all;
- AI/text parsing may propose an external identity, but proposal/inference is not
  retained semantic authority.

Production now reflects those boundaries directly through:

- `Loam/Core/ExternalParty.lean`;
- `RelationEndpoint.external : ExternalPartyId`;
- `Loam/Core/EventMerchantEvidence.lean`;
- explicit EventMerchant publication/admission.

The Event-scoped lone Merchant relation is therefore deliberately narrow. If a
future query needs creditor, direct recipient, multi-seller attribution, or a
broader participation graph, that meaning must be earned as a separate relation
rather than being smuggled into `ExternalPartyId` or EventDescription.

The Observation 263–265 Alloy models stay live because they independently
falsify the tempting collapses between identity, Locus, relation role,
Event-party granularity, and description text.

## Durable Merchant boundary inherited from Observations 266–269

The earlier Merchant sequence earned the production relation now carried by:

- `Loam/Core/EventMerchantEvidence.lean`;
- `Loam/EventMerchantPublisher.lean`;
- normalized Actual Merchant rows/admission;
- `Loam/MerchantExpenseReview.lean`;
- focused publisher, persistence, review, and TUI tests.

The retained meaning is intentionally narrow:

```text
EventMerchant
  EventId -> lone ExternalPartyId

meaning:
  the retained external commercial provider from whom the household regards
  this Event as acquiring goods or services
```

`ExternalPartyId` is shared role-free identity. Merchant meaning belongs to
the EventMerchant relation, not to the identity token itself.

Merchant therefore does **not** mean generic counterparty, payee/direct payment
recipient, creditor, payment processor/acquirer, account provider/Locus, or legal
merchant-of-record unless that is explicitly the identity the household chooses
to retain.

The current Event-scoped lone Merchant is the earned minimum for the ordinary
single-provider Event shape. It has an explicit future break point: if one Event
must be partitioned exactly across two genuine sellers/providers at Effect
granularity, the current relation is insufficient and a finer relation must be
earned then. That possibility does not justify Effect-level Merchant evidence
today.

Missing Merchant evidence remains unresolved. Explicit `nonmerchant` means only
that the Event is outside this commercial-provider relation; it does not mean no
external actor, no creditor, no recipient, or internal transfer.

The live Observation 266 and 268 Alloy models remain independent falsification
witnesses for the query boundary and completeness distinction. Their detailed
historical prose, Observation 267 terminology review, and Observation 269
promotion checkpoint have graduated to Git history because current production
code plus this durable audit now own the practical conclusions.

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
