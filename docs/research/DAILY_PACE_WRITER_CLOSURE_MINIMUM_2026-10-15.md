# Daily Pace as-known: writer closure and minimum independent evidence

Status: **research-only writer inventory and design gate; no canonical migration**
Date: 2026-10-15
Repository cut: `main a42f47afd457356075418ab4a48a06b6f14c44e9`
Related: merged PR #2003 (Observation 381); former P0 #1995 was closed at the research PR merge, **although as-known storage and replay are not implemented**.

## 1. The narrower information question

For every local day `d`, reconstruct the end-of-day Daily Pace from knowledge
admitted by that day's cut, with the *then-active* selected balance pool,
explicit cycle boundary, eligible actual quantities, and open Scheduled
protection. Explanation must preserve eligible balance `B`, protected
commitment `C`, optional *separately evidenced* inside-pool reserve `E`, and
remaining days `R`. No reserve `E` exists in the current Daily Pace authority.

`P = (B - C - E) / R` uses the **existing** exact integer-quanta projection.
This audit is about knowledge needed to supply that projection, not a proposal
for another accounting engine or a daily-value snapshot.

The key distinction is between two source families:

1. **Append/retain the old fact**: existing stable ID and correction/terminal
   edge preserve the substance, but publication/learned day is missing.
2. **Replace the current value**: an old state is physically overwritten or
   removed. Even if the date of the update were known, previous policy/support
   contents cannot be recovered from today's authority.

Adding learned days to family (1) does not solve family (2).

## 2. Exact read dependency, not the whole household ontology

Production owners inspected:

- `Loam/Review/CycleSpendingPaceReview.lean`: single-Measure selection,
  current balance, `ScheduledReview.currentOpenRecords`, net selected-pool
  outflow for `scheduledOn < endExclusive`, and integer-quanta division.
  The current path deliberately includes *open overdue* bills and excludes
  future inflow and within-pool transfers from protected deductions.
- `Loam/Review/DailyPacePeriods.lean`: today/current answer plus partially
  supported **current-knowledge restatement**, not a historical as-known
  authority. This module reads `daily-pace.tsv` and
  `boundary-presets.tsv` directly, **outside** the qualified Household
  generation that supplied Actual/Scheduled evidence.
- `Loam/Review/HistoricalBalanceReview.lean` and
  `Loam/Review/CurrentBalanceReview.lean`: correction-aware dated Actual
  evidence, zero-origin/opening/current-anchor/current-presence/bounded-history
  support, with explicit unavailable cases.
- `Loam/Review/DailyPaceChangeReview.lean`: derives change decomposition.
  It is not an independent fact stream.
- `Loam/Authority/HouseholdAuthority.lean`: qualified current image, stale
  generation refusal and a **single previous** image, not a long-term
  publication chronology.

No proof exists that today's reconstructed point was the figure actually seen
on an earlier day. Historic data before a qualified known-time adoption cut
stays `unknown` when answering as-known questions.

## 3. Inventory: each writer that can change the answer

**Class T: source facts/relations already retained; add knowledge membership only.**

| Production path | Existing retained meaning | Minimal absent information | Additional money payload? |
|---|---|---|---|
| `MovementPublisher` | Event/Effects, valid day, optional operation→Event id | Accepted learned-day/publication association for newly admitted Event + related date assertions | **No** |
| `OriginalAmountMovementPublisher`, `ExchangePublisher` | Actual Event and typed original/exchange evidence | Same learned cut for Actual/Event+validity; avoid another time per physical Effect | **No** |
| `CorrectionPublisher` | New Event, `EventCorrection` target→replacement and validity | When replacement + edge became visible **together** | **No** |
| `ActualValidityPublisher` | Identified date revision and correction edge | Learned cut of revision + edge (not the revised valid day) | **No** |
| `ActualReversalPublisher` | Reversal Event, valid day and reversal linkage | Learned cut of reversal publication | **No** |
| `ScheduledCreationPublisher` | Scheduled ID/date/balanced movement | Learned cut of newly admitted Scheduled ID | **No** |
| `ScheduledReplacementPublisher` | Old source→new Scheduled successor; batch may also inherit routing | Learned cut for successor(s) and terminal edge(s), sharing **one** publication cut for a batch | **No** |
| `ScheduledTerminalPublisher` cancellation | Scheduled source→retired terminal | Learned cut of the terminal edge | **No** |
| `ScheduledTerminalPublisher` completion | Scheduled→Actual terminal and completion Actual Event + validity | **One shared** learned cut for both sections in the qualified Household transition | **No** |

A source ID may need no new invented identity: use existing EventId,
ScheduledId, validity revision ID or relation endpoint. Where a relation has no
independent identity, it can be addressed by its already-qualified source/key
and qualified terminal type, provided endpoint uniqueness is preserved.
No extra "open/closed" flag, payment status, derived balance or daily pace.

