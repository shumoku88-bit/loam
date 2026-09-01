import Loam.Core.QuantityBasisMemory

namespace Loam.Core

set_option autoImplicit false

/-- Stable identity for one explicit quantity-basis correction relation. -/
structure QuantityBasisCorrectionId where
  token : String
deriving Repr, DecidableEq

/--
One append-only claim that a replacement basis fact corrects one earlier basis
fact. Both endpoints remain ordinary `QuantityBasisId` values; this raw value
carries no chronology, winner rule, accounting role, or rebasing meaning.
-/
structure QuantityBasisCorrection where
  id : QuantityBasisCorrectionId
  target : QuantityBasisId
  replacement : QuantityBasisId
deriving Repr, DecidableEq

/--
Raw memory for basis-correction facts. Only correction identity is unique here.
Endpoint closure, coordinate preservation, acyclicity, and current-frontier
uniqueness are Application admission laws rather than storage-order laws.
-/
structure QuantityBasisCorrectionMemory where
  corrections : List QuantityBasisCorrection
  idNodup : (corrections.map QuantityBasisCorrection.id).Nodup

namespace QuantityBasisCorrectionMemory

/-- Admit raw correction facts only when correction identity is unique. -/
def ofCorrections?
    (corrections : List QuantityBasisCorrection) : Option QuantityBasisCorrectionMemory :=
  if h : (corrections.map QuantityBasisCorrection.id).Nodup then
    some { corrections := corrections, idNodup := h }
  else
    none

private def findCorrectionById? :
    List QuantityBasisCorrection → QuantityBasisCorrectionId → Option QuantityBasisCorrection
  | [], _ => none
  | correction :: rest, id =>
      if correction.id = id then some correction else findCorrectionById? rest id

/-- Find one remembered basis correction by stable correction identity. -/
def findById?
    (memory : QuantityBasisCorrectionMemory)
    (id : QuantityBasisCorrectionId) : Option QuantityBasisCorrection :=
  findCorrectionById? memory.corrections id

/-- Append one complete raw relation without deriving currentness from list order. -/
def add?
    (memory : QuantityBasisCorrectionMemory)
    (correction : QuantityBasisCorrection) : Option QuantityBasisCorrectionMemory :=
  ofCorrections? (memory.corrections ++ [correction])

@[simp] theorem ofCorrections?_nil :
    ofCorrections? [] = some { corrections := [], idNodup := by simp } := by
  simp [ofCorrections?]

@[simp] theorem ofCorrections?_singleton (correction : QuantityBasisCorrection) :
    ofCorrections? [correction] =
      some { corrections := [correction], idNodup := by simp } := by
  simp [ofCorrections?]

@[simp] theorem add?_empty (correction : QuantityBasisCorrection) :
    add? { corrections := [], idNodup := by simp } correction =
      some { corrections := [correction], idNodup := by simp } := by
  simp [add?, ofCorrections?]

end QuantityBasisCorrectionMemory

end Loam.Core
