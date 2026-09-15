import Loam.ActualDate
import Loam.Core.BalancedMovement
import Loam.Core.OpenRelation
import Loam.Application.OpenRelationFrontier
import Loam.Application.RelationDischargeFrontier
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.LocusAdmission
import Loam.FreshNumberedToken
import Loam.Persistence.TokenSyntax
import Loam.SparseEffectIdentity

namespace Loam.MovementAdmission

set_option autoImplicit false

/--
Semantic draft for one positive open relation attached to an already-collected
Movement Effect.

This value belongs to Movement admission, not to any terminal or line-input
collector. It has no durable EventId or RelationUnitId; those identities are
allocated only while admitting the complete draft against the current world.
-/
structure RelationDraft where
  sourceEffect : Loam.Core.EffectKey
  debtor : Loam.Core.RelationEndpoint
  creditor : Loam.Core.RelationEndpoint
  quantity : Loam.Core.Quantity
  deriving Repr, DecidableEq

/--
Semantic draft for one exact discharge against an existing RelationUnit.

The later Event identity is intentionally absent. Human-input adapters may build
this value, but admission owns its meaning and currentness checks.
-/
structure DischargeDraft where
  target : Loam.Core.RelationUnitId
  quantity : Loam.Core.Quantity
  deriving Repr, DecidableEq

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
  relations : List RelationDraft
  discharges : List DischargeDraft
  total : Int

/--
The independently meaningful evidence and policy families Movement admission
reads and may extend.

`locusAdmission` is current new-write policy, not Event history and not a display
completion cache. The remaining fields are retained household evidence. This is
an in-memory semantic boundary, not a persistence bundle or a claim that the
families are one meaning. Physical publishers remain responsible for how an
admitted world becomes authority.

The default is deliberately closed. Older call sites or version-1 serialized inputs that
supply no explicit policy therefore remain readable but cannot authorize a new
quantity-bearing Movement.
-/
structure World where
  events : Loam.Core.EventMemory
  validity : Loam.Core.ActualValidityHistory String
  descriptions : Loam.Core.EventDescriptionMemory
  relations : List Loam.Core.RelationUnit
  discharges : List Loam.Core.RelationDischarge
  locusAdmission : Loam.Core.LocusAdmissionVocabulary :=
    Loam.Core.LocusAdmissionVocabulary.empty

/--
One successfully admitted Movement plus the updated typed world.

The operation result exposes only the updated semantic world and the newly
allocated Event identity. Relation and discharge deltas are already represented
in `world` and are not a second publication contract.
-/
structure Admitted where
  world : World
  eventId : Loam.Core.EventId

private def recordEventTokens (world : World) : List String :=
  world.events.events.map (fun event => event.id.token) ++
    world.validity.facts.map (fun fact => fact.event.token) ++
    world.descriptions.entries.map (fun entry => entry.event.token) ++
    world.relations.map (fun relation => relation.sourceEvent.token) ++
    world.discharges.map (fun discharge => discharge.event.token)

private def freshRecordEventId (world : World) : Loam.Core.EventId :=
  ⟨Loam.firstUnusedNumberedToken "record-" (recordEventTokens world) 1⟩

private theorem freshRecordEventToken_not_mem (world : World) :
    (freshRecordEventId world).token ∉ recordEventTokens world := by
  exact Loam.firstUnusedNumberedToken_not_mem "record-" (recordEventTokens world) 1

private theorem eventId_not_mem_of_token_not_mem {Item : Type}
    (keyOf : Item → Loam.Core.EventId)
    (items : List Item)
    (id : Loam.Core.EventId)
    (hFresh : id.token ∉ items.map (fun item => (keyOf item).token)) :
    id ∉ items.map keyOf := by
  intro hMem
  apply hFresh
  rcases List.mem_map.mp hMem with ⟨item, hItem, hEq⟩
  exact List.mem_map.mpr ⟨item, hItem, congrArg Loam.Core.EventId.token hEq⟩

private theorem freshRecordEventId_not_mem_events (world : World) :
    freshRecordEventId world ∉ world.events.events.map Loam.Core.Event.id := by
  apply eventId_not_mem_of_token_not_mem Loam.Core.Event.id
  intro hMem
  exact freshRecordEventToken_not_mem world (by
    simp [recordEventTokens, hMem])

private theorem freshRecordEventId_not_mem_validityEvents (world : World) :
    freshRecordEventId world ∉
      world.validity.facts.map Loam.Core.ActualValidityFact.event := by
  apply eventId_not_mem_of_token_not_mem Loam.Core.ActualValidityFact.event
  intro hMem
  exact freshRecordEventToken_not_mem world (by
    simp [recordEventTokens, hMem])

private theorem freshRecordEventId_not_mem_descriptions (world : World) :
    freshRecordEventId world ∉
      world.descriptions.entries.map Loam.Core.EventDescription.event := by
  apply eventId_not_mem_of_token_not_mem Loam.Core.EventDescription.event
  intro hMem
  exact freshRecordEventToken_not_mem world (by
    simp [recordEventTokens, hMem])

