# Daily Pace automatic as-known history: writer-closure and publication protocol

Status: **executable research, not production authority**
Date: 2026-10-15
Base: main `a42f47afd457356075418ab4a48a06b6f14c44e9`
Predecessors: merged #2003 (Observation 381); draft #2004 (writer inventory).
Live checker: `tla/DailyPaceAutomaticKnowledge.tla` plus five TLC configurations under the existing TLA research workflow.

## Product acceptance criterion

**No daily closing action. No manual "confirm today's knowledge" step. No
periodic daemon or background writing.** The only change to retained knowledge
is made automatically by an ordinary successful **semantic publication** such
as saving a Movement, completing/replacing Scheduled, updating a qualified
balance-support claim, or adopting a versioned policy. An uneventful day
does not add a row, a "closed day", a Daily Pace number, or a pseudo-event.

At a later read, reconstruct the relevant source frontier at
`knowledgeCut=endOfLocalDay(d)` and perform **the existing Daily Pace
projection** using the then-admitted pool, cycle boundaries and coverage.
Calendar days remaining are computed from the queried day; opening the TUI
is not required.

## Writer closure: actual paths, not a new event store

The following *directly verified production seams* cover the key
Daily-Pace-relevant operations:

| Operation | Existing concrete writer / authority | Fact change per accepted action | Research requirement |
|---|---|---|---|
| ordinary / idempotent Movement | `MovementPublisher.publishDraft[Idempotent]` -> `ActualAuthority.publishActual?` -> HouseholdImage | Event + valid-day facts; optional stable operation receipt | retain one knowledge cut for the admitted group, **not a new record on retry** |
| replacement of Actual movement | `CorrectionPublisher.publishCorrection` -> `ActualAuthority.publishActual?` | replacement Event + existing correction edge + valid-day assertion | tie all to one accepted publication |
| validity/date change | `ActualValidityPublisher.publishDate` -> `ActualAuthority.publishActual?` | revision and correction relation | learned day is **not** the revised valid day |
| cancellation/reversal | `ActualReversalPublisher.publishHousehold` -> Actual authority | reversal relation and Actual Event | one cut for the whole admitted change |
| Scheduled creation | `ScheduledCreationPublisher.publishHousehold` -> `ScheduledLifecycleAuthority.publishObserved?` | Scheduled ID/amount/date | one learned cut per accepted creation |
| Scheduled replacement batch | `ScheduledReplacementPublisher.publishHouseholdBatch` -> `HouseholdAuthority.publishObserved?` | multiple successors and terminal edges, possibly routing | a **shared publication cut**; do not infer sequential times |
| Scheduled completion | `ScheduledTerminalPublisher.publishHouseholdCompletion` -> `HouseholdAuthority.publishObserved?` | `Scheduled` terminal **and** `Actual` completion Event/date | one atomic two-section publication plus knowledge |
| Scheduled retirement | `ScheduledTerminalPublisher.publishHouseholdCancellation` -> Scheduled lifecycle authority | terminal edge | learned cut for the retirement |
| current quantity re-observation | `CurrentQuantityAnchorPublisher` -> `CurrentSupportAuthority.publishObserved?` | replaces affected coordinate groups and may refine presence | **retain old value/cut**, not just new timestamp |
| bounded-history support | `BoundedHistorySupportPublisher` -> CurrentSupport authority | replace/remove explicit support start | **retain previous support and its knowledge cut** |
| current pool / cycle policy | `DailyPaceConfig.loadForMeasure`, `BoundaryPresetConfig.load?`, `DailyPacePeriods.load` | today: replaceable TSVs, **not** history publishers | qualify immutable version/winner before claiming as-known |
| restore previous image | `HouseholdAuthority.restorePrevious?` | current authority bytes can revert to an old image | version the restore or refuse as-known replay across it |

Important scope limits: the table is a narrow direct code review, **not yet a
machine-certified exhaustive graph of all executable roots, importers, legacy
file-path APIs or manual filesystem edits**. Other Actual publishers
(`Exchange`, `OriginalAmountMovement`, `Settlement`,
`SettlementAction`, `EventMerchant`) reuse Actual authority; preserve
knowledge only when their changed evidence is observable to the declared
query vocabulary. Other Household writers (`Capacity`, `Attention`,
`AccountingRole`, routing etc.) do not automatically earn a duplicate
Daily-Pace-specific history stream, but any *Actual/Scheduled* evidence
written as part of a compound operation must still be covered.

The current same-generation publication already checks stale observed bytes
and stages/re-reads a candidate. The model adds the **future requirement** of
publishing fact-reference membership and knowledge cut in that same committed
generation. It does not pretend this metadata is currently implemented.

