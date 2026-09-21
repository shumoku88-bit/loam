import Loam.Core.EventCorrection
import Loam.Core.HashNodup

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

private theorem correctionPairToken_injective :
    Function.Injective (fun (p : EventId × EventId) => (p.1.token, p.2.token)) := by
  intro ⟨⟨t1⟩, ⟨r1⟩⟩ ⟨⟨t2⟩, ⟨r2⟩⟩ h
  simp only [Prod.mk.injEq] at h
  cases h.1
  cases h.2
  rfl

/-- Admit raw correction facts while refusing duplicate semantic edges. -/
def ofCorrections? (corrections : List EventCorrection) : Option EventCorrectionMemory := do
  let h ← hashNodupBy?
    (fun (p : EventId × EventId) => (p.1.token, p.2.token))
    correctionPairToken_injective
    (corrections.map fun correction => (correction.target, correction.replacement))
  some { corrections := corrections, idNodup := h.proof }

/-- Whether any retained raw correction explicitly targets this Event identity. -/
def targetsEvent (memory : EventCorrectionMemory) (event : EventId) : Bool :=
  memory.corrections.any fun correction => decide (correction.target = event)

@[simp] theorem targetsEvent_empty (event : EventId) :
    targetsEvent { corrections := [], idNodup := by simp } event = false := by
  simp [targetsEvent]

@[simp] theorem targetsEvent_singleton
    (correction : EventCorrection) (event : EventId) :
    targetsEvent { corrections := [correction], idNodup := by simp } event =
      decide (correction.target = event) := by
  simp [targetsEvent]

/-- Empty correction memory is valid. -/
@[simp] theorem ofCorrections?_nil :
    ofCorrections? [] = some { corrections := [], idNodup := by simp } := by
  change
    (do
      let h ← hashNodupBy?
        (fun (p : EventId × EventId) => (p.1.token, p.2.token))
        correctionPairToken_injective []
      some ({ corrections := [], idNodup := h.proof } : EventCorrectionMemory)) =
    some ({ corrections := [], idNodup := by simp } : EventCorrectionMemory)
  rw [hashNodupBy?_nil]
  rfl

/-- One correction edge is always unique within a correction memory. -/
@[simp] theorem ofCorrections?_singleton (correction : EventCorrection) :
    ofCorrections? [correction] =
      some { corrections := [correction], idNodup := by simp } := by
  change
    (do
      let h ← hashNodupBy?
        (fun (p : EventId × EventId) => (p.1.token, p.2.token))
        correctionPairToken_injective [(correction.target, correction.replacement)]
      some ({ corrections := [correction], idNodup := h.proof } : EventCorrectionMemory)) =
    some ({ corrections := [correction], idNodup := by simp } : EventCorrectionMemory)
  rw [hashNodupBy?_singleton]
  rfl

/-- Repeating one exact correction edge is rejected rather than ordered. -/
@[simp] theorem ofCorrections?_duplicate (correction : EventCorrection) :
    ofCorrections? [correction, correction] = none := by
  change
    (do
      let h ← hashNodupBy?
        (fun (p : EventId × EventId) => (p.1.token, p.2.token))
        correctionPairToken_injective
        [(correction.target, correction.replacement), (correction.target, correction.replacement)]
      some ({ corrections := [correction, correction], idNodup := h.proof } : EventCorrectionMemory)) =
    none
  rw [hashNodupBy?_repeat]
  rfl

/-- A pair of distinct correction edges admits uniquely. -/
theorem ofCorrections?_pair_distinct
    (c1 c2 : EventCorrection)
    (h : (c1.target, c1.replacement) ≠ (c2.target, c2.replacement)) :
    ofCorrections? [c1, c2] =
      some { corrections := [c1, c2], idNodup := by simp [h] } := by
  have hKey :
      (fun (p : EventId × EventId) => (p.1.token, p.2.token))
          (c1.target, c1.replacement) ≠
        (fun (p : EventId × EventId) => (p.1.token, p.2.token))
          (c2.target, c2.replacement) := by
    intro hEq
    exact h (correctionPairToken_injective hEq)
  change
    (do
      let hw ← hashNodupBy?
        (fun (p : EventId × EventId) => (p.1.token, p.2.token))
        correctionPairToken_injective
        [(c1.target, c1.replacement), (c2.target, c2.replacement)]
      some ({ corrections := [c1, c2], idNodup := hw.proof } : EventCorrectionMemory)) =
    some ({ corrections := [c1, c2], idNodup := by simp [h] } : EventCorrectionMemory)
  rw [hashNodupBy?_pair_of_key_ne _ _ _ _ hKey]
  rfl

/--
A successful runtime admission preserves exactly the supplied correction list.
-/
theorem ofCorrections?_some_corrections
    (corrections : List EventCorrection)
    (memory : EventCorrectionMemory)
    (h : ofCorrections? corrections = some memory) :
    memory.corrections = corrections := by
  unfold ofCorrections? at h
  cases hAdmission :
      hashNodupBy?
        (fun (p : EventId × EventId) => (p.1.token, p.2.token))
        correctionPairToken_injective
        (corrections.map fun correction => (correction.target, correction.replacement)) with
  | none => simp [hAdmission] at h
  | some witness =>
      simp [hAdmission] at h
      cases h
      rfl

/--
Semantic correspondence: hash-accelerated `ofCorrections?` accepts exactly when
the raw target-replacement pairs have no duplicates according to `List.Nodup`.
-/
theorem ofCorrections?_isSome_iff_nodup
    (corrections : List EventCorrection) :
    (ofCorrections? corrections).isSome =
      decide ((corrections.map fun c => (c.target, c.replacement)).Nodup) := by
  unfold ofCorrections?
  have hKey :
      (hashNodupBy?
        (fun (p : EventId × EventId) => (p.1.token, p.2.token))
        correctionPairToken_injective
        (corrections.map fun c => (c.target, c.replacement))).isSome =
      decide ((corrections.map fun c => (c.target, c.replacement)).Nodup) :=
    hashNodupBy?_isSome_iff_nodup _ _ _
  cases hHN : hashNodupBy?
    (fun (p : EventId × EventId) => (p.1.token, p.2.token))
    correctionPairToken_injective
    (corrections.map fun c => (c.target, c.replacement)) with
  | none =>
      rw [hHN] at hKey
      simp [bind, Option.bind]
      exact of_decide_eq_false hKey.symm
  | some witness =>
      simp [bind, Option.bind]
      exact witness.proof

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
  change ofCorrections? [correction] = _
  rw [ofCorrections?_singleton]

@[simp] theorem add?_singleton_duplicate (correction : EventCorrection) :
    add? { corrections := [correction], idNodup := by simp } correction = none := by
  change ofCorrections? [correction, correction] = _
  rw [ofCorrections?_duplicate]

theorem add?_singleton_distinct
    (existing added : EventCorrection)
    (h : (existing.target, existing.replacement) ≠
      (added.target, added.replacement)) :
    add? { corrections := [existing], idNodup := by simp } added =
      some { corrections := [existing, added], idNodup := by simp [h] } := by
  change ofCorrections? [existing, added] = _
  rw [ofCorrections?_pair_distinct _ _ h]

end EventCorrectionMemory

end Loam.Core
