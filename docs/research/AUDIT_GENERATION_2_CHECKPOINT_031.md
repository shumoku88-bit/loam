# LOAM Audit Generation 2 — Coverage Checkpoint at G2-031

Status: **ACTIVE CAMPAIGN — BROAD COVERAGE, TARGETED GAPS REMAIN**

Baseline main:

```text
477bf29d73254db7afb46f434fb926efd0eeafdf
refactor(tui): remove Snapshot from Home transition (#972)
```

This checkpoint catches the Generation-2 campaign up to the repository rather
than the older starting ledger. The original `AUDIT_GENERATION_2.md` remains the
historical launch document; this file is the current coverage view after G2-031.

Generation 2 still follows the same rule:

> Keep only distinctions that have an independent reason to exist; derive what
> can be derived; separate only responsibilities that change for different
> reasons.

DRAKONview and semantic / proof-obligation DAGs remain the primary observation
instruments. Lean, tests, history, reachability, Alloy, TLA+, and ordinary source
inspection are used when the question calls for them.

## Executive checkpoint

The campaign is no longer in its exploratory beginning.

Thirty-one numbered Generation-2 observations now span three broad waves:

```text
G2-001 .. G2-009   read / projection / report topology
G2-010 .. G2-021   write / admission / publication topology
G2-022 .. G2-031   derived summaries, retained state, and TUI/root ownership
```

The important result is not the count. The audit has now produced all three
kinds of healthy verdict:

- **SIMPLIFY / RETIRE** when a retained value, pass, path, or state owner was
  derivable or obsolete;
- **FIX** when a map exposed a real admission or open-world semantic gap;
- **KEEP / STOP** when superficially similar structure had an independent reason
  to remain local or separate.

That mixture is evidence that Generation 2 is not mechanically compressing the
repository.

## Observation ledger

The rows below record the main question or result of each merged numbered
observation. They are a navigation index, not replacements for the detailed DAGs,
DRAKON maps, tests, and PR discussions.

| ID | Surface | Main result / checkpoint |
| --- | --- | --- |
| G2-001 | Actual Review | Mapped admitted read boundary; correction-frontier uniqueness is already owned upstream; KEEP the existing read model. |
| G2-002 | Balance Review | DAG exposed one query-global correction quantity world repeated inside coordinate-local rows; simplification candidate. |
| G2-003 | Balance Review | Qualified one shared correction-aware quantity basis while preserving refusal order. |
| G2-004 | StockFlowReview | Kept one Actual observation interval for the composed flow answer. |
| G2-005 | RoleBalanceReview | Routed each support candidate once through the production support decision. |
| G2-006 | Role balance / current anchor | Shared earned quantity worlds and one selected-cut world where the evidence basis is common. |
| G2-007 | Liquidity / Budget | Qualified obligation topology across conditional liquidity and budget reads without inventing a second semantic engine. |
| G2-008 | Actual routing / AccountingRole | Classified admitted roles once and aligned routing with the same partition. |
| G2-009 | Attention | Mapped the delivery topology and exposed the remaining delivery gap instead of hiding it behind presentation. |
| G2-010 | Scheduled Creation / Replacement | Proved the positive side is derived from retained `BalancedMovement`; removed duplicate positive-total guards. |
| G2-011 | Relation publication | Retired a derived source-resolution pass while preserving the positive-source refusal boundary. |
| G2-012 | Current Actual target | Reached an explicit KEEP-LOCAL stop point rather than forcing cross-writer sharing. |
| G2-013 | Capacity entry publication | Fixed coordinate persistence admission and pinned binary-coordinate refusal. |
| G2-014 | Locus placement | Retired a dead legacy sidecar path helper. |
| G2-015 | AccountingRole publication/review | Closed the current-anchor virginity gap and aligned candidate review with anchor evidence. |
| G2-016 | Opening support / correction | Mapped the correction stop point and retained the earned boundary. |
| G2-017 | Current quantity anchor | Mapped the publication boundary and its independent obligations. |
| G2-018 | Actual/Scheduled routing | Let routing history own the append invariant instead of re-validating it in sibling publishers. |
| G2-019 | Actual Event construction | Let the Core Event constructor own construction admission across correction, completion, and reversal. |
| G2-020 | Current anchor | Fixed missing Locus admission and made legacy fixture assumptions explicit. |
| G2-021 | Locus writers | Closed the writer-surface audit after the admission fix; no additional writer gap remained. |
| G2-022 | Conditional liquidity | Derived conditional summary values instead of retaining redundant answer fields. |
| G2-023 | TransactionsFlowReview | Derived row activity summaries from retained row evidence. |
| G2-024 | ActualReview.Record | Derived `isCurrent` from `replacement.isNone`; removed duplicated currentness state. |
| G2-025 | Actual Review | Kept correction-topology admission but stopped materializing an unused frontier. |
| G2-026 | TUI cursors | Derived total count from displayed rows instead of retaining a second total cache. |
| G2-027 | TUI Actual snapshot | Derived undated count from retained records. |
| G2-028 | Home presentation | Retired the legacy Home renderer after production HRA Home owned the real surface. |
| G2-029 | HRA Scheduled | Fixed the adapter so open-world `Unknown` is not collapsed to empty / NotDue. |
| G2-030 | TUI root | Retired the legacy Main Actual/Scheduled workspace state machine and hidden Tab compatibility entrance. |
| G2-031 | Home transition | Removed the false `Snapshot` dependency from `Main.update` while keeping real Snapshot-backed presentation and known-date behavior. |

