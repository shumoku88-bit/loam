# Native annual selected HEAD: two-year TLA+ qualification

Date: 2026-10-16  
Tracking: [#2030](https://github.com/shumoku88-bit/loam/issues/2030), continuation of merged [#2042](https://github.com/shumoku88-bit/loam/pull/2042)  
Status: **bounded TLA+ research, not production annual-source qualification**

## Why formal methods now?

The first abstract `AnnualSegmentCommitRecovery.tla` model checked *one* year transition. After #2042, the executable Lean sandbox has a **2026 baseline**, a **2027 Actual+Scheduled publication**, and a **2028 LocusAdmission publication** behind a single selected `HEAD`. New interleavings arise: two successive commits, stale observed HEAD after the first, crash between publishing a source object and the HEAD, and restoration to a perfectly valid but old selected HEAD.

The new `tla/AnnualNativeHeadTwoYear.tla` is a **small finite-state operational model** of the actual `Loam/Authority/AnnualSourceHeadSandbox.lean` sequence, rather than a claim that the new Lean code itself is proven correct.

| Model operation | Concrete Lean sandbox behavior | Important abstraction |
| --- | --- | --- |
| `AdvanceCalendar` | No operation on idle day/year | Injected logical calendar, not system time |
| `BeginPublication` | Observed HEAD comparison, occupied ordinal path refusal | Single modeled writer ownership |
| `ValidateFullSource` | Production-known-family decode and strict candidate publication test | Codec's semantic correctness taken as given |
| `InstallSourceObject` | Stage, reopen and rename `journal/Y/N.full.loam` | Rename is process-visible, not assumed durable after power loss |
| `ValidateCandidateHead` | Proposed HEAD reconstructed against all selected source objects | Full native replay abstracted to complete source closure |
| `CommitOneHead` | Stage and rename one `HEAD` after source replay | Atomic process-visible HEAD replace |
| `Crash` / `Restart` | Process death releases writer lock; stage can remain | Orphan already-renamed source object survives in this SIGKILL model |
| `ReadSelected` | Pin one HEAD; materialize all predecessors or refuse | If selected source missing, report unavailable; never choose another HEAD |

## Required TLC results

**Positive invariant/property suite**: head only selects a complete installed prefix, monotonic committed chronology *relative to a modeled independent ghost counter*, baseline remains available, readers return only a pinned selected generation or unavailable, and a calendar tick alone never writes a source.

**Expected counterexample witnesses**:

1. **Two accepted publications reachable.** The `NeverReachSecondYear` invariant deliberately fails when the model reaches the second (2028) HEAD.
2. **Orphan after SIGKILL.** The `OrphanAfterCrashImpossible` invariant deliberately fails after `InstallSourceObject → Crash` but before `CommitOneHead`. The installed source for ordinal N+1 exists while HEAD still selects N. This is not a wrong financial answer: the reader still selects the old committed generation. However, #2042's `append?` refuses a path already occupied by the orphan, so retry cannot progress without a separately approved recovery/adoption protocol. **Fail-closed safety is not liveness.**
3. **HEAD-first promotion.** `UnsafeHeadFirst` deliberately violates `HeadReferencesCompleteSource`: a reader would see a HEAD requiring an unavailable source.
4. **Valid-old-HEAD rollback.** `UnsafeValidOldHead` deliberately violates `HeadMatchesGhostChronology`. The older referenced sources remain complete and decode normally, so a reader **cannot detect** a valid rollback without additional trusted monotonic freshness. The ghost counter exists only in the model and is **not available in #2042**. Do not claim this test implements rollback detection.
5. **Partial restore of selected source.** `UnsafeRemoveSelectedObject` violates `HeadReferencesCompleteSource`. Real code must refuse current results on missing or corrupt selected objects; it must not silently use an older materialization.

The expected-negative TLC tests must **exit nonzero with the named invariant**, or CI fails. A green status means that both the positive checks *and* the required unsafe counterexamples were verified.

## Implementation consequences and next stage

1. **Resolve orphan retry with an explicit crash-restart operation contract.** Before reusing an occupied next-ordinal source path, compare it to a completely qualified *same* expected operation and predecessor, under one lock, and either finish the sole HEAD commit idempotently or refuse with a typed recovery-required answer. Do not delete unknown orphans automatically, promote a random object, or double-post an Actual/Scheduled event.
2. **Preserve one selected HEAD**; direct second equal canonical authorities for Git and HouseholdImage are still disallowed.
3. **Separate trusted freshness from content integrity.** A good hash and a replayable image do not establish the latest committed ordinal after external rollback.
4. **Prove the real physical boundary separately.** File fsync, directory fsync, atomic rename semantics and power loss on target macOS/Linux are not modeled by a SIGKILL transition. The future implementation must distinguish these.
5. **Connect to Lean via tests.** Replay the exact orphan trace with a subprocess kill and restart on a temporary household, including the expected occupied-file refusal, before modifying any product writer.

Neither the model, its TLC suite, nor this document modifies actual family authority, the TUI, `loam-data`, or a production journal. The [#2040 readiness inventory](https://github.com/shumoku88-bit/loam/pull/2040) must continue reporting physical canonical cutover as blocked.
