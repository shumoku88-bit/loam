# Annual source orphan recovery: formal + real process-kill qualification

Date: 2026-10-16  
Tracking: #2030, following merged PRs #2042, #2043, #2044  
Status: **sandbox-only Lean source authority, not product cutover**

## The concrete crash cut

The actual Lean `AnnualSourceHeadSandbox.appendWithInstalledTestHook?` installs and fully qualifies the new source object **before** staging/promoting the selected `HEAD`. The `NativeAnnualSigkillWriter.lean` test tool executes this exact native writer, writes a ready marker only after source installation/requalification, and blocks. The test harness `tools/test-native-annual-sigkill-retry.py` sends Linux SIGKILL to the *whole subprocess group*, checks the process exit signal, observes the unchanged 2026 selected HEAD and complete but unselected 2027 Actual+Scheduled source, then starts a **separate Lean interpreter process**.

The restarted `NativeAnnualOrphanRetryProbe.lean retry` checks the old selected answer; refuses a different operation ID or day while leaving source and HEAD untouched; refuses a corrupt existing object; then restores the saved synthetic orphan bytes and verifies only the exact matching native publication can advance a single HEAD once. It refuses stale/duplicated replay and admits a normal 2028 LocusAdmission change with unknown-section bytes preserved. The test checks its input fixtures are unchanged, without any user data access.

**Precise scope:** this is a Linux SIGKILL/process-visibility result. Atomic rename at the process-visible boundary is NOT a file or directory `fsync` or sudden-power-loss durability proof.

## Formal correspondence

`tla/AnnualNativeOrphanRecovery.tla` explores the finite sequence of one 2026 baseline followed by 2027 and 2028 commits, alongside staged, installed, selected, crashed and restarted states. The model distinguishes `exact` (entire native publication matches expected predecessor, operation, day, changed families, result bytes) from `foreign` (mismatch/corruption).

Positive invariants establish, **within the stated abstractions**:
- the only selected source closure is entirely qualified; no HEAD points at an unqualified source;
- the single selected HEAD advances exactly once for each modeled accepted commit;
- mismatched or foreign installed objects are not adopted;
- readers only return whole selected generations.

Dedicated expected-failure TLC variants demonstrate reachability of exact-orphan resume after a kill, mismatch refusal, a second 2028 publication, and a deliberately unsafe mutation that would adopt a foreign orphan. Thus a green CI requires both safe model exploration and counterexample witnesses, not just a proof with no progress.

## Remaining obligations

- The TLA+ exact/foreign classifier **assumes**, rather than proves, the production codecs and byte-equality test; Lean CI supplies the corresponding concrete positive and negative witnesses.
- SIGKILL only checks process termination. Power-loss consistency requires file+parent-dir synchronization, atomic replace semantics on target OS/filesystems and actual durability/recovery tests.
- Injection day is controlled; a household IANA-zone admission clock and cross-midnight retry policy are absent.
- Full valid-old-HEAD rollback remains undetectable without trusted monotonic freshness. The TLA+ committed counter is ghost evidence, not native proof of this property.
- Interrupted initial bootstrap and incomplete staging have separate safe-stop rules. Do not automatically delete a different orphan or promote any nonselected year.
- No production `household.loam` migration, no `loam-data` changes, no TUI/CLI cutover, no Git as independent canonical head, no budget or pension cycle resetting.

Keep #2030 production cutover blocked until its separately tracked hard gates pass.
