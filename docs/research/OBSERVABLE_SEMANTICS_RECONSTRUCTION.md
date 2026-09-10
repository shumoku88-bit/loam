# Observable semantics reconstruction

Status: **working answer-first reconstruction; no production or loam-data mutation authorized**

Baseline: `f79c4a474932da5ce9fd6e4192ebb18062dd6b6c`  
Tracking: #693 / draft PR #695

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

Minimality is vocabulary-relative. Keep three answer sets separate:

```text
Q_read   current read/report/administration answers
Q_write  admission, preview, publication success/refusal
Q_safe   crash/recovery/corruption/concurrency obligations
```

A surface may contain more than one set. Reading current administration state is `Q_read`; deciding whether a proposed mutation is admitted is `Q_write`.

## Current Q_read map

| Desired answer | Current owner | Retained semantic inputs | Query/config input |
| --- | --- | --- | --- |
| What actually happened? | `ActualReview` | Event, ActualValidity, EventDescription, EventCorrection | selection/filter |
| What is still scheduled / due? | `ScheduledReview` | ScheduledOccurrence, Completion, Retirement, Replacement, Event closure | date |
| What is the current selected balance? | `BalanceReview` | Event, EventCorrection, ZeroOriginCoverage | coordinate selection |
| What Capacity exists? | `CapacityReview` | CapacityMovement | none |
| What applies in a window? | `BudgetWindowReview` / Capacity inspection | CapacityMovement, CapacityEffective, Event, EventCorrection, ActualValidity, ActualRouting | window |
| What remains after spending and future pressure? | `CurrentCoverageReview` | composed below | windows, observation date |
| Which current Expense loci are routed? | `ActualRoutingReview` | LocusAdmission, AccountingRole, ActualRouting, CapacityMovement | observation date |
| Why did selected balances change? | `StockFlowReview` | inherited Balance + ActualReview basis | window |
| Which Events contributed where? | `TransactionsFlowReview` | inherited ActualReview basis | window |
| What conditional balance path follows? | `ConditionalBalancePathReview` | inherited Balance + current-open Scheduled basis | observation date, completeness assumption |
| What is the current cycle funding picture? | `CycleBudgetReview` | inherited CurrentCoverage + Balance basis | preset/selection/date |
| What needs Attention? | `AttentionReview` | AttentionItem, AttentionClosure | source availability |

Accounting `UNAVAILABLE` and unconditional Liquidity `UNKNOWN` are deliberate evidence-limit answers. They do not earn extra retained household state merely to produce a stronger-looking report.

## CurrentCoverage is already a small algebra

```text
Entitlement
  <- CapacityMovement + CapacityEffective + elapsed window

Consumption
  <- Event + EventCorrection + ActualValidity + ActualRouting + elapsed window

Commitment
  <- current-open Scheduled lifecycle
     + AccountingRole + ScheduledRouting + future horizon

Remaining = Entitlement - Consumption
Headroom  = Remaining - managed Commitment
```

`Remaining`, `Commitment`, `Headroom`, unmanaged pressure, unrouted pressure and unresolved eligibility are projections, not additional stored budget objects.

Observation 243 reduces this further to answer-determining dimensions rather than current type boundaries. Alloy found worlds with equal Headroom but different visible unmanaged/unrouted/unresolved pressure. Therefore a Headroom-only vocabulary admits stronger compression than the present full CurrentCoverage answer.

## Q_read witness index

Do not mint a new observation when an earlier one already supplies the counterexample.

| Retained distinction | Current Q_read pressure | Existing witness / law | Status |
| --- | --- | --- | --- |
| Event + signed Effects | Actual, Balance, flow reports | base observed quantity evidence | WITNESS |
| ActualValidity | dated Actual / historical Consumption | Obs. 111 | WITNESS |
| EventDescription | recognition/search of otherwise quantity-identical Events | Obs. 130 Lean proofs | WITNESS |
| EventCorrection | current Actual / Consumption frontier | Obs. 114 two-world correction witness | WITNESS |
| ZeroOriginCoverage | answerable balance vs coverage missing | current `ZeroOriginQuantity` law | WITNESS |
| CapacityMovement semantic plane | Entitlement distinct from physical holdings | Obs. 106 | WITNESS |
| CapacityEffective | windowed Entitlement | Obs. 112 / 158; Obs. 243 current witness | WITNESS |
| ActualRouting | Purpose Consumption and routing administration | Obs. 111; Obs. 243 current witness | WITNESS |
| LocusAdmission | current routing-administration vocabulary | direct production dependency; write policy also observes it | WITNESS, representation open |
| AccountingRole | Expense administration and Scheduled pressure eligibility | Obs. 049 / 227; Obs. 243 frontier pressure | WITNESS |
| ScheduledOccurrence | future expected quantity/date distinct from Actual | Obs. 105 family | WITNESS |
| ScheduledCompletion | explicit Scheduled -> Actual realization | Obs. 105 family | WITNESS |
| ScheduledRetirement | why an expectation is no longer open | Obs. 105 family | WITNESS |
| ScheduledReplacement | supersession / successor provenance | Obs. 105 / 122 | WITNESS |
| ScheduledRouting | managed/unmanaged/unrouted pressure | Obs. 108 / 153 / 227; Obs. 243 | WITNESS |
| AttentionItem | non-financial actionable matter + due meaning | Obs. 109 | WITNESS |
| AttentionClosure | resolved/dropped lifecycle distinct from provenance | Obs. 109 | WITNESS |

