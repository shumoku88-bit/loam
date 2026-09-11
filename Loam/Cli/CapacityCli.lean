import Loam.ActualDate
import Loam.Application.CapacityWindowInspection
import Loam.CapacityAuthority
import Loam.CapacityPublisher
import Loam.CapacityReview
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

/--
Parse the first practical capacity coordinate vocabulary through the shared
Capacity publication boundary.
-/
def parseCoordinate? (token : String) : Option CapacityCoordinate :=
  Loam.CapacityPublisher.parseCoordinate? token

/--
Collect one dated JPY Capacity transfer, then delegate all retained write
semantics and writer ownership to `CapacityPublisher.publish`.
-/
def recordCapacity (capacityPath : String) : IO UInt32 := do
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
                  let draft : Loam.CapacityPublisher.Draft := {
                    effectiveOn := effectiveOn
                    source := fromCoordinate
                    destination := toCoordinate
                    quanta := quanta
                  }
                  match ← Loam.CapacityPublisher.publish capacityPath draft with
                  | .error message =>
                      IO.eprintln ("loam: " ++ message)
                      return 2
                  | .ok receipt =>
                      IO.println
                        ("Recorded capacity movement: " ++ fromText ++ " -> " ++ toText ++
                          " = " ++ toString receipt.quanta ++ " jpy. Effective: " ++ receipt.effectiveOn ++ ".")
                      return 0

/--
Show the shared all-retained JPY Capacity review.

This remains the original untimed projection for inspection and compatibility.
Household cycle questions should use `show-window` instead.
-/
def showCapacity (capacityPath : String) : IO UInt32 := do
  match ← Loam.CapacityReview.loadSnapshot (System.FilePath.mk capacityPath) with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok snapshot =>
      if snapshot.rows.isEmpty then
        IO.println "No spending-purpose capacity."
      else
        IO.println "Spending capacity (derived from all retained movements):"
        for row in snapshot.rows do
          IO.println
            ("  " ++ row.purpose.token ++ ": " ++
              toString row.entitlement.quanta ++ " jpy")
      return 0

/-- Show JPY Entitlement selected only by Purpose and a half-open ISO date window. -/
def showCapacityWindow
    (capacityPath start end_ : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    IO.eprintln "loam: Capacity window endpoints must be real YYYY-MM-DD calendar dates"
    return 2
  else
    let capacityFile := System.FilePath.mk capacityPath
    match ← Loam.CapacityAuthority.loadOrEmpty capacityFile with
    | .error message =>
        IO.eprintln ("loam: " ++ message)
        return 2
    | .ok image =>
        let memory := image.movements
        let effective := image.effective
        let purposes := Loam.CapacityReview.rememberedPurposes memory
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
