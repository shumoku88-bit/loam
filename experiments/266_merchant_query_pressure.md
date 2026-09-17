# Observation 266 — exact merchant-query pressure

Status: **QUALIFIED by Alloy 6.2.0 / Sat4j**

Baseline:

```text
shumoku88-bit/loam
main observed before branch: 36343a9dbf1b584c44e2f92e7f427da3be9cec4e
stacked on Observation 265 branch head: c3e5dd508ddabf266cfb79448e00dda39080509d
```

Exact qualified branch head before this documentation commit:

```text
b2c8fcae648aad7635ab3b4dce693c5b4fa3b6d7
```

GitHub Actions qualification:

```text
workflow: Observation 266
run:      35175780009
job:      105057052276
result:   SUCCESS
solver:   Alloy 6.2.0 / Sat4j
warnings: none
```

Observed matrix:

```text
splitExpenseOneMerchantNeedsNoStoredMerchantAmount     SAT
counterpartyCanExistWithoutMerchant                    SAT
merchantCanMatchCounterpartyForSimplePurchase          SAT
merchantEvidenceCanExistWithUnresolvedRole             SAT
multiMerchantEffectPressureEscapesEventLoneMerchant    SAT

PhysicalRoleAndMerchantDetermineMerchantExpense        UNSAT counterexample
PhysicalAndMerchantDetermineMerchantExpense            SAT counterexample
PhysicalAndRoleDetermineMerchantExpense                SAT counterexample
SelectedCounterpartyDeterminesMerchantExpense          SAT counterexample
MerchantEvidenceImpliesQueryReady                      SAT counterexample
LoneEventMerchantCannotExactlyPartitionTwoSellers      UNSAT counterexample
```

## Trigger

Observations 263–265 established:

```text
shared external identity can span semantic uses

Party identity
  != obligation identity
  != creditor role
  != direct payment-recipient relation
  != Locus
  != EventDescription
```

Observation 265 then identified the first practical pressure ordering as a stable
cross-Event merchant identity query.

The concrete household question is intentionally narrow:

```text
How much Expense-role quantity is associated with the same merchant identity
across current Events in a requested Measure/window?
```

Colloquially:

```text
How much did I spend at Sanwa?
How much did I spend at Seven-Eleven?
```

This observation asks what *minimum independent evidence* is required to answer
that query exactly without recreating the O264 generic `Who` collapse.

## Existing production evidence

LOAM already owns the quantity and accounting sides separately.

`TransactionsFlowReview` keeps current Event columns and derives exact signed
Event/Locus/Measure incidence quantities from Effects. It deliberately gives
those quantities no income/expense meaning.

`AccountingRole` is an explicit partial relation:

```text
LocusId -> lone AccountingRole
```

with `expense` as one currently earned role. Absence is unresolved evidence, not
an `UnknownRole`, zero, or irrelevance.

`RoleFlowReview` composes those two boundaries and deliberately retains each
unresolved Effect so cancellation cannot hide classification incompleteness.

Therefore an exact merchant-expense answer must not store another merchant
amount. It should derive quantity from existing Effects and explicit role evidence.

## Real household pressure

The canonical data already contains shapes that distinguish the question:

```text
repeated merchant recognizer
  DESC 三和

single merchant, split Expense Effects
  DESC セブンイレブン
  tobacco + food

merchant embedded in richer human text
  DESC グランベリーモールモンベルコアスパンウォッシュアウトパーカ

self transfer
  DESC smbc→paypay

non-merchant expense / obligation language
  DESC 家賃
  DESC 健康保険料...
```

Observation 265 already qualified that Description cannot be identity authority.
The Seven-Eleven row adds another pressure: one merchant Event may contain more
than one Expense Effect, so repeating merchant identity on every Effect would be
redundant under the current single-merchant shape.

## Observation-local candidate

O266 introduces only this candidate relation:

```text
merchant : Event -> lone ExternalIdentity
```

The Alloy carrier is named `Party`, but this is not a generic Party bag. The
relation itself has merchant meaning.

Its semantics are deliberately partial:

```text
present Merchant fact
  = this Event has one retained merchant identity at this boundary

absent Merchant fact
  != no external actor exists
  != internal Event
  != no creditor
  != no payment recipient
```

The candidate therefore does not make `Merchant` synonymous with `Counterparty`.

## Qualified derived query

For one World `w`, Party `p`, and Measure `m`:

```text
merchantExpense(w, p, m)
  = sum Event e where merchant(e) = p
      sum Effect coordinate c in e
        quantity(e,c)
        only when AccountingRole(c.locus) = Expense
        and c.measure = m
```

