import Loam.Core.ActualValidityHistory

namespace Loam.ActualValidityV2

open Loam.Core

set_option autoImplicit false

/--
Derived in-memory adapter identity for a V2 Event-rooted occurrence date.

V2 persistence does not store an independent identity for the initial date.
Existing `ActualValidityHistory` consumers still speak in fact identities, so
while that compatibility boundary exists the EventId is injected into a
reserved derived token. This token is representation glue, not new canonical
evidence and is never serialized as the identity of a BASE row.
-/
def rootFactId (event : EventId) : ActualValidityFactId :=
  ⟨"event-root:" ++ event.token⟩

/-- True exactly when a compatibility fact identity is derived from its Event. -/
def isRootFact {Time : Type} (fact : ActualValidityFact Time) : Bool :=
  decide (fact.id = rootFactId fact.event)

end Loam.ActualValidityV2
