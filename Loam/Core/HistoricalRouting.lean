import Loam.Core.Purpose

namespace Loam.Core

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
Minimal linear order structure needed for deterministic latest-visible route selection.
Provides reflexive, transitive, antisymmetric, and total ordering with decidable comparison.
-/
class LinearOrder (α : Type) extends LE α where
  le_refl (a : α) : a ≤ a
  le_trans {a b c : α} : a ≤ b → b ≤ c → a ≤ c
  le_antisymm {a b : α} : a ≤ b → b ≤ a → a = b
  le_total (a b : α) : a ≤ b ∨ b ≤ a
  decidableLE : DecidableRel (· ≤ · : α → α → Prop)

instance {α : Type} [lo : LinearOrder α] : DecidableRel (· ≤ · : α → α → Prop) :=
  lo.decidableLE

instance : LinearOrder Nat where
  le_refl := Nat.le_refl
  le_trans := @Nat.le_trans
  le_antisymm := @Nat.le_antisymm
  le_total := Nat.le_total
  decidableLE := inferInstance

instance : LinearOrder Int where
  le_refl := Int.le_refl
  le_trans := @Int.le_trans
  le_antisymm := @Int.le_antisymm
  le_total := Int.le_total
  decidableLE := inferInstance

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

/--
Find the latest visible routing entry for a subject on or before `validOn`.
Selection is determined by effective coordinate order, not by storage order.
-/
def findLatestVisible? [DecidableEq Subject] [LinearOrder Time]
    (history : RoutingHistory Subject Time)
    (subject : Subject)
    (validOn : Time) : Option (RoutingEntry Subject Time) :=
  history.entries.foldl
    (fun best e =>
      if e.subject = subject && (e.effectiveOn ≤ validOn) then
        match best with
        | none => some e
        | some current =>
            if current.effectiveOn ≤ e.effectiveOn then some e else some current
      else
        best)
    none

/--
Project the three-way routing status for a subject at a valid coordinate.
-/
def statusAt [DecidableEq Subject] [LinearOrder Time]
    (history : RoutingHistory Subject Time)
    (subject : Subject)
    (validOn : Time) : RoutingStatus :=
  match history.findLatestVisible? subject validOn with
  | none => .unrouted
  | some entry =>
      match entry.purpose with
      | some purpose => .managed purpose
      | none => .unmanaged

@[simp] theorem statusAt_empty [DecidableEq Subject] [LinearOrder Time]
    (subject : Subject) (validOn : Time) :
    statusAt ({ entries := [], coordinateNodup := by simp } : RoutingHistory Subject Time) subject validOn = .unrouted := by
  simp [statusAt, findLatestVisible?]

end RoutingHistory

end Loam.Core
