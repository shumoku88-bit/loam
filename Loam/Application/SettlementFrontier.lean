import Loam.Application.ReplacementFrontier
import Loam.Core.EventMemory
import Loam.Core.Settlement

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Settlement admission and composed frontier

Observation 371 promoted the raw settlement vocabulary while deliberately
leaving semantic admission in the Application layer.

This module is the first executable production boundary over that raw
provenance.

It keeps three responsibilities separate:

1. raw Core values retain facts and append-only revision edges;
2. generic `ReplacementFrontier` selects current correspondence/member rows;
3. this settlement-specific image enforces local and cross-mode conservation.

Superseded correspondence/member rows are retained history and are not
re-admitted as current settlement facts. Structural revision topology still
fails closed.

No persistence, writer, finality publication, automatic matching, FX valuation,
or investment ontology is introduced here.
-/

/-- One settlement commitment after its exact source Effect resolves. -/
structure AdmittedSettlementCommitment where
  commitment : SettlementCommitment
  source : Effect

/--
One current direct settlement correspondence after its target and physical
Effect resolve and its local settlement laws pass.
-/
structure AdmittedSettlementCorrespondence where
  correspondence : SettlementEffectCorrespondence
  target : AdmittedSettlementCommitment
  physical : Effect

/-- One current netting member after its context/target-local laws pass. -/
structure AdmittedSettlementNettingMember where
  member : SettlementNettingMember
  target : AdmittedSettlementCommitment

/--
One admitted netting context with its current members and optional resolved
physical Effect.

`physical = none` is meaningful only for an admitted exact-zero outcome.
-/
structure AdmittedSettlementNettingContext where
  context : SettlementNettingContext
  members : List AdmittedSettlementNettingMember
  physical : Option Effect

/--
One safe in-memory settlement projection.

The image stores only admitted read views. Aggregate net amounts, settled totals,
and outstanding quantities remain derived.
-/
structure AdmittedSettlementImage where
  commitments : List AdmittedSettlementCommitment
  correspondences : List AdmittedSettlementCorrespondence
  netting : List AdmittedSettlementNettingContext

private def magnitudeQuanta (quantity : Quantity) : Int :=
  if quantity.quanta < 0 then -quantity.quanta else quantity.quanta

private def findEffect?
    (events : EventMemory)
    (eventId : EventId)
    (effectKey : EffectKey) : Option Effect := do
  let event ← events.findById? eventId
  event.effects.find? fun effect => effect.key = some effectKey

private def settlementEndpointsAdmissible
    (commitment : SettlementCommitment) : Bool :=
  match commitment.debtor, commitment.creditor with
  | .household, .external _ => true
  | .external _, .household => true
  | _, _ => false

private def physicalSignAgrees
    (commitment : SettlementCommitment)
    (physical : Effect) : Bool :=
  match commitment.debtor, commitment.creditor with
  | .household, .external _ => physical.quantity.quanta < 0
  | .external _, .household => physical.quantity.quanta > 0
  | _, _ => false

private def uniqueCommitmentIds
    (commitments : List SettlementCommitment) : Bool :=
  decide ((commitments.map SettlementCommitment.id).Nodup)

private def uniqueCorrespondenceIds
    (rows : List SettlementEffectCorrespondence) : Bool :=
  decide ((rows.map SettlementEffectCorrespondence.id).Nodup)

private def uniqueContextIds
    (contexts : List SettlementNettingContext) : Bool :=
  decide ((contexts.map SettlementNettingContext.id).Nodup)

private def uniqueMemberIds
    (members : List SettlementNettingMember) : Bool :=
  decide ((members.map SettlementNettingMember.id).Nodup)

private def admitCommitment?
    (events : EventMemory)
    (commitment : SettlementCommitment) :
    Option AdmittedSettlementCommitment := do
  let source ← findEffect? events commitment.sourceEvent commitment.sourceEffect
  if !settlementEndpointsAdmissible commitment then
    none
  else if commitment.quantity.quanta <= 0 then
    none
  else
    some { commitment := commitment, source := source }

