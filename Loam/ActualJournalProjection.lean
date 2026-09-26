import Loam.ActualAuthority

namespace Loam.ActualJournalProjection

open Loam.Core

set_option autoImplicit false

/-!
# Current Actual journal projection

This read-only boundary projects one fully admitted normalized Actual image into
dated current journal entries. It owns no persistence and introduces no second
Actual authority.

Correction selection is inherited from `ActualAuthority.Image.currentEvents`.
Current occurrence dates are inherited from `Image.currentValidities`.
Descriptions remain optional presentation evidence.
-/

structure Entry where
  event : Event
  validOn : String
  description : Option String

private def entry?
    (validities : ActualValidityMemory String)
    (descriptions : EventDescriptionMemory)
    (event : Event) : Except String Entry :=
  match ActualValidityMemory.findByEventId? validities event.id with
  | none =>
      Except.error
        ("effective Event is missing current Actual occurrence date: " ++ event.id.token)
  | some validOn =>
      Except.ok {
        event := event
        validOn := validOn
        description := EventDescriptionMemory.findText? descriptions event.id
      }

private def entries?
    (validities : ActualValidityMemory String)
    (descriptions : EventDescriptionMemory) :
    List Event → Except String (List Entry)
  | [] => Except.ok []
  | event :: rest => do
      let current ← entry? validities descriptions event
      let later ← entries? validities descriptions rest
      pure (current :: later)

private def ordering (left right : Entry) : Ordering :=
  match compare left.validOn right.validOn with
  | .eq => compare left.event.id.token right.event.id.token
  | other => other

private def entryLe (left right : Entry) : Bool :=
  match ordering left right with
  | .gt => false
  | _ => true

/--
Order the admitted current journal with merge sort.

R4 / Observation 335 qualified this as an exact refinement of the former
fold-of-insertion mechanics on the reachable Actual domain: EventMemory rejects
duplicate EventId values, and EventId is the final journal tie-breaker.
-/
private def sortEntries (entries : List Entry) : List Entry :=
  entries.mergeSort entryLe

/--
Project the correction-aware current Actual frontier into deterministic dated
journal entries. Historical superseded Events do not appear.
-/
def fromImage? (image : Loam.ActualAuthority.Image) : Except String (List Entry) := do
  let entries ← entries?
    image.currentValidities image.evidence.descriptions image.currentEvents.events
  pure (sortEntries entries)

end Loam.ActualJournalProjection
