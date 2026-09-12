import Loam.ActualAuthority
import Loam.AccountingRolePublisher
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
      [⟨"fresh"⟩, ⟨"actual-used"⟩, ⟨"scheduled-used"⟩, ⟨"assigned"⟩, ⟨"cash"⟩]
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

  let .ok (proposed, receipt) := Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled roles { locus := ⟨"fresh"⟩, role := .expense }
    | throw (IO.userError "virgin admitted Locus role assignment was rejected")
  expect (hasRole proposed "fresh" .expense)
    "proposal did not retain first role assignment"
  expect (receipt.previousCount == 2 && receipt.currentCount == 3)
    "proposal receipt does not describe one additive assignment"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled roles { locus := ⟨"assigned"⟩, role := .expense }).isOk)
    "existing AccountingRole was replaceable"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled roles { locus := ⟨"unknown"⟩, role := .expense }).isOk)
    "non-admitted Locus received AccountingRole"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled roles { locus := ⟨"actual-used"⟩, role := .expense }).isOk)
    "Actual-used unresolved Locus received retroactive AccountingRole"
  expect (!(Loam.AccountingRolePublisher.propose?
      w.locusAdmission w.events scheduled roles { locus := ⟨"scheduled-used"⟩, role := .expense }).isOk)
    "Scheduled-used unresolved Locus received retroactive AccountingRole"

  let encoded ←
    match Loam.Persistence.encodeAccountingRoleMap? proposed with
    | some text => pure text
    | none => throw (IO.userError "representable AccountingRole map did not encode")
  let some decoded := Loam.Persistence.decodeAccountingRoleMap? encoded
    | throw (IO.userError "encoded AccountingRole map did not decode")
  expect (hasRole decoded "fresh" .expense && hasRole decoded "assigned" .asset)
    "AccountingRole persistence round-trip lost assignments"

  let .ok _ ← Loam.ActualAuthority.publishWorld? root w
    | throw (IO.userError "publish Movement manifest fixture")
  let lifecycle0 ← lifecycle
  expect (← Loam.Persistence.saveScheduledLifecycleImage? scheduledFile lifecycle0)
    "publish Scheduled lifecycle fixture"
  expect (← Loam.Persistence.saveAccountingRoleMap? roleFile roles)
    "publish AccountingRole fixture"

  let .ok published ← Loam.AccountingRolePublisher.publishInitialRole
      scheduledFile.toString root.toString roleFile.toString
      { locus := ⟨"fresh"⟩, role := .expense }
    | throw (IO.userError "publish virgin Locus AccountingRole")
  expect (published.currentCount == 3)
    "publisher receipt count mismatch"

  let some loadedRoles ← Loam.Persistence.loadAccountingRoleMap? roleFile
    | throw (IO.userError "reload AccountingRole authority")
  expect (hasRole loadedRoles "fresh" .expense)
    "published AccountingRole was not retained"
  expect (!(← Loam.AccountingRolePublisher.publishInitialRole
      scheduledFile.toString root.toString roleFile.toString
      { locus := ⟨"fresh"⟩, role := .income }).isOk)
    "publisher allowed role replacement after first assignment"

  let .ok loadedWorld ← Loam.ActualAuthority.loadSelectedWorld? root
    | throw (IO.userError "reload Movement authority")
  expect (loadedWorld.events.events.map (fun e => e.id) ==
      w.events.events.map (fun e => e.id))
    "AccountingRole publication changed retained Actual Event evidence"
  let some loadedLifecycle ← Loam.Persistence.loadScheduledLifecycleImage? scheduledFile
    | throw (IO.userError "reload Scheduled authority")
  expect (loadedLifecycle.scheduled.occurrences.length == lifecycle0.scheduled.occurrences.length)
    "AccountingRole publication changed retained Scheduled evidence"

  IO.println "AccountingRole publisher: virgin-Locus first assignment, retroactive refusal, persistence round-trip and authority isolation passed."
