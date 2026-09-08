# Observation 229 — What evidence is sufficient for a day-boundary liquidity path?

Status: **QUALIFIED by Alloy 6.2.0 / SAT4J — day-boundary prefix arithmetic survives, but selection, intraday order, and overdue future timing remain independent evidence**

Research baseline: LOAM `012150a70ad2940038e9db2f049c8578566a2119`

Qualified model head: `3ac6c08d12901da36368b03ac6d66e8dbf2fd376`

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

The arithmetic hypothesis is deliberately tiny. Once the input is qualified, the path itself is only a prefix sum:

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

For end-of-day boundaries, all effects on one date may be summed before applying the prefix recurrence. The order among those same-day movements does not change the day-end answer in the selected model.

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
    can be derived without intraday order once other inputs are qualified

intraday low-water
    requires stronger ordering evidence
```

The Report Lab must not accidentally promise the second when it only owns the first.

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

A production path must either:

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
overdue future settlement day
```

The representative selected path uses `Bank + Wallet`:

```text
current  7
D1       8
D2       8
D3       6
```

The D2 transfer is neutral when both Bank and Wallet are selected. The D3 investment movement reduces the selected path because Investment is outside that selection.

## Executed result

Workflow run `34186644379`, job `101936221522`, completed **SUCCESS** after the initial parser-only correction from Lean-style comments to Alloy comments. No expected semantic result changed.

Alloy 6.2.0 + Sat4j produced exactly the selected matrix:

```text
representativeSelectedPath                         SAT
sameEvidenceDifferentSelectionChangesPath          SAT
sameDayNetDifferentIntradayOrder                   SAT
sameCompleteEvidenceDifferentOverdueTiming         SAT
FixedSelectionDeterminesDayBoundaryScheduledPath   UNSAT counterexample
CompletenessChoosesLiquiditySelection              SAT counterexample
DayBoundaryPathDeterminesIntradayFirstBalance      SAT counterexample
CompletenessDeterminesOverdueFutureTiming          SAT counterexample
```

For the `check` commands, SAT means Alloy found a counterexample to the asserted sufficiency claim.

## Finding

The selected bounded result separates one small arithmetic law from three evidence questions.

### Qualified arithmetic

Once the selected coordinates and dated Scheduled effects are fixed, same-day ordering does not change the selected **day-boundary** path in the model:

```text
current selected quantity
+ dated selected daily net effects
-> day-boundary prefix path
```

The path calculation itself therefore needs no new financial ontology. It is additive accumulation.

### Selection remains independent

The same complete Scheduled evidence yields a different path when the selected coordinate set changes. Therefore:

```text
Scheduled completeness
    -/->
liquidity selection
```

This blocks treating `balance-view` as canonical liquidity merely because it is already available to a report.

### Intraday minimum remains stronger

Two worlds can agree on the day-end path but disagree on the first same-day intermediate balance. Therefore:

```text
day-boundary path
    -/->
intraday low-water
```

A report may safely expose a minimum over qualified day boundaries without claiming an intraday minimum.

### Overdue future placement remains independent

The same complete Scheduled set and the same selected coordinates can disagree about which future day settles an already-overdue open item. Therefore:

```text
complete-through
    -/->
future re-date of overdue open Scheduled
```

Completeness answers whether absence inside a scope is meaningful. It does not invent future chronology for already-retained overdue evidence.

## Architectural consequence

The narrow candidate production topology is now:

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

This could justify a small analytical `SelectedBalancePathReview` without a second semantic engine.

The name `Liquidity` should remain provisional until the coordinate-selection semantics are earned. A replaceable explicit query selection may be sufficient for a useful path report without creating a canonical `LiquidityRole`.

The next practical pressure is **not more math**. It is whether a household can maintain a truthful bounded Scheduled complete-through claim and how a selected overdue open item should block or weaken the path answer.

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
prefix arithmetic            qualified here for day boundaries

remaining pressure
  selection semantics
  overdue future timing
  practical maintainability of complete-through evidence
```

This narrows the next Report Lab step without adding a production concept merely to make the screen numeric.
