import Loam.ActualAuthority
import Loam.ActualDate
import Loam.Application.ActualValidityFrontier
import Loam.Application.CapacityWindowInspection
import Loam.CapacityAuthority
import Loam.CapacityReview
import Loam.Persistence.ActualRoutingPersistence

namespace Loam.BudgetWindowReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Budget Window review

This is the production read boundary for explicit half-open budget-window queries.
It consumes selected semantic authorities without exposing physical placement:

- Event / ActualValidity / EventCorrection come through `ActualAuthority`;
- Capacity / CapacityEffective come through `CapacityAuthority`;
- ActualRouting remains its independent canonical stream.

The caller supplies `[start, end)` explicitly. This module does not choose a
cycle, month, selected-day window, or retained Period identity. Remaining is
derived from the two resolved component projections and is not retained state.
-/

structure Row where
  purpose : PurposeId
  entitlement : Quantity
  consumption : Quantity
  deriving Repr, DecidableEq

/-- Exact Remaining derived from the two retained Budget Window components. -/
def Row.remaining (row : Row) : Quantity :=
  row.entitlement - row.consumption

structure Snapshot where
  start : String
  endExclusive : String
  rows : List Row
  deriving Repr, DecidableEq

private structure Evidence where
  capacity : Loam.CapacityAuthority.Image
  events : EventMemory
  corrections : EventCorrectionMemory
  validities : ActualValidityMemory String
  routing : Loam.Persistence.ActualRoutingHistory

private def requireFile (path : System.FilePath) (label : String) : IO (Except String Unit) := do
  if ← path.pathExists then return .ok ()
  return .error ("loam: required " ++ label ++ " not found: " ++ path.toString)

private def validateWindow (start end_ : String) : Except String Unit :=
  if !Loam.ActualDate.validIsoDate start || !Loam.ActualDate.validIsoDate end_ then
    .error "loam: budget window endpoints must be real YYYY-MM-DD calendar dates"
  else if !validCapacityWindow start end_ then
    .error "loam: budget window start must be earlier than end"
  else
    .ok ()

private def projectPurpose?
    (evidence : Evidence)
    (start end_ : String)
    (purpose : PurposeId) : Option Row := do
  let yen : MeasureId := ⟨"jpy"⟩
  let entitlement ←
    entitlementAtAdmittedEffectiveWindow?
      evidence.capacity start end_ purpose yen
  let consumption ←
    consumptionAtCorrectionFrontierEffectiveRoutingWindow?
      evidence.events evidence.corrections evidence.validities evidence.routing
      start end_ purpose yen
  some {
    purpose := purpose
    entitlement := entitlement
    consumption := consumption
  }

/--
Project one Purpose after the query-global correction frontier has already been
admitted. Entitlement remains Purpose-local, while Capacity cross-family
completeness is carried by the already-admitted authority image and is not
rescanned per Purpose.
-/
private def projectPurposeFromFrontier?
    (evidence : Evidence)
    (frontier : EventMemory)
    (start end_ : String)
    (purpose : PurposeId) : Option Row := do
  let yen : MeasureId := ⟨"jpy"⟩
  let entitlement ←
    entitlementAtAdmittedEffectiveWindow?
      evidence.capacity start end_ purpose yen
  let consumption ←
    consumptionAtRecordedEffectiveRoutingWindow?
      frontier evidence.validities evidence.routing start end_ purpose yen
  some {
    purpose := purpose
    entitlement := entitlement
    consumption := consumption
  }

private def loadActualEvidence
    (actualRoot : System.FilePath) : IO (Except String Loam.ActualEvidence) :=
  if actualRoot.fileName == some Loam.ActualAuthority.actualFileName then
    Loam.ActualAuthority.loadActualFile? actualRoot
  else
    Loam.ActualAuthority.loadActual? actualRoot

