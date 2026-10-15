# Annual on-demand reader: qualified-index source closure

Date: 2026-10-15
Status: **research-only, no production partition/codec**
Repository: shumoku88-bit/loam, existing storage Issue #1969
Predecessors: #2007 synthetic year query parity; merged #2008 actual Lean
publisher/read-boundary dependency test.

## The concrete problem found in PR #2008

LOAM's actual `ScheduledOpenWorldInspection` activates a completion
terminal only when its referenced Actual Event is present in the *caller
provided* Event memory. A year-filtered caller omitting that Event can
therefore project a completed Scheduled as **open** without any error from
the low-level Review. This behavior is intentional for raw incomplete
evidence and is safe when the current complete HouseholdImage is supplied.
It creates a *new obligation at the prospective partition reader*:
complete the Actual/Scheduled reference graph first, or refuse the query.

This experiment does **not** modify the current Scheduled Review behavior.

## Candidate API without a dedicated daemon

A hypothetical reader obtains a verified/pinned manifest head (an opaque
trusted root digest), then resolves only the partitions containing relevant
source identities and transitive correction/terminal endpoints.
The prototype models the logical algorithm as a standard-library-only
Python harness; its input is *synthetic*, not LOAM's canonical wire format.

- Canonical events are physically assigned to the **admission year**, not
  the Event occurrence year, so a 2027 correction of a 2025 event does
  not rewrite sealed 2025 data.
- A *derived*, rebuildable manifest hint claims effective years and source
  endpoints per accepted operation. Claims can produce false positives
  (more loading), but false negatives would be unsound. This implementation
  models a trusted complete index as a precondition, **not a result**.
- A year-range Actual query loads matching rows and then closes all
  `EventId` correction/validity references transitively.
- A due-year Scheduled query follows retained terminal links through
  to the completion `Actual EventId` or Scheduled replacement identity,
  including endpoints in other publication years.
- The result is computed only from admitted, hash-checked source rows, in
  stable publication order and at the query's learned cutoff.
- A financial answer with **no qualified historical checkpoint** gets a
  conservative **full-prefix** source read plan. It does *not* emit a
  guessed balance, Daily Pace number, or assume unloaded prior balance 0.

An index is a performance hint, **not** a new family of financial facts.
A hand-written manifest digest saved alongside itself would not prove
anything. The experiment passes an independently pinned expected digest
from `seal` to `Reader`, modeling the future admitted root authority.
It does not prove how the actual root was durably committed or protected.

## Reproduction

```sh
python3 tools/research-annual-index-closure.py
```

The fixture uses source-ID-tagged abstract facts with genuine LOAM-like
correction and terminal semantics:

- 2025 Event corrected in 2027; corrected Event re-dated into 2027;
  a further 2028 correction and date revision move it back to 2025.
- A 2025-created Scheduled due in 2026 is completed in one synthetic 2026
  publication group with its target Actual; the valid due/Actual date is
  independent of the publication year.
- A 2027 Scheduled is replaced with a 2029-due Scheduled in one 2028
  synthetic publication group.
- A 2027 admission for a 2025 effective date is retained in the 2027
  physical segment.
- No accepted operations in idle years 2024, 2029 or 2030; no empty
  calendar-year segments are created.

For each 1-, 5- and 10-year segment width, compare **98**
(7 learned cutoffs × 7 effective years × 2 query types) bounded
selective answers to the same data fully replayed, for **294 comparisons
in total**. Additionally check each cutoff's source-only full-prefix
plan against its full oracle, including completeness of terminal endpoints.

Negative controls:
- Naively omitting completion Actual makes an already completed Scheduled
  appear OPEN with low-level semantics; a strict planner refuses it.
- Missing required correction/terminal segments are rejected, never
  substituted with empty/zero evidence.
- A missing irrelevant later segment is not opened for an earlier
  source query; the later full-prefix source query refuses.
- A modified index claim under the previous pinned digest is rejected.

## Why this is not yet a production design

1. Python facts are not the qualified LOAM codec or a proof that the
   canonical Scheduled/Actual/Settlement graph has been exhaustively
   indexed. Real graph validation and provenance require an actual codec.
2. The hypothetical trusted manifest digest is **not** a filesystem
   transaction protocol. Crash between segment file and manifest
   replacement, Git restore, missing parent directories, fsync ordering,
   stale writer and corruption require explicit tests before migration.
3. An up-to-date **complete** index may itself cost time and bytes.
   Measure per-publication update cost and compact manifest growth.
   Do not promote one metadata row per date/record as new canonical truth
   just because a small fixture passes.
4. CurrentQuantityAnchor, CurrentQuantityPresence, bounded history support,
   zero origin, Scheduled routing and policies may cross every year boundary.
   Until qualified independent coverage/checkpoint exists, **current
   balance and Daily Pace load the complete relevant prefix**.
5. The bounded synthetic cutoff uses learned dates supplied by the test.
   Production LOAM does not yet retain automatic learned-time admission
   for all relevant writer paths, so **no as-known product claim** follows.
6. A "dedicated reading engine" is initially a callable library module,
   not an always-on process, user action, or background service.

**Next gate:** decide a small, independently validated committed head +
immutable segment protocol, and falsify it under crash/partial restore,
before promoting any annual directory to real authority. Benchmark
compiled native read/write on identical workloads and compare the
single-Image baseline against 1/5/10-year and append/seal variants.

No real household data, `loam-data`, `Loam/*` production code,
schema, TUI or yearly manual confirmation action changed.
