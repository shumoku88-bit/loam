import Loam.ActualAuthority
import Loam.ActualDate
import Loam.BalanceReview
import Loam.BoundedHistorySupport
import Loam.CurrentQuantityAnchor
import Loam.HouseholdPaths
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.OpeningSupportPersistence

namespace Loam.HistoricalBalanceReview

open Loam.Core

set_option autoImplicit false

/-!
# Historical balance reconstruction

This is the shared read boundary for exact historical quantity reconstruction.

The first production route is deliberately narrow:

```text
BoundedHistorySupport
        +
CurrentQuantityAnchor
        +
ActualAuthority.Image
        ↓
exact start-of-day quantity
```

For one supported coordinate and one calendar boundary `t`:

```text
quantity at start of day t
  = exact current anchored quantity
  - current-truth dated deltas whose occurrence date >= t
```

The current Event frontier comes only from `ActualAuthority.Image.currentEvents`.
Current occurrence dates come only from `Image.currentValidities`. Event
correction and ActualValidity correction therefore remain owned by the existing
admitted Actual image.

This module does not widen `BalanceReview`, infer completeness from endpoint
equality, store opening quantities, create report state, or invent a second
correction/date engine. The zero-origin forward route remains independently
owned until a later integration composes both justifications here.
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

private def coordinateLabel (coordinate : EffectCoordinate) : String :=
  coordinate.locus.token ++ " / " ++ coordinate.measure.token

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
    throw
      ("loam: historical balance unavailable: competing support families for " ++
        coordinateLabel coordinate)

/--
Current-truth quantity delta on one coordinate from the queried start-of-day
boundary through the admitted current Actual frontier.

Only current correction-frontier Events contribute. A selected nonzero Event
must carry one admitted current occurrence date. `ActualAuthority.Image` already
proves that invariant, but the local check keeps this projection fail-closed if
its representation is ever generalized.
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
      let some validOn := image.currentValidities.findByEventId? event.id
        | throw
            ("loam: historical balance unavailable: current selected Actual " ++
              event.id.token ++ " has no admitted occurrence date")
      if !Loam.ActualDate.validIsoDate validOn then
        throw
          ("loam: historical balance unavailable: current selected Actual " ++
            event.id.token ++ " has an invalid occurrence date")
      if decide (startOfDay ≤ validOn) then
        return total + quantity
      return total)
    0

/--
Reconstruct exact quantities at one start-of-day boundary through the bounded
historical support route.

Presentation duplicates are normalized. Every selected coordinate must have its
own explicit bounded start and exact current anchor. A query never crosses an
earlier support start, and manually conflicting zero-origin/opening support is
refused rather than assigned precedence.
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
  for coordinate in selected do
    validateBoundedCoordinate evidence startOfDay coordinate
  let currents ←
    Loam.CurrentQuantityAnchor.inspectQuantities
      image.evidence.events image.evidence.corrections evidence.anchor selected
  let rows ← (selected.zip currents).mapM fun pair => do
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
  return { startOfDay := startOfDay, rows := rows }

private def loadOpening
    (path : System.FilePath) : IO (Except String OpeningSupportMap) := do
  if !(← path.pathExists) then
    return .ok OpeningSupportMap.empty
  let some evidence ← Loam.Persistence.loadOpeningSupportMap? path
    | return .error "loam: malformed or unsupported opening support evidence"
  return .ok evidence

private def loadAnchor
    (path : System.FilePath) :
    IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  if !(← path.pathExists) then
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty
  let some evidence ← Loam.Persistence.loadCurrentQuantityAnchor? path
    | return .error "loam: malformed or unsupported current quantity anchor evidence"
  return .ok evidence

private def loadBounded
    (path : System.FilePath) :
    IO (Except String Loam.BoundedHistorySupport.Evidence) := do
  if !(← path.pathExists) then
    return .ok Loam.BoundedHistorySupport.Evidence.empty
  let some evidence ← Loam.Persistence.loadBoundedHistorySupport? path
    | return .error "loam: malformed or unsupported bounded historical support evidence"
  return .ok evidence

/-- Load the independent support families needed by bounded historical reconstruction. -/
def loadEvidence (dataDir : System.FilePath) : IO (Except String Evidence) := do
  let zeroOrigin ←
    match ← Loam.BalanceReview.loadCoverage
        (Loam.HouseholdPaths.zeroOriginCoverage dataDir) with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let opening ←
    match ← loadOpening (Loam.HouseholdPaths.openingSupport dataDir) with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let bounded ←
    match ← loadBounded (Loam.HouseholdPaths.boundedHistorySupport dataDir) with
    | .error message => return .error message
    | .ok evidence => pure evidence
  let anchor ←
    match ← loadAnchor (Loam.HouseholdPaths.currentQuantityAnchor dataDir) with
    | .error message => return .error message
    | .ok evidence => pure evidence
  return .ok { zeroOrigin, opening, bounded, anchor }

/-- Reconstruct one boundary from a caller-owned admitted Actual generation. -/
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

/-- Load one admitted Actual generation and reconstruct one bounded historical boundary. -/
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

end Loam.HistoricalBalanceReview
