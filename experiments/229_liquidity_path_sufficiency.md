# Observation 229 — What evidence is sufficient for a day-boundary liquidity path?

Status: **IN PROGRESS — selected bounded sufficiency / ambiguity probes**

Research baseline: LOAM `012150a70ad2940038e9db2f049c8578566a2119`

## Pressure

The provisional Report Lab has now graduated one real production report:

```text
Stock–Flow
  current accepted Actual evidence
  + explicit [start, end) coordinates
  -> reconstructed boundary change
```

The next Report Lab question is Liquidity:

> Starting from a current quantity, what future balance path and low-water point may LOAM safely show?

The current production TUI correctly refuses to invent a numeric path:

```text
Forecast path: UNKNOWN
Known low-water mark: UNKNOWN
```

because current-open Scheduled rows are retained evidence, not a complete description of all future household obligations.

However, the missing concept is **not** an unexplored generic `Coverage` abstraction.

Observation 211 already qualified a bounded Scheduled completeness claim:

```text
explicit occurrence                         -> Due
absent + inside complete-through scope       -> NotDue
absent + outside complete-through scope      -> Unknown
```

Observation 221 then qualified the smaller shared information law while explicitly rejecting a generic production Coverage ontology.

Therefore Observation 229 does not reopen those questions. It asks what remains after Scheduled completeness is hypothetically available.

## Prior boundaries held fixed

This observation reuses:

- Observation 108: overdue current-open Scheduled remains visible until lifecycle evidence closes it;
- Observation 119: open Scheduled + explicit BalanceView selection determines selected per-coordinate Scheduled effects, but BalanceView is not liquidity/backing authority;
- Observation 185: a derived liquid projection is not decision authority and does not make Scheduled equal later Actual;
- Observation 211: completeness may qualify bounded absence without earning recurrence;
- Observation 221: completeness is family-specific evidence and must not be replaced by visibility, admission, or a generic Coverage record.

The production `ScheduledBalanceInspection` already performs a useful but weaker calculation:

```text
current-open Scheduled
+ selected balance coordinates
+ end-exclusive horizon
-> aggregate signed selected effects
```

It deliberately does **not** combine those effects with current balances or call the result a forecast balance.

## Candidate decomposition under test

A day-boundary path needs at least these logically separate ingredients:

```text
current selected quantity
+ explicit report selection
+ dated current-open Scheduled effects
+ bounded Scheduled completeness qualification
+ a rule for unresolved overdue open evidence
-> qualified day-boundary Scheduled path
```

The hypothesis is that no new arithmetic ontology is required. Once the input is qualified, the path itself is only a prefix sum:

```text
B0 = current selected quantity
B(d+1) = B(d) + selected Scheduled flow on d+1
```

But three questions remain independent from the completeness result.

### 1. Which coordinates belong to the path?

`balance-view.tsv` is a replaceable query selection. It is not currently a canonical liquidity classification.

If two otherwise identical worlds choose different selected coordinates, an internal transfer or investment movement can change one projected path and not the other.

So Scheduled completeness cannot itself choose what `liquid` means.

A future production slice may therefore need either:

- an explicitly named report selection supplied as query/configuration; or
- separately earned liquidity/access evidence.

This observation does **not** choose between them.

### 2. Does same-day order matter?

For end-of-day boundaries, all effects on one date may be summed before applying the prefix recurrence. The order among those same-day movements should not change the day-end answer.

But intraday low-water is stronger.

With current quantity 7 and same-day movements:

```text
rent     -3
funding  +4
```

the end-of-day quantity is 8 either way, while the first intermediate quantity differs:

```text
rent first     -> 4 -> 8
funding first  -> 11 -> 8
```

Therefore:

```text
day-boundary low-water
    may be derivable without intraday order

intraday low-water
    requires stronger ordering evidence
```

The Report Lab should not accidentally promise the second when it only owns the first.

### 3. What happens to already-overdue open Scheduled evidence?

Observation 108 intentionally keeps overdue Scheduled evidence open until it is completed, cancelled, or replaced.

That is correct for obligation visibility, but a future path starts *now*.

An occurrence whose retained `scheduledOn` lies before today cannot simply be inserted into a future date without evidence. Two worlds can retain the same overdue open Scheduled item and the same complete-through horizon while the eventual future settlement happens on different later days.

