import Loam.Core.Purpose
import Init.Data.Order
import Init.Data.List.Perm

namespace Loam.Core

open Std (IsLinearOrder le_total le_antisymm le_trans)

set_option autoImplicit false

/-!
# Historical routing

Observation 107 and Observation 111 qualify historical routing as a specific
algebra attaching purpose assertions to a subject over time coordinates.

A route assertion is effective from an explicit coordinate. The three-way
routing view partitions occurrences at their valid coordinates:
- `managed`: latest visible route names a Purpose
- `unmanaged`: latest visible route exists and names no Purpose (explicitly unmanaged)
- `unrouted`: no routing evidence is visible

Duplicate routing evidence for the same `(subject, effectiveOn)` coordinate is
rejected at admission (fail closed). Selection of the latest visible route uses
the linear order of the time coordinate rather than storage or representation
order.
-/

/--
One historical routing assertion for a subject, effective from a coordinate.
`purpose` is `some p` for managed routing, or `none` for explicitly unmanaged routing.
-/
structure RoutingEntry (Subject : Type) (Time : Type) where
  subject : Subject
  effectiveOn : Time
  purpose : Option PurposeId
deriving Repr, DecidableEq

/--
The three-way historical routing status for an occurrence at a valid coordinate:
- `managed`: latest visible route names a Purpose
- `unmanaged`: latest visible route exists and names no Purpose (explicitly unmanaged)
- `unrouted`: no routing evidence is visible
-/
inductive RoutingStatus where
  | managed (purpose : PurposeId)
  | unmanaged
  | unrouted
deriving Repr, DecidableEq

/--
A practical history of routing assertions.
`entries` is a deterministic collection. Duplicate assertions for the same
`(subject, effectiveOn)` coordinate are rejected at admission. List position
carries no temporal, priority, or winner meaning.
-/
structure RoutingHistory (Subject : Type) (Time : Type) where
  entries : List (RoutingEntry Subject Time)
  coordinateNodup : (entries.map (fun e => (e.subject, e.effectiveOn))).Nodup

namespace RoutingHistory

variable {Subject Time : Type}

/--
Admit routing entries only when no `(subject, effectiveOn)` coordinate is repeated.
Representation order is retained but does not determine routing priority.
-/
def ofEntries? [DecidableEq Subject] [DecidableEq Time]
    (entries : List (RoutingEntry Subject Time)) :
    Option (RoutingHistory Subject Time) :=
  if h : (entries.map (fun e => (e.subject, e.effectiveOn))).Nodup then
    some { entries := entries, coordinateNodup := h }
  else
    none

@[simp] theorem ofEntries?_nil [DecidableEq Subject] [DecidableEq Time] :
    ofEntries? ([] : List (RoutingEntry Subject Time)) =
      some { entries := [], coordinateNodup := by simp } := by
  simp [ofEntries?]

@[simp] theorem ofEntries?_singleton [DecidableEq Subject] [DecidableEq Time]
    (entry : RoutingEntry Subject Time) :
    ofEntries? [entry] = some { entries := [entry], coordinateNodup := by simp } := by
  simp [ofEntries?]

variable [DecidableEq Subject] [LE Time] [DecidableRel (· ≤ · : Time → Time → Prop)] [Std.IsLinearOrder Time]

private def combineLatest
    (subject : Subject) (validOn : Time)
    (e : RoutingEntry Subject Time) (acc : Option (RoutingEntry Subject Time)) :
    Option (RoutingEntry Subject Time) :=
  if e.subject = subject && e.effectiveOn ≤ validOn then
    match acc with
    | none => some e
    | some current =>
        if current.effectiveOn ≤ e.effectiveOn then some e else some current
  else
    acc

/--
Find the latest visible routing entry for a subject on or before `validOn`.
Selection is determined by effective coordinate order, not by storage order.
-/
def findLatestVisible?
    (history : RoutingHistory Subject Time)
    (subject : Subject)
    (validOn : Time) : Option (RoutingEntry Subject Time) :=
  history.entries.foldr (combineLatest subject validOn) none

/--
Project the three-way routing status for a subject at a valid coordinate.
-/
def statusAt
    (history : RoutingHistory Subject Time)
    (subject : Subject)
    (validOn : Time) : RoutingStatus :=
  match history.findLatestVisible? subject validOn with
  | none => .unrouted
  | some entry =>
      match entry.purpose with
      | some purpose => .managed purpose
      | none => .unmanaged

omit [Std.IsLinearOrder Time] in
@[simp] theorem statusAt_empty
    (subject : Subject) (validOn : Time) :
    statusAt ({ entries := [], coordinateNodup := by simp } : RoutingHistory Subject Time) subject validOn = .unrouted := by
  simp [statusAt, findLatestVisible?]

