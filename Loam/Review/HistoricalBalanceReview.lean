import Loam.Authority.ActualAuthority
import Loam.ActualDate
import Loam.Review.BalanceReview
import Loam.Core.BoundedHistorySupport
import Loam.Application.CurrentQuantityAnchor
import Loam.Authority.OpeningSupportAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.HouseholdPaths

namespace Loam.HistoricalBalanceReview

open Loam.Core

set_option autoImplicit false

/-!
# Historical balance reconstruction

This is the shared read boundary for exact historical quantity reconstruction.

Two independent justification routes are admitted coordinate by coordinate:

```text
ZeroOriginCoverage
        +
correction/date-admitted ActualAuthority.Image
        ↓
forward reconstruction from exact zero origin
```

and

```text
BoundedHistorySupport
        +
CurrentQuantityAnchor
        +
correction/date-admitted ActualAuthority.Image
        ↓
backward reconstruction to the certified start
```

The current Event frontier comes only from `ActualAuthority.Image.currentEvents`.
Current occurrence dates come only from `Image.currentValidities`. Event
correction and ActualValidity correction therefore remain owned by the existing
admitted Actual image.

This module does not widen `BalanceReview`, reinterpret `OpeningSupport` as
historical completeness, infer completeness from endpoint equality, store opening
quantities, create report state, or invent another correction/date engine.
-/

structure Row where
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

structure Snapshot where
  startOfDay : String
  rows : List Row
deriving Repr, DecidableEq

structure Evidence where
  zeroOrigin : ZeroOriginCoverage
  opening : OpeningSupportMap
  bounded : Loam.BoundedHistorySupport.Evidence
  anchor : Loam.CurrentQuantityAnchor.Evidence

private inductive Route where
  | zeroOrigin
  | bounded
deriving Repr, DecidableEq

private def coordinateLabel (coordinate : EffectCoordinate) : String :=
  coordinate.locus.token ++ " / " ++ coordinate.measure.token

private def supportConflict {α : Type}
    (coordinate : EffectCoordinate) : Except String α :=
  .error
    ("loam: historical balance unavailable: competing support families for " ++
      coordinateLabel coordinate)

private def admittedEventDate
    (image : Loam.ActualAuthority.Image)
    (event : Event) : Except String String := do
  let some validOn := image.currentValidities.findByEventId? event.id
    | throw
        ("loam: historical balance unavailable: current selected Actual " ++
          event.id.token ++ " has no admitted occurrence date")
  if !Loam.ActualDate.validIsoDate validOn then
    throw
      ("loam: historical balance unavailable: current selected Actual " ++
        event.id.token ++ " has an invalid occurrence date")
  return validOn

/-- Exact zero-origin quantity at the queried start-of-day boundary. -/
private def zeroOriginQuantityAtStart
    (image : Loam.ActualAuthority.Image)
    (coordinate : EffectCoordinate)
    (startOfDay : String) : Except String Quantity := do
  let total ← image.currentEvents.events.foldlM
    (fun total event => do
      let quantity :=
        (Event.quantityAt event coordinate.locus coordinate.measure).quanta
      if quantity = 0 then
        return total
      let validOn ← admittedEventDate image event
      if decide (validOn < startOfDay) then
        return total + quantity
      return total)
    0
  return Quantity.ofQuanta total

/--
Current-truth quantity delta on one coordinate from the queried start-of-day
boundary through the admitted current Actual frontier.
-/
private def deltaFromStartOfDay
    (image : Loam.ActualAuthority.Image)
    (coordinate : EffectCoordinate)
    (startOfDay : String) : Except String Int :=
  image.currentEvents.events.foldlM
    (fun total event => do
      let quantity :=
        (Event.quantityAt event coordinate.locus coordinate.measure).quanta
      if quantity = 0 then
        return total
      let validOn ← admittedEventDate image event
      if decide (startOfDay ≤ validOn) then
        return total + quantity
      return total)
    0

private def validateBoundedCoordinate
    (evidence : Evidence)
    (startOfDay : String)
    (coordinate : EffectCoordinate) :
    Except String Unit := do
  let some support := evidence.bounded.supportFor? coordinate
    | throw
        ("loam: historical balance unavailable: bounded history support missing for " ++
          coordinateLabel coordinate)
  if decide (startOfDay < support.startDay) then
    throw
      ("loam: historical balance unavailable: requested boundary precedes bounded history start for " ++
        coordinateLabel coordinate)
  if (evidence.anchor.assertionFor? coordinate).isNone then
    throw
      ("loam: historical balance unavailable: exact current anchor missing for " ++
        coordinateLabel coordinate)
  if evidence.zeroOrigin.covers coordinate ||
      (evidence.opening.supportFor? coordinate).isSome then
    supportConflict coordinate

private def routeCoordinate
    (evidence : Evidence)
    (startOfDay : String)
    (coordinate : EffectCoordinate) : Except String Route := do
  let zero := evidence.zeroOrigin.covers coordinate
  let bounded := (evidence.bounded.supportFor? coordinate).isSome
  let opening := (evidence.opening.supportFor? coordinate).isSome
  let anchored := (evidence.anchor.assertionFor? coordinate).isSome

  if zero then
    if bounded || opening || anchored then
      supportConflict coordinate
    return .zeroOrigin

  if bounded then
    validateBoundedCoordinate evidence startOfDay coordinate
    return .bounded

  if opening then
    throw
      ("loam: historical balance unavailable: opening support does not justify historical reconstruction for " ++
        coordinateLabel coordinate)

  if anchored then
    throw
      ("loam: historical balance unavailable: bounded history support missing for " ++
        coordinateLabel coordinate)

  throw
    ("loam: historical balance unavailable: historical support missing for " ++
      coordinateLabel coordinate)

