import Loam.ActualDate
import Loam.CapacityEvidence
import Loam.Core.BalancedMovement
import Loam.Persistence.TokenSyntax

namespace Loam.Persistence

open Loam
open Loam.Core

set_option autoImplicit false

/-!
# Normalized Capacity persistence

Single-document wire representation for CapacityMovement and CapacityEffective.
The two meanings remain distinct after decoding; only their physical publication
unit is normalized.
-/

/-- Header for the normalized Capacity document. -/
def normalizedCapacityHeader : String := "LOAM-NORMALIZED-CAPACITY\t1"

private def encodeChangeRow? (change : MovementChange CapacityCoordinate) : Option String :=
  match change.coordinate with
  | .unallocated =>
      some ("CHANGE\tUNALLOCATED\t" ++ toString change.quantity.quanta)
  | .purpose purpose =>
      if validToken purpose.token then
        some ("CHANGE\tPURPOSE\t" ++ purpose.token ++ "\t" ++ toString change.quantity.quanta)
      else
        none

private def decodeChangeRow? (row : String) : Option (MovementChange CapacityCoordinate) :=
  match row.splitOn "\t" with
  | ["CHANGE", "UNALLOCATED", quantaText] => do
      let quanta ← quantaText.toInt?
      some { coordinate := .unallocated, quantity := Quantity.ofQuanta quanta }
  | ["CHANGE", "PURPOSE", purposeToken, quantaText] => do
      if !validToken purposeToken then none
      else
        let quanta ← quantaText.toInt?
        some { coordinate := .purpose ⟨purposeToken⟩, quantity := Quantity.ofQuanta quanta }
  | _ => none

private structure ParsedMovement where
  id : CapacityMovementId
  effectiveOn : String
  measure : MeasureId
  changes : List (MovementChange CapacityCoordinate)

private structure MovementParserState where
  current : Option (CapacityMovementId × String × MeasureId × List (MovementChange CapacityCoordinate)) := none
  completed : List ParsedMovement := []

private def stepMovementParser
    (state : MovementParserState)
    (row : String) : Option MovementParserState :=
  match state.current with
  | none =>
      match row.splitOn "\t" with
      | ["MOVEMENT", idToken, effectiveOn, measureToken] =>
          if !validToken idToken || !validToken measureToken ||
              !Loam.ActualDate.validIsoDate effectiveOn then
            none
          else
            some { state with
              current := some (⟨idToken⟩, effectiveOn, ⟨measureToken⟩, []) }
      | _ => none
  | some (id, effectiveOn, measure, changes) =>
      if row == "ENDMOVEMENT" then
        some {
          current := none
          completed := {
            id := id
            effectiveOn := effectiveOn
            measure := measure
            changes := changes
          } :: state.completed
        }
      else do
        let change ← decodeChangeRow? row
        some { state with
          current := some (id, effectiveOn, measure, changes ++ [change])
        }

private def parseMovements (rows : List String) : Option (List ParsedMovement) := do
  let finalState ← rows.foldlM stepMovementParser {}
  match finalState.current with
  | some _ => none
  | none => some finalState.completed.reverse

/-- Decode a complete candidate normalized Capacity image, failing closed. -/
def decodeNormalizedCapacity? (input : String) : Option (CapacityEvidence String) := do
  if !input.endsWith "\n" then none
  let lines := (input.dropEnd 1).toString.splitOn "\n"
  match lines with
  | [] => none
  | header :: rows =>
      if header != normalizedCapacityHeader then none
      else
        let parsed ← parseMovements rows
        let mut movements : List CapacityMovement := []
        let mut effective : List (CapacityEffective String) := []
        for item in parsed do
          let balanced ← BalancedMovement.ofChanges? item.measure item.changes
          movements := movements ++ [{ id := item.id, movement := balanced }]
          effective := effective ++ [{ movement := item.id, effectiveOn := item.effectiveOn }]
        let movementMemory ← CapacityMemory.ofMovements? movements
        let effectiveMemory ← CapacityEffectiveMemory.ofEntries? effective
        CapacityEvidence.ofParts? movementMemory effectiveMemory

/-- Encode one admitted Capacity image as one normalized document. -/
def encodeNormalizedCapacity? (evidence : CapacityEvidence String) : Option String := do
  let mut rows : List String := [normalizedCapacityHeader]
  for movement in evidence.movements.movements do
    let effectiveOn ← evidence.effective.findByMovementId? movement.id
    if !validToken movement.id.token || !validToken movement.measure.token ||
        !Loam.ActualDate.validIsoDate effectiveOn then
      none
    let changeRows ← movement.movement.changes.mapM encodeChangeRow?
    rows := rows ++
      [s!"MOVEMENT\t{movement.id.token}\t{effectiveOn}\t{movement.measure.token}"] ++
      changeRows ++ ["ENDMOVEMENT"]
  some (String.intercalate "\n" rows ++ "\n")

end Loam.Persistence
