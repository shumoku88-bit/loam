# Daily Pace as-known history: evidence boundary and delivery design

Status: **research/design qualification only; no canonical migration or feature completion claimed**
Date: 2026-10-15
Owner issue: #1995 (P0). Current-value unblocker: merged #1997 / completed #1996.
Source baseline: main `6fd25b32ceaa9cd56767878b51bb853f90e7686c`.

## 0. User-visible requirement drives the model

The central household question is:

> After protecting fixed bills, other commitments, and savings, how has the
> **remaining discretionary amount per day until the cycle boundary**
> increased or decreased over time, and why?

Not a daily-spending total, envelope budget, or Home dashboard. Home is a
launcher; Daily Pace is a destination.

The daily historical query must mean exactly one of:

- **As known then:** `pace(validDay=d, knowledgeCut=endOfLocalDay(d))` using
  versions/evidence admitted by that knowledge boundary, plus the payment
  cycle and protected obligations *known on that day*.
- **Restated today:** `pace(validDay=d, knowledgeCut=now)` with current,
  correction-aware knowledge about events whose occurrence date is at/before d.

A calculation retrospectively executed today does **not** prove the user
actually opened the TUI or saw those pixels on day d. Saved UI observations
are a separate question, not the default history store. Non-attested legacy
`as-known` values must not silently masquerade as exact ones.

### Existing production formula, unchanged until a reviewed semantics change

For the explicitly configured single-Measure spendable pool S:

```text
B(d, k) = historical pool quantity at end of valid day d,
          using only assertions visible at knowledge cut k
C(d, k) = protected current-open Scheduled net outflows
          with scheduledOn < cycleEndExclusive(d),
          as the household knew them at k
E(d, k) = separately protected savings/earmarks still inside S
          (only if an explicit reserve authority is qualified)

F(d, k) = B(d, k) - C(d, k) - E(d, k)
R(d)    = number of calendar days from d, inclusive, until cycle end exclusive
P(d, k) = exact LOAM integer-quanta division F(d, k) / R(d)
```

Today, `E` is **not** an existing Daily Pace reserve authority. Funds outside
S are already excluded from B; currently open Scheduled outflows leaving S are
already covered by C. Do not subtract either again. Do not infer a savings
reserve from an intention, account name, or Purpose. A transfer *within* S has
net zero pool effect and cannot by itself establish a protected reserve.

Keep original current `CycleSpendingPaceReview.projectForMeasure` rules:
open overdue Scheduled outflows are included; future planned inflows are not
spendable until Actual; intra-pool transfers are net zero; cycle boundaries
are explicit and not calendar-month guesses.

### Concrete invariants the user's history should explain

1. When an already-reserved bill is paid from S, B decreases by x and
   its outstanding C decreases by x. F and the numerator of P **do not**
   decrease a second time. If the paid amount differs from the reservation,
   only the difference affects F, subject to other changes.
2. Spending x on a discretionary purchase from S decreases B and F by x.
3. Transferring to a savings account excluded from S decreases B; when
   previously Scheduled/protected, releasing that matching outstanding
   commitment prevents double deduction.
4. Earmarking a subset of *the same* included account without an actual
   transfer affects F **only if** separately retained protection evidence
   exists. Releasing it increases F; the ledger quantity B does not change.
5. A higher `P` is **not inherently income or saving**. R shrinks as days
   pass. Explain numerator and denominator effects separately.

Within one cycle, define deterministic explanatory components using the
existing signed integer-division semantics:

```text
day_count_effect = div(F_previous, R_today) - div(F_previous, R_previous)
fund_effect      = div(F_today,    R_today) - div(F_previous, R_today)
total_change     = day_count_effect + fund_effect
                 = P_today - P_previous
```

Break `F_today - F_previous` further into available-balance,
outstanding-commitment and retained-savings-reserve differences when those
components are individually supported. Within-cycle explanation is not
silently bridged across the cycle reset. Use exact integer units; no floats
or rounding-based reconciliation.

