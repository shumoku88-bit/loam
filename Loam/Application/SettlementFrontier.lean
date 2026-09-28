import Loam.Application.ReplacementFrontier
import Loam.ActualDate
import Loam.Core.EventMemory
import Loam.Core.Settlement

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Settlement admission and composed frontier

`Loam.Core.Settlement` owns the raw settlement vocabulary while this module
owns semantic admission in the Application layer.

This module is the executable production boundary over that raw provenance.

It keeps three responsibilities separate:

1. raw Core values retain facts and append-only revision edges;
2. settlement-specific commitment revision semantics select current commitments;
3. generic `ReplacementFrontier` selects current correspondence/member rows;
4. this settlement-specific image re-resolves historical commitment targets and
   enforces local and cross-mode conservation.

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

/--
One current non-settlement extinguishment after its historical commitment target
resolves through commitment correction lineage and its local laws pass.
-/
structure AdmittedSettlementExtinguishment where
  extinguishment : SettlementCommitmentExtinguishment
  target : AdmittedSettlementCommitment

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
  extinguishments : List AdmittedSettlementExtinguishment := []
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

private def commitmentPresent
    (commitments : List SettlementCommitment)
    (id : SettlementCommitmentId) : Bool :=
  commitments.any fun commitment => decide (commitment.id = id)

private def commitmentRevisionTargetsUnique
    (revisions : List SettlementCommitmentRevision) : Bool :=
  decide ((revisions.map SettlementCommitmentRevision.target).Nodup)

private def commitmentEdges
    (revisions : List SettlementCommitmentRevision) :
    List (ReplacementFrontier.Edge SettlementCommitmentId) :=
  revisions.filterMap fun revision =>
    match revision.replacement with
    | none => none
    | some replacement =>
        some { source := revision.target, successor := replacement }

private def commitmentReferencesClosed
    (commitments : List SettlementCommitment)
    (revisions : List SettlementCommitmentRevision) : Bool :=
  revisions.all fun revision =>
    commitmentPresent commitments revision.target &&
      match revision.replacement with
      | none => true
      | some replacement => commitmentPresent commitments replacement

private def commitmentRetracted
    (revisions : List SettlementCommitmentRevision)
    (id : SettlementCommitmentId) : Bool :=
  revisions.any fun revision =>
    decide (revision.target = id) && revision.replacement.isNone

private def currentCommitments?
    (commitments : List SettlementCommitment)
    (revisions : List SettlementCommitmentRevision) :
    Option (List SettlementCommitment) := do
  if !uniqueCommitmentIds commitments then
    none
  else if !commitmentRevisionTargetsUnique revisions then
    none
  else if !commitmentReferencesClosed commitments revisions then
    none
  else
    let edges := commitmentEdges revisions
    if !ReplacementFrontier.structurallyAdmissible
        (commitmentPresent commitments) edges then
      none
    else
      let positiveFrontier :=
        ReplacementFrontier.frontier SettlementCommitment.id commitments edges
      some (positiveFrontier.filter fun commitment =>
        !commitmentRetracted revisions commitment.id)

private def nextCommitmentId?
    (edges : List (ReplacementFrontier.Edge SettlementCommitmentId))
    (id : SettlementCommitmentId) : Option SettlementCommitmentId :=
  match edges.find? fun edge => edge.source = id with
  | none => none
  | some edge => some edge.successor

private def terminalCommitmentIdWithin
    (edges : List (ReplacementFrontier.Edge SettlementCommitmentId)) :
    Nat → SettlementCommitmentId → Option SettlementCommitmentId
  | 0, _ => none
  | fuel + 1, current =>
      match nextCommitmentId? edges current with
      | none => some current
      | some next => terminalCommitmentIdWithin edges fuel next

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

private def resolveCommitment?
    (commitments : List AdmittedSettlementCommitment)
    (revisions : List SettlementCommitmentRevision)
    (historical : SettlementCommitmentId) :
    Option AdmittedSettlementCommitment := do
  let edges := commitmentEdges revisions
  let terminal ← terminalCommitmentIdWithin edges (edges.length + 1) historical
  if commitmentRetracted revisions terminal then
    none
  else
    findCommitment? commitments terminal

private def uniqueExtinguishmentIds
    (rows : List SettlementCommitmentExtinguishment) : Bool :=
  decide ((rows.map SettlementCommitmentExtinguishment.id).Nodup)

private def extinguishmentPresent
    (rows : List SettlementCommitmentExtinguishment)
    (id : SettlementExtinguishmentId) : Bool :=
  rows.any fun row => decide (row.id = id)

