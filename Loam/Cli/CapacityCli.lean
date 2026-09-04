import Loam.ActualDate
import Loam.Application.CapacityInspection
import Loam.Application.CapacityWindowInspection
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence
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
  "Show current all-history JPY entitlement projections:\n" ++
  "  ./tools/loam capacity show <capacity-file>\n\n" ++
  "Show JPY entitlement projected from movements effective in [start, end):\n" ++
  "  ./tools/loam capacity show-window <capacity-file> YYYY-MM-DD YYYY-MM-DD\n\n" ++
  "Scripted recording may set LOAM_CAPACITY_EFFECTIVE_DATE=YYYY-MM-DD."

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

private def validateEffectiveDate (text : String) : Except String String :=
  if Loam.ActualDate.validIsoDate text then
    Except.ok text
  else
    Except.error "loam: Capacity effective date must be a real calendar date in YYYY-MM-DD form"

/--
Choose the practical effective day for a new Capacity movement.

The date remains separate evidence from `CapacityMovement`. Interactive use may
accept the host-local day or enter another ISO day. Redirected/scripted callers
may set `LOAM_CAPACITY_EFFECTIVE_DATE`; when absent they use the host-local day.
-/
private def practicalEffectiveDate : IO (Except String String) := do
  let stdin ← IO.getStdin
  if !(← stdin.isTty) then
    match ← IO.getEnv "LOAM_CAPACITY_EFFECTIVE_DATE" with
    | some configured => return validateEffectiveDate configured
    | none =>
        match ← Loam.ActualDate.todayIso? with
        | some today => return Except.ok today
        | none =>
            return Except.error
              "loam: could not determine the local date; set LOAM_CAPACITY_EFFECTIVE_DATE=YYYY-MM-DD"
  else
    match ← Loam.ActualDate.todayIso? with
    | some today =>
        let entered ← promptLine ("Effective date [" ++ today ++ "]: ")
        if entered.isEmpty then
          return Except.ok today
        else
          return validateEffectiveDate entered
    | none =>
        let entered ← promptLine "Effective date (YYYY-MM-DD): "
        return validateEffectiveDate entered

private def effectiveEvidenceComplete
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Bool :=
  memory.movements.all
      (fun movement => (effective.findByMovementId? movement.id).isSome) &&
    effective.entries.all
      (fun entry => (memory.findById? entry.movement).isSome)

private def effectiveMentionsMovement
    (effective : CapacityEffectiveMemory String)
    (id : CapacityMovementId) : Bool :=
  effective.entries.any fun entry => decide (entry.movement = id)

private def freshCapacityIdFrom
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Nat → Nat → Option CapacityMovementId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : CapacityMovementId := ⟨"capacity-" ++ toString index⟩
      match CapacityMemory.findById? memory candidate with
      | none =>
          if effectiveMentionsMovement effective candidate then
            freshCapacityIdFrom memory effective (index + 1) fuel
          else
            some candidate
      | some _ => freshCapacityIdFrom memory effective (index + 1) fuel