private def admitCommitments? :
    EventMemory →
    List SettlementCommitment →
    Option (List AdmittedSettlementCommitment)
  | _, [] => some []
  | events, commitment :: rest => do
      let admitted ← admitCommitment? events commitment
      let later ← admitCommitments? events rest
      some (admitted :: later)

private def findCommitment?
    (commitments : List AdmittedSettlementCommitment)
    (id : SettlementCommitmentId) :
    Option AdmittedSettlementCommitment :=
  commitments.find? fun admitted => admitted.commitment.id = id

private def correspondenceEdges
    (revisions : List SettlementCorrespondenceRevision) :
    List (ReplacementFrontier.Edge SettlementCorrespondenceId) :=
  revisions.map fun revision =>
    { source := revision.target, successor := revision.replacement }

private def correspondencePresent
    (rows : List SettlementEffectCorrespondence)
    (id : SettlementCorrespondenceId) : Bool :=
  rows.any fun row => decide (row.id = id)

private def currentCorrespondences?
    (rows : List SettlementEffectCorrespondence)
    (revisions : List SettlementCorrespondenceRevision) :
    Option (List SettlementEffectCorrespondence) := do
  if !uniqueCorrespondenceIds rows then
    none
  let edges := correspondenceEdges revisions
  if !ReplacementFrontier.structurallyAdmissible
      (correspondencePresent rows) edges then
    none
  some (ReplacementFrontier.frontier
    SettlementEffectCorrespondence.id rows edges)

private def admitCorrespondence?
    (events : EventMemory)
    (commitments : List AdmittedSettlementCommitment)
    (row : SettlementEffectCorrespondence) :
    Option AdmittedSettlementCorrespondence := do
  let target ← findCommitment? commitments row.target
  let physical ← findEffect? events row.event row.effect
  if row.quantity.quanta <= 0 then
    none
  else if physical.measure != target.commitment.measure then
    none
  else if !physicalSignAgrees target.commitment physical then
    none
  else if row.quantity.quanta > target.commitment.quantity.quanta then
    none
  else if row.quantity.quanta > magnitudeQuanta physical.quantity then
    none
  else
    some {
      correspondence := row
      target := target
      physical := physical
    }

private def admitCorrespondences? :
    EventMemory →
    List AdmittedSettlementCommitment →
    List SettlementEffectCorrespondence →
    Option (List AdmittedSettlementCorrespondence)
  | _, _, [] => some []
  | events, commitments, row :: rest => do
      let admitted ← admitCorrespondence? events commitments row
      let later ← admitCorrespondences? events commitments rest
      some (admitted :: later)

private structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving DecidableEq

private def correspondenceAnchor
    (row : AdmittedSettlementCorrespondence) : EffectAnchor := {
  event := row.correspondence.event
  effect := row.correspondence.effect
}

private def directPhysicalTotal
    (rows : List AdmittedSettlementCorrespondence)
    (anchor : EffectAnchor) : Int :=
  rows.foldl
    (fun total row =>
      if correspondenceAnchor row = anchor then
        total + row.correspondence.quantity.quanta
      else
        total)
    0

private def directPhysicalCoverageAdmissible
    (rows : List AdmittedSettlementCorrespondence) : Bool :=
  rows.all fun row =>
    directPhysicalTotal rows (correspondenceAnchor row) <=
      magnitudeQuanta row.physical.quantity

private def memberEdges
    (revisions : List SettlementNettingMemberRevision) :
    List (ReplacementFrontier.Edge SettlementNettingMemberId) :=
  revisions.map fun revision =>
    { source := revision.target, successor := revision.replacement }

private def memberPresent
    (members : List SettlementNettingMember)
    (id : SettlementNettingMemberId) : Bool :=
  members.any fun member => decide (member.id = id)