## Coverage by semantic area

Coverage means "observed at a useful semantic scale", not "every line has a box".

### 1. Read / report semantics — **BROAD**

Deep or focused Generation-2 pressure has now reached:

- Actual Review;
- Balance Review;
- StockFlowReview;
- RoleBalanceReview;
- conditional liquidity;
- Budget Window obligations;
- Actual routing / AccountingRole partitioning;
- Attention delivery topology;
- TransactionsFlowReview;
- Current Coverage and Cycle Budget from the immediately preceding read-atlas
  work that motivated Generation 2.

This is substantially broader than the original Generation-2 launch document,
whose read-atlas inventory only named Actual Review, Balance Review, Current
Coverage, and Cycle Budget as deeply mapped.

Remaining read-side work should therefore be **targeted**, not another generic
"map all reports" pass. The clearest current candidate is `RoleFlowReview` and
its relationship to the already-observed RoleBalance / Transactions flow family.
The production Reports composition shell is also worth checking only if a
same-generation or duplicated-derived-answer question appears.

### 2. Write / admission semantics — **BROAD**

Generation 2 now covers or cross-compares substantial parts of:

- Scheduled Creation and Replacement;
- relation publication;
- Capacity entry persistence;
- Locus placement and admission;
- AccountingRole virginity / opening support;
- current quantity anchor publication;
- Actual and Scheduled routing history;
- Event construction used by correction, completion, and reversal;
- Locus writer closure.

Together with the pre-Generation-2 write atlas for Record Movement, Correct
Actual, Complete Scheduled, Reverse Actual, and Correct Actual Date, the write
surface is no longer a sparse map.

The best remaining write candidates are families where sibling publishers may
still hide repeated admission or effect mechanics, especially:

- Capacity transfer / rebalance publication compared with the audited Capacity
  entry boundary;
- Attention publication end-to-end, because G2-009 mapped delivery topology but
  did not by itself make the whole Attention lifecycle a same-scale write atlas;
- remaining relation opening / discharge paths if source inspection shows that
  G2-011 did not already cover their relevant common mechanic.

These are candidates, not a queue that must be exhausted.

### 3. TUI / root ownership — **DEEP**

G2-026 through G2-031 form a concentrated ownership pass:

```text
cursor total cache
-> undated count cache
-> legacy Home renderer
-> Scheduled Unknown adapter
-> legacy Main workspaces
-> false Main.update Snapshot dependency
```

The result is a much smaller root semantic surface:

- `Main.State` owns Home date focus plus notice;
- object workspace state belongs to `SelectedDay`, `HraActual`, and
  `HraScheduled`;
- Home household evidence remains a read / presentation dependency, not a root
  navigation-state dependency.