`WITNESS` protects information, not the current type, filename, sidecar, authority count, or container shape.

## Q_read result that changes the earlier 18-family audit

The broader Phase-2 audit asked about the current product as a whole. The narrower reconstructed `Q_read` graph does not consume:

```text
ActualReversal
RelationUnit
RelationDischarge
```

That is not a deletion result. It is evidence that read semantics and mutation semantics had been counted together.

## First Q_write reconstruction

Current production writers answer questions such as:

```text
May this Movement be admitted?
May this correction replace the selected Actual?
May this exact reversal be published?
Which fresh identities remain legal?
```

The three families absent from `Q_read` immediately reappear here.

| Retained distinction | Current write answer it changes | Existing evidence | Q_write status |
| --- | --- | --- | --- |
| RelationUnit | Movement relation frontier, source coverage, correction/reversal independence | Obs. 172-177 + current `MovementAdmission` | WITNESS |
| RelationDischarge | exact partial fulfillment, target frontier, fresh Event/Relation id reservation, correction/reversal independence | Obs. 178, 182, 183 + current `MovementAdmission` | WITNESS |
| ActualReversal | correction admission, reversal retry/currentness, identity reservation | Obs. 241 + current `CorrectionPublisher` / `ActualReversalPublisher` | WITNESS |

So the useful factorization is currently:

```text
read projection basis
  does not require RelationUnit / RelationDischarge / ActualReversal

write admission basis
  does require them
```

This creates pressure to keep mutation-only evidence out of read projection machinery where possible, without erasing it from the household world.

### Why no new Observation 244 yet

Existing observations already cover the novel semantic pressure:

- Obs. 177: required positive RelationUnit support must precede Event activation for fresh Movement; no routine negative `NoRelation` fact is earned.
- Obs. 178: `(EventId, RelationUnitId)` alone cannot determine partial fulfillment; exact discharge quantity is independent information.
- Obs. 182: discharge-first/Event-last publication plus Event-first acquisition prevents false outstanding answers; pre-Event discharge residue can remain inert.
- Obs. 183: raw discharge targets must reserve future RelationUnit identity so unrelated allocation cannot activate stale provenance.
- Obs. 241: known-empty Reversal authority and unavailable Reversal authority produce different correction-admission answers, while container shape remains representation.

A new model would currently duplicate those witnesses rather than reduce uncertainty.

## Semantic regions and shared mechanics

The older household-minimum-vocabulary checkpoint remains a useful factorization target:

```text
household semantic regions
  Actual
  Scheduled
  Capacity
  Attention

cross-cutting mechanics / evidence dimensions
  quantity + signed Effects
  time
  context
  lifecycle / provenance
  routing
  classification
  completeness
  admission
```

Observation 242 reconstructs the current read graph in these terms. Shared mechanics do not imply shared semantic authority. Actual and Capacity can reuse quantity algebra; Actual and Scheduled can reuse routing mechanics; several families can reuse lifecycle/replacement machinery while still answering different household questions.

## Next pressure: Q_safe without theorem inflation

Before adding a new generic safety theorem, map current safety obligations onto existing witnesses:

```text
activation ordering
reader acquisition ordering
crash residue inertness
identity reservation
writer ownership / lock order
malformed authority refusal
known-empty vs unavailable
recovery / retry idempotence
```

Prefer Obs. 055, 059, 129, 177, 182, 183, 240/241 and current production proofs when they already determine the answer. Add a new observation only for a safety distinction left genuinely unresolved.

## Stop rule

Do not optimize file count directly, and do not count a mechanism once per semantic user.

```text
wanted answers
  -> independently observable distinctions
  -> shared mechanics
  -> write/safety obligations
  -> authority boundaries
  -> physical topology
```

The target is the smallest world description that still gives every selected answer, not the smallest number of files.
