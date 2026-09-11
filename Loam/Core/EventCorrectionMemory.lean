import Loam.Core.EventCorrection

namespace Loam.Core

set_option autoImplicit false

/--
A practical memory of explicit Event correction relations.

`corrections` is a deterministic representation only. Its list position carries
no temporal, causal, priority, authority, or arrival-order meaning. One exact
`target -> replacement` edge may occur at most once in the raw memory.

Referential closure and one-to-one frontier admission against `EventMemory` are
deliberately not part of this structure. Those remain separate fail-closed
Application concerns.
-/
structure EventCorrectionMemory where
  corrections : List EventCorrection
  idNodup : (corrections.map fun correction =>
    (correction.target, correction.replacement)).Nodup

namespace EventCorrectionMemory

/-- Admit raw correction facts while refusing duplicate semantic edges. -/
def ofCorrections? (corrections : List EventCorrection) : Option EventCorrectionMemory :=
  if h : (corrections.map fun correction =>
      (correction.target, correction.replacement)).Nodup then
    some { corrections := corrections, idNodup := h }
  else
    none

/-- Empty correction memory is valid. -/
@[simp] theorem ofCorrections?_nil :
    ofCorrections? [] = some { corrections := [], idNodup := by simp } := by
  simp [ofCorrections?]

/-- One correction edge is always unique within a correction memory. -/
@[simp] theorem ofCorrections?_singleton (correction : EventCorrection) :
    ofCorrections? [correction] =
      some { corrections := [correction], idNodup := by simp } := by
  simp [ofCorrections?]

/-- Repeating one exact correction edge is rejected rather than ordered. -/
@[simp] theorem ofCorrections?_duplicate (correction : EventCorrection) :
    ofCorrections? [correction, correction] = none := by
  simp [ofCorrections?]

/--
Add one complete raw correction relation, rejecting an exact duplicate edge.

This operation deliberately does not inspect `EventMemory`. Referential closure
and frontier shape remain derived Application concerns, so raw fact retention
cannot depend on physical Event/relation arrival order.
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
    (h : (existing.target, existing.replacement) ≠
      (added.target, added.replacement)) :
    add? { corrections := [existing], idNodup := by simp } added =
      some { corrections := [existing, added], idNodup := by simp [h] } := by
  simp [add?, ofCorrections?, h]

end EventCorrectionMemory

end Loam.Core
