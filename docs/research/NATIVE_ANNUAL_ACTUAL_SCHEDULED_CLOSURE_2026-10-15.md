# Native Actual/Scheduled year-reader dependency closure

Date: 2026-10-15
Status: **research only; no partitioned production authority**
Related: Issue #1969, merged PR #2007 (symbolic 1/5/10-year planner),
merged #2005 (automatic knowledge admission model).

## What we need to know

An annual on-demand reader may not simply open "2027 Actual" and
"2027 Scheduled" and assume that all obligations/current amounts can
be reconstructed. The **actual** correction/validity and Scheduled
completion links can refer to events with effective dates in other
years.

This test ties the next model to **existing admitted LOAM codecs**,
**real publishers** and **real Review frontiers** without inventing
publication/knowledge timestamps that LOAM does not yet retain.

## Reproduce on a disposable test-only household

Run after building imported Lean modules:

```sh
root="$(mktemp -d)/native-annual"
lake env lean --run Loam/Tests/ScheduledBatchReplacement.lean setup "$root"
lake env lean --run tools/NativeAnnualReadProbe.lean "$root"
```

The setup uses existing production Scheduled completion/cancellation writers,
and includes one current completion Actual, six Scheduled occurrences,
a 2027-due occurrence and scheduled routing across the year boundary.

The native probe:

1. Loads one **qualified Household generation** via
   `ActualAuthority.loadHouseholdObserved?` and derives Scheduled from
   *the same* generation and Event memory with
   `ScheduledReview.fromGenerationForEvents`.
2. Confirms a completed 2026 Scheduled is not open while 2027-due
   obligations remain open.
3. Intentionally passes an empty Actual Event memory to that same
   Scheduled reader and requires an error: a planner which omitted
   the completion Actual must not silently claim the obligation is open
   or settled.
4. Publishes a dated 2025 Actual using the **real**
   `MovementPublisher.publishDraft`, corrects its amount using the
   real `CorrectionPublisher.publishCorrection`, and moves the
   winner's effective date into 2027 via
   `ActualValidityPublisher.publishDate`.
5. Confirms the old Event remains retained but superseded, the
   replacement is current in 2027, and the Scheduled section remains
   identical after all Actual-only publications.
6. Computes a **transient identity dependency closure** over the real
   normalized Actual Review correction graph. Both 2025 and 2027
   target-year queries must identify **both** related Event IDs, even
   though only the 2027 replacement is current. For 2025/26/27,
   current-year results agree with production Review's complete-image
   current answers.

## What the test deliberately does NOT establish

- It does **not** physically split canonical HouseholdImage or measure
  segment I/O performance. The transient closure is calculated from
  a **fully admitted image** and therefore is an **oracle/requirement**
  for a future selective reader, not that future reader itself.
- It does **not** reconstruct a historical *as-known* 2025 view.
  The real writer retains Event validity but has **no qualified learned
  publication-time source** for these synthetic operations today.
  Treating a validOn date as a learned date would be a serious
  correctness error.
- It does not qualify a cross-segment atomic commit protocol,
  an index/manifest, a restore path, or durable checkpoints for
  CurrentBalance/DailyPace.
- The Schedule fixture uses the real existing
  `ScheduledTerminalPublisher`, but the independent Actual correction
  operations later on are ordinary successive publications, not a
  newly introduced multi-file transaction.

## Next safety/design gates

- A proposed **small index** must be derived from qualified source
  IDs and revision/terminal links and must refuse stale, missing,
  mixed-generation or conflicting index claims. The manifest is a
  selection optimization only, **not** independent financial authority.
- A safe annual layout groups retained information by **admission
  year**, not original valid year, so later corrections don't rewrite
  sealed historical knowledge. It must retain intra-day ordering
  when policy winners require it.
- Balances/Daily Pace require cross-year support, Scheduled coverage
  and time-qualified policy versions; until independently qualified
  checkpoints cover prior facts and their late corrections, the
  request planner must conservatively load the whole necessary
  prefix. Unknown remains unknown, never zero.
- Measure against current one-image compiled baseline (#1969)
  using the **same actual workload** before selecting 1-, 5-, or
  10-year physical segments. A separate reader process or daemon
  is not necessary until evidence warrants it.

Production `Loam/*`, `loam-data`, canonical formats, year-end
user actions and existing Daily Pace arithmetic are unchanged.
