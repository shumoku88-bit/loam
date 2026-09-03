import Loam.Application.CapacityInspection
import Loam.CapacityPersistence
import Loam.WriterOwnership
import Std

namespace Loam.CapacityCli

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def usage : String :=
  "LOAM spending capacity\n\n" ++
  "Move JPY capacity between unallocated and purpose coordinates:\n" ++
  "  ./tools/loam capacity <capacity-file>\n\n" ++
  "Show current JPY entitlement projections:\n" ++
  "  ./tools/loam capacity show <capacity-file>"

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def loadCapacityMemoryForEntry?
    (path : System.FilePath) : IO (Option CapacityMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadCapacityMemory? path
  else
    return CapacityMemory.ofMovements? []

private def loadCapacityMemoryForView?
    (path : System.FilePath) : IO (Option CapacityMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadCapacityMemory? path
  else
    return CapacityMemory.ofMovements? []

private def freshCapacityIdFrom
    (memory : CapacityMemory) : Nat → Nat → Option CapacityMovementId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : CapacityMovementId := ⟨"capacity-" ++ toString index⟩
      match CapacityMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshCapacityIdFrom memory (index + 1) fuel

private def freshCapacityId? (memory : CapacityMemory) : Option CapacityMovementId :=
  freshCapacityIdFrom memory 1 (memory.movements.length + 1)

/--
Parse the first practical capacity coordinate vocabulary.

`unallocated` is one reserved boundary token. Every other admitted token is a
Purpose identity; no Purpose registry or Account lookup is introduced.
-/
def parseCoordinate? (token : String) : Option CapacityCoordinate :=
  if token = "unallocated" then
    some .unallocated
  else if Loam.Persistence.validToken token then
    some (.purpose ⟨token⟩)
  else
    none

/-- Build the single-Measure two-endpoint movement used by the practical entrance. -/
def makeJpyMovement?
    (id : CapacityMovementId)
    (fromCoordinate toCoordinate : CapacityCoordinate)
    (quanta : Int) : Option CapacityMovement := do
  if quanta <= 0 then
    none
  else if fromCoordinate = toCoordinate then
    none
  else
    let changes : List (MovementChange CapacityCoordinate) :=
      [ { coordinate := fromCoordinate, quantity := Quantity.ofQuanta (-quanta) },
        { coordinate := toCoordinate, quantity := Quantity.ofQuanta quanta } ]
    let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩ changes
    pure { id := id, movement := movement }

private def recordCapacityUnlocked (capacityPath : String) : IO UInt32 := do
  let capacityFile := System.FilePath.mk capacityPath
  match ← loadCapacityMemoryForEntry? capacityFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported capacity file"
      return 2
  | some memory =>
      let fromText ← promptLine "Capacity from (unallocated or purpose): "
      match parseCoordinate? fromText with
      | none =>
          IO.eprintln "loam: capacity source must be unallocated or a nonempty single-line purpose token"
          return 2
      | some fromCoordinate =>
          let toText ← promptLine "Capacity to (unallocated or purpose): "
          match parseCoordinate? toText with
          | none =>
              IO.eprintln "loam: capacity destination must be unallocated or a nonempty single-line purpose token"
              return 2
          | some toCoordinate =>
              let amountText ← promptLine "Amount? "
              match amountText.toInt? with
              | none =>
                  IO.eprintln "loam: capacity amount must be a positive integer"
                  return 2
              | some quanta =>
                  match freshCapacityId? memory with
                  | none =>
                      IO.eprintln "loam: could not generate a fresh capacity identity"
                      return 2
                  | some movementId =>
                      match makeJpyMovement? movementId fromCoordinate toCoordinate quanta with
                      | none =>
                          IO.eprintln "loam: capacity movement requires a positive amount and distinct endpoints"
                          return 2
                      | some movement =>
                          match CapacityMemory.add? memory movement with
                          | none =>
                              IO.eprintln "loam: generated capacity identity already remembered"
                              return 2
                          | some updated =>
                              if ← Loam.Persistence.saveCapacityMemory? capacityFile updated then
                                IO.println
                                  ("Recorded capacity movement: " ++ fromText ++ " -> " ++ toText ++
                                    " = " ++ toString quanta ++ " jpy.")
                                return 0
                              else
                                IO.eprintln "loam: capacity movement contains an unrepresentable identity token"
                                return 2

/-- Record one JPY capacity movement under capacity-file writer ownership. -/
def recordCapacity (capacityPath : String) : IO UInt32 :=
  Loam.WriterOwnership.withOwnership
    (System.FilePath.mk capacityPath)
    (recordCapacityUnlocked capacityPath)

private def addPurposeIfAbsent (purposes : List PurposeId) (purpose : PurposeId) : List PurposeId :=
  if purpose ∈ purposes then purposes else purposes ++ [purpose]

private def rememberedPurposes (memory : CapacityMemory) : List PurposeId :=
  memory.movements.foldl
    (fun purposes movement =>
      movement.movement.changes.foldl
        (fun current change =>
          match change.coordinate with
          | .unallocated => current
          | .purpose purpose => addPurposeIfAbsent current purpose)
        purposes)
    []

/--
Show JPY entitlement at remembered Purpose coordinates.

The internal `unallocated` coordinate is deliberately not rendered as a
household balance. It is the balancing boundary outside named purposes, not an
independently asserted quantity of spendable money.
-/
def showCapacity (capacityPath : String) : IO UInt32 := do
  let capacityFile := System.FilePath.mk capacityPath
  match ← loadCapacityMemoryForView? capacityFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported capacity file"
      return 2
  | some memory =>
      let yen : MeasureId := ⟨"jpy"⟩
      match rememberedPurposes memory with
      | [] =>
          IO.println "No spending-purpose capacity."
          return 0
      | purposes =>
          IO.println "Spending capacity (derived from retained movements):"
          for purpose in purposes do
            let quantity := entitlementAt memory.movements purpose yen
            IO.println ("  " ++ purpose.token ++ ": " ++ toString quantity.quanta ++ " jpy")
          return 0

/-- Command dispatcher for the first practical Capacity entrance. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [capacityPath] => recordCapacity capacityPath
  | ["show", capacityPath] => showCapacity capacityPath
  | _ => do
      IO.eprintln usage
      return 2

end Loam.CapacityCli

def main (args : List String) : IO UInt32 :=
  Loam.CapacityCli.run args