## The small TLC model

The model uses three symbolic operations:

- `move`: one immutable Event reference
- `complete`: a Scheduled terminal **and** an Actual completion event
- `policy`: one immutable accepted policy-version reference

Each symbolic operation is either not committed, or belongs to a *qualified*
publication with a `learned` local-day cut. No duplicate amounts or
snapshots are modeled. `image` represents the admitted fact references and
`knowledge` the retained association to admission day. These two variables
are physically modeled as **one atomic generation transition**.

Positive invariants:

1. **BodyMatchesKnowledge**: no committed reference without matching
   knowledge, and no knowledge reference without committed source.
2. **CompletionAtomic**: Scheduled terminal and completion Actual are
   either both present or both absent.
3. **NoDuplicateOperations**: stable operation identity can be retried but
   cannot produce another admitted change.
4. **PublicationCount**: exactly one revision increase for each committed
   group; no daily or retry generation.
5. **KnowledgeNotFromFuture**, **KnowledgeDaysNondecreasing** and
   **AppendOnlyKnowledge**: no backdating publication, reordering known cuts
   or retroactively rewriting an earlier knowledge view.
6. **UnattendedDayDoesNotWrite**: advancing an idle day cannot alter
   canonical body, chronology, or generation.

The transition system includes staging, atomic accept, a competing publisher
that makes a prepared draft stale, stale refusal, crash with loss of an
uncommitted draft, restart, a committed-operation retry, idle-day advance,
an offline external policy edit and subsequent **first qualified policy
adoption** at the observed day.

Negative controls required to emit *actual counterexamples*:

- **UnsafeSplitActual**: a partially published completion Actual without
  its Scheduled terminal/knowledge violates the body–knowledge invariant.
- **UnsafeRestore**: copying an old Household body while retaining new
  knowledge produces a mismatched authority. Restoring only bytes is not
  undoing history safely.
- **IdleNeverChangesPace**: intentionally false. An unattended day changes
  `R(d)` and can change the quotient despite zero canonical writes.
- **NoCommitAfterAnyCrash**: intentionally false. A staging crash can be
  followed by restart, a fresh prepare, and successful commit.

TLC is a *bounded abstract model checker*. A green run proves these
properties only for the selected finite state system, not for the actual
POSIX rename/fsync/directory durability protocol or all production paths.

## What was already qualified and should not be rebuilt

- `tla/CompleteImagePublication.tla`: stage first, then atomic publication.
- `experiments/application_003_writer_interleaving.tla`:
  earlier writer/snapshot interleaving pressure.
- `tla/BitemporalCorrectionFrontier.tla`: append-oriented valid/learned cuts.
- `Loam/Observations/Observation381.lean`: when group membership is
  retained, date-bucket projection matches per-reference learned-day tags.
- `experiments/381_daily_pace_knowledge_minimality.als`: a same-day **set**
  is not enough to pick an ordered policy winner; a retained successor/winner
  reference remains independently observable.

Do not infer a common knowledge date from an Event's occurrence date,
current list order, Git commits, mtime, or the `.prev` recovery file.

## Open design gates before touching real canonical data

1. **Adoption clock:** select timezone-aware local day at **successful
   publication**, not merely at draft input. Across midnight, retries
   may legitimately acquire a later learned day if the first attempt did
   not commit. Clock rollback, multi-machine writes, and ordering among
   multiple same-day policy versions need qualified rules.
2. **Versioned externally editable configs:** an offline TSV edit is not
   known at its actual edit time. A qualified adoption may be automatic
   on next ordinary use, but it must not backdate the change; old windows
   with unobserved intervals remain unknown. Decide the safe migration
   from direct `DailyPacePeriods.load` config reads.
3. **Mutable support:** preserve prior exact-anchor/support state only
   where as-known queries can observe differences; changing support does
   not justify inventing balances in earlier unsupported periods.
4. **Physical durability:** evaluate encoding changes against
   `HouseholdImage`'s finite `knownSectionNames`, codecs, staging,
   rename, `.prev`, locking and explicit restore. The model is not a
   filesystem crash proof. Avoid detached sidecar metadata.
5. **Measured topology:** compare per-reference date tags vs date-group
   entries + version differences on synthetic 1-, 10-, and 20-year
   workloads for bytes, write amplification and replay time.
6. **End-to-end acceptance:** after selected implementation, verify
   current truth, as-known history, corrections, policy changes, gaps,
   explanations, no-operation days and idempotent retries through actual
   product readers and PTY UI.

If those gates hold, the eventual user action remains exactly:
**record the household facts normally and open Daily Pace whenever desired**.
No per-day confirmation, no service, and no daily historical snapshot.