**Class V: replaceable evidence; a time tag alone is insufficient.**

| Path | What is replaceable today | Minimal new independently observable information |
|---|---|---|
| `CurrentQuantityAnchorPublisher` / `CurrentQuantityAnchor.Evidence.replacingWithGroup?` | Existing coordinate group's assertion and reflected-root cut are replaced by a new group | The **former qualified anchor group/coordinate assertions and cut**, plus the knowledge boundary on which the successor replaced them; do not duplicate the whole household |
| `BoundedHistorySupportPublisher` / `Evidence.withSupport?` / `withoutCoordinate?` | A coordinate's supported start-day claim can be replaced or removed | Previous support value/presence and activation/retraction knowledge cut |
| `CurrentSupportAuthority.publishObserved?` | Current anchor, presence and bounded support may change in one Household transition | One shared publication cut; preserve earlier *availability vs unknown* status if current-presence is refined or dropped |
| `DailyPaceConfig` / `config/daily-pace.tsv` | Pool selection entirely replaceable, currently no retained version/writer | Historical **pool membership versions** and activation/winner cuts; absent/malformed states stay distinct |
| `BoundaryPresetConfig` / `config/boundary-presets.tsv` | Named preset values, boundaries and the currently selected unique applicable cycle may change | Historical **boundary policy versions**, including removed/changed dates and selection, with activation/winner cuts |

A compact change record or immutable policy revision can retain only the
**old/new difference**, but a value that has been overwritten is not recoverable
from its date alone. When preserving a valid source's old assertion is
necessary, that original information, not a second copy of its latest value,
is what earns permanent storage.

**Class S: support/coverage qualification, not another household movement.**

- `ZeroOriginCoverageAuthority` and `OpeningSupportAuthority` currently
  have no ordinary production writer; they are cutover/reconstruction evidence.
  A new as-known reader must not use these retroactively before their adoption
  was known. Treat legacy coverage before qualified adoption as unknown.
- `CurrentQuantityPresence` represents known-present/unknown quantity; it
  can be refined when the anchor is published. Do not erase that historical
  unknown/exact distinction when reconstructing what was known on a given day.
- The as-known result can remain unavailable even if a restated historical
  balance is exact today. Qualifying completeness is not inferred from
  equal endpoint balances or mere absence of additional edits.

**Class N: no direct new knowledge history required *for the current Daily Pace
numeric and explanatory vocabulary*, subject to regression and future scope.**

- `AttentionPublisher`, `CapacityPublisher`, `AccountingRolePublisher`,
  `ActualRoutingPublisher`, `ScheduledRoutingPublisher`,
  `EventMerchantPublisher`, settlement-only claims
  (`SettlementPublisher` / `SettlementActionPublisher`),
  and Locus admission do **not** enter
  `CycleSpendingPaceReview.projectForMeasure` as a separate amount.
  Their mutation does not earn a Daily-Pace-specific known-day tag **solely**
  because it changes the Household image.
- Do **not** ignore an actual Event published alongside another semantic
  operation: its entry is covered by class T. For example, Scheduled
  **completion** changes both Scheduled and Actual. Classify by changed
  retained evidence and read dependency, not by the publisher's name.
- `balance-view.tsv` and `cycle-funding.tsv` are not Daily Pace's
  selection policy. The `MeasurePresentationAuthority` refuses changes to
  the scale of a Measure already used by retained Actual/Scheduled/Capacity/
  current-anchor quantities, rather than silently reinterpreting quanta.
  A future currency migration needs its own distinct qualification.

**Inventory boundary:** this is a source/read dependency census, not a proof
that no alternate executable or manual filesystem writer exists.
HouseholdImage's admitted write seam and CLI/TUI entry points still require
a reachability/closure test before claiming all writers covered.

## 4. Physical authority closure is the real integration cost

Today `HouseholdAuthority.publishObserved?` accepts changed names from the
finite `knownSectionNames` list. Each new known family must have a codec and
qualifier, and its candidate bytes must survive staged typed readback.
Unmarked sections are preserved exactly.

A **knowledge update written after** an ordinary Household rename would not
be atomic with its source. This can produce a committed Event but an unknown
(or falsely guessed) capture day after a crash.

Thus a candidate authority design must publish **one qualified generation**
containing both new semantic evidence and the minimal committed-knowledge
association. An independent sidecar journal is acceptable only if a
separately qualified atomic/recovery protocol actually proves the pair;
this is not established by the existing `.prev` file.

In particular, the existing Scheduled completion already publishes
`["Scheduled", "Actual"]` together. One shared knowledge coordinate should
cover that **transaction**, not two independently timestamped families.

