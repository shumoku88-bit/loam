# Selected annual HEAD → ordinary Home read composition (synthetic preview)

Date: 2026-10-16  
Delivery issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Predecessor: [#2051](https://github.com/shumoku88-bit/loam/pull/2051), copy-first migration and exact native balance / Daily Pace parity

**Not a product TUI mode and not annual source cutover.** No change to the normal TUI/CLI entrypoint, its default `household.loam` authority, `loam-data`, user configuration, or write/restore commands.

## User-visible target and smallest safe slice

LOAM Home already provides `Loam.Tui.Cli.loadSnapshotFromActualImage`, consuming an admitted Actual image together with an optional **same-generation HouseholdImage**. It preserves paired Scheduled evidence, home calendar/accounting roles and the existing home read state behavior. The next physical-year step is not a separate year-specific home, menu or duplicate projection. The same Home composition must be able to receive an already selected annual native source generation.

`Loam/Review/AnnualSelectedHomePreview.lean` adds a **research-only, read-only** adapter:

1. Refuse source/config roots that are literally the same, missing the disposable annual marker, using an invalid observation day, or holding a competing `household.loam` owner.
2. Acquire the existing cross-process annual HEAD writer lock and replay exactly ONE selected HEAD using `AnnualSourceHeadSandbox.readSelected?`. Require the caller's expected HEAD bytes to be exactly the selected bytes. This outside pin is only a *test oracle*, not a trustworthy product freshness anchor.
3. Qualify native Actual, Scheduled and exact current-balance support from the selected generation using `AnnualSourceReadView.fromGeneration?`.
4. Pass this same generation and its Actual image to the **existing** `Tui.Cli.loadSnapshotFromActualImage`, not a new Home composition. Scheduled unavailability is fatal to the preview; no fallbacks to `.prev`, ordinary `household.loam`, a previous year or directory enumeration.
5. Keep current query/presentation configuration as explicit reads from the original synthetic household root, not as retained source-year history. No as-known-at-time configuration guarantees or simultaneous config/source transaction are claimed.

## Real native integration test

`NativeAnnualSelectedHomePreviewProbe.lean` reuses the actual ordinary-household Jan-1 fixture and copy-first year-source publication from #2051, without creating another fixture family. The annual copy contains one **2027 baseline** and a 2028 LocusAdmission change. This preserves 2026-effective Actual and 2027 corrections within its native image.

After a separate Lean process reopens its 2028 selected HEAD, the probe requires:

- the Home Actual identity sequence and observation day to match the *ordinary* installed HouseholdImage Home; four cross-year retained records remain;
- no reopened Scheduled obligations, exact bank 7850 JPY and cash that is not falsely reported as an exact zero;
- current-truth pension Daily Pace from the same **explicit source-pinned generation and external policy bytes** to agree with installed truth, retaining the Feb 15 end date, without a Jan 1 cycle reset;
- corrupt selected 2028 source, a complete valid-old but *unpinned* HEAD, an unmarked root, a same-root dual-owner attempt, invalid day and pin mismatch are all refused; restore test mutation and verify full read again;
- original `household.loam`, `.prev`, and query config remain byte-for-byte unchanged.

Linux and APFS (Intel/Apple Silicon) CI invoke this extra Lean probe immediately after the existing Jan-1 household copy-migration fixture, reusing the existing test image and durability adapters.

## Release boundary

A passing preview proves that the **ordinary Home read composer works from one real native annual HEAD** without selecting a mixed family generation. It does **not** mean a user can choose annual source in the production TUI: there is no live opt-in, product source selector or publisher interface yet. The caller-supplied HEAD pin could itself be stale; a complete valid-old snapshot cannot be detected in general without trusted freshness evidence or explicit restore selection. A real product migration also needs single-authority write admission, source-year clock, backup promotion, configuration coherence and crash qualification.

**Next:** on a separate disposable product-shaped root, implement a fail-closed single-authority source *selection contract* for both reads and writes, keeping the original HouseholdImage as production until qualified. Avoid any dual canonical owner or unreviewed migration.
