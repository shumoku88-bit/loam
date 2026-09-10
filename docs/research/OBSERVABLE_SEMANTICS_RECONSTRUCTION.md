# Observable semantics reconstruction

Status: **working answer-first reconstruction; no production or loam-data mutation authorized**

Baseline: `f79c4a474932da5ce9fd6e4192ebb18062dd6b6c`

Tracking: #693

## Question

Instead of asking which current canonical file or family should survive, ask:

> Which answers do we want LOAM to be able to give, and what is the least retained information needed to determine each answer without guessing?

The direction is therefore:

```text
desired answer
    -> semantic prerequisites
    -> reusable intermediate answers
    -> minimal retained distinctions
    -> publication / recovery requirements
    -> physical storage topology
```

Physical files are deliberately absent from the first four steps.

## Why start from answers

A current file can acquire an accidental aura of necessity:

```text
file exists
  -> codec exists
  -> loader exists
  -> writer exists
  -> tests exist
  -> callers know the path
  -> file starts to look like a domain concept
```

Answer-first reconstruction reverses that pressure.

A retained distinction earns a place only when some desired answer cannot be
reconstructed without it.

The minimal basis is therefore **vocabulary-relative**. There is not necessarily
one metaphysical minimum for every possible future LOAM.

## Separate vocabularies before minimizing

Do not mix all pressures at once.

```text
Q_read   current read / report / administration answers
Q_write  admitted writes and visible refusal reasons
Q_safe   crash, recovery, corruption, concurrency obligations
```

Start with `Q_read`.

A family absent from `Q_read` is not automatically deletable. It may later earn
its place through `Q_write` or `Q_safe`.

This is especially important for current Reversal and Relation evidence.

## Current question-shaped read vocabulary

The current product can be described more compactly as questions than as module
names.

### A. What actually happened?

Production owner: `ActualReview`.

Answer includes:

```text
Event identity
signed Effects
current/superseded frontier membership
occurrence date or unknown date
description text
replacement identity when corrected
```

Current semantic prerequisites:

```text
Event
ActualValidity
EventDescription
EventCorrection
```

The review record itself is derived and should not be retained.

### B. What is still scheduled / due?

Production owner: `ScheduledReview`.

Answer includes replacement-aware current-open Scheduled occurrences and
explicit refusal states for unknown completion/retirement/replacement identities,
invalid replacement graphs, and conflicting terminal evidence.

Current semantic prerequisites:

```text
ScheduledOccurrence
ScheduledCompletion
ScheduledRetirement
ScheduledReplacement
Event identity closure
query date for day-specific evidence
```

The current-open list is derived.

### C. What is the current selected balance?

Production owner: `BalanceReview`.

Answer:

```text
selected EffectCoordinate -> current Quantity
or explicit unavailable/refusal state
```

Current semantic prerequisites:

```text
Event
EventCorrection
ZeroOriginCoverage
```

Query/configuration input:

```text
selected balance coordinates
```

The selection is not historical household fact.

### D. What spending capacity has been allocated?

Production owner: `CapacityReview`.

The all-retained answer depends on:

```text
CapacityMovement
```

A dated/windowed Entitlement answer additionally needs:

```text
CapacityEffective
window coordinates
```

Therefore effective time can be necessary for one answer vocabulary while being
irrelevant to the simpler all-history Capacity answer.

### E. How much is available after actual spending and scheduled pressure?

Production owners: `CurrentCoverageInspection` / `CurrentCoverageReview`.

The current answer exposes:

```text
Entitlement
Consumption
Remaining
Commitment
Headroom
unmanaged Scheduled pressure
unrouted Scheduled pressure
unresolved eligibility pressure
```

The production arithmetic already factors as:

```text
Remaining = Entitlement - Consumption
Headroom  = Remaining - managed Commitment
```

So `Remaining` and `Headroom` are not retained-state candidates.

The three substantive inputs are themselves derived answers:

```text
Entitlement
  <- CapacityMovement + CapacityEffective + current elapsed window

Consumption
  <- Event + EventCorrection + ActualValidity + ActualRouting
     + current elapsed window

Commitment
  <- ScheduledOccurrence + Completion + Retirement + Replacement
     + Event + AccountingRole + ScheduledRouting
     + current future horizon
```

This is the strongest current example of a large-looking product answer arising
from a relatively small composition algebra.

### F. Which current Expense loci are routed to which Purposes?

Production owner: `ActualRoutingReview`.

Answer includes:

```text
current admitted Expense Locus -> routing status
currently admitted Loci with unresolved AccountingRole
historical-only routed Loci
current Purpose candidates
```

Current semantic prerequisites:

```text
LocusAdmission
AccountingRole
ActualRouting
CapacityMovement
```

Query input:

```text
observation date
```

### G. Why did selected balances change over a window?

Production owner: `StockFlowReview`.

Answer includes:

```text
reconstructed opening
reconstructed closing
positive changes
negative changes
net change
current tracked total
```

It does not introduce a second retained history.

It composes:

```text
Balance answer
+ ActualReview answer
+ explicit half-open window
```

