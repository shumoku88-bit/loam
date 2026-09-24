# LOAM Audit Generation 2 — visual and obligation coverage ledger

Status: **HISTORICAL LAUNCH / LEDGER — GENERATION 2 CLOSED AT G2-034**

Generation-2 baseline: `8942f6ea68f20b16eeb02f097ecc67fa3ca13ccb` (`#912`)

The campaign is closed by `AUDIT_GENERATION_2_CLOSURE_034.md`. This file remains as the launch and early observation ledger; campaign-specific DRAKON builders have graduated to Git history.

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

- Actual Review
  - normalized Actual read boundary
  - correction-frontier admission
  - Actual-validity admission
  - transient record projection
- Balance Review
  - evidence/config read boundary
  - per-coordinate zero-origin gate
  - correction-world quantity obligation
  - cross-row shared-obligation pressure
  - qualified shared correction-aware quantity basis
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

Audit obligation DAGs:

- Balance Review current quantity
  - coordinate-local zero-origin coverage
  - one shared Event/correction quantity world
  - coordinate-local quantity projection
  - row justification
  - refusal-order constraint on sharing
  - qualified production factorization in G2-003

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

## Generation-2 observations

### G2-001 — Actual Review read boundary

Instrument: source inspection plus read-path DRAKON mapping.

`ActualReview.loadRecordsFromActual` loads one normalized `ActualEvidence` image.
`recordsFromActualEvidence?` then refuses unless both of these independent
admission boundaries succeed:

- `correctionFrontierMemory?`, establishing one current Event frontier from a
  closed, acyclic, source/successor-unique correction relation;
- `admittedActualValidityMemory?`, establishing one admitted current occurrence
  date per Event.

Only after both admissions does the read boundary project transient `Record`
values. `isCurrent` is derived from frontier membership; `date` is derived from
the admitted validity memory; description and replacement labels are projected
from the same already-loaded Actual evidence.

The visual audit exposed one non-local proof obligation. Raw
`EventCorrectionMemory` guarantees only that an exact target/replacement edge is
not duplicated. It does **not** by itself prohibit two different replacement
edges from sharing one target. The later `replacement` lookup in Actual Review is
nevertheless deterministic because record projection is control-dependent on a
successful `correctionFrontierMemory?`, whose generic `ReplacementFrontier`
admission requires source uniqueness before the projection can run.

Verdict: **KEEP**.

No second correction model, read-specific replacement index, public Evidence API,
or proof-only routing layer is justified. The existing frontier admission already
owns the required uniqueness obligation and the read path consumes it in the same
function before projection. Revisit only if target-based replacement lookup is
later moved outside an admitted correction-frontier boundary, or if production
semantics begin admitting branching correction relations.

### G2-002 — Balance Review obligation topology

Primary instruments: **DRAKONview + proof-obligation DAG**.

The DRAKON pass separates three scales that are nested in the G2-002 source:

- evidence/config work performed once for the answer;
- the coordinate-local zero-origin gate;
- correction-world admission reached from inside each covered row.

`BalanceReview.collectRows` called `inspectZeroOriginQuantity` for each selected
coordinate. A covered coordinate delegated to `inspectQuantity`. When correction
facts existed, that in turn checked correction-reference closure and asked
`correctionFrontierMemory?` for one admitted Event frontier before projecting the
coordinate quantity.

The DAG exposed an important factorization. For coordinate `c`, row success
requires:

```text
zeroOrigin(c)
+
sharedQuantityWorld(events, corrections)
+
quantity(c, sharedQuantityWorld)
```

Only the first and third obligations depend on `c`. The correction world depends
only on the shared Event/correction memories supplied to the whole
`BalanceReview.project` call. The G2-002 row loop therefore re-evaluated one
query-global obligation for every covered coordinate.

This is structurally analogous to earlier Current Coverage pressure where
query-global Scheduled work had leaked into Purpose-local projection.

The DAG also prevented an unsafe eager refactor. Rows are inspected left-to-right.
An uncovered earlier coordinate can refuse before correction admission is
attempted, while an earlier covered coordinate can expose a correction failure
before a later uncovered coordinate is reached. Hoisting correction admission
ahead of every zero-origin gate would therefore change observable refusal
ordering.

Verdict at G2-002: **SIMPLIFY CANDIDATE CONFIRMED; production change deferred to
qualification**.

The detailed DAG and refusal-order examples live in
`docs/research/BALANCE_REVIEW_OBLIGATION_DAG.md`. The historical G2 DRAKON map and its builder graduated from the working tree after campaign closure; Git history retains the exact renderer.

### G2-003 — qualify one shared Balance Review correction basis

Primary instruments: **DRAKONview + proof-obligation DAG + Lean production tests**.

The G2-002 lazy-cache sketch can be simplified further. An uncovered coordinate
terminates `BalanceReview.project` immediately, so a non-empty projection reaches
any later row only after the **first** coordinate has passed zero-origin coverage.
There is no need to thread an Option cache, thunk, or new inspection context
through recursion.

The qualified production shape is:

```text
eraseDups coordinates

empty?
    yes -> return empty Snapshot

first coordinate covered?
    no  -> return its zero-origin diagnostic
    yes -> resolve one correction-aware Event quantity basis

basis admitted?
    no  -> return the existing correction diagnostic
    yes -> project first row

remaining coordinates, left-to-right
    uncovered -> return that zero-origin diagnostic
    covered   -> project from the SAME Event basis
```

`BalanceReview` now keeps this factorization private. It calls the existing
`correctionReferencesClosed` and `correctionFrontierMemory?` admission primitives
once per non-empty, first-covered projection and continues to delegate arithmetic
to `EventMemory.quantityAtRecorded`. No public Evidence API, prepared inspection
context, or second quantity arithmetic engine was introduced.

The qualification test pins four distinguishing cases:

- valid correction evidence with multiple covered coordinates;
- empty selection with a broken correction endpoint, which must not force the
  unused correction obligation;
- `[uncovered, covered]` with broken correction evidence, which must return the
  first zero-origin diagnostic;
- `[covered, uncovered]` with broken correction evidence, which must return the
  correction diagnostic before the later coverage gate.

CI qualification for PR #916 succeeded across:

- Compression Audit;
- Selected Lean Observations;
- Cycle Funding Inspection;
- Accounting Projection Basis;
- Production TUI, including the Balance Review build, Balance Review execution
  test, Balances workspace, and downstream Stock-Flow / Transactions-Flow paths.

Verdict: **SIMPLIFY QUALIFIED**.

This is the first Generation-2 case where the DRAKON/DAG observation directly
reduced repeated production semantic work while the DAG also supplied the edge
that constrained the safe implementation order.

## Initial direction

The read atlas currently has the largest coverage gap. Extending visual pressure
beyond Actual Review, Balance Review, Current Coverage, and Cycle Budget into the
other production reports is a natural next place to observe.

The write atlas also remains incomplete and can be expanded when a sibling path
or product change makes comparison valuable.

No fixed order is declared here. Repeated useful results should become practice
naturally rather than being imposed in advance.