private def extinguishmentRevisionTargetsUnique
    (revisions : List SettlementExtinguishmentRevision) : Bool :=
  decide ((revisions.map SettlementExtinguishmentRevision.target).Nodup)

private def extinguishmentEdges
    (revisions : List SettlementExtinguishmentRevision) :
    List (ReplacementFrontier.Edge SettlementExtinguishmentId) :=
  revisions.filterMap fun revision =>
    match revision.replacement with
    | none => none
    | some replacement =>
        some { source := revision.target, successor := replacement }

private def extinguishmentReferencesClosed
    (rows : List SettlementCommitmentExtinguishment)
    (revisions : List SettlementExtinguishmentRevision) : Bool :=
  revisions.all fun revision =>
    extinguishmentPresent rows revision.target &&
      match revision.replacement with
      | none => true
      | some replacement => extinguishmentPresent rows replacement

private def extinguishmentRetracted
    (revisions : List SettlementExtinguishmentRevision)
    (id : SettlementExtinguishmentId) : Bool :=
  revisions.any fun revision =>
    decide (revision.target = id) && revision.replacement.isNone

private def currentExtinguishments?
    (rows : List SettlementCommitmentExtinguishment)
    (revisions : List SettlementExtinguishmentRevision) :
    Option (List SettlementCommitmentExtinguishment) := do
  if !uniqueExtinguishmentIds rows then
    none
  else if !extinguishmentRevisionTargetsUnique revisions then
    none
  else if !extinguishmentReferencesClosed rows revisions then
    none
  else
    let edges := extinguishmentEdges revisions
    if !ReplacementFrontier.structurallyAdmissible
        (extinguishmentPresent rows) edges then
      none
    else
      let positiveFrontier :=
        ReplacementFrontier.frontier SettlementCommitmentExtinguishment.id rows edges
      some (positiveFrontier.filter fun row =>
        !extinguishmentRetracted revisions row.id)

private def admitExtinguishment?
    (commitments : List AdmittedSettlementCommitment)
    (commitmentRevisions : List SettlementCommitmentRevision)
    (row : SettlementCommitmentExtinguishment) :
    Option AdmittedSettlementExtinguishment := do
  let target ← resolveCommitment? commitments commitmentRevisions row.target
  if row.quantity.quanta <= 0 then
    none
  else if let some effectiveOn := row.effectiveOn then
    if !Loam.ActualDate.validIsoDate effectiveOn then
      none
    else
      some { extinguishment := row, target := target }
  else
    some { extinguishment := row, target := target }

private def admitExtinguishments? :
    List AdmittedSettlementCommitment →
    List SettlementCommitmentRevision →
    List SettlementCommitmentExtinguishment →
    Option (List AdmittedSettlementExtinguishment)
  | _, _, [] => some []
  | commitments, commitmentRevisions, row :: rest => do
      let admitted ← admitExtinguishment? commitments commitmentRevisions row
      let later ← admitExtinguishments? commitments commitmentRevisions rest
      some (admitted :: later)

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
    (commitmentRevisions : List SettlementCommitmentRevision)
    (row : SettlementEffectCorrespondence) :
    Option AdmittedSettlementCorrespondence := do
  let target ← resolveCommitment? commitments commitmentRevisions row.target
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
    List SettlementCommitmentRevision →
    List SettlementEffectCorrespondence →
    Option (List AdmittedSettlementCorrespondence)
  | _, _, _, [] => some []
  | events, commitments, commitmentRevisions, row :: rest => do
      let admitted ← admitCorrespondence?
        events commitments commitmentRevisions row
      let later ← admitCorrespondences?
        events commitments commitmentRevisions rest
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
    (commitmentRevisions : List SettlementCommitmentRevision)
    (contexts : List SettlementNettingContext)
    (member : SettlementNettingMember) :
    Option AdmittedSettlementNettingMember := do
  let context ← findContext? contexts member.context
  let target ← resolveCommitment? commitments commitmentRevisions member.target
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
    List SettlementCommitmentRevision →
    List SettlementNettingContext →
    List SettlementNettingMember →
    Option (List AdmittedSettlementNettingMember)
  | _, _, _, [] => some []
  | commitments, commitmentRevisions, contexts, member :: rest => do
      let admitted ← admitMember?
        commitments commitmentRevisions contexts member
      let later ← admitMembers?
        commitments commitmentRevisions contexts rest
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
      if row.target.commitment.id = target then
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
          if member.target.commitment.id = target then
            subtotal + member.member.quantity.quanta
          else
            subtotal)
        total)
    0

