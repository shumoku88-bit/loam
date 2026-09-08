import Loam.Core.EventCorrection
import Loam.Core.FiniteKeyed

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

/--
Find one remembered correction by stable relation identity.

The lookup observes `EventCorrectionId` only. List position cannot select a
winner among relations because repeated identity is rejected at admission.
-/
def findById?
    (memory : EventCorrectionMemory)
    (id : EventCorrectionId) : Option EventCorrection :=
  FiniteKeyed.findBy? EventCorrection.id memory.corrections id

/-- Correction identity lookup is invariant under representation permutation. -/
theorem findById?_perm
    (left right : EventCorrectionMemory)
    (hPerm : left.corrections.Perm right.corrections)
    (id : EventCorrectionId) :
    findById? left id = findById? right id := by
  exact FiniteKeyed.findBy?_perm EventCorrection.id hPerm left.idNodup id

@[simp] theorem findById?_empty (id : EventCorrectionId) :
    findById? { corrections := [], idNodup := by simp } id = none := by
  simp [findById?, FiniteKeyed.findBy?]

@[simp] theorem findById?_singleton_self (correction : EventCorrection) :
    findById? { corrections := [correction], idNodup := by simp } correction.id =
      some correction := by
  simp [findById?, FiniteKeyed.findBy?]

/--
Add one complete raw correction relation, rejecting repeated correction identity.

This operation deliberately does not inspect `EventMemory`. Referential closure
remains a derived `RelationAdmission` concern, so raw fact retention cannot
depend on physical Event/relation arrival order.
-/
def add?
    (memory : EventCorrectionMemory)
    (correction : EventCorrection) : Option EventCorrectionMemory :=
  ofCorrections? (memory.corrections ++ [correction])

@[simp] theorem add?_empty (correction : EventCorrection) :
    add? { corrections := [], idNodup := by simp } correction =
      some { corrections := [correction], idNodup := by simp } := by
  simp [add?, ofCorrections?]

@[simp] theorem add?_singleton_duplicate (correction : EventCorrection) :
    add? { corrections := [correction], idNodup := by simp } correction = none := by
  simp [add?, ofCorrections?]

theorem add?_singleton_distinct
    (existing added : EventCorrection)
    (h : existing.id ≠ added.id) :
    add? { corrections := [existing], idNodup := by simp } added =
      some { corrections := [existing, added], idNodup := by simp [h] } := by
  simp [add?, ofCorrections?, h]

end EventCorrectionMemory

end Loam.Core
