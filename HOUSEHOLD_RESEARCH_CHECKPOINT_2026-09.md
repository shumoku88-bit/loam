# Household Research Checkpoint — September 2026

Status: **research chapter settled enough to widen external investigation**

This checkpoint consolidates the qualified household observations that currently live in open experimental pull requests. It is intentionally a research summary, not a request to promote every experimental noun or model into Practical Core.

The purpose of this checkpoint is to make the repository state explicit:

```text
qualified experiment
    !=
unfinished production feature

open research PR
    !=
required implementation queue
```

After this checkpoint, the household recording / Scheduled / Capacity / envelope-budget research chapter is considered settled enough that new work should preferably come from fresh dogfood pressure or from concrete difficulties observed in existing accounting and personal-finance systems.

## Current practical and semantic baseline

The already-merged household compression work established a small evidence-oriented base:

```text
Actual       retained occurrence evidence
Scheduled    retained intentional / expected occurrence evidence
Capacity     retained allocation / spending authority
Purpose      stable household purpose coordinate

Consumption
Commitment
Remaining
Headroom
accounting presentation
    derived where the selected evidence is sufficient
```

The research summarized below reinforces a recurring rule:

> Preserve independently observable evidence, but do not retain a named object merely because a UI or accounting tradition has a noun for it.

## Scheduled and external-source boundary

### PR #278 — split / merged Scheduled realization

Qualified result:

```text
one-to-one ScheduledCompletion
    too small for split / merged realization

quantity-free many-to-many topology
    still too small when shared Actual quantity must be apportioned
```

No production `RealizationShare` is earned. Equivalent finer-grained evidence may later satisfy the same information need.

### PR #279 — external observation reconciliation

Qualified result:

```text
external source observation
    !=
household Actual

content similarity
    does not determine
reconciliation / support provenance
```

### PR #281 — external observation lifecycle

Qualified result:

```text
pending / posted source lifecycle
    !=
household Actual lifecycle

current posted state
    does not determine
whether pending evidence existed earlier
```

### PR #283 — external delivery identity

Qualified result:

```text
delivery attempt
    !=
external observation identity

same payload twice
    may be retry
    or two distinct source observations
```

### PR #284 — provider-key continuity

Qualified result:

```text
provider record key
    !=
source lifecycle identity

pending key P -> posted key Q
    may still be one source lifecycle
```

These observations remain valuable evidence if import / bank / card integration becomes practical. They do not currently justify a production external-observation subsystem.

## Backing and Capacity boundary

### PR #285 — Capacity / Backing topology

Qualified result:

```text
Capacity authority
    !=
physical holdings
    !=
Backing support
```

Aggregate eligible holdings do not determine which Purpose capacity is funded.

### PR #287 — Backing apportionment

Qualified result:

```text
Backing topology
    !=
Backing quantity apportionment
```

One Holding may support several Purposes, and topology alone is too small for per-Purpose funded / gap answers.

### PR #288 — budget reallocation authority

Qualified result:

```text
shared balanced signed movement mechanics     useful
one universal Purpose coordinate for Backing  too small
canonical EnvelopeTransfer                    not earned

Capacity coordinate: Purpose
Backing coordinate:  Holding x Purpose
```

One user-facing reallocation may compose several semantic authorities without earning a third canonical transfer fact.

### PR #289 — Actual / Backing follow boundary

Qualified result:

```text
Actual consumption
    does not uniquely determine
post-Actual Backing allocation
```

A deterministic Backing policy could provide the missing authority without requiring a second manual entry after every spend.

### PR #290 — Backing policy projection

Qualified result:

```text
current holdings
+ current Remaining
+ deterministic Backing policy definition
    -> current Backing / Funded / Gap projection
```

Retained current Backing state may therefore be avoidable, but Backing authority itself is not erased.

## DateRange / budget-window boundary

### PR #291 — DateRange budget window

Qualified result:

```text
monthly / pension / half-year / custom
    may resolve to ordinary half-open DateRange

canonical Cycle identity
    not earned
```

DateRange determines temporal membership, while Capacity authority remains independently required for a full budget answer.

### PR #293 — DateRange Capacity formula

Qualified result:

```text
DateRange
+ formula definition
    -> generated base Capacity

DateRange
+ formula definition
+ retained Capacity adjustments
    -> final Capacity
```

No canonical MonthlyBudget / PensionBudget / HalfYearBudget family is earned.

### PR #295 — overlapping budget views

Qualified result:

Multiple overlapping DateRange views may reuse the same retained evidence without copying it into budget containers. Overlapping projected totals are not generally additive. A selected operating context is query/application input, not canonical household truth.

