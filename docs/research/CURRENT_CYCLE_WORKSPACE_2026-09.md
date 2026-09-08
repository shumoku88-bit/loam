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
Locus selection, BalanceReview physical context, CurrentCoverage rows and one
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
