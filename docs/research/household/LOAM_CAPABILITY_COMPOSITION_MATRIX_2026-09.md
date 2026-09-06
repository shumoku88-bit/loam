# LOAM capability composition matrix

Status: research pressure, not a production feature specification.

Baseline:

```text
LOAM main
113b580a61ec3fd78b15c3662bf1b2e0bed87c56

HRA interaction comparator
75cc6b04c38dff47cb6373f5d2ca38038ba7c9bf
```

The current TUI research stack is intentionally not the base of this document. Prototype 11 / PR #473 is independently pressure-testing selected-day Scheduled evidence on Home. This matrix starts from production `main` so it can remain a stable capability map while UI prototypes continue in parallel.

## Question

The target is not minimum source lines and not a port of HRA's domain model.

The stronger hypothesis is:

> Can LOAM recover a broad daily-use household interface from a small set of independently meaningful parts, explicit relations, query coordinates, projections, and local laws?

A large implementation is acceptable if the semantic vocabulary remains small and the parts compose cleanly. Parser code, persistence code, terminal mechanics, tests, and proofs may grow when they buy clarity or safety.

The pressure is instead on **semantic multiplication**. A new household capability should not automatically earn a new Core noun, state machine, stored aggregate, or top-level UI ontology.

## What counts as a small part

This study treats a part as small when it has one independent meaning and can be reused without pretending that two household meanings are identical.

Current examples include:

```text
Event / Effect
Locus / Measure / exact Quantity
BalancedMovement
EventCorrection / ActualValidity
Scheduled identity + explicit occurrence day + balanced movement
Scheduled completion / retirement / replacement evidence
Purpose + Capacity movement
Historical routing
Attention + due meaning + closure + provenance relation
selected/query time coordinates
Application projections
writer admission / ownership boundaries
```

Sharing signed effects does not make Actual and Capacity one semantic plane. Sharing identity/relation mechanics does not make Scheduled replacement and Attention continuation one lifecycle meaning. Reuse is successful only when independent meanings remain distinguishable.

## Composition ladder

Before adding a new primitive for a requested capability, test the following ladder in order:

```text
0. presentation only
   existing answer, new view or interaction

1. projection
   existing retained evidence can answer the question

2. explicit relation
   existing identities are sufficient, but provenance between them is missing

3. query coordinate / policy
   the answer needs a caller-supplied interval, horizon, role, or selection

4. new retained semantic part
   only after 0-3 cannot preserve the household distinction
```

Failure at one rung is evidence, not permission to jump immediately to rung 4.

## Status legend

### Composition status

- **C0**: existing retained parts are semantically sufficient; no new Core meaning is expected.
- **P**: a projection or query adapter is still needed.
- **R**: an explicit relation or relation distinction is still needed.
- **Q**: query coordinate or policy is still needed.
- **S**: current semantics are genuinely insufficient or deliberately absent.
- **UI**: presentation mechanics only.

Several labels may appear together, for example `C0 + P + UI`.

### Delivery maturity

- **PROD-W**: practical production write path exists.
- **PROD-R**: practical production read/application path exists.
- **PROTO**: exercised only through current UI prototypes/research.
- **CORE**: semantic evidence exists in Core/Application, but no complete daily-use surface is claimed here.
- **ABSENT**: intentionally absent or not yet earned.

This column is deliberately separate from semantic sufficiency. A capability can be `C0` while still lacking a TUI.

## Capability matrix

