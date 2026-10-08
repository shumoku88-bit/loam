import Loam.Tests.ActualWorldFixture
import Loam.Publisher.ScheduledReplacementPublisher
import Loam.Publisher.ScheduledTerminalPublisher
import Loam.Review.ScheduledReview
import Loam.Application.ScheduledCommitmentInspection

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireOk {α : Type} (result : Except String α) : IO α :=
  match result with
  | .ok value => pure value
  | .error message => throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

private def change (locus : String) (amount : Int) : MovementChange LocusId :=
  { coordinate := ⟨locus⟩, quantity := Quantity.ofQuanta amount }

private def occurrence (id date : String) (amount : Int) (measure : String := "jpy") : IO (ScheduledOccurrence String) := do
  let movement ← requireSome
    (BalancedMovement.ofChanges? ⟨measure⟩ [change "bank" (-amount), change "wifi" amount]) "movement"
  return { id := ⟨id⟩, scheduledOn := date, movement }

private def revised (source : ScheduledOccurrence String) (amount : Int) :
    IO Loam.ScheduledReplacementPublisher.Draft := do
  let movement ← requireSome
    (BalancedMovement.ofChanges? source.measure [change "bank" (-amount), change "wifi" amount]) "revised movement"
  return { source := source.id, scheduledOn := source.scheduledOn, movement }

private def routingSubject (id : ScheduledId) : ScheduledRoutingSubject :=
  { scheduled := id, locus := ⟨"wifi"⟩ }

private def publishSection (root : System.FilePath) (name body : String) : IO Unit := do
  let _ ← requireOk (← Loam.Tests.ActualWorldFixture.publishHouseholdSection? root name body)
  pure ()

private def load (root : System.FilePath) : IO Loam.ScheduledLifecycleAuthority.Observed := do
  requireOk (← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? root)

private def assertRefused
    (root : System.FilePath) (wire : String)
    (drafts : List Loam.ScheduledReplacementPublisher.Draft) : IO Unit := do
  let before ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  let result ← Loam.ScheduledReplacementPublisher.publishHouseholdBatch root { observedWire := wire, drafts }
  expect (!result.isOk) "invalid batch was admitted"
  expect ((← IO.FS.readFile (Loam.HouseholdAuthority.path root)) == before) "refused batch partially changed household bytes"

private def successor
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage) (source : ScheduledId) :
    IO (ScheduledOccurrence String) := do
  let id ← requireSome (lifecycle.terminals.replacementFor? source) "replacement endpoint"
  requireSome (lifecycle.scheduled.findById? id) "successor occurrence"