private def freshCapacityId?
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Option CapacityMovementId :=
  freshCapacityIdFrom memory effective 1
    (memory.movements.length + effective.entries.length + 1)

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
  let effectiveFile := Loam.Persistence.capacityEffectivePathForMemory capacityFile
  match ← loadCapacityMemoryForEntry? capacityFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported capacity file"
      return 2
  | some memory =>
      match ← Loam.Persistence.loadCapacityEffectiveMemoryOrEmpty? effectiveFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported Capacity effective evidence"
          return 2
      | some effective =>
          if !effectiveEvidenceComplete memory effective then
            IO.eprintln
              "loam: Capacity authority and effective evidence are incomplete; explicit migration or recovery is required"
            return 2
          else
            match ← practicalEffectiveDate with
            | Except.error message =>
                IO.eprintln message
                return 2
            | Except.ok effectiveOn =>
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
                            match freshCapacityId? memory effective with
                            | none =>
                                IO.eprintln "loam: could not generate a fresh capacity identity"
                                return 2
                            | some movementId =>
                                match makeJpyMovement? movementId fromCoordinate toCoordinate quanta with
                                | none =>
                                    IO.eprintln "loam: capacity movement requires a positive amount and distinct endpoints"
                                    return 2
                                | some movement =>
                                    if canMoveCapacityFrom memory.movements fromCoordinate ⟨"jpy"⟩ quanta then
                                      match CapacityMemory.add? memory movement,
                                          CapacityEffectiveMemory.ofEntries?
                                            (effective.entries ++
                                              [{ movement := movementId, effectiveOn := effectiveOn }]) with
                                      | some updated, some updatedEffective =>
                                          if ← Loam.Persistence.saveCapacityEffectiveMemory?
                                              effectiveFile updatedEffective then
                                            if ← Loam.Persistence.saveCapacityMemory?
                                                capacityFile updated then
                                              IO.println
                                                ("Recorded capacity movement: " ++ fromText ++ " -> " ++ toText ++
                                                  " = " ++ toString quanta ++ " jpy. Effective: " ++ effectiveOn ++ ".")
                                              return 0
                                            else
                                              IO.eprintln
                                                "loam: capacity authority was not published; already-published effective evidence is inert and requires explicit recovery"
                                              return 2
                                          else
                                            IO.eprintln "loam: Capacity effective evidence could not be published"
                                            return 2
                                      | _, _ =>
                                          IO.eprintln "loam: could not append Capacity movement and effective evidence"
                                          return 2
                                    else
                                      IO.eprintln "loam: capacity source has insufficient current entitlement"
                                      return 2

/-- Record one dated JPY capacity movement under capacity-file writer ownership. -/
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
Show JPY entitlement across all retained Capacity movements.

This remains the original untimed projection for inspection and compatibility.
Household cycle questions should use `show-window` instead.
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
          IO.println "Spending capacity (derived from all retained movements):"
          for purpose in purposes do
            let quantity := entitlementAt memory.movements purpose yen
            IO.println ("  " ++ purpose.token ++ ": " ++ toString quantity.quanta ++ " jpy")
          return 0

/-- Show JPY Entitlement selected only by Purpose and a half-open ISO date window. -/
def showCapacityWindow
    (capacityPath start end_ : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    IO.eprintln "loam: Capacity window endpoints must be real YYYY-MM-DD calendar dates"
    return 2
  else
    let capacityFile := System.FilePath.mk capacityPath
    let effectiveFile := Loam.Persistence.capacityEffectivePathForMemory capacityFile
    match ← loadCapacityMemoryForView? capacityFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported capacity file"
        return 2
    | some memory =>
        match ← Loam.Persistence.loadCapacityEffectiveMemoryOrEmpty? effectiveFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported Capacity effective evidence"
            return 2
        | some effective =>
            let purposes := rememberedPurposes memory
            let yen : MeasureId := ⟨"jpy"⟩
            match purposes.mapM
                (fun purpose =>
                  entitlementAtEffectiveWindow?
                    memory effective start end_ purpose yen) with
            | none =>
                IO.eprintln
                  "loam: cannot project Capacity window from incomplete effective evidence or an invalid window"
                return 2
            | some quantities =>
                if purposes.isEmpty then
                  IO.println "No spending-purpose capacity."
                else
                  IO.println ("Spending capacity [" ++ start ++ ", " ++ end_ ++ "):")
                  for (purpose, quantity) in purposes.zip quantities do
                    IO.println
                      ("  " ++ purpose.token ++ ": " ++ toString quantity.quanta ++ " jpy")
                return 0

/-- Command dispatcher for practical Capacity recording and inspection. -/
def run (args : List String) : IO UInt32 :=
  match args with
  | [capacityPath] => recordCapacity capacityPath
  | ["show", capacityPath] => showCapacity capacityPath
  | ["show-window", capacityPath, start, end_] => showCapacityWindow capacityPath start end_
  | _ => do
      IO.eprintln usage
      return 2

end Loam.CapacityCli

def main (args : List String) : IO UInt32 :=
  Loam.CapacityCli.run args
