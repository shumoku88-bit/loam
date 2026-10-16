# Native annual source: copy-first restore rehearsal (isolated, pinned)

Date: 2026-10-16  
Issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
After: merged [#2049](https://github.com/shumoku88-bit/loam/pull/2049) (Linux + APFS native-Lean barriers)

**This is a synthetic test-only rehearsal, NOT a household backup application, restoration CLI, cutover, trusted freshness record, or a power-loss proof. Operational `household.loam` and `loam-data` remain untouched.**

## Why this step

The production `household.loam` engine already carries Dec 31 to Jan 1 across balances, Scheduled, and pension-cycle Daily Pace. The experimental physical annual HEAD can preserve Actual+Scheduled and native other sections with synchronous Linux/macOS barriers, but **a complete selected multi-year source closure must be portable as a unit**. Restoring HEAD alone is not a restore; restoring a missing/corrupt source should not guess another generation. A valid old HEAD, however, remains internally replayable and needs a trusted external expected identity to detect a rollback.

## Implementation without a second authority

Reuses the existing `AnnualSourceHeadSandbox` Lean native bootstrap/append/replay, `AnnualSandboxDurabilityBarriers` and real synthetic Actual+Scheduled source fixture. No new runtime source owner, format, import/export API, migration writer, or product-setting switch.

1. A native Lean process seeds an isolated source root with the 2026 full-image baseline; no idle 2027 directory is created. It then admits Actual+Scheduled together on **2027-01-03** and a native LocusAdmission change on 2028-01-01. The two committed generations are replayed and the final HEAD bytes + full canonical image bytes saved separately as **test-oracle pins**.
2. `tools/test-native-annual-copy-restore.py` parses **one explicitly pinned HEAD**, copies only its selected baseline and ordered source filenames plus the experimental root marker into a fresh, untrusted stage. It compares every file byte-for-byte and asks a separate Lean invocation to replay/requalify the entire selected source closure. It never scans directory names to select a later year.
3. Only after staging qualifies does the Python *test harness* rename its stage to an unused restored-directory name and replay it again. This process-level rename is **not** a durable product restore protocol (no directory sync after that rename, no independent trust anchor).
4. Negative backup candidates: missing 2027, missing 2028, corrupted 2027 source, malformed HEAD, and a **structurally valid but older 2027-only HEAD**. All are refused by the pinned restore check; importantly unpinned native replay of the valid-old HEAD succeeds, demonstrating the real limitation rather than misreporting automatic rollback detection. Unselected 2030 orphan files must not change the selected read. An existing restored root cannot be silently overwritten.
5. The *restored copy*, not the original, accepts another fully synchronized native operation admitted in **2029**. Restart/readback verifies 2027/2028/2029 operations and no duplicate or missing native image. Original fixtures and original source HEAD remain unchanged.

Linux and macOS (Intel and Apple Silicon) CI exercise exactly the same Lean+Python flow. The APFS lane reuses the #2049 precompiled C F_FULLFSYNC bridge and refuses unsupported targets without fallback.

## Safety caveats and next engineering step

- These external test pins are not secured against a malicious or unintended old-backup substitution. A trusted monotonic anchor or **explicit user-approved version choice** is still required for a real restore UI. Never silently pick a valid older HEAD on restart as current.
- A staged copy may fail after mutation; it is kept unnamed/unselected and never replaces a known good restore. Product restore would need additional directory synchronization, origin/destination capability checks and user-confirmed promotion.
- The test copies synthetic sources it *already knows* were published correctly; it does not perform live `household.loam` migration, TUI recording after Dec 31, or a literal power cut.
- Treat successful CI as progress on cross-year **restore closure**, not readiness to enable the annual source owner. This test does not shorten or override remaining #2030 production gates.

After this slice, prioritize a single-authority opt-in product adapter for isolated **normal TUI commands** and a copy-first migration rehearsal from ordinary `household.loam`, with explicit rollback and no dual-written source. Keep the current engine if the annual topology costs more complexity than its long-term benefit.