| Household capability / HRA affordance | Small LOAM parts that should compose it | Composition pressure | Delivery now | Next UI / research pressure |
| --- | --- | --- | --- | --- |
| Move focus by day/week on Home | selected presentation day | UI | PROTO | Retain the pure bounded orientation law; do not store selected day as household evidence. |
| Return focus to known/visible horizon | selected day + explicit knowledge horizon | Q + UI | PROTO / partial semantics | Preserve focus vs visibility as separate coordinates; do not fake a horizon from wall clock. |
| Show selected-day Actual on Home | dated admitted Actual review projection | C0 + P + UI | PROD-R + PROTO | Reuse the same projection in Home and Actual workspace. |
| Show selected-day Scheduled on Home | Scheduled occurrence + completion + retirement + replacement + selected day | C0 + P + UI | PROD-R + PROTO | Keep open-world answer: explicit current-open -> Due; missing explicit occurrence -> Unknown, not NotDue. |
| Show selected-day Attention / Issue | Attention due meaning + closure + selected day | C0 + P + UI | CORE | Earn an exact-day/current Attention projection before adding Home markers. |
| Calendar attention markers | independent Actual/Scheduled/Attention/cycle answers | P + UI | PROTO for Actual/Scheduled only | Compose markers as projections. Never retain a generic calendar-attention fact. |
| Record an Actual directly from Home | selected day + BalancedMovement + Event publication boundary | C0 + UI | PROD-W, TUI absent | HRA-style form/preview is a presentation experiment, not a new transaction semantic. |
| Balanced multi-leg purchase / transfer / income / split | BalancedMovement + Effects | C0 | PROD-W | One editor should expose movement structure without separate operation kinds. |
| Actual browse and detail | admitted ActualReview record projection + local cursor | C0 + UI | PROD-R + PROTO | Keep detail as a local Actual workspace mode. |
| Reverse/correct selected Actual | visible Event identity + EventCorrection / ActualValidity evidence | C0 + UI | production semantics exist | Object-local TUI action should pass target identity to the existing application boundary. |
| Record new Actual from Actual workspace | same Movement writer as Home | C0 + UI | PROD-W | Reuse one editor, not a second Actual-workspace-specific writer. |
| Seed Scheduled from selected Actual | selected admitted movement as editable draft + Scheduled writer | C0 + UI, provenance question remains optional | production Scheduled writer exists | First test draft reuse with no retained relation. Add provenance only if a household answer needs it. |
| Create Scheduled occurrence | Scheduled identity + explicit day + BalancedMovement | C0 | PROD-W | TUI form can reuse movement-entry mechanics while keeping Scheduled meaning distinct. |
| Browse open Scheduled | Scheduled + terminal lifecycle evidence + replacement frontier | C0 + P + UI | PROD-R | Prototype next as one HRA-style Scheduled workspace. |
| Complete Scheduled as Actual | ScheduledCompletion relation + newly admitted Actual Event | C0 + UI | PROD-W | Prefill an editable Actual draft; publication remains explicit and stale drafts must be rejected. |
| Cancel Scheduled | ScheduledRetirement evidence | C0 + UI | PROD-W | UI verb may say cancel; retained meaning remains append-only retirement evidence. |
| Replace/reschedule Scheduled | ScheduledReplacement + new Scheduled occurrence | C0 + UI | PROD-W | Keep replacement separate from continuation/recurrence even if one local action flow creates the successor draft. |
| Continue / create a genuinely next occurrence | current Scheduled identities plus a meaning not equivalent to replacement | S or R | ABSENT | Do not infer continuation from replacement. Observe concrete household cases first. |
| Recurring schedule / cadence / series | unknown | S | ABSENT | Stay absent until repeated real use forces a generator or retained relation. Do not infer recurrence from missing/adjacent occurrences. |
| Show overdue/upcoming obligations | current-open Scheduled + time query + a completeness/knowledge boundary | Q + P, current open-world gap matters | partial PROD-R | Do not derive NotDue from absence. Earn enough horizon/completeness semantics before strong overdue/upcoming claims. |
| Keep non-financial household matter visible | Attention identity + opaque context + explicit due meaning | C0 | CORE | Build read-only Issue workspace before adding taxonomy. |
| Distinguish due date / no due date / due unknown | AttentionDue | C0 | CORE | Preserve three-way presentation; no optional-date collapse. |
| Resolve/drop Attention | AttentionClosure kind + knowledge coordinate | C0 + UI | CORE | Practical writer/UI can be additive without changing Attention itself. |
| Realize Attention as Actual | AttentionRelation target Event + separate closure evidence | C0 + UI | CORE | A TUI may stage relation + closure, but relation existence must never silently imply closure. |
| Continue Attention as another Attention | AttentionRelation target Attention + new Attention identity + separate closure evidence | C0 + UI | CORE | Interaction can resemble HRA continue while retaining provenance and closure independently. |
| Classify Attention into refund/subscription/want/etc. | currently no qualified need for category primitive | P or S depending query | ABSENT | Prefer query/view labels until a distinction changes legal operations or retained answers. |
| Observe capacity by purpose | Purpose + CapacityMemory + current inspection | C0 + P + UI | PROD-R | Candidate independent Capacity workspace after Scheduled. |
| Move capacity from one purpose/unallocated endpoint to another | balanced Capacity movement + Purpose + writer admission | C0 + UI | PROD-W | Reuse From -> To interaction grammar, but not Actual authority or semantic plane. |
| Show before/after allocation preview | current Capacity projection + proposed movement | C0 + P + UI | practical ingredients exist | Presentation-only safety affordance. No retained preview state. |
| Consumption of purpose capacity by Actual | Actual movement + historical routing + Purpose | C0 + P | production semantic slices exist | Surface only after exact routing/current-history answer is clear. |
| Commitment from open Scheduled | Scheduled current-open evidence + routing + Purpose | C0 + P, open-world caveat | application semantics exist | Any UI must expose explicit-only/open-world limits until completeness is earned. |
| Remaining / headroom | entitlement/consumption/commitment projections | C0 + P | partial application semantics | Keep derived; do not store Remaining or Headroom as canonical state. |
| Backing / funded promises | holdings + explicit backing/routing evidence | unresolved composition | later | Re-audit current production evidence before designing HRA-equivalent Backing UI. |
| Cycle position | time interval policy + selected/known coordinate | Q + P | ABSENT as a complete Home capability | Try derived interval policy before adding a Cycle object. |
| Daily spending pace | cycle interval + eligible holdings + commitments + exact division/remainder | Q + P | ABSENT | Projection experiment only after cycle and Scheduled completeness questions are adequate. |
| Recent Actual report | admitted dated Actual review | C0 + P + UI | PROD-R | Could be a first Report section with almost no new semantics. |
| Daily flow | dated admitted Effects + routing/role selection as required | P + Q | partial | Keep sparse activity-day projection if dogfood still prefers it. |
| Monthly accounts | dated effects + month interval + selected Loci | P + Q | ABSENT as production report | Month should remain a query interval unless counterexample forces retention. |
| Planned payments report | current-open Scheduled + query interval/horizon | P + Q | partial | Must preserve Unknown/open-world caveat. |
| Open Issues report | openAttentions projection | C0 + P | CORE | Same answer should feed both Issue workspace and Report section. |
| Report section navigation | local section identity + scroll orientation | UI | HRA comparator only | One Report workspace, sections as local modes, no top-level application per report. |
| Vertical/horizontal/page scrolling | terminal presentation mechanics | UI | HRA comparator only | Extract only after two real LOAM surfaces need the same mechanism. |
| Mouse selection / wheel | terminal presentation mechanics | UI | ABSENT | Add only after keyboard dogfood exposes value; no domain semantics. |
| Refresh after write while keeping safe orientation | canonical re-admission + presentation-only selected day/cursor | C0 + UI | writer boundaries already re-admit locally | Treat stale-state rejection as both safety and interaction behavior. |

