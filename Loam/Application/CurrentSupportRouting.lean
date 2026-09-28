import Loam.Core.EventMemory
import Loam.Core.OpeningSupport
import Loam.Core.ZeroOriginCoverage
import Loam.CurrentQuantityAnchor
import Loam.CurrentQuantityPresence

namespace Loam.Application.CurrentSupportRouting

open Loam.Core

set_option autoImplicit false

/-!
# Current quantity support routing

This module owns only the pure routing law shared by current-balance projections.

It combines no authorities, performs no I/O, assigns no AccountingRole, and does
not choose a winner between overlapping support families. Callers must validate
support separation before applying the route.

The routing order therefore describes the four admitted cases rather than a
precedence policy:

- explicit zero-origin support;
- explicit OpeningSupport;
- exact CurrentQuantityAnchor support;
- unsupported by those exact-quantity families.
-/

def eventCoordinates (events : EventMemory) : List EffectCoordinate :=
  events.events.flatMap fun event => event.effects.map fun effect => effect.coordinate

def hasOpeningSupport
    (supportMap : OpeningSupportMap) (coordinate : EffectCoordinate) : Bool :=
  (supportMap.supportFor? coordinate).isSome

def hasCurrentAnchor
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : Bool :=
  (currentAnchor.assertionFor? coordinate).isSome

def candidateCoordinates
    (frontier : EventMemory)
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (currentPresence : Loam.CurrentQuantityPresence.Evidence) : List EffectCoordinate :=
  (eventCoordinates frontier ++ coverage.coordinates ++ openingSupport.coordinates ++
      currentAnchor.coordinates ++ currentPresence.coordinates).eraseDups

inductive SupportRoute where
  | zeroOrigin
  | opening
  | currentAnchor
  | unsupported
  deriving Repr, DecidableEq

/--
Route one already-separated coordinate to its exact-current support family.

Callers validate overlap before invoking this function, so branch order is not a
winner policy.
-/
def supportRoute
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : SupportRoute :=
  if coverage.covers coordinate then
    .zeroOrigin
  else if hasOpeningSupport openingSupport coordinate then
    .opening
  else if hasCurrentAnchor currentAnchor coordinate then
    .currentAnchor
  else
    .unsupported

/-- Zero-origin evidence reaches the zero-origin leaf. -/
theorem zero_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = true) :
    supportRoute coverage openingSupport currentAnchor coordinate = .zeroOrigin := by
  simp [supportRoute, hzero]

/-- Opening support is selected when zero-origin support is absent. -/
theorem opening_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = true) :
    supportRoute coverage openingSupport currentAnchor coordinate = .opening := by
  simp [supportRoute, hzero, hopening]

/-- Current-anchor support is selected when the earlier exact families are absent. -/
theorem anchor_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = false)
    (hanchor : hasCurrentAnchor currentAnchor coordinate = true) :
    supportRoute coverage openingSupport currentAnchor coordinate = .currentAnchor := by
  simp [supportRoute, hzero, hopening, hanchor]

/-- Absence of all three exact support families reaches the unsupported leaf. -/
theorem unsupported_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = false)
    (hanchor : hasCurrentAnchor currentAnchor coordinate = false) :
    supportRoute coverage openingSupport currentAnchor coordinate = .unsupported := by
  simp [supportRoute, hzero, hopening, hanchor]

/-- Every coordinate reaches exactly one constructor of the shared route. -/
theorem support_partition_root
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) :
    supportRoute coverage openingSupport currentAnchor coordinate = .zeroOrigin ∨
      supportRoute coverage openingSupport currentAnchor coordinate = .opening ∨
      supportRoute coverage openingSupport currentAnchor coordinate = .currentAnchor ∨
      supportRoute coverage openingSupport currentAnchor coordinate = .unsupported := by
  cases hzero : coverage.covers coordinate with
  | false =>
      cases hopening : hasOpeningSupport openingSupport coordinate with
      | false =>
          cases hanchor : hasCurrentAnchor currentAnchor coordinate with
          | false =>
              exact Or.inr (Or.inr (Or.inr
                (unsupported_leaf coverage openingSupport currentAnchor coordinate
                  hzero hopening hanchor)))
          | true =>
              exact Or.inr (Or.inr (Or.inl
                (anchor_leaf coverage openingSupport currentAnchor coordinate
                  hzero hopening hanchor)))
      | true =>
          exact Or.inr (Or.inl
            (opening_leaf coverage openingSupport currentAnchor coordinate hzero hopening))
  | true =>
      exact Or.inl (zero_leaf coverage openingSupport currentAnchor coordinate hzero)

structure SupportBuckets where
  zeroOrigin : List EffectCoordinate := []
  opening : List EffectCoordinate := []
  currentAnchor : List EffectCoordinate := []
  unsupported : List EffectCoordinate := []

/--
Partition caller-ordered candidates by the shared route while preserving order
within each support family.
-/
def routeCandidates
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence) :
    List EffectCoordinate → SupportBuckets
  | [] => {}
  | coordinate :: rest =>
      let later := routeCandidates coverage openingSupport currentAnchor rest
      match supportRoute coverage openingSupport currentAnchor coordinate with
      | .zeroOrigin => { later with zeroOrigin := coordinate :: later.zeroOrigin }
      | .opening => { later with opening := coordinate :: later.opening }
      | .currentAnchor => { later with currentAnchor := coordinate :: later.currentAnchor }
      | .unsupported => { later with unsupported := coordinate :: later.unsupported }

end Loam.Application.CurrentSupportRouting