## 1. Existing LOAM research that answers the general question

**Do not repeat these experiments as generic “new bitemporal research.”**

- `observations/037-how-much-bitemporal-memory-is-needed.md`:
  histories with the *same final frontier* may have different earlier
  knowledge-time frontiers. As-of historical queries earn retained learned
  time. Semantic information is distinct from storage representation:
  change points/events can encode a timeline without daily snapshots.
- `tla/BitemporalCorrectionFrontier.tla`: separate valid and learned
  coordinates, append-only correction frontier, stability of earlier
  knowledge-time views.
- `experiments/100_query_relative_temporal_ambiguity.md` and
  `tla/QueryRelativeTemporalAmbiguity.tla`: ambiguity is **query-relative**.
  Different admissible temporal interpretations may yield the *same* exact
  selected quantity, which need not be refused merely because the
  underlying temporal frontier has alternatives.
- `docs/research/SEMANTIC_AUDIT_SA003_TEMPORAL_EVIDENCE.md`:
  ActualValidity, CapacityEffective, RoutingHistory and learned time have
  different meanings. Reuse the proven latest-visible algebra when suitable;
  **do not invent a universal TemporalMap** from superficial similarity.
- `docs/research/SEMANTIC_AUDIT_SA008_SCHEDULED.md`:
  canonical Scheduled basis is occurrence, terminal relation and routing.
- `docs/research/HISTORY_REGISTER_IDENTITY_BOUNDARY.md`:
  list order is never arrival chronology, and final balances do not imply
  provenance or complete earlier recording.
- `docs/research/TUI_DAILY_PACE_PERIODS_2026-10-10.md`:
  five existing view periods, historical balance batching, explicit support
  refusals, and present historical window all-or-nothing limitation.

External cross-checks (patterns, not instructions to replace LOAM storage):

- Martin Fowler, *Bitemporal History*:
  https://martinfowler.com/articles/bitemporal-history.html
- XTDB, *Time in XTDB*: https://docs.xtdb.com/about/time-in-xtdb.html
- Martin Fowler, *Event Sourcing*:
  https://martinfowler.com/eaaDev/EventSourcing.html

### Daily Pace-specific two-world witness

Assume a cycle with 10 days left on day d, B=20,000, and a known future
bill originally 3,000. The ultimate canonical image contains a replacement
bill of 4,000 and its source-to-successor terminal edge.

- World A learned of the replacement **before** day d.
- World B learned of that **same** replacement **after** day d.

The final Scheduled image, Actual image and all valid dates may be identical.
But on day d:

```text
P_A(d, endOfDay(d)) = (20,000 - 4,000) / 10 = 1,600
P_B(d, endOfDay(d)) = (20,000 - 3,000) / 10 = 1,700
```

Thus existing final Scheduled/Actual facts alone do not determine the
historical as-known Daily Pace. There is no sound default to choosing A,
B, Git commit order, or today's successor as if it had always existed.

A second witness should change only *when* a replacement whose selected
pool net effect remains equal became known. The resulting historical
Daily Pace may be identical in every admissible world. In that case
`P` can be exact despite unresolved lifecycle chronology, **provided all
relevant alternatives and their equal pool effects are qualified**. This is
Observation 100 applied to the actual query; it is not permission to assume
that untracked changes never happened.

## 2. Exact gaps in current production, not speculative duplicates

