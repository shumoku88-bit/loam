import Loam.MeasurePresentationAuthority
import Loam.CapacityAuthority
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Tests.ActualWorldFixture
import Loam.MovementPublisher
import Loam.MovementWorldAdapter
import Loam.LocusAdmissionAuthority

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type}
    (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type}
    (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error error => throw (IO.userError (message ++ ": " ++ error))

private def expectError {α : Type}
    (value : Except String α) (message : String) : IO Unit :=
  match value with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError message)

private def emptyWorld : IO Loam.MovementAdmission.World := do
  let vocabulary ←
    requireSome
      (LocusAdmissionVocabulary.ofLoci?
        [⟨"actual-source"⟩, ⟨"actual-destination"⟩])
      "Actual fixture Locus vocabulary"
  return {
    events := { events := [], idNodup := by simp }
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp
    }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary
  }

private def actualDraft
    (measureToken : String) : Loam.MovementAdmission.Draft := {
  validOn := "2026-09-24"
  description := none
  effects := [
    Effect.ofQuantity
      ⟨"scale-test-source"⟩ ⟨"actual-source"⟩ ⟨measureToken⟩
      (Quantity.ofQuanta (-100)),
    Effect.ofQuantity
      ⟨"scale-test-destination"⟩ ⟨"actual-destination"⟩ ⟨measureToken⟩
      (Quantity.ofQuanta 100)
  ]
  relations := []
  discharges := []
  total := 100
}

private def emptyScheduledImage : IO Loam.Persistence.ScheduledLifecycleImage := do
  let scheduled ←
    requireSome (ScheduledMemory.ofOccurrences? []) "empty Scheduled memory"
  let terminals ←
    requireSome (ScheduledTerminalMemory.ofTerminals? []) "empty Scheduled terminals"
  return { scheduled, terminals }

private def initBase (root : System.FilePath) : IO Unit := do
  IO.FS.createDirAll root
  let world ← emptyWorld
  requireOk (← Loam.Tests.ActualWorldFixture.publishWorld? root world)
    "initialize admitted Actual fixture"
  let scheduled ← emptyScheduledImage
  expect (← Loam.Persistence.saveScheduledLifecycleImage? (root / "scheduled.loam") scheduled)
    "initialize Scheduled"

private def writePresentation
    (root : System.FilePath)
    (metadata : List Loam.MeasurePresentation.Metadata) : IO Unit := do
  let path := Loam.MeasurePresentationAuthority.configPath root
  if let some parent := path.parent then
    IO.FS.createDirAll parent
  let text ← requireSome (Loam.MeasurePresentation.encode? metadata)
    "encode Measure presentation fixture"
  IO.FS.writeFile path text

private def publishActualMeasure
    (root : System.FilePath)
    (measureToken : String) : IO Unit := do
  requireOk
    (← Loam.MovementPublisher.publishDraft root.toString (actualDraft measureToken))
    "publish admitted Actual fixture"

private def publishScheduledMeasure
    (root : System.FilePath)
    (measureToken : String) : IO Unit := do
  let movement : BalancedMovement LocusId ←
    requireSome
      (BalancedMovement.ofChanges? ⟨measureToken⟩
        [ { coordinate := ⟨"scheduled-source"⟩, quantity := Quantity.ofQuanta (-100) }
        , { coordinate := ⟨"scheduled-destination"⟩, quantity := Quantity.ofQuanta 100 } ])
      "Scheduled balanced movement"
  let occurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-used"⟩
    scheduledOn := "2026-09-25"
    movement := movement
  }
  let scheduled ←
    requireSome (ScheduledMemory.ofOccurrences? [occurrence])
      "Scheduled used memory"
  let terminals ←
    requireSome (ScheduledTerminalMemory.ofTerminals? [])
      "Scheduled terminal memory"
  expect
    (← Loam.Persistence.saveScheduledLifecycleImage?
      (root / "scheduled.loam") { scheduled, terminals })
    "publish Scheduled fixture"

