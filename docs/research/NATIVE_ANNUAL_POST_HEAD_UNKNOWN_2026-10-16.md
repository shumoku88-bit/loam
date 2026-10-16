# Annual source HEAD: post-replace result unknown and macOS durability preflight

Date: 2026-10-16  
Issues: [#2030](https://github.com/shumoku88-bit/loam/issues/2030), [#1969](https://github.com/shumoku88-bit/loam/issues/1969)  
Baseline: merged [#2046](https://github.com/shumoku88-bit/loam/pull/2046), commit `5a18989206ebab9538117d7f0ca0d7df7a004b02`

**Research-only. No production `household.loam`, TUI/CLI, `loam-data`, Git pin, or migration changes.**

## Specific defect and smallest remedy

The existing `AnnualSourceHeadSandbox.appendWithBarriers?` performs:

1. Recheck the pinned old HEAD, replay every source, refuse already admitted operation IDs.
2. Write/requalify and synchronize an immutable new year source.
3. Write and synchronize a new HEAD stage; replay the proposed complete source closure.
4. Rename the new HEAD over the old HEAD.
5. Synchronize the HEAD parent directory and return success.

A thrown error from step 5 must **not** be treated like a step-2 or step-3 refusal. The HEAD *name is already replaced* in the running process; an additional operation may double-apply or conflict if retried naively. Conversely, immediately reading the proposed HEAD does **not** establish storage power-loss durability.

The opt-in `appendWithOutcome?` reuses the exact native publisher, barrier injection, and cross-process writer lock. It tracks the invocation of the HEAD parent sync callback (which the current publisher reaches only after the HEAD rename) and returns one of:

| Result | What is known | Required caller behavior |
| --- | --- | --- |
| `committed selected` | All configured file + directory barriers returned and one full native HEAD replay succeeded | Continue only within the configured filesystem's separately qualified guarantees |
| `refusedBeforeHead reason` | Operation was rejected or a failure occurred before the HEAD parent sync cut | Inspect errors/orphans; no blanket automatic retry is authorized |
| `outcomeUnknown operation reason` | A failure occurred at/after invocation of the post-rename HEAD directory sync | **Never report definite failure or commit. Do not blindly retry.** Reobserve the selected HEAD and preserve operation identity |

`reobserveUnknown?` is a read-only, full native replay returning:

- `requestedHeadSelected`: the exact expected next HEAD is currently visible, last operation ID and admission day match. **This is not a durability receipt.**
- `priorHeadSelected`: the observed previous HEAD is currently visible. **This is not proof the attempted update can safely be replayed after power loss.**
- `cannotClassify reason`: a third head, missing/corrupt evidence, or any incompatible identity; refuse automatic continuation.

Because head files encode year+ordinal rather than the operation ID, the reobservation also validates the entire source closure and compares the final operation and admitted day, not just the HEAD bytes. This readback does not detect a fully well-formed rollback to a once-valid old HEAD, and is not a substitute for a trusted freshness anchor.

### Deterministic Linux test

`tools/NativeAnnualUnknownOutcomeProbe.lean` uses the existing **synthetic Actual+Scheduled full HouseholdImage** fixture and Linux syscall helper. It injects:

- Source-stage file sync error: `refusedBeforeHead`, prior HEAD remains selected.
- HEAD-parent sync error *after* successful HEAD rename: `outcomeUnknown`; read-only reobservation sees the fully replayable proposed HEAD but does not upgrade the status to durable success.
- Retries with stale prior HEAD and with the currently selected HEAD plus the same operation ID: both refused; no doubled operation.
- Normal barrier completion: `committed` with qualified generation.

These are process-visible fault tests, **not** power-cut tests. They do not establish which HEAD a crashed device would expose.

## macOS/APFS API evidence (no implementation claim)

Apple's macOS `fsync(2)` documentation warns that the drive may re-order and defer physical media writes. The current macOS `fcntl(2)` manual describes:

- `F_BARRIERFSYNC`: orders earlier synchronized IO against later IO; **does not say all data is durable when it returns**.
- `F_FULLFSYNC`: synchronizes the descriptor and requests device buffer flush; contemporary manual includes APFS, unlike older archived references. Its success is a stronger basis for persistence ordering than `fsync` alone, but device implementation/firmware matters.
- Neither source explicitly supplies an end-to-end promise that `F_FULLFSYNC` on a **directory fd** durably commits a replacement name under all APFS and device conditions. Distinguish file-content flush, namespace replacement, directory-entry persistence and platform/volume-specific capabilities.

References:

- Apple `fsync(2)` (archived): https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fsync.2.html
- Current macOS `fcntl(2)`: https://manp.gs/mac/2/fcntl
- APFS FAQ (copy-on-write/crash protection is not an application transaction durability receipt): https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html
- Apple storage guidance (barrier vs full sync tradeoffs): https://developer.apple.com/documentation/xcode/reducing-disk-writes

Next macOS slice: separately probe real syscalls on a **marked throwaway APFS root**, report `fsync` / `F_FULLFSYNC` results and errno **for regular files and directories**, verify rename+reopen sequence and support matrix for the exact OS/volume, and refuse unsupported operations without silently falling back. Prefer an audited C FFI/native adapter to a Python subprocess for eventual product integration. Neither that probe nor a simulated SIGKILL should be called a literal device-power-loss test.

## Stop rules

Do not enable year journals for live households. Do not treat `requestedHeadSelected` as a durable commit confirmation. Do not disable or weaken the current single-authority `household.loam`. Reject ambiguous/missing/reordered sources; preserve unknown-versus-zero. Freshness rollback, admission clock, backup/restore and production cutover remain blockers. The existing TLA+ model covers the pre-HEAD interrupted install; introducing a model-level explicit `unknown-after-rename` observation is appropriate before *automated retry or recovery decisions*, not required to validate this isolated error-classification interface.