## First observations from the matrix

### 1. The HRA capability set does not currently demand one Core type per screen

The strongest current candidates for top-level interaction surfaces remain:

```text
Home
Actual
Scheduled
Attention / Issue
Capacity
Reports
```

That is an interaction decomposition, not a semantic ontology. In particular:

- Home can compose independent answers without a `HomeState` household fact;
- Actual and Capacity may share movement-shaped mechanics without becoming one plane;
- Reports can be projections without a `Report` domain object;
- Scheduled lifecycle actions remain explicit relations/evidence around Scheduled identity;
- Attention relation provenance and Attention closure remain deliberately separate.

### 2. The biggest current semantic hole around the TUI is not basic CRUD

Actual, Scheduled, and Capacity already have substantial practical read/write machinery. Attention already has a small semantic family and current inspection.

The sharper unresolved areas are:

- completeness / knowledge needed for strong negative Scheduled claims;
- continuation / recurrence beyond replacement;
- cycle policy and cycle-relative projections;
- richer report classifications and intervals;
- the minimum evidence for Backing and other envelope-health questions.

The UI should not silently fill these holes with presentation assumptions.

### 3. Record editor is valuable as a TUI-kernel pressure test

The verified TUI work has already encountered two different presentation shapes:

```text
spatial calendar
vertical list/detail
```

