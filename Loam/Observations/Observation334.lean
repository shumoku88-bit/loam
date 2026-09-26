import Loam.Core.HistoricalRouting
import Loam.Core.Effect
import Std.Data.HashMap.Lemmas

namespace Loam.Observation334

open Loam.Core
open Std (IsLinearOrder)

set_option autoImplicit false

variable {Time : Type}
  [LE Time]
  [DecidableRel (· ≤ · : Time → Time → Prop)]
  [Std.IsLinearOrder Time]

/-!
# Observation 334 — fixed-time Actual routing status image

`RoutingHistory.statusAt` is deliberately a simple focused specification: one
query scans the retained history and selects the latest visible assertion for one
subject.

Several production readers ask the same history at one fixed observation
coordinate for many Loci. This observation asks whether those repeated focused
queries factor through one transient fixed-time image.

The image is keyed only by the exact `LocusId.token`. It retains, for each
Locus visible at the queried time, the latest visible `RoutingEntry`.

No persistence or routing authority is changed.
-/

abbrev LatestIndex (Time : Type) :=
  Std.HashMap String (RoutingEntry LocusId Time)

private def chooseLatest
    (validOn : Time)
    (entry : RoutingEntry LocusId Time)
    (current : Option (RoutingEntry LocusId Time)) :
    Option (RoutingEntry LocusId Time) :=
  if entry.effectiveOn ≤ validOn then
    match current with
    | none => some entry
    | some prior =>
        if prior.effectiveOn ≤ entry.effectiveOn then
          some entry
        else
          some prior
  else
    current

private def updateEntry
    (validOn : Time)
    (entry : RoutingEntry LocusId Time)
    (index : LatestIndex Time) : LatestIndex Time :=
  if entry.effectiveOn ≤ validOn then
    match index.get? entry.subject.token with
    | none => index.insert entry.subject.token entry
    | some prior =>
        if prior.effectiveOn ≤ entry.effectiveOn then
          index.insert entry.subject.token entry
        else
          index
  else
    index

/-- One transient fixed-time latest-visible image. -/
def buildLatestIndex
    (history : RoutingHistory LocusId Time)
    (validOn : Time) : LatestIndex Time :=
  history.entries.foldr (updateEntry validOn) {}

private theorem locus_token_ne
    (left right : LocusId)
    (hNe : left ≠ right) :
    left.token ≠ right.token := by
  intro h
  apply hNe
  cases left
  cases right
  simp_all

private theorem updateEntry_same
    (validOn : Time)
    (entry : RoutingEntry LocusId Time)
    (index : LatestIndex Time) :
    (updateEntry validOn entry index).get? entry.subject.token =
      chooseLatest validOn entry (index.get? entry.subject.token) := by
  unfold updateEntry chooseLatest
  by_cases hVisible : entry.effectiveOn ≤ validOn
  · simp only [if_pos hVisible]
    cases hPrior : index.get? entry.subject.token with
    | none =>
        change
          (index.insert entry.subject.token entry).get? entry.subject.token =
            some entry
        rw [Std.HashMap.get?_insert]
        simp
    | some prior =>
        by_cases hLater : prior.effectiveOn ≤ entry.effectiveOn
        · simp only [if_pos hLater]
          change
            (index.insert entry.subject.token entry).get? entry.subject.token =
              some entry
          rw [Std.HashMap.get?_insert]
          simp
        · simp only [if_neg hLater]
          exact hPrior
  · simp only [if_neg hVisible]

private theorem updateEntry_other
    (validOn : Time)
    (entry : RoutingEntry LocusId Time)
    (index : LatestIndex Time)
    (subject : LocusId)
    (hNe : entry.subject ≠ subject) :
    (updateEntry validOn entry index).get? subject.token =
      index.get? subject.token := by
  unfold updateEntry
  by_cases hVisible : entry.effectiveOn ≤ validOn
  · simp only [if_pos hVisible]
    cases hPrior : index.get? entry.subject.token with
    | none =>
        change
          (index.insert entry.subject.token entry).get? subject.token =
            index.get? subject.token
        rw [Std.HashMap.get?_insert]
        have hToken := locus_token_ne entry.subject subject hNe
        have hBeq : (entry.subject.token == subject.token) = false :=
          beq_eq_false_iff_ne.mpr hToken
        rw [hBeq]
        rfl
    | some prior =>
        by_cases hLater : prior.effectiveOn ≤ entry.effectiveOn
        · simp only [if_pos hLater]
          change
            (index.insert entry.subject.token entry).get? subject.token =
              index.get? subject.token
          rw [Std.HashMap.get?_insert]
          have hToken := locus_token_ne entry.subject subject hNe
          have hBeq : (entry.subject.token == subject.token) = false :=
            beq_eq_false_iff_ne.mpr hToken
          rw [hBeq]
          rfl
        · simp only [if_neg hLater]
  · simp only [if_neg hVisible]

private def directStep
    (subject : LocusId)
    (validOn : Time)
    (entry : RoutingEntry LocusId Time)
    (current : Option (RoutingEntry LocusId Time)) :
    Option (RoutingEntry LocusId Time) :=
  if entry.subject = subject && entry.effectiveOn ≤ validOn then
    match current with
    | none => some entry
    | some prior =>
        if prior.effectiveOn ≤ entry.effectiveOn then
          some entry
        else
          some prior
  else
    current

