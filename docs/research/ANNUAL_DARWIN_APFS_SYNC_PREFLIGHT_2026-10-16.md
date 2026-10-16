# Annual source macOS/APFS syscall preflight (research only)

Date: 2026-10-16  
Main issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Predecessor: merged [#2047](https://github.com/shumoku88-bit/loam/pull/2047)

**No LOAM product writer is changed in this PR. No real `household.loam`, `loam-data`, or migration.**

## Why this slice

The current annual native-Lean sandbox uses real Linux `fsync` file + parent-directory callbacks. macOS uses different storage interfaces. Apple's `fsync(2)` warns a drive can defer and reorder physical writes; `fcntl(fd, F_FULLFSYNC)` asks the device to flush buffered writes. On APFS, the open question is not just whether file sync works; **a directory descriptor may reject one or both calls**. We must know the exact failure errno at an actual macOS runner rather than guessing from a Linux result.

Current Apple references:

- [Apple Mac OS X fsync(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fsync.2.html)
- [Apple Mac OS X fcntl(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/fcntl.2.html)
- [GitHub-hosted macOS runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

## Test surface

- Tiny native C witness `tools/annual-darwin-sync-probe.c` invokes actual Darwin `fsync` or `fcntl(F_FULLFSYNC)` on an opened regular-file or directory descriptor. It verifies descriptor type, opens with `O_NOFOLLOW`, reports the filesystem type via `fstatfs` and preserves errno.
- `tools/test-annual-darwin-sync.py` runs only on macOS. It compiles the witness locally in a new Python temporary directory and operates only on its own synthetic paths.
- **Independent direct checks** always exercise both APIs on a regular file and a directory. `unsupported` (specific errno) is distinct from other hard failures. The report includes filesystem type so a non-APFS runner is not silently counted as APFS qualification.
- A small **noncanonical** source + HEAD rename experiment observes ordering: create year directories, sync directories (including the test root's parent), sync source stage, rename source, sync installed source and year directory, sync HEAD stage, rename HEAD, sync HEAD directory. If a barrier fails before HEAD replacement the test refuses; if HEAD directory sync fails after rename the test reports `outcome_unknown`. This is NOT a new Lean writer, commit protocol, or valid source-image test.
- Fault injection before the HEAD and after HEAD replacement checks that no failure is reinterpreted as an unconditional success. If the platform blocks at an earlier unsupported sync, the injected cut cannot be reached; the output explicitly records `injection_reached: false`.
- Symlink target must be refused. Nothing is promoted from the test root into a household.

Run: `python3 tools/test-annual-darwin-sync.py` on a macOS system with `cc`.

CI: `.github/workflows/research-annual-darwin-sync.yml` (macos-15). The logged JSON includes `direct_syscalls`, `apfs_observed`, ordered `results`, `failure_injection`, and `injection_reached`.

## Interpretation and stop criteria

A green CI means **the probe ran and reported actual syscall results correctly**. It does not mean APFS durability is qualified:

- `fsync` success is not equivalent to `F_FULLFSYNC` media persistence.
- Directory `F_FULLFSYNC` unsupported/error must **block** a full-barrier publication, not cause a silent weaker fallback. A failing directory barrier before HEAD is a definite refusal; a failing post-rename HEAD directory barrier is potentially committed, so needs reobservation and no blind retry.
- A successful F_FULLFSYNC return does not guarantee that untrusted device firmware or a physical power interruption could not lose data.
- SIGKILL only stops the process; runner CI cannot power-cycle the VM or device.
- The existing native-Lean `PublicationBarriers`, `appendWithOutcome?`, and `reobserveUnknown?` remain the experimental semantic writer. The C and Python probe do not by themselves wire those functions to macOS.

**Next engineering step:** use the measured file/directory support matrix to decide a fail-closed, directly auditable macOS barrier adapter, then run the *existing native Lean annual writer and readback* on disposable APFS. If a required directory sync is unsupported, retain the present single `household.loam` owner and record an explicit blocker or evaluate a properly justified alternative. Do not claim annual production readiness by passing this probe.
