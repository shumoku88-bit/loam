import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CapacityWindowInspection
import Loam.Persistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.CapacityEffectivePersistence
import Loam.Persistence.CapacityPersistence

namespace Loam.BudgetWindowCli

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def usage : String :=
  "Usage: loamBudgetWindow DATA_ROOT START END PURPOSE|--all\n" ++
  "\n" ++
  "Projects JPY Entitlement, routed Actual Consumption, and Remaining over the\n" ++
  "half-open coordinate window [START, END). --all reuses the same projection\n" ++
  "for every Purpose already represented by Capacity evidence. No Period or\n" ++
  "Remaining state is stored."

private def loadCorrectionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return EventCorrectionMemory.ofCorrections? []

private def requireFile (path : System.FilePath) (label : String) : IO Bool := do
  if ← path.pathExists then
    return true
  else
    IO.eprintln ("loam: required " ++ label ++ " not found: " ++ path.toString)
    return false

private def addPurposeIfAbsent
    (purposes : List PurposeId)
    (purpose : PurposeId) : List PurposeId :=
  if purpose ∈ purposes then purposes else purposes ++ [purpose]

/--
Recover the Purpose coordinates already represented by retained Capacity evidence.
This is only a query-local enumeration; it does not create a Purpose registry.
-/
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

private structure PurposeProjection where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity

private def projectPurpose?
    (capacity : CapacityMemory)
    (effective : CapacityEffectiveMemory String)
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory String)
    (routing : RoutingHistory LocusId String)
    (start end_ : String)
    (purpose : PurposeId)
    (measure : MeasureId) : Option PurposeProjection := do
  let entitlement ←
    entitlementAtEffectiveWindow?
      capacity effective start end_ purpose measure
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      events corrections validities routing start end_ purpose measure
  return {
    purpose := purpose
    entitlement := entitlement
    consumption := consumption
  }

private def printOne
    (start end_ : String)
    (projection : PurposeProjection) : IO Unit := do
  let remaining := projection.entitlement - projection.consumption
  IO.println ("Budget window [" ++ start ++ ", " ++ end_ ++ ")")
  IO.println ("Purpose: " ++ projection.purpose.token)
  IO.println
    ("Entitlement: " ++ toString projection.entitlement.quanta ++ " jpy")
  IO.println
    ("Consumption: " ++ toString projection.consumption.quanta ++ " jpy")
  IO.println
    ("Remaining: " ++ toString remaining.quanta ++ " jpy")

private def printAll
    (start end_ : String)
    (projections : List PurposeProjection) : IO Unit := do
  IO.println ("Budget window [" ++ start ++ ", " ++ end_ ++ ")")
  if projections.isEmpty then
    IO.println "No spending-purpose capacity."
  else
    IO.println "Purposes:"
    for projection in projections do
      let remaining := projection.entitlement - projection.consumption
      IO.println
        ("  " ++ projection.purpose.token ++
          ": entitlement " ++ toString projection.entitlement.quanta ++
          " jpy, consumption " ++ toString projection.consumption.quanta ++
          " jpy, remaining " ++ toString remaining.quanta ++ " jpy")

/--
Read canonical household evidence and project one Purpose, or every Purpose
represented by Capacity evidence, over `[start, end)`.

Required authority/evidence streams under `root`:

- `capacity.loam`
- `capacity.loam.effective`
- `memory.loam`
- `memory.loam.actual-validity`
- `actual-routing.loam`

`corrections.loam` is optional and means an empty Event-correction memory when
absent, matching the existing practical read-side convention.

ActualValidity V2 correction history is resolved to one current date per Event
before the query. Entitlement and Consumption are projected once from the loaded
snapshot, then Remaining is derived exactly from those resolved values. No
Remaining state is retained as canonical evidence.
-/
def report
    (rootPath start end_ purposeToken : String) : IO UInt32 := do
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    IO.eprintln "loam: budget window endpoints must be real YYYY-MM-DD calendar dates"
    return 2
  else if purposeToken != "--all" && !Loam.Persistence.validToken purposeToken then
    IO.eprintln "loam: budget Purpose must be a nonempty single-line token or --all"
    return 2
  else
    let root := System.FilePath.mk rootPath
    let capacityPath := root / "capacity.loam"
    let effectivePath := Loam.Persistence.capacityEffectivePathForMemory capacityPath
    let memoryPath := root / "memory.loam"
    let validityPath := Loam.Persistence.actualValidityPathForEventMemory memoryPath
    let correctionPath := root / "corrections.loam"
    let routingPath := root / "actual-routing.loam"

    if !(← requireFile capacityPath "Capacity authority") ||
        !(← requireFile effectivePath "Capacity effective evidence") ||
        !(← requireFile memoryPath "Event authority") ||
        !(← requireFile validityPath "Actual validity history") ||
        !(← requireFile routingPath "Actual routing evidence") then
      return 2
    else
      match ← Loam.Persistence.loadCapacityMemory? capacityPath with
      | none =>
          IO.eprintln "loam: malformed or unsupported Capacity authority"
          return 2
      | some capacity =>
          match ← Loam.Persistence.loadCapacityEffectiveMemory? effectivePath with
          | none =>
              IO.eprintln "loam: malformed or unsupported Capacity effective evidence"
              return 2
          | some effective =>
              match ← Loam.Persistence.loadEventMemory? memoryPath with
              | none =>
                  IO.eprintln "loam: malformed or unsupported Event authority"
                  return 2
              | some events =>
                  match ← loadCorrectionMemoryOrEmpty? correctionPath with
                  | none =>
                      IO.eprintln "loam: malformed or unsupported Event correction authority"
                      return 2
                  | some corrections =>
                      match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityPath with
                      | none =>
                          IO.eprintln "loam: malformed or unsupported Actual validity history"
                          return 2
                      | some validityHistory =>
                          match admittedActualValidityMemory? validityHistory with
                          | none =>
                              IO.eprintln
                                "loam: Actual validity corrections do not justify one current date per Event"
                              return 2
                          | some validities =>
                              match ← Loam.Persistence.loadActualRoutingHistory? routingPath with
                              | none =>
                                  IO.eprintln "loam: malformed or unsupported Actual routing evidence"
                                  return 2
                              | some routing =>
                                  let yen : MeasureId := ⟨"jpy"⟩
                                  if purposeToken = "--all" then
                                    let purposes := rememberedPurposes capacity
                                    match purposes.mapM
                                        (fun purpose =>
                                          projectPurpose?
                                            capacity effective events corrections validities routing
                                            start end_ purpose yen) with
                                    | none =>
                                        IO.eprintln
                                          "loam: canonical evidence does not justify this budget-window projection"
                                        return 2
                                    | some projections =>
                                        printAll start end_ projections
                                        return 0
                                  else
                                    let purpose : PurposeId := ⟨purposeToken⟩
                                    match
                                        projectPurpose?
                                          capacity effective events corrections validities routing
                                          start end_ purpose yen with
                                    | none =>
                                        IO.eprintln
                                          "loam: canonical evidence does not justify this budget-window projection"
                                        return 2
                                    | some projection =>
                                        printOne start end_ projection
                                        return 0

end Loam.BudgetWindowCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [rootPath, start, end_, purpose] =>
      Loam.BudgetWindowCli.report rootPath start end_ purpose
  | _ => do
      IO.eprintln Loam.BudgetWindowCli.usage
      return 2
