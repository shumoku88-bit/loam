# Jan-1 native LOAM source journals at Git commits (research)

Date: 2026-10-15  
Status: **research-only prototype, NOT a production canonical migration**  
Tracking: [Issue #1969](https://github.com/shumoku88-bit/loam/issues/1969).
Prior gates: #2012 section COW, #2013 native Actual TX delta,
#2014 qualified PTA year-sharded view, #2015 **real Tackler 26.10.1 FS/Git
balance parity**.

## New question

Can Git manage **human-readable, date-of-source-publication
journal files** which replay exact real Lean-admitted Actual
HouseholdImage snapshots, instead of only current-accounting derived
Tackler `.txn` text?

The user's date boundary is **January 1**, without optional year-end
close transactions or annual user confirmation. A backdated
2025-effective Event first admitted on 2026-12-31 belongs in the **2026
source** journal. A 2027-01-01 admitted correction of that Event
belongs in **2027 source**, without rewriting any 2026 source file.
The corrected financial *effective-year query* remains a separate
question, and the pension two-month cycle is untouched.

## What the PR does

`tools/research-tackler-git-source-year.py --check`:

1. Obtain **four genuinely native qualified** synthetic
   `household.loam` snapshots from existing actual
   `MovementPublisher`, `CorrectionPublisher`,
   `ActualValidityPublisher`, plus full Scheduled setup.
2. For this test **only**, supply explicitly synthetic publication
   days: `2026-12-30`, `2026-12-31`, `2027-01-01`,
   `2027-01-02`. These dates are NOT recovered from actual LOAM
   source, Git timestamps, or `validOn`. The current LOAM source
   publishers do not yet provide universally qualified admitted
   timestamps for this purpose.
3. Store the initial **unaltered** real HouseholdImage wire text
   inside `journal/2026/000001.household.loam`.
4. Store each subsequent admitted Actual change as one
   **human-readable** `LOAM-SOURCE-YEAR-TX-PATCH\t1` text file
   under its **test publication year**:
   ```text
   journal/
     2026/
       000001.household.loam      # complete initial actual+scheduled source
       000002.actual-patch.loam   # admission of late 2025-effective event
     2027/
       000003.actual-patch.loam   # new REPLACES source in 2027
       000004.actual-patch.loam   # changed full native TX with DATE-REV
   ```
   A patch includes a synthetic publication day and full before/after
   HouseholdImage SHA-256 identifiers, plus only changed **verbatim
   original normalized Actual `TX..ENDTX` blocks**. There is no SQL,
   fabricated balancing Event, inferred date, irreversible export, or
   new production Core entity.
5. Make one **real temporary Git commit** per admitted generation
   and replay exact journal *Git objects* at each SHA. Reconstructed
   full `household.loam` must match native snapshot **byte-for-byte**
   and be admitted by the same real native
   `ActualAuthority.loadHouseholdObserved?` and
   `ScheduledReview.fromGenerationForEvents` readers.
6. Check that 2027 source publications do not alter any already
   committed 2026 source journal file, including the 2025-effective
   original, and that 2028 has no empty files.
7. Refuse missing interior journal sequence, mutated late
   `DATE-REV`, unsupported non-Actual family changes, unresolved
   before/after source hash, nonmonotonic publication-date label,
   misplaced year, and invalid appended/replaced TX identity.
   Working-tree tampering does not affect a **pinned Git commit**.

## Critical differences from #2014 / #2015

Those PRs tested **disposable Tackler `.txn` accounting projections**,
organized by *effective date*. Such a file correctly disappears
from a later current report if an Event is superseded or moved to
another effective year; Git can still reproduce the earlier projection.

This PR, conversely, tests a **candidate annual source journal**,
organized by test **publication date**, preserving correction and
validity revision records. Tackler **cannot parse this new
`.actual-patch.loam` file** and is not claimed to. It is LOAM
research source syntax; Tackler may remain the selected read/report
engine for only the representable accounting subset.

The sequence test does **not** independently establish trustworthy
learned time: the admission days are injected **by the research
test**. This is deliberately labeled a gap. Neither Git commit
time nor normalized Event valid date can be silently substituted
for an admitted source clock.

## Deliberate restrictions and stop conditions

- The first source file is **a full coherent HouseholdImage**, not an
  annual slice of every family. Following experiments only replace
  or append one complete normalized Actual transaction block.
- Entire changed `TX` bodies are duplicated on a date revision.
  No typed `DATE-REV`-only op grammar is admitted.
- The prototype **refuses** changes to the Scheduled, policy, anchors,
  and other HouseholdImage sections. This means it cannot yet
  represent real co-published cross-family operations. Production
  cannot use this lane without safe multi-family support/fallback.
- Each read currently traverses **the entire publication prefix**,
  reconstructs the whole HouseholdImage, then Lean re-admits it.
  There is no native lazy-year reader, source coverage checkpoint
  or bounded startup/partial query guarantee yet.
- Git's commit graph protects **objects in a selected trusted
  commit**, not the trustworthiness/freshness of the ref pointing to
  it. A rolled-back but valid older Git SHA remains readable and
  **cannot be diagnosed as stale** without an independently
  trusted monotonic source of freshness.
- Git commit and the existing LOAM publisher's atomic local authority
  publication are **not an atomic transaction**. Writer crash recovery,
  HEAD ref replacement durability, concurrent writer protection,
  actual knowledge clock and source backfill migration are separate
  production stop conditions.
- No historical learned-time queries, complete Balance/Daily Pace
  prefix, current-quantity support, unknown-vs-zero status, source
  reader performance or year-end book-closing are claimed.

The experiment uses only disposable synthetic native sources in
temporary directories. It does not change production `Loam/*`,
`loam-data`, current canonical wire, actual Git repository, UI or
user behavior.

## Next gate

Before implementing source-year writers, qualify **the actual writer
admission clock** and a **multi-family retained source-delta** format
or an atomic, verified complete-image fallback. Then compare
start-up, change time, Git object count/pack size, RSS and verified
read times at 1/5/10/20 calendar years. Only allow genuinely
narrow year selection when the Actual correction and Scheduled
completion dependency graph, support/evidence coverage and as-known
cutoffs prove it complete.

For reports, continue reusing Tackler FS/Git backend where faithful,
but **never promote lossy PTA output to household authority**.
