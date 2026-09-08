import Loam.Core.EventResolution
import Loam.Core.FiniteKeyed

namespace Loam.Core

set_option autoImplicit false

/--
A practical memory of explicit Event resolution relations.

`resolutions` is a deterministic representation only. Its list position carries
no temporal, causal, priority, authority, or arrival-order meaning. One
`EventResolutionId` may occur at most once in the memory.

Referential closure against `EventMemory` and whole-frontier settlement remain
separate admission/projection questions.
-/
structure EventResolutionMemory where
  resolutions : List EventResolution
  idNodup : (resolutions.map EventResolution.id).Nodup

namespace EventResolutionMemory

/-- Admit a runtime resolution collection only when resolution identity is unique. -/
def ofResolutions? (resolutions : List EventResolution) : Option EventResolutionMemory :=
  if h : (resolutions.map EventResolution.id).Nodup then
    some { resolutions := resolutions, idNodup := h }
  else
    none

/-- Empty resolution memory is valid. -/
@[simp] theorem ofResolutions?_nil :
    ofResolutions? [] = some { resolutions := [], idNodup := by simp } := by
  simp [ofResolutions?]

/-- One resolution always has unique identity within a resolution memory. -/
@[simp] theorem ofResolutions?_singleton (resolution : EventResolution) :
    ofResolutions? [resolution] =
      some { resolutions := [resolution], idNodup := by simp } := by
  simp [ofResolutions?]

/-- Repeating one resolution identity is rejected rather than ordered. -/
@[simp] theorem ofResolutions?_duplicate (resolution : EventResolution) :
    ofResolutions? [resolution, resolution] = none := by
  simp [ofResolutions?]

/--
Find one remembered resolution by stable relation identity.

The lookup observes `EventResolutionId` only. List position cannot select a
winner among relations because repeated identity is rejected at admission.
-/
def findById?
    (memory : EventResolutionMemory)
    (id : EventResolutionId) : Option EventResolution :=
  FiniteKeyed.findBy? EventResolution.id memory.resolutions id

/-- Resolution identity lookup is invariant under representation permutation. -/
theorem findById?_perm
    (left right : EventResolutionMemory)
    (hPerm : left.resolutions.Perm right.resolutions)
    (id : EventResolutionId) :
    findById? left id = findById? right id := by
  exact FiniteKeyed.findBy?_perm EventResolution.id hPerm left.idNodup id

@[simp] theorem findById?_empty (id : EventResolutionId) :
    findById? { resolutions := [], idNodup := by simp } id = none := by
  simp [findById?, FiniteKeyed.findBy?]

@[simp] theorem findById?_singleton_self (resolution : EventResolution) :
    findById? { resolutions := [resolution], idNodup := by simp } resolution.id =
      some resolution := by
  simp [findById?, FiniteKeyed.findBy?]

/--
Add one complete raw resolution relation, rejecting repeated resolution identity.

This operation deliberately does not inspect `EventMemory`. Referential closure
and whole-frontier settlement remain derived admission/projection concerns, so
raw fact retention cannot depend on physical Event/relation arrival order.
-/
def add?
    (memory : EventResolutionMemory)
    (resolution : EventResolution) : Option EventResolutionMemory :=
  ofResolutions? (memory.resolutions ++ [resolution])

@[simp] theorem add?_empty (resolution : EventResolution) :
    add? { resolutions := [], idNodup := by simp } resolution =
      some { resolutions := [resolution], idNodup := by simp } := by
  simp [add?, ofResolutions?]

@[simp] theorem add?_singleton_duplicate (resolution : EventResolution) :
    add? { resolutions := [resolution], idNodup := by simp } resolution = none := by
  simp [add?, ofResolutions?]

theorem add?_singleton_distinct
    (existing added : EventResolution)
    (h : existing.id ≠ added.id) :
    add? { resolutions := [existing], idNodup := by simp } added =
      some { resolutions := [existing, added], idNodup := by simp [h] } := by
  simp [add?, ofResolutions?, h]

end EventResolutionMemory

end Loam.Core
