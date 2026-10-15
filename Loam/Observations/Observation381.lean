import Loam.Review.CycleSpendingPaceReview

namespace Loam.Observation381

open Loam.Core

set_option autoImplicit false

/-!
# Observation 381 — minimal day-end knowledge representation

This research-only encoding comparison takes a *qualified* list of already
retained source values and its learned-day association as input. No new
household fact, publisher, or clock authority is introduced here.

Tagged representation: one learned day per source occurrence.
Bucket representation: one day shared by the source occurrences learned then.

The theorem does not infer knowledge dates, source completeness, ordering, or
the currently external Daily Pace/cycle configuration. Those are independent
admission obligations. This is a representation theorem, not a migration.
-/

/-- Expanded per-reference knowledge-day association (research model). -/
def expand : List (Nat × List Nat) → List (Nat × Nat)
  | [] => []
  | (day, values) :: rest =>
      values.map (fun value => (day, value)) ++ expand rest

/-- Read all references visible at the end of a cut day in tagged form. -/
def visibleTagged : List (Nat × Nat) → Nat → List Nat
  | [], _ => []
  | (day, value) :: rest, cut =>
      if day ≤ cut then value :: visibleTagged rest cut
      else visibleTagged rest cut

/-- Read exactly the same day-end question directly from grouped form. -/
def visibleBucket : List (Nat × List Nat) → Nat → List Nat
  | [], _ => []
  | (day, values) :: rest, cut =>
      if day ≤ cut then values ++ visibleBucket rest cut
      else visibleBucket rest cut

private theorem taggedMapOneDay (day cut : Nat) (values : List Nat) :
    visibleTagged (values.map (fun value => (day, value))) cut =
      if day ≤ cut then values else [] := by
  induction values with
  | nil =>
      simp [visibleTagged]
  | cons value rest ih =>
      by_cases h : day ≤ cut
      · simp [visibleTagged, h, ih]
      · simp [visibleTagged, h, ih]

private theorem taggedAppend (first second : List (Nat × Nat)) (cut : Nat) :
    visibleTagged (first ++ second) cut =
      visibleTagged first cut ++ visibleTagged second cut := by
  induction first with
  | nil => rfl
  | cons entry rest ih =>
      rcases entry with ⟨day, value⟩
      by_cases h : day ≤ cut
      · simp [visibleTagged, h, ih]
      · simp [visibleTagged, h, ih]

/--
The same grouped references, in their within-bucket list order, reconstruct
exactly the same day-end visible reference sequence as individual tags.

The theorem holds for arbitrary finite buckets/cuts, including repeated days.
It deliberately makes no assertion that a bag/set-only bucket retains order.
-/
theorem bucketDayEnd_eq_taggedDayEnd
    (groups : List (Nat × List Nat)) (cut : Nat) :
    visibleBucket groups cut = visibleTagged (expand groups) cut := by
  induction groups with
  | nil => rfl
  | cons group rest ih =>
      rcases group with ⟨day, values⟩
      by_cases h : day ≤ cut
      · simp [visibleBucket, expand, h, taggedAppend, taggedMapOneDay, ih]
      · simp [visibleBucket, expand, h, taggedAppend, taggedMapOneDay, ih]

/--
Model an already-admitted positive protection effect per reference. This is
not a new Scheduled state or amount copy in LOAM: the values stand for a
projection from the existing canonical source IDs at the selected knowledge
cut, subject to writer-coverage and lifecycle qualifications.
-/
def paceFromQualifiedEffects
    (eligiblePool : Int) (remainingDays : Nat) (effects : List Nat) :
    Option Int :=
  let protection : Int := Int.ofNat effects.sum
  let snapshot : Loam.CycleSpendingPaceReview.Snapshot := {
    observedAt := "2026-10-15"
    endExclusive := "2026-12-15"
    remainingDays := remainingDays
    eligiblePool := Quantity.ofQuanta eligiblePool
    automaticDeductions := Quantity.ofQuanta protection
    availableThroughEnd := Quantity.ofQuanta (eligiblePool - protection)
  }
  snapshot.dailyPaceQuanta?

/--
Day bucketing does not change the production Daily Pace division on this
already-qualified finite projection; it merely changes how the same
knowledge-day association is represented.
-/
theorem bucketedDailyPace_eq_taggedDailyPace
    (groups : List (Nat × List Nat))
    (cut remainingDays : Nat) (eligiblePool : Int) :
    paceFromQualifiedEffects eligiblePool remainingDays
      (visibleBucket groups cut) =
    paceFromQualifiedEffects eligiblePool remainingDays
      (visibleTagged (expand groups) cut) := by
  rw [bucketDayEnd_eq_taggedDayEnd]

/--
Dropping a change because today's displayed quotient did not move is not
safe for a later query with fewer remaining days.
-/
theorem unchangedPaceToday_canChangeTomorrow :
    ((80 : Int) / 10 = (81 : Int) / 10) ∧
    ((80 : Int) / 9 ≠ (81 : Int) / 9) := by
  decide

end Loam.Observation381
