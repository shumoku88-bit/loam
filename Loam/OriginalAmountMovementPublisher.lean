import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.LocusAdmissionAuthority
import Loam.MovementAdmission
import Loam.MovementWorldAdapter
import Loam.Persistence.TokenSyntax

namespace Loam.OriginalAmountMovementPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Atomic Movement + original amount publisher

This write seam is for the practical case where household accounting is an
ordinary single-Measure Movement but the merchant/card presents one positive
amount in another explicit Measure.

The Movement Event and OriginalAmountEvidence row are published together under
one Actual writer ownership interval and one atomic authority switch.
-/

structure Draft where
  movement : Loam.MovementAdmission.Draft
  originalMeasure : MeasureId
  originalQuantity : Quantity
deriving Repr

private def validateOriginal? (draft : Draft) : Except String Unit := do
  if !Loam.Persistence.validToken draft.originalMeasure.token then
    throw "loam: original amount Measure must be a valid token"
  if draft.originalQuantity.quanta <= 0 then
    throw "loam: original amount must be positive"

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Draft) :
    IO (Except String EventId) := do
  match validateOriginal? draft with
  | .error message => return .error message
  | .ok () => pure ()

  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok value => pure value
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok value => pure value
    | .error message => return .error message

  let world := Loam.MovementWorldAdapter.ofActual evidence locusAdmission
  let admitted ←
    match Loam.MovementAdmission.admit? world draft.movement with
    | .ok value => pure value
    | .error message => return .error message

  let original : OriginalAmountEvidence := {
    event := admitted.eventId
    measure := draft.originalMeasure
    quantity := draft.originalQuantity
  }

  let originalAmounts ←
    match evidence.originalAmounts.add? original with
    | some value => pure value
    | none =>
        return .error
          "loam: could not retain one original amount for the newly admitted Event"

  let updatedEvidence : ActualEvidence := {
    evidence with
    events := admitted.world.events
    validity := admitted.world.validity
    descriptions := admitted.world.descriptions
    originalAmounts := originalAmounts
    relations := admitted.world.relations
    discharges := admitted.world.discharges
  }

  match ← Loam.ActualAuthority.publishActual? root updatedEvidence with
  | .error message => return .error message
  | .ok () => return .ok admitted.eventId

/--
Publish one ordinary Movement and its original presented amount atomically.
-/
def publish
    (rootPath : String)
    (draft : Draft) :
    IO (Except String EventId) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.OriginalAmountMovementPublisher
