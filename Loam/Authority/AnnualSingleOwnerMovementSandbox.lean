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
  | outcomeUnknown (operation : MovementOperationId) (reason : String)

/-- Prepare a real Movement in memory from precisely this pinned generation.
No IO or alternative authority is consulted. Missing/corrupt policy refuses,
not an implicit empty vocabulary. Retained idempotency evidence is in the
updated Actual section of the same resulting native generation. -/
private def prepareMovement?
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
      return .outcomeUnknown operation reason

end Loam.AnnualSingleOwnerSandbox
