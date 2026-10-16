# Annual storage research retirement and product reset

Date: 2026-10-16
Tracking: [#2030](https://github.com/shumoku88-bit/loam/issues/2030) (product) and [#1969](https://github.com/shumoku88-bit/loam/issues/1969) (history/performance)
Retired working-tree snapshot: [0f5f03b10956dcefdfb7289cc327a7f5ef67a5c8](https://github.com/shumoku88-bit/loam/tree/0f5f03b10956dcefdfb7289cc327a7f5ef67a5c8)

**STATUS: cleanup only. No annual canonical storage, migration, or new TUI behavior has shipped.**

## Why this surface was retired

The October 15–16 annual-source prototypes accumulated separate experimental HEAD owners, replay adapters, route probes, durability wrappers, Python harnesses and CI jobs. They established useful constraints (cross-family atomicity, fail-closed missing sources, exact operation identity, result-unknown observation, and full-image parity), but were not invoked by ordinary LOAM. Their native publication format stores a **complete HouseholdImage for every accepted operation**, so simply grouping files under calendar years does not bound retained-history rewrite, replay, memory, or storage costs.

These files are **not deleted from history**. Inspect or restore any specific experiment directly from the pinned commit above or its PRs; do not reinstate the entire test suite without a concrete need. This removes the live duplicated experimental surface, not the lessons or the product objective.

## Current production and retained checks

- The installed authority remains a single `household.loam`. No writes to `loam-data`, no migration and no second canonical owner occurred in this cleanup.
- Keep `Loam/Tests/JanuaryFirstHousehold.lean` for Dec 31/Jan 1 balances, Scheduled completion and pension-cycle continuity.
- Keep native `HouseholdAuthority`, normal command/TUI behavior, Actual projection and readable journal export.
- Keep manual `tools/research-horizon-baseline.py`, `tools/research-horizon-write.py` and `tools/HorizonWriteProfile.lean` for comparable long-history measurements; retire the one-off automatic horizon workflow.
- Keep the registered `tla/Annual*.tla` / `*.cfg` safety counterexamples and the shared TLA research case registry; they remain independent safety witnesses without a new always-on annual test pipeline.

## Simpler proposed product behavior (not yet implemented)

1. One independently stored calendar-year journal, with current year **writable**, previous year **usually readable**, and older years **opened explicitly on demand**. Avoid reading twenty full journals to write one current entry.
2. A year switch creates the new book using *verified* carried state (account identity, balances with evidence/unknown distinction, unpaid Scheduled commitments, and current pension-cycle inputs). No Jan 1 reset, inferred zero, fabricated opening transaction or AI-guessed balance.
3. Backdated changes and corrections must not silently diverge from verified carryover or alter old immutable evidence. Choose a small explicit correction/requalification policy before implementation.
4. Reuse current native codecs, reviews, TUI commands and existing results. Compare actual read, write, memory and restore costs against single-image baseline for 1/5/10/20-year synthetic fixtures.
5. Production cutover, copy-first verification, backups, and explicit user approval are separate work. An experimental archive is not proof of future physical year files being safe.

## Do not accidentally regress

Never silently fall back to a valid but older source after an incomplete restore; distinguish unknown from zero, absent from known empty, and result-unknown from definite write refusal. Actual + Scheduled updates must remain one logical acceptance. A backup/derived report must not become a second source of truth.

If a future PR needs one of the archived research modules, restore only the needed files from the pinned historical commit and show the new direct product caller and bounded-performance evidence.
