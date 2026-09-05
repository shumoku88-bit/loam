import Loam.Core.EventMemory
import Loam.Core.OpenRelation

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Open relation admission and frontier

This module is the first executable projection over the raw open-relation
vocabulary promoted after Observation 176.

Raw `RelationUnit` and `RelationRevision` values remain append-only provenance.
This boundary decides only whether their current semantic frontier is safe to
publish. It deliberately introduces no relation memory, persistence topology,
writer protocol, endpoint registry, or universal revision framework.

A failed projection is represented by outer `none`: malformed or conflicting
current evidence is unresolved and must not be mistaken for absence.
-/

/--
One relation unit after its source Effect has resolved and its current semantic
shape has passed admission.

The source Effect is retained in the read-only result so callers can obtain the
existing `MeasureId` without duplicating measure identity in `RelationUnit`.
-/
structure AdmittedRelationUnit where
  relation : RelationUnit
  source : Effect

namespace AdmittedRelationUnit

/-- Measure identity is inherited from the resolved source Effect. -/
def measure (admitted : AdmittedRelationUnit) : MeasureId :=
  admitted.source.measure

end AdmittedRelationUnit

/--
Current source-level answer after a successful frontier projection.

`knownPositive` may contain several independent relation units on one Effect.
`knownNone` is available only when the caller supplies qualified completeness
for the queried source. Uncovered clean absence remains `unknown`.

Unresolved evidence is intentionally not a constructor here: the enclosing
`Option` returns `none` instead, so callers cannot accidentally consume an
ambiguous state as a semantic answer.
-/
inductive RelationSourceState where
  | unknown
  | knownNone
  | knownPositive (relations : List AdmittedRelationUnit)

private def findEffectByKey? : List Effect → EffectKey → Option Effect
  | [], _ => none
  | effect :: rest, key =>
      if effect.key = key then
        some effect
      else
        findEffectByKey? rest key

/-- Resolve the exact source Effect named by one raw relation unit. -/
def relationSourceEffect?
    (events : EventMemory) (relation : RelationUnit) : Option Effect := do
  let event ← EventMemory.findById? events relation.sourceEvent
  findEffectByKey? event.effects relation.sourceEffect

/-- Event-memory representation order cannot change source-Effect resolution. -/
theorem relationSourceEffect?_eventMemory_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (relation : RelationUnit) :
    relationSourceEffect? left relation = relationSourceEffect? right relation := by
  unfold relationSourceEffect?
  rw [EventMemory.findById?_perm left right hPerm relation.sourceEvent]

/--
The currently earned endpoint admission is exactly Household-to-external or
external-to-Household. Endpoint identity itself carries no debtor/creditor role.
-/
def relationEndpointsAdmissible (relation : RelationUnit) : Bool :=
  match relation.debtor, relation.creditor with
  | .household, .external _ => true
  | .external _, .household => true
  | _, _ => false

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then
    -quantity.quanta
  else
    quantity.quanta

/--
Admit one raw relation unit only when its current semantic shape is safe.

Admission requires:

- the exact `(EventId, EffectKey)` source to resolve;
- one Household endpoint and one external endpoint;
- a strictly positive relation quantity;
- relation magnitude no greater than the absolute source-Effect magnitude.

The collection-level frontier separately enforces the Observation 173 law that
the total current relation-plane coverage on one source Effect cannot exceed the
source magnitude.

Source sign itself has no relation-direction meaning.
-/
def admitRelationUnit?
    (events : EventMemory) (relation : RelationUnit) : Option AdmittedRelationUnit := do
  let source ← relationSourceEffect? events relation
  if !relationEndpointsAdmissible relation then
    none
  else if relation.quantity.quanta ≤ 0 then
    none
  else if relation.quantity.quanta > magnitudeQuanta source.quantity then
    none
  else
    some { relation := relation, source := source }

/-- A missing source reference can never enter the admitted positive view. -/
@[simp] theorem admitRelationUnit?_missing_source
    (events : EventMemory)
    (relation : RelationUnit)
    (hMissing : relationSourceEffect? events relation = none) :
    admitRelationUnit? events relation = none := by
  simp [admitRelationUnit?, hMissing]

/-- Single-unit admission is independent of EventMemory representation order. -/
theorem admitRelationUnit?_eventMemory_perm
    (left right : EventMemory)
    (hPerm : left.events.Perm right.events)
    (relation : RelationUnit) :
    admitRelationUnit? left relation = admitRelationUnit? right relation := by
  unfold admitRelationUnit?
  rw [relationSourceEffect?_eventMemory_perm left right hPerm relation]

private def findRelationById? :
    List RelationUnit → RelationUnitId → Option RelationUnit
  | [], _ => none
  | relation :: rest, id =>
      if relation.id = id then
        some relation
      else
        findRelationById? rest id

