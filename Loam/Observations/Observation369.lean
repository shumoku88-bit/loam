import Loam.Application.ReplacementFrontier
import Loam.Core.EventMemory
import Loam.Core.OpenRelation

namespace Loam.Observation369

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 369 — correcting finality evidence earns publication version identity

Observation 368 separated:

    current-restated netting

from:

    as-finalized settlement publication

and kept the finality publication small:

    context
    exact finalized member versions
    exact physical Effect anchor

The next question is narrower.

Suppose the physical settlement is unquestionably:

    -300 JPY

and two different gross member compositions are both arithmetically compatible:

    composition A
      -1000 + 700 = -300

    composition B
       -900 + 600 = -300

If a historical finality record was entered with composition B, but later
documentary evidence establishes that composition A was the one actually
finalized, the physical Effect does not tell us which publication is correct.

This is not a source/member restatement.

It is a correction to the retained finality evidence itself.

If LOAM promises append-only correction history for such evidence, old and new
finality records must remain distinguishable even though they share the same:

    netting context
    physical Effect anchor
    derived final amount

This observation asks whether publication version identity is therefore earned,
and whether generic ReplacementFrontier mechanics remain sufficient.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def settlementEventId : EventId := ⟨"o369-final-settlement"⟩
private def settlementEffectKey : EffectKey := ⟨"o369-final-cash"⟩

private def settlementEvent? : Option Event :=
  Event.ofEffects? settlementEventId [
    Effect.ofQuantity
      settlementEffectKey bank yen (Quantity.ofQuanta (-300))
  ]

private def events? : Option EventMemory := do
  let event ← settlementEvent?
  EventMemory.ofEvents? [event]

private def broker : ExternalPartyId := ⟨"broker-counterparty"⟩

structure SettlementCommitmentId where
  token : String
deriving Repr, DecidableEq

structure SettlementCommitment where
  id : SettlementCommitmentId
  debtor : RelationEndpoint
  creditor : RelationEndpoint
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

private def outgoingId : SettlementCommitmentId := ⟨"outgoing"⟩
private def incomingId : SettlementCommitmentId := ⟨"incoming"⟩

