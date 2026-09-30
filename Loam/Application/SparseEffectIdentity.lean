import Loam.Core.Event

namespace Loam.SparseEffectIdentity

open Loam.Core

set_option autoImplicit false

/-!
# Sparse Effect identity admission

Collector-local Effect keys are not durable household evidence by themselves.
A key survives admission only when independent evidence explicitly needs that
Effect to remain addressable.

This module owns only that small semantic normalization. It does not decide
which evidence earns identity, allocate Event identity, validate Movement
balance, or publish any authority.
-/

/--
Erase collector-local Effect keys unless the exact key appears in `earned`.

Callers remain responsible for deriving `earned` from their own semantic
contract. Record Movement derives it from Relation sources. Current Correction
and Scheduled Completion admit no new Relation source, so their successful
plain-Actual paths pass an empty list.
-/
def canonicalizeEffects
    (earned : List EffectKey)
    (effects : List Effect) : List Effect :=
  effects.map fun effect =>
    match effect.key with
    | none => effect
    | some key =>
        if key ∈ earned then effect else { effect with key := none }

/-- Canonicalizing with no earned keys leaves no retained Effect identity. -/
@[simp] theorem retainedEffectKeys_canonicalizeEffects_nil
    (effects : List Effect) :
    retainedEffectKeys (canonicalizeEffects [] effects) = [] := by
  simp only [retainedEffectKeys, canonicalizeEffects, List.filterMap_map]
  rw [List.filterMap_eq_nil_iff]
  intro effect _
  cases h : effect.key <;> simp [h]

end Loam.SparseEffectIdentity