So:

```text
Scheduled completeness
    !=
future timing of overdue unresolved evidence
```

A production liquidity path must either:

- refuse a fully dated path while selected overdue open effects remain unresolved;
- expose those effects separately as undated/overdue pressure; or
- consume separately qualified replacement/re-date evidence.

Observation 229 does not invent an automatic re-date policy.

## Bounded Alloy specimen

The model fixes one small household evidence set:

```text
current quantities
  Bank        5
  Wallet      2
  Investment  6

D1
  rent        Bank -3
  funding     Bank +4

D2
  transfer    Bank -2, Wallet +2

D3
  investment  Bank -2, Investment +2

Past
  overdue     Bank -2

completeThrough = D3
```

The worlds vary only report/query facts not supplied by that retained evidence:

```text
selection
same-day first movement
over-due future settlement day
```

The intended representative selected path uses `Bank + Wallet`:

```text
current  7
D1       8
D2       8
D3       6
```

The D2 transfer is neutral when both Bank and Wallet are selected. The D3 investment movement reduces the selected path because Investment is outside that selection.

## Selected probes

The Alloy model asks for four witnesses and four checks.

### Witnesses

1. `representativeSelectedPath`
   - the fixed Bank + Wallet day-boundary path exists with the expected values;

2. `sameEvidenceDifferentSelectionChangesPath`
   - identical retained evidence and completeness can yield a different day-boundary path when the report selection differs;

3. `sameDayNetDifferentIntradayOrder`
   - the D1 day-end balance is equal while the first intraday balance differs;

4. `sameCompleteEvidenceDifferentOverdueTiming`
   - identical complete Scheduled evidence and selection can still yield different near-term pressure paths when one overdue open item receives different future settlement timing.

### Checks

1. `FixedSelectionDeterminesDayBoundaryScheduledPath`
   - expected **UNSAT counterexample**;
   - with this fixed explicit Scheduled evidence, a fixed selection determines the day-boundary *Scheduled projection* regardless of same-day ordering or overdue hidden timing;

2. `CompletenessChoosesLiquiditySelection`
   - expected **SAT counterexample**;
   - completeness does not select the coordinates that count as liquid;

3. `DayBoundaryPathDeterminesIntradayFirstBalance`
   - expected **SAT counterexample**;
   - equal day-boundary path does not determine intraday first-step quantity;

4. `CompletenessDeterminesOverdueFutureTiming`
   - expected **SAT counterexample**;
   - Scheduled completeness does not date an already-overdue unresolved obligation into the future.

## Expected architectural result

If the selected matrix is confirmed, the narrow production direction becomes:

```text
shared current BalanceReview
+ replacement-aware current-open Scheduled read
+ explicit report coordinate selection
+ family-specific Scheduled complete-through evidence
+ no unresolved selected overdue timing ambiguity
        |
        v
pure day-bucket accumulation
        |
        v
prefix-sum balance path
        |
        v
minimum over day boundaries
```

This would justify a small analytical `LiquidityReview` or more conservatively named `SelectedBalancePathReview` without a second semantic engine.

The name `Liquidity` should remain provisional until the coordinate-selection semantics are earned. A replaceable explicit query selection may be enough for a useful report without creating a canonical `LiquidityRole`.

## What this observation does not earn

Observation 229 does not authorize:

- a generic `Coverage` concept or `coverage.loam`;
- recurrence, Series, Cadence, or generation policy;
- a canonical `LiquidityRole`;
- treating `balance-view` as net worth, backing, or universal liquidity;
- an automatic overdue re-date policy;
- intraday ordering that is not retained;
- a claim that Scheduled equals later Actual;
- a safe-to-spend quantity;
- a probability distribution or Monte Carlo forecast;
- persistence changes;
- a writer;
- a TUI numeric liquidity path before the evidence boundary is production-qualified.

## Relation to Report Lab

Stock–Flow has already crossed from Observation 225 into production in PR #543.

Liquidity remains a research question, but its blocker is now more precise than "we need completeness":

```text
completeness law             already qualified by Observation 211
information-order boundary   already qualified by Observation 221

remaining pressure
  selection semantics
  overdue future timing
  day-boundary vs intraday ordering
  practical maintainability of complete-through evidence
```

That is the terrain Observation 229 is intended to narrow.
