import Loam.Observations.Observation242
import Loam.Observations.Observation244
import Loam.MovementAdmission
import Lean.Elab.Tactic.Omega

namespace Loam.Observations.Observation247

open Loam.Core

set_option autoImplicit false

/-!
# Observation 247 — Movement record EventId allocation is total across five families

Movement admission reserves a proposed `record-` EventId when that EventId is
already represented or mentioned by any of five retained evidence families:
Event, ActualValidity, EventDescription, RelationUnit, or RelationDischarge.

Production budgets one candidate beyond the sum of those five represented list
lengths. This observation connects that exact OR-shaped collision domain to the
finite-search law from Observation 242.
-/

/-- EventId tokens mentioned by one retained family. -/
def eventIdTokens {Item : Type}
    (keyOf : Item → EventId) (items : List Item) : List String :=
  items.map (fun item => (keyOf item).token)

@[simp] theorem eventIdTokens_length {Item : Type}
    (keyOf : Item → EventId) (items : List Item) :
    (eventIdTokens keyOf items).length = items.length := by
  simp [eventIdTokens]

/-- The complete finite EventId namespace consulted by Movement record allocation. -/
def recordEventTokens (world : Loam.MovementAdmission.World) : List String :=
  Observation244.eventTokens world.events.events ++
    eventIdTokens ActualValidityFact.event world.validity.facts ++
    eventIdTokens EventDescription.event world.descriptions.entries ++
    eventIdTokens RelationUnit.sourceEvent world.relations ++
    eventIdTokens RelationDischarge.event world.discharges

@[simp] theorem recordEventTokens_length
    (world : Loam.MovementAdmission.World) :
    (recordEventTokens world).length =
      world.events.events.length + world.validity.facts.length +
        world.descriptions.entries.length + world.relations.length +
        world.discharges.length := by
  simp [recordEventTokens, eventIdTokens, Observation244.eventTokens] <;> omega

/-- Left-associated production OR and right-associated list membership agree. -/
private theorem boolOr5_reassociate (a b c d e : Bool) :
    a || b || c || d || e = a || (b || (c || (d || e))) := by
  cases a <;> cases b <;> cases c <;> cases d <;> cases e <;> rfl

/-- Keyed finite lookup is equivalent to an explicit any over the same key. -/
private theorem findBy_isSome_eq_any {Item : Type}
    (keyOf : Item → EventId)
    (items : List Item)
    (target : EventId) :
    (FiniteKeyed.findBy? keyOf items target).isSome =
      items.any (fun item => decide (keyOf item = target)) := by
  induction items with
  | nil =>
      simp [FiniteKeyed.findBy?]
  | cons item rest ih =>
      by_cases h : keyOf item = target
      · simp [FiniteKeyed.findBy?, h]
      · simp [FiniteKeyed.findBy?, h, ih]

/-- EventId equality over one family is exactly token membership in its witness. -/
private theorem anyEventId_eq_usedByList {Item : Type}
    (keyOf : Item → EventId)
    (items : List Item)
    (token : String) :
    items.any
        (fun item => decide (keyOf item = (⟨token⟩ : EventId))) =
      Observation242.usedByList (eventIdTokens keyOf items) token := by
  induction items with
  | nil =>
      simp [eventIdTokens, Observation242.usedByList]
  | cons item rest ih =>
      cases hKey : keyOf item with
      | mk itemToken =>
          by_cases hEq : itemToken = token
          · simp [eventIdTokens, Observation242.usedByList, hKey, hEq, ih]
          · have hEqSymm : token ≠ itemToken := by
              intro h
              exact hEq h.symm
            simp [eventIdTokens, Observation242.usedByList, hKey, hEq, hEqSymm, ih]

/-- Description lookup reserves exactly the EventIds represented by description entries. -/
private theorem descriptionUsed_eq_usedByList
    (memory : EventDescriptionMemory)
    (token : String) :
    (memory.findText? (⟨token⟩ : EventId)).isSome =
      Observation242.usedByList
        (eventIdTokens EventDescription.event memory.entries) token := by
  have hFind :=
    findBy_isSome_eq_any EventDescription.event memory.entries
      (⟨token⟩ : EventId)
  have hAny :=
    anyEventId_eq_usedByList EventDescription.event memory.entries token
  rw [EventDescriptionMemory.findText?]
  simpa using hFind.trans hAny

/--
The exact five-family collision predicate used by Movement record allocation is
finite membership in `recordEventTokens`.
-/
theorem recordEventUsed_eq_usedByList
    (world : Loam.MovementAdmission.World) :
    (fun token =>
      let candidate : EventId := ⟨token⟩
      (EventMemory.findById? world.events candidate).isSome ||
        world.validity.facts.any
          (fun fact => decide (fact.event = candidate)) ||
        (EventDescriptionMemory.findText? world.descriptions candidate).isSome ||
        world.relations.any
          (fun relation => decide (relation.sourceEvent = candidate)) ||
        world.discharges.any
          (fun discharge => decide (discharge.event = candidate))) =
      Observation242.usedByList (recordEventTokens world) := by
  funext token
  have hEvents := congrFun (Observation244.eventUsed_eq_usedByList world.events) token
  have hValidity :=
    anyEventId_eq_usedByList ActualValidityFact.event world.validity.facts token
  have hDescriptions := descriptionUsed_eq_usedByList world.descriptions token
  have hRelations :=
    anyEventId_eq_usedByList RelationUnit.sourceEvent world.relations token
  have hDischarges :=
    anyEventId_eq_usedByList RelationDischarge.event world.discharges token
  simp only
  rw [hEvents, hValidity, hDescriptions, hRelations, hDischarges]
  simp [Observation242.usedByList, recordEventTokens, eventIdTokens,
    Observation244.eventTokens]
  exact boolOr5_reassociate _ _ _ _ _

/-- The exact Movement record EventId search cannot exhaust its current fuel. -/
theorem movementRecordSearch_is_total
    (world : Loam.MovementAdmission.World) :
    ∃ token,
      Loam.firstUnusedNumberedToken?
        "record-"
        (fun token =>
          let candidate : EventId := ⟨token⟩
          (EventMemory.findById? world.events candidate).isSome ||
            world.validity.facts.any
              (fun fact => decide (fact.event = candidate)) ||
            (EventDescriptionMemory.findText? world.descriptions candidate).isSome ||
            world.relations.any
              (fun relation => decide (relation.sourceEvent = candidate)) ||
            world.discharges.any
              (fun discharge => decide (discharge.event = candidate)))
        1
        (world.events.events.length + world.validity.facts.length +
          world.descriptions.entries.length + world.relations.length +
          world.discharges.length + 1) = some token := by
  rw [recordEventUsed_eq_usedByList world]
  apply Observation242.search_succeeds_when_window_outnumbers_used
  rw [recordEventTokens_length]
  omega

/-!
Observation 247 earns the five-family result:

```text
used record EventIds = Event ∪ Validity ∪ Description ∪ Relation ∪ Discharge mentions
finite witness length = sum of those five represented family lengths
fuel = that sum + 1
-> fresh Movement record EventId search cannot return none
```

Production remains unchanged.
-/

end Loam.Observations.Observation247