private def loadEvidence
    (dataDir actualRoot : System.FilePath) : IO (Except String Evidence) := do
  let capacityPath := dataDir / "capacity.loam"
  let routingPath := dataDir / "actual-routing.loam"

  let capacityImage ←
    match ← Loam.CapacityAuthority.loadRequired capacityPath with
    | .ok image => pure image
    | .error message => return .error message
  match ← requireFile routingPath "Actual routing evidence" with
  | .error message => return .error message
  | .ok _ => pure ()

  let actualEvidence ←
    match ← loadActualEvidence actualRoot with
    | .ok ev => pure ev
    | .error message => return .error message

  let validities ←
    match admittedActualValidityMemory? actualEvidence.validity with
    | some memory => pure memory
    | none =>
        return .error
          "loam: Actual validity corrections do not justify one current date per Event"
  let routing ←
    match ← Loam.Persistence.loadActualRoutingHistory? routingPath with
    | some history => pure history
    | none => return .error "loam: malformed or unsupported Actual routing evidence"

  return .ok {
    capacity := capacityImage
    events := actualEvidence.events
    corrections := actualEvidence.corrections
    validities := validities
    routing := routing
  }

private def loadWindowEvidence
    (dataDir actualRoot : System.FilePath)
    (start end_ : String) : IO (Except String Evidence) := do
  match validateWindow start end_ with
  | .error message => return .error message
  | .ok _ => loadEvidence dataDir actualRoot

/--
Load one immutable production evidence snapshot and answer one explicit JPY
Purpose over `[start, end)`. The Purpose need not already appear in Capacity
history: complete evidence can therefore justify an exact zero row.
-/
def loadPurposeRow
    (dataDir actualRoot : System.FilePath)
    (start end_ : String)
    (purpose : PurposeId) : IO (Except String Row) := do
  let evidence ←
    match ← loadWindowEvidence dataDir actualRoot start end_ with
    | .ok evidence => pure evidence
    | .error message => return .error message
  match projectPurpose? evidence start end_ purpose with
  | some row => return .ok row
  | none =>
      return .error "loam: canonical evidence does not justify this budget-window projection"

/--
Load one immutable production evidence snapshot and answer an explicit JPY
`[start, end)` query for every Purpose represented by retained Capacity evidence.

An empty Purpose set remains an empty successful answer without forcing an
otherwise irrelevant correction-world obligation. For a non-empty set, the
first Purpose keeps the existing Entitlement-before-Consumption refusal order;
after that gate succeeds, one correction frontier is admitted and shared by all
Purpose-local Consumption projections.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start end_ : String) : IO (Except String Snapshot) := do
  let evidence ←
    match ← loadWindowEvidence dataDir actualRoot start end_ with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let purposes := Loam.CapacityReview.rememberedPurposes evidence.capacity.movements
  match purposes with
  | [] =>
      return .ok { start := start, endExclusive := end_, rows := [] }
  | first :: rest =>
      let yen : MeasureId := ⟨"jpy"⟩
      let some firstEntitlement :=
          entitlementAtAdmittedEffectiveWindow?
            evidence.capacity start end_ first yen
        | return .error "loam: canonical evidence does not justify this budget-window projection"
      let some frontier := correctionFrontierMemory? evidence.events evidence.corrections
        | return .error "loam: canonical evidence does not justify this budget-window projection"
      let some firstConsumption :=
          consumptionAtRecordedEffectiveRoutingWindow?
            frontier evidence.validities evidence.routing start end_ first yen
        | return .error "loam: canonical evidence does not justify this budget-window projection"
      let firstRow : Row := {
        purpose := first
        entitlement := firstEntitlement
        consumption := firstConsumption
      }
      match rest.mapM (projectPurposeFromFrontier? evidence frontier start end_) with
      | none =>
          return .error "loam: canonical evidence does not justify this budget-window projection"
      | some later =>
          return .ok { start := start, endExclusive := end_, rows := firstRow :: later }

end Loam.BudgetWindowReview
