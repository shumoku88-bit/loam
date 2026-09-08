# Provisional Report Lab

Status: **PROVISIONAL HOUSEHOLD REPORT FAMILY; RESEARCH-OWNED; NOT YET A PRODUCTION REPORT ENGINE**

This checkpoint promotes the useful part of Observation 225 from a paper-only comparison into a report family that may be grown against real household evidence while the TUI continues independently.

## Repository/data checkpoint

This report checkpoint is rebased onto LOAM main:

```text
5d3c136b6e9fe119e2d0e2d1ba9365eb4b03812a
feat(scheduled): cut to complete lifecycle authority (#533)
```

The household terminal comparison that motivated this checkpoint was first run against older pinned readers/data. The current canonical-data checkpoint at promotion time is:

```text
loam-data 11029ed7d3173d5f7443552bebfd74c8f9d7761c
data: cut Scheduled to complete lifecycle authority (#77)
```

Any future executable Report Lab must re-read the actual current remote/data state rather than treating those SHAs as permanent inputs.

## Provisional report family

The useful minimal family is now:

```text
CURRENT BALANCES
  question: what tracked quantity exists now?

STOCK–FLOW BRIDGE
  question: how did the tracked quantity change over the selected window?

ACCOUNTING VIEW
  question: what accounting-role effects correspond to that tracked change?

LIQUIDITY OUTLOOK
  question: what can safely be said about the future path from qualified evidence?

TECHNICAL DETAIL
  signed closure + daily closure matrix + evidence/parity checks
```

This ordering deliberately reads as:

```text
state -> change -> closure structure -> qualified future
```

The report family is provisional. It may shrink, merge, or change labels after repeated dogfood.

## Household evidence learned from the first real-data mock

The first household-informed terminal mock was useful enough to keep the family alive.

It showed, for its pinned 30-day window and balance-view selection:

```text
tracked balance total                    92,607 JPY
reconstructed window-start tracked value  9,577 JPY
net tracked change                       +83,030 JPY
```

The accounting-role projection closed the same period exactly:

```text
tracked balances   +83,030
income            -267,179
expense           +172,243
liability          +10,000
other asset            -94
unassigned          +2,000
--------------------------
total                    0
```

The useful lesson is not the particular amounts. It is that the balance, period change, and complete signed closure expose different information while agreeing mathematically.

The first household Liquidity Outlook also produced a useful refusal:

```text
retained Scheduled items exist
but no qualified known-through future horizon was available
therefore future balance path = UNKNOWN
therefore low-water mark = UNKNOWN
```

That refusal is part of the report result, not a report failure.

## Presentation rules earned by dogfood

### 1. Do not call a reconstruction an archived opening balance

Use wording such as:

```text
Reconstructed at window start
```

when the value is derived from current accepted evidence and occurrence dates.

Do not imply an as-recorded historical snapshot unless such evidence actually exists.

### 2. Avoid income/spending language for sign-only movement

For tracked-balance movement, prefer wording such as:

```text
Tracked increases across Events
Tracked decreases across Events
```

Do not call positive tracked movement `income` or negative tracked movement `spending` merely from sign.

Avoid the word `gross` when the calculation first nets within an Event and then groups Event net changes by sign.

### 3. Human view and signed closure may be two layers

A Simple View may show magnitudes for comprehension:

```text
Income-side effects
Expense-side effects
Liability-side effects
...
```

The Technical View must retain exact signs and show closure explicitly.

A compact teaching line is encouraged:

```text
Tracked change             +X
Counterpart roles combined -X
-----------------------------
Closed                       0
```

### 4. `tracked` is safer than `assets` or `net worth`

`balance-view` is a presentation selection. It is not automatically total assets, all holdings, or net worth.

### 5. Prototype liquidity classification must say that it is prototype policy

If the Report Lab selects, for example:

```text
cash + paypay + smbc + yucho
```

for a liquidity experiment, label it as a prototype/liquid-like selection.

The underlying balances are real; the liquidity classification is not yet a canonical LOAM role.

### 6. Known Scheduled items are not a complete future path

Never derive a numeric cumulative balance path beyond a qualified completeness horizon.

```text
known Scheduled items
!=
complete future cash-flow path
```

`UNKNOWN` is a legitimate report answer.

### 7. Keep the full matrix technical

The daily role matrix is useful as a microscope, not as the first household screen.

It should remain available for questions such as:

```text
How did this day close?
Why did tracked quantity jump on this date?
Does the period projection close as one system?
```

Do not invent pairwise source-to-destination edges from arbitrary multi-Effect Movements.

## Architectural boundary

Growing this report family does **not** require treating reporting as a dumb renderer.

A dedicated verified analytical layer is allowed if earned, with the boundary:

```text
canonical evidence
      -> shared Application readers
      -> typed Report Input
      -> pure/verified report calculations
      -> Report Answer
      -> terminal/TUI/export rendering
```

The report layer may contain real mathematics and reusable theorems.

It must not become a second canonical semantic engine.

In particular it must not:

- parse canonical persistence independently when a shared reader exists;
- reimplement Event correction/frontier semantics;
- reimplement Scheduled lifecycle/completeness semantics;
- infer missing future evidence as zero;
- invent AccountingRole from names/signs;
- write canonical evidence;
- infer pairwise transfer edges not retained by evidence.

## Candidate verified algebra

The current family gives practical pressure for a small mathematical layer around:

```text
finite signed coordinate vectors
finite sums
explicit projections
matrix accumulation
prefix sums / discrete integration
minimum / argmin within a qualified horizon
first threshold crossing when a threshold is explicitly supplied
```

High-value Lean laws to try first:

```text
project (sum movements) = sum (project movement)

matrix period totals = ordinary coordinate projection

closing = reconstructed-window-start + period delta

B(k+1) = B(k) + qualified-flow(k+1)

same qualified evidence through H
  -> same liquidity answer through H

missing completeness after H
  -/-> zero future flow
```

Do not add Mathlib or a general framework merely because these shapes are recognizable. First prove that the small reusable boundary actually reduces duplication or strengthens correctness.

## Repository ownership of the executable mock

The polished terminal prototype currently exists outside the repository in local scratch space (`/tmp/loam-report-mock/`). Its terminal behavior has been dogfooded, but its implementation is not yet repository-owned by this checkpoint.

That is intentional for this promotion step.

The next implementation slice should port only the useful calculation/rendering surface into repository ownership while preserving shared-reader semantics. Do not commit a raw-file-parser prototype merely to preserve the terminal appearance.

## Current decision

Observation 225 remains the research source.

This document records the practical decision:

```text
keep this small report family alive
use it as the provisional household report lab
grow it with repeated real-data dogfood
allow a verified analytical layer if mathematics earns it
keep canonical semantics outside the report calculator
keep TUI work independent until the report answers stabilize
```

The next question is not "which additional report can we add?"

It is:

> Which of these few views repeatedly changes how the household is understood, and which report calculations deserve to become small proved reusable laws?
