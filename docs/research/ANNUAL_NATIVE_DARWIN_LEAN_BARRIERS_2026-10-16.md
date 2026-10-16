# Native Lean annual source barriers on Darwin/APFS, experimental closure

Date: 2026-10-16  
Issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Predecessors: [#2046](https://github.com/shumoku88-bit/loam/pull/2046) Linux native fsync, [#2047](https://github.com/shumoku88-bit/loam/pull/2047) post-HEAD uncertainty, [#2048](https://github.com/shumoku88-bit/loam/pull/2048) Darwin C syscall matrix.

**Research-only bridge, on marked synthetic roots. The operational `household.loam`, `loam-data`, TUI/CLI, cutover gate and migration are NOT modified.**

## What changed, and what was reused

Existing native Lean `AnnualSourceHeadSandbox` continues to own the **same single HEAD**, replay the entire known/unknown `HouseholdImage`, require an exact observed HEAD and reject duplicate operation IDs. Its publication protocol and `PublicationBarriers` callbacks are unchanged.

The existing `AnnualSandboxDurabilityBarriers.lean` calls `tools/annual-sandbox-sync.py` synchronously. This wrapper now branches on the OS:

- **Linux**: retains the previously qualified experimental `os.fsync` behavior and marker/path constraints; Linux CI remains in place.
- **Darwin/APFS**: requires `LOAM_ANNUAL_DARWIN_SYNC_BINARY` to point to a precompiled **real file**, compiled from the existing audited `tools/annual-darwin-sync-probe.c`. Requests `fcntl(fd, F_FULLFSYNC)` for every file and each directory/ancestor barrier, and requires the C witness to report APFS. No binary, unsupported syscall, non-APFS volume, path/symlink/marker violation, or failed call means **hard refusal**. No fallback to `fsync`, `flush`, or rename alone.

The C witness opens the actual target with `O_NOFOLLOW`, verifies expected descriptor type, reports `fstatfs` filesystem and errors; the fixed Python wrapper keeps the prior marked-root boundary and recursive directory ordering. The marker is not an adversarial security policy, and path races remain outside the scope of this sandbox. External binaries and Python are not a production-quality native FFI.

## New CI checks

`.github/workflows/research-annual-darwin-sync.yml` runs macOS 15 both Apple Silicon and Intel:

1. Repeats the independent syscall-only `fsync`/`F_FULLFSYNC` preflight from #2048.
2. Builds the genuine Lean modules and **synthetic native Actual+Scheduled source** via the same fixture as Linux.
3. Compiles the C helper into an isolated temporary directory and explicitly passes its absolute path to the fixed bridge.
4. Runs `tools/test-native-annual-durability-barriers.py` unmodified: ordered source/file/directory barriers, real process `SIGKILL` after fully-synced source but before HEAD, restart in another Lean process, byte-exact orphan recovery, duplicate refusal, 2028 continuation and pre-HEAD sync-failure refusal.
5. Runs `tools/NativeAnnualUnknownOutcomeProbe.lean`: injects a failure at the **post-rename HEAD directory sync** and classifies it as `outcomeUnknown`; reobserves the source in read-only mode without claiming a durability receipt; a resend of the same operation ID is refused.

The native Lean test is **not** replaced by the noncanonical bytes from #2048. This closes the gap between Darwin syscall recon and the actual Lean annual semantic prototype without wiring a product writer.

## Safety interpretation and remaining blockers

- A passing macOS runner proves that the specific Lean writer used a synchronous, fail-closed Darwin APFS fullsync bridge **and** survived *process* SIGKILL + restarted replay in test conditions. It does not prove real power-failure survival, correct behavior on the user's older Mac or volumes, or device firmware flush promises.
- On failed post-HEAD sync, `outcomeUnknown` remains unresolved as a durable result even if the process can immediately reread the new HEAD.
- A complete but stale valid HEAD cannot yet be detected with a trusted monotonic anchor; the pinned source replay alone cannot detect a valid-old-HEAD rollback.
- Automated cutover, authoritative admission clock, migration/rollback rehearsal, backup/restore UX and performance at realistic long history remain separate work.
- Maintain `household.loam` as the sole production authority until separately qualified. Future production backend requires an audited native syscall adapter, stable on-disk manifest semantics and fail-closed recovery contract.

This PR should only be merged if Linux CI and **both** macOS runner native-Lean jobs succeed. A green CI is not a production-migration authorization.
