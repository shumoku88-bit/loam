import Loam.CurrentCoverageReview
import Loam.ActualAuthority
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ActualRoutingPersistence

open Loam.Core
open Loam.Application

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private structure UnroutedExpenseRow where
  event : EventId
  validOn : String
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

private def inCurrentWindow (start observedAt value : String) : Bool :=
  decide (start ≤ value) && decide (value ≤ observedAt)

private def addLocusIfAbsent (loci : List LocusId) (locus : LocusId) : List LocusId :=
  if locus ∈ loci then loci else loci ++ [locus]

private def eventLociAtMeasure (event : Event) (measure : MeasureId) : List LocusId :=
  event.effects.foldl
    (fun loci effect =>
      if effect.measure = measure then addLocusIfAbsent loci effect.locus else loci)
    []

private def eventUnroutedExpenseRows
    (event : Event)
    (validOn start observedAt : String)
    (roles : AccountingRoleMap)
    (routing : Loam.Persistence.ActualRoutingHistory)
    (measure : MeasureId) : List UnroutedExpenseRow :=
  if !inCurrentWindow start observedAt validOn then
    []
  else
    (eventLociAtMeasure event measure).filterMap fun locus =>
      match roles.roleOf? locus, routing.statusAt locus (.dated validOn) with
      | some .expense, .unrouted =>
          some {
            event := event.id
            validOn := validOn
            coordinate := ⟨locus, measure⟩
            quantity := event.quantityAt locus measure }
      | _, _ => none

private def unroutedExpenseRowsThrough?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (validities : ActualValidityMemory String)
    (roles : AccountingRoleMap)
    (routing : Loam.Persistence.ActualRoutingHistory)
    (start observedAt : String)
    (measure : MeasureId) : Option (List UnroutedExpenseRow) := do
  if !validCurrentWindow start observedAt then none else
  let frontier ← correctionFrontierMemory? events corrections
  frontier.events.foldlM
    (fun rows event => do
      let validOn ← validities.findByEventId? event.id
      return rows ++ eventUnroutedExpenseRows event validOn start observedAt roles routing measure)
    []

private def loadActualFrontier
    (dataDir : System.FilePath)
    (start observedAt : String) : IO (Except String (List UnroutedExpenseRow)) := do
  let actualEvidence ←
    match ← Loam.ActualAuthority.loadActual? dataDir with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let validities ←
    match admittedActualValidityMemory? actualEvidence.validity with
    | some memory => pure memory
    | none => return .error "Observation 249: Actual validity frontier unavailable"
  let routing ←
    match ← Loam.Persistence.loadActualRoutingHistory? (dataDir / "actual-routing.loam") with
    | some history => pure history
    | none => return .error "Observation 249: Actual routing unavailable"
  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? (dataDir / "accounting-role.loam") with
    | some roleMap => pure roleMap
    | none => return .error "Observation 249: AccountingRole map unavailable"
  match unroutedExpenseRowsThrough?
      actualEvidence.events actualEvidence.corrections validities roles routing
      start observedAt ⟨"jpy"⟩ with
  | some rows => return .ok rows
  | none => return .error "Observation 249: derived Actual frontier failed closed"

private def findFrontierRow?
    (rows : List UnroutedExpenseRow) (locus : String) : Option UnroutedExpenseRow :=
  rows.find? fun row => row.coordinate.locus.token == locus

private def printCoverageRow (row : Loam.CurrentCoverageReview.Row) : IO Unit :=
  IO.println s!"COVERAGE\t{row.purpose.token}\tentitlement={row.entitlement.quanta}\tconsumption={row.consumption.quanta}\tremaining={row.remaining.quanta}\tcommitment={row.commitment.quanta}\theadroom={row.headroom.quanta}"

private def printFrontierRow (row : UnroutedExpenseRow) : IO Unit :=
  IO.println s!"ACTUAL-FRONTIER\t{row.validOn}\t{row.event.token}\t{row.coordinate.locus.token}\t{row.coordinate.measure.token}\t{row.quantity.quanta}"

def main (args : List String) : IO Unit := do
  let [dataPath] := args
    | throw <| IO.userError "usage: 249_current_coverage_frontier_dogfood DATA_DIR"
  let dataDir := System.FilePath.mk dataPath
  let start := "2026-08-14"
  let observedAt := "2026-09-13"
  let endExclusive := "2026-10-15"

  let .ok snapshot ← Loam.CurrentCoverageReview.loadSnapshotAt
      dataDir dataDir start observedAt endExclusive
    | throw <| IO.userError "Observation 249: CurrentCoverage snapshot unavailable"
  let .ok frontier ← loadActualFrontier dataDir start observedAt
    | throw <| IO.userError "Observation 249: Actual frontier unavailable"

  IO.println s!"WINDOW\t{start}\t{observedAt}\t{endExclusive}"
  for row in snapshot.rows do
    printCoverageRow row
  for row in frontier do
    printFrontierRow row

  expect (frontier.length == 4)
    s!"expected four real-data Actual frontier rows, got {frontier.length}: {repr frontier}"
  let rent ← requireSome (findFrontierRow? frontier "rent") "missing rent frontier row"
  let utilities ← requireSome (findFrontierRow? frontier "utilities") "missing utilities frontier row"
  let shipping ← requireSome (findFrontierRow? frontier "shipping") "missing shipping frontier row"
  let snacks ← requireSome (findFrontierRow? frontier "snacks") "missing snacks frontier row"

  expect (rent.validOn == "2026-08-15" && rent.quantity.quanta == 64000)
    "rent frontier witness changed"
  expect (utilities.validOn == "2026-08-15" && utilities.quantity.quanta == 20854)
    "utilities frontier witness changed"
  expect (shipping.validOn == "2026-09-05" && shipping.quantity.quanta == 720)
    "shipping frontier witness changed"
  expect (snacks.validOn == "2026-09-06" && snacks.quantity.quanta == 354)
    "snacks frontier witness changed"

  let total := frontier.foldl (fun sum row => sum + row.quantity.quanta) 0
  expect (total == 85928) s!"real-data frontier total changed to {total}"
  IO.println s!"ACTUAL-FRONTIER-TOTAL\t{total}"
  IO.println "Observation 249 dogfood: CurrentCoverage values coexist with four real Event-valid unrouted Expense coordinates."
