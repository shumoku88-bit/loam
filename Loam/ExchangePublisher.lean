import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.ExchangeAdmission
import Loam.LocusAdmissionAuthority

namespace Loam.ExchangePublisher

open Loam.Core

set_option autoImplicit false

/-!
# Atomic practical exchange publisher

This is the production write seam for one newly observed cross-Measure exchange.
Event creation and ExchangeEvidence publication happen under one Actual writer
ownership interval and one atomic authority switch.
-/

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Loam.ExchangeAdmission.Draft) :
    IO (Except String EventId) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok value => pure value
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok value => pure value
    | .error message => return .error message

  let world : Loam.ExchangeAdmission.World := {
    events := evidence.events
    validity := evidence.validity
    descriptions := evidence.descriptions
    exchanges := evidence.exchanges
    corrections := evidence.corrections
    locusAdmission := locusAdmission
  }

  let admitted ←
    match Loam.ExchangeAdmission.admit? world draft with
    | .ok value => pure value
    | .error message => return .error message

  let updatedEvidence : ActualEvidence := {
    evidence with
    events := admitted.world.events
    validity := admitted.world.validity
    descriptions := admitted.world.descriptions
    exchanges := admitted.world.exchanges
  }

  match ← Loam.ActualAuthority.publishActual? root updatedEvidence with
  | .error message => return .error message
  | .ok () => return .ok admitted.eventId

/--
Publish one new exchange occurrence through normalized Actual authority.
-/
def publish
    (rootPath : String)
    (draft : Loam.ExchangeAdmission.Draft) :
    IO (Except String EventId) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.ExchangePublisher