Therefore opening, closing, increase, decrease, and net-change report state are
all derived.

### H. Which current Events contributed to which coordinates?

Production owner: `TransactionsFlowReview`.

Answer includes:

```text
rows    = EffectCoordinate
columns = current dated Event
cell    = Event quantity at coordinate
row net / positive / negative / gross / active-event count
per-Event Measure residual
```

It composes:

```text
ActualReview answer
+ explicit half-open window
```

Cells and row aggregates are derived. There is no second posting store.

### I. Under an explicit completeness assumption, what selected-balance path follows?

Production owner: `ConditionalBalancePathReview`.

Answer includes:

```text
current selected balance
dated Scheduled changes
conditional balance points
final horizon balance
low-water balance
```

It composes:

```text
Balance answer
+ replacement-aware current-open Scheduled answer
+ caller-supplied completeness horizon
```

The completeness assumption is explicitly not retained household evidence.

### J. What is the current cycle funding / coverage picture?

Production owner: `CycleBudgetReview`.

This is a composition surface with independently visible failure boundaries:

```text
current window
CurrentCoverage answer
physical Balance answer
replaceable funding selection
funding summary
```

Window presets and funding selections are query/configuration inputs, not
historical facts merely because the TUI uses them.

### K. What currently needs Attention?

Production owner: `AttentionReview`.

Answer:

```text
open Attention items
with due-on / no-due-date / due-undetermined meaning
```

Semantic prerequisites:

```text
AttentionItem
AttentionClosure
```

Source availability is deliberately a separate state from an explicitly empty
Attention lifecycle.

## First global structural model

`experiments/242_current_read_answer_basis.als` encodes the dependency graph
above without any file or module topology.

It separates:

```text
Retained
QueryInput
Intermediate answer
Observable answer
```

The important role of this model is not to prove that every declared retained
input is indispensable. It gives a common graph on which those claims can now be
challenged one by one.

For example, the model records these composition equalities:

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

## Immediate read-only pressure result

The reconstructed `Q_read` graph does **not** consume these currently retained /
selected families:

```text
ActualReversal
RelationUnit
RelationDischarge
```

This is not a deletion result.

It changes the question to:

```text
Which Q_write or Q_safe obligation, if any, uniquely requires each one?
```

That is much sharper than retaining them because the selected physical authority
currently contains them.

## Second-order compression candidates exposed by the graph

The graph also reveals repeated semantic shapes that should be tested rather than
immediately generalized.

### Temporal attachment

Current LOAM has several ways to attach effective/occurrence time:

```text
ActualValidity
CapacityEffective
ScheduledOccurrence.scheduledOn
Actual/Scheduled routing effective coordinates
```

Question:

> Are these genuinely different retained concepts, or typed instances of one
> smaller temporal-evidence relation plus different admission laws?

### Identity/lifecycle edges

Several facts change how another identity is interpreted:

```text
EventCorrection
ActualReversal
ScheduledCompletion
ScheduledRetirement
ScheduledReplacement
```

Question:

> Which distinctions belong to one generic identity-relation skeleton, and which
> operation-specific laws must remain separate?

### Routing

Production already shares a generic `RoutingHistory` shape while retaining
ActualRouting and ScheduledRouting separately.

Question:

> Can one semantic routing algebra serve both without collapsing their different
> subject/effective-time authority?

### Epistemic completeness

Current answers distinguish states such as:

```text
known current zero
coverage missing
source unavailable
open-world unknown
unresolved eligibility
```

Question:

> Can a smaller information-order / lattice vocabulary represent these states
> without inventing false equality between them?

This is a candidate place where the earlier lattice / abstract-interpretation
idea may reduce concepts rather than add them.

## Next formal sequence

Do not build one giant Alloy universe immediately.

Use the global graph to choose small destructive tests:

```text
1. Freeze one desired answer.
2. Hold all other candidate information equal.
3. Vary or erase one retained distinction.
4. Ask Alloy for two worlds with different answers.
5. SAT  -> the distinction is required for that answer.
6. UNSAT within the model -> try a smaller representation / quotient.
7. Promote only general arithmetic/uniqueness laws that need proof to Lean.
```

The highest-leverage next targets are:

```text
A. CurrentCoverage semantic basis
   Can its many current inputs be factored further without changing the full
   managed/unmanaged/unrouted/unresolved answer?

B. ActualReview semantic basis
   Which retained differences are numerical, temporal, contextual, or only
   presentation?

C. Scheduled lifecycle basis
   Can completion / retirement / replacement share a smaller relation skeleton
   while preserving every current-open refusal state?

D. Q_write overlay
   Re-introduce ActualReversal, RelationUnit, RelationDischarge only through the
   concrete admission/refusal/safety questions that need them.
```

## Stop rule

Do not ask how many files LOAM should have until this graph has been reduced as
far as the desired answer vocabulary allows.

The physical question becomes last:

```text
minimal answer-determining semantic basis
    -> required authority / failure boundaries
    -> smallest safe physical topology
```

That is the point at which file count becomes an implementation result rather
than a design premise.