private theorem updateEntry_lookup
    (validOn : Time)
    (entry : RoutingEntry LocusId Time)
    (index : LatestIndex Time)
    (subject : LocusId) :
    (updateEntry validOn entry index).get? subject.token =
      directStep subject validOn entry (index.get? subject.token) := by
  by_cases hSubject : entry.subject = subject
  · subst subject
    rw [updateEntry_same]
    unfold directStep chooseLatest
    by_cases hVisible : entry.effectiveOn ≤ validOn
    · simp [hVisible]
    · simp [hVisible]
  · rw [updateEntry_other validOn entry index subject hSubject]
    unfold directStep
    simp [hSubject]

private theorem buildLatestIndex_lookup_direct
    (entries : List (RoutingEntry LocusId Time))
    (validOn : Time)
    (subject : LocusId)
    (index : LatestIndex Time) :
    (entries.foldr (updateEntry validOn) index).get? subject.token =
      entries.foldr
        (directStep subject validOn)
        (index.get? subject.token) := by
  induction entries with
  | nil =>
      rfl
  | cons entry rest ih =>
      simp only [List.foldr_cons]
      rw [updateEntry_lookup]
      rw [ih]

/--
Research specification copied from the public latest-visible selection rule.

The production helper used inside `findLatestVisible?` is file-private, so this
observation proves the transient image against this exact local specification.
A production promotion can place the final bridge theorem inside
`HistoricalRouting.lean`, where the private helper is visible.
-/
def directFindLatestVisible?
    (history : RoutingHistory LocusId Time)
    (subject : LocusId)
    (validOn : Time) : Option (RoutingEntry LocusId Time) :=
  history.entries.foldr (directStep subject validOn) none

/--
For every history, Locus and observation coordinate, transient-image lookup is
exactly the research latest-visible specification.
-/
theorem buildLatestIndex_get?_eq_direct
    (history : RoutingHistory LocusId Time)
    (subject : LocusId)
    (validOn : Time) :
    (buildLatestIndex history validOn).get? subject.token =
      directFindLatestVisible? history subject validOn := by
  unfold buildLatestIndex directFindLatestVisible?
  calc
    (history.entries.foldr (updateEntry validOn) {}).get? subject.token =
        history.entries.foldr
          (directStep subject validOn)
          (({} : LatestIndex Time).get? subject.token) :=
      buildLatestIndex_lookup_direct
        history.entries validOn subject {}
    _ = history.entries.foldr (directStep subject validOn) none := by
      simp

/-- Three-way status projection from the transient image. -/
def statusFromIndex
    (index : LatestIndex Time)
    (subject : LocusId) : RoutingStatus :=
  match index.get? subject.token with
  | none => .unrouted
  | some entry =>
      match entry.purpose with
      | some purpose => .managed purpose
      | none => .unmanaged

private def statusFromDirect
    (history : RoutingHistory LocusId Time)
    (subject : LocusId)
    (validOn : Time) : RoutingStatus :=
  match directFindLatestVisible? history subject validOn with
  | none => .unrouted
  | some entry =>
      match entry.purpose with
      | some purpose => .managed purpose
      | none => .unmanaged

/--
Pointwise correspondence to the mirrored research specification.
-/
theorem statusFromIndex_build_eq_direct
    (history : RoutingHistory LocusId Time)
    (subject : LocusId)
    (validOn : Time) :
    statusFromIndex (buildLatestIndex history validOn) subject =
      statusFromDirect history subject validOn := by
  unfold statusFromIndex statusFromDirect
  rw [buildLatestIndex_get?_eq_direct]

private def food : PurposeId := ⟨"food"⟩
private def home : PurposeId := ⟨"home"⟩
private def coffee : LocusId := ⟨"coffee"⟩
private def rent : LocusId := ⟨"rent"⟩

private def pressureHistory : RoutingHistory LocusId Nat :=
  {
    entries :=
      [ { subject := coffee, effectiveOn := 3, purpose := some home }
      , { subject := rent, effectiveOn := 2, purpose := none }
      , { subject := coffee, effectiveOn := 1, purpose := some food }
      ]
    coordinateNodup := by native_decide
  }

/--
Closed pressure against the public production specification covers managed,
unmanaged, unrouted, before-first-change, exact-change and later-change cases.
-/
example :
    [0, 1, 2, 3, 4].all (fun time =>
      [coffee, rent, (⟨"ghost"⟩ : LocusId)].all (fun subject =>
        statusFromIndex (buildLatestIndex pressureHistory time) subject ==
          pressureHistory.statusAt subject time)) = true := by
  native_decide

/-!
## Finding

At one fixed observation coordinate, repeated Actual-routing queries factor
through one transient latest-visible image:

    retained RoutingHistory
        -> one scan at validOn
        -> LatestIndex
        -> many Locus status lookups

The focused public `statusAt` remains the simple semantic specification.

The paired benchmark that motivated this proof showed the expected crossover:

- one subject / 64 history entries: focused statusAt 24 µs, image 55 µs;
- 4 subjects / 16 entries: 21 µs vs 21 µs;
- 16 subjects / 64 entries: 272 µs vs 97 µs (~2.80x);
- 64 subjects / 4096 entries: 64.1 ms vs 3.5 ms (~17.87x);
- 256 subjects / 16384 entries: 1.0 s vs 14.3 ms (~70.53x).

The result therefore qualifies a narrow future bulk-read optimization under
measured pressure. Small focused workloads should remain on direct `statusAt`.
No production promotion, persisted index, cardinality threshold, or generic
Actual/Scheduled routing abstraction is justified yet.
-/

end Loam.Observation334