This is a **signed Expense-role quantity** query.

It is not:

```text
direct amount sent to p
cash paid to p
creditor discharge amount
settlement amount
```

Those remain different semantic questions from Observation 264.

## Classification completeness

Because `AccountingRole` is partial, a mathematical sum that simply ignores
unclassified Loci is not yet an exact household answer.

O266 therefore defines:

```text
merchantQueryReady(w,p,m)
```

which requires every nonzero Effect in Measure `m` belonging to an Event selected
for merchant `p` to have explicit AccountingRole evidence.

The qualified counterexample to `MerchantEvidenceImpliesQueryReady` confirms that
Merchant identity alone cannot justify silently dropping an unresolved Effect.
The exact query must fail closed or surface unresolved evidence.

## Qualified findings

### 1. Event scope is sufficient for the current single-merchant purchase shape

`splitExpenseOneMerchantNeedsNoStoredMerchantAmount = SAT`.

One Event-level merchant identity can cover multiple Expense Effects, such as food
plus tobacco, while the merchant amount remains a deterministic projection of the
existing Effects. No second amount authority is earned.

### 2. Merchant is narrower than selected counterparty

Both of these are satisfiable:

```text
counterpartyCanExistWithoutMerchant
merchantCanMatchCounterpartyForSimplePurchase
```

So a simple purchase may use the same external identity in both relations, while a
non-merchant expense may still have a meaningful counterparty. Agreement does not
earn equivalence.

### 3. Merchant and AccountingRole are independently necessary

The positive authority theorem has no counterexample:

```text
Physical + AccountingRole + Merchant
  -> merchant Expense answer
```

But removing either independent relation produces a counterexample:

```text
Physical + Merchant
  != enough

Physical + AccountingRole
  != enough
```

This is the central O266 result. Merchant owns the cross-Event identity selection;
AccountingRole owns the Expense classification; Event Effects own quantity.

### 4. Selected counterparty cannot substitute for Merchant

`SelectedCounterpartyDeterminesMerchantExpense` has a counterexample.

This preserves O264 at the query layer. A convenient broad counterparty projection
must not silently become merchant authority merely because it agrees on common
retail purchases.

### 5. Current minimum has an explicit future break point

The future negative-control predicate is satisfiable:

```text
one Event
  Effect A -> Seller A
  Effect B -> Seller B
```

and `LoneEventMerchantCannotExactlyPartitionTwoSellers` has no counterexample.
Therefore an Event-scoped lone Merchant relation cannot exactly partition genuine
two-seller Effect attribution.

This does not earn Effect-level merchant evidence today. It records the condition
under which the current minimum must be revisited.

## Qualified information boundary

The bounded result establishes:

```text
Merchant identity evidence
  + existing Event Effects
  + explicit AccountingRole evidence
  -> exact signed merchant Expense quantity
```

while rejecting these compressions:

```text
Merchant amount stored independently
Merchant = selected counterparty
Merchant = creditor
Merchant = payment recipient
Description = Merchant identity
Merchant identity alone = monetary answer
```

For the current household single-merchant purchase shape, Event scope is smaller
than Effect scope because one Event-level identity can cover several Expense
Effects.

## Production implication

O266 earns the *shape* of a first query-specific relation more strongly than a
generic `EventParty`:

```text
EventMerchant
  EventId -> lone shared external identity
```

with three caveats:

1. the exact production vocabulary (`Merchant`, `Vendor`, etc.) still requires a
   naming/coverage review;
2. absence remains partial/unresolved evidence, not a claim about reality;
3. multi-merchant Event attribution is intentionally outside the admitted shape.

No separate merchant amount, merchant-role enum, generic Party registry, or
Effect-level merchant relation is earned by Observation 266 alone.

## AI boundary

AI may propose:

```text
DESC "グランベリーモールモンベル..."
  -> candidate merchant identity: Montbell
```

but Observation 265 remains in force:

```text
AI interpretation != retained Merchant evidence
```

Once retained, however, the amount itself should be derived deterministically
from Event Effects + AccountingRole rather than estimated by AI.

## Stop condition

Do not generalize from this first merchant query to a generic participation model.

Observation 266 qualifies the semantic shape, not production persistence. The
next decision is whether the household wants this exact merchant aggregation as a
production capability and, before admission, whether `Merchant` is the correct
vocabulary across retail, subscriptions, service providers, marketplaces, rent,
and public payments.