private def extinguishmentTargetTotal
    (rows : List AdmittedSettlementExtinguishment)
    (target : SettlementCommitmentId) : Int :=
  rows.foldl
    (fun total row =>
      if row.target.commitment.id = target then
        total + row.extinguishment.quantity.quanta
      else
        total)
    0

private def targetConservationAdmissible
    (commitments : List AdmittedSettlementCommitment)
    (direct : List AdmittedSettlementCorrespondence)
    (netting : List AdmittedSettlementNettingContext)
    (extinguishments : List AdmittedSettlementExtinguishment) : Bool :=
  commitments.all fun admitted =>
    directTargetTotal direct admitted.commitment.id +
      netTargetTotal netting admitted.commitment.id +
      extinguishmentTargetTotal extinguishments admitted.commitment.id <=
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

1. validate commitment revision topology and select the current commitment frontier;
2. admit only current commitment payloads;
3. validate extinguishment/correspondence/member revision topology and select current row frontiers;
4. resolve each historical dependent target through commitment correction lineage;
5. re-admit current extinguishment/direct/member rows against the resolved current commitment;
6. derive and admit each netting context outcome;
7. enforce direct physical coverage;
8. enforce committed = settled + extinguished + outstanding conservation;
9. enforce cross-mode physical conservation.

Superseded correspondence/member payload is retained history but not current
semantic state.
-/
def admitSettlementImage?
    (events : EventMemory)
    (commitments : List SettlementCommitment)
    (commitmentRevisions : List SettlementCommitmentRevision)
    (extinguishments : List SettlementCommitmentExtinguishment)
    (extinguishmentRevisions : List SettlementExtinguishmentRevision)
    (correspondences : List SettlementEffectCorrespondence)
    (correspondenceRevisions : List SettlementCorrespondenceRevision)
    (contexts : List SettlementNettingContext)
    (members : List SettlementNettingMember)
    (memberRevisions : List SettlementNettingMemberRevision) :
    Option AdmittedSettlementImage := do
  if !uniqueContextIds contexts then
    none
  let currentCommitments ← currentCommitments? commitments commitmentRevisions
  let admittedCommitments ← admitCommitments? events currentCommitments
  let currentExtinguishments ← currentExtinguishments?
    extinguishments extinguishmentRevisions
  let admittedExtinguishments ← admitExtinguishments?
    admittedCommitments commitmentRevisions currentExtinguishments
  let currentDirect ← currentCorrespondences?
    correspondences correspondenceRevisions
  let admittedDirect ← admitCorrespondences?
    events admittedCommitments commitmentRevisions currentDirect
  if !directPhysicalCoverageAdmissible admittedDirect then
    none
  let currentNetMembers ← currentMembers? members memberRevisions
  let admittedMembers ← admitMembers?
    admittedCommitments commitmentRevisions contexts currentNetMembers
  let admittedNetting ← admitNettingContexts?
    events admittedMembers contexts
  if !targetConservationAdmissible
      admittedCommitments admittedDirect admittedNetting admittedExtinguishments then
    none
  else if !physicalConservationAdmissible admittedDirect admittedNetting then
    none
  else
    some {
      commitments := admittedCommitments
      extinguishments := admittedExtinguishments
      correspondences := admittedDirect
      netting := admittedNetting
    }

/-- Exact current settled magnitude for one admitted commitment. -/
def AdmittedSettlementImage.settledQuanta
    (image : AdmittedSettlementImage)
    (target : SettlementCommitmentId) : Int :=
  directTargetTotal image.correspondences target +
    netTargetTotal image.netting target

/-- Exact current non-settlement extinguished magnitude for one commitment. -/
def AdmittedSettlementImage.extinguishedQuanta
    (image : AdmittedSettlementImage)
    (target : SettlementCommitmentId) : Int :=
  extinguishmentTargetTotal image.extinguishments target

/--
Exact current outstanding Quantity for one admitted commitment.

The value is derived, never retained. Admission already guarantees combined
settlement plus non-settlement extinguishment does not exceed commitment Quantity.
-/
def AdmittedSettlementImage.outstanding?
    (image : AdmittedSettlementImage)
    (target : SettlementCommitmentId) : Option Quantity := do
  let commitment ← findCommitment? image.commitments target
  some (Quantity.ofQuanta
    (commitment.commitment.quantity.quanta -
      image.settledQuanta target -
      image.extinguishedQuanta target))

end Loam.Application