private def boundedRows
    (image : Loam.ActualAuthority.Image)
    (evidence : Evidence)
    (startOfDay : String)
    (coordinates : List EffectCoordinate) :
    Except String (List Row) := do
  for coordinate in coordinates do
    validateBoundedCoordinate evidence startOfDay coordinate
  let currents ←
    Loam.CurrentQuantityAnchor.inspectQuantities
      image.evidence.events image.evidence.corrections evidence.anchor coordinates
  (coordinates.zip currents).mapM fun pair => do
    let coordinate := pair.1
    let some current := pair.2
      | throw
          ("loam: historical balance unavailable: exact current anchor did not resolve for " ++
            coordinateLabel coordinate)
    let delta ← deltaFromStartOfDay image coordinate startOfDay
    return {
      coordinate := coordinate
      quantity := Quantity.ofQuanta (current.quanta - delta)
    }

/--
Reconstruct exact quantities at one start-of-day boundary through the bounded
historical support route only.

This narrow entrance remains available for callers that specifically require
bounded support rather than the general historical-support router.
-/
def projectBoundedStartOfDay
    (image : Loam.ActualAuthority.Image)
    (evidence : Evidence)
    (startOfDay : String)
    (coordinates : List EffectCoordinate) :
    Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate startOfDay then
    throw "loam: historical balance boundary must be a real YYYY-MM-DD calendar date"
  let selected := coordinates.eraseDups
  let rows ← boundedRows image evidence startOfDay selected
  return { startOfDay := startOfDay, rows := rows }

/--
Reconstruct exact quantities at one start-of-day boundary, choosing the
independently justified route for each coordinate.

A coordinate may use exact zero-origin forward reconstruction or certified
bounded backward reconstruction. OpeningSupport alone never authorizes history,
and support-family overlap is refused rather than assigned precedence.
-/
def projectStartOfDay
    (image : Loam.ActualAuthority.Image)
    (evidence : Evidence)
    (startOfDay : String)
    (coordinates : List EffectCoordinate) :
    Except String Snapshot := do
  if !Loam.ActualDate.validIsoDate startOfDay then
    throw "loam: historical balance boundary must be a real YYYY-MM-DD calendar date"
  let selected := coordinates.eraseDups
  let routes ← selected.mapM (routeCoordinate evidence startOfDay)
  let boundedCoordinates :=
    (selected.zip routes).filterMap fun pair =>
      match pair.2 with
      | .bounded => some pair.1
      | .zeroOrigin => none
  let bounded ← boundedRows image evidence startOfDay boundedCoordinates
  let rows ← (selected.zip routes).mapM fun pair => do
    let coordinate := pair.1
    match pair.2 with
    | .zeroOrigin =>
        let quantity ← zeroOriginQuantityAtStart image coordinate startOfDay
        return { coordinate := coordinate, quantity := quantity }
    | .bounded =>
        let some row := bounded.find? fun row => decide (row.coordinate = coordinate)
          | throw
              ("loam: historical balance unavailable: bounded projection lost " ++
                coordinateLabel coordinate)
        return row
  return { startOfDay := startOfDay, rows := rows }

/-- Load the independent support families needed by historical reconstruction. -/
def loadEvidence (dataDir : System.FilePath) : IO (Except String Evidence) := do
  let zeroOrigin ←
    match ← Loam.BalanceReview.loadHouseholdCoverage dataDir with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let opening ←
    match ← Loam.OpeningSupportAuthority.loadHouseholdOrEmpty? dataDir with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let currentSupport ←
    match ← Loam.CurrentSupportAuthority.loadHousehold? dataDir with
    | .error message => return .error message
    | .ok observed => pure observed.snapshot
  return .ok {
    zeroOrigin
    opening
    bounded := currentSupport.bounded
    anchor := currentSupport.anchor
  }

/-- Reconstruct one bounded-only boundary from a caller-owned Actual generation. -/
def loadBoundedStartOfDayFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (startOfDay : String)
    (coordinates : List EffectCoordinate) :
    IO (Except String Snapshot) := do
  let evidence ←
    match ← loadEvidence dataDir with
    | .error message => return .error message
    | .ok evidence => pure evidence
  return projectBoundedStartOfDay image evidence startOfDay coordinates

/-- Load one Actual generation and reconstruct one bounded-only historical boundary. -/
def loadBoundedStartOfDay
    (dataDir actualRoot : System.FilePath)
    (startOfDay : String)
    (coordinates : List EffectCoordinate) :
    IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadBoundedStartOfDayFromActualImage dataDir image startOfDay coordinates

/-- Reconstruct one mixed-support historical boundary from a caller-owned Actual image. -/
def loadStartOfDayFromActualImage
    (dataDir : System.FilePath)
    (image : Loam.ActualAuthority.Image)
    (startOfDay : String)
    (coordinates : List EffectCoordinate) :
    IO (Except String Snapshot) := do
  let evidence ←
    match ← loadEvidence dataDir with
    | .error message => return .error message
    | .ok evidence => pure evidence
  return projectStartOfDay image evidence startOfDay coordinates

/-- Load one Actual generation and reconstruct one mixed-support historical boundary. -/
def loadStartOfDay
    (dataDir actualRoot : System.FilePath)
    (startOfDay : String)
    (coordinates : List EffectCoordinate) :
    IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .error message => return .error message
    | .ok image => pure image
  loadStartOfDayFromActualImage dataDir image startOfDay coordinates

end Loam.HistoricalBalanceReview
