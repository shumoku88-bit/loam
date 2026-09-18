import Loam.CurrentQuantityAnchor
import Loam.Core.OpeningSupport
import Loam.Core.ZeroOriginCoverage

namespace Loam.Observation270

open Loam.Core

set_option autoImplicit false

/-!
# Observation 270 — proof-carrying balance support aggregate

Role Balance currently composes three independently retained current-balance
support families:

- ZeroOriginCoverage;
- OpeningSupport;
- CurrentQuantityAnchor.

The authorities remain semantically and physically independent. This observation
asks a narrower question:

> After those authorities have been read, can their pairwise non-overlap
> requirement be carried once by a proof-bearing value instead of being rechecked
> by every downstream consumer?

World-relative obligations are deliberately excluded. Opening witnesses must still
be validated against the current Actual correction frontier, and anchor reflected
roots must still be validated against the current Actual correction world.
-/

/-- Pure cross-authority separation check. No Actual world is consulted here. -/
def supportFamiliesSeparated
    (coverage : ZeroOriginCoverage)
    (opening : OpeningSupportMap)
    (anchor : Loam.CurrentQuantityAnchor.Evidence) : Bool :=
  opening.supports.all (fun support =>
      !coverage.covers support.coordinate) &&
    anchor.assertions.all (fun assertion =>
      !coverage.covers assertion.coordinate &&
        (opening.supportFor? assertion.coordinate).isNone)

/--
Observation-local proof-carrying aggregate.

This is intentionally not a persistence image. Each retained authority remains
independent; the value exists only after read-side composition.
-/
structure SupportEvidence where
  zeroOrigin : ZeroOriginCoverage
  opening : OpeningSupportMap
  currentAnchor : Loam.CurrentQuantityAnchor.Evidence
  separation : supportFamiliesSeparated zeroOrigin opening currentAnchor = true

namespace SupportEvidence

/-- Admit only read-side support bundles whose retained families do not overlap. -/
def ofParts?
    (coverage : ZeroOriginCoverage)
    (opening : OpeningSupportMap)
    (anchor : Loam.CurrentQuantityAnchor.Evidence) : Option SupportEvidence :=
  if h : supportFamiliesSeparated coverage opening anchor = true then
    some {
      zeroOrigin := coverage
      opening := opening
      currentAnchor := anchor
      separation := h
    }
  else
    none

/-- Downstream code can consume the carried invariant without re-running admission. -/
theorem carries_separation (evidence : SupportEvidence) :
    supportFamiliesSeparated
      evidence.zeroOrigin evidence.opening evidence.currentAnchor = true :=
  evidence.separation

end SupportEvidence

private def yen : MeasureId := ⟨"jpy"⟩
private def locusA : LocusId := ⟨"o270-a"⟩
private def locusB : LocusId := ⟨"o270-b"⟩
private def locusC : LocusId := ⟨"o270-c"⟩

private def coordinateA : EffectCoordinate := ⟨locusA, yen⟩
private def coordinateB : EffectCoordinate := ⟨locusB, yen⟩
private def coordinateC : EffectCoordinate := ⟨locusC, yen⟩

private def coverageA : ZeroOriginCoverage := {
  coordinates := [coordinateA]
  nodup := by simp
}

private def openingA : OpeningSupportMap := {
  supports := [{ coordinate := coordinateA, openingEvent := ⟨"o270-opening-a"⟩ }]
  coordinateNodup := by simp
}

private def openingB : OpeningSupportMap := {
  supports := [{ coordinate := coordinateB, openingEvent := ⟨"o270-opening-b"⟩ }]
  coordinateNodup := by simp
}

private def anchorA : Loam.CurrentQuantityAnchor.Evidence := {
  reflectedRoots := []
  assertions := [{
    coordinate := coordinateA
    quantity := Quantity.ofQuanta 10
  }]
  rootNodup := by simp
  coordinateNodup := by simp
}

private def anchorB : Loam.CurrentQuantityAnchor.Evidence := {
  reflectedRoots := []
  assertions := [{
    coordinate := coordinateB
    quantity := Quantity.ofQuanta 20
  }]
  rootNodup := by simp
  coordinateNodup := by simp
}

private def anchorC : Loam.CurrentQuantityAnchor.Evidence := {
  reflectedRoots := []
  assertions := [{
    coordinate := coordinateC
    quantity := Quantity.ofQuanta 30
  }]
  rootNodup := by simp
  coordinateNodup := by simp
}

/-- Three independent families on three coordinates admit one proof-carrying bundle. -/
theorem separated_families_are_admitted :
    (SupportEvidence.ofParts? coverageA openingB anchorC).isSome = true := by
  native_decide

/-- Zero-origin and OpeningSupport may each be valid alone but cannot claim one coordinate together. -/
theorem zero_opening_overlap_is_rejected :
    (SupportEvidence.ofParts?
      coverageA openingA Loam.CurrentQuantityAnchor.Evidence.empty).isNone = true := by
  native_decide

/-- Zero-origin and CurrentQuantityAnchor cannot claim one coordinate together. -/
theorem zero_anchor_overlap_is_rejected :
    (SupportEvidence.ofParts? coverageA OpeningSupportMap.empty anchorA).isNone = true := by
  native_decide

/-- OpeningSupport and CurrentQuantityAnchor cannot claim one coordinate together. -/
theorem opening_anchor_overlap_is_rejected :
    (SupportEvidence.ofParts? ZeroOriginCoverage.empty openingB anchorB).isNone = true := by
  native_decide

/--
The aggregate proves only cross-family separation. It does not prove that an
OpeningSupport Event survives the current correction frontier, nor that an
anchor's reflected roots are valid in the current Actual world.

Those obligations remain intentionally world-relative and must stay with the
production consumers that own them.
-/

end Loam.Observation270