private def currentMembers?
    (members : List SettlementNettingMember)
    (revisions : List SettlementNettingMemberRevision) :
    Option (List SettlementNettingMember) := do
  if !uniqueMemberIds members then
    none
  let edges := memberEdges revisions
  if !ReplacementFrontier.structurallyAdmissible
      (memberPresent members) edges then
    none
  some (ReplacementFrontier.frontier
    SettlementNettingMember.id members edges)

private def findContext?
    (contexts : List SettlementNettingContext)
    (id : SettlementNettingContextId) :
    Option SettlementNettingContext :=
  contexts.find? fun context => context.id = id

private def admitMember?
    (commitments : List AdmittedSettlementCommitment)
    (contexts : List SettlementNettingContext)
    (member : SettlementNettingMember) :
    Option AdmittedSettlementNettingMember := do
  let context ← findContext? contexts member.context
  let target ← findCommitment? commitments member.target
  if member.quantity.quanta <= 0 then
    none
  else if member.quantity.quanta > target.commitment.quantity.quanta then
    none
  else if target.commitment.measure != context.measure then
    none
  else
    some { member := member, target := target }

private def admitMembers? :
    List AdmittedSettlementCommitment →
    List SettlementNettingContext →
    List SettlementNettingMember →
    Option (List AdmittedSettlementNettingMember)
  | _, _, [] => some []
  | commitments, contexts, member :: rest => do
      let admitted ← admitMember? commitments contexts member
      let later ← admitMembers? commitments contexts rest
      some (admitted :: later)

private def membersForContext
    (members : List AdmittedSettlementNettingMember)
    (context : SettlementNettingContextId) :
    List AdmittedSettlementNettingMember :=
  members.filter fun admitted => admitted.member.context = context

private def memberSignedContribution
    (member : AdmittedSettlementNettingMember) : Int :=
  match member.target.commitment.debtor, member.target.commitment.creditor with
  | .household, .external _ => -member.member.quantity.quanta
  | .external _, .household => member.member.quantity.quanta
  | _, _ => 0

private def signedMemberTotal
    (members : List AdmittedSettlementNettingMember) : Int :=
  members.foldl
    (fun total member => total + memberSignedContribution member)
    0

private def admitNettingContext?
    (events : EventMemory)
    (members : List AdmittedSettlementNettingMember)
    (context : SettlementNettingContext) :
    Option AdmittedSettlementNettingContext := do
  let selected := membersForContext members context.id
  let total := signedMemberTotal selected
  match context.outcome with
  | .zero =>
      if total = 0 then
        some {
          context := context
          members := selected
          physical := none
        }
      else
        none
  | .physical event effect => do
      if total = 0 then
        none
      let physical ← findEffect? events event effect
      if physical.measure != context.measure then
        none
      else if physical.quantity.quanta != total then
        none
      else
        some {
          context := context
          members := selected
          physical := some physical
        }

private def admitNettingContexts? :
    EventMemory →
    List AdmittedSettlementNettingMember →
    List SettlementNettingContext →
    Option (List AdmittedSettlementNettingContext)
  | _, _, [] => some []
  | events, members, context :: rest => do
      let admitted ← admitNettingContext? events members context
      let later ← admitNettingContexts? events members rest
      some (admitted :: later)

private def directTargetTotal
    (rows : List AdmittedSettlementCorrespondence)
    (target : SettlementCommitmentId) : Int :=
  rows.foldl
    (fun total row =>
      if row.correspondence.target = target then
        total + row.correspondence.quantity.quanta
      else
        total)
    0

private def netTargetTotal
    (contexts : List AdmittedSettlementNettingContext)
    (target : SettlementCommitmentId) : Int :=
  contexts.foldl
    (fun total context =>
      context.members.foldl
        (fun subtotal member =>
          if member.member.target = target then
            subtotal + member.member.quantity.quanta
          else
            subtotal)
        total)
    0

