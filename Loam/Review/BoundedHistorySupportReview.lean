import Loam.Core.BoundedHistorySupport
import Loam.Application.CurrentQuantityAnchor
import Loam.Authority.CurrentSupportAuthority

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
  let currentSupport ←
    match ← Loam.CurrentSupportAuthority.loadHousehold? root with
    | .ok observed => pure observed.snapshot
    | .error message => return .error message
  return .ok (project currentSupport.bounded currentSupport.anchor)

end Loam.BoundedHistorySupportReview
