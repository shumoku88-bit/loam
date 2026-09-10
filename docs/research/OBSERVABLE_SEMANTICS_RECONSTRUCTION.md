# Observable semantics reconstruction

Status: **working answer-first reconstruction; no production or loam-data mutation authorized**

Baseline: `f79c4a474932da5ce9fd6e4192ebb18062dd6b6c`  
Tracking: #693

## Question

Do not start from current files or fact-family names. Start from:

> Which answers should LOAM give, and what is the least retained information that determines each answer without guessing?

```text
desired answers
  -> semantic prerequisites
  -> reusable derived answers
  -> minimal retained distinctions
  -> write / safety obligations
  -> physical topology
```

Minimality is vocabulary-relative. Separate:

```text
Q_read   read/report/administration answers
Q_write  admitted writes and visible refusals
Q_safe   crash/recovery/corruption/concurrency obligations
```

This checkpoint starts with `Q_read`.

## Current answer map

| Desired answer | Current owner | Retained semantic inputs | Non-canonical query/config input | Derived, not retained |
| --- | --- | --- | --- | --- |
| What actually happened? | `ActualReview` | Event, ActualValidity, EventDescription, EventCorrection | selection/filter | review Record, current frontier |
| What is still scheduled / due? | `ScheduledReview` | ScheduledOccurrence, Completion, Retirement, Replacement, Event closure | query date | current-open list, day status |
| What is the current selected balance? | `BalanceReview` | Event, EventCorrection, ZeroOriginCoverage | balance coordinate selection | balance rows |
| What Capacity exists across all retained history? | `CapacityReview` | CapacityMovement | none | Entitlement rows |
| What Capacity applies to a window? | `CapacityWindowInspection` | CapacityMovement, CapacityEffective | window | windowed Entitlement |
| What is available after spending and future pressure? | `CurrentCoverageInspection/Review` | see composition below | elapsed/future windows, observation date | Entitlement, Consumption, Remaining, Commitment, Headroom, pressure frontier |
| Which current Expense loci are routed? | `ActualRoutingReview` | LocusAdmission, AccountingRole, ActualRouting, CapacityMovement | observation date | routing status rows, unresolved role loci, Purpose candidates |
| Why did selected balances change? | `StockFlowReview` | inherited from Balance + ActualReview | window | opening, closing, increases, decreases, net change |
| Which Events contributed to which coordinates? | `TransactionsFlowReview` | inherited from ActualReview | window | cells, row activity, residuals |
| What conditional selected-balance path follows? | `ConditionalBalancePathReview` | inherited from Balance + current-open Scheduled | observation date, completeness assumption | path points, final balance, low-water |
| What is the current cycle funding picture? | `CycleBudgetReview` | inherited from CurrentCoverage + Balance | boundary preset/window, funding selection, observation date | cycle summary |
| What currently needs Attention? | `AttentionReview` | AttentionItem, AttentionClosure | source availability | open-item view |

## CurrentCoverage is already a small algebra

Production factors the largest current budget answer through three substantive answers:

```text
Entitlement
  <- CapacityMovement + CapacityEffective + elapsed window

Consumption
  <- Event + EventCorrection + ActualValidity + ActualRouting + elapsed window

Commitment
  <- current-open Scheduled lifecycle
     + AccountingRole + ScheduledRouting + future horizon
```

Then:

```text
Remaining = Entitlement - Consumption
Headroom  = Remaining - managed Commitment
```

`Remaining`, `Commitment`, `Headroom`, unmanaged pressure, unrouted pressure and unresolved eligibility are projections, not additional stored budget objects.

The full current answer intentionally distinguishes Scheduled pressure classes:

```text
managed for queried Purpose
managed for another Purpose
unmanaged
unrouted pressure
resolved non-pressure
unresolved eligibility
```

A narrower answer such as Headroom alone needs fewer distinctions. The present full answer needs more because unresolved pressure is itself observable.

## First global Alloy graph

`experiments/242_current_read_answer_basis.als` models only:

```text
Retained information
Query/config input
Intermediate answer
Observable answer
```

There is no file, sidecar, manifest, codec or module concept in the model.

Its main structural equalities are:

```text
CurrentCoverage
  = EffectiveEntitlement + ActualConsumption + ScheduledCommitment

StockFlow retained base
  = Balance retained base + ActualReview retained base

TransactionsFlow retained base
  = ActualReview retained base

ConditionalBalancePath retained base
  = Balance retained base + ScheduledOpen retained base
```

This is provenance, not yet proof that every input family is indispensable.

## First read-only pressure result

The reconstructed current `Q_read` graph does not consume:

```text
ActualReversal
RelationUnit
RelationDischarge
```

This is **not** a deletion result. It isolates the next question:

> Which `Q_write` or `Q_safe` obligation uniquely requires each one?

That is stronger than retaining them because current authority topology happens to select them.

## First semantic reduction model

`experiments/243_current_coverage_answer_basis.als` stops mirroring current type boundaries and reduces one Purpose/Measure CurrentCoverage answer to answer-determining dimensions:

```text
Capacity:
  amount
  included in elapsed window?

Actual:
  amount
  current?
  included in elapsed window?
  routed to queried Purpose?

Scheduled:
  amount
  current-open?
  included in future horizon?
  pressure classification
```

It then derives the complete current answer.

The intended counterexamples ask whether changing only:

```text
Capacity effective placement
Actual Purpose routing
Scheduled open/terminal state
Scheduled pressure classification
```

can change the answer.

It also searches for worlds with identical Headroom but different visible pressure frontiers. Such a witness means a scalar Headroom vocabulary permits stronger compression than the current full CurrentCoverage vocabulary.

## Cross-cutting compression questions exposed by the answer graph

These are hypotheses, not abstractions to implement yet.

### Temporal evidence

```text
ActualValidity
CapacityEffective
ScheduledOccurrence.scheduledOn
Actual/Scheduled routing effective coordinates
```

Can these be typed instances of a smaller temporal-evidence relation while preserving their different admission laws?

### Identity/lifecycle relations

```text
EventCorrection
ActualReversal
ScheduledCompletion
ScheduledRetirement
ScheduledReplacement
```

Can they share a smaller relation skeleton without collapsing operation-specific meaning?

### Routing

ActualRouting and ScheduledRouting already share generic routing mechanics. Test semantic unification separately from authority/storage unification.

### Epistemic states

```text
known zero
coverage missing
source unavailable
open-world unknown
unresolved eligibility
```

Test whether a small information-order/lattice vocabulary can represent these without equating states that current answers distinguish.

## Next sequence

1. Qualify the two current Alloy models before merge.
2. Extend the answer map only when a current production read is missing.
3. For each retained family, hold all other information equal and ask Alloy for two worlds whose selected answer differs.
4. Classify each family per answer as `WITNESS`, `DERIVABLE`, `QUERY-IRRELEVANT`, or `UNRESOLVED`.
5. Add `Q_write` and `Q_safe` separately, especially for ActualReversal, RelationUnit and RelationDischarge.
6. Only after the semantic basis stabilizes, resume `CapacityAuthority` / physical-topology work.

## Stop rule

Do not optimize file count directly.

```text
minimal answer-determining semantics
  -> required authority/failure boundaries
  -> smallest safe physical topology
```

File count should be the result, not the premise.