private def uniqueUnitIds : List RelationUnit → Bool
  | [] => true
  | relation :: rest =>
      !(rest.any fun other => decide (other.id = relation.id)) &&
        uniqueUnitIds rest

private def uniqueRevisionIds : List RelationRevision → Bool
  | [] => true
  | revision :: rest =>
      !(rest.any fun other => decide (other.id = revision.id)) &&
        uniqueRevisionIds rest

private def uniqueRevisionTargets : List RelationRevision → Bool
  | [] => true
  | revision :: rest =>
      !(rest.any fun other => decide (other.target = revision.target)) &&
        uniqueRevisionTargets rest

private def uniqueRevisionReplacements : List RelationRevision → Bool
  | [] => true
  | revision :: rest =>
      match revision.replacement with
      | none => uniqueRevisionReplacements rest
      | some replacement =>
          !(rest.any fun other => decide (other.replacement = some replacement)) &&
            uniqueRevisionReplacements rest

private def closedRevisionReferences
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : Bool :=
  revisions.all fun revision =>
    match findRelationById? relations revision.target with
    | none => false
    | some _ =>
        match revision.replacement with
        | none => true
        | some replacement => (findRelationById? relations replacement).isSome

private def preservesRevisionSource
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : Bool :=
  revisions.all fun revision =>
    match findRelationById? relations revision.target with
    | none => false
    | some target =>
        match revision.replacement with
        | none => true
        | some replacementId =>
            match findRelationById? relations replacementId with
            | none => false
            | some replacement =>
                decide
                  (target.sourceEvent = replacement.sourceEvent ∧
                    target.sourceEffect = replacement.sourceEffect)

private def nextReplacement? :
    List RelationRevision → RelationUnitId → Option RelationUnitId
  | [], _ => none
  | revision :: rest, id =>
      if revision.target = id then
        revision.replacement
      else
        nextReplacement? rest id

private def pathAcyclicFrom
    (revisions : List RelationRevision)
    (start : RelationUnitId) : Nat → RelationUnitId → Bool
  | 0, _ => true
  | fuel + 1, current =>
      match nextReplacement? revisions current with
      | none => true
      | some next =>
          if next = start then
            false
          else
            pathAcyclicFrom revisions start fuel next

private def revisionsAcyclic (revisions : List RelationRevision) : Bool :=
  revisions.all fun revision =>
    pathAcyclicFrom revisions revision.target revisions.length revision.target

private def targetUsed
    (revisions : List RelationRevision) (id : RelationUnitId) : Bool :=
  revisions.any fun revision => decide (revision.target = id)

private def relationFrontierUnits
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : List RelationUnit :=
  relations.filter fun relation => !(targetUsed revisions relation.id)

private def admitAll?
    (events : EventMemory) : List RelationUnit → Option (List AdmittedRelationUnit)
  | [] => some []
  | relation :: rest => do
      let admitted ← admitRelationUnit? events relation
      let later ← admitAll? events rest
      some (admitted :: later)

private def currentUnitsAdmissible
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : Bool :=
  (relationFrontierUnits relations revisions).all fun relation =>
    (admitRelationUnit? events relation).isSome

private def sameRelationSource (left right : RelationUnit) : Bool :=
  decide
    (left.sourceEvent = right.sourceEvent ∧
      left.sourceEffect = right.sourceEffect)

private def sameRawSource
    (sourceEvent : EventId)
    (sourceEffect : EffectKey)
    (relation : RelationUnit) : Bool :=
  decide
    (relation.sourceEvent = sourceEvent ∧
      relation.sourceEffect = sourceEffect)

private def sourceRelationFrontierUnits
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : List RelationUnit :=
  (relationFrontierUnits relations revisions).filter
    (sameRawSource sourceEvent sourceEffect)

private def sourceCurrentUnitsAdmissible
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : Bool :=
  (sourceRelationFrontierUnits relations revisions sourceEvent sourceEffect).all
    fun relation => (admitRelationUnit? events relation).isSome

private def currentCoverageFor
    (current : List RelationUnit)
    (sourceRelation : RelationUnit) : Int :=
  current.foldl
    (fun total relation =>
      if sameRelationSource relation sourceRelation then
        total + relation.quantity.quanta
      else
        total)
    0

/--
Observation 173 requires relation units to form only a partial partition inside
the relation plane: several current units may share one source Effect, but their
combined exact quantity may not exceed that source magnitude.
-/
private def currentRelationCoverageBounded
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : Bool :=
  let current := relationFrontierUnits relations revisions
  current.all fun relation =>
    match relationSourceEffect? events relation with
    | none => false
    | some source =>
        currentCoverageFor current relation <= magnitudeQuanta source.quantity