| Current authority/projection | What can already be proved | As-known gap |
|---|---|---|
| `HistoricalBalanceReview`, `ActualValidityHistory`, `EventCorrection` | Current-knowledge past occurrence quantities; correction-aware source | When each Event/new dated interpretation/correction was *known and committed*; a backdated valid date is not a publication date |
| `ScheduledOccurrence` | Stable identity, expected date, balanced amount | When initial plan became visible |
| `ScheduledTerminal` | Stable completion/replacement/retirement relation; for a completion, retained Actual occurrence date | When closure/replacement/retirement was published, distinct from occurrence date |
| `DailyPaceConfig`, `BoundaryPresetConfig` | Current selected pool and explicit boundaries | Versions of pool membership and boundary policy at each knowledge cut |
| Existing savings treatment | Outside-pool balances and explicit Scheduled outflows | Protection for earmarked funds *inside* selected pool when user requires it |
| `HouseholdAuthority` | One qualified current generation; one previous image for recovery | No durable timeline of all committed household knowledge states |
| Git data-repo history | Opportunistic approximate forensic prior snapshots | Push/commit time does not establish actual local publication time or evidence completeness |
| `DailyPacePeriods` | Current-knowledge daily reconstructions with batch balance support | `days.mapM` refuses an entire range on one bad day; no as-known daily index; no knowledge-time-aware pool policy |
| Merged #1997 | Today's exact calculation and what-if independent of refused historical windows | Does not reconstruct a past as-known household state |

There is **no** justified reason yet to treat CurrentQuantityAnchor as
proof that all historical effects were captured or that exact backdated
capture times exist.

## 3. Architecture candidates to qualify against an explicit contract

### A. Append-only knowledge-change evidence in the Household authority

A retained, identity-bearing sequence (or graph) of *committed household
knowledge changes* bound atomically to the matching
`HouseholdAuthority.publish` generation:

- Scheduled creation and terminal changes (including the successor ID);
- Actual Event entry, correction, cancellation/reversal and date revisions;
- policy/configuration updates that affect P;
- explicit savings reserve/release if needed, with non-double-counting law.

Each admitted action needs a durable **commit-order** coordinate, plus
a qualified local-day/instant coordinate for the as-known end-of-day
selection. A monotonically increasing ordinal prevents collision for
same-instant edits; timestamps alone must not become last-write-wins
authority. Clock skew, retry and partial publication require explicit
semantics. A single atomic Household generation can carry both new fact
and knowledge metadata or reject the whole transition.

Advantages: stays near existing canonical authority and source identities,
replayable without storing each rendered P. Costs: migration, all relevant
publishers and settings must participate, and the retained history may
grow (consider indexing/checkpoints).

### B. Durable committed Household generation archive

Retain every qualified generation with commit-time/order metadata,
query past generations by recorded knowledge time, then derive P using
the *matching* historical query configuration and algorithm semantics.

Advantages: preserves the old full view with fewer new subject-specific
reconstruction paths. Costs: archival growth, external config snapshot
coherence, deterministic replay/index cost, GC/backups and policy
versioning. One `.prev` recovery file is not this solution.

### C. Hybrid (leading candidate for qualification, not yet adopted)

Canonical append-only change evidence + a periodically rebuilt,
non-authoritative **as-of read index/checkpoints** for efficient queries.
Retain enough knowledge chronology to reproduce user-observable past
states. Cache/output snapshots improve performance but do not replace
retained evidence; deleting indexes must be safe.

Evaluate A/B/C on correctness, migration from existing loam-data,
atomically published mixed-family writes, crash/retry, long-history
latency/memory, diagnostics, and integration cost. Do **not** minimize
line count at the cost of the required query.

### Proposed query interface, deliberately independent of TUI

```text
DailyPaceReview.asKnownOn(day, knowledgeCut, admittedEvidence)
   -> Exact(point, provenance)
    | UniqueAcrossAmbiguity(point, admitted alternatives)
    | Unavailable(typed reasons)

DailyPaceReview.restatedOn(day, currentAdmittedEvidence)
   -> Exact / Unavailable
```

The `UniqueAcrossAmbiguity` constructor should be exposed **only when
candidate equivalence is actually checked**; otherwise return unknown.
The same arithmetic implementation serves current, historical and
purchase what-if. TUI owns no second accounting implementation.

Version the meaning of `asKnownOn` if rounding rules, included accounts,
cycle policies, or protection semantics change. Reproducing a historical
**decision** is distinct from restating historic *truth* under today's
algorithm.

## 4. Implementation/qualification order: ship the user question

