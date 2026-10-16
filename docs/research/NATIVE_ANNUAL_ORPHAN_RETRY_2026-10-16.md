# Native annual single-HEAD orphan retry: narrowly qualified recovery

Date: 2026-10-16  
Issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Predecessors: [#2042](https://github.com/shumoku88-bit/loam/pull/2042), [#2043](https://github.com/shumoku88-bit/loam/pull/2043)  
Status: **synthetic native source-owner qualification, not installed production recovery**

## Incident and exact cut

The existing Lean sandbox stages, qualifies, and renames `journal/Y/N.full.loam` **before** writing the sole selected `HEAD`. #2043's bounded TLA+ model demonstrates that process termination in this interval can leave a *fully formed unselected source object* at the next ordinal path.

The pre-fix sandbox refused all occupied next-ordinal paths. This was fail-closed for read safety but left a legitimate interrupted write unable to make progress. It was not safe to fix it by overwriting the old object or guessing that any syntactically valid orphan represented the user's intended transaction.

## Narrow fix, under one sandbox writer lock

1. Re-read **exact observed HEAD bytes** under `WriterOwnership` and replay the selected source closure through the already-existing native section codecs.
2. Refuse time regression and an already-committed operation identifier. Build exactly the proposed `AnnualSourcePublication` using the selected generation, requested ordinal, admission day, operation, previous ordinal, explicit changed known section set and complete resulting native image.
3. If the next publication's year/ordinal path does not exist, retain the previous staging/qualification/readback flow.
4. If that path **already exists**, read its *unchanged* bytes. Refuse if they differ in **any byte** from the expected native source publication; if equal, re-decode and requalify against the same pinned predecessor and assert the full publication identity and native resulting bytes again. Never truncate, rewrite or delete an existing orphan.
5. With either fully admitted path, read back the installed source and verify again. Only then stage a candidate new HEAD, replay the entire referenced history, and finally rename the one selected HEAD.
6. After HEAD publication, ordinary stale-head or duplicate-operation checks still reject another posting. This is *at-most-once* success, not a claim to have durably learned the external caller's receipt or to return automatic idempotent success from an old observed HEAD.

## Executable test cases

`NativeAnnualOrphanRetryProbe.lean seed` creates an isolated native baseline and uses the **exact writer path** with a test-injected exception immediately after the complete source object is installed. HEAD remains on the 2026 baseline, while the qualified 2027 Actual+Scheduled publication remains as an unselected orphan.

A **separate Lean process** executes `retry` on the same isolated directory and checks:

- Different operation and different admission day cannot reuse the occupied path.
- Corrupting the orphan causes refusal without rewriting it or moving HEAD; the fixture explicitly restores the test-only saved bytes.
- Exact same selected predecessor, day, operation, changed-family mask and full native image resumes successfully, without rewriting the saved orphan source bytes.
- A repeated request using old observed HEAD is stale; a repeated committed operation with new observed HEAD is rejected rather than posted twice.
- 2028 LocusAdmission continuation works after recovered 2027 Actual+Scheduled; unknown family bytes and test fixture files remain unchanged.

The existing #2043 TLA+ **orphan reachability counterexample remains true**. This change provides one explicitly guarded transition out of that state, rather than claiming the failure point is unreachable. A model of all safe and adversarial recovery transitions is still a separate qualification task.

## What remains blocked

The stop is **an exception in a disposable Lean process**, not literal SIGKILL or sudden power failure. A next slice should exercise real process SIGKILL and the physical stages on the supported OS/filesystem.

No file+directory fsync durability, trusted clock, cryptographic selected-HEAD identity, trusted anti-rollback freshness, automatic recovery of unknown/orphan sources, safe migration/restore, physical year cutover, or real TUI integration is proven here. The supplied day is test-injected; retries on a different *year* need a separately designed admission/abandoned-orphan policy. Partial stage files and failed initial bootstrap likewise require dedicated recovery rules. Do not infer that arbitrary orphan garbage can be cleaned automatically.

Keep `household.loam` as the sole canonical production authority. No `loam-data` write, production source switch, tax-year closing, pension cycle reset, or zero-balance invention is authorized. The #2040 cutover inventory remains blocked.
