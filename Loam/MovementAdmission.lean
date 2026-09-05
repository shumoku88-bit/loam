import Loam.Application.OpenRelationFrontier
import Loam.Application.RelationDischargeFrontier
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.MovementRelationEntry
import Loam.MovementDischargeEntry
import Loam.Persistence

namespace Loam.MovementAdmission

set_option autoImplicit false

/--
One already-collected practical Movement before durable identity allocation.

The draft keeps signed Effects, occurrence-date evidence, optional human
recognition text, explicit open-relation drafts, and explicit discharge drafts
separate. It contains no durable EventId, RelationUnitId allocated by this
operation, or persistence concern.
-/
structure Draft where
  validOn : String
  description : Option String
  effects : List Loam.Core.Effect
  relations : List Loam.MovementRelationEntry.Draft
  discharges : List Loam.MovementDischargeEntry.Draft
  total : Int

/--
The five typed evidence families Movement admission reads and may extend.

This is an in-memory semantic boundary, not a persistence bundle or a claim that
the families are one meaning. Physical publishers remain responsible for how an
admitted world becomes authority.
-/
structure World where
  events : Loam.Core.EventMemory
  validity : Loam.Core.ActualValidityHistory String
  descriptions : Loam.Core.EventDescriptionMemory
  relations : List Loam.Core.RelationUnit
  discharges : List Loam.Core.RelationDischarge

/--
One successfully admitted Movement plus the updated typed world.

`newRelations` and `newDischarges` remain explicit so a physical publisher can
retain current conditional-write behavior without re-deriving semantic change
from byte differences or Effect signs.
-/
structure Admitted where
  world : World
  event : Loam.Core.Event
  newRelations : List Loam.Core.RelationUnit
  newDischarges : List Loam.Core.RelationDischarge

private def historyMentionsEvent
    (history : Loam.Core.ActualValidityHistory String)
    (id : Loam.Core.EventId) : Bool :=
  history.facts.any fun fact => decide (fact.event = id)

private def relationsMentionEvent
    (relations : List Loam.Core.RelationUnit)
    (id : Loam.Core.EventId) : Bool :=
  relations.any fun relation => decide (relation.sourceEvent = id)

private def dischargesMentionEvent
    (discharges : List Loam.Core.RelationDischarge)
    (id : Loam.Core.EventId) : Bool :=
  discharges.any fun discharge => decide (discharge.event = id)

private def freshRecordEventIdFrom
    (world : World) : Nat → Nat → Option Loam.Core.EventId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventId := ⟨"record-" ++ toString index⟩
      match Loam.Core.EventMemory.findById? world.events candidate with
      | none =>
          if historyMentionsEvent world.validity candidate ||
              (Loam.Core.EventDescriptionMemory.findText? world.descriptions candidate).isSome ||
              relationsMentionEvent world.relations candidate ||
              dischargesMentionEvent world.discharges candidate then
            freshRecordEventIdFrom world (index + 1) fuel
          else
            some candidate
      | some _ => freshRecordEventIdFrom world (index + 1) fuel

private def freshRecordEventId? (world : World) : Option Loam.Core.EventId :=
  freshRecordEventIdFrom world 1
    (world.events.events.length + world.validity.facts.length +
      world.descriptions.entries.length + world.relations.length +
      world.discharges.length + 1)

private def relationIdUsed
    (used : List Loam.Core.RelationUnitId)
    (id : Loam.Core.RelationUnitId) : Bool :=
  used.any fun candidate => decide (candidate = id)

private def freshRelationUnitIdFrom
    (used : List Loam.Core.RelationUnitId) : Nat → Nat → Option Loam.Core.RelationUnitId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.RelationUnitId := ⟨"relation-" ++ toString index⟩
      if relationIdUsed used candidate then
        freshRelationUnitIdFrom used (index + 1) fuel
      else
        some candidate

private def freshRelationUnitIdsFrom
    (used : List Loam.Core.RelationUnitId) : Nat → Nat → Option (List Loam.Core.RelationUnitId)
  | 0, _ => some []
  | remaining + 1, index => do
      let id ← freshRelationUnitIdFrom used index (used.length + 1)
      let rest ← freshRelationUnitIdsFrom (id :: used) remaining (index + 1)
      some (id :: rest)

/--
Allocate fresh practical RelationUnit identities without rebinding retained raw
provenance. Raw discharge targets reserve the same operational namespace as
retained RelationUnit ids, matching the currently qualified Movement behavior.
-/
private def freshRelationUnitIds?
    (world : World)
    (count : Nat) : Option (List Loam.Core.RelationUnitId) :=
  let used :=
    world.relations.map (fun relation => relation.id) ++
      world.discharges.map (fun discharge => discharge.target)
  freshRelationUnitIdsFrom used count 1

private def materializeRelationUnits? :
    Loam.Core.EventId →
    List Loam.Core.RelationUnitId →
    List Loam.MovementRelationEntry.Draft →
    Option (List Loam.Core.RelationUnit)
  | _, [], [] => some []
  | eventId, id :: ids, draft :: drafts => do
      let rest ← materializeRelationUnits? eventId ids drafts
      some ({
        id := id
        sourceEvent := eventId
        sourceEffect := draft.sourceEffect
        debtor := draft.debtor
        creditor := draft.creditor
        quantity := draft.quantity
      } :: rest)
  | _, _, _ => none

