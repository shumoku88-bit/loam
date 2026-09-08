# Current cycle workspace: qualification and staging

## Authority and scope

HRA remains operational household authority. This work composes LOAM's existing
Application/Review/Publisher boundaries; it does not retain Budget, Cycle,
remaining, scheduled totals, or SafeToSpend authority.

## 2026-09-08 initial recheck

- LOAM remote main: `15bcc2928e58d03a8b061c56a232f55d437c1bd8`.
  Local main was two commits behind and was fast-forwarded before branching.
- loam-data local and remote main: `2e2c7058353e443868d04a7a1391c0c75b140d07`.
  No tracked uncommitted changes; neither repository had an open PR.
- `feat/tui` was not used as a starting point.

### Concrete seam: current entitlement and editor date

CurrentCoverage bounded Actual consumption but used all-retained Capacity.
`capacity-11` grants stock food 1180 and `capacity-12` grants general living
5546; **both** have retained effective date 2026-10-08. The user's stated intent
was current-cycle correction as observed on 2026-09-08.

Capacity session passed Home's selected date into Transfer and Rebalance.
The session must instead receive only observedAt for Capacity editor defaults;
Home selected day remains meaningful for Actual and Scheduled recording.
Explicit editing of a future effective date remains allowed.

Current decision Entitlement selects the closed elapsed interval
`currentWindowStart <= effectiveOn <= observedAt`. Missing or orphan effective
evidence rejects the answer, including an orphan-only image with no Purpose
rows. Historical BudgetWindow stays half-open. Actual correction frontier and
Scheduled current-open lifecycle/routing are unchanged.

### Dogfood recovery boundary (not performed)

Inspection found no Capacity correction/replacement admission or publisher.
CapacityEffective admits one coordinate per movement identity, not a
last-write-wins history. Do not edit the two dates in place or append duplicate
EFFECTIVE entries. CapacityPublisher publishes under writer ownership and
rechecks complete movement/effective evidence; reuse it for any compensation.

An append-only recovery candidate is, for **each** erroneous grant:

1. Publish an equal opposite movement effective 2026-10-08.
2. Publish the intended grant effective 2026-09-08.

This preserves original evidence and cancels its future contribution rather
than pretending the original date was never retained. It is compensation, not
a retained correction relation. These are separate publications, not an atomic
cross-date operation; interruption must be reconciled from receipts and reread
evidence, not blindly retried. Preview and explicit approval are required.
Do not decompose a same-date multi-delta Rebalance into binary transfers.

No household files were changed during this initial qualification. Before any
recovery, recheck git status, both original movement IDs/dates, and newly added
movements. After recovery verify both the 2026-09-08 and 2026-10-08 projections,
plus effective completeness and physical balances (which must not change).
The existing CurrentCoverageDogfood checkpoint describes the **pre-recovery**
answer and must not be silently relabeled as the recovered answer.

## Reused boundaries and following PRs

A. CapacityWindowInspection closed elapsed projection, CurrentCoverageInspection
and CurrentCoverageReview, Transfer/Rebalance date isolation, regressions.

B. Surface-independent CycleFundingInspection: explicit caller-supplied finite
EffectCoordinate selection and JPY measure, BalanceReview physical context, CurrentCoverage rows and one
shared Scheduled frontier. `remainingAssigned = sum(max(row.remaining, 0))`.
Do not compare cumulative allocations with today's assets. Test retroactive
negative-to-zero grants separately from positive future-spending grants.
Keep unmanaged, unrouted, and unresolvedEligibility pressure separate; do not
sum the same global frontier once per Purpose. Unconfigured selection must be
visible, never inferred from account names or asset roles.

C. Cycle workspace: BoundaryPresetConfig coordinates, shared Funding/Coverage/
Balance projections, local grant preview with a presentation-only deficit
suggestion. No TUI budget arithmetic or automatic publication.

D. Extract ScheduledRoutingCli.recordUnlocked admission/publication into a
shared publisher; CLI and TUI use it. Human chooses managed Purpose or unmanaged.
Reread routing, coverage and funding after publish and return to workspace.

E. Reuse CapacityPublisher.Proposal and atomic balanced publication in existing
Rebalance workspace with shared cycle/funding context.

## Qualification instruments

Executable Lean synthetic tests and the existing real-data checkpoint are the
smallest instruments for this concrete temporal/composition seam. No new formal
tool is needed. Required checks include observation endpoint, pre-start and
future exclusion, missing/orphan evidence, and unchanged pre-recovery dogfood
values. TUI builds and relevant production tests accompany the date change.

## Stage B: pure funding composition