### PR #297 — Capacity formula composition

Qualified result:

Adjacent range additivity depends on the formula definition. In the bounded affine specimen, zero intercept characterizes adjacent-partition additivity. A separate composability identity is not earned.

### PR #299 — Capacity adjustment window

Qualified result:

```text
authority DateRange
+ selected view DateRange
+ formula definition
+ timed Capacity adjustments
    -> Capacity at selected view end
```

A visible DateRange alone is too small because adjustments before the visible subview may remain in force.

### PR #300 — Capacity boundary policy

Qualified result:

```text
adjacent DateRanges
+ formula
+ timed adjustments
    do not determine
cross-boundary treatment

explicit boundary policy definition
    supplies the missing authority
```

Universal reset and universal carry-all both fail as general laws. Policy identity itself is not earned once its definition is fixed.

### PR #301 — unused Remaining carry

Qualified result:

```text
previous Remaining
    = previous Capacity projection
    - previous Actual consumption
```

Unused Remaining can remain derived rather than retained as an `EnvelopeBalance`.

Cross-boundary unused carry is independently meaningful from prior-adjustment carry:

```text
reallocation carry
    !=
unused Remaining carry
    !=
physical Holdings
    !=
Backing
```

No canonical `RolloverBudget`, retained Remaining, or Envelope balance is earned.

### PR #302 — stable Purpose coordinate across changing views

Qualified result:

```text
stable Purpose identity
+ time-local Capacity authority
+ optional time-local descriptive evidence
    -> changing household presentation
```

The same Purpose may cross a boundary while its name, Capacity, or both change. No `PurposeVersion`, `EnvelopeVersion`, canonical Cycle, or open/closed Purpose lifecycle is earned by this pressure.

Historical name storage remains deliberately unearned until practical dogfood requires preserving old human labels.

## Envelope-budget checkpoint

The current smallest picture is therefore closer to coordinates plus evidence than to mutable envelope objects:

```text
Purpose                         stable coordinate
DateRange                       temporal coordinate / query boundary
Capacity authority              time-local allocation authority
Capacity adjustment evidence    explicit allocation change
Actual                          occurrence evidence
Scheduled                       intentional evidence
boundary policy definition      only when cross-boundary semantics matter
Backing authority               separate funding question

Remaining / Headroom / Funded / Gap / envelope-like views
    derived projections
```

This means the following concepts are **not currently earned as canonical household state** merely for ordinary envelope budgeting:

```text
Envelope
EnvelopeBalance
EnvelopeVersion
BudgetCycle / CycleId
MonthlyBudget / PensionBudget object families
RolloverBudget
retained Remaining
open / closed envelope state
canonical OperatingBudget / ForecastBudget roles
PurposeVersion
```

A UI may still use words such as envelope, month, pension period, rollover, funded, or remaining. The checkpoint only says those UI nouns need not own separate canonical truth under the qualified observations.

## What remains deliberately unsettled

The chapter is settled enough to widen investigation, not proven complete for every accounting domain.

Known unresolved or only experimentally qualified seams include:

```text
split / merged realization quantity apportionment
external-source reconciliation and identity
provider lifecycle continuity
practical Backing policy selection and historical provenance
negative Remaining / overspending across a boundary
partial / capped / expiring rollover rules
historical Purpose presentation if old names must be reproduced
```

These should be revisited only when dogfood or external-system research demonstrates a concrete household question that the current evidence cannot answer.

## Historical numbering note

There is one already-created duplicate observation label:

```text
merged main Observation 135
    Historical Migration Archive minimal boundary

PR #299 "Observation 135"
    Capacity adjustment window
```

This checkpoint does **not** rewrite merged history or silently renumber already-qualified experimental artifacts.

Bare `Observation 135` is therefore ambiguous. References must use the title / PR number (and exact head when qualification matters):

```text
Historical Migration Archive — merged PR #298
Capacity adjustment window     — PR #299
```

Future observations should avoid reusing an already-present number, but the duplicate historical label itself does not introduce a domain concept and does not affect either result.

## Research gate

The next preferred mode is now:

```text
existing OSS / commercial accounting systems
        ↓
find places with persistent exceptions, workarounds,
manual reconciliation, duplicated state, or ad-hoc lifecycle rules
        ↓
remove cases LOAM has already qualified
        ↓
rank genuinely untested information boundaries
        ↓
small Alloy / TLA+ / Lean observation only where needed
```

Do not extend the household ontology merely to keep the observation sequence busy.