private def materializeRelationDischarges
    (eventId : Loam.Core.EventId)
    (drafts : List Loam.MovementDischargeEntry.Draft) :
    List Loam.Core.RelationDischarge :=
  drafts.map fun draft => {
    event := eventId
    target := draft.target
    quantity := draft.quantity
  }

private def freshValidityFactIdFrom
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.ActualValidityFactId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.ActualValidityFactId :=
        ⟨"validity-" ++ toString index⟩
      match history.findFactById? candidate with
      | none => some candidate
      | some _ => freshValidityFactIdFrom history (index + 1) fuel

private def freshValidityFactId?
    (history : Loam.Core.ActualValidityHistory String) :
    Option Loam.Core.ActualValidityFactId :=
  freshValidityFactIdFrom history 1 (history.facts.length + 1)

private def uncoveredRelationSource
    (_ : Loam.Core.EventId) (_ : Loam.Core.EffectKey) : Bool := false

private def relationSourceResolved?
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (eventId : Loam.Core.EventId)
    (effectKey : Loam.Core.EffectKey) : Bool :=
  (Loam.Application.currentRelationState?
    events relations [] uncoveredRelationSource eventId effectKey).isSome

private def relationSourcePositive?
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (eventId : Loam.Core.EventId)
    (effectKey : Loam.Core.EffectKey) : Bool :=
  match Loam.Application.currentRelationState?
      events relations [] uncoveredRelationSource eventId effectKey with
  | some (.knownPositive _) => true
  | _ => false

private def relationPublicationAdmissible
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (event : Loam.Core.Event)
    (newRelations : List Loam.Core.RelationUnit) : Bool :=
  event.effects.all (fun effect =>
    relationSourceResolved? events relations event.id effect.key) &&
  newRelations.all (fun relation =>
    relationSourcePositive? events relations event.id relation.sourceEffect)

private def dischargePublicationAdmissible
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (discharges : List Loam.Core.RelationDischarge)
    (newDischarges : List Loam.Core.RelationDischarge) : Bool :=
  newDischarges.all fun discharge =>
    match Loam.Application.admittedRelationDischargesFor?
        events relations [] discharges discharge.target with
    | none => false
    | some admitted =>
        admitted.any fun item =>
          decide
            (item.discharge.event = discharge.event ∧
              item.discharge.target = discharge.target ∧
              item.discharge.quantity = discharge.quantity)

/--
Admit one already-collected Movement against one current typed world.

This function owns the current practical identity allocation and world-dependent
relation/discharge admission rules, but performs no IO, persistence, authority
switch, terminal rendering, or writer locking. A caller either receives one
fully admitted five-family typed world or the same error boundary used by the
current practical writer.
-/
def admit? (world : World) (draft : Draft) : Except String Admitted := do
  let eventId ← match freshRecordEventId? world with
    | some id => pure id
    | none => throw "loam: could not generate fresh recording identities"
  let factId ← match freshValidityFactId? world.validity with
    | some id => pure id
    | none => throw "loam: could not generate fresh recording identities"
  let relationIds ← match freshRelationUnitIds? world draft.relations.length with
    | some ids => pure ids
    | none => throw "loam: could not generate fresh recording identities"
  let event ← match Loam.Core.Event.ofEffects? eventId draft.effects with
    | some admitted => pure admitted
    | none => throw "loam: could not admit generated movement or relation evidence"
  let newRelations ← match materializeRelationUnits? eventId relationIds draft.relations with
    | some admitted => pure admitted
    | none => throw "loam: could not admit generated movement or relation evidence"
  let newDischarges := materializeRelationDischarges eventId draft.discharges
  let fact : Loam.Core.ActualValidityFact String := {
    id := factId
    event := eventId
    validOn := draft.validOn
  }
  let updatedDescriptions ← match draft.description with
    | none => pure world.descriptions
    | some text =>
        match Loam.Core.EventDescriptionMemory.ofEntries?
            (world.descriptions.entries ++ [{ event := eventId, text := text }]) with
        | some descriptions => pure descriptions
        | none =>
            throw "loam: could not append movement, occurrence-date, and description evidence"
  let updatedEvents ← match Loam.Core.EventMemory.add? world.events event with
    | some events => pure events
    | none =>
        throw "loam: could not append movement, occurrence-date, and description evidence"
  let updatedHistory ← match world.validity.addFact? fact with
    | some history => pure history
    | none =>
        throw "loam: could not append movement, occurrence-date, and description evidence"
  let updatedRelations := world.relations ++ newRelations
  let updatedDischarges := world.discharges ++ newDischarges
  if !relationPublicationAdmissible updatedEvents updatedRelations event newRelations then
    throw "loam: open relation evidence did not justify one source-local frontier"
  if !dischargePublicationAdmissible
      updatedEvents updatedRelations updatedDischarges newDischarges then
    throw "loam: relation discharge evidence did not justify one current target frontier"
  pure {
    world := {
      events := updatedEvents
      validity := updatedHistory
      descriptions := updatedDescriptions
      relations := updatedRelations
      discharges := updatedDischarges
    }
    event := event
    newRelations := newRelations
    newDischarges := newDischarges
  }

end Loam.MovementAdmission
