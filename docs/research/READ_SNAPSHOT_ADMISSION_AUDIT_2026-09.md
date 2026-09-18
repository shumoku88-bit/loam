# Read snapshot / same-generation admission audit — 2026-09

Status: **BOUNDED PRODUCTION REFACTOR CANDIDATE**

Baseline:

```text
LOAM main
73c7ae8bcdf38cbddd35b9d24ff8a6dd4a6cbfda
experiment(balance): test proof-carrying support evidence (#1043)
```

## Question

After the Capacity authority topology was normalized, inspect production read
composition for two different problems:

1. one answer reading the same canonical authority more than once without a
   same-generation guarantee;
2. one already-admitted evidence family being revalidated repeatedly inside one
   query.

The goal is not to create a universal household snapshot.

## Existing same-generation repairs

Generation 2 already established the narrow rule:

> Pin only the authority whose repeated observation must belong to one published
> generation.

Current production examples:

### StockFlowReview

`BalanceReview` and `ActualReview` both observe `actual.loam`.

`StockFlowReview.loadSnapshot` therefore wraps both readers in one short
`ActualAuthority.withActualFileOwnership` interval.

### ConditionalBalancePathReview

`BalanceReview` and `ScheduledReview` both depend on Actual.

Their two observations likewise share one short Actual ownership interval.

### CycleBudgetReview

`CurrentCoverageReview` and `BalanceReview.loadEvidence` both observe Actual.

`CycleBudgetReview` pins one Actual generation while preserving all other
failure boundaries independently.

These repairs do not introduce a combined report authority or generic read
transaction.

## Why a universal cross-authority snapshot is not earned

The major report authorities remain independently meaningful.

```text
Capacity
Actual
ActualRouting
Scheduled lifecycle
ScheduledRouting
AccountingRole
ZeroOriginCoverage
OpeningSupport
CurrentQuantityAnchor
```

Current readers do not require those files to form one physical generation.

Important reference seams already have explicit semantics:

- stale OpeningSupport retracts a RoleBalance answer instead of freezing Actual;
- CurrentQuantityAnchor interprets later Actual changes relative to its retained
  reflected-root cut;
- Scheduled terminal evidence is validated against retained Actual identity;
- ScheduledRouting names retained Scheduled identities and loci rather than a
  replaceable file generation;
- AccountingRole and LocusAdmission remain independent policy/classification
  facts;
- Capacity and routing are independently meaningful evidence.

No concrete current query requires a global filesystem transaction over all of
these authorities.

Verdict: **DO NOT ADD GLOBAL READ SNAPSHOT**.

## New concrete duplication found

The audit did find a narrower production mismatch.

### CurrentCoverage

The report already computes Scheduled pressure once for the complete query, but
before this refactor each Purpose projection independently called:

```text
correctionFrontierMemory?
capacityEffectiveEvidenceComplete
```

Therefore for N remembered Purposes the same query-global Actual frontier and
Capacity cross-family completeness could be rediscovered N times.

Additionally `CurrentCoverageReview.loadSnapshotAt` explicitly rechecked
Capacity completeness immediately after `CapacityAuthority.loadRequired`, even
though normalized decoding had already admitted the same relation.

### BudgetWindow

G2-007 already shared one Actual correction frontier across the multi-Purpose
snapshot.

However each Purpose still called the raw Capacity window API, which rescanned
movement/effective cross-family completeness every time.

## Smallest repair

### Proof-carry CapacityEvidence

Strengthen:

```lean
CapacityEvidence Time
```

so it carries:

```text
Capacity movements
+ Capacity effective coordinates
+ proof that both memories reference exactly the same movement identities
```

`ofParts?` remains the admission entrance.

Normalized decoding establishes the proof once. The normalized encoder then
accepts only the admitted type and no longer re-admits the same cross-family
predicate.

Raw Application entrances remain available and fail closed by constructing an
admitted CapacityEvidence first.

### CurrentCoverage query-global frontier

For a non-empty Purpose set:

```text
Actual evidence
  -> correction frontier ONCE

Capacity authority
  -> admitted CapacityEvidence ONCE

Scheduled evidence
  -> pressure partition ONCE

for each Purpose
  -> Purpose-local Consumption from shared Actual frontier
  -> Purpose-local Entitlement from admitted CapacityEvidence
  -> Purpose-local managed Commitment from shared pressure
```

An empty Purpose set still does not introduce a new report-local frontier
obligation.

### BudgetWindow

Keep the G2-007 shared Actual frontier and replace raw Capacity pairs in the local
Evidence shape with the admitted CapacityAuthority image.

No report arithmetic or persistence semantics change.

## Deliberate non-change

This refactor does **not** make `ActualEvidence` proof-carrying.

Normalized Actual decoding already performs substantial cross-family admission,
but strengthening that type would touch a much larger production surface. The
current concrete pressure only earns sharing one CurrentCoverage frontier, not a
repository-wide ActualEvidence redesign.

That remains a separate Lean-language-power audit candidate.

## Verdict

```text
global multi-authority read snapshot            DO NOT ADD
same-Actual short ownership intervals           KEEP
CapacityEvidence proof field                    ADD
normalized Capacity encoder re-admission        REMOVE
CurrentCoverage per-Purpose Capacity rescan     REMOVE
CurrentCoverage per-Purpose correction frontier REMOVE
BudgetWindow per-Purpose Capacity rescan        REMOVE
raw fail-closed Capacity APIs                    KEEP
ActualEvidence type redesign                     DEFER
```

The intended rule is:

> Share a generation or admission exactly where one answer reuses the same
> authority fact. Do not turn independent household authorities into one giant
> snapshot merely because one report reads several of them.