`Loam/CycleFundingInspection.lean` composes existing pure
`BalanceReview.project` with a complete `CurrentCoverageReview.Snapshot`.
It lives alongside these shared Reviews rather than introducing an Application
module that depends upwards on Review/IO adapters. The new function performs
no IO. `BalanceReview.loadSnapshot` and `config/balance-view.tsv` are **not**
used: display selection asks a balance question, not which assets are budgetable.

The caller explicitly supplies `List EffectCoordinate` and `MeasureId`. JPY is
required because the existing CurrentCoverageReview is JPY-only; mixed/wrong
measures are refused rather than coerced. Duplicate coordinates are refused
before BalanceReview can normalize presentation duplicates. Selected balances
require zero-origin evidence and correction-aware projection. A covered
coordinate without activity is a known zero, not missing evidence. Unselected
assets do not contribute, regardless of their names or accounting roles.
An explicit empty list selects no backing; it is not a substitute for absent
configuration. No config adapter or account-name inference is introduced.

The derived summary contains:

- `budgetableBacking`: signed sum of explicitly selected current balances;
- `remainingAssigned`: sum of each row's `max(remaining, 0)`, not headroom;
- `residualBeforeUnresolved`: backing minus remainingAssigned;
- `unmanagedFuturePressure`, `unroutedFuturePressure`,
  `unresolvedFuturePressure`: the global frontier copied once.

Managed Scheduled commitment is already inside remainingAssigned and must not
reduce assignment a second time. A -20 -> 0 retroactive fill leaves assigned
funds unchanged; 0 -> +20 increases them by 20. Likewise -5546 -> 0 reserves no
new money, while -5546 -> +1000 reserves 1000. Neither negative physical backing
nor a negative residual is clamped. The three global pressure quantities stay
separate; they are not automatically deducted or labeled available/safe to spend.

### Nearby composition qualifications and caller obligations

- Missing Scheduled frontier (`none`) fails visibly. CurrentCoverageReview may
  currently produce this when there are no Purpose rows; absence must not be
  invented into a zero frontier. No new Scheduled engine is added to work around it.
- Duplicate Purpose rows are rejected, preventing accidental repeated assignment.
- Caller supplies the complete current snapshot, not a filtered display subset,
  and physical evidence from the same current observation. This pure function
  is not historical balance replay and cannot certify independent read epochs.
- Funding reuses BalanceReview's zero-origin/correction refusal; tests include
  corrected physical backing and a missing correction endpoint. No writer or
  recovery behavior changes.

`Loam/Tests/CycleFundingInspection.lean` qualifies requested A-J examples, signed
backing, explicit empty/known-zero selection, absent frontier, duplicate Purpose
refusal and the correction seam. Dedicated exact-head CI runs it alongside
BalanceReview and CurrentCoverageReview tests. No Core primitive, persistence,
TUI, routing write, or household recovery is part of Stage B.

## Stage C: read-only cycle budget workspace

Stage C introduces the read-only cycle Budget workspace (`Loam/Tui/CycleBudget.lean`,
`Loam/CycleBudgetReview.lean`, `Loam/CycleFundingConfig.lean`) accessed via `c` from
LOAM Home.

### Semantic boundaries and evidence flow

- Preserves explicit boundary coordinate: `BoundaryPresetConfig.CurrentWindow` requires
  exactly one configured preset containing `observedAt`. Both preset boundaries are
  retained; the TUI never guesses among multiple report coordinate systems.
- Preserves raw Capacity: `e` from Home remains the direct entrance into all-retained
  Capacity. From Budget, `e` enters Capacity with current coverage, and `b` returns to
  Budget, reloading fresh evidence so that transfer/rebalance actions never leave stale
  Budget views.
- Separate config authority: `config/cycle-funding.tsv` selects budgetable backing
  coordinates. Absence is an explicit refusal, not an empty list. Balance display
  (`config/balance-view.tsv`) remains an independent question and cannot grant or revoke
  backing authority.
- No budget arithmetic or automatic actions: the workspace maps loaded Review answers
  directly. Future pressures (unresolved, unrouted, unmanaged) are shown separately and
  not summed or deducted into an invented safe-to-spend figure.
- Date independence: navigation focus on Home does not alter the Budget observation
  date; Budget always queries `snapshot.actual.today`.

### Verification and qualification

- `Loam/Tests/CycleBudgetReview.lean`: independent layer failures, configuration parsing,
  duplicate coordinate rejection, non-JPY refusal, filesystem degradation.
- `Loam/Tests/TuiCycleBudget.lean`: rendering, scrolling, layout under degraded layers,
  view paging.
- `tests/test_cycle_budget_tui.py`: real PTY interaction with `loamTui` on isolated
  synthetic evidence, verifying `c` entrance, focus independence, Capacity transition,
  `b` back-navigation, clean exit, and zero disk mutation.
- `Loam/Tests/CycleBudgetDogfood.lean`: read-only verification against the 2026-09-08
  checkpoint in `loam-data`.

