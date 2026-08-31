import Init.Data.List.Perm
import Loam.Core.EventCorrection

namespace Loam.Core

set_option autoImplicit false

/--
A practical memory of explicit Event correction relations.

`corrections` is a deterministic representation only. Its list position carries
no temporal, causal, priority, authority, or arrival-order meaning. One
`EventCorrectionId` may occur at most once in the memory.

Referential closure against `EventMemory` is deliberately not part of this
structure. That remains the separate fail-closed relation-admission boundary.
-/
structure EventCorrectionMemory where
  corrections : List EventCorrection
  idNodup : (corrections.map EventCorrection.id).Nodup

namespace EventCorrectionMemory

/-- Admit a runtime correction collection only when correction identity is unique. -/
def ofCorrections? (corrections : List EventCorrection) : Option EventCorrectionMemory :=
  if h : (corrections.map EventCorrection.id).Nodup then
    some { corrections := corrections, idNodup := h }
  else
    none

/-- Empty correction memory is valid. -/
@[simp] theorem ofCorrections?_nil :
    ofCorrections? [] = some { corrections := [], idNodup := by simp } := by
  simp [ofCorrections?]

/-- One correction always has unique identity within a correction memory. -/
@[simp] theorem ofCorrections?_singleton (correction : EventCorrection) :
    ofCorrections? [correction] =
      some { corrections := [correction], idNodup := by simp } := by
  simp [ofCorrections?]

/-- Repeating one correction identity is rejected rather than ordered. -/
@[simp] theorem ofCorrections?_duplicate (correction : EventCorrection) :
    ofCorrections? [correction, correction] = none := by
  simp [ofCorrections?]

private def findCorrectionById? :
    List EventCorrection → EventCorrectionId → Option EventCorrection
  | [], _ => none
  | correction :: rest, id =>
      if correction.id = id then
        some correction
      else
        findCorrectionById? rest id

private theorem findCorrectionById?_perm
    {left right : List EventCorrection}
    (hPerm : left.Perm right)
    (hNodup : (left.map EventCorrection.id).Nodup)
    (id : EventCorrectionId) :
    findCorrectionById? left id = findCorrectionById? right id := by
  induction hPerm with
  | nil =>
      rfl
  | cons correction hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases h : correction.id = id
      · simp [findCorrectionById?, h]
      · simp [findCorrectionById?, h, ih hNodup.2]
  | swap x y rest =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      have hyx : y.id ≠ x.id := by
        intro hEqual
        apply hNodup.1
        simp [hEqual]
      by_cases hy : y.id = id
      · have hx : x.id ≠ id := by
          intro hx
          exact hyx (hy.trans hx.symm)
        simp [findCorrectionById?, hy, hx]
      · by_cases hx : x.id = id
        · simp [findCorrectionById?, hy, hx]
        · simp [findCorrectionById?, hy, hx]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup := (hLeft.map EventCorrection.id).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

/--
Find one remembered correction by stable relation identity.

The lookup observes `EventCorrectionId` only. List position cannot select a
winner among relations because repeated identity is rejected at admission.
-/
def findById?
    (memory : EventCorrectionMemory)
    (id : EventCorrectionId) : Option EventCorrection :=
  findCorrectionById? memory.corrections id

/-- Correction identity lookup is invariant under representation permutation. -/
theorem findById?_perm
    (left right : EventCorrectionMemory)
    (hPerm : left.corrections.Perm right.corrections)
    (id : EventCorrectionId) :
    findById? left id = findById? right id := by
  simpa [findById?] using
    findCorrectionById?_perm hPerm left.idNodup id

@[simp] theorem findById?_empty (id : EventCorrectionId) :
    findById? { corrections := [], idNodup := by simp } id = none := by
  simp [findById?, findCorrectionById?]

@[simp] theorem findById?_singleton_self (correction : EventCorrection) :
    findById? { corrections := [correction], idNodup := by simp } correction.id =
      some correction := by
  simp [findById?, findCorrectionById?]

end EventCorrectionMemory

end Loam.Core
