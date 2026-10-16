# Native annual single-HEAD fsync barriers, Linux research boundary

Date: 2026-10-16  
Issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
After: merged [#2045](https://github.com/shumoku88-bit/loam/pull/2045)

**Scope: qualified Linux process/filesystem synchronization experiment on disposable native Lean household images. NOT production migration or proven sudden-power-loss durability.**

## Motivation and actual baseline

Lean's existing `IO.FS.writeFile` / `IO.FS.rename` and its file-handle flush operations do not by themselves provide POSIX file and parent-directory `fsync` guarantees. The installed product `HouseholdAuthority` is unchanged. The earlier `research-annual-fs-killpoints.py` studied file+directory sync on a *synthetic* Annual segment, not the new native all-family Lean codec.

This change wires **the real Lean AnnualSourceHeadSandbox semantic publisher** to an explicit, injected, fail-closed file/parent-directory barrier interface. The ordinary sandbox entrypoints retain their previous no-barrier behavior and do not become durability qualified. Only the opt-in `AnnualSandboxDurabilityBarriers` module, on a marked **disposable** root, invokes `tools/annual-sandbox-sync.py` synchronously for each Linux `os.fsync(fd)`. There is no silent fallback to `flush` or rename if a helper call fails.

The Python subprocess is an intentional experimental bridge because the current Lean 4 runtime does not expose a stable, directly used fsync operation in this repository. **This is not the chosen production FFI/portable durability implementation**; it exists to exercise real system calls with native HousehouldImage data and identify the mandatory commit cut. A final adapter should be native and separately qualified on macOS and Linux.

## Ordered publication contract

Under the existing cross-process Lean writer lock and pinned HEAD:

1. Validate the complete current native 2026/2027/2028 source closure and the exact observed HEAD; refuse duplicates/stale operations and inconsistent unknown sections.
2. When creating directories, synchronize directory entries up the directory chain including the temporary root's parent. The temporary marker restricts accidental invocation on normal household data, but **is not an authentication mechanism**.
3. Stage the **complete** new source object; perform file `fsync` of its stage before any rename; re-read/re-decode it with the native Lean codec.
4. Install the source name, then synchronize the installed source's bytes and its directory/ancestor entries. A preexisting **exact** orphan is re-synchronized before re-admission, even if a killed predecessor might not have completed an earlier barrier. Different or corrupt orphans remain untouched and are refused.
5. Build the sole candidate HEAD, replay its full selected native source closure, write a HEAD stage file, **fsync that file**, then rename it over the selected HEAD and **fsync its parent directory** before reporting success.
6. If any `fsync` call fails, throw and **never report successful publication**. A failed post-rename HEAD directory sync leaves the authority outcome *uncertain*, and a caller must re-read/qualify the selected HEAD instead of pretending it failed atomically.

No second canonical HEAD is introduced. Backdated events remain admission-year sourced; January 1 alone does not create a journal or reset pension cycle.

## Linux CI evidence

`tools/test-native-annual-durability-barriers.py` uses real native Synthetic HouseholdImage snapshots generated from the Scheduled terminal publisher (paired Actual+Scheduled). It launches the real native Lean writer, checks a diagnostic sequence of successful file and parent `fsync` calls, and sends **SIGKILL** after a fully-synced 2027 source install but before HEAD stage. A separate Lean process reads the old selected HEAD, resumes the exact orphan without rewriting it, refuses foreign/stale/duplicate operations and completes 2028 with LocusAdmission and unknown sections intact. Also injects a file-sync failure BEFORE source publication, confirming a hard refusal without advancing HEAD. Unmarked roots and paths outside the sandbox are refused by the helper. Inputs remain unchanged.

CI verifies that barriers ran at the expected locations, not that storage media survives a literal power interruption. A *process SIGKILL* leaves the operating system and its caches alive. No real machine power-cut, block-layer fault injection, nonvolatile flush audit or ENOSPC investigation occurs here.

## Explicit open blockers

- **Sudden-power-loss correctness is not proven.** A return from `fsync` depends on OS, filesystem, device firmware and mount settings. macOS/APFS additionally needs separate testing of its preferred stronger flush semantics (for example `F_FULLFSYNC` where supported), as well as directory sync behavior. The Python bridge explicitly **refuses non-Linux** systems rather than promising portability.
- **Trusted selected-head freshness is absent.** A complete valid old HEAD rollback still reconstructs an old but valid HouseholdImage. Checksums, file sync, and source replay alone cannot detect this.
- **Backup/restore, cross-midnight admission-day capture, incomplete bootstrap, concurrent writers outside the shared lock and directory symlink/adversarial attack resistance are not comprehensively qualified**.
- This is an experimental opt-in physical backend. The ordinary Lean application, `household.loam`, `loam-data`, CLI/TUI, and migration remain unchanged. No claim that source years can be enabled for an existing household follows from this work.

**Next**: qualify a native/portable sync adapter and explicit uncertainty result after a failed post-HEAD directory sync, then real power-fault/harness testing before enabling an annual canonical owner. Stop rather than silently lowering the storage durability promise.
