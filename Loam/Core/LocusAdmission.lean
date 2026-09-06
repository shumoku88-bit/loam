import Loam.Core.Effect

namespace Loam.Core

set_option autoImplicit false

/-!
# Locus new-write admission vocabulary

Observation 212 showed that historically observed `LocusId` values do not determine
which Loci may be used by a new quantity-bearing canonical write. Historical
readability and current new-write permission are independent information.

This module retains only the independently earned policy: one explicit set of
`LocusId` identities approved for new quantity Effects. It deliberately adds no
Account, category, ownership, debit/credit, routing, display hierarchy, alias, or
retirement semantics.
-/

/--
Explicit current vocabulary for Loci that may appear in newly published quantity
Effects.

The list is a finite representation of a set. Its order has no priority, display,
temporal, or accounting meaning.
-/
structure LocusAdmissionVocabulary where
  approved : List LocusId
  nodup : approved.Nodup

namespace LocusAdmissionVocabulary

/-- Admit one explicit finite vocabulary only when identities are unique. -/
def ofLoci? (approved : List LocusId) : Option LocusAdmissionVocabulary :=
  if h : approved.Nodup then
    some { approved := approved, nodup := h }
  else
    none

/-- The empty vocabulary approves no new quantity-bearing write. -/
def empty : LocusAdmissionVocabulary :=
  { approved := [], nodup := by simp }

/-- Whether one existing Locus identity is approved for a new quantity Effect. -/
def allows (vocabulary : LocusAdmissionVocabulary) (locus : LocusId) : Bool :=
  decide (locus ∈ vocabulary.approved)

/-- Whether one proposed Effect uses an approved Locus. -/
def admitsEffect (vocabulary : LocusAdmissionVocabulary) (effect : Effect) : Bool :=
  vocabulary.allows effect.locus

/--
Whether every Effect in one proposed quantity-bearing write uses an approved
Locus. This is intentionally independent of Event identity, Effect-key
uniqueness, balance, time, routing, and persistence admission.
-/
def admitsEffects
    (vocabulary : LocusAdmissionVocabulary)
    (effects : List Effect) : Bool :=
  effects.all vocabulary.admitsEffect

end LocusAdmissionVocabulary

end Loam.Core
