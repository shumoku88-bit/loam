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

private theorem eventIdToken_injective :
    Function.Injective (fun id : EventId => id.token) := by
  intro left right h
  cases left
  cases right
  cases h
  rfl

private theorem correctionPairToken_injective :
    Function.Injective (fun pair : EventId × EventId =>
      (pair.1.token, pair.2.token)) := by
  intro left right h
  apply Prod.ext
  · exact eventIdToken_injective (congrArg Prod.fst h)
  · exact eventIdToken_injective (congrArg Prod.snd h)

/--
Admit raw correction facts while refusing duplicate semantic edges.

The HashSet used during admission is transient. The retained Core authority is
still the same `List.Nodup` proof over exact target/replacement pairs.
-/
def ofCorrections? (corrections : List EventCorrection) : Option EventCorrectionMemory := do
  let pairs := corrections.map fun correction =>
    (correction.target, correction.replacement)
  let h ← hashNodupBy?
    (fun pair : EventId × EventId => (pair.1.token, pair.2.token))
    correctionPairToken_injective
    pairs
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
        (fun pair : EventId × EventId => (pair.1.token, pair.2.token))
        correctionPairToken_injective
        []
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
        (fun pair : EventId × EventId => (pair.1.token, pair.2.token))
        correctionPairToken_injective
        [(correction.target, correction.replacement)]
      some ({ corrections := [correction], idNodup := h.proof } :
        EventCorrectionMemory)) =
    some ({ corrections := [correction], idNodup := by simp } :
      EventCorrectionMemory)
  rw [hashNodupBy?_singleton]
  rfl

/-- Repeating one exact correction edge is rejected rather than ordered. -/
@[simp] theorem ofCorrections?_duplicate (correction : EventCorrection) :
    ofCorrections? [correction, correction] = none := by
  change
    (do
      let h ← hashNodupBy?
        (fun pair : EventId × EventId => (pair.1.token, pair.2.token))
        correctionPairToken_injective
        [(correction.target, correction.replacement),
          (correction.target, correction.replacement)]
      some ({ corrections := [correction, correction], idNodup := h.proof } :
        EventCorrectionMemory)) = none
  simp [hashNodupBy?_repeat]

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
  simpa [add?] using ofCorrections?_singleton correction

@[simp] theorem add?_singleton_duplicate (correction : EventCorrection) :
    add? { corrections := [correction], idNodup := by simp } correction = none := by
  simpa [add?] using ofCorrections?_duplicate correction

theorem add?_singleton_distinct
    (existing added : EventCorrection)
    (h : (existing.target, existing.replacement) ≠
      (added.target, added.replacement)) :
    add? { corrections := [existing], idNodup := by simp } added =
      some { corrections := [existing, added], idNodup := by simp [h] } := by
  have hKey :
      (existing.target.token, existing.replacement.token) ≠
        (added.target.token, added.replacement.token) := by
    intro hEq
    exact h (correctionPairToken_injective hEq)
  change ofCorrections? [existing, added] =
    some ({ corrections := [existing, added], idNodup := by simp [h] } :
      EventCorrectionMemory)
  unfold ofCorrections?
  change
    (do
      let witness ← hashNodupBy?
        (fun pair : EventId × EventId => (pair.1.token, pair.2.token))
        correctionPairToken_injective
        [(existing.target, existing.replacement),
          (added.target, added.replacement)]
      some ({ corrections := [existing, added], idNodup := witness.proof } :
        EventCorrectionMemory)) =
    some ({ corrections := [existing, added], idNodup := by simp [h] } :
      EventCorrectionMemory)
  rw [hashNodupBy?_pair_of_key_ne
    (fun pair : EventId × EventId => (pair.1.token, pair.2.token))
    correctionPairToken_injective
    (existing.target, existing.replacement)
    (added.target, added.replacement)
    hKey]
  rfl

end EventCorrectionMemory

end Loam.Core
