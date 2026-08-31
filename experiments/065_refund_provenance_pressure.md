# Observation 065 — Does a reversing quantity preserve refund provenance?

## Question

Observations 039–041 established that explanation relations can carry information that a flattened current view does not preserve. Observation 020 separately established append-only Correction as a relation that changes effective interpretation while retaining the original observation in provenance.

The current household source introduces a more specific pressure: later Events can numerically offset an earlier expense-like Event because money is refunded or reimbursed.

The public experiment copies **none** of the private descriptions, dates, quantities, account identities, transaction identities, or counterparties. It keeps only the anonymized structural pressure:

- an expense-like Event occurs;
- a later return-like Event moves quantity in the opposite direction;
- more than one earlier expense can have indistinguishable selected coordinates;
- future questions may ask which earlier Event the return belongs to.

The question is:

> If Event records and net quantity are already retained, can refund provenance be reconstructed, or must the correspondence between the return Event and its source Event survive independently?

A second boundary question follows:

> Is a refund semantically equivalent to a Correction that supersedes the earlier expense in an effective view?

## Why Alloy

The first pressure is structural:

- keep the same Event identities and fields;
- keep the same net quantity;
- vary only refund linkage;
- observe whether source/refund answers change.

The Correction comparison is also a bounded relational comparison between two projections. No transition order is needed, so TLA+ and SPIN would add machinery without a new answer. Lean should wait unless a practical law is earned.

## Anonymous vocabulary

```text
Expense Event identity
  + Time
  + signed Quantity delta

Return Event identity
  + Time
  + signed Quantity delta

refundOf : Return -> lone Expense
```

The `Expense` and `Return` labels are experiment-local specimen classes. Observation 065 does not restore nominal EventKind as a Practical Core primitive.

Every World sees the same Event records. Only `refundOf` may vary.

The model intentionally does **not** require the return quantity to equal the source expense quantity. The provenance question exists independently of whether an offset is full or partial.

## Selected answers

From explicit refund linkage the model derives:

- which earlier expenses have a linked refund;
- which return Events are explicitly refund-linked;
- which source Event a return belongs to.

Separately, the model computes net quantity from Event deltas alone.

It also defines a deliberately wrong comparison projection:

```text
correctionStyleVisibleExpenses
  = occurred expenses - refund targets
```

This imitates treating refund linkage like a Correction whose target disappears from an effective frontier.

## Probes

### 1. Can a return distinguish between two otherwise matching source expenses?

Require two identity-distinct expense Events with the same selected time and quantity, plus one opposite-signed return. Link the return to one source in `Left` and the other in `Right`.

Expected: **SAT**.

### 2. Can identical Event records yield different refund provenance?

Expected: **SAT**.

### 3. Can identical net quantity coexist with different refund provenance?

Expected: **SAT**.

This is the key distinction between numerical offset and explanatory linkage.

### 4. Can exact source-coordinate matching remain ambiguous?

Expected: **SAT**.

Stable Event identity should preserve a distinction that matching time / quantity / broad shape cannot recover.

### 5. Can the same return Event be refund-linked in one world and unlinked in another while its physical record stays identical?

Expected: **SAT**.

### 6. Do Event records determine refund provenance?

Expected check result: **SAT counterexample**.

### 7. Does net quantity determine refund provenance?

Expected check result: **SAT counterexample**.

### 8. Once explicit refund linkage is fixed, are selected refund answers fixed?

Expected check result: **UNSAT counterexample**.

### 9. Can refund linkage be substituted for Correction-style supersession without losing the answer "did the original expense occur?"

Expected check result: **SAT counterexample**.

The original expense remains a historical occurrence even when later quantity returns. A Correction-style effective projection that removes the source therefore answers a different question.

## Observed Alloy result

Alloy 6.2.0 + Sat4j returned:

```text
representativeRefundPressure                              SAT
sameRecordsDifferentRefundProvenance                      SAT
sameNetDifferentRefundProvenance                          SAT
exactSourceCandidatesAmbiguous                            SAT
sameReturnCanBeRefundOrUnlinked                           SAT
EventRecordsDetermineRefundProvenance                     SAT counterexample
NetQuantityDeterminesRefundProvenance                     SAT counterexample
ExplicitRefundRelationDeterminesSelectedAnswers           UNSAT counterexample
RefundCanUseCorrectionProjectionWithoutLosingOccurrence   SAT counterexample
```

Observation 065 run #3 completed SUCCESS after the shape scope was made explicit. The earlier failed runs were model plumbing errors, not semantic counterexamples.

## Finding

The bounded separation is:

```text
opposite-signed Event
    +
net quantity

        does not determine

refund provenance
```

and:

```text
refund / reimbursement
    !=
Correction
```

A refund may offset the quantitative effect of an earlier Event without saying that the earlier Event was mistaken, replaced, or did not occur.

The same Event records can therefore support distinct refund explanations while every quantitative fact remains unchanged. Even matching source coordinates do not recover which identity was refunded.

Treating the refund edge as if it were a Correction edge also loses a selected answer: the source expense remains an occurrence, whereas a Correction-style effective projection removes the target from the current effective set.

This extends the general explanation result of Observation 039 with a household-shaped semantic boundary, and it pressure-tests the practical Correction concept without changing it.

## Important boundaries

Observation 065 does **not** establish:

- a Practical Core `Refund` type;
- that every opposite-signed Event is a refund;
- that every return links to exactly one source generally;
- rules for allocating one return quantity across one or more source Events;
- one expense receiving several refunds;
- one return reimbursing several source Events;
- refund lifecycle, dispute, chargeback, or settlement semantics;
- correction of refund linkage;
- stable identity for the linkage itself;
- persistence layout;
- tax treatment or accounting recognition rules;
- that experiment-local `Expense` / `Return` classes belong in neutral Event ontology.

If real records later require many-to-many reimbursement or lifecycle behavior, that should be a separate pressure rather than silently widened here.
