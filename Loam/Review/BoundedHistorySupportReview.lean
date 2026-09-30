import Loam.BoundedHistorySupport
import Loam.Application.CurrentQuantityAnchor
import Loam.HouseholdPaths
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence

namespace Loam.BoundedHistorySupportReview

open Loam.Core

set_option autoImplicit false

structure Row where
  coordinate : EffectCoordinate
  startDay : Option String
  hasExactCurrentAnchor : Bool
deriving Repr, DecidableEq

structure Snapshot where
  rows : List Row
deriving Repr, DecidableEq

private def loadSupport
    (path : System.FilePath) : IO (Except String Loam.BoundedHistorySupport.Evidence) := do
  if !(← path.pathExists) then
    return .ok Loam.BoundedHistorySupport.Evidence.empty
  let some evidence ← Loam.Persistence.loadBoundedHistorySupport? path
    | return .error "loam: bounded historical support authority is malformed or unsupported"
  return .ok evidence

private def loadAnchor
    (path : System.FilePath) : IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  if !(← path.pathExists) then
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty
  let some evidence ← Loam.Persistence.loadCurrentQuantityAnchor? path
    | return .error "loam: current quantity anchor authority is malformed or unsupported"
  return .ok evidence

def project
    (support : Loam.BoundedHistorySupport.Evidence)
    (anchor : Loam.CurrentQuantityAnchor.Evidence) : Snapshot :=
  let coordinates := (anchor.coordinates ++ support.coordinates).eraseDups
  {
    rows := coordinates.map fun coordinate =>
      {
        coordinate := coordinate
        startDay := (support.supportFor? coordinate).map (·.startDay)
        hasExactCurrentAnchor := (anchor.assertionFor? coordinate).isSome
      }
  }

def loadSnapshot (root : System.FilePath) : IO (Except String Snapshot) := do
  let support ←
    match ← loadSupport (Loam.HouseholdPaths.boundedHistorySupport root) with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let anchor ←
    match ← loadAnchor (Loam.HouseholdPaths.currentQuantityAnchor root) with
    | .ok evidence => pure evidence
    | .error message => return .error message
  return .ok (project support anchor)

end Loam.BoundedHistorySupportReview
