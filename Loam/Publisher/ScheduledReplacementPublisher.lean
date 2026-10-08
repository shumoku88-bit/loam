import Loam.Authority.ActualAuthority
import Loam.ActualDate
import Loam.Core.ActualEvidence
import Loam.Application.ScheduledInspection
import Loam.Authority.LocusAdmissionAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Persistence.TokenSyntax
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Application.ScheduledOccurrenceConstruction
import Loam.Persistence.ScheduledRoutingPersistence

namespace Loam.ScheduledReplacementPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled replacement publication

This module exposes the surface-independent write boundary for Scheduled replacement.

Production publication reads Scheduled, Actual, and LocusAdmission from one
observed HouseholdImage generation. Single replacement preserves its Scheduled-only
contract. Reviewed batch replacement additionally preserves routing for retained
same-Measure positive Loci and publishes Scheduled + ScheduledRouting atomically.
Both entrances share the same pure source admission and replacement proposal.
-/

structure Draft where
  source : ScheduledId
  scheduledOn : String
  movement : BalancedMovement LocusId

private def currentOpen?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory) : Except String (List (ScheduledOccurrence String)) :=
  match Loam.Application.currentOpenScheduled
      lifecycle.scheduled lifecycle.terminals events with
  | .unknownCompletionScheduled =>
      .error "loam: Scheduled completion refers to an unknown Scheduled identity"
  | .unknownRetirementScheduled =>
      .error "loam: Scheduled retirement refers to an unknown Scheduled identity"
  | .unknownReplacementScheduled =>
      .error "loam: Scheduled replacement refers to an unknown Scheduled identity"
  | .invalidReplacementGraph =>
      .error "loam: Scheduled replacement graph is cyclic or otherwise invalid"
  | .conflictingTerminalEvidence =>
      .error "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement"
  | .open occurrences => .ok occurrences

private def containsScheduled
    (occurrences : List (ScheduledOccurrence String))
    (target : ScheduledId) : Bool :=
  occurrences.any fun occurrence => decide (occurrence.id = target)

private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw "loam: Scheduled replacement requires a valid ISO calendar date"
  if draft.movement.changes.isEmpty then
    throw "loam: Scheduled replacement requires at least one movement change"
  if !draft.movement.changes.all (fun change =>
      Loam.Persistence.validToken change.coordinate.token &&
      change.quantity.quanta != 0) then
    throw ("loam: Scheduled replacement requires valid Locus tokens and nonzero " ++
      draft.movement.measure.token ++ " quantities")

/-- A reviewed batch is bound to the exact household bytes used for its preview. -/
structure BatchDraft where
  observedWire : String
  drafts : List Draft

private structure Replacement where
  source : ScheduledOccurrence String
  successor : ScheduledOccurrence String

/-- Pure shared proposal: no source is changed until every draft has passed admission. -/
private def proposeBatch
    (observed : Loam.ScheduledLifecycleAuthority.Observed)
    (drafts : List Draft) :
    Except String (Loam.Persistence.ScheduledLifecycleImage × List Replacement) := do
  if drafts.isEmpty then
    throw "loam: select at least one Scheduled occurrence"
  if !(decide (drafts.map (·.source)).Nodup) then
    throw "loam: a Scheduled identity may be selected only once"
  let actualImage ← Loam.ActualAuthority.decodeHouseholdGeneration? observed.generation
  let some locusBody := Loam.Persistence.HouseholdImage.body?
      observed.generation.image "LocusAdmission"
    | throw "loam: required HouseholdImage Locus admission section is missing"
  let some locusAdmission := Loam.Persistence.decodeLocusAdmissionVocabulary? locusBody
    | throw "loam: malformed or unsupported HouseholdImage Locus admission authority"
  let openOccurrences ← currentOpen? observed.lifecycle actualImage.evidence.events
  let mut lifecycle := observed.lifecycle
  let mut replacements : List Replacement := []
  for draft in drafts do
    validateDraft draft
    if !draft.movement.changes.all (fun change => locusAdmission.allows change.coordinate) then
      throw "loam: Scheduled replacement uses a Locus not approved for new publication"
    let some source := ScheduledMemory.findById? observed.lifecycle.scheduled draft.source
      | throw "loam: selected Scheduled identity is not retained"
    if !containsScheduled openOccurrences draft.source then
      throw "loam: only a currently open Scheduled identity can be replaced"
    let successor : ScheduledOccurrence String := {
      id := Loam.ScheduledOccurrenceConstruction.freshId lifecycle.scheduled
      scheduledOn := draft.scheduledOn
      movement := draft.movement
    }
    let some scheduled := lifecycle.scheduled.add? successor
      | throw "loam: replacement identity is not fresh"
    let some terminals := lifecycle.terminals.add? {
        source := draft.source, target := some (.scheduled successor.id) }
      | throw "loam: replacement relation violates one-to-one endpoint ownership"
    lifecycle := { lifecycle with scheduled, terminals }
    replacements := replacements ++ [{ source := source, successor := successor }]
  let _ ← currentOpen? lifecycle actualImage.evidence.events
  return (lifecycle, replacements)

