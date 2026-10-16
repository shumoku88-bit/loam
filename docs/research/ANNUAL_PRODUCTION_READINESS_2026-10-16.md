# Calendar-year canonical source journals: production-readiness gate

Date: 2026-10-16  
Primary delivery issue: [#2030](https://github.com/shumoku88-bit/loam/issues/2030)  
Storage alternatives: [#1969](https://github.com/shumoku88-bit/loam/issues/1969)  
Status: **BLOCKED FOR PRODUCTION CUTOVER**, even when research CI is green.

## What the household can already do

The currently installed `household.loam` remains the **single canonical source**. The native `Loam/Tests/JanuaryFirstHousehold.lean` regression already opens one qualified household on 2026-12-31 and 2027-01-01, preserves exact supported and unsupported balances, carries the **Dec 15 to Feb 15 pension cycle** across Jan 1, records a 2027 expense, corrects a prior-year expense, and atomically completes a Scheduled item with Actual evidence. It explicitly verifies that the current production path **does not create a 2027 journal**.

This is important: **calendar rollover of the same financial household is already functional**; *physical publication-year partitioning* is not. Do not replace the first achievement with a false claim that annual canonical journals have shipped.

## What research proved, with its limits

| Merged slice | Evidence available | What it does **not** prove |
| --- | --- | --- |
| #2032 | Single-head source manifest and invariants | Installed source owner or durable protocol |
| #2033 | Cross-family synthetic native replay and process SIGKILL boundaries | Power-loss durability or production write promotion |
| #2034 | Controlled injected admission-day receipt across Jan 1 | Trusted real acceptance time or instantaneous physical-head switch |
| #2035 | Three 2027/2028 source publications and closed immutable chain | Generalized whole-family production source writer; valid-old-head rollback detection |
| #2036 | Read-only comparison of materialized native bytes to existing `household.loam` | Canonical migration |
| #2037 | One qualified native Actual and Scheduled read generation | Production selection of a journal HEAD |
| #2038 | Current quantity supports and native current-truth Daily Pace | Unsupported balance becoming zero, historical as-known answers or current config coherence |
| #2039 | Byte-pinned **caller-supplied** Daily Pace config and explicit pension-cycle window | Historized policy edits or atomic current config/source selection |

These results are valuable but **the test-only Python source writer is not the production Lean writer**. A source journal filename, Git pin, checksum, or a green CI job does not establish an authoritative source of truth.

## Cutover policy: stop rules

Keep the existing `household.loam` production write/read/restore unchanged until all cutover blockers below have been qualified on **disposable real-native workflows** and checked by the repository owner. Do not dual-write `household.loam` and a new source HEAD as two equal authorities. Do not touch `loam-data`; a real household requires an **explicit, separately approved, copy-first migration**.

**One logical accepted publication must carry every changed native section together.** Existing research about Actual-only 2028 deltas and paired Actual+Scheduled 2027 completion is not yet a generic one-action multi-family journal writer. A **complete native generation source object is an acceptable first implementation fallback** when a smaller generalized delta cannot be proved, even if larger and slower.

**Physical year = qualified local publication/admission year**, never Event valid date, Scheduled date, Git commit time, or pension-cycle boundary. At midnight **without** a new write, create nothing. First use on Jan 3 admits to the new year on the successful new publication, without inventing prior Jan 1 actions.

**One selected head**, no independently authoritative Git head. Derived TUI materialization/cache, year exports and Tackler projections may lag; stale projections cannot win against source truth. A failed partial restore must fail closed, not choose the older apparently valid cache. Internal hashes alone **cannot** prove freshness against a complete valid-old-head rollback.

**Config remains external by default.** Current query-specific selection can be byte-pinned without pretending to know an earlier edit's publication date. Add separate versioning/adoption protocol only for claims that require historical as-known configuration. A tax/calendar-year turnover does **not** alter a pension cycle.

## Hard gates and shortest route to a product

This is an *ordering* of engineering tasks, not a calendar-time promise.

| Order | Required work / evidence | Release criterion |
| --- | --- | --- |
| 1 | **Source owner + all-family writer.** One authoritative new HEAD, global ordinal/idempotency, accepted-year receipt and generic multi-section native operation. | Current `HouseholdAuthority` publisher can be adapted on an isolated root without a dual-head interval; staged source fully replays before promotion. |
| 2 | **Crash-safe commit & restore.** fsync files and parent dirs, atomic HEAD switch on supported targets, writer lock and restart, real vs injected clock, rollback/freshness policy. | Inject every physical failure point, then restart on target OS/filesystem. Prove old or new complete source, never split Actual/Scheduled or silent valid-old-head restoration. |
| 3 | **Readers, all support and policy.** Exact selected HEAD, native known-section admission, unknown-section preservation, current/old-year review, support/role/Scheduled/Daily Pace, external query config. | Answers coincide with whole-image baseline; any missing old-year segment or dependency reports unavailable; stale cache never supplies substitute truth. |
| 4 | **Copy-first migration + backup.** Capture current native authority and `.prev`, rehearse verifiable baseline creation, corruption, interrupted migration and explicit restore, Git pinning as backup only. | Before any product opt-in, prove a disposable migrated copy matches byte-for-byte and can safely return to original unmodified bytes. |
| 5 | **Real UX and performance.** Actual TUI Dec 31/Jan 1/Jan 3, 2028 repeat, new entry, cross-year correction/Scheduled completion; 1/5/10/20-year benchmark against whole-image. | Seamless real commands, no mandatory year setup or empty idle year, no incorrect historical answer, acceptable measurable overhead. |

A fallback is **explicitly allowed**: if items 1–5 cannot be justified simply, continue reliable `household.loam` plus derived year-filtered, Git-backed *exports*. That is a product choice, not a failed experiment; it must not be described as physical canonical year journals.

## Machine-readable audit and how to run it

- `tools/annual-production-readiness.json` contains separate **existing-engine**, **synthetic-research**, and **cutover** gates with concrete evidence paths and next actions.
- `python3 tools/check-annual-production-readiness.py --json` validates the inventory, current production owner, distinct required gate IDs, declared scope and presence of referenced paths, then prints the blockers. It returns exit **0 for a coherent inventory, not for release readiness**.
- `python3 tools/check-annual-production-readiness.py --self-test` exercises deletion, duplicate IDs, scope promotion, unsafe evidence path, authority-change and toggle-only attempts.
- `python3 tools/check-annual-production-readiness.py --require-ready` must exit **2** while the product gates remain blocked. The CI workflow checks that precise negative behavior.

Changing a gate to `qualified_product` requires reviewed **actual executable product evidence**; changing the ledger status or placing a file at an evidence path proves nothing by itself. The checker is an inventory integrity tool, **not a correctness proof or a migration command**.

## First implementation candidate after this inventory

Do **not** add another UI or convenience option first. Prototype **one generalized native multi-section publication** on isolated synthetic household roots under one selected source HEAD, preserving full House image fallback, unknown sections and no-op refusal. Test one Actual+Scheduled completion and one other real multi-section publisher (e.g. Scheduled+Routing or support-family transition) without editing historical years, then attempt writer integration only after the source commit and durability obligations are addressed.

Issue #2030 remains **open** until its full production physical rollover acceptance is demonstrably met. This read-only audit PR itself changes **no** TUI routes, writers, retention, files under `loam-data`, actual household configuration, migration, or active canonical authority.
