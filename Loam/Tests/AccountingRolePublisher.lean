import Loam.Tests.ActualWorldFixture
import Loam.MovementWorldLoader
import Loam.Publisher.AccountingRolePublisher
import Loam.Authority.CurrentSupportAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Authority.AccountingRoleAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Persistence.HouseholdImagePersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.ScheduledLifecyclePersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=
  [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofQuantity ⟨"effect-2"⟩ ⟨toLocus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def world : IO Loam.MovementAdmission.World := do
  let some event := Event.ofEffects? ⟨"event-1"⟩ (effects "actual-used" "cash" 100)
    | throw (IO.userError "Actual Event fixture")
  let some events := EventMemory.ofEvents? [event]
    | throw (IO.userError "EventMemory fixture")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"fresh"⟩, ⟨"actual-used"⟩, ⟨"scheduled-used"⟩, ⟨"anchor-used"⟩,
       ⟨"assigned"⟩, ⟨"cash"⟩]
    | throw (IO.userError "Locus admission fixture")
  return {
    events := events
    validity := {
      facts := [.base ⟨"event-1"⟩ "2026-09-01"]
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def scheduledMemory : IO (ScheduledMemory String) := do
  let changes : List (MovementChange LocusId) :=
    [ { coordinate := ⟨"scheduled-used"⟩, quantity := Quantity.ofQuanta (-200) }
    , { coordinate := ⟨"cash"⟩, quantity := Quantity.ofQuanta 200 } ]
  let some movement := BalancedMovement.ofChanges? ⟨"jpy"⟩ changes
    | throw (IO.userError "Scheduled movement fixture")
  let occurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-1"⟩
    scheduledOn := "2026-09-10"
    movement := movement }
  let some scheduled := ScheduledMemory.ofOccurrences? [occurrence]
    | throw (IO.userError "ScheduledMemory fixture")
  return scheduled

private def lifecycle : IO Loam.Persistence.ScheduledLifecycleImage := do
  let scheduled ← scheduledMemory
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "terminal fixture")
  return { scheduled, terminals }

private def roleMap : IO AccountingRoleMap := do
  let some roles := AccountingRoleMap.ofAssignments?
      [{ locus := ⟨"assigned"⟩, role := .asset }, { locus := ⟨"cash"⟩, role := .asset }]
    | throw (IO.userError "AccountingRole fixture")
  return roles

private def anchorEvidence : IO Loam.CurrentQuantityAnchor.Evidence := do
  let assertion : Loam.CurrentQuantityAnchor.Assertion := {
    coordinate := ⟨⟨"anchor-used"⟩, ⟨"jpy"⟩⟩
    quantity := Quantity.ofQuanta 750
  }
  let some anchor := Loam.CurrentQuantityAnchor.Evidence.ofLists? [] [assertion]
    | throw (IO.userError "current quantity anchor fixture")
  return anchor