def main (args : List String) : IO Unit := do
  let (path, setupOnly) ←
    match args with
    | [path] => pure (path, false)
    | ["setup", path] => pure (path, true)
    | _ => throw (IO.userError "supply isolated test directory (optional setup prefix)")
  let root := System.FilePath.mk path
  IO.FS.createDirAll root
  let _ ← requireOk (← Loam.HouseholdAuthority.installInitial? root {
    sections := [{ name := "CustomEvidence", body := "preserve these opaque bytes\n" }] })
  let events ← requireSome (EventMemory.ofEvents? []) "events"
  let vocabulary ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [⟨"bank"⟩, ⟨"wifi"⟩]) "vocabulary"
  let world : Loam.MovementAdmission.World := {
    events
    validity := { facts := [], factRefNodup := by simp, corrections := [], correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary
  }
  let _ ← requireOk (← Loam.Tests.ActualWorldFixture.publishWorld? root world)
  let first ← occurrence "first" "2026-11-08" 4800
  let second ← occurrence "second" "2026-12-08" 4800
  let exception ← occurrence "exception" "2027-01-08" 6000
  let paid ← occurrence "paid" "2026-10-08" 4800
  let cancelled ← occurrence "cancelled" "2026-11-09" 4800
  let foreign ← occurrence "foreign" "2026-12-09" 4800 "usd"
  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [first, second, exception, paid, cancelled, foreign]) "scheduled"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? []) "terminals"
  let body ← requireSome
    (Loam.Persistence.encodeScheduledLifecycleImage? { scheduled, terminals }) "Scheduled encoding"
  publishSection root "Scheduled" body
  let history ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := routingSubject first.id, effectiveOn := "2026-01-01", purpose := some ⟨"internet"⟩ },
       { subject := routingSubject first.id, effectiveOn := "2026-12-01", purpose := none },
       { subject := routingSubject second.id, effectiveOn := "2026-01-01", purpose := none }]) "history"
  let routingBody ← requireSome (Loam.Persistence.encodeScheduledRoutingHistory? history) "routing encoding"
  publishSection root "ScheduledRouting" routingBody

  let effects := paid.movement.changes.map fun item =>
    Effect.ofAnonymousQuantity item.coordinate paid.measure item.quantity
  let _ ← requireOk (← Loam.ScheduledTerminalPublisher.publishHouseholdCompletion root {
    scheduled := paid.id
    movement := {
      validOn := "2026-10-08"
      description := some "paid Wi-Fi"
      effects := effects
      relations := []
      discharges := []
      total := 4800 }
  })
  let _ ← requireOk (← Loam.ScheduledTerminalPublisher.publishHouseholdCancellation root {
    scheduled := cancelled.id })
  if setupOnly then return
  let observed ← load root
  let one ← revised first 5200
  let two ← revised second 5200
  let paidDraft ← revised paid 5200
  let cancelledDraft ← revised cancelled 5200
  assertRefused root observed.generation.wire []
  assertRefused root observed.generation.wire [one, one]
  assertRefused root observed.generation.wire [one, paidDraft]
  assertRefused root observed.generation.wire [one, cancelledDraft]
  assertRefused root observed.generation.wire [one, { two with source := ⟨"missing"⟩ }]
  assertRefused root observed.generation.wire [one, { two with scheduledOn := "2026-02-29" }]
  let unapproved ← requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩ [change "bank" (-5200), change "unknown" 5200]) "unapproved balanced draft"
  assertRefused root observed.generation.wire [one, { two with movement := unapproved }]
  let zero ← requireSome (BalancedMovement.ofChanges? ⟨"jpy"⟩ []) "zero movement"
  assertRefused root observed.generation.wire [one, { two with movement := zero }]

  -- An unrelated change still makes the exact reviewed sheet stale.
  let widerVocabulary ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [⟨"bank"⟩, ⟨"wifi"⟩, ⟨"other"⟩]) "wider vocabulary"
  let widerBody ← requireSome (Loam.Persistence.encodeLocusAdmissionVocabulary? widerVocabulary) "wider vocabulary encoding"
  publishSection root "LocusAdmission" widerBody
  assertRefused root observed.generation.wire [one, two]
  let beforeReserved ← load root
  let reservedId := Loam.ScheduledOccurrenceConstruction.freshId beforeReserved.lifecycle.scheduled
  let reservedHistory ← requireSome (history.add? {
    subject := routingSubject reservedId
    effectiveOn := "2026-04-01"
    purpose := some ⟨"unrelated"⟩ }) "reserved route fixture"
  let reservedBody ← requireSome (Loam.Persistence.encodeScheduledRoutingHistory? reservedHistory) "reserved route encoding"
  publishSection root "ScheduledRouting" reservedBody
  assertRefused root (← load root).generation.wire [one, two]
  publishSection root "ScheduledRouting" routingBody
  let fresh ← load root
  let batch : Loam.ScheduledReplacementPublisher.BatchDraft := {
    observedWire := fresh.generation.wire, drafts := [one, two] }
  let _ ← requireOk (← Loam.ScheduledReplacementPublisher.publishHouseholdBatch root batch)
  let after ← load root
  expect (after.lifecycle.scheduled.occurrences.length == 8) "batch did not append exactly two successors"
  expect (after.lifecycle.terminals.terminals.length == 4) "batch lost or duplicated terminal relations"
  for part in fresh.generation.image.sections do
    if part.name != "Scheduled" && part.name != "ScheduledRouting" then
      expect (Loam.Persistence.HouseholdImage.body? after.generation.image part.name == some part.body)
        ("batch changed unrelated authority: " ++ part.name)
  expect ((after.lifecycle.scheduled.findById? first.id).map (·.movement.changes) == some first.movement.changes)
    "batch rewrote original Scheduled provenance"
  let newFirst ← successor after.lifecycle first.id
  let newSecond ← successor after.lifecycle second.id
  expect (newFirst.id != newSecond.id && newFirst.scheduledOn == first.scheduledOn &&
    newSecond.scheduledOn == second.scheduledOn) "successors did not retain dates/fresh distinct IDs"
  expect ((newFirst.quantityAt ⟨"wifi"⟩).quanta == 5200 &&
    (newSecond.quantityAt ⟨"bank"⟩).quanta == -5200) "batch amount/balance changed"
  let snapshot ← requireOk (← Loam.ScheduledReview.loadHouseholdEvidence root root)
  let openRecords ← requireOk (Loam.ScheduledReview.currentOpenRecords snapshot)
  expect (openRecords.map (·.id) |>.contains exception.id) "unchecked exception disappeared"
  expect (!(openRecords.map (·.id)).contains paid.id && !(openRecords.map (·.id)).contains first.id)
    "paid/replaced sources stayed current-open"
  let nextRoutingBody ← requireSome
    (Loam.Persistence.HouseholdImage.body? after.generation.image "ScheduledRouting") "routing section"
  let nextHistory ← requireSome (Loam.Persistence.decodeScheduledRoutingHistory? nextRoutingBody) "routing decode"
  expect (nextHistory.entries.length == 6 && nextHistory.entries.take 3 == history.entries)
    "routing provenance was lost or duplicated"
  for date in ["2025-12-31", "2026-11-01", "2026-12-01", "2027-01-01"] do
    expect (nextHistory.statusAt (routingSubject newFirst.id) date == history.statusAt (routingSubject first.id) date)
      "replacement changed dated routing status"
    expect (nextHistory.statusAt (routingSubject newSecond.id) date == history.statusAt (routingSubject second.id) date)
      "replacement lost explicitly unmanaged routing"
  let roles ← requireSome
    (AccountingRoleMap.ofAssignments? [{ locus := ⟨"bank"⟩, role := .asset },
      { locus := ⟨"wifi"⟩, role := .expense }]) "roles"
  let pressure ← requireSome (Loam.Application.currentScheduledCommitment?
    after.lifecycle.scheduled after.lifecycle.terminals snapshot.events roles nextHistory
    ⟨"internet"⟩ ⟨"jpy"⟩ "2026-10-08" "2027-01-01") "Budget pressure"
  expect (pressure.managed.quanta == 5200 && pressure.unmanaged.quanta == 5200 && pressure.unrouted.quanta == 0)
    "batch amount edit changed routing partition or double-counted old pressure"
  -- Same preview cannot be replayed; a newly observed batch cannot replace old sources either.
  assertRefused root batch.observedWire batch.drafts
  assertRefused root after.generation.wire batch.drafts

  -- The shared batch writer is not a Wi-Fi or single-pair amount mechanism:
  -- explicit split movements and non-JPY replacements are ordinary balanced drafts.
  let splitMovement ← requireSome (BalancedMovement.ofChanges? ⟨"jpy"⟩
    [change "bank" (-7000), change "wifi" 6000, change "other" 1000]) "explicit split replacement"
  let foreignDraft ← revised foreign 5250
  let genericDraft : Loam.ScheduledReplacementPublisher.Draft := {
    source := exception.id, scheduledOn := exception.scheduledOn, movement := splitMovement }
  let _ ← requireOk (← Loam.ScheduledReplacementPublisher.publishHouseholdBatch root {
    observedWire := after.generation.wire, drafts := [genericDraft, foreignDraft] })
  let generic ← load root
  let newException ← successor generic.lifecycle exception.id
  let newForeign ← successor generic.lifecycle foreign.id
  expect (newException.movement.changes == splitMovement.changes && newForeign.measure == ⟨"usd"⟩ &&
    (newForeign.quantityAt ⟨"wifi"⟩).quanta == 5250) "generic batch lost split or Measure meaning"
  expect (Loam.Persistence.HouseholdImage.body? generic.generation.image "ScheduledRouting" == some nextRoutingBody)
    "generic batch manufactured routing for previously unrouted occurrences"

  -- Missing and malformed routing refuse before ANY part of a batch is installed.
  let third ← revised newException 8000
  let valid ← load root
  let malformed ← requireSome (Loam.Persistence.HouseholdImage.replaceBody?
    valid.generation.image "ScheduledRouting" "malformed\n") "malformed fixture"
  let malformedWire ← requireSome (Loam.Persistence.HouseholdImage.encode? malformed) "malformed outer wire"
  -- Deliberate corruption of isolated fixture bytes, not a production publication.
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) malformedWire
  assertRefused root malformedWire [third]
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) valid.generation.wire
  let current ← load root
  let noRouting : Loam.Persistence.HouseholdImage.Image := {
    sections := current.generation.image.sections.filter (·.name != "ScheduledRouting") }
  let _ ← requireOk (← Loam.HouseholdAuthority.publishObserved?
    root current.generation.wire ["ScheduledRouting"] noRouting)
  assertRefused root (← load root).generation.wire [third]

  IO.println "Scheduled batch replacement: atomic refusal/publication, stale review, paid history, exception preservation, dated routing and Budget pressure passed."
