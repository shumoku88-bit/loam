# LOAM Audit Generation 2 — visual and obligation coverage ledger

Status: **ACTIVE**

Generation-2 baseline: `8942f6ea68f20b16eeb02f097ecc67fa3ca13ccb` (`#912`)

The first semantic-compression campaign remains valid historical evidence. Its
`SEMANTIC_AUDIT_LEDGER.md` reached a natural checkpoint: the registered SA-001
through SA-010 candidates were implemented, rejected, or given explicit KEEP
verdicts.

Generation 2 starts from a different observation surface.

The central question is no longer only:

> Which concepts or implementations look duplicated in the source tree?

It is also:

> What becomes visible when production paths are drawn at the same scale, and
> when a difficult semantic claim is decomposed into independently checkable
> obligations?

DRAKONview and proof-obligation DAGs are especially useful instruments for this
work. They are not mandatory stages and do not replace Lean, Alloy, TLA+,
Promela, tests, reachability analysis, ordinary code review, or future tools.
The instrument should follow the question.

## Why a second generation

The first DRAKON work already found pressure that the earlier candidate-led audit
had not exposed as clearly:

- repeated Purpose-global Scheduled work became visible beside Purpose-local
  Current Coverage work, leading to one shared `ScheduledPressurePartition`;
- read-atlas inspection exposed retained and copied Cycle Funding echoes, which
  were reduced to independent quantities plus derivations;
- the Cycle Budget diagram exposed two reads of the same normalized Actual
  authority, and obligation-style decomposition led to one short shared Actual
  observation interval without adding new public Evidence APIs;
- write-path comparison exposed small shared mechanics such as sparse Effect
  identity, fixed Scheduled -> Actual ownership order, and raw Correction-target
  membership while preserving different semantic authorities.

The proof-obligation DAG experiment also earned one production-bound example:
`RoleBalanceReview.supportRoute` is shared by runtime routing and the leaf/root
proof obligations rather than mirrored in a second proof model.

These results justify continuing the audit with path topology and obligation
structure as first-class evidence.

## Starting coverage

Coverage means "observed at useful semantic scale", not "every line is drawn".
A path may be mapped without earning a DAG, and a semantic question may benefit
from a DAG without needing a permanent diagram.

### Write-path DRAKON coverage

Deeply mapped at the Generation-2 baseline:

- Record Movement
- Correct Actual
- Complete Scheduled
- Reverse Actual
- Correct Actual Date

These paths already participate in the cross-path write atlas.

Not yet given the same cross-path visual pressure, or only represented at a
higher-level index, include examples such as:

- Scheduled Creation
- Scheduled Replacement
- Capacity publication families
- AccountingRole publication
- routing publication families
- relation opening / discharge publication
- Attention publication and other smaller authorities

This is a coverage inventory, not a mandatory order of work.

### Read-path DRAKON coverage

Deeply mapped:

- Current Coverage
  - read boundary
  - per-Purpose projection
  - Scheduled pressure partition
  - compatibility entrances
  - legacy Headroom composition
- Cycle Budget
  - read boundary
  - Cycle Funding composition

The rest of `07 Projections & Reports` is still largely an index rather than a
same-scale read atlas. Candidate surfaces for future observation include:

- ActualReview
- BalanceReview
- StockFlowReview
- TransactionsFlowReview
- RoleFlowReview
- RoleBalanceReview
- LiquidityReview
- BudgetWindowReview
- AccountingRoleReview
- ActualRoutingReview
- AttentionReview
- other report/review compositions that appear in production

Again, visibility does not imply a refactor is required.

### DAG coverage

Production-bound obligation DAG:

- `RoleBalanceReview.supportRoute`
  - zero-origin leaf
  - opening-support leaf
  - current-anchor leaf
  - unsupported leaf
  - one root partition theorem over the production decision

Obligation-style decomposition has also been useful during analysis of:

- Scheduled pressure / Purpose independence
- Cycle Budget same-Actual-generation observation

Most branchy semantic decisions in LOAM have **not** yet been audited this way.
Generation 2 should therefore not treat DAG coverage as mature or complete.

## What to look for

The map or code may suggest questions such as:

- Why does one sibling path have an extra branch or reconstruction step?
- Are several boxes really one mechanic with different semantic entrances?
- Is a retained field uniquely derivable from neighboring retained evidence?
- Does one composed answer read the same authority more than once and therefore
  permit different generations inside one answer?
- Is a compatibility entrance still exercised, or has it become an empty shell?
- Are two visually similar paths actually different because the canonical thing
  being changed is different?
- Does a branchy decision contain several independent claims that become easier
  to inspect as leaf obligations plus one root claim?

These are examples of useful questions, not admission rules for a method.

## Working posture

A typical successful observation may look like:

```text
production path or question
        |
        v
DRAKON / source / tests reveal pressure
        |
        v
choose the smallest useful instrument
(DAG, Lean, Alloy, TLA+, reachability, tests, ...)
        |
        v
observe or falsify
        |
        v
KEEP, simplify, or add only the distinction actually earned
```

The sequence is intentionally loose. A trivial derivation should not acquire a
DAG merely to satisfy process. A useful DAG should not be rejected because a
previous audit used another tool.

## Generation-2 stop behavior

Negative results remain first-class results.

If a mapped boundary has an independent reason to exist, record KEEP and move
on. If a DAG only restates a straight-line derivation, retire it. If sharing a
mechanic creates more adapters, types, or proof surface than it removes, keep the
local implementations until new pressure appears.

The purpose of Generation 2 is not to make LOAM smaller at any cost. It is to
make the justified structure easier to see, and to expose unjustified structure
that source-local inspection can miss.

## Initial direction

The read atlas currently has the largest coverage gap. Extending visual pressure
beyond Current Coverage and Cycle Budget into the other production reports is a
natural next place to observe.

The write atlas also remains incomplete and can be expanded when a sibling path
or product change makes comparison valuable.

No fixed order is declared here. Repeated useful results should become practice
naturally rather than being imposed in advance.