An old-generation restore is another distinct problem:
`HouseholdAuthority.restorePrevious?` replaces the current image with prior
bytes. A retained knowledge stream must represent restore as an explicit
qualified publication or refuse as-known replay across untracked restoration.
Do not equate a saved old generation with its earlier knowledge time on reuse.

### External config writer closure

`DailyPacePeriods.load` reads the two replaceable TSVs outside the Household
generation. The inspected `DailyPaceConfig` / `BoundaryPresetConfig` modules
expose decoders/loaders, **not history-preserving publisher APIs**. A user or
tool can edit these files while LOAM is offline.

Two viable strategies, not yet selected:

1. **Qualified policy adoption into Household authority**. Keep TSV as an
   edit/input convenience, but activate its selected policy through one
   immutable/admitted version and shared generation. For as-known queries use
   the versioned policy, never today's file. External unadopted changes cannot
   silently become historical truth.
2. **Separate committed policy-version authority** with an independently
   specified multi-file atomicity/recovery gate. This preserves file topology
   but adds protocol and crash complexity; it must be compared, not assumed
   cheaper merely because data bytes are fewer.

Neither method may invent a learned time for pre-existing policy from Git
timestamps or filesystem modification times.

## 5. Minimality lower bound and cost model

Let:

- `N`: independently observable appended source/terminal/revision additions,
  potentially multiple additions in one qualified publication;
- `G`: distinct committed *day groups* in which relevant additions occur;
- `V`: changed versions of mutable policy/current-support evidence;
- `D`: number of displayed calendar days;
- `A`: cost of a retained source reference (or zero *extra* bytes when the
  learned-day field is embedded in an otherwise retained record);
- `T`: cost of an explicit learned-day coordinate; and
- `W`: storage of the minimal actual values/diffs of `V` revisions.

Illustrative record-shape cost, **not measured LOAM bytes**:

```text
per-source learned day        <= N * (A + T)
day-bucketed source refs      <= N * A + G * T + framing
mutable policy/support delta  = W + qualified version/winner coordinates
daily pace result snapshots   = O(D * result width) [not needed]
full-generation archive       = O(publications * household image size) [not needed]
```

A single publication's day may be shared across the admitted Event, its date
evidence, its operation receipt, and related terminal/correction edges,
**provided same-publication identity and visibility are proved**. For
ordered same-day policy revisions, either a retained predecessor relation or
a qualified winner/order coordinate remains necessary (Alloy 381).
Do not omit a change merely because today's integer division did not move:
Observation 381's 80/10 = 81/10 but 80/9 != 81/9 example blocks that rule.

Actual amount `B`, Scheduled protection `C`, `F=B-C`, integer `P`,
remaining `R`, drawn dots, explanation breakdown and full-day snapshots
stay derived. No `DailyPaceObservation` or `DailyPaceStatus` authority is
earned by this audit.

Sparse history is not necessarily sparse computation. The query needs a
rebuildable index/checkpoint measured against realistic 1–20 year data, but
read caches do not become a second canonical truth.

## 6. Delivery gate: a small admissible solution, not a universal event store

**Minimum next decision inputs:**

1. Author a mechanical writer-closure matrix from every executable-reachable
   producer of `publishActual?`, `publishObserved?`, and any explicit
   standalone writer. Include idempotent/no-op and multi-family operations.
2. Distinguish append-only source IDs from overwritten current-support and
   policy states; exhibit two-world counterexamples where the old overwritten
   value changes a day-end answer.
3. Select a day-cut contract including local timezone, same-day predecessor,
   correction and policy-winner semantics. Mark incomplete old data unknown.
4. Measure two concrete formats on synthetic changing 1/10/20-year household
   workloads: embedded learned day per new source, versus grouped day with
   source references and version deltas. Measure **bytes, publish-write
   amplification and reconstruct time**. Avoid claiming savings from an
   artificial text encoding alone.
5. Once the physical publication topology is fixed, use TLA+ for atomic
   source+knowledge write, stale rejection, same-day retry, crash, explicit
   restore and unobserved external config changes. Reuse Observation 381's
   Lean list-equivalence proof; a new generic temporal map is unnecessary.
6. Only after the evidence is qualified, route one as-known replay query
   through the current CycleSpendingPaceReview, preserving restated-today as
   an explicitly different answer and supporting honest unknown gaps.

**Recommended leading candidate:** attach the **minimum new learned-time
membership** to already retained source/relation evidence, share one learned
day at the accepted publication group when justified, and retain only
*versions/differences of presently replaceable data that actually affect
the Daily Pace vocabulary*. Versioned policy must have a qualified admission
boundary. New canonical history must not simply duplicate every Household
generation or create a parallel copy of Scheduled/Actual money.

This audit does not certify actual writer closure, choose the final encoding,
retroactively reconstruct legacy past, or complete the formerly P0 as-known
feature. No operational data was read or mutated.
