import Loam.Authority.AnnualSingleOwnerSandbox
import Loam.Application.MovementAdmission
import Loam.Application.MovementWorldAdapter
import Loam.Authority.ActualAuthority
import Loam.Authority.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax

namespace Loam.AnnualSingleOwnerSandbox

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
A single *real practical Movement* through the same disposable annual HEAD
session as Home. Semantic admission, canonical Actual encoding and the native
annual publisher are existing qualified code, not a new bookkeeping algorithm.

No production TUI/CLI commands are routed here. The operation day is supplied
explicitly by a synthetic caller; it must NOT be inferred from draft.validOn.
-/

/-- No success receipt until HEAD has been installed and all requested native
barriers returned. An unknown outcome is never reclassified as a failure that
may be retried blindly. -/
inductive MovementOutcome where
  | committed (event : EventId) (selected : Loam.AnnualSourceHeadSandbox.Selected)
  | refusedBeforeHead (reason : String)
  | outcomeUnknown (operation : MovementOperationId) (event : EventId) (reason : String)

/-- Prepare a real Movement in memory from precisely this pinned generation.
No IO or alternative authority is consulted. This pure preparation is also
used by the disposable fault-injection probe; it does not itself publish.
Missing/corrupt policy refuses,
not an implicit empty vocabulary. Retained idempotency evidence is in the
updated Actual section of the same resulting native generation. -/
def prepareMovement?
    (pin : Pinned)
    (operation : MovementOperationId)
    (draft : Loam.MovementAdmission.Draft) :
    Except String (EventId × Image) := do
  if !Loam.Persistence.validToken operation.token then
    throw "loam: annual Movement operation token invalid"
  let actual ← Loam.ActualAuthority.decodeHouseholdGeneration?
    pin.selected.generation
  if (actual.evidence.movementOperations.findEvent? operation).isSome then
    throw "loam: annual Movement operation already retained; no second admission"
  let vocabulary ← Loam.LocusAdmissionAuthority.decodeGeneration?
    pin.selected.generation
  let world := Loam.MovementWorldAdapter.ofActual actual.evidence vocabulary
  let admitted ← Loam.MovementAdmission.admit? world draft
  let some operations := actual.evidence.movementOperations.add? {
      operation := operation
      event := admitted.eventId
    } | throw "loam: annual Movement operation evidence rejected"
  let proposed : ActualEvidence := {
    actual.evidence with
    events := admitted.world.events
    validity := admitted.world.validity
    descriptions := admitted.world.descriptions
    movementOperations := operations
    relations := admitted.world.relations
    discharges := admitted.world.discharges
  }
  let some body := Loam.Persistence.encodeNormalizedActual? proposed
    | throw "loam: annual Movement Actual did not encode"
  let some candidate :=
    replaceBody? pin.selected.generation.image "Actual" body
    | throw "loam: annual Movement missing required Actual section"
  return (admitted.eventId, candidate)

/-- Record one qualified practical Movement against exactly the HEAD used for
this session's Home reads. CAS and OS synchronization happen in Pinned.append?.
Refuse a stale generation and operation ID without writing to household.loam.

Do NOT interpret a result-unknown HEAD sync as definitely unpublished, even
though process-visible reobservation may show the new source selected. -/
def Pinned.recordMovement?
    (pin : Pinned)
    (admittedDay : String)
    (operation : MovementOperationId)
    (draft : Loam.MovementAdmission.Draft) : IO MovementOutcome := do
  let .ok (eventId, candidate) :=
      prepareMovement? pin operation draft
    | return .refusedBeforeHead
        "loam: annual Movement semantic admission or operation identity refused"
  let result ← pin.append?
    admittedDay ("movement-" ++ operation.token) ["Actual"] candidate
  match result with
  | .committed selected =>
      return .committed eventId selected
  | .refusedBeforeHead reason =>
      return .refusedBeforeHead reason
  | .outcomeUnknown _ reason =>
      return .outcomeUnknown operation eventId reason


/-- What ONE complete replayable annual source says about an uncertain
Movement attempt. These are process-visible observations, not acknowledgments
that disk/firmware survived sudden power loss. No branch is a retry command. -/
inductive MovementObservation where
  | priorHeadVisible
  | requestedMovementVisible (event : EventId)
  | cannotClassify (reason : String)

/-- Check one complete selected annual generation and its retained actual
Movement idempotency mapping against the original pin, operation, admission
day, and the Event ID calculated BEFORE the uncertain write. The second HEAD
read inside `open?` refuses a changed source, rather than mixing generations
across separate Actual and HEAD observations.

A valid old HEAD with an old external expectation is still replayable; this
is not a trusted monotonic anchor or a durable-success receipt. -/
def Pinned.observeMovement?
    (pin : Pinned)
    (admittedDay : String)
    (operation : MovementOperationId)
    (expectedEvent : EventId) : IO MovementObservation := do
  let .ok seen ← Loam.AnnualSourceHeadSandbox.readSelected? pin.root
    | return .cannotClassify "annual HEAD missing/corrupt during Movement reobservation"
  let .ok current ← open? pin.root seen.headWire
    | return .cannotClassify "annual source changed or is ineligible during reobservation"
  let conclusion := Loam.AnnualSourceHeadSandbox.classifyUnknownSelected
    current.selected pin.selected.headWire admittedDay
    ("movement-" ++ operation.token)
  let .ok actual := Loam.ActualAuthority.decodeHouseholdGeneration?
    current.selected.generation
    | return .cannotClassify "Movement Actual section missing/corrupt during reobservation"
  let retained := actual.evidence.movementOperations.findEvent? operation
  match conclusion with
  | .priorHeadSelected =>
      if retained.isNone then
        return .priorHeadVisible
      return .cannotClassify "prior HEAD unexpectedly retains uncertain Movement ID"
  | .requestedHeadSelected =>
      if retained == some expectedEvent &&
          (actual.evidence.events.findById? expectedEvent).isSome then
        return .requestedMovementVisible expectedEvent
      return .cannotClassify
        "selected requested HEAD does not retain the expected Event identity"
  | .cannotClassify reason =>
      return .cannotClassify reason

end Loam.AnnualSingleOwnerSandbox