private theorem rootRef_not_mem_of_event_not_mem
    (facts : List (Loam.Core.ActualValidityFact String))
    (id : Loam.Core.EventId)
    (hFresh : id ∉ facts.map Loam.Core.ActualValidityFact.event) :
    Loam.Core.ActualValidityRef.root id ∉
      facts.map Loam.Core.ActualValidityFact.ref := by
  intro hMem
  rcases List.mem_map.mp hMem with ⟨fact, hFact, hEq⟩
  apply hFresh
  apply List.mem_map.mpr
  refine ⟨fact, hFact, ?_⟩
  cases fact with
  | base event validOn =>
      simpa [Loam.Core.ActualValidityFact.ref, Loam.Core.ActualValidityFact.event] using hEq
  | revision revision event validOn =>
      simp [Loam.Core.ActualValidityFact.ref] at hEq

private theorem freshDescriptionAppend_isSome
    (world : World) (text : String) :
    (world.descriptions.add? {
      event := freshRecordEventId world
      text := text
    }).isSome := by
  have hFresh := freshRecordEventId_not_mem_descriptions world
  simp [Loam.Core.EventDescriptionMemory.add?, Loam.Core.EventDescriptionMemory.ofEntries?,
    world.descriptions.eventNodup, hFresh]

private theorem freshValidityAppend_isSome
    (world : World) (validOn : String) :
    (world.validity.addFact?
      (.base (freshRecordEventId world) validOn)).isSome := by
  have hFreshEvent := freshRecordEventId_not_mem_validityEvents world
  have hFreshRoot :
      Loam.Core.ActualValidityRef.root (freshRecordEventId world) ∉
        world.validity.facts.map Loam.Core.ActualValidityFact.ref :=
    rootRef_not_mem_of_event_not_mem world.validity.facts
      (freshRecordEventId world) hFreshEvent
  simp [Loam.Core.ActualValidityHistory.addFact?, Loam.Core.ActualValidityHistory.ofParts?,
    world.validity.factRefNodup, world.validity.correctionIdNodup, hFreshRoot]

private theorem eventOfEffects_some_id
    (id : Loam.Core.EventId)
    (effects : List Loam.Core.Effect)
    (event : Loam.Core.Event)
    (h : Loam.Core.Event.ofEffects? id effects = some event) :
    event.id = id := by
  unfold Loam.Core.Event.ofEffects? at h
  split at h
  next _ =>
    cases h
    rfl
  next _ =>
    cases h