private def sourceRelationCoverageBounded
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : Bool :=
  let current := sourceRelationFrontierUnits
    relations revisions sourceEvent sourceEffect
  current.all fun relation =>
    match relationSourceEffect? events relation with
    | none => false
    | some source =>
        currentCoverageFor current relation <= magnitudeQuanta source.quantity

/--
Global relation/revision structure that must remain coherent even when some raw
relation units are not yet source-admissible.

Identity uniqueness, revision reference closure, source-preserving replacement,
and acyclicity are properties of retained provenance itself. They are therefore
checked across the whole raw collection rather than weakened by one source query.
-/
private def relationFrontierStructurallyAdmissible
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : Bool :=
  uniqueUnitIds relations &&
    uniqueRevisionIds revisions &&
    uniqueRevisionTargets revisions &&
    uniqueRevisionReplacements revisions &&
    closedRevisionReferences relations revisions &&
    preservesRevisionSource relations revisions &&
    revisionsAcyclic revisions

/--
Whether one raw relation/revision collection has one safe append-only frontier.

The whole-frontier boundary rejects repeated relation/revision identity, sibling
revisions of one target, shared positive replacements, open revision references,
source-changing positive replacement, revision cycles, malformed current
relation units, and aggregate current relation coverage beyond a source Effect's
exact magnitude. Historical units that have been explicitly revised remain raw
provenance and need not themselves satisfy the current positive admission law.
-/
def relationFrontierAdmissible
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : Bool :=
  relationFrontierStructurallyAdmissible relations revisions &&
    currentUnitsAdmissible events relations revisions &&
    currentRelationCoverageBounded events relations revisions

/--
Return the admitted current positive frontier, or `none` when the whole raw
frontier cannot currently be resolved safely.

Representation list order is retained only for deterministic output. Revision
targets decide currentness; no list position acquires authority. A pre-Event raw
relation may therefore make this whole-frontier view unresolved until its source
Event appears; source-specific queries use a narrower projection below.
-/
def admittedRelationFrontier?
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision) : Option (List AdmittedRelationUnit) :=
  if relationFrontierAdmissible events relations revisions then
    admitAll? events (relationFrontierUnits relations revisions)
  else
    none

/--
Admit only the current units attached to one queried source while retaining the
global identity/revision invariants of the raw relation family.

This is the executable counterpart of Observation 176's source-local status
projection and Observation 177's permitted pre-Event crash residue. An orphan
raw relation for another source remains inert instead of poisoning an unrelated
Effect query. Global identity collisions and malformed revision structure still
fail closed because they make retained provenance itself ambiguous.
-/
private def admittedRelationSourceFrontier?
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : Option (List AdmittedRelationUnit) :=
  if relationFrontierStructurallyAdmissible relations revisions &&
      sourceCurrentUnitsAdmissible
        events relations revisions sourceEvent sourceEffect &&
      sourceRelationCoverageBounded
        events relations revisions sourceEvent sourceEffect then
    admitAll? events
      (sourceRelationFrontierUnits relations revisions sourceEvent sourceEffect)
  else
    none

/--
Project one source Effect to `knownPositive`, `knownNone`, or `unknown`.

`completeAt` is supplied by the caller because no concrete relation completeness
writer/cutover has yet been promoted. This function never invents completeness
from storage order or from the mere presence of a retraction.

Only current units attached to the queried `(EventId, EffectKey)` are subjected
to source admission and relation-plane coverage. Thus unrelated pre-Event raw
residue stays inert. Global relation/revision identity and structural invariants
remain whole-family checks, so ambiguity is not hidden merely because it sits on
another source coordinate.

A malformed current raw relation on the queried source still returns outer
`none` even when `completeAt` says the source is covered; it cannot be filtered
away and mispublished as `knownNone`.
-/
def currentRelationState?
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (completeAt : EventId → EffectKey → Bool)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey) : Option RelationSourceState := do
  let event ← EventMemory.findById? events sourceEvent
  let _source ← findEffectByKey? event.effects sourceEffect
  let current ← admittedRelationSourceFrontier?
    events relations revisions sourceEvent sourceEffect
  if current.isEmpty then
    if completeAt sourceEvent sourceEffect then
      some .knownNone
    else
      some .unknown
  else
    some (.knownPositive current)

/-- A missing queried Event cannot be turned into known absence by completeness. -/
@[simp] theorem currentRelationState?_missing_event
    (events : EventMemory)
    (relations : List RelationUnit)
    (revisions : List RelationRevision)
    (completeAt : EventId → EffectKey → Bool)
    (sourceEvent : EventId)
    (sourceEffect : EffectKey)
    (hMissing : EventMemory.findById? events sourceEvent = none) :
    currentRelationState?
      events relations revisions completeAt sourceEvent sourceEffect = none := by
  simp [currentRelationState?, hMissing]

end Loam.Application
