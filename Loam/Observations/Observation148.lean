import Loam.Core.ActualValidity
import Loam.Core.EventCorrection
import Loam.Core.EventDescription

namespace Loam.Observation148

open Loam.Core

set_option autoImplicit false

/-!
# Observation 148 — compact Event / Effect identity re-keying

Observation 146 established that Event and Effect identity are structural while
migration-shaped token spelling is representation. Observation 147 then removed
one identity family that was not structural at the initial ActualValidity root.

This observation asks the remaining narrower question:

> Can a finite canonical generation replace long migration-issued EventId and
> EffectKey spellings with compact opaque keys when every identity-bearing
> reference is translated by one complete injective map?

The candidate does not derive identity from content, date, locus, quantity, or
list position. Compact numbers are opaque labels only. Their numeric order has
no temporal or authority meaning.

This is an observation-local qualification. It does not rewrite canonical data
or add a production migration surface.
-/

structure EventMapEntry where
  old : EventId
  new : EventId
deriving Repr, DecidableEq

structure EffectMapEntry where
  old : EffectKey
  new : EffectKey
deriving Repr, DecidableEq

structure RekeyPlan where
  events : List EventMapEntry
  effects : List EffectMapEntry
deriving Repr, DecidableEq

private def translateEvent? : List EventMapEntry → EventId → Option EventId
  | [], _ => none
  | entry :: rest, id =>
      if entry.old = id then some entry.new else translateEvent? rest id

private def translateEffect? : List EffectMapEntry → EffectKey → Option EffectKey
  | [], _ => none
  | entry :: rest, key =>
      if entry.old = key then some entry.new else translateEffect? rest key

private def eventPlanAdmissible
    (plan : RekeyPlan) (source : List EventId) : Bool :=
  (source.all fun id => (translateEvent? plan.events id).isSome) &&
  decide (plan.events.length = source.length) &&
  decide ((plan.events.map EventMapEntry.old).Nodup) &&
  decide ((plan.events.map EventMapEntry.new).Nodup)

private def effectPlanAdmissible
    (plan : RekeyPlan) (source : List EffectKey) : Bool :=
  (source.all fun key => (translateEffect? plan.effects key).isSome) &&
  decide (plan.effects.length = source.length) &&
  decide ((plan.effects.map EffectMapEntry.old).Nodup) &&
  decide ((plan.effects.map EffectMapEntry.new).Nodup)

private def planAdmissible
    (plan : RekeyPlan)
    (sourceEvents : List EventId)
    (sourceEffects : List EffectKey) : Bool :=
  eventPlanAdmissible plan sourceEvents &&
  effectPlanAdmissible plan sourceEffects

private def translateCorrection?
    (plan : RekeyPlan) (correction : EventCorrection) : Option EventCorrection := do
  let target ← translateEvent? plan.events correction.target
  let replacement ← translateEvent? plan.events correction.replacement
  pure { id := correction.id, target := target, replacement := replacement }

private def translateValidity?
    {Time : Type}
    (plan : RekeyPlan) (entry : ActualValidity Time) : Option (ActualValidity Time) := do
  let event ← translateEvent? plan.events entry.event
  pure { event := event, validOn := entry.validOn }

private def translateDescription?
    (plan : RekeyPlan) (entry : EventDescription) : Option EventDescription := do
  let event ← translateEvent? plan.events entry.event
  pure { event := event, text := entry.text }

structure EffectReference where
  effect : EffectKey
  label : String
deriving Repr, DecidableEq

private def translateEffectReference?
    (plan : RekeyPlan) (reference : EffectReference) : Option EffectReference := do
  let effect ← translateEffect? plan.effects reference.effect
  pure { effect := effect, label := reference.label }

structure EffectPayload where
  locus : LocusId
  measure : MeasureId
  quanta : Int
deriving Repr, DecidableEq