/--
Preserve dated routing assertions only for same-Measure positive Loci present on
both sides of a replacement. No latest-date default, guessed Purpose, or route
for a newly introduced Locus is manufactured. Original assertions remain history.
-/
private def inheritRouting
    (history : ScheduledRoutingHistory String)
    (replacements : List Replacement) : Except String (ScheduledRoutingHistory String) := do
  let mut updated := history
  for replacement in replacements do
    if history.entries.any (fun entry => entry.subject.scheduled == replacement.successor.id) then
      throw "loam: fresh replacement identity has pre-existing routing evidence"
    if replacement.source.measure == replacement.successor.measure then
      for entry in history.entries do
        if entry.subject.scheduled == replacement.source.id &&
            (replacement.source.quantityAt entry.subject.locus).quanta > 0 then
          if (replacement.successor.quantityAt entry.subject.locus).quanta > 0 then
            let some next := updated.add? { entry with
                subject := { entry.subject with scheduled := replacement.successor.id } }
              | throw "loam: inherited Scheduled routing coordinate conflicts"
            updated := next
  return updated

private def publishHouseholdFromGeneration
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let observed ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return .error message
  let (updatedLifecycle, _) ←
    match proposeBatch observed [draft] with
    | .ok proposal => pure proposal
    | .error message => return .error message
  match ← Loam.ScheduledLifecycleAuthority.publishObserved? root observed updatedLifecycle with
  | .ok _ => return .ok ()
  | .error message => return .error message

/--
Publish all reviewed replacements and inherited routing in one HouseholdImage
transition. Any refusal, including a stale preview, leaves every source untouched.
Unlike a loop of single publications, no intermediate batch state is installed.
-/
def publishHouseholdBatch
    (root : System.FilePath)
    (draft : BatchDraft) : IO (Except String Unit) := do
  if root.toString.isEmpty then
    return .error "loam: data directory must not be empty"
  let observed ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return .error message
  if observed.generation.wire != draft.observedWire then
    return .error "loam: household changed after review; reopen batch edit and review again"
  let proposal : Except String Loam.Persistence.HouseholdImage.Image := do
    let (lifecycle, replacements) ← proposeBatch observed draft.drafts
    let some routingBody := Loam.Persistence.HouseholdImage.body?
        observed.generation.image "ScheduledRouting"
      | throw "loam: required HouseholdImage Scheduled routing section is missing"
    let some history := Loam.Persistence.decodeScheduledRoutingHistory? routingBody
      | throw "loam: malformed or unsupported HouseholdImage Scheduled routing authority"
    let updatedRouting ← inheritRouting history replacements
    let some scheduledBody := Loam.Persistence.encodeScheduledLifecycleImage? lifecycle
      | throw "loam: proposed Scheduled lifecycle did not encode"
    let some updatedRoutingBody := Loam.Persistence.encodeScheduledRoutingHistory? updatedRouting
      | throw "loam: proposed Scheduled routing did not encode"
    let some image := Loam.Persistence.HouseholdImage.replaceBody?
        observed.generation.image "Scheduled" scheduledBody
      | throw "loam: required Scheduled section disappeared"
    let some candidate := Loam.Persistence.HouseholdImage.replaceBody?
        image "ScheduledRouting" updatedRoutingBody
      | throw "loam: required Scheduled routing section disappeared"
    return candidate
  let candidate ←
    match proposal with
    | .ok candidate => pure candidate
    | .error message => return .error message
  match ← Loam.HouseholdAuthority.publishObserved?
      root draft.observedWire ["Scheduled", "ScheduledRouting"] candidate with
  | .ok _ => return .ok ()
  | .error message => return .error message

/--
Publish one production household Scheduled replacement through HouseholdImage.
-/
def publishHousehold
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  if root.toString.isEmpty then
    return .error "loam: data directory must not be empty"
  publishHouseholdFromGeneration root draft



end Loam.ScheduledReplacementPublisher