private def publishCapacityMeasure
    (root : System.FilePath)
    (measureToken : String) : IO Unit := do
  let balanced : BalancedMovement CapacityCoordinate ←
    requireSome
      (BalancedMovement.ofChanges? ⟨measureToken⟩
        [ { coordinate := .unallocated, quantity := Quantity.ofQuanta (-100) }
        , { coordinate := .purpose ⟨"capacity-purpose"⟩,
            quantity := Quantity.ofQuanta 100 } ])
      "Capacity balanced movement"
  let movement : CapacityMovement := {
    id := ⟨"capacity-used"⟩
    movement := balanced
  }
  let movements ←
    requireSome (CapacityMemory.ofMovements? [movement])
      "Capacity movement memory"
  let effective ←
    requireSome
      (CapacityEffectiveMemory.ofEntries?
        [{ movement := movement.id, effectiveOn := "2026-09-24" }])
      "Capacity effective memory"
  let image ←
    requireSome (Loam.CapacityEvidence.ofParts? movements effective)
      "Capacity complete image"
  requireOk (← Loam.CapacityAuthority.publishImage? (root / "capacity.loam") image)
    "publish Capacity fixture"

private def publishAnchorMeasure
    (root : System.FilePath)
    (measureToken : String) : IO Unit := do
  let anchor ←
    requireSome
      (Loam.CurrentQuantityAnchor.Evidence.ofLists? []
        [{ coordinate := ⟨⟨"anchor-locus"⟩, ⟨measureToken⟩⟩,
           quantity := Quantity.ofQuanta 100 }])
      "CurrentQuantityAnchor evidence"
  expect
    (← Loam.Persistence.saveCurrentQuantityAnchor?
      (root / "current-quantity-anchor.loam") anchor)
    "publish CurrentQuantityAnchor fixture"

private def loadScale
    (root : System.FilePath) (measureToken : String) : IO Nat := do
  let metadata ←
    requireOk (← Loam.MeasurePresentation.loadMetadata root)
      "load Measure presentation"
  return Loam.MeasurePresentation.scaleFor metadata ⟨measureToken⟩

private def sequentialQualification (base : System.FilePath) : IO Unit := do
  let root := base / "used-families"
  initBase root
  publishActualMeasure root "jpy"
  publishScheduledMeasure root "usd"
  publishCapacityMeasure root "cad"
  publishAnchorMeasure root "ils"
  writePresentation root
    [ { measure := ⟨"jpy"⟩, scale := 0 }
    , { measure := ⟨"usd"⟩, scale := 2 }
    , { measure := ⟨"cad"⟩, scale := 2 }
    , { measure := ⟨"ils"⟩, scale := 2 }
    , { measure := ⟨"eur"⟩, scale := 2 } ]

  requireOk
    (← Loam.MeasurePresentationAuthority.setScale root ⟨"eur"⟩ 3)
    "unused Measure scale change"
  expect ((← loadScale root "eur") == 3)
    "unused Measure scale change was not published"

  expectError
    (← Loam.MeasurePresentationAuthority.setScale root ⟨"jpy"⟩ 2)
    "used Actual Measure scale change was admitted"
  expectError
    (← Loam.MeasurePresentationAuthority.setScale root ⟨"usd"⟩ 3)
    "used Scheduled Measure scale change was admitted"
  expectError
    (← Loam.MeasurePresentationAuthority.setScale root ⟨"cad"⟩ 3)
    "used Capacity Measure scale change was admitted"
  expectError
    (← Loam.MeasurePresentationAuthority.setScale root ⟨"ils"⟩ 3)
    "used CurrentQuantityAnchor Measure scale change was admitted"

  let beforeNoOp ← IO.FS.readFile (Loam.MeasurePresentationAuthority.configPath root)
  requireOk
    (← Loam.MeasurePresentationAuthority.setScale root ⟨"jpy"⟩ 0)
    "same-scale used Measure no-op"
  let afterNoOp ← IO.FS.readFile (Loam.MeasurePresentationAuthority.configPath root)
  expect (beforeNoOp == afterNoOp)
    "same-scale used Measure no-op rewrote config"

  IO.FS.writeFile
    (Loam.MeasurePresentationAuthority.configPath root)
    "not-a-valid-measure-presentation\n"
  let malformedBefore ←
    IO.FS.readFile (Loam.MeasurePresentationAuthority.configPath root)
  expectError
    (← Loam.MeasurePresentationAuthority.setScale root ⟨"eur"⟩ 4)
    "malformed Measure config did not fail closed"
  let malformedAfter ←
    IO.FS.readFile (Loam.MeasurePresentationAuthority.configPath root)
  expect (malformedBefore == malformedAfter)
    "malformed config refusal changed authority bytes"

  let missingRoot := base / "missing-config"
  initBase missingRoot
  publishActualMeasure missingRoot "jpy"
  let missingPath := Loam.MeasurePresentationAuthority.configPath missingRoot
  expect (!(← missingPath.pathExists))
    "missing-config fixture unexpectedly has presentation config"
  expect ((← loadScale missingRoot "jpy") == 0)
    "missing config no longer preserves historical scale-0 compatibility"
  requireOk
    (← Loam.MeasurePresentationAuthority.setScale missingRoot ⟨"jpy"⟩ 0)
    "used scale-0 no-op with missing config"
  expect (!(← missingPath.pathExists))
    "scale-0 no-op manufactured a config file"
  expectError
    (← Loam.MeasurePresentationAuthority.setScale missingRoot ⟨"jpy"⟩ 2)
    "used Measure changed away from missing-config historical scale 0"

  IO.println
    "Measure scale administration: unused change, all retained authority families, no-op, malformed config, and missing-config compatibility passed."

