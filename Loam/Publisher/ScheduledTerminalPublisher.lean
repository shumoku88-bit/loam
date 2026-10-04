import Loam.Authority.ActualAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Core.ActualEvidence
import Loam.Application.ScheduledInspection
import Loam.Authority.LocusAdmissionAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.Application.MovementAdmission
import Loam.Application.MovementWorldAdapter
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Application.SparseEffectIdentity

namespace Loam.ScheduledTerminalPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Shared Scheduled terminal publication

Production household completion reads Scheduled, Actual, and LocusAdmission from
one observed HouseholdImage generation and publishes the Scheduled terminal plus
its Actual endpoint in one Household generation update. The temporary Actual
serializer remains outside that publication so completion still coordinates with
Actual writers that have not yet been collapsed onto one-generation observation.

Production household retry continues to accept a previously retained interrupted
completion claim, so pre-cutover recovery evidence remains usable. Cancellation
changes only Scheduled evidence; it reads Scheduled and Actual from one observed
Household generation and relies on stale-generation refusal instead of the
temporary Actual serializer.
-/

structure CompletionDraft where
  scheduled : ScheduledId
  movement : Loam.MovementAdmission.Draft

structure CancellationDraft where
  scheduled : ScheduledId

private def completionEventId (scheduled : ScheduledId) : EventId :=
  ⟨"scheduled-completion:" ++ scheduled.token⟩

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

private def findOpen?
    (lifecycle : Loam.Persistence.ScheduledLifecycleImage)
    (events : EventMemory)
    (target : ScheduledId) : Except String (ScheduledOccurrence String) := do
  let occurrences ← currentOpen? lifecycle events
  match occurrences.find? fun occurrence => decide (occurrence.id = target) with
  | some occurrence => pure occurrence
  | none => throw "loam: selected Scheduled identity is no longer current-open"

private def appendCompletionActual?
    (world : Loam.MovementAdmission.World)
    (actualId : EventId)
    (rawDraft : Loam.MovementAdmission.Draft) :
    Except String Loam.MovementAdmission.World := do
  let effects := Loam.SparseEffectIdentity.canonicalizeEffects [] rawDraft.effects
  let draft := { rawDraft with effects := effects }
  Loam.MovementAdmission.validateDraft draft
  if !draft.relations.isEmpty || !draft.discharges.isEmpty then
    throw "loam: Scheduled completion currently admits plain Actual Movement effects only"
  if !world.locusAdmission.admitsEffects draft.effects then
    throw "loam: Scheduled completion uses a Locus not approved for new publication"
  let event ←
    match Event.ofEffects? actualId effects with
    | some event => pure event
    | none => throw "loam: Scheduled completion Effect identity is not unique"
  let fact : ActualValidityFact String :=
    .base actualId draft.validOn
  let events ←
    match EventMemory.add? world.events event with
    | some events => pure events
    | none => throw "loam: could not append Scheduled completion Actual Event"
  let validity ←
    match world.validity.addFact? fact with
    | some validity => pure validity
    | none => throw "loam: could not append Scheduled completion occurrence date"
  let descriptions ←
    match draft.description with
    | none => pure world.descriptions
    | some text =>
        match world.descriptions.add? { event := actualId, text := text } with
        | some descriptions => pure descriptions
        | none => throw "loam: could not append Scheduled completion description"
  pure {
    events := events
    validity := validity
    descriptions := descriptions
    relations := world.relations
    discharges := world.discharges
    locusAdmission := world.locusAdmission
  }