private def findEffectPayloadIn? : List Effect → EffectKey → Option EffectPayload
  | [], _ => none
  | effect :: rest, key =>
      if effect.key = key then
        some {
          locus := effect.locus
          measure := effect.measure
          quanta := effect.quantity.quanta
        }
      else
        findEffectPayloadIn? rest key

private def findEffectPayloadAcross? : List Event → EffectKey → Option EffectPayload
  | [], _ => none
  | event :: rest, key =>
      match findEffectPayloadIn? event.effects key with
      | some payload => some payload
      | none => findEffectPayloadAcross? rest key

private def findDescriptionText? : List EventDescription → EventId → Option String
  | [], _ => none
  | entry :: rest, event =>
      if entry.event = event then some entry.text else findDescriptionText? rest event

/-! ## Public synthetic old and compact generations -/

private def oldEventA : EventId :=
  ⟨"hpev-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"⟩

private def oldEventB : EventId :=
  ⟨"hpev-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"⟩

private def compactEventA : EventId := ⟨"e1"⟩
private def compactEventB : EventId := ⟨"e2"⟩

private def oldEffectA1 : EffectKey :=
  ⟨"hpef-11111111111111111111111111111111"⟩

private def oldEffectA2 : EffectKey :=
  ⟨"hpef-22222222222222222222222222222222"⟩

private def oldEffectB1 : EffectKey :=
  ⟨"hpef-33333333333333333333333333333333"⟩

private def compactEffectA1 : EffectKey := ⟨"f1"⟩
private def compactEffectA2 : EffectKey := ⟨"f2"⟩
private def compactEffectB1 : EffectKey := ⟨"f3"⟩

private def wallet : LocusId := ⟨"wallet"⟩
private def food : LocusId := ⟨"food"⟩
private def transport : LocusId := ⟨"transport"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

private def oldA : Event :=
  { id := oldEventA
    effects :=
      [ Effect.ofQuantity oldEffectA1 wallet jpy (Quantity.ofQuanta (-100)),
        Effect.ofQuantity oldEffectA2 food jpy (Quantity.ofQuanta 100) ]
    keyNodup := by decide }

private def oldB : Event :=
  { id := oldEventB
    effects :=
      [Effect.ofQuantity oldEffectB1 transport jpy (Quantity.ofQuanta 30)]
    keyNodup := by decide }

private def compactA : Event :=
  { id := compactEventA
    effects :=
      [ Effect.ofQuantity compactEffectA1 wallet jpy (Quantity.ofQuanta (-100)),
        Effect.ofQuantity compactEffectA2 food jpy (Quantity.ofQuanta 100) ]
    keyNodup := by decide }

private def compactB : Event :=
  { id := compactEventB
    effects :=
      [Effect.ofQuantity compactEffectB1 transport jpy (Quantity.ofQuanta 30)]
    keyNodup := by decide }

private def oldMemory : EventMemory :=
  { events := [oldA, oldB], idNodup := by decide }

private def compactMemory : EventMemory :=
  { events := [compactA, compactB], idNodup := by decide }

private def sourceEventIds : List EventId := [oldEventA, oldEventB]
private def sourceEffectKeys : List EffectKey := [oldEffectA1, oldEffectA2, oldEffectB1]

private def completePlan : RekeyPlan :=
  { events :=
      [ { old := oldEventA, new := compactEventA },
        { old := oldEventB, new := compactEventB } ]
    effects :=
      [ { old := oldEffectA1, new := compactEffectA1 },
        { old := oldEffectA2, new := compactEffectA2 },
        { old := oldEffectB1, new := compactEffectB1 } ] }

private def eventCollisionPlan : RekeyPlan :=
  { completePlan with
    events :=
      [ { old := oldEventA, new := compactEventA },
        { old := oldEventB, new := compactEventA } ] }

private def effectCollisionPlan : RekeyPlan :=
  { completePlan with
    effects :=
      [ { old := oldEffectA1, new := compactEffectA1 },
        { old := oldEffectA2, new := compactEffectA1 },
        { old := oldEffectB1, new := compactEffectB1 } ] }

