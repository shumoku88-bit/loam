# Annual source journal: single-head commit contract (design gate)

Date: 2026-10-16  
Tracking: [#2030](https://github.com/shumoku88-bit/loam/issues/2030), [#1969](https://github.com/shumoku88-bit/loam/issues/1969)  
Status: **design candidate and falsification plan; NOT an implemented protocol, durability proof, or production migration**

## 0. Exact baseline and what is not yet true

The merged #2031 production-publisher regression qualifies **ordinary reads/writes in one existing \`household.loam\`** across Dec 31 / Jan 1. It does not install physical annual source journals. In current production, \`HouseholdAuthority.publishObserved?\` is the one observed-wire/stale-writer guarded publication boundary; it stages and readback-qualifies a whole image, writes a qualified \`.prev\`, then renames staged current. There is no retained qualified admission day, monotonically numbered receipt, Git pin, or demonstrated file/directory fsync durability. The final rename is the program-visible point, not a demonstrated sudden-power-loss guarantee. \`restorePrevious?\` deliberately replaces current bytes but does not prove retained publication chronology.

Research already demonstrates byte-exact native replay for Actual patches and paired Actual+Scheduled replacement, and real SIGKILL disagreement between Git and Household promotion orders. These use **test-injected publication dates**, not a production clock. The abstract annual TLA+ model assumes a durable segment and atomic head: it does not implement a filesystem transaction.

Therefore **no production dual-write of two canonical heads** is authorized. Until a separately qualified cutover, existing \`household.loam\` remains the sole production authority; Git and Tackler files are backups/projections, not a rival source.

## 1. Candidate selection and rejected shortcut

| Candidate | Single source commit point | Decision now |
| --- | --- | --- |
| A. Retain whole \`household.loam\`; Git stores backups and year-filtered **derived** views | Existing native current-image rename | **Production fallback / continued normal operation.** Safest if a split fails qualification. Not a physical canonical annual split. |
| B. Immutable, publication-year source segments plus one manifest/head; a full HouseholdImage becomes a verified **derived materialization** | **One installed, qualified head** referencing durable manifest and immutable source bytes | **Research candidate** for genuine annual canonical storage, subject to gates below. Do not enable in production yet. |
| C. Update HouseholdImage and Git HEAD as equal commit authorities | Two independently promoted heads | **Reject.** Both orderings have demonstrated mismatched crash states; matching old heads cannot establish freshness. |

Git may copy/pin the exact B head and its referents for history/backup **after** authoritative commit. Neither Git author/commit time nor a Git ref is a source admission clock. Tackler parses only its representable *derived effective-date accounting projections*, not native LOAM sections, source-year patches or unknown/zero and Scheduled source evidence.

## 2. Proposed B physical contract, not a finalized codec

\`\`\`text
authority.head                 # sole mutable selected canonical generation identity
objects/<hash>                # immutable qualified manifest objects
journal/2026/<id>-<hash>.loam  # immutable source generation/section delta, by admitted year
journal/2027/<id>-<hash>.loam  # 2027 admissions, including 2026-effective corrections
materialized/household.loam   # optional rebuildable/read-only full-image cache
backup/git                    # external history of already-committed objects/head
\`\`\`

The name layout is illustrative, not production path/schema approval. A **head** identifies exactly one complete manifest; the manifest pins complete segment identities/hashes, predecessor, global source ordinal, changed section set, chronological receipt and declared replay/coverage closure. All changed sections of one semantic operation are in **one referenced source publication**. A content-addressed file alone is never an independent authority; no year directory is independently "current." Entire sections or full images are an initially acceptable fallback when a safe small multi-family delta is not known.

For first cutover, preserve the exact prior qualified full image as the **baseline** with an explicit migration provenance/cut. Never fabricate historic admission dates for events originating in pre-cutover data, or silently claim complete historical "as known on date" views. Preserve recoverable old original bytes out of band. A pre-cutover effective-year report may remain calculable, while past publication-year claims are explicitly unavailable. A no-activity year has **no file** until the first admitted operation in that publication year.

## 3. Required invariants

- **C1, unique selection:** Exactly one committed head selects source evidence for all readers/writers. Materialized HouseholdImage, Git and Tackler never override it. A missing/invalid/ambiguous head refuses, rather than choosing the newest-looking directory.
- **C2, whole semantic action:** A publication is one ordered group of all changed named Household sections. Actual+Scheduled completion, Scheduled+Routing replacement, and Anchor+Presence+Bounded support remain indivisible. Unknown sections survive byte-identically; absent is not silently present-empty.
- **C3, identity and provenance:** Global ordinal and previous-head identity form one qualified chain; no duplicate source operation on retry. Earlier accepted source segments are immutable, even for backdated insertions, date revisions, reversal or correction. Effective date never assigns physical source year.
- **C4, learned/publication day:** One accepted local calendar day, IANA timezone rule and total order are associated with the **accepted group** in the same committed manifest. Not \`validOn\`, Scheduled date, UI draft day, Git clock or mtime. Test-injected clock is allowed only in isolated experiments. Exact timestamp acquisition and trusted-time/rollback policy are still open implementation gates.
- **C5, no publication on observation:** Midnight, idle year, reading a report, a no-op source proposal, failed/stale write and a recognized committed retry create no source generation or empty new-year journal.
- **C6, closed reads:** Head-referenced blobs, source IDs, cross-year correction/reversal/Scheduled completion/replacement edges, policy/support versions and coverage must all qualify for the requested result. Unknown != exact zero; absent != known empty; unclosed read yields **unavailable**, never a plausible partial balance/Daily Pace.
- **C7, crash and restore:** Readers pin one exact head throughout a read. Pre-head staging is invisible. A previous head is **recovery evidence**, not an automatic permission to roll back a newer accepted publication. Explicit restore requires a validated continuity/compensating-publication policy or is refused.
- **C8, durability and stale writers:** Writer ownership plus exact observed head check precedes staging. Durable ordered object/manifest installation and a single atomic/durable head transition must be demonstrated on target platforms before product use. The current Lean rename sequence alone is insufficient.
- **C9, cache and backup:** Derived HouseholdImage/Tackler/index/Git mirror can lag. Pin and verify against source-head identity; ignore or rebuild stale cache. Git cannot commit *for* the source publisher.
- **C10, no false freshness:** Hash integrity proves content, **not** that an old but valid selected head was rolled back. Detecting full valid rollback requires independently trusted monotonic freshness evidence. Without it, never promise guaranteed rollback detection; ambiguous restoration requires explicit operator action and may make post-anchor history unavailable.

## 4. Candidate B commit/restart state machine

Under **one writer-ownership scope** and after an exact observed-head match:

1. Decode/qualify the selected source head and construct the semantic candidate from the same full typed snapshot. Reject unchanged or stale candidates. Reserve a stable operation identity and next source ordinal.
2. Sample the publication local day from a **controlled clock at the final admission boundary**, with a declared household timezone. Require day >= previous committed day; on clock regression or unresolved timezone fail closed. If the day changes during preparation, rebuild/requalify the candidate receipt under the same lock instead of quietly using draft/effective day. The precise sampling-to-head-switch rule requires a fault-injected implementation check.
3. Build one immutable publication containing all changed families plus exact before/after source image IDs. Stage its complete byte representation, re-read and semantically qualify it, verify native reconstruction against the candidate, and verify references and section preservation.
4. Make source objects and a complete manifest durable **before** head can reference them; verify the filesystem-specific file-and-parent-directory sync/rename requirements. No unverified \`IO.FS.rename\` durability claims.
5. Publish **one head** with compare-against-observed semantics as the only commit transition. Readers either see qualified prior head or qualified next head. A head exposing a missing/corrupt referent is an **error**, never a fallback to a convenient old image.
6. After commit, update/rebuild derived HouseholdImage and optionally Git. Treat those steps as **idempotent, recoverable, nonauthoritative follow-up**. A successful source commit with a failed mirror is still committed; report mirror health separately.
7. On restart, verify head, references, predecessor chain/ordinal, replay, current source answer and any available trusted freshness marker. Ignore unreferenced staged/orphan objects. If the response to a write was lost, inspect committed operation identity before retry; never publish the same action twice.

**Important unresolved engineering point:** A calendar day taken before a physical head switch is a *qualified logical admission-day rule*, not a guarantee of the wall-clock instant of durable storage. The exact midnight behavior must be specified and falsified with an injected clock; do not silently label a 2027 commit "2026" because the draft began earlier. Cross-device writers, manually edited refs and clock reversal are unsupported until qualified.

## 5. Concrete crash / wrong-answer matrix

| Injected point or condition | Only acceptable observation |
| --- | --- |
| Before staging or in partial source write | Old head stays authoritative; incomplete bytes invisible |
| Completed staged source, no manifest/head | Old head; staged candidate ignored |
| Durable new source+manifest, before head transition | Old head; new objects are orphans, not source truth |
| Durable qualified head switched, cache HouseholdImage still old | New head authoritative; stale cache refused/rebuilt, never used as the source |
| Git backup succeeds before/after source head or Git fails | No semantic answer change; pinned source head remains sole authority |
| Head references missing/corrupt 2027 segment after partial restore | Refuse current truth rather than showing a 2026 balance or reopening a paid bill |
| Head is well-formed but older than separately trusted freshness | Refuse rollback; never silently load old valid Git/ref |
| Both all-source and freshness evidence rolled back consistently | Undetectable with internal hashes alone: do not claim a guarantee |
| Repeated command after lost success reply | Compare stable operation identity to the committed head, return already-applied/no duplicate or refuse ambiguity |
| Stale writer; clock rollback; unqualified cross-year dependency | Refuse publication and preserve previous qualified head |
| Dec 31 -> Jan 1 with no semantic writes (or first use Jan 3) | No auto-write, new year assigned only on the first accepted admission |
| Accepted 2027 correction of 2026-effective item | New immutable **2027 source** publication; effective **2026 report** changes without mutating 2026 source |
| Jan 2027 Scheduled completion created in 2026 | Actual+Scheduled committed together; no reopen/double deduction after restart |
| Jan 2028 following Jan 2027 | Same algorithm; no 2027 special case or pension-cycle boundary change |

## 6. Read-side performance and selective-year gate

A 2027 current Balance or Daily Pace may depend on old events, corrections, Scheduled endpoints, exact current-quantity anchors and bounded support. The ability to open only \`journal/2027\` **does not follow** from a year filename.

Start with fully pinned reconstruction and native admission for correctness. Only optimize when a checkpoint/index includes a **qualified complete dependency closure** and is tied to the same source head, with an independently reproducible reference replay. Cache summaries do not become financial facts, and no checkpoint turns unknown current history into a zero/complete history.

Measure current-only Balance, current-forward Daily Pace, Scheduled, historical effective-year, corrected cross-year and as-known-at-day separately. Compare whole-image baseline vs candidate B with synthetic 1, 5, 10 and 20-year histories: p50/range, RSS, physical bytes, per-operation writes, Git object count and restore time. A selective read that is fast but loses provenance is a failed result. Keep A if B does not earn its extra complexity.

## 7. Next **disposable** executable slice (not implemented by this decision)

Build one small fixture/harness reusing \`JanuaryFirstHousehold\`, \`NativeAnnualReadProbe\`, \`NativeCrossFamilyYearSource\`, \`research-source-year-cross-family.py\`, and \`AnnualSegmentCommitRecovery.tla\`. Do **not** invent a broad new storage framework or point it at \`loam-data\`.

Acceptance is:

1. Produce H0/H1 from the **real** native Scheduled completion path, plus a backdated correction and later-year append; inject a controlled acceptance clock.
2. Stage B objects/manifest/head only in a temporary synthetic directory. Kill after every physically distinguishable stage/sync/rename boundary and restart via one pinned head; compare exact reconstructed image bytes to H0/H1.
3. Verify old-year source immutability, all 13 families and unknown sections (including absent vs empty), stale writer, no-op, ambiguous retry, clock midnight/regression and Jan 2028.
4. Refuse corrupt/missing segments, stale/mismatched cache, partial restore, split Actual/Scheduled, broken dependencies and wrong manifest/ordinal; report unprovable valid-old-head rollback as an explicit limitation.
5. Record the actual filesystem/OS durability contract, not only SIGKILL. If durable head and freshness cannot be justified, **stop** and keep whole HouseholdImage authority with optional derived year exports.

This document changes **no** production publisher, TUI, config, canonical wire, Git authority, CI lane, migration, or \`loam-data\`. It is a proposal to be falsified, not a declaration of qualified annual source storage.

## Evidence references

- \`Loam/Authority/HouseholdAuthority.lean\` and \`Loam/Persistence/HouseholdImagePersistence.lean\`
- \`Loam/Authority/CurrentSupportAuthority.lean\` (semantic no-op is not a publication)
- \`Loam/Publisher/ScheduledTerminalPublisher.lean\` (paired completion)
- \`Loam/Tests/JanuaryFirstHousehold.lean\` (#2031, whole-image baseline)
- \`docs/research/TACKLER_SOURCE_YEAR_GIT_REPLAY_2026-10-15.md\`
- \`docs/research/CROSS_FAMILY_SOURCE_YEAR_PUBLICATION_2026-10-15.md\`
- \`docs/research/ANNUAL_SOURCE_PUBLISHER_GIT_COORDINATION_2026-10-15.md\`
- \`docs/research/ANNUAL_SEGMENT_COMMIT_RECOVERY_2026-10-15.md\`
- \`docs/research/DAILY_PACE_AUTOMATIC_KNOWLEDGE_PROTOCOL_2026-10-15.md\`
- \`tla/AnnualSegmentCommitRecovery.tla\`
