import Loam.Authority.CurrentSupportAuthority
import Loam.Authority.HouseholdAuthority
import Loam.HouseholdPaths
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.CurrentQuantityPresencePersistence
import Loam.Persistence.BoundedHistorySupportPersistence

namespace Loam.Tests.HouseholdCurrentSupportAuthority

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type}
    (value : Option α)
    (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α)
    (message : String) : IO α :=
  match value with
  | .ok value => pure value
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def coordinate (locus : String) : EffectCoordinate :=
  ⟨⟨locus⟩, ⟨"jpy"⟩⟩

private def anchor
    (locus : String)
    (quantity : Int) : IO Loam.CurrentQuantityAnchor.Evidence :=
  requireSome
    (Loam.CurrentQuantityAnchor.Evidence.ofLists? [] [{
      coordinate := coordinate locus
      quantity := Quantity.ofQuanta quantity
    }])
    ("anchor fixture: " ++ locus)

private def presence
    (locus : String) : IO Loam.CurrentQuantityPresence.Evidence :=
  requireSome
    (Loam.CurrentQuantityPresence.Evidence.ofLists? [] [coordinate locus])
    ("presence fixture: " ++ locus)

private def bounded
    (locus startDay : String) : IO Loam.BoundedHistorySupport.Evidence :=
  requireSome
    (Loam.BoundedHistorySupport.Evidence.ofSupports? [{
      coordinate := coordinate locus
      startDay := startDay
    }])
    ("bounded fixture: " ++ locus)

private def anchorBody
    (evidence : Loam.CurrentQuantityAnchor.Evidence) : IO String :=
  requireSome
    (encodeCurrentQuantityAnchor? evidence)
    "anchor fixture did not encode"

private def presenceBody
    (evidence : Loam.CurrentQuantityPresence.Evidence) : IO String :=
  requireSome
    (encodeCurrentQuantityPresence? evidence)
    "presence fixture did not encode"

private def boundedBody
    (evidence : Loam.BoundedHistorySupport.Evidence) : IO String :=
  requireSome
    (encodeBoundedHistorySupport? evidence)
    "bounded fixture did not encode"

private def expectSnapshotBodies
    (snapshot : Loam.CurrentSupportAuthority.Snapshot)
    (expectedAnchor expectedPresence expectedBounded : String)
    (message : String) : IO Unit := do
  expect ((← anchorBody snapshot.anchor) == expectedAnchor)
    (message ++ ": anchor changed")
  expect ((← presenceBody snapshot.presence) == expectedPresence)
    (message ++ ": presence changed")
  expect ((← boundedBody snapshot.bounded) == expectedBounded)
    (message ++ ": bounded support changed")