An HRA-like Movement editor introduces a third:

```text
form focus
candidate selection
field validation
editable draft
preview
explicit publish/cancel
```

If the existing small Widget/Screen/update/runtime pieces survive that shape without a generic forms framework, that is direct evidence for the wider LOAM hypothesis: a small set of parts can generate materially richer behavior.

### 4. Scheduled workspace should stay on the current prototype lane

Prototype 11 is already the nearest pressure point. If selected-day Scheduled Home preview survives dogfood, the next narrow experiment should be a Scheduled workspace with browse and only currently qualified local actions.

Do not mix recurrence, series, completeness, or generic routing into that experiment.

## Measuring composition instead of LOC

For every new capability or TUI action, record this small ledger:

```text
Core families added            N
canonical relation kinds added N
query coordinates/policies     N
new projections                N
existing laws reused           N
new local laws                 N
presentation-only mechanisms   N
```

LOC is intentionally absent.

A feature that needs 500 lines of careful parsing, tests, and proofs but adds zero semantic primitives may be a better LOAM result than a 30-line feature that introduces a new ambiguous state object.

## Candidate success criteria

This research hypothesis becomes stronger if repeated household capabilities show all of the following:

1. **Breadth from composition**
   - most daily-use HRA capabilities are recovered without one new Core family per capability;
2. **Independent meaning survives reuse**
   - sharing mechanics never collapses distinctions such as Actual vs Capacity, Unknown vs NotDue, or replacement vs continuation;
3. **Safety composes too**
   - new UI actions reuse admission, writer ownership, fail-closed readers, and explicit publication boundaries rather than bypassing them;
4. **Derived answers stay derived**
   - reports, Home summaries, Remaining, Headroom, calendar markers, and previews do not become duplicate authority;
5. **UI mechanics earn extraction empirically**
   - a generic interaction primitive enters the kernel only after multiple distinct real surfaces need the same law/mechanic.

## Refutation criteria

The hypothesis should be weakened rather than protected if repeated practical capabilities require any of these:

- frequent new Core families merely to distinguish ordinary UI actions;
- relations so generic that illegal combinations proliferate and each consumer needs ad-hoc exclusions;
- projections that repeatedly need hidden policy or reconstruct provenance from text;
- a small vocabulary that makes writers harder to admit safely than more explicit domain evidence would;
- one shared UI abstraction whose state space is substantially larger or less provable than several small local state machines;
- real household questions that cannot be answered without retaining an apparently "derived" distinction.

A counterexample is a useful result. The goal is not to keep LOAM small at any cost.

## Parallel work plan

Keep two independent lanes:

```text
Lane A: concrete TUI pressure
  Prototype 11 Home Scheduled dogfood
    -> Scheduled workspace
    -> Movement Record editor as a third UI shape
    -> Attention read-only workspace
    -> Capacity workspace
    -> Report workspace when projections are ready

Lane B: semantic composition pressure
  HRA capability
    -> composition ladder 0..4
    -> counterexample search when meaning is uncertain
    -> smallest retained evidence that preserves the distinction
    -> production Application/read-write boundary
```

The lanes meet only at qualified boundaries. A prototype may reveal missing semantics, but it must not invent them locally.

## Immediate next gates

1. Finish Prototype 11 human dogfood without changing this branch.
2. If it survives, prototype a Scheduled workspace using the existing completion, retirement, and replacement boundaries only.
3. In parallel, design one HRA-style Movement Record editor over the existing production Movement writer contract.
4. Treat Attention and Capacity as the next two distinct semantic-family workspace pressures.
5. Update this matrix whenever a capability either composes successfully or forces a genuinely new retained part.

The important result to watch is not whether the final program is physically tiny. It is whether a modest semantic vocabulary continues to support richer household behavior while retaining explicit evidence, safe publication, strong negative-answer discipline, and small local proofs.