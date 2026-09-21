import Loam.ActualEvidence
import Loam.Core.LocusAdmission
import Loam.MovementAdmission

namespace Loam.MovementWorldAdapter

open Loam.Core

set_option autoImplicit false

/-!
# Pure Movement World Representation Adapter

This module provides the pure representation conversion from retained
authoritative `ActualEvidence` and the independent current `LocusAdmissionVocabulary`
into `MovementAdmission.World`.

This is a pure in-memory boundary:
* no filesystem access
* no IO
* no persistence ownership
* no merge of independent household authorities
-/

/--
Construct the Movement admission view from retained Actual evidence and the
independent current new-write Locus policy.

This is a pure representation boundary. It does not merge the two authorities
or grant persistence ownership to the semantic `World` type.
-/
def ofActual
    (evidence : ActualEvidence)
    (locusAdmission : LocusAdmissionVocabulary) : Loam.MovementAdmission.World := {
  events := evidence.events
  validity := evidence.validity
  descriptions := evidence.descriptions
  relations := evidence.relations
  discharges := evidence.discharges
  locusAdmission := locusAdmission
}

/-- Compatibility alias for `ofActual`. -/
abbrev movementWorld := ofActual

end Loam.MovementWorldAdapter
