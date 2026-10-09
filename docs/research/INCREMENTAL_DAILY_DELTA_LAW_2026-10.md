# Incremental daily delta law (bounded Lean 4 experiment)

Status: **research-only**. No production or canonical household data change.

## Question

Once the existing LOAM authority has admitted the current correction frontier,
valid dates, Measure boundaries, and any required AccountingRole selection,
can a date/Measure total be updated after one append or replacement without
recomputing every selected contribution?

The answer to this **narrow arithmetic** question is yes. The experiment
proves equality with a full-list oracle. It does **not** prove that arbitrary
raw changes can be classified, admitted, or applied incrementally.

## Artifacts and checks

- `Loam/Tests/IncrementalDailyDelta.lean`: self-contained Lean 4 laws and
  concrete date-change and currency-isolation examples.
- The existing Lean Application workflow separately checks the proof via
  `lake env lean Loam/Tests/IncrementalDailyDelta.lean`, after its usual application
  tests; the regular test groups remain unchanged.
- Focused command: `lake env lean Loam/Tests/IncrementalDailyDelta.lean`
  (or `lake test -- IncrementalDailyDelta`).

The model uses one signed integer amount at a `(day, Measure)` bucket.
Only an already admitted/selected row contributes to the modeled input list.
A replacement explicitly identifies exactly one existing row:

```text
recompute(prefix ++ [old] ++ suffix)
  - contribution(old)
  + contribution(new)
= recompute(prefix ++ [new] ++ suffix)
```

The theorem is universal over the prefix, suffix, removed and added row,
day/Measure bucket, and signed integers. A different date or Measure changes
which bucket receives the positive or negative delta. The proof uses no
`sorry`, external axioms, database, index, or retained cache.

## What is intentionally not proved

- Raw `EventCorrection` or validity evidence selects the old/new rows.
- A proposed replacement is admitted by LOAM's correction/routing/lifecycle
  rules. The existing authority remains responsible for these decisions.
- Every account classification is known. Missing evidence must still fail
  closed rather than become zero.
- Temporal snapshots, current-anchor obligations, retroactive role changes,
  and multi-Event corrections can be updated without broader invalidation.
- A cache remains correct across crashes, concurrent writes or stale
  generations; no such cache is introduced here.
- Incremental updates are faster in a real workload. No speedup is claimed.

## Nearest existing owners

- `Loam/Application/CorrectionFrontierIndexed.lean`: authoritative
  admission-related correction frontier *projection*, not replaced here.
- `Loam/Review/TransactionsFlowReview.lean`: one report's selected rows.
- `Loam/Review/CycleSpendingPaceReview.lean`: existing finite-vector
  history optimization is not reimplemented.
- `Loam/Authority/HouseholdAuthority.lean`: canonical generation ownership,
  staleness refusal, and read qualification remain untouched.

This answers the incremental-update question identified under MATH-5 in
`docs/research/MATHEMATICAL_STRUCTURE_MAP_DRAFT_2026-09-25.md` without
promoting a generic incremental engine.

## Follow-up gate

Only if a concrete report exhibits repeated full recomputation should a
production implementation be proposed. It must compare the answer **and
refusal cases** against the existing full calculation, handle past corrections
and evidence reclassification, measure throughput/memory, and remain
rebuildable from canonical LOAM evidence.

For Bakhlo, the same law can be tested against its own admitted current-book
representation and full oracle. Bakhlo's corrected-entry storage need not
copy LOAM's retained correction-chain semantics.

Background: DBSP formalization (Lean 3), https://github.com/tchajed/database-stream-processing-theory .

## Follow-up: canonical correction-frontier bridge

`Loam/Tests/IncrementalCorrectedFrontier.lean` composes **two separately
admitted Actual images** (before and after a single correction), obtains the
current `ActualReview` rows, and cross-checks their Event identities against
the existing `correctionFrontierMemory?` projection. It then compares
date/Measure totals under a removed-old / added-new delta against full current
row selection, including a date change, unaffected EUR data, a malformed
correction, and an undated nonzero contribution.

The `qualified_single_replacement` theorem is **conditional**: source
selection must independently establish that before/after current rows differ
by one exactly identified contribution, with all other selected contributions
unchanged. Neither the theorem nor the runtime test proves this relation for
*every* permitted correction, historical validity correction, grouping or
classification change. A production updater must prove/verify that premise
or recompute from canonical evidence.

No cache, scheduler, persistent index, production query or canonical writer is
introduced. Both Lean files are checked in the existing Application workflow.