Further TUI/root compression should therefore require new concrete pressure.
Generation 2 should not keep mining this area merely because recent results were
productive.

### 4. Module granularity — **CALIBRATED, SEPARATE TRACK**

The Module Granularity Audit has supplied an orthogonal physical-boundary check.
Merged MGA-001 through MGA-014 established that raw file count and one-consumer
count are candidate signals, not verdicts.

Important calibration results include:

- retired unreachable `Loam.Sha256`;
- KEEP boundaries for compact independent codecs/config/shared laws;
- qualified Session boundaries for Record, Correction, and Scheduled
  Replacement effect shells;
- rejected split for `ActualDateCorrection`;
- mixed Scheduled-family result rather than suffix symmetry;
- zero production-like modules unreachable from declared Lake roots at the
  MGA-014 checkpoint.

PR #974 / MGA-015 is deliberately **outside this main baseline**. Its branch
ledger currently classifies `ScheduledCompletionSession` as
`KEEP_BOUNDARY / SPLIT_QUALIFIED`; the candidate inventory is 334 Lean modules,
91 modules at or below 80 lines, 54 one-consumer modules, and zero
production-like unreachable modules. The PR has not been folded into this
checkpoint baseline, so those numbers are evidence about the candidate, not
about main.

### 5. Obligation DAG coverage — **SELECTIVE BUT MATURE ENOUGH TO GUIDE WORK**

DAGs are no longer a one-off Balance Review experiment. They have been useful
across flow reviews, role/support decisions, liquidity/budget reads, routing,
relation publication, Capacity admission, AccountingRole virginity, retained
summary derivations, and the TUI ownership pass.

The lesson is not to create a DAG for every branch. The useful pattern is now
clear:

```text
branchy or repeated production claim
        |
        v
separate independent obligations
        |
        v
identify which obligations are query-global, row-local, writer-local, or derived
        |
        v
KEEP / FIX / SIMPLIFY with refusal order and authority ownership preserved
```

Straight-line derivations should remain straight-line.

## Current frontier

The next audit should not automatically be G2-032 on the last-touched TUI code.
The best current frontier is ordered by information value:

1. **RoleFlowReview same-scale read audit**
   - compare its evidence basis, row derivations, and role partition with
     `RoleBalanceReview` and `TransactionsFlowReview`;
   - look specifically for copied role classification, repeated Actual reads, or
     retained summaries derivable from rows;
   - KEEP is a valid outcome.

2. **Capacity publication family comparison**
   - compare transfer / rebalance publication against the already-audited Capacity
     entry boundary;
   - ask whether admission, identity, persistence, and reload mechanics repeat or
     genuinely change for different semantic reasons.

3. **Attention end-to-end closure check**
   - use G2-009 as the starting map;
   - determine whether the remaining delivery gap is a missing product entrance,
     a deliberately read-only surface, or duplicated publication topology.

Only after one of those exposes pressure should a production refactor be opened.

## Generation-2 completion criterion

Generation 2 should end because its observation surface stops producing
high-value structural pressure, not because an arbitrary observation count is
reached.

A reasonable closure test is:

- every major production read/report family has either a same-scale audit or an
  explicit reason why deeper mapping is unnecessary;
- every major write family has either cross-path pressure or a recorded KEEP
  boundary for its remaining distinctive mechanics;
- TUI/root has no known duplicate semantic state owner or legacy presentation
  island;
- module inventory has no unexplained production-like unreachable surface, and
  large composition roots retain only responsibilities with explicit KEEP/SPLIT
  decisions;
- two or three consecutive targeted frontier audits produce only KEEP / no-new-
  pressure results.

At that point, continuing to search randomly would be more likely to manufacture
abstractions than to remove unjustified structure. The correct verdict would be
**Generation 2 complete**, with later audits reopened only when new product work
or evidence creates fresh pressure.

## Checkpoint verdict

**Generation 2 is in its late-middle / early-closing phase.**

The campaign has already crossed the main read, write, admission, derived-state,
and TUI ownership surfaces. The remaining work is no longer broad cleanup. It is
hole-filling and falsification: inspect the few still-thin production families,
record KEEP when their distinctions are earned, and stop when new structural
pressure dries up.
