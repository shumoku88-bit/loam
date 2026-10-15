# Native cross-family Scheduled+Actual at a Jan-1 Git source-journal boundary

Date: 2026-10-15  
Status: **Research, not production source migration**  
Related: #1969, merged #2016 (Actual-only publication-year journal)

## One important existing piece to reuse

The production `ScheduledTerminalPublisher.publishHouseholdCompletion`
already publishes **Scheduled terminal evidence and its Actual payment endpoint
in the same validated HouseholdImage generation**, under a coordinated writer
lock and stale-generation refusal. Do not split this accepted operation
into separate independent Actual and Scheduled Git commits or files with
independent visible heads.

The existing `HouseholdAuthority.publishObserved?` checks a declared
set of changed known sections, compares every unchanged section against the
observed source, re-qualifies staged bytes and makes the staged HouseholdImage
visible with one file rename. It is a useful semantic publication boundary
but **not yet a transactional Git+filesystem source commit**.

## Narrow executable experiment

`tools/NativeCrossFamilyYearSource.lean` runs only on the existing disposable
`ScheduledBatchReplacement setup` fixture. It uses the **actual production
Scheduled completion publisher** on open Scheduled identity `first`,
whose existing scheduled/effective date is `2026-11-08`. A single accepted
operation changes the complete **Actual and Scheduled** sections; all other
known and unknown sections must be byte-identical.

`tools/research-source-year-cross-family.py --check` stores:
```text
journal/
  2026/
    000001.household.loam       # admitted complete source baseline
  2027/
    000002.sections.loam        # one atomic pair of Actual+Scheduled bodies
```
The publication day `2027-01-01` is **assigned externally by the test**.
It is deliberately different from Scheduled's occurrence date. This is
the proposed Jan-1 physical publication-year grouping, **not** a claim
that current LOAM publishers retain qualified acceptance-time metadata.

The second source file is UTF-8 text with a minimal research-only
`LOAM-CROSS-FAMILY-SOURCE-PATCH 1` header (test publication day,
full-generation BEFORE/AFTER SHA-256), followed by a *verbatim native*
`LOAM-HOUSEHOLD-IMAGE 2` nested fragment with **both** changed
source-family sections. This is not Tackler's accounting transaction
grammar. Tackler's real FS/Git parser support was separately checked
in #2015 for **derived, representable Actual report projections**.

The test creates two actual temporary Git commits. Replaying exact
Git tree objects reconstructs the same accepted native HouseholdImage
**byte for byte**. The restored generation is read again through the
real `ActualAuthority` and `ScheduledReview`, with the complete Actual
completion endpoints. The earlier year's source bytes are untouched.

Negative trials refuse:
- omission of the entire committed cross-family publication;
- a partial Actual-only completion source without Scheduled terminal;
- a partial Scheduled-only source without completion Actual;
- publication-year/date mismatch;
- corruption of a Scheduled/Actual linked source identity.

No files for empty years, no year-end account closing Event, and no
daily confirmation are created.

## Bounded dual-write crash witness (follow-up to #2018)

The same `tools/research-source-year-cross-family.py --check` now reuses the
**real native Scheduled completion before/after HouseholdImage wires**, the
existing two Git commits, the existing test-only 2027-01-01 publication label,
and an isolated temporary working tree per interruption. No new persistence
engine, journal syntax, CI lane, or production hook was added.

A short subprocess promotes **one** of two independent observable references
at a time: (1) `household.loam` by a staged file replace of the *previously
Lean-admitted* H1 bytes, or (2) the temporary Git repository HEAD from
previously committed G0 to previously committed G1. It uses a **real
`SIGKILL`** after the first or second promotion and inspects both sources
on restart. This subprocess **does not execute the native Lean publisher
during the kill**. Native production publisher admission was exercised
earlier while obtaining H0/H1; the experiment addresses only an outer
hypothetical dual-write orchestration gap.

| Ordering | SIGKILL point | Household | Git | Qualified joint selection |
| --- | --- | --- | --- | --- |
| Household first | after first | H1 | G0 | **mismatch: refuse** |
| Git first | after first | H0 | G1 | **mismatch: refuse** |
| Household first | after both | H1 | G1 | matching pair, **not a durability proof** |
| Git first | after both | H1 | G1 | matching pair, **not a durability proof** |

Each candidate is checked against the **exact two existing native generated
whole-image wires**, and Git G1 is replayed from the committed source-year
journal with both Actual and Scheduled together. This deliberately detects
mismatches instead of choosing a "winner" or inferring the accepted date.
Git G0 and Household H0 are internally valid too: if both roll back, without
an independent freshness anchor a matching old pair can evade detection.

**Result's meaning:** neither order of two independent promotions gives a
single atomic Household+Git publication. There is no proposed production
repair policy. The observed return states are process-kill/filesystem
observations, **not verified power-loss durability**, no `fsync` guarantee
for production `HouseholdAuthority.publishObserved?`, and not an injected
crash *inside* the Lean publisher's staging or renames. A distinct future
acceptance-time clock, idempotent ambiguous retries and versioned restore
remain blocked by the prior Phase 0 audit.

**Stop here unless needed:** No need to multiply mock commit protocols or
add another TLA+ model. Existing `AnnualSegmentCommitRecovery.tla` and
`DAILY_PACE_AUTOMATIC_KNOWLEDGE_PROTOCOL_2026-10-15.md` already spell out
the single-head and learned-time requirements. Choose a unique authority
before experimenting with recovery changes.

## Non-claims / production stop conditions

- This is **two generations in a narrow synthetic fixture**, not a
  qualified comprehensive source-year migration. The first file
  contains a full coherent HouseholdImage. It is not an independent
  2026-only section: historical support and all families are part of
  the baseline, so read-side partial prefix correctness remains open.
- Both changed section **whole bodies are duplicated**, not just
  their changed evidence. Native year-to-year write performance and
  Git pack sizes have **not** been benchmarked.
- Actual and Scheduled are covered here; CurrentQuantityAnchor,
  CurrentQuantityPresence, BoundedHistorySupport, policies, routing,
  and all other source-family transitions must be qualified as well.
- **No reliable actual learned/admission clock** is published in
  the existing operation. Git commit time, file mtime, transaction
  validOn and Scheduled date are not substitutes.
- **Atomic publication across the original HouseholdImage and Git**
  is not implemented. A crash between those steps, partial restore,
  or Git ref rollback requires an explicit future reconciliation and
  independently trusted freshness policy.
- The Git commit at a known SHA is internally content-addressed,
  but a valid older SHA is also internally consistent. Rollback of
  the trusted HEAD to that older generation is undetectable without
  an independent anchor.
- Exact Balance / Daily Pace selective-year loading still requires
  cross-year support, correction, Scheduled, policy and unknown/zero
  completeness. Full-prefix re-admission remains the conservative
  qualified baseline.
- Nothing changes `Loam/*` production code, real `loam-data`,
  canonical schemas, TUI workflows, or the two-month pension cycle.

## Decision gate

The next correct step is **not** to promote this patch format as canon.
Instead, audit all writer seams for grouping and unchanged-section
preservation, then qualify a native successful-publication metadata
protocol (ordered one-generation learned day, no idle date writes,
idempotent retry, restoring with source continuity). Only after that
can a multi-year source store be evaluated against Tackler + Git and
existing whole-text LOAM on 1/5/10/20-year workloads.

This reuses LOAM's existing atomic semantic publisher as the source of
truth; it does not transfer LOAM domain authority to the Tackler parser
or ordinary Git timestamps.
