# Installed HouseholdImage → isolated annual HEAD copy-migration preflight

Date: 2026-10-16  
Issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
After: merged [#2050](https://github.com/shumoku88-bit/loam/pull/2050)

**Scope:** reusable existing production-family Jan-1 test fixture, plus a separate synthetic annual root. This is NOT a migration command, production writer selection, or approval to touch `loam-data`.

## Motivation: one real installed household, not only hand-crafted year images

The existing `Loam/Tests/JanuaryFirstHousehold.lean` test runs real product commands to construct one `household.loam` on 2026-12-31 and 2027-01-03, including a 2026-effective expense corrected after Jan 1, a January expense, paid Scheduled Actual+Scheduled pair, explicitly anchored bank, cash not known to be zero, and a **Dec 15–Feb 15 pension Daily Pace cycle**. Until now the test generated a private temp root and could not feed that *same installed complete household* directly to a copy-first annual baseline rehearsal.

This change exposes a test-only optional positional root while keeping the original argument-free regression path. The test continues using the ordinary production authority, not an annual CLI. No source-family codec or product persistence code is replaced.

## Isolated native parity contract

`NativeAnnualInstalledMigrationProbe.lean` takes a synthetic installed household and an unused annual root, then:

1. Reads/qualifies the installed `household.loam`, snapshots `household.loam.prev` and external Daily Pace policy contents.
2. Decodes the same-generation original Actual/Scheduled, current balance and current-truth Daily Pace via the existing `AnnualSourceReadView` and `AnnualSourceQueryPolicy`.
3. Creates a marked **separate** annual root with the existing durable native Lean publisher and a byte-for-byte complete 2027 baseline equal to the installed household. No journal for 2028 exists merely from reading or crossing midnight; 2026-effective events remain events, not 2026 physical source publications.
4. Reopens the selected HEAD in native Lean. Requires the same complete image wire, Event identities/currentness, closed Scheduled frontier, exact bank balance of 7850, unsupported cash **not zero**, the same Daily Pace snapshot and the unchanged pension end date **2027-02-15**. The `compareInstalled?` gate additionally refuses a generation that is not equal to the original installed source.
5. Appends a separate **2028-01-03** native LocusAdmission operation to the copied annual source. It must not alter preserved prior Actual, Scheduled, support, or 2027 selected query projection. The original installed source and `.prev` remain byte-identical. No year directory is written inside the original household.
6. Existing Linux `fsync` and Darwin/APFS `F_FULLFSYNC` barriers are exercised in CI through the shared `AnnualSandboxDurabilityBarriers`, not simulated no-op callbacks.

## Exact guarantees and limits

- This is **copy-first**, not dual-write. The original `household.loam` is the only product authority, and the generated annual root is an **experimental candidate** for read parity; there is no automatic cutover, operating system power loss guarantee, product freshness anchor, UI migration wizard or TUI annual commands.
- The annual physical baseline is labeled **2027** because the already-running synthetic household is copied after the January 2027 admissions. Historical 2026-effective events stay inside that complete baseline. Source publication year is not event effective year.
- Subsequent query policy is provided by the original current `config/*.tsv` bytes. The annual source does not invent versioned historical query policy or a Jan-1 pension-cycle reset.
- The caller must restrict inputs to isolated synthetic fixtures. The sandbox marker limits accidental invocation but is not an adversarial file-access security boundary or sufficient authorization to migrate a real household.
- Success establishes *read parity and safe separation on one covered fixture*, **not readiness for physical canonical year-source cutover**. The production readiness gates in `tools/annual-production-readiness.json` remain blocked. Trusted admission day, valid-old-HEAD freshness, backup promotion and actual TUI selection still need dedicated product work.

Next: reuse this concrete old-vs-year-copy parity harness for a qualified, explicitly opt-in single-authority reader/writer integration test, without silently switching the operational household.