private def eventWithRequestedId?
    (id : Loam.Core.EventId)
    (effects : List Loam.Core.Effect) :
    Option { event : Loam.Core.Event // event.id = id } :=
  match h : Loam.Core.Event.ofEffects? id effects with
  | none => none
  | some event => some ⟨event, eventOfEffects_some_id id effects event h⟩

private theorem freshEventAppend_isSome
    (world : World)
    (event : Loam.Core.Event)
    (hId : event.id = freshRecordEventId world) :
    (Loam.Core.EventMemory.add? world.events event).isSome := by
  have hFresh : event.id ∉ world.events.events.map Loam.Core.Event.id := by
    simpa [hId] using freshRecordEventId_not_mem_events world
  simp [Loam.Core.EventMemory.add?, Loam.Core.EventMemory.ofEvents?,
    world.events.idNodup, hFresh]

private def materializeRelationUnitsFrom
    (eventId : Loam.Core.EventId)
    (used : List String) : Nat → List RelationDraft → List Loam.Core.RelationUnit
  | _, [] => []
  | index, draft :: drafts =>
      let token := Loam.firstUnusedNumberedToken "relation-" used index
      let relation : Loam.Core.RelationUnit := {
        id := ⟨token⟩
        sourceEvent := eventId
        sourceEffect := draft.sourceEffect
        debtor := draft.debtor
        creditor := draft.creditor
        quantity := draft.quantity
      }
      relation :: materializeRelationUnitsFrom eventId (token :: used) (index + 1) drafts

/--
Materialize each RelationDraft with one fresh practical RelationUnit identity.
Raw discharge targets reserve the same operational namespace as retained
RelationUnit ids, matching the currently qualified Movement behavior.
-/
private def materializeRelationUnits
    (world : World)
    (eventId : Loam.Core.EventId)
    (drafts : List RelationDraft) : List Loam.Core.RelationUnit :=
  let used :=
    world.relations.map (fun relation => relation.id.token) ++
      world.discharges.map (fun discharge => discharge.target.token)
  materializeRelationUnitsFrom eventId used 1 drafts

private def materializeRelationDischarges
    (eventId : Loam.Core.EventId)
    (drafts : List DischargeDraft) :
    List Loam.Core.RelationDischarge :=
  drafts.map fun draft => {
    event := eventId
    target := draft.target
    quantity := draft.quantity
  }

private def uncoveredRelationSource
    (_ : Loam.Core.EventId) (_ : Loam.Core.EffectKey) : Bool := false

/--
An anonymous Effect has no independently addressable Relation source to resolve.
A retained key, when present, must still resolve through the same source-local
frontier as before sparse Effect identity.
-/
private def relationSourceResolved?
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (eventId : Loam.Core.EventId)
    (effectKey : Option Loam.Core.EffectKey) : Bool :=
  match effectKey with
  | none => true
  | some key =>
      (Loam.Application.currentRelationState?
        events relations uncoveredRelationSource eventId key).isSome

private def relationSourcePositive?
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (eventId : Loam.Core.EventId)
    (effectKey : Loam.Core.EffectKey) : Bool :=
  match Loam.Application.currentRelationState?
      events relations uncoveredRelationSource eventId effectKey with
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
        events relations discharges discharge.target with
    | none => false
    | some admitted =>
        admitted.any fun item =>
          decide
            (item.discharge.event = discharge.event ∧
              item.discharge.target = discharge.target ∧
              item.discharge.quantity = discharge.quantity)

/-- Anonymous Effects need no persisted identity token; retained keys still do. -/
private def retainedEffectKeyPersistable (effect : Loam.Core.Effect) : Bool :=
  match effect.key with
  | none => true
  | some key => Loam.Persistence.validToken key.token

/--
Erase collector-local Effect keys unless relation evidence independently earns
stable identity for that exact key.

This normalization is shared with other Actual-producing admissions through
`SparseEffectIdentity`; Movement admission supplies Relation source keys as the
independent evidence that earns durable Effect identity.
-/
def canonicalizeDraft (draft : Draft) : Draft :=
  let referenced := draft.relations.map (fun relation => relation.sourceEffect)
  { draft with
    effects := Loam.SparseEffectIdentity.canonicalizeEffects referenced draft.effects }

/-- Shared practical draft validation. Balanced JPY is an entrance contract,
not a global law imposed on neutral Core Events. All publishers call admit?. -/
def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.validOn then
    throw "loam: date must be a real calendar date in YYYY-MM-DD form"
  if !draft.effects.all (fun effect =>
      retainedEffectKeyPersistable effect &&
      Loam.Persistence.validToken effect.locus.token &&
      decide (effect.measure = ⟨"jpy"⟩) && effect.quantity.quanta != 0) then
    throw "loam: movement requires valid effect tokens and nonzero JPY quantities"
  let changes := draft.effects.map fun effect =>
    ({ coordinate := effect.locus, quantity := effect.quantity } :
      Loam.Core.MovementChange Loam.Core.LocusId)
  if (Loam.Core.BalancedMovement.ofChanges? ⟨"jpy"⟩ changes).isNone then
    throw "loam: movement totals differ"
  let positive := draft.effects.foldl
    (fun total effect => total + max 0 effect.quantity.quanta) 0
  if positive <= 0 || draft.total != positive then
    throw "loam: movement requires positive FROM / TO totals matching the draft total"

/--
Admit one already-collected Movement against one current typed world.

Collector-local Effect identity is first reduced to the stable identity actually
earned by explicit relation references. The first world-dependent rule is then
the explicit Observation-212 Locus vocabulary: every proposed Effect must use a
currently approved Locus. Event history and UI completion hints are not consulted
for this decision.

This function also owns the current practical identity allocation and
relation/discharge admission rules, but performs no IO, persistence, authority
switch, terminal rendering, or writer locking. A caller either receives one
fully admitted typed world or the same error boundary used by the current
practical writer.
-/
def admit? (world : World) (rawDraft : Draft) : Except String Admitted := do
  let draft := canonicalizeDraft rawDraft
  validateDraft draft
  if !world.locusAdmission.admitsEffects draft.effects then
    throw "loam: movement uses a Locus not approved for new publication"
  let eventId := freshRecordEventId world
  let admittedEvent ← match eventWithRequestedId? eventId draft.effects with
    | some admitted => pure admitted
    | none => throw "loam: could not admit generated movement or relation evidence"
  let event := admittedEvent.1
  let newRelations := materializeRelationUnits world eventId draft.relations
  let newDischarges := materializeRelationDischarges eventId draft.discharges
  let fact : Loam.Core.ActualValidityFact String :=
    .base eventId draft.validOn
  let updatedDescriptions := match draft.description with
    | none => world.descriptions
    | some text =>
        (world.descriptions.add? { event := eventId, text := text }).get
          (by simpa [eventId] using freshDescriptionAppend_isSome world text)
  let updatedEvents :=
    (Loam.Core.EventMemory.add? world.events event).get
      (by simpa [event, eventId] using
        freshEventAppend_isSome world event admittedEvent.2)
  let updatedHistory :=
    (world.validity.addFact? fact).get
      (by simpa [fact, eventId] using freshValidityAppend_isSome world draft.validOn)
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
      locusAdmission := world.locusAdmission
    }
    eventId := eventId
  }

end Loam.MovementAdmission