private def incompletePlan : RekeyPlan :=
  { completePlan with
    events := [{ old := oldEventA, new := compactEventA }] }

/-- A complete one-to-one finite map is admitted. -/
theorem complete_injective_plan_admitted :
    planAdmissible completePlan sourceEventIds sourceEffectKeys = true := by
  decide

/-- Event identity collision is rejected before any canonical rewrite. -/
theorem event_collision_refused :
    planAdmissible eventCollisionPlan sourceEventIds sourceEffectKeys = false := by
  decide

/-- Effect identity collision is likewise rejected. -/
theorem effect_collision_refused :
    planAdmissible effectCollisionPlan sourceEventIds sourceEffectKeys = false := by
  decide

/-- A map that omits one source Event is not a re-key plan. -/
theorem incomplete_event_map_refused :
    planAdmissible incompletePlan sourceEventIds sourceEffectKeys = false := by
  decide

/-! ## Payload and query preservation -/

/-- EventId and EffectKey spelling do not change exact quantity projection. -/
theorem recorded_quantity_projection_preserved :
    EventMemory.quantityAtRecorded oldMemory wallet jpy =
      EventMemory.quantityAtRecorded compactMemory wallet jpy ∧
    EventMemory.quantityAtRecorded oldMemory food jpy =
      EventMemory.quantityAtRecorded compactMemory food jpy ∧
    EventMemory.quantityAtRecorded oldMemory transport jpy =
      EventMemory.quantityAtRecorded compactMemory transport jpy := by
  decide

/-- Translating an Effect endpoint preserves the selected physical payload. -/
theorem effect_reference_payload_preserved :
    findEffectPayloadAcross? oldMemory.events oldEffectA2 =
      findEffectPayloadAcross? compactMemory.events compactEffectA2 := by
  decide

private def oldValidities : ActualValidityMemory String :=
  { entries :=
      [ { event := oldEventA, validOn := "2026-09-01" },
        { event := oldEventB, validOn := "2026-09-02" } ]
    eventNodup := by decide }

private def compactValidities : ActualValidityMemory String :=
  { entries :=
      [ { event := compactEventA, validOn := "2026-09-01" },
        { event := compactEventB, validOn := "2026-09-02" } ]
    eventNodup := by decide }

private def oldDescriptions : List EventDescription :=
  [ { event := oldEventA, text := "groceries" },
    { event := oldEventB, text := "train" } ]

private def compactDescriptions : List EventDescription :=
  [ { event := compactEventA, text := "groceries" },
    { event := compactEventB, text := "train" } ]

private def oldCorrection : EventCorrection :=
  { id := ⟨"correction-1"⟩, target := oldEventA, replacement := oldEventB }

private def compactCorrection : EventCorrection :=
  { id := ⟨"correction-1"⟩, target := compactEventA, replacement := compactEventB }

private def oldEffectReference : EffectReference :=
  { effect := oldEffectA2, label := "selected-effect" }

private def compactEffectReference : EffectReference :=
  { effect := compactEffectA2, label := "selected-effect" }

/-- Date and description values survive when their Event endpoints are translated. -/
theorem event_attached_evidence_preserved :
    ActualValidityMemory.findByEventId? oldValidities oldEventA =
      ActualValidityMemory.findByEventId? compactValidities compactEventA ∧
    ActualValidityMemory.findByEventId? oldValidities oldEventB =
      ActualValidityMemory.findByEventId? compactValidities compactEventB ∧
    findDescriptionText? oldDescriptions oldEventA =
      findDescriptionText? compactDescriptions compactEventA ∧
    findDescriptionText? oldDescriptions oldEventB =
      findDescriptionText? compactDescriptions compactEventB := by
  decide

