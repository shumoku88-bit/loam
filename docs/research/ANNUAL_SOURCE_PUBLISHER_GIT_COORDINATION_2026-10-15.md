# Calendar-year Git journal: native publication boundary and crash coordination audit

Date: 2026-10-15
Status: **research-only Phase 0 audit; no production journal or authority change**
Tracking: [storage #1969](https://github.com/shumoku88-bit/loam/issues/1969)
Base: `main` `1c279504aa5367048b2c4d115d9c841a06388a8f`, after merged #2017
Related: [Daily Pace publication protocol](DAILY_PACE_AUTOMATIC_KNOWLEDGE_PROTOCOL_2026-10-15.md), open draft #2004 (Daily Pace-specific writer closure), [annual head recovery](ANNUAL_SEGMENT_COMMIT_RECOVERY_2026-10-15.md), [native cross-family Git witness](CROSS_FAMILY_SOURCE_YEAR_PUBLICATION_2026-10-15.md).

## Decision under test

One normal user action has **one admitted semantic Household generation**, even when it changes several evidence families. Future calendar-year source journals must record the year in which a publication was *accepted*, not the year of an Event's `validOn`. An accepted 2027 correction to a 2025-effective Event belongs in the 2027 source journal and must not edit an already retained 2025/2026 source journal. Jan 1 is the publication-year boundary; pension cycles and effective-date reporting remain independent.

The present production authority is **one** `household.loam`. Neither `git commit` nor a journal-year label is a production commit point today. This audit does not choose a new physical authority topology, define a new codec, or implement timestamps.

## Current executable publication boundary

Source: `Loam/Authority/HouseholdAuthority.lean`.

1. `publishObserved? root observedWire changedNames candidate` takes the existing `WriterOwnership` lock on the Household path, reloads **exact current wire** and rejects stale observations.
2. `changedNames` must be a nonempty subset of the 13 `knownSectionNames`; it cannot name an unknown section. `preservesUntouched` retains every unmarked section byte-equivalently and in relative order, including unknown future sections. A semantically equal candidate is refused here.
3. Candidate and staged copy must pass current known-section decoders. Missing sections remain absent during qualification, not silently materialized.
4. The old current wire is staged/read back/qualified and renamed to `household.loam.prev`. The staged new wire is then renamed to `household.loam`. **The final current rename is the program's visible whole-image transition**, not an established power-loss durability or Git atomicity proof.
5. `loadRecoverable?` can explicitly report a qualified previous generation; `restorePrevious?` is a *separate deliberate write*. Neither operation authorizes silently discarding newer accepted source history.

`HouseholdAuthority` does **not** currently accept or persist an admitted local day, stable publication ordinal, cross-generation source receipt, Git object ID, or Git HEAD. Its staged/renamed whole image cannot be made atomically committed with a separate Git ref by adding a Git command before or after the rename.

## Publisher-to-generation map

This is an **examined production-path inventory**, not a formally exhaustive executable call-graph proof. Consult #2004 for the narrower Daily Pace as-known fact classification. Legacy standalone APIs that remain for tests/migration are **not** independent current production authority just because they appear in a source file.

| Source operation / family | Current observed-generation route | Changed Household sections per accepted publication | Boundary consequence for annual source journal |
| --- | --- | --- | --- |
| Ordinary/idempotent Movement, Correction, Actual validity, reversal, FX/OriginalAmount, Settlement, merchant | respective `Loam/Publisher/*` -> `ActualAuthority.publishActual?` -> `publishHouseholdObserved?` | `Actual` | One admission for all TX/effect/correction/date facts in that Actual proposal; successful retry is not a second admission |
| Scheduled create / retire | `ScheduledCreationPublisher` / `ScheduledTerminalPublisher.publishHouseholdCancellation` -> `ScheduledLifecycleAuthority.publishObserved?` | `Scheduled` | A complete lifecycle change; validity of the Scheduled occurrence is not its learned day |
| Scheduled batch replacement | `ScheduledReplacementPublisher.publishHouseholdBatch` -> `HouseholdAuthority.publishObserved?` | `Scheduled`, `ScheduledRouting` | All replacements and inherited routing share **one** publication order/knowledge cut |
| Scheduled completion | `ScheduledTerminalPublisher.publishHouseholdCompletion` -> `HouseholdAuthority.publishObserved?` under Actual ownership | `Scheduled`, `Actual` | Terminal and Actual payment endpoint must never be separate source commits |
| Current reconciliation | `CurrentQuantityAnchorPublisher.publish` -> `CurrentSupportAuthority.publishObserved?` | `CurrentQuantityAnchor`, optionally `CurrentQuantityPresence` | Re-observed values may *replace* support and refine presence; a new timestamp alone cannot reconstruct older as-known state |
| Bounded history support | `BoundedHistorySupportPublisher.publish` -> `CurrentSupportAuthority.publishObserved?` | `BoundedHistorySupport` (depending on actual semantic change) | Retain old support version and admission cut if querying old knowledge |
| Actual / Scheduled routing | `ActualRoutingAuthority.updateHouseholdCurrent?`, `ScheduledRoutingAuthority.updateHouseholdCurrent?` from routing publishers | `ActualRouting` / `ScheduledRouting` | Single routing sections when used alone; do not strip routing when co-published with Scheduled batch |
| Capacity / Attention / AccountingRole | household publishers through `HouseholdAuthority` or `AccountingRoleAuthority.publishObserved?` | `Capacity` / `Attention` / `AccountingRole` | May not affect Daily Pace directly, but must survive full source replay and maintain exact order |
| Locus admission | `LocusAdmissionAuthority.updateHouseholdCurrent?` / `publishHouseholdCurrent?` | `LocusAdmission` | Admission policy is a real household change, not an inferred date/section of Actual |
| ZeroOrigin / OpeningSupport | `ZeroOriginCoverageAuthority`, `OpeningSupportAuthority` production Household readers; no ordinary publisher found in these modules | No normal writer identified by this audit | Preserve the initial/migrated section and explicit absence semantics; do not invent annual zero/opening Events |

`CurrentSupportAuthority.publishObserved?` constructs a candidate for **the subset actually changed** among Anchor/Presence/Bounded; if none changed, it returns the observed generation **without publishing**. Hence a hypothetical universal `publisher called = new journal record` hook is incorrect. Similar no-op/idempotent behavior must be classified across all writers before applying an ordinal.

All 13 current known section identities are accounted for above: Actual, Scheduled, Capacity, Attention, ActualRouting, ScheduledRouting, AccountingRole, LocusAdmission, ZeroOrigin, OpeningSupport, CurrentQuantityAnchor, CurrentQuantityPresence and BoundedHistorySupport. External `daily-pace.tsv`, boundary presets and periods are currently **not** versioned inside this generation, per the Daily Pace protocol. They are a separate as-known policy-adoption gate, not permission to invent a read-time publication date.

## Accepted day + order: required contract, not an implementation

A future *successful semantic publication* should carry a qualified receipt (conceptually `{source generation, previous generation identity, accepted local day, total order, changed family set, source identity references}`) **in the same logical committed authority** as its facts. Exact receipt encoding, local time-zone rule, clock source and whether the ordering unit is image generation or an independent durable integer remain open.

- Establish the chronology **under the shared publisher ownership/commit boundary**, not in each UI, journal-file pathname, Event `validOn`, Git commit time or filesystem mtime.
- A returned no-op, rejected stale writer, failed stage, or already-admitted idempotent retry creates **no new accepted journal publication**. After a crash with an ambiguous reply, requalify committed authority/operation identity before retrying.
- Midnight crossing between preparing a draft, constructing its receipt and the final commit is an explicit clock-definition test. The admitted day cannot silently be the draft-input day. Clock rollback, multi-host time-zone disagreement and two same-day policy winners need ordering/refusal rules.
- Retained earlier snapshots/deltas must remain available for as-known history of **replaceable** support and external policy; solely tagging the latest value with a day is insufficient.
- Restoration of `.prev` must have an explicit chronology/compensating-publication story or refuse historical as-known claims. Reverting bytes without reconciling admitted source membership rewinds history.

**No receipt is currently implemented.** This is a specification of what a future design must prove, not a claim that #2017 supplies an authenticated clock.

## Git vs Household: crash matrix

Let `H0/G0` be the previously admitted Household/source-journal pair and `H1/G1` a proposed accepted successor. Exactly one authority must ultimately decide what readers may trust; current LOAM has no durable two-resource transaction linking Git HEAD and `household.loam`.

| Crash/restart observation | If Household remains the authority (current system) | If Git becomes the authority (hypothetical migration) |
| --- | --- | --- |
| New text/Git objects staged but ref stays G0, H0 | Ignore uncommitted source candidates; old source is current | Ignore unreferenced candidates |
| Git ref moves to G1 while Household remains H0 | **Do not** regard G1 as accepted solely from Git; must identify/undo or reconcile speculative Git progress | Rebuild derived Household from qualified G1 **only** if Git head/segment durability, closure and freshness are independently qualified |
| Household current rename exposes H1 while Git stays G0 | Household H1 is visible; journal is behind. Without an in-H1 admitted receipt, reconstructing its trusted acceptance day is **not established** | H1 is a speculative/recoverable derived cache and must not override G0 |
| Both appear G1/H1 with matching identities | Logical agreement alone does not prove crash durability or independent anti-rollback | Same |
| Git HEAD validly rolls back G1 -> G0 | Current Household H1 and selected Git G0 disagree; do not silently backdate or erase H1 | Old Git history can still be valid; rollback **cannot** be detected without an independently trusted freshness source |
| `household.loam` malformed but `.prev` valid | Explicit previous recovery candidate, **not** automatically accepted as up-to-date history | Must rebuild/qualify against the designated Git commit point; do not silently select incomplete segments |

`HouseholdAuthority.publishObserved?` currently has **two separate rename calls**: previous backup then current. There is no demonstrated fsync of file data and parent directories in this function. Its staging/requalification and lock/stale guarantees are valuable, but are not a proof of sudden-power-loss ordering. Nor can a Git commit be treated as a transaction encompassing those two renames. A dual-write approach without a unique committed head and reconstruction/repair proof is **blocked**.

## Evidence reused, falsifications and next gate

- #2017: real `ScheduledTerminalPublisher.publishHouseholdCompletion` changed Actual + Scheduled in one synthetic native generation; a paired 2027 Git journal section publication replayed exactly and rejected missing halves. **The 2027 day was injected by the fixture.**
- `tla/CompleteImagePublication.tla`, `tla/AnnualSegmentCommitRecovery.tla`, `tla/DailyPaceAutomaticKnowledge.tla` and `tla/BitemporalCorrectionFrontier.tla` already capture whole-image cut, immutable old segments, one learned cut and valid/learned separation. Do not start a new general persistence framework.
- Refusal witnesses still needed against a **concrete proposed Git/Household protocol**: crash after Git ref before Household rename, crash after Household rename before Git ref, retry after acknowledged-vs-ambiguous completion, midnight handoff, stale writer, explicit restore, clock rollback and valid old Git ref rollback.
- An experiment that simply runs `git commit` after `publishObserved?` and checks success is **not** evidence of atomicity. A research-only fault-injection harness must pin each boundary and compare native admitted source identity/byte replay, without touching `loam-data`.
- Do not create a canonical schema migration, sidecar timestamps, another engine, background daemon, year-end user action or year-index read shortcut in this PR. For Balance / Scheduled / Daily Pace, missing dependency closure still means unavailable, **not zero**.
- Subsequent measured choice: keep Household authority and qualify Git as a *recoverable replica*, or separately design Git as the sole authority with derived Household rebuild. Compare 1/5/10/20-year reads/writes and backup/recovery on identical synthetic fixtures **after** resolving the singular commit-point and accepted-clock obligations.

### Outcome of this Phase 0 audit

**No production change is justified by this inventory alone.** The existing one-generation native publisher remains the safe semantic baseline. The next executable test should be a small crash/receipt experiment at the existing publisher seam, not an independent annual-journal writer. This record is deliberately complementary to draft #2004 and does not claim its writer-closure audit is merged.
