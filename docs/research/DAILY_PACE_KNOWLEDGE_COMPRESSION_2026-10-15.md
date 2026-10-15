# Daily Pace knowledge-history compression: bounded counterexamples and representation law

Status: **research qualification candidate, no canonical migration**  
Date: 2026-10-15  
Parent: #1995 (P0)  
Verification owners: `experiments/381_daily_pace_knowledge_minimality.als` (Alloy) and `Loam/Observations/Observation381.lean` (Lean 4)

## The exact question

The target is **the end of each local day as then known**, not every
intermediate keyboard action and not merely the most recently restated past.

Can LOAM retain only the independent knowledge coordinates newly required to
reconstruct Daily Pace, reusing its existing Actual and Scheduled identities,
correction/replacement edges, quantities, and computation, without saving
daily values, snapshots, derived status, or duplicate money movements?

Three encodings were compared:

| Encoding | Retained independent meaning | Benefit | Hazard |
|---|---|---|---|
| A: per-reference learned day | Association between a retained source/revision/edge and qualified knowledge cut | Straightforward typed references, simple incremental write | Repeated date text |
| B: day bucket of retained references | **Same association** with shared day | Potentially smaller when many changes/day | An unordered bucket cannot supply last-writer semantics by itself |
| C: only a change in displayed Daily Pace | A selected displayed scalar's change points | Very small | Does not preserve future quotients, pool/protection components, explanation, or policy changes |

A and B are alternative *encodings*, not reasons to create competing
canonical authorities. Neither authorizes a second copy of Scheduled amounts or
Actual movements. The source reference must continue to resolve to qualified
immutable evidence in the retained household authority.

## Formal question 1: why some learned-day information is necessary

The Alloy model fixes two immutable obligation amounts, 3 and 4, and retains
the same final identities and explicit predecessor/successor relationship.

World A learned the replacement on D0; World B learned it on D1. At the
end of D0, the protection and hence Daily Pace differs, even though the final
household image is identical. A single latest-state snapshot therefore loses
a legitimate answer.

This is a Daily Pace-specific specialization of Observation 037's
knowledge-time quotient, not a new generic bitemporal theory.

## Formal question 2: when is a day bucket insufficient?

Alloy also lets two writes to a mutable last-write-wins query policy occur
on D0. The two worlds retain **identical** day-to-reference memberships.
One world writes the old version last; the other writes the new version last.

An *unordered* bucket cannot determine the selected policy. The intentionally
false assertion `DayBucketsAloneDetermineLastWriteWins` should yield a
counterexample. This is not a defect in day-level sampling: it is a loss of
the end-of-day winner.

However, when source identities already have a retained replacement relation
whose selection semantics determine the successor, `ExistingReplacementRelationDeterminesDayEnd`
should hold within the bounded model, regardless of incidental entry order.

**Minimality rule:** do not store an extra ordinal per item if an already
retained semantic predecessor/successor edge determines the admitted end-of-day
state. Conversely, if a replaceable policy has no retained versions and
no known final winner, the day bucket alone is inadequate. In that case
retain a minimal identified policy version/winner or an equivalent ordered
commit-coordinate. Preserve the distinction between committed knowledge
order and wall-clock arrival.

A separate Alloy witness shows that equal numeric protected contributions do
not identify the same Scheduled source. Scalar-only compression would lose
why a payment disappeared and whether one bill was completed or replaced.

## Lean 4: precise positive boundary

`Observation381.bucketDayEnd_eq_taggedDayEnd` proves for all finite
ordered buckets and all day cuts that expanding each bucket into individually
tagged references produces **the same visible reference list** as selecting
visible buckets directly.

`Observation381.bucketedDailyPace_eq_taggedDailyPace` then feeds either list
to the current `CycleSpendingPaceReview.Snapshot.dailyPaceQuanta?` division
after constructing the same already-qualified balance/protection projection.
It proves identical results, not two independently implemented accounting
formulas. `unchangedPaceToday_canChangeTomorrow` proves a concrete
integer-division counterexample to scalar-only change retention.

**Important proof scope:** the bucket retains the within-day list ordering.
This theorem does not prove that a *set* of references is sufficient, or that
the complete production source/policy/configuration states can already be
replayed. Those are separate semantic/persistence obligations; the Alloy
counterexample identifies one of them. Production event/revision semantics
remain governed by existing frontiers.

## Existing evidence reused, not repeated

- `observations/037-how-much-bitemporal-memory-is-needed.md`: answer vocabulary sets the semantic minimum.
- `Loam/Observations/Observation029.lean`: sufficiency and mutual-recovery laws; no new abstract compression framework necessary.
- `experiments/100_query_relative_temporal_ambiguity.md`: distinct interpretations can still yield one justified selected quantity.
- `docs/research/SEMANTIC_AUDIT_SA003_TEMPORAL_EVIDENCE.md`: learned-time and valid/effective time are not the same.
- `docs/research/SEMANTIC_AUDIT_SA008_SCHEDULED.md`: retained Scheduled occurrence plus terminal relation, not a canonical status or headroom stream.
- `docs/research/DAILY_PACE_AS_KNOWN_DESIGN_2026-10-15.md`: query vocabulary, correctness boundaries and publisher risks.

## Architecture consequence, still a hypothesis

Prefer a small **reference-to-knowledge-cut association**, grouping repeated
date bytes as a physical optimization if measured savings justify it. Prefer
known successor/correction topology to inventing an independent ordering field.
A retained batch with shared commit-day may reference several fact IDs, but
all facts required for one transition must be atomically visible.

Do not assume the cheapest encoding from synthetic per-record byte counts:
compression ratio depends on update density, reference format, encoding,
staging/rewrites and archive strategy. Measure bytes, replay latency and
write amplification separately.

The current external replaceable `daily-pace.tsv` and boundary presets also
lack historic policy versions. They must not silently use today's membership
or cycle policy for an old as-known cut. A policy-specific version reference is
a real additional distinction *when the query can observe it*.

Past operational states before complete, admitted capture remain `unknown`.
Git commit dates, current row order and Schedule occurrence dates are not
substitutes for knowledge dates.

## Next boundary before implementation

1. Enumerate source-changing writers (creation, replacement, retirement,
   completion, late Actual, revisions/corrections, relevant policy editors).
2. Decide whether the user needs end-of-day only; validate local-day and
   boundary semantics under same-day and clock-skew conditions.
3. Model the whole-generation atomic commit, stale preview, retry and crash
   boundaries in TLA+ *once the physical storage topology is selected*.
4. Measure tagged-vs-bucketed metadata bytes and read/write costs on
   synthetic 1-year and 10-year workloads; avoid premature index authority.
5. Prove the narrowed source-selection correspondence to LOAM's actual
   Scheduled/Actual writer closures before calling historical replay exact.

No `loam-data` changes, new production Core fact families, TUI changes, or
cross-family publication claims are made by this research slice.
