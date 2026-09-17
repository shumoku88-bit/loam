# Observation 268 — merchant coverage completeness

Status: **QUALIFIED — Alloy 6.2.0 / Sat4j**

Baseline:

```text
shumoku88-bit/loam
stacked on Observation 267 / PR #1013
```

## Trigger

Observation 266 qualified the narrow derivation:

```text
Merchant identity evidence
  + Event Effects
  + AccountingRole(expense)
  -> merchant-associated Expense quantity
```

Observation 267 then kept `Merchant` as the narrow relation vocabulary for the
commercial provider from whom the household regards an Event as acquiring goods
or services.

Production design pressure exposes one remaining information problem.

`Event -> lone Merchant` is intentionally partial. Observation 265 already
established that absence of identity evidence is unresolved, not evidence that no
such identity exists. Therefore this data:

```text
Event A -> Merchant Sanwa
Event B -> no Merchant evidence
```

does not justify the global household claim:

```text
all Sanwa Expense = Expense(Event A)
```

because Event B might also be a Sanwa Event whose Merchant evidence has not yet
been retained.

## Question

What additional evidence is required before an exact cross-Event merchant total
can claim classification completeness?

The observation compares:

```text
positive-only evidence
  Event -> lone Merchant
```

with observation-local explicit disposition:

```text
Event -> Merchant
or
Event -> explicitly non-Merchant-for-this-relation
```

`explicitly non-Merchant` is deliberately narrow. It does **not** mean:

- no external actor exists;
- no creditor exists;
- no payment recipient exists;
- no Party exists;
- the Event is an internal transfer.

It means only that the Event is explicitly outside the `EventMerchant` commercial
goods/services-provider relation tested by Observations 266–267.

## Observation-local model

The Alloy model separates retained evidence from one possible complete Merchant
interpretation:

```text
expense                 Event -> Int
retainedMerchant        Event -> lone Party
explicitlyNonMerchant   set Event
merchantInterpretation  Event -> lone Party
```

Retained Merchant evidence must be preserved by every interpretation, while an
explicitly non-Merchant Event cannot receive a Merchant in that interpretation.

Relevant Events are positive Expense-bearing Events in the bounded model.

Coverage is complete exactly when every relevant Event is either:

```text
assigned one retained Merchant
or
explicitly marked outside EventMerchant
```

## Qualification

Observed matrix:

```text
positiveOnlyEvidenceCanHideAnotherMerchantEvent        SAT
samePositiveEvidenceAllowsDifferentMerchantTotals      SAT
explicitNonMerchantCanCloseOneOtherwiseUnknownEvent    SAT

MerchantAbsenceMeansExplicitNonMerchant                 SAT counterexample
PositiveMerchantEvidenceDeterminesExactTotal            SAT counterexample
CompleteMerchantDispositionClosesExactTotal             UNSAT counterexample
SameCompleteMerchantEvidenceDeterminesExactTotal        UNSAT counterexample
```

The result qualifies the intended distinction:

```text
missing Merchant evidence
  != explicit non-Merchant evidence
```

and the completeness boundary:

```text
complete EventMerchant disposition
  + existing Effects
  + AccountingRole
  -> exact merchant total
```

## Production consequence

Do **not** persist a bare positive-only `EventId -> lone Merchant` map while
advertising natural-language exact totals such as:

```text
How much did I spend at Sanwa?
```

The smallest candidate production boundary becomes a partial disposition memory:

```text
EventMerchantEvidence
  merchant EventId ExternalPartyId
  nonmerchant EventId
```

with at most one disposition per Event.

During incremental classification, unmentioned Events remain unresolved. An exact
merchant query must surface incomplete coverage while any relevant Event in its
window remains unresolved.

No Merchant amount is retained. Amount remains derived from Event Effects and
AccountingRole after coverage closes.

This is not a reason to create a generic Party role enum or generic Event
participation table. The negative evidence is specific to the Merchant relation.

## Stop condition

Do not equate missing Merchant evidence with explicit non-Merchant evidence.

Do not generalize `nonmerchant` into `NoParty`, `Internal`, or another cross-domain
negative ontology.