/-- Event and Effect relation endpoints translate through the same finite plan. -/
theorem relation_endpoints_translate_exactly :
    translateCorrection? completePlan oldCorrection = some compactCorrection ∧
    translateEffectReference? completePlan oldEffectReference = some compactEffectReference := by
  decide

/-- Correction topology remains projectable after both endpoints are re-keyed. -/
theorem correction_topology_preserved :
    (EventCorrection.project? oldMemory oldCorrection).isSome = true ∧
    (EventCorrection.project? compactMemory compactCorrection).isSome = true := by
  decide

/-- Re-keying the authority without translating a retained relation is not equivalent. -/
theorem untranslated_event_relation_fails_closed :
    (EventCorrection.project? compactMemory oldCorrection).isSome = false := by
  decide

/--
Stable identity remains observable. Old keys stop selecting after the re-key and
callers must use the translated identity. This is an isomorphism, not a claim
that identity can be erased.
-/
theorem identity_observing_query_requires_translation :
    (EventMemory.findById? oldMemory oldEventA).isSome = true ∧
    (EventMemory.findById? compactMemory oldEventA).isSome = false ∧
    (EventMemory.findById? compactMemory compactEventA).isSome = true := by
  decide

/-! ## Physical cutover boundary -/

inductive GenerationImage
  | old
  | compact
  deriving Repr, DecidableEq

inductive ReaderOutcome
  | oldCorrect
  | failClosed
  | compactCorrect
  | falseReadable
  deriving Repr, DecidableEq

structure RekeyWorld where
  events : GenerationImage
  validities : GenerationImage
  descriptions : GenerationImage
  corrections : GenerationImage
  effectEndpoints : GenerationImage
  deriving Repr, DecidableEq

inductive CutoverPhase
  | initial
  | validityGuardPublished
  | descriptionsPublished
  | correctionsPublished
  | effectEndpointsPublished
  | eventAuthorityCommitted
  deriving Repr, DecidableEq

/--
Dependent identity-bearing evidence is prepared before EventMemory, with
ActualValidity first as the availability guard. EventMemory is the authority
commit point. This is the compact-rekey specialization of the already-qualified
auxiliary-first destructive cutover shape from Observation 145.
-/
def worldAt : CutoverPhase → RekeyWorld
  | .initial => ⟨.old, .old, .old, .old, .old⟩
  | .validityGuardPublished => ⟨.old, .compact, .old, .old, .old⟩
  | .descriptionsPublished => ⟨.old, .compact, .compact, .old, .old⟩
  | .correctionsPublished => ⟨.old, .compact, .compact, .compact, .old⟩
  | .effectEndpointsPublished => ⟨.old, .compact, .compact, .compact, .compact⟩
  | .eventAuthorityCommitted => ⟨.compact, .compact, .compact, .compact, .compact⟩

/--
The old complete generation is readable, every qualified pre-commit mixed state
is unavailable, and only the full compact generation becomes readable after the
Event authority commit.
-/
def readerOutcome : RekeyWorld → ReaderOutcome
  | ⟨.old, .old, .old, .old, .old⟩ => .oldCorrect
  | ⟨.old, .compact, .old, .old, .old⟩ => .failClosed
  | ⟨.old, .compact, .compact, .old, .old⟩ => .failClosed
  | ⟨.old, .compact, .compact, .compact, .old⟩ => .failClosed
  | ⟨.old, .compact, .compact, .compact, .compact⟩ => .failClosed
  | ⟨.compact, .compact, .compact, .compact, .compact⟩ => .compactCorrect
  | _ => .falseReadable

/-- No state reachable in the qualified order is a mixed readable generation. -/
theorem reachable_cutover_never_false_readable (phase : CutoverPhase) :
    readerOutcome (worldAt phase) ≠ .falseReadable := by
  cases phase <;> decide

/-- The authority commit exposes only the complete compact identity generation. -/
theorem event_authority_commit_completes_rekey :
    readerOutcome (worldAt .eventAuthorityCommitted) = .compactCorrect := by
  rfl

end Loam.Observation148