def main (args : List String) : IO Unit := do
  let [rootText] := args
    | throw (IO.userError "supply isolated Household current-support authority directory")
  let base := System.FilePath.mk rootText
  let legacyRoot := base / "legacy"
  let imageRoot := base / "image"
  let missingLegacyRoot := base / "missing-legacy"
  let missingImageRoot := base / "missing-image"
  let malformedImageRoot := base / "malformed-image"
  for root in [
      legacyRoot, imageRoot, missingLegacyRoot, missingImageRoot, malformedImageRoot] do
    IO.FS.createDirAll root

  let initialAnchor ← anchor "cash" 100
  let initialPresence ← presence "debt"
  let initialBounded ← bounded "cash" "2026-09-01"
  let initialAnchorBody ← anchorBody initialAnchor
  let initialPresenceBody ← presenceBody initialPresence
  let initialBoundedBody ← boundedBody initialBounded

  expect
    (← saveCurrentQuantityAnchor?
      (Loam.HouseholdPaths.currentQuantityAnchor legacyRoot) initialAnchor)
    "legacy anchor fixture did not save"
  expect
    (← saveCurrentQuantityPresence?
      (Loam.HouseholdPaths.currentQuantityPresence legacyRoot) initialPresence)
    "legacy presence fixture did not save"
  expect
    (← saveBoundedHistorySupport?
      (Loam.HouseholdPaths.boundedHistorySupport legacyRoot) initialBounded)
    "legacy bounded fixture did not save"

  let initialImage : Image := {
    sections := [
      { name := "CurrentQuantityAnchor", body := initialAnchorBody },
      { name := "CurrentQuantityPresence", body := initialPresenceBody },
      { name := "BoundedHistorySupport", body := initialBoundedBody },
      { name := "FutureEvidence", body := "FUTURE\t1\nopaque\n" }
    ]
  }
  let initialGeneration ← requireOk
    (← Loam.HouseholdAuthority.installInitial? imageRoot initialImage)
    "initial current-support HouseholdImage did not install"

  -- Stale valid standalone evidence may disagree beside HouseholdImage and must
  -- remain frozen throughout Household publication.
  let staleAnchor ← anchor "legacy-anchor" 999
  let stalePresence ← presence "legacy-presence"
  let staleBounded ← bounded "legacy-bounded" "2026-01-01"
  expect
    (← saveCurrentQuantityAnchor?
      (Loam.HouseholdPaths.currentQuantityAnchor imageRoot) staleAnchor)
    "stale legacy anchor did not save"
  expect
    (← saveCurrentQuantityPresence?
      (Loam.HouseholdPaths.currentQuantityPresence imageRoot) stalePresence)
    "stale legacy presence did not save"
  expect
    (← saveBoundedHistorySupport?
      (Loam.HouseholdPaths.boundedHistorySupport imageRoot) staleBounded)
    "stale legacy bounded support did not save"
  let frozenAnchor ←
    IO.FS.readFile (Loam.HouseholdPaths.currentQuantityAnchor imageRoot)
  let frozenPresence ←
    IO.FS.readFile (Loam.HouseholdPaths.currentQuantityPresence imageRoot)
  let frozenBounded ←
    IO.FS.readFile (Loam.HouseholdPaths.boundedHistorySupport imageRoot)

  let legacy ← requireOk
    (← Loam.CurrentSupportAuthority.loadLegacyOrEmpty? legacyRoot)
    "legacy current-support snapshot did not load"
  let observed ← requireOk
    (← Loam.CurrentSupportAuthority.loadHousehold? imageRoot)
    "Household current-support snapshot did not load"
  expectSnapshotBodies legacy
    initialAnchorBody initialPresenceBody initialBoundedBody
    "legacy current-support meaning"
  expectSnapshotBodies observed.snapshot
    initialAnchorBody initialPresenceBody initialBoundedBody
    "Household current-support meaning"

  -- Anchor and weaker presence change together in one Household generation.
  let nextAnchor ← anchor "cash" 120
  let nextPresence ← presence "wifi"
  let nextAnchorBody ← anchorBody nextAnchor
  let nextPresenceBody ← presenceBody nextPresence
  let published ← requireOk
    (← Loam.CurrentSupportAuthority.publishObserved?
      imageRoot observed {
        anchor := nextAnchor
        presence := nextPresence
        bounded := initialBounded
      })
    "atomic anchor/presence publication failed"

  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)) ==
      initialGeneration.wire)
    "multi-section publication did not preserve the exact previous generation"

  let afterPair ← requireOk
    (← Loam.CurrentSupportAuthority.loadHousehold? imageRoot)
    "current-support generation did not reload after pair publication"
  expectSnapshotBodies afterPair.snapshot
    nextAnchorBody nextPresenceBody initialBoundedBody
    "atomic anchor/presence publication"

  expect
    (body? published.image "FutureEvidence" == some "FUTURE\t1\nopaque\n")
    "multi-section publication changed unknown Household evidence"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.currentQuantityAnchor imageRoot)) ==
      frozenAnchor)
    "Household publication changed stale legacy anchor"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.currentQuantityPresence imageRoot)) ==
      frozenPresence)
    "Household publication changed stale legacy presence"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.boundedHistorySupport imageRoot)) ==
      frozenBounded)
    "Household publication changed stale legacy bounded support"

  -- An old observed generation cannot publish a later bounded-support change.
  let movedBounded ← bounded "cash" "2026-09-02"
  expect
    (!(← Loam.CurrentSupportAuthority.publishObserved?
      imageRoot observed {
        anchor := initialAnchor
        presence := initialPresence
        bounded := movedBounded
      }).isOk)
    "stale current-support generation was allowed to publish"

  -- A fresh observation may update bounded support alone without rewriting the
  -- other two support families.
  let beforeBoundedWire := afterPair.generation.wire
  let movedBoundedBody ← boundedBody movedBounded
  let afterBoundedGeneration ← requireOk
    (← Loam.CurrentSupportAuthority.publishObserved?
      imageRoot afterPair {
        anchor := afterPair.snapshot.anchor
        presence := afterPair.snapshot.presence
        bounded := movedBounded
      })
    "bounded-only Household publication failed"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)) ==
      beforeBoundedWire)
    "bounded-only publication did not rotate the exact prior Household generation"
  let afterBounded ← requireOk
    (← Loam.CurrentSupportAuthority.loadHousehold? imageRoot)
    "current-support generation did not reload after bounded publication"
  expectSnapshotBodies afterBounded.snapshot
    nextAnchorBody nextPresenceBody movedBoundedBody
    "bounded-only publication"
  expect
    (body? afterBoundedGeneration.image "FutureEvidence" ==
      some "FUTURE\t1\nopaque\n")
    "bounded-only publication changed unknown Household evidence"

  -- Semantic no-op does not manufacture a new generation.
  let previousBeforeNoop ←
    IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)
  let noop ← requireOk
    (← Loam.CurrentSupportAuthority.publishObserved?
      imageRoot afterBounded afterBounded.snapshot)
    "current-support no-op was refused"
  expect (noop.wire == afterBounded.generation.wire)
    "current-support no-op returned a different generation"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.previousPath imageRoot)) ==
      previousBeforeNoop)
    "current-support no-op rotated previous generation"

  -- Missing sections remain semantically empty and are not normalized into
  -- physical empty sections when an unrelated support family is published.
  let missingLegacy ← requireOk
    (← Loam.CurrentSupportAuthority.loadLegacyOrEmpty? missingLegacyRoot)
    "missing legacy current support did not load as empty"
  expect
    (missingLegacy.anchor.assertions.isEmpty &&
      missingLegacy.presence.coordinates.isEmpty &&
      missingLegacy.bounded.supports.isEmpty)
    "missing legacy current support did not preserve semantic empty"

  let _ ← requireOk
    (← Loam.HouseholdAuthority.installInitial? missingImageRoot {
      sections := [{ name := "FutureEvidence", body := "opaque\n" }]
    })
    "missing current-support HouseholdImage did not install"
  let missingObserved ← requireOk
    (← Loam.CurrentSupportAuthority.loadHousehold? missingImageRoot)
    "missing Household current support did not load as empty"
  expect
    (missingObserved.snapshot.anchor.assertions.isEmpty &&
      missingObserved.snapshot.presence.coordinates.isEmpty &&
      missingObserved.snapshot.bounded.supports.isEmpty)
    "missing Household current support did not preserve semantic empty"

  let firstAnchor ← anchor "first-anchor" 7
  let firstAnchorBody ← anchorBody firstAnchor
  let firstGeneration ← requireOk
    (← Loam.CurrentSupportAuthority.publishObserved?
      missingImageRoot missingObserved {
        anchor := firstAnchor
        presence := Loam.CurrentQuantityPresence.Evidence.empty
        bounded := Loam.BoundedHistorySupport.Evidence.empty
      })
    "first anchor publication into missing cluster failed"
  expect (body? firstGeneration.image "CurrentQuantityAnchor" == some firstAnchorBody)
    "first anchor section was not appended"
  expect ((body? firstGeneration.image "CurrentQuantityPresence").isNone)
    "missing empty presence was normalized into a physical section"
  expect ((body? firstGeneration.image "BoundedHistorySupport").isNone)
    "missing empty bounded support was normalized into a physical section"
  expect (body? firstGeneration.image "FutureEvidence" == some "opaque\n")
    "first cluster publication changed unknown evidence"

  -- A malformed present known section fails closed before cluster selection.
  let malformedWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? {
      sections := [{
        name := "CurrentQuantityAnchor"
        body := "not-current-anchor\n"
      }]
    })
    "malformed inner current-support HouseholdImage did not outer-encode"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedImageRoot) malformedWire
  expect
    (!(← Loam.CurrentSupportAuthority.loadHousehold? malformedImageRoot).isOk)
    "malformed Household current-support section did not fail closed"
  expect
    ((← IO.FS.readFile (Loam.HouseholdAuthority.path malformedImageRoot)) ==
      malformedWire)
    "failed current-support read changed malformed HouseholdImage"

  IO.println
    "Household current support authority: coherent optional reads, atomic multi-section publication, stale-generation refusal, no-op stability, missing-section preservation, stale-legacy isolation, unknown preservation, and malformed fail-closed passed."

end Loam.Tests.HouseholdCurrentSupportAuthority

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdCurrentSupportAuthority.main args