1. **Meaning + change point experiments:** write executable Daily Pace-specific
   witnesses for different learned dates and identical final data, for
   ambiguity with equal selected-pool effects, and bill settlement
   non-double-counting. Reuse Observations 037/100; prove the bridge to
   actual arithmetic instead of restating generic temporal theorems.
2. **Durable knowledge history:** choose A/B/C with explicit invariants and
   migration. Inventory and update *every relevant publisher* atomically,
   including configuration and late Actual. Preserve old image reader
   compatibility or perform a fail-closed versioned migration; never alter
   operational user data merely by testing.
3. **As-of reconstruction core:** one accepted/qualified historical image
   per knowledge cut or equivalent typed change-point index; resolve valid
   day, policy version, cycle horizon, pool quantities, outstanding
   commitments, protected savings and corrections consistently. Compare
   pointwise with independent current result at the latest cut.
4. **Visible partially supported graph:** represent **day-indexed**
   `exact | invariant-under-ambiguity | unavailable(cause)` samples, and
   break lines at unknown days. Do not display restated-today values in the
   as-known series without an explicit label. Preserve current value and
   what-if even when all historical points are unknown.
5. **Explanations:** show `F`, `R`, `P`, protected Scheduled/savings and
   within-cycle changes. Account for integer-rounding residual and
   distinguish time passage from cash/obligation changes. Do not imply
   causal provenance unsupported by the available evidence.
6. **Performance and durability:** same-generation consistency, no
   query-time writes, no unbounded per-keystroke reconstruction, bounded
   memory or measured resource behavior for 10–20 year histories.
   Model-check crash/retry and partial publication once topology is chosen.

### Must-pass scenario matrix

- exact current and what-if when every old day fails;
- two different learned times, same final Scheduled image, different
  day-d P, plus identical-effect replacement not making P unknowable;
- late/backdated Actual, date revisions, corrections/reversals and
  cross-day known-time cut;
- scheduled creation/replacement/cancellation/completion on distinct
  valid-vs-recorded dates; outstanding overdue; future inflow uncounted;
- reserved bill completion does **not** spend discretionary money twice;
- savings already outside pool, Scheduled savings transfer, earmarked
  reserve inside pool, reserve release, transfer within pool, all without
  double deduction;
- explicit cycle boundary, day-count-only increase, cycle reset, changes
  to pool policy/boundaries, unknown predecessor and unknown history;
- multi-write same instant, retry, clock skew, publication crash,
  concurrent writer, restore, migration and old data with unknown knownAt;
- all five existing date windows, mixed-known and unknown date
  islands, 24x8 through wide terminal, `q` navigation, no UI writes;
- exact integer quanta and like-Measure comparisons only;
- long-period query complexity and storage growth measured on synthetic
  inputs and historical replay, not guessed.

## 5. Actual historic backfill and non-goals

The operational data repository's Git history *may* permit forensic
reconstruction of some historic states, but without a qualified one-to-one
publication record it cannot certify exactly when every edit was learned.
Tag each recovered interval with evidence status instead of constructing
invented exact backdates.

Do not:

- equate Scheduled due dates or Actual occurrence dates with learned times;
- treat representation/list order as temporal authority;
- turn one missing historical fact into current-value unavailability;
- reintroduce envelopes as a requirement for discretionary capacity;
- invent earmarked savings or auto-classify a reserve by account label;
- make Home a fixed money dashboard;
- close #1995 because the current-value regression #1996 was repaired.

**Executable bridge included with this design PR:** the existing
`Loam/Tests/CycleSpendingPaceReview.lean` now exercises the production
Daily Pace kernel against (a) differing as-known Scheduled frontiers with
the same eventual final image, (b) identity-distinct replacements that
produce the same selected-pool value, and (c) completed, previously
protected bills that must not be deducted twice.

These synthetic tests qualify **the Daily Pace arithmetic consequence**
of the existing temporal research. They do not yet provide a persistent
knowledge-time authority, provenance coverage, or historical TUI behavior.
Next implementation PRs should qualify savings reserve semantics,
durable known-time publications, and replay/query projections.
