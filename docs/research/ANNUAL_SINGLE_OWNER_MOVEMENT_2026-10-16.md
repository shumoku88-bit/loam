# Practical Movement through one selected annual HEAD (synthetic only)

Date: 2026-10-16  
Issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Predecessor: merged [#2053](https://github.com/shumoku88-bit/loam/pull/2053)

**No product routing/cutover. No `loam-data` edits. No installed `household.loam` writes. This is a research experiment over an already-marked disposable native annual source.**

## Why this slice

#2053 demonstrated same-HEAD read/append using a synthetic LocusAdmission change, not an actual household spending command. This slice connects *one real practical Movement admission* to that same selected HEAD, using qualified existing semantic APIs rather than recoding balanced movement, event ID allocation or eligibility rules.

`AnnualSingleOwnerMovementSandbox.lean` introduces `Pinned.recordMovement?`:

1. Read the pinned generation's **actual** evidence with `ActualAuthority.decodeHouseholdGeneration?` and its required new-write vocabulary with `LocusAdmissionAuthority.decodeGeneration?`. Neither is separately loaded from legacy files or untrusted derived data.
2. Require a valid `MovementOperationId`, refuse any already-retained ID in the selected Actual. Use the existing `MovementWorldAdapter.ofActual` + **`MovementAdmission.admit?`** to check balanced quantities, date, source Locus permission, relation/discharge semantics, and allocate real Event evidence.
3. Copy the admission's native Actual fields and insert its operation-id → Event-id evidence, encode using the current production normalized Actual codec. Replace **only** the `Actual` section of the already-pinned HouseholdImage. Unknown and untouched sections remain exactly preserved by existing annual publication validation.
4. Publish via the same `Pinned.append?` and **same observed HEAD**. It acquires existing annual cross-process ownership and uses Linux `fsync`/Darwin `F_FULLFSYNC` with the already established barrier adapter. The publication year is explicit `admittedDay`, not the Event's `validOn`.
5. Return typed `MovementOutcome`. Only a fully barrier-acknowledged commit returns the new Event and selected HEAD. A pre-HEAD refusal is not a receipt; a post-HEAD `outcomeUnknown` is **not** safe to retry blindly. Existing selected-source readback remains available for inspection but is not a proof of power-loss persistence.

No command is forwarded to the ordinary `HouseholdCommand.record` or `household.loam` after the annual source has been selected. No second journal writer or dual canonical owner is introduced.

## Native integration test

The new `NativeAnnualSingleOwnerMovementProbe.lean` runs after the existing synthetic Jan-1 household migration, Home parity and #2053 single-owner session probes.

- Start from a 2027 baseline, a 2028 LocusAdmission and a 2029 admission already selected, with the original installed HouseholdImage preserved.
- On a **2030-01-01** first annual native Movement, admit a balanced 75 JPY bank-to-food transaction with **effective day 2028-12-31**. No prior 2030 file exists and merely opening Jan 1 does not create one. A successful commit publishes the 2030 journal/source and exact operation evidence.
- Reopen the selected annual HEAD: existing Home Actual records grow by exactly one, Scheduled stays closed, exact bank current quantity changes 7850→7775 JPY, unknown cash stays unknown. The externally supplied current-truth pension policy retains end date 2027-02-15. Full previous section semantics remain independently qualified.
- Fail closed for zero/unbalanced Movement, unapproved source Locus, invalid admitted calendar day, malformed operation token, duplicate retained operation and stale session write. A rejected operation cannot manufacture a selected source of ordinal 4.
- The old installed HouseholdImage, `.prev` and external current policy config are byte-identical before/after. No ordinary product root receives a new annual journal or Movement.

Run exactly this Lean test on Linux and macOS Intel + Apple Silicon with their existing real native full-image publication barriers, immediately after #2053.

## Important qualification limits

- This is *one practical Movement operation family*, not the normal TUI/Cli command dispatcher, Scheduled completion, correction, FX, bank reconciliation or every editing operation. Normal LOAM keeps `household.loam` as its authority.
- This does not establish trusted local admission-day evidence, authenticated HEAD freshness or user-approved rollback/restore choice. A caller can present an equally old valid HEAD and pin. No automatic selection or migration is allowed.
- The native barrier adapter still calls a Python helper (and compiled Darwin C helper), and physical power interruption has not been proven by SIGKILL-based CI.
- The disposable marker is a test boundary, not a hostile-path security capability. Release gates and real household data remain untouched.

**Next:** decide if this prototype should support more practical operations or instead consolidate the annual backend into a smaller production-shaped interface, before any user data cutover. In either case a trusted admission-day source and explicit freshness/restore contract remain blockers.
