import Loam.RoleBalanceReview

namespace Loam.Tests.RoleBalanceProofDag

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

/-!
# Hand-written proof-obligation DAG probe

This is intentionally not a framework. It mirrors only the support-selection
boolean guards currently used by `RoleBalanceReview.project` and asks Lean to
qualify the decomposition shape itself.

Parent obligation:

* every represented coordinate is routed to exactly one support bucket.

Leaf obligations:

* zero-origin support wins when present;
* otherwise opening support wins when present;
* otherwise current-anchor support wins when present;
* otherwise the coordinate is unsupported.

The parent theorem closes only by selecting one of those four already-proved
leaf cases. This is the small LOAM analogue of a theorem DAG: statements are
independent leaves, while the root merely composes qualified results.
-/

private def hasOpeningSupport
    (supportMap : OpeningSupportMap) (coordinate : EffectCoordinate) : Bool :=
  (supportMap.supportFor? coordinate).isSome

private def hasCurrentAnchor
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : Bool :=
  (currentAnchor.assertionFor? coordinate).isSome

private def zeroGuard
    (coverage : ZeroOriginCoverage) (coordinate : EffectCoordinate) : Bool :=
  coverage.covers coordinate

private def openingGuard
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (coordinate : EffectCoordinate) : Bool :=
  !coverage.covers coordinate && hasOpeningSupport openingSupport coordinate

private def anchorGuard
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : Bool :=
  !coverage.covers coordinate &&
    !hasOpeningSupport openingSupport coordinate &&
    hasCurrentAnchor currentAnchor coordinate

private def unsupportedGuard
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : Bool :=
  !coverage.covers coordinate &&
    !hasOpeningSupport openingSupport coordinate &&
    !hasCurrentAnchor currentAnchor coordinate

private def supportGuards
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) : List Bool :=
  [ zeroGuard coverage coordinate
  , openingGuard coverage openingSupport coordinate
  , anchorGuard coverage openingSupport currentAnchor coordinate
  , unsupportedGuard coverage openingSupport currentAnchor coordinate
  ]

/-- DAG leaf Z: zero-origin support selects only the zero bucket. -/
private theorem zero_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = true) :
    supportGuards coverage openingSupport currentAnchor coordinate =
      [true, false, false, false] := by
  simp [supportGuards, zeroGuard, openingGuard, anchorGuard, unsupportedGuard, hzero]

/-- DAG leaf O: absent zero-origin plus opening support selects only opening. -/
private theorem opening_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = true) :
    supportGuards coverage openingSupport currentAnchor coordinate =
      [false, true, false, false] := by
  simp [supportGuards, zeroGuard, openingGuard, anchorGuard, unsupportedGuard,
    hzero, hopening]

/-- DAG leaf A: absent earlier support plus an anchor selects only the anchor. -/
private theorem anchor_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = false)
    (hanchor : hasCurrentAnchor currentAnchor coordinate = true) :
    supportGuards coverage openingSupport currentAnchor coordinate =
      [false, false, true, false] := by
  simp [supportGuards, zeroGuard, openingGuard, anchorGuard, unsupportedGuard,
    hzero, hopening, hanchor]

/-- DAG leaf U: absence of all support selects only the unsupported bucket. -/
private theorem unsupported_leaf
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate)
    (hzero : coverage.covers coordinate = false)
    (hopening : hasOpeningSupport openingSupport coordinate = false)
    (hanchor : hasCurrentAnchor currentAnchor coordinate = false) :
    supportGuards coverage openingSupport currentAnchor coordinate =
      [false, false, false, true] := by
  simp [supportGuards, zeroGuard, openingGuard, anchorGuard, unsupportedGuard,
    hzero, hopening, hanchor]

/--
DAG root: the four qualified leaves compose into one exactly-one routing result.
No leaf proves another leaf, and the root contains no support-selection algebra.
-/
private theorem support_partition_root
    (coverage : ZeroOriginCoverage)
    (openingSupport : OpeningSupportMap)
    (currentAnchor : Loam.CurrentQuantityAnchor.Evidence)
    (coordinate : EffectCoordinate) :
    (supportGuards coverage openingSupport currentAnchor coordinate).count true = 1 := by
  cases hzero : coverage.covers coordinate with
  | false =>
      cases hopening : hasOpeningSupport openingSupport coordinate with
      | false =>
          cases hanchor : hasCurrentAnchor currentAnchor coordinate with
          | false =>
              rw [unsupported_leaf coverage openingSupport currentAnchor coordinate
                hzero hopening hanchor]
              decide
          | true =>
              rw [anchor_leaf coverage openingSupport currentAnchor coordinate
                hzero hopening hanchor]
              decide
      | true =>
          rw [opening_leaf coverage openingSupport currentAnchor coordinate hzero hopening]
          decide
  | true =>
      rw [zero_leaf coverage openingSupport currentAnchor coordinate hzero]
      decide

end Loam.Tests.RoleBalanceProofDag
