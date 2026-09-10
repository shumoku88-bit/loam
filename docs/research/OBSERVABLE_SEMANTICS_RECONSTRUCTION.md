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

## Q_write reconstruction

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

Existing observations already cover the novel write pressure, so no new Q-write observation is currently justified:

- Obs. 177: required positive RelationUnit support precedes Event activation; routine negative `NoRelation` state is not earned.
- Obs. 178: `(EventId, RelationUnitId)` alone cannot determine partial fulfillment; exact discharge quantity is independent information.
- Obs. 182: discharge-first/Event-last publication and Event-first acquisition prevent false outstanding answers; pre-Event residue can remain inert.
- Obs. 183: raw discharge targets reserve future RelationUnit identity so unrelated allocation cannot activate stale provenance.
- Obs. 241: known-empty Reversal authority and unavailable Reversal authority differ for correction admission, while physical container shape is irrelevant to that distinction.

## Q_safe reconstruction

`Q_safe` is not another household ontology. It is the set of invariants required so `Q_read` and `Q_write` are never strengthened by torn, stale, or ambiguous evidence.

| Safety question | Existing witness / implementation | Current result |
| --- | --- | --- |
| Must semantically related facts occupy one atomic file/image? | Obs. 055 | no; atomic bundle is sufficient, not necessary; dependency ordering + fail-closed admission can preserve closure |
| May a UI action admitted when rendered remain authorized later? | Obs. 118 SPIN | no; re-read and re-admit at activation |
| Can auxiliary evidence precede a fresh Event commit and survive crash? | Obs. 129 | yes when pre-Event evidence is inert; exact prepared candidate supports restart/idempotence |
| How may fresh RelationUnit support activate? | Obs. 177 SPIN | positive support before Event; Event-before-relation reader acquisition for that protocol |
| How may fresh RelationDischarge support activate? | Obs. 182 SPIN | discharge before Event; Event-before-discharge acquisition; missing-later-Event residue stays inert |
| Can dangling discharge references release their identities for unrelated reuse? | Obs. 182 / 183 SPIN | no; both Event and RelationUnit target namespaces require reservation where raw provenance names them |
| Does atomic replacement alone prevent concurrent stale overwrite? | production `WriterOwnership` + `WriterOwnershipPersistence` | no; own from authoritative re-read through publication |
| Is unavailable authority equivalent to explicit known-empty authority? | Obs. 241 | no; selected mutation can distinguish them |

The resulting small safety vocabulary is currently closer to:

```text
re-admit on current world
exclusive writer ownership over read/prepare/admit/publish
support before semantic activation where required
reader acquisition order matched to publication order
inert pre-activation crash residue
identity reservation across dangling retained provenance
fail closed on unresolved active evidence
preserve unavailable vs known-empty when Q distinguishes them
```

than to a generic transaction ontology.

### Observation 240 / PR #692

Observation 240 proves a useful representation-free lemma:

```text
all required evidence ranks before activation anchor
  -> every crash prefix exposing the anchor also exposes its requirements
```

and the converse wrong-order witness.

In the answer-first reconstruction this is **not a new `Q_safe` requirement**. Obs. 055, 129, 177 and 182 already supplied concrete publication-pressure witnesses. Observation 240 is therefore best classified as a candidate **mechanic extraction** over existing obligations.

Merge discipline remains:

```text
new generic theorem
  -> must replace/simplify an existing live proof obligation or duplicated production rationale
  -> otherwise keep it out of the live working set
```

Observation 240 does not replace the reader-order, orphan-inertness, restart, or identity-reservation results. Its possible dividend is only the common activation-order fragment. Until that dividend is made concrete, #692 should not be treated as required by this reconstruction.

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

## First concrete re-compression candidate: Scheduled terminal evidence

The answer-first pass exposed one important difference between **independent information** and **independent Core families**.

Current production represents Scheduled terminal meaning as three separate semantic memories:

```text
ScheduledCompletion
  ScheduledId -> EventId

ScheduledRetirement
  ScheduledId

ScheduledReplacement
  ScheduledId -> ScheduledId
```

This separation grew incrementally. Completion became practical first, retirement followed as a separate small slice, and replacement arrived much later. At each introduction, refusing a general lifecycle framework was a reasonable anti-abstraction guardrail.

But Observation 105 had already qualified a smaller semantic representation:

```text
LifecycleEdge
  source : Scheduled
  target : lone Endpoint

Movement target   -> completion
Scheduled target  -> replacement
no target         -> retirement
```

That model also showed:

- a terminal/open summary alone is too small;
- completion/retirement/replacement kind sets alone are too small when successor identity differs;
- the target-preserving lifecycle edge determines the selected Scheduled lifecycle views;
- postpone/advance/same-day replacement derive from source/target dates rather than stored operation kinds.

The present implementation later added important operational pressure that Observation 105 did not model directly:

```text
dangling completion Actual endpoint is inert until the Event exists
unknown Scheduled endpoints fail closed
replacement cycles fail closed
cross-kind terminal conflicts fail closed
raw publication/retry behavior must remain safe
```

Therefore the correct modern question is **not** whether completion, retirement and replacement meanings may be erased. They may not. The question is:

> Does current LOAM still require three independent retained memory concepts, or can one target-preserving typed Scheduled-terminal relation retain all three meanings and reject malformed/conflicting raw evidence at one boundary?

Observation 226 already grouped occurrence/completion/retirement/replacement into one physical lifecycle image while deliberately keeping their semantic fact types separate. That solved authority topology, not this semantic/type-topology question.

This is the first concrete place where the original answer-first model appears smaller than the mature production type graph.

### Why this matters to the 001-084 hypothesis

This does not show that the later implementation decision was wrong when made. It shows a more precise failure mode that can accumulate after incremental development:

```text
feature A arrives -> narrow typed evidence A
feature B arrives -> narrow typed evidence B
feature C arrives -> narrow typed evidence C

anti-premature-abstraction rule remains active
but
post-maturity re-compression never re-runs the earlier minimum model
```

The likely discipline to restore is therefore:

```text
avoid abstraction before repeated pressure exists
AND
once the family is mature, rerun answer-first semantic compression
```

The second half is the candidate that may have weakened after early LOAM.

No production change is authorized by this finding yet. The next step is to compare the current fail-closed lifecycle contract against a single typed terminal-relation candidate and demand behavior/provenance parity before any implementation refactor.

## Current checkpoint

The answer-first pass has not earned deletion of a household meaning. It has earned two stronger architectural conclusions:

```text
1. Q_read / Q_write / Q_safe are materially smaller when separated.

2. independent meanings need not imply one Core memory/type family per meaning;
   Scheduled terminal evidence is the first concrete re-compression candidate.
```

The current retained answer vocabulary still contains roughly twenty named distinctions when read and write questions are combined, but that number is now an **information vocabulary**, not a lower bound on Core types, files, authorities, or algorithms.

## Stop rule

Do not optimize file count directly, and do not count a mechanism once per semantic user.

```text
wanted answers
  -> independently observable distinctions
  -> smallest information-preserving representation
  -> shared mechanics
  -> write/safety obligations
  -> authority boundaries
  -> physical topology
```

The target is the smallest world description that still gives every selected answer, not the smallest number of files.
