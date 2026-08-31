import Init.Data.List.Perm
import Loam.Core.EventCorrection

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

private def findResolutionById? :
    List EventResolution → EventResolutionId → Option EventResolution
  | [], _ => none
  | resolution :: rest, id =>
      if resolution.id = id then
        some resolution
      else
        findResolutionById? rest id

private theorem findResolutionById?_perm
    {left right : List EventResolution}
    (hPerm : left.Perm right)
    (hNodup : (left.map EventResolution.id).Nodup)
    (id : EventResolutionId) :
    findResolutionById? left id = findResolutionById? right id := by
  induction hPerm with
  | nil =>
      rfl
  | cons resolution hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases h : resolution.id = id
      · simp [findResolutionById?, h]
      · simp [findResolutionById?, h, ih hNodup.2]
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
        simp [findResolutionById?, hy, hx]
      · by_cases hx : x.id = id
        · simp [findResolutionById?, hy, hx]
        · simp [findResolutionById?, hy, hx]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup := (hLeft.map EventResolution.id).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

/--
Find one remembered resolution by stable relation identity.

The lookup observes `EventResolutionId` only. List position cannot select a
winner among relations because repeated identity is rejected at admission.
-/
def findById?
    (memory : EventResolutionMemory)
    (id : EventResolutionId) : Option EventResolution :=
  findResolutionById? memory.resolutions id

/-- Resolution identity lookup is invariant under representation permutation. -/
theorem findById?_perm
    (left right : EventResolutionMemory)
    (hPerm : left.resolutions.Perm right.resolutions)
    (id : EventResolutionId) :
    findById? left id = findById? right id := by
  simpa [findById?] using
    findResolutionById?_perm hPerm left.idNodup id

@[simp] theorem findById?_empty (id : EventResolutionId) :
    findById? { resolutions := [], idNodup := by simp } id = none := by
  simp [findById?, findResolutionById?]

@[simp] theorem findById?_singleton_self (resolution : EventResolution) :
    findById? { resolutions := [resolution], idNodup := by simp } resolution.id =
      some resolution := by
  simp [findById?, findResolutionById?]

end EventResolutionMemory

end Loam.Core
