import Loam.Core.ActualValidityHistory

namespace Loam.ActualValidityV2

open Loam.Core

set_option autoImplicit false

private def scheduledCompletionPrefix : String := "scheduled-completion:"
private def scheduledCompletionValidityPrefix : String := "scheduled-completion-validity:"

/--
Derived in-memory adapter identity for a V2 Event-rooted occurrence date.

V2 persistence does not store an independent identity for the initial date.
Existing `ActualValidityHistory` consumers still speak in fact identities, so
while that compatibility boundary exists the EventId is injected into a
reserved derived token. This token is representation glue, not new canonical
evidence and is never serialized as the identity of a BASE row.

Scheduled completion historically used a deterministic initial validity token
for interrupted-publication recovery. While the compatibility adapter exists,
that one family is derived back from the Scheduled completion EventId so old V1
and new V2 retries observe the same in-memory identity. The V2 file still stores
only `BASE scheduled-completion:* DATE`; this legacy spelling never becomes V2
canonical evidence and disappears with the adapter.
-/
def rootFactId (event : EventId) : ActualValidityFactId :=
  if event.token.startsWith scheduledCompletionPrefix then
    let suffix := event.token.drop scheduledCompletionPrefix.length
    ⟨scheduledCompletionValidityPrefix ++ suffix⟩
  else
    ⟨"event-root:" ++ event.token⟩

/-- True exactly when a compatibility fact identity is derived from its Event. -/
def isRootFact {Time : Type} (fact : ActualValidityFact Time) : Bool :=
  decide (fact.id = rootFactId fact.event)

end Loam.ActualValidityV2