private theorem combineLatest_swap
    (subject : Subject) (validOn : Time)
    (x y : RoutingEntry Subject Time)
    (hDiff : (x.subject, x.effectiveOn) ≠ (y.subject, y.effectiveOn))
    (acc : Option (RoutingEntry Subject Time)) :
    combineLatest subject validOn x (combineLatest subject validOn y acc) =
      combineLatest subject validOn y (combineLatest subject validOn x acc) := by
  dsimp [combineLatest]
  by_cases hx : (x.subject = subject && x.effectiveOn ≤ validOn) = true
  <;> by_cases hy : (y.subject = subject && y.effectiveOn ≤ validOn) = true
  · simp only [hx, hy, ite_true]
    have hx_and : x.subject = subject ∧ x.effectiveOn ≤ validOn := by
      simpa using hx
    have hy_and : y.subject = subject ∧ y.effectiveOn ≤ validOn := by
      simpa using hy
    have hDiffTime : x.effectiveOn ≠ y.effectiveOn := by
      intro hEq
      apply hDiff
      ext
      · rw [hx_and.1, hy_and.1]
      · exact hEq
    rcases le_total (a := x.effectiveOn) (b := y.effectiveOn) with hle | hle
    · have hnot : ¬ (y.effectiveOn ≤ x.effectiveOn) := by
        intro hge
        exact hDiffTime (le_antisymm hle hge)
      cases acc with
      | none =>
          simp [hle, hnot]
      | some c =>
          by_cases hcx : c.effectiveOn ≤ x.effectiveOn
          · have hcy : c.effectiveOn ≤ y.effectiveOn := le_trans hcx hle
            simp [hcx, hcy, hle, hnot]
          · by_cases hcy : c.effectiveOn ≤ y.effectiveOn
            · simp [hcx, hcy, hnot]
            · simp [hcx, hcy]
    · have hnot : ¬ (x.effectiveOn ≤ y.effectiveOn) := by
        intro hge
        exact hDiffTime (le_antisymm hge hle)
      cases acc with
      | none =>
          simp [hle, hnot]
      | some c =>
          by_cases hcy : c.effectiveOn ≤ y.effectiveOn
          · have hcx : c.effectiveOn ≤ x.effectiveOn := le_trans hcy hle
            simp [hcx, hcy, hle, hnot]
          · by_cases hcx : c.effectiveOn ≤ x.effectiveOn
            · simp [hcx, hcy, hnot]
            · simp [hcx, hcy]
  · simp [hx, hy]
  · simp [hx, hy]
  · simp [hx, hy]

private theorem findLatestVisibleFold_perm
    {left right : List (RoutingEntry Subject Time)}
    (hPerm : left.Perm right)
    (hNodup : (left.map (fun e => (e.subject, e.effectiveOn))).Nodup)
    (subject : Subject) (validOn : Time) :
    left.foldr (combineLatest subject validOn) none = right.foldr (combineLatest subject validOn) none := by
  induction hPerm with
  | nil => rfl
  | cons e hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      simp only [List.foldr_cons]
      rw [ih hNodup.2]
  | swap x y rest =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      have hyx : (y.subject, y.effectiveOn) ≠ (x.subject, x.effectiveOn) := by
        intro hEqual
        apply hNodup.1
        simp [hEqual]
      simp only [List.foldr_cons]
      rw [combineLatest_swap subject validOn x y hyx.symm]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup := (hLeft.map (fun e => (e.subject, e.effectiveOn))).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

/--
Finding the latest visible route is invariant under permutation of RoutingHistory's entries.
List representation order therefore carries no temporal priority or winner meaning.
-/
theorem findLatestVisible?_perm
    (left right : RoutingHistory Subject Time)
    (hPerm : left.entries.Perm right.entries)
    (subject : Subject) (validOn : Time) :
    findLatestVisible? left subject validOn = findLatestVisible? right subject validOn := by
  simpa [findLatestVisible?] using
    findLatestVisibleFold_perm hPerm left.coordinateNodup subject validOn

/--
Selected routing status is invariant under permutation of RoutingHistory's entries.
List representation order cannot alter the resolved routing view.
-/
theorem statusAt_perm
    (left right : RoutingHistory Subject Time)
    (hPerm : left.entries.Perm right.entries)
    (subject : Subject) (validOn : Time) :
    statusAt left subject validOn = statusAt right subject validOn := by
  simp only [statusAt, findLatestVisible?_perm left right hPerm subject validOn]

end RoutingHistory

end Loam.Core
