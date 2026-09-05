# Observation 185 — typed hypothetical relief without decision authority

Status: Lean observation from household decision-support pressure.

## Pressure

Current LOAM read-side capabilities can already answer useful baseline questions from retained evidence, including:

- current quantity / selected balance projections;
- Scheduled effects before an explicit horizon;
- Capacity / Consumption / Remaining over an explicit half-open window;
- same-width historical Consumption comparisons when the retained time evidence exists.

That is enough to detect pressure such as:

```text
one Purpose is consuming faster than before
one selected balance may be too low for known future obligations
one Capacity allocation is exhausted while cash still exists
```

But household advice asks a further class of question:

```text
what changes if I do X instead?
```

Representative X include:

- pause one Scheduled expense;
- reduce Consumption;
- reallocate Capacity;
- pause a future investment contribution;
- liquidate an already-held asset.

The question for this observation is not which option is best. It is whether LOAM can support those comparisons without turning a hypothetical into authority or collapsing every intervention to one scalar "money saved" number.

No private household amounts, identifiers, descriptions, or repository locations are copied into this public observation. The real household question supplies pressure only; the formal witness is synthetic.

## First distinction: shortage is not one scalar thing

Two practical shortages can look similar in ordinary conversation while being different queries:

```text
liquid shortage
    !=
selected-Purpose headroom shortage
```

A Capacity reallocation may repair a selected-Purpose headroom deficit while changing neither cash nor total wealth.

Conversely, pausing a future transfer may improve liquid quantity while leaving selected-Purpose headroom unchanged.

Therefore a decision-support projection needs to say *which axis changed*, not only how many JPY moved in one aggregate.

## Candidate observation-local projection

Observation 185 uses only three derived axes:

```text
selected liquid quantity
selected-Purpose headroom
total wealth
```

This is intentionally incomplete. It is enough to expose the structural distinction under test and is not proposed as a household state schema.

The hypothetical actions remain explicitly typed:

```text
SuppressScheduledExpense
ReduceConsumption
ReallocateCapacity
PauseFutureContribution
LiquidateExistingAsset
```

The projection then has the shape:

```text
canonical input
+ typed hypothetical list
-> derived projection
```

The result carries:

```text
canonical input unchanged
projected values
the exact typed hypothetical list
```

The hypothetical list is query provenance, not canonical household evidence.

## Lean result 1: the empty overlay is the baseline

`Loam/Observations/Observation185.lean` proves:

```text
query canonical []
    -> projected = canonical
```

So hypothetical support does not require a second default world. The baseline is just the ordinary projection with no overlay.

## Lean result 2: the query does not replace canonical input

The observation also proves:

```text
(query canonical scenario).canonical = canonical
```

and separately:

```text
(query canonical scenario).scenario = scenario
```

This is the narrow read-only boundary wanted for external clients:

```text
canonical evidence stays canonical
hypothetical intervention stays hypothetical
```

No simulation result receives household authority merely because it was computed by LOAM.

## Lean result 3: Capacity relief and cash relief are different

A closed witness starts with:

```text
liquid quantity:             1000
selected-Purpose headroom:   -500
wealth:                      5000
```

Applying a synthetic `ReallocateCapacity 500` yields:

```text
liquid quantity:             1000
selected-Purpose headroom:      0
wealth:                      5000
```

Lean checks that exact result.

Therefore:

```text
budget-allocation shortage
    -/->
liquid-cash shortage
```

A household assistant should not recommend finding more cash when the observed problem is only allocation headroom, nor claim that a reallocation created money.

## Lean result 4: equal liquid relief can have different wealth consequences

Another witness starts with a liquid shortfall and compares equal 1000-unit immediate relief from two actions:

```text
SuppressScheduledExpense 1000
PauseFutureContribution  1000
```

Both repair the same selected liquid shortfall in the bounded model.

But the first also avoids an expense, while the second leaves total wealth unchanged because it is modeled as pausing an internal future asset transfer.

Lean proves:

```text
same projected liquid quantity
and
different projected wealth
```

Therefore:

```text
same immediate cash relief
    !=
same household consequence
```

A single `savedAmount` field is not sufficient semantics for decision support.

## Lean result 5: even the same projection vector does not identify the action

The observation then compares:

```text
PauseFutureContribution 1000
LiquidateExistingAsset   1000
```

In the deliberately small three-axis projection, both produce the same result:

```text
same liquid delta
same selected-Purpose headroom delta
same wealth delta
```

Yet Lean also proves the typed interventions are unequal.

So:

```text
same derived projection
    -/->
same intervention meaning
```

This is the same kind of pressure LOAM has repeatedly encountered elsewhere: an aggregate answer may be sufficient for one question while losing provenance required by a later question.

For household advice, that provenance matters. Pausing a future contribution and selling an already-held asset may look identical to a narrow liquidity projection while exposing very different future choices and costs.

## Decision-support boundary

The observation supports this direction:

```text
canonical retained evidence
        |
        +--> baseline projection
        |
        +--> baseline + typed hypothetical A -> projection A
        |
        +--> baseline + typed hypothetical B -> projection B
        |
        +--> baseline + typed hypothetical C -> projection C
```

A client may then present questions such as:

```text
which candidate removes the observed shortfall?
which candidate changes only allocation and not cash?
which candidate preserves total wealth in this bounded projection?
which candidate requires touching an existing asset position?
```

That is decision **support**.

It is deliberately not:

```text
LOAM chooses the best candidate
```

because `best` requires a preference or objective that is not derivable from household arithmetic alone.

## What is not earned

Observation 185 does not earn:

- a canonical `Scenario` fact family;
- a canonical `Recommendation` or `Decision` object;
- a generic preference ordering;
- an optimizer;
- a universal utility / score function;
- one scalar `Savings` or `MoneySaved` meaning;
- `SafeToSpend` authority;
- automatic cancellation of Scheduled evidence;
- automatic Capacity reallocation;
- automatic contribution suspension;
- automatic asset liquidation;
- a claim that Scheduled will equal later Actual;
- a claim that `liquid + headroom + wealth` is a complete household model;
- a new persistent simulation store.

The hypothetical layer remains derived and disposable.

## Smallest practical follow-up

Do not implement a broad scenario engine yet.

The smallest earned follow-up is one concrete read-only overlay over an already-qualified Application projection, for example:

```text
baseline Scheduled/balance projection
+
one explicitly identified hypothetical Scheduled suppression
->
baseline and hypothetical answers side by side
```

That follow-up should retain the typed intervention provenance and make the no-write boundary mechanically visible.

Only after a second genuinely different intervention is required should LOAM ask whether a shared hypothetical representation is earned.

## Result

The pressure supports household-wide consultation, but with a precise division of responsibility:

```text
LOAM:
  retain facts
  project consequences
  keep intervention meanings distinct
  expose which constraints each candidate changes

person / explicit external preference:
  decide which consequence is acceptable
```

This is enough to make LOAM useful for questions about cutting spending, pausing subscriptions, changing contributions, reallocating Capacity, or touching invested assets without turning the accounting model into a hidden life optimizer.