private def raceSetup (root : System.FilePath) : IO Unit := do
  initBase root
  writePresentation root [{ measure := ⟨"usd"⟩, scale := 2 }]

private def raceFirstUse
    (root ready : System.FilePath) : IO Unit := do
  Loam.ActualAuthority.withActualOwnership root do
    let actual ←
      requireOk (← Loam.ActualAuthority.loadActual? root)
        "race load Actual"
    let locusAdmission ←
      requireOk (← Loam.LocusAdmissionAuthority.loadCurrent? root)
        "race load current Locus admission"
    let world := Loam.MovementWorldAdapter.ofActual actual locusAdmission
    let admitted ←
      requireOk
        (Loam.MovementAdmission.admit? world (actualDraft "usd"))
        "race admit first USD Movement"
    let updated : Loam.ActualEvidence := {
      actual with
      events := admitted.world.events
      validity := admitted.world.validity
      descriptions := admitted.world.descriptions
      relations := admitted.world.relations
      discharges := admitted.world.discharges
    }
    IO.FS.writeFile ready "actual-owned\n"
    IO.sleep 1200
    requireOk
      (← Loam.ActualAuthority.publishActual? root updated)
      "race publish first USD use"

private def raceCheck (root : System.FilePath) : IO Unit := do
  expect ((← loadScale root "usd") == 2)
    "concurrent first-use race changed used USD scale"
  let actual ←
    requireOk (← Loam.ActualAuthority.loadActual? root)
      "race final Actual"
  expect
    (actual.events.events.any fun event =>
      event.effects.any fun effect => effect.measure == (⟨"usd"⟩ : MeasureId))
    "race first-use writer did not retain USD quantity"
  IO.println
    "Measure scale administration: concurrent first-use publication serialized before scale re-read and the scale change was refused."

def main (args : List String) : IO Unit := do
  match args with
  | [baseText] =>
      sequentialQualification (System.FilePath.mk baseText)
  | ["race-setup", rootText] =>
      raceSetup (System.FilePath.mk rootText)
  | ["race-first-use", rootText, readyText] =>
      raceFirstUse (System.FilePath.mk rootText) (System.FilePath.mk readyText)
  | ["race-check", rootText] =>
      raceCheck (System.FilePath.mk rootText)
  | _ =>
      throw
        (IO.userError
          "usage: MeasureScaleAdministration ROOT | race-setup ROOT | race-first-use ROOT READY | race-check ROOT")