private def hasRole
    (roles : AccountingRoleMap) (locus : String) (role : AccountingRole) : Bool :=
  roles.roleOf? ⟨locus⟩ == some role

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let root := dataDir
  let scheduledFile := dataDir / "scheduled.loam"
  let roleFile := dataDir / "accounting-role.loam"

  let w ← world
  let scheduled ← scheduledMemory
  let roles ← roleMap
  let anchor ← anchorEvidence
  let emptyAnchor := Loam.CurrentQuantityAnchor.Evidence.empty

  let missingRoleRoot := dataDir / "missing-role"
  IO.FS.createDirAll missingRoleRoot
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? missingRoleRoot w
    | throw (IO.userError "publish missing-role Household fixture")
  expect (!(← Loam.AccountingRoleAuthority.loadHouseholdCurrent? missingRoleRoot).isOk)
    "missing Household AccountingRole section was treated as empty"

  let malformedRoleRoot := dataDir / "malformed-role"
  IO.FS.createDirAll malformedRoleRoot
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? malformedRoleRoot w
    | throw (IO.userError "publish malformed-role Household fixture")
  let malformedGeneration ←
    match ← Loam.HouseholdAuthority.loadCurrent? malformedRoleRoot with
    | .ok generation => pure generation
    | .error message => throw (IO.userError message)
  let some malformedImage :=
      Loam.Persistence.HouseholdImage.appendSection?
        malformedGeneration.image
        { name := "AccountingRole", body := "not-accounting-role-evidence\n" }
    | throw (IO.userError "append malformed AccountingRole fixture")
  let some malformedWire := Loam.Persistence.HouseholdImage.encode? malformedImage
    | throw (IO.userError "encode malformed AccountingRole fixture")
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedRoleRoot) malformedWire
  expect (!(← Loam.AccountingRoleAuthority.loadHouseholdCurrent? malformedRoleRoot).isOk)
    "malformed present Household AccountingRole section did not fail closed"

  let .ok proposed := Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled emptyAnchor roles
      { locus := ⟨"fresh"⟩, role := .expense }
    | throw (IO.userError "virgin admitted Locus role assignment was rejected")
  expect (hasRole proposed "fresh" .expense)
    "proposal did not retain first role assignment"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled emptyAnchor roles
      { locus := ⟨"assigned"⟩, role := .expense }).isOk)
    "existing AccountingRole was replaceable"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled emptyAnchor roles
      { locus := ⟨"unknown"⟩, role := .expense }).isOk)
    "non-admitted Locus received AccountingRole"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled emptyAnchor roles
      { locus := ⟨"actual-used"⟩, role := .expense }).isOk)
    "Actual-used unresolved Locus received retroactive AccountingRole"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled emptyAnchor roles
      { locus := ⟨"scheduled-used"⟩, role := .expense }).isOk)
    "Scheduled-used unresolved Locus received retroactive AccountingRole"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled anchor roles
      { locus := ⟨"anchor-used"⟩, role := .expense }).isOk)
    "current-anchor-backed unresolved Locus received retroactive AccountingRole"

  let candidates := Loam.AccountingRolePublisher.eligibleInitialLoci
    w.locusAdmission w.events scheduled anchor roles
  expect (candidates.contains ⟨"fresh"⟩)
    "virgin Locus disappeared from initial AccountingRole candidates"
  expect (!candidates.contains ⟨"anchor-used"⟩)
    "current-anchor-backed Locus remained an initial AccountingRole candidate"

  let encoded ←
    match Loam.Persistence.encodeAccountingRoleMap? proposed with
    | some text => pure text
    | none => throw (IO.userError "representable AccountingRole map did not encode")
  let some decoded := Loam.Persistence.decodeAccountingRoleMap? encoded
    | throw (IO.userError "encoded AccountingRole map did not decode")
  expect (hasRole decoded "fresh" .expense && hasRole decoded "assigned" .asset)
    "AccountingRole persistence round-trip lost assignments"

  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root w
    | throw (IO.userError "publish Actual authority fixture")
  let lifecycle0 ← lifecycle
  let lifecycleBody ←
    match Loam.Persistence.encodeScheduledLifecycleImage? lifecycle0 with
    | some body => pure body
    | none => throw (IO.userError "encode Household Scheduled lifecycle fixture")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "Scheduled" lifecycleBody
    | throw (IO.userError "publish Household Scheduled lifecycle fixture")
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle0)
    "publish frozen legacy Scheduled lifecycle fixture"
  let frozenLegacyScheduled ← IO.FS.readFile scheduledFile
  let roleBody ←
    match Loam.Persistence.encodeAccountingRoleMap? roles with
    | some body => pure body
    | none => throw (IO.userError "encode Household AccountingRole fixture")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "AccountingRole" roleBody
    | throw (IO.userError "publish Household AccountingRole fixture")

  let staleObserved ←
    match ← Loam.AccountingRoleAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => throw (IO.userError message)
  let anchorBody ←
    match Loam.Persistence.encodeCurrentQuantityAnchor? anchor with
    | some body => pure body
    | none => throw (IO.userError "encode Household current quantity anchor fixture")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishHouseholdSection?
      root "CurrentQuantityAnchor" anchorBody
    | throw (IO.userError "publish Household current quantity anchor fixture")

  expect (!(← Loam.AccountingRoleAuthority.publishObserved?
      root staleObserved proposed).isOk)
    "stale Household AccountingRole generation was accepted"
  let afterStaleRefusal ←
    match ← Loam.AccountingRoleAuthority.loadHouseholdCurrent? root with
    | .ok roles => pure roles
    | .error message => throw (IO.userError message)
  expect ((afterStaleRefusal.roleOf? ⟨"fresh"⟩).isNone)
    "stale AccountingRole publication changed current Household evidence"
  let staleAnchor ←
    match Loam.CurrentQuantityAnchor.Evidence.ofLists? [] [{
      coordinate := ⟨⟨"legacy-only"⟩, ⟨"jpy"⟩⟩
      quantity := Quantity.ofQuanta 1
    }] with
    | some evidence => pure evidence
    | none => throw (IO.userError "stale legacy current quantity anchor fixture")
  expect
    (← Loam.Persistence.saveCurrentQuantityAnchor?
      (Loam.HouseholdPaths.currentQuantityAnchor root) staleAnchor)
    "publish stale legacy current quantity anchor fixture"
  let frozenLegacyAnchor ←
    IO.FS.readFile (Loam.HouseholdPaths.currentQuantityAnchor root)

  let some staleLegacyRoles := AccountingRoleMap.ofAssignments?
      (roles.assignments ++ [{ locus := ⟨"fresh"⟩, role := .income }])
    | throw (IO.userError "stale legacy AccountingRole fixture")
  expect (← Loam.Persistence.saveAccountingRoleMap? roleFile staleLegacyRoles)
    "publish stale legacy AccountingRole fixture"
  let frozenLegacyRole ← IO.FS.readFile roleFile

  let generationWithRole ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => throw (IO.userError message)
  let some withUnknown :=
      Loam.Persistence.HouseholdImage.appendSection?
        generationWithRole.image { name := "FutureEvidence", body := "opaque-future-section\n" }
    | throw (IO.userError "append unknown Household section fixture")
  let some withUnknownWire := Loam.Persistence.HouseholdImage.encode? withUnknown
    | throw (IO.userError "encode unknown Household section fixture")
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) withUnknownWire

  let .ok () ← Loam.AccountingRolePublisher.publishInitialRoleHousehold
      root { locus := ⟨"fresh"⟩, role := .expense }
    | throw (IO.userError "publish virgin Locus AccountingRole")

  let loadedRoles ←
    match ← Loam.AccountingRoleAuthority.loadHouseholdCurrent? root with
    | .ok roles => pure roles
    | .error message => throw (IO.userError message)
  expect (hasRole loadedRoles "fresh" .expense)
    "published AccountingRole was not retained"
  expect ((← IO.FS.readFile roleFile) == frozenLegacyRole)
    "production AccountingRole publication changed frozen legacy authority"
  let currentGeneration ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => throw (IO.userError message)
  expect
    (Loam.Persistence.HouseholdImage.body?
      currentGeneration.image "FutureEvidence" == some "opaque-future-section\n")
    "AccountingRole publication did not preserve unknown Household section"

  let previousWire ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath root)
  let some previousImage := Loam.Persistence.HouseholdImage.decode? previousWire
    | throw (IO.userError "decode previous Household generation")
  let some previousRoleBody :=
      Loam.Persistence.HouseholdImage.body? previousImage "AccountingRole"
    | throw (IO.userError "previous Household generation lost AccountingRole")
  let some previousRoles := Loam.Persistence.decodeAccountingRoleMap? previousRoleBody
    | throw (IO.userError "decode previous Household AccountingRole")
  expect ((previousRoles.roleOf? ⟨"fresh"⟩).isNone)
    ".prev did not retain the pre-publication AccountingRole generation"
  expect (!(← Loam.AccountingRolePublisher.publishInitialRoleHousehold
      root { locus := ⟨"fresh"⟩, role := .income }).isOk)
    "publisher allowed role replacement after first assignment"
  expect (!(← Loam.AccountingRolePublisher.publishInitialRoleHousehold
      root { locus := ⟨"anchor-used"⟩, role := .expense }).isOk)
    "publisher classified retained current-anchor quantity retroactively"

  let rolesAfterAnchorRefusal ←
    match ← Loam.AccountingRoleAuthority.loadHouseholdCurrent? root with
    | .ok roles => pure roles
    | .error message => throw (IO.userError message)
  expect ((rolesAfterAnchorRefusal.roleOf? ⟨"anchor-used"⟩).isNone)
    "anchor-backed refusal changed AccountingRole authority"
  let currentSupportAfter ←
    match ← Loam.CurrentSupportAuthority.loadHousehold? root with
    | .ok observed => pure observed.snapshot
    | .error message => throw (IO.userError message)
  expect (decide (currentSupportAfter.anchor = anchor))
    "AccountingRole refusal changed Household current quantity anchor evidence"
  expect
    ((← IO.FS.readFile (Loam.HouseholdPaths.currentQuantityAnchor root)) ==
      frozenLegacyAnchor)
    "AccountingRole publication changed frozen legacy current quantity anchor evidence"

  let .ok loadedWorld ← Loam.MovementWorldLoader.loadSelectedWorld? root
    | throw (IO.userError "reload Movement authority")
  expect (loadedWorld.events.events.map (fun e => e.id) ==
      w.events.events.map (fun e => e.id))
    "AccountingRole publication changed retained Actual Event evidence"
  let loadedLifecycle ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root with
    | .ok lifecycle => pure lifecycle
    | .error message => throw (IO.userError message)
  expect (loadedLifecycle.scheduled.occurrences.length == lifecycle0.scheduled.occurrences.length)
    "AccountingRole publication changed retained Household Scheduled evidence"
  expect ((← IO.FS.readFile scheduledFile) == frozenLegacyScheduled)
    "AccountingRole publication changed frozen legacy Scheduled evidence"

  IO.println "AccountingRole publisher: virgin-Locus first assignment, Actual/Scheduled/current-anchor retroactive refusal, persistence round-trip and authority isolation passed."
