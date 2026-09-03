import Loam.Core.CapacityMemory
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Capacity movement persistence

The first practical Capacity stream keeps stable movement identity, one explicit
Measure, and every signed CapacityCoordinate change. It does not store grant,
reallocation, or release operation kinds; those remain interpretations of the
movement endpoints.
-/

/-- Version marker for the first raw capacity-memory format. -/
def capacityMemoryHeader : String := "LOAM-CAPACITY-MEMORY\t1"

private def encodeCapacityChangeRow? (change : MovementChange CapacityCoordinate) : Option String :=
  match change.coordinate with
  | .unallocated =>
      some ("CHANGE\tUNALLOCATED\t" ++ toString change.quantity.quanta)
  | .purpose purpose =>
      if validToken purpose.token then
        some ("CHANGE\tPURPOSE\t" ++ purpose.token ++ "\t" ++ toString change.quantity.quanta)
      else
        none

private def decodeCapacityChangeRow? (row : String) : Option (MovementChange CapacityCoordinate) :=
  match row.splitOn "\t" with
  | ["CHANGE", "UNALLOCATED", quantaText] =>
      match quantaText.toInt? with
      | some quanta => some { coordinate := .unallocated, quantity := Quantity.ofQuanta quanta }
      | none => none
  | ["CHANGE", "PURPOSE", purposeToken, quantaText] =>
      if validToken purposeToken then
        match quantaText.toInt? with
        | some quanta =>
            some {
              coordinate := .purpose ⟨purposeToken⟩
              quantity := Quantity.ofQuanta quanta
            }
        | none => none
      else
        none
  | _ => none

private def encodeCapacityMovementLines? (movement : CapacityMovement) : Option (List String) :=
  let idToken := movement.id.token
  let measureToken := movement.measure.token
  if validToken idToken && validToken measureToken then
    match movement.movement.changes.mapM encodeCapacityChangeRow? with
    | some rows => some (("MOVEMENT\t" ++ idToken ++ "\t" ++ measureToken) :: rows)
    | none => none
  else
    none

private def withoutTrailingEmpty (rows : List String) : List String :=
  match rows.reverse with
  | "" :: rest => rest.reverse
  | _ => rows

private def decodeCapacityMovementChunk? (chunk : String) : Option CapacityMovement :=
  match chunk.splitOn "\n" with
  | header :: rawRows =>
      match header.splitOn "\t" with
      | [idToken, measureToken] =>
          if validToken idToken && validToken measureToken then
            match (withoutTrailingEmpty rawRows).mapM decodeCapacityChangeRow? with
            | some changes =>
                match BalancedMovement.ofChanges? ⟨measureToken⟩ changes with
                | some movement => some { id := ⟨idToken⟩, movement := movement }
                | none => none
            | none => none
          else
            none
      | _ => none
  | _ => none

/--
Encode raw Capacity memory without assigning meaning to representation order.
Every represented movement has already retained its exact zero-total proof.
-/
def encodeCapacityMemory? (memory : CapacityMemory) : Option String :=
  match memory.movements.mapM encodeCapacityMovementLines? with
  | some blocks =>
      some (String.intercalate "\n" (capacityMemoryHeader :: blocks.flatten) ++ "\n")
  | none => none

/--
Decode one raw version-1 Capacity stream, rechecking movement balance and stable
movement identity fail-closed.
-/
def decodeCapacityMemory? (input : String) : Option CapacityMemory :=
  if input = capacityMemoryHeader ++ "\n" then
    CapacityMemory.ofMovements? []
  else
    match (input.splitOn "\n").reverse with
    | "" :: _ =>
        match input.splitOn "\nMOVEMENT\t" with
        | header :: chunks =>
            if header = capacityMemoryHeader then
              match chunks with
              | [] => none
              | _ =>
                  match chunks.mapM decodeCapacityMovementChunk? with
                  | some movements => CapacityMemory.ofMovements? movements
                  | none => none
            else
              none
        | _ => none
    | _ => none

private def capacityMemoryStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish one raw Capacity stream by complete sibling staging plus rename. -/
def saveCapacityMemory?
    (path : System.FilePath)
    (memory : CapacityMemory) : IO Bool := do
  match encodeCapacityMemory? memory with
  | some text =>
      let stagePath := capacityMemoryStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      return true
  | none =>
      return false

/-- Read and fail-closed decode one raw Capacity stream. -/
def loadCapacityMemory?
    (path : System.FilePath) : IO (Option CapacityMemory) := do
  let input ← IO.FS.readFile path
  return decodeCapacityMemory? input

end Loam.Persistence