private def outgoingCommitment : SettlementCommitment := {
  id := outgoingId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def incomingCommitment : SettlementCommitment := {
  id := incomingId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 700
}

private def commitments : List SettlementCommitment :=
  [outgoingCommitment, incomingCommitment]

private def findCommitment?
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

structure NettingContextId where
  token : String
deriving Repr, DecidableEq

private def context : NettingContextId := ⟨"o369-context"⟩

inductive NettingMemberVersionId where
  | outgoingA
  | incomingA
  | outgoingB
  | incomingB
deriving Repr, DecidableEq

structure NettingMember where
  id : NettingMemberVersionId
  context : NettingContextId
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

private def outgoingA : NettingMember := {
  id := .outgoingA
  context := context
  target := outgoingId
  quantity := Quantity.ofQuanta 1000
}

private def incomingA : NettingMember := {
  id := .incomingA
  context := context
  target := incomingId
  quantity := Quantity.ofQuanta 700
}

private def outgoingB : NettingMember := {
  id := .outgoingB
  context := context
  target := outgoingId
  quantity := Quantity.ofQuanta 900
}

private def incomingB : NettingMember := {
  id := .incomingB
  context := context
  target := incomingId
  quantity := Quantity.ofQuanta 600
}

private def retainedMembers : List NettingMember :=
  [outgoingA, incomingA, outgoingB, incomingB]

private def retainedMemberById?
    (id : NettingMemberVersionId) : Option NettingMember :=
  retainedMembers.find? fun member => member.id = id

private def memberAdmitted (member : NettingMember) : Bool :=
  match findCommitment? member.target with
  | none => false
  | some commitment =>
      member.context = context &&
      member.quantity.quanta > 0 &&
      member.quantity.quanta <= commitment.quantity.quanta &&
      commitment.measure = yen

private def signedContribution? (member : NettingMember) : Option Int := do
  let commitment ← findCommitment? member.target
  if !memberAdmitted member then
    none
  else
    match commitment.debtor, commitment.creditor with
    | .household, .external _ =>
        some (-member.quantity.quanta)
    | .external _, .household =>
        some member.quantity.quanta
    | _, _ =>
        none

private def signedTotal? : List NettingMember -> Option Int
  | [] => some 0
  | member :: rest => do
      let head ← signedContribution? member
      let tail ← signedTotal? rest
      some (head + tail)

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def physicalAnchor : EffectAnchor :=
  ⟨settlementEventId, settlementEffectKey⟩

structure FinalityCoordinate where
  context : NettingContextId
  physical : EffectAnchor
deriving Repr, DecidableEq

inductive FinalityPublicationVersionId where
  | recordedWrong
  | correctedRecord
  | competingRecord
deriving Repr, DecidableEq

structure FinalizedSettlementPublication where
  id : FinalityPublicationVersionId
  context : NettingContextId
  memberVersions : List NettingMemberVersionId
  physical : EffectAnchor
deriving Repr, DecidableEq

private def coordinate
    (publication : FinalizedSettlementPublication) : FinalityCoordinate := {
  context := publication.context
  physical := publication.physical
}

private def recordedWrong : FinalizedSettlementPublication := {
  id := .recordedWrong
  context := context
  memberVersions := [.outgoingB, .incomingB]
  physical := physicalAnchor
}

private def correctedRecord : FinalizedSettlementPublication := {
  id := .correctedRecord
  context := context
  memberVersions := [.outgoingA, .incomingA]
  physical := physicalAnchor
}

private def competingRecord : FinalizedSettlementPublication := {
  id := .competingRecord
  context := context
  memberVersions := [.outgoingA, .incomingA]
  physical := physicalAnchor
}

/-!
## Pressure 1 — the semantic publication coordinate repeats under correction

Both records refer to the same finality occasion and the same physical movement.

Only the exact member-version composition differs.

Therefore context + physical anchor cannot also serve as the replacement-graph
identity if append-only correction history is promised.
-/

theorem finality_correction_repeats_semantic_coordinate :
    coordinate recordedWrong = coordinate correctedRecord ∧
    recordedWrong ≠ correctedRecord := by
  native_decide

private def publicationMembers?
    (publication : FinalizedSettlementPublication) :
    Option (List NettingMember) :=
  publication.memberVersions.mapM retainedMemberById?

private def publicationNet?
    (publication : FinalizedSettlementPublication) : Option Int := do
  if publication.context != context then
    none
  let members ← publicationMembers? publication
  if !members.all (fun member => member.context = publication.context) then
    none
  signedTotal? members

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def physicalNet? (memory : EventMemory) : Option Int := do
  let event ← memory.findById? settlementEventId
  let effect ← findEffectByKey? event settlementEffectKey
  if effect.measure != yen then
    none
  else
    some effect.quantity.quanta

private def publicationAdmitted?
    (memory : EventMemory)
    (publication : FinalizedSettlementPublication) : Bool :=
  match publicationNet? publication, physicalNet? memory with
  | some semantic, some physical =>
      publication.physical = physicalAnchor &&
      semantic = physical
  | _, _ =>
      false

/-!
## Pressure 2 — arithmetic and physical settlement cannot distinguish the two records

Both candidate publications are admissible against the same -300 JPY physical
settlement.

So "pick the one that matches cash" cannot repair the historical record.
-/

theorem distinct_member_compositions_can_support_the_same_final_amount :
    (do
      let memory ← events?
      pure (
        publicationNet? recordedWrong,
        publicationNet? correctedRecord,
        publicationAdmitted? memory recordedWrong,
        publicationAdmitted? memory correctedRecord,
        recordedWrong.memberVersions ≠ correctedRecord.memberVersions)) =
      some (some (-300), some (-300), true, true, true) := by
  native_decide

/-!
## Generic correction frontier

The publication family gets a version identity only because the correction
promise now requires old and corrected finality evidence to coexist.
-/

private structure PublicationHistory where
  retained : List FinalizedSettlementPublication
  replacements :
    List (ReplacementFrontier.Edge FinalityPublicationVersionId)

private def present
    (history : PublicationHistory)
    (id : FinalityPublicationVersionId) : Bool :=
  history.retained.any fun publication => decide (publication.id = id)

private def currentPublication?
    (history : PublicationHistory) :
    Option FinalizedSettlementPublication := do
  if !ReplacementFrontier.structurallyAdmissible
      (present history) history.replacements then
    none
  let current :=
    ReplacementFrontier.frontier
      FinalizedSettlementPublication.id
      history.retained
      history.replacements
  match current with
  | [publication] => some publication
  | _ => none

private def beforeCorrection : PublicationHistory := {
  retained := [recordedWrong]
  replacements := []
}

private def afterCorrection : PublicationHistory := {
  retained := [recordedWrong, correctedRecord]
  replacements := [
    { source := .recordedWrong, successor := .correctedRecord }
  ]
}

private def competingCorrection : PublicationHistory := {
  retained := [recordedWrong, correctedRecord, competingRecord]
  replacements := [
    { source := .recordedWrong, successor := .correctedRecord },
    { source := .recordedWrong, successor := .competingRecord }
  ]
}

theorem generic_frontier_preserves_old_finality_evidence_and_moves_current_record :
    currentPublication? beforeCorrection = some recordedWrong ∧
    afterCorrection.retained = [recordedWrong, correctedRecord] ∧
    currentPublication? afterCorrection = some correctedRecord := by
  native_decide

theorem competing_finality_corrections_reuse_generic_conflict_refusal :
    currentPublication? competingCorrection = none := by
  native_decide

/-!
## Pressure 3 — correction changes historical attribution, not physical settlement

The corrected publication names a different gross composition while preserving
the same physical settlement anchor and amount.

This is distinct from Observation 368's source/member restatement:

    Observation 368
      source/member evidence changes
      finality publication remains historically true

    Observation 369
      finality publication itself was mis-recorded
      finality evidence frontier must move
-/

theorem correcting_finality_record_does_not_rewrite_physical_cash :
    (do
      let memory ← events?
      let before ← currentPublication? beforeCorrection
      let after ← currentPublication? afterCorrection
      pure (
        physicalNet? memory,
        publicationNet? before,
        publicationNet? after,
        before.physical = after.physical,
        before.memberVersions ≠ after.memberVersions)) =
      some (some (-300), some (-300), some (-300), true, true) := by
  native_decide

/-!
## Finding

Finality publication version identity is earned only when LOAM promises
append-only correction of finality evidence itself.

The semantic coordinate remains:

    NettingContext + physical Effect anchor

and the exact finalized composition remains:

    member version identities

A mis-recorded publication can therefore be corrected without:

- changing the physical Event / Effect;
- changing the final amount;
- deleting the old erroneous record;
- inventing settlement-specific mutation machinery.

The minimum correction shape is:

    FinalityPublicationVersionId
      distinct revision identity

    FinalizedSettlementPublication
      version id
      context
      exact member version ids
      physical Effect anchor

    ReplacementFrontier
      old finality evidence -> corrected finality evidence

This is the same generic supersession mechanics already used elsewhere, but the
authority remains finality-specific.

## Important distinction

An adjusted pre-final balance is not the same thing as correcting a finalized
historical record.

Settlement systems may publish or recalculate figures before the legally defined
point of finality. Such operational adjustment belongs to the live settlement
workflow.

This observation concerns only a retained claim that:

    "these exact members and this exact physical settlement were final"

when that claim itself was recorded incorrectly.

## Still not earned

- production finality persistence;
- automatic creation of finality publications;
- legal-finality inference;
- one universal finality type;
- settlement-law / jurisdiction rules;
- reopening the underlying settled transfer;
- changing a final transfer merely because evidence was corrected;
- cross-currency finality;
- close-out/default netting;
- TUI writer.

At this point the research has found separate pressures for:

    commitment identity
    direct correspondence version identity
    netting context identity
    netting member version identity
    finality publication version identity

without promoting any of them into neutral Core merely for convenience.

The next useful move is not another identity type by default.

It should be a consolidation pass over Observations 359-369 to ask which pieces
are now sufficiently repeated and independent to justify a production settlement
family, and which should remain research-only extensions.
-/

end Loam.Observation369