private def publishHouseholdCompletionUnderActualOwnership
    (root : System.FilePath)
    (draft : CompletionDraft) : IO (Except String Unit) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let actualImage ←
    match Loam.ActualAuthority.decodeHouseholdGeneration? generation with
    | .ok image => pure image
    | .error message => return .error message
  let evidence := actualImage.evidence
  let scheduledBody ←
    match Loam.Persistence.HouseholdImage.body? generation.image "Scheduled" with
    | some body => pure body
    | none =>
        return .error "loam: required HouseholdImage Scheduled lifecycle section is missing"
  let lifecycle ←
    match Loam.Persistence.decodeScheduledLifecycleImage? scheduledBody with
    | some lifecycle => pure lifecycle
    | none =>
        return .error
          "loam: malformed or unsupported HouseholdImage Scheduled lifecycle authority"
  let locusBody ←
    match Loam.Persistence.HouseholdImage.body? generation.image "LocusAdmission" with
    | some body => pure body
    | none =>
        return .error "loam: required HouseholdImage Locus admission section is missing"
  let locusAdmission ←
    match Loam.Persistence.decodeLocusAdmissionVocabulary? locusBody with
    | some vocabulary => pure vocabulary
    | none =>
        return .error
          "loam: malformed or unsupported HouseholdImage Locus admission authority"
  let world := Loam.MovementWorldAdapter.ofActual evidence locusAdmission
  let _ ←
    match findOpen? lifecycle world.events draft.scheduled with
    | .ok occurrence => pure occurrence
    | .error message => return .error message
  let existing := lifecycle.terminals.completionActualFor? draft.scheduled
  let actualId := existing.getD (completionEventId draft.scheduled)
  match EventMemory.findById? world.events actualId with
  | some _ =>
      return .error "loam: selected Scheduled identity is already completed"
  | none => pure ()
  match lifecycle.terminals.completionSourceForActual? actualId with
  | some source =>
      if source != draft.scheduled then
        return .error "loam: Scheduled completion Actual identity belongs to another Scheduled occurrence"
  | none => pure ()
  let updatedWorld ←
    match appendCompletionActual? world actualId draft.movement with
    | .ok updated => pure updated
    | .error message => return .error message
  let relation : ScheduledTerminal := {
    source := draft.scheduled
    target := some (.actual actualId)
  }
  let updatedTerminals ←
    match existing with
    | some _ => pure lifecycle.terminals
    | none =>
        match lifecycle.terminals.add? relation with
        | some terminals => pure terminals
        | none => return .error "loam: Scheduled completion violates one-to-one endpoint ownership"
  let updatedLifecycle := { lifecycle with terminals := updatedTerminals }
  let updatedEvidence : ActualEvidence := {
    evidence with
    events := updatedWorld.events
    validity := updatedWorld.validity
    descriptions := updatedWorld.descriptions
    relations := updatedWorld.relations
    discharges := updatedWorld.discharges
  }
  let candidateWithScheduled ←
    match existing with
    | some _ => pure generation.image
    | none =>
        let some body := Loam.Persistence.encodeScheduledLifecycleImage? updatedLifecycle
          | return .error "loam: proposed Household Scheduled lifecycle did not encode"
        let some candidate :=
            Loam.Persistence.HouseholdImage.replaceBody?
              generation.image "Scheduled" body
          | return .error
              "loam: HouseholdImage Scheduled lifecycle section disappeared before publication"
        pure candidate
  let some actualBody := Loam.Persistence.encodeNormalizedActual? updatedEvidence
    | return .error "loam: proposed HouseholdImage Actual authority did not encode"
  let some candidate :=
      Loam.Persistence.HouseholdImage.replaceBody?
        candidateWithScheduled "Actual" actualBody
    | return .error
        "loam: HouseholdImage Actual section disappeared before publication"
  let changedNames :=
    match existing with
    | some _ => ["Actual"]
    | none => ["Scheduled", "Actual"]
  match ← Loam.HouseholdAuthority.publishObserved?
      root generation.wire changedNames candidate with
  | .ok _ => return .ok ()
  | .error message =>
      return .error
        ("loam: Scheduled completion Household generation could not be published: " ++ message)

private def publishHouseholdCancellationFromGeneration
    (root : System.FilePath)
    (draft : CancellationDraft) : IO (Except String Unit) := do
  let observed ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return .error message
  let lifecycle := observed.lifecycle
  let actualImage ←
    match Loam.ActualAuthority.decodeHouseholdGeneration? observed.generation with
    | .ok image => pure image
    | .error message => return .error message
  let evidence := actualImage.evidence
  match lifecycle.terminals.completionActualFor? draft.scheduled with
  | some actual =>
      if (EventMemory.findById? evidence.events actual).isSome then
        return .error "loam: selected Scheduled identity is already completed"
      else
        return .error "loam: selected Scheduled identity has an interrupted completion; retry completion before cancellation"
  | none => pure ()
  let _ ←
    match findOpen? lifecycle evidence.events draft.scheduled with
    | .ok occurrence => pure occurrence
    | .error message => return .error message
  let retirement : ScheduledTerminal := {
    source := draft.scheduled
    target := none
  }
  let updatedTerminals ←
    match lifecycle.terminals.add? retirement with
    | some terminals => pure terminals
    | none => return .error "loam: could not append Scheduled retirement evidence"
  let updatedLifecycle := { lifecycle with terminals := updatedTerminals }
  match ← Loam.ScheduledLifecycleAuthority.publishObserved?
      root observed updatedLifecycle with
  | .ok _ => return .ok ()
  | .error message =>
      return .error
        ("loam: Scheduled retirement lifecycle could not be published: " ++ message)

/--
Complete one production household Scheduled occurrence by publishing its
Scheduled terminal and Actual endpoint in one HouseholdImage generation update.

The temporary Actual serializer remains the outer ownership boundary until the
remaining Actual writers are converted away from that coordination lock.
-/
def publishHouseholdCompletion
    (root : System.FilePath)
    (draft : CompletionDraft) : IO (Except String Unit) := do
  if root.toString.isEmpty then
    return .error "loam: data directory must not be empty"
  Loam.ActualAuthority.withActualOwnership root
    (publishHouseholdCompletionUnderActualOwnership root draft)

/-- Cancel one production household Scheduled occurrence through HouseholdImage. -/
def publishHouseholdCancellation
    (root : System.FilePath)
    (draft : CancellationDraft) : IO (Except String Unit) := do
  if root.toString.isEmpty then
    return .error "loam: data directory must not be empty"
  publishHouseholdCancellationFromGeneration root draft



end Loam.ScheduledTerminalPublisher