private def targetConservationAdmissible
    (commitments : List AdmittedSettlementCommitment)
    (direct : List AdmittedSettlementCorrespondence)
    (netting : List AdmittedSettlementNettingContext) : Bool :=
  commitments.all fun admitted =>
    directTargetTotal direct admitted.commitment.id +
      netTargetTotal netting admitted.commitment.id <=
        admitted.commitment.quantity.quanta

private def netPhysicalAnchor?
    (context : AdmittedSettlementNettingContext) : Option EffectAnchor :=
  match context.context.outcome with
  | .zero => none
  | .physical event effect => some { event := event, effect := effect }

private def netPhysicalAnchors
    (contexts : List AdmittedSettlementNettingContext) : List EffectAnchor :=
  contexts.filterMap netPhysicalAnchor?

private def directUsesAnchor
    (direct : List AdmittedSettlementCorrespondence)
    (anchor : EffectAnchor) : Bool :=
  direct.any fun row => correspondenceAnchor row = anchor

private def physicalConservationAdmissible
    (direct : List AdmittedSettlementCorrespondence)
    (netting : List AdmittedSettlementNettingContext) : Bool :=
  let anchors := netPhysicalAnchors netting
  decide anchors.Nodup &&
    anchors.all fun anchor => !directUsesAnchor direct anchor

/--
Build one safe current settlement image.

Admission order is intentional:

1. admit all unversioned commitments;
2. validate revision topology and select current direct/member frontiers;
3. admit current direct rows and current member rows;
4. derive and admit each netting context outcome;
5. enforce direct physical coverage;
6. enforce cross-mode target and physical conservation.

Superseded correspondence/member payload is retained history but not current
semantic state.
-/
def admitSettlementImage?
    (events : EventMemory)
    (commitments : List SettlementCommitment)
    (correspondences : List SettlementEffectCorrespondence)
    (correspondenceRevisions : List SettlementCorrespondenceRevision)
    (contexts : List SettlementNettingContext)
    (members : List SettlementNettingMember)
    (memberRevisions : List SettlementNettingMemberRevision) :
    Option AdmittedSettlementImage := do
  if !uniqueCommitmentIds commitments || !uniqueContextIds contexts then
    none
  let admittedCommitments ← admitCommitments? events commitments
  let currentDirect ← currentCorrespondences?
    correspondences correspondenceRevisions
  let admittedDirect ← admitCorrespondences?
    events admittedCommitments currentDirect
  if !directPhysicalCoverageAdmissible admittedDirect then
    none
  let currentNetMembers ← currentMembers? members memberRevisions
  let admittedMembers ← admitMembers?
    admittedCommitments contexts currentNetMembers
  let admittedNetting ← admitNettingContexts?
    events admittedMembers contexts
  if !targetConservationAdmissible
      admittedCommitments admittedDirect admittedNetting then
    none
  else if !physicalConservationAdmissible admittedDirect admittedNetting then
    none
  else
    some {
      commitments := admittedCommitments
      correspondences := admittedDirect
      netting := admittedNetting
    }

/-- Exact current settled magnitude for one admitted commitment. -/
def AdmittedSettlementImage.settledQuanta
    (image : AdmittedSettlementImage)
    (target : SettlementCommitmentId) : Int :=
  directTargetTotal image.correspondences target +
    netTargetTotal image.netting target

/--
Exact current outstanding Quantity for one admitted commitment.

The value is derived, never retained. Admission already guarantees settled
attribution does not exceed the commitment Quantity.
-/
def AdmittedSettlementImage.outstanding?
    (image : AdmittedSettlementImage)
    (target : SettlementCommitmentId) : Option Quantity := do
  let commitment ← findCommitment? image.commitments target
  some (Quantity.ofQuanta
    (commitment.commitment.quantity.quanta - image.settledQuanta target))

end Loam.Application
