import Loam.Application.ReplacementFrontier
import Loam.Core.EventMemory
import Loam.Core.OpenRelation

namespace Loam.Observation368

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 368 — settlement finality earns an as-finalized publication layer

Observation 367 left the aggregate net amount derived from the current member
frontier.

That is correct for a live / restated view.

Settlement finality introduces a different question.

External settlement systems define finality as an irrevocable and unconditional
transfer or discharge at a legally defined moment. DTC also publishes final
figures and requires settling banks to acknowledge the net-net balance.

So after a settlement has become final, later corrections to semantic source or
member evidence must not silently rewrite the historical fact:

    what was actually finalized at that time?

This observation compares:

    current-restated netting
      derived from the current member frontier

with:

    as-finalized settlement publication
      exact retained member versions
      exact retained physical settlement evidence

The goal is not to make every netting context final.

The goal is to determine whether workflows that explicitly promise finality need
an independently retained publication boundary.
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def settlementEventId : EventId := ⟨"o368-final-settlement"⟩
private def settlementEffectKey : EffectKey := ⟨"o368-final-cash"⟩

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

private def outgoing1000 : SettlementCommitment := {
  id := outgoingId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def incoming800 : SettlementCommitment := {
  id := incomingId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 800
}

private def commitments : List SettlementCommitment :=
  [outgoing1000, incoming800]

private def findCommitment?
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

structure NettingContextId where
  token : String
deriving Repr, DecidableEq

private def context : NettingContextId := ⟨"o368-context"⟩

inductive NettingMemberVersionId where
  | outgoingOriginal
  | incomingOriginal
  | incomingCorrected
deriving Repr, DecidableEq

structure NettingMember where
  id : NettingMemberVersionId
  context : NettingContextId
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

private def outgoingOriginal : NettingMember := {
  id := .outgoingOriginal
  context := context
  target := outgoingId
  quantity := Quantity.ofQuanta 1000
}

private def incomingOriginal : NettingMember := {
  id := .incomingOriginal
  context := context
  target := incomingId
  quantity := Quantity.ofQuanta 700
}

private def incomingCorrected : NettingMember := {
  id := .incomingCorrected
  context := context
  target := incomingId
  quantity := Quantity.ofQuanta 800
}

private structure MembershipHistory where
  retained : List NettingMember
  replacements : List (ReplacementFrontier.Edge NettingMemberVersionId)

private def originalHistory : MembershipHistory := {
  retained := [outgoingOriginal, incomingOriginal]
  replacements := []
}

private def correctedHistory : MembershipHistory := {
  retained := [outgoingOriginal, incomingOriginal, incomingCorrected]
  replacements := [
    { source := .incomingOriginal, successor := .incomingCorrected }
  ]
}

private def present
    (history : MembershipHistory)
    (id : NettingMemberVersionId) : Bool :=
  history.retained.any fun member => decide (member.id = id)

private def currentMembers?
    (history : MembershipHistory) : Option (List NettingMember) := do
  if !ReplacementFrontier.structurallyAdmissible
      (present history) history.replacements then
    none
  some (ReplacementFrontier.frontier
    NettingMember.id history.retained history.replacements)

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

private def currentRestatedNet?
    (history : MembershipHistory) : Option Int := do
  let current ← currentMembers? history
  signedTotal? (current.filter fun member => member.context = context)

theorem later_member_correction_restates_the_live_net :
    currentRestatedNet? originalHistory = some (-300) ∧
    currentRestatedNet? correctedHistory = some (-200) := by
  native_decide

/-!
## Candidate finality publication

The publication stores no duplicate member payload.

It points to the exact retained member versions that were finalized.

That is enough to preserve the historical semantic allocation even after the
current member frontier moves.
-/

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

structure FinalizedSettlementPublication where
  context : NettingContextId
  memberVersions : List NettingMemberVersionId
  physical : EffectAnchor
deriving Repr, DecidableEq

private def publication : FinalizedSettlementPublication := {
  context := context
  memberVersions := [.outgoingOriginal, .incomingOriginal]
  physical := ⟨settlementEventId, settlementEffectKey⟩
}

private def retainedMemberById?
    (history : MembershipHistory)
    (id : NettingMemberVersionId) : Option NettingMember :=
  history.retained.find? fun member => member.id = id

private def publicationMembers?
    (history : MembershipHistory)
    (publication : FinalizedSettlementPublication) :
    Option (List NettingMember) :=
  publication.memberVersions.mapM fun id =>
    retainedMemberById? history id

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def physicalQuantity?
    (memory : EventMemory)
    (anchor : EffectAnchor) : Option Int := do
  let event ← memory.findById? anchor.event
  let effect ← findEffectByKey? event anchor.effect
  if effect.measure != yen then
    none
  else
    some effect.quantity.quanta

private def asFinalizedNet?
    (history : MembershipHistory)
    (publication : FinalizedSettlementPublication) :
    Option Int := do
  if publication.context != context then
    none
  let members ← publicationMembers? history publication
  if !members.all (fun member => member.context = publication.context) then
    none
  signedTotal? members

private def publicationAdmitted?
    (memory : EventMemory)
    (history : MembershipHistory)
    (publication : FinalizedSettlementPublication) : Bool :=
  match asFinalizedNet? history publication,
        physicalQuantity? memory publication.physical with
  | some semantic, some physical =>
      semantic = physical
  | _, _ =>
      false

theorem finalized_publication_is_supported_before_correction :
    (do
      let memory ← events?
      pure (
        asFinalizedNet? originalHistory publication,
        publicationAdmitted? memory originalHistory publication)) =
      some (some (-300), true) := by
  native_decide

/-!
## Pressure 1 — current-restated and as-finalized views may legitimately diverge

The incoming member is later corrected from 700 to 800.

The current frontier therefore restates to -200.

But the exact retained member versions named by the finality publication still
project to -300 and still agree with the actual physical settlement Effect.
-/

theorem finality_does_not_silently_follow_later_member_correction :
    (do
      let memory ← events?
      pure (
        currentRestatedNet? correctedHistory,
        asFinalizedNet? correctedHistory publication,
        publicationAdmitted? memory correctedHistory publication)) =
      some (some (-200), some (-300), true) := by
  native_decide

/-!
## Pressure 2 — using the current frontier as the historical finality answer is wrong
-/

private def naiveFinalityFromCurrent?
    (history : MembershipHistory) : Option Int :=
  currentRestatedNet? history

theorem naive_current_projection_rewrites_historical_finality :
    naiveFinalityFromCurrent? originalHistory = some (-300) ∧
    naiveFinalityFromCurrent? correctedHistory = some (-200) ∧
    asFinalizedNet? correctedHistory publication = some (-300) := by
  native_decide

/-!
## Pressure 3 — exact member-version references are stronger than the net amount

The publication is not merely "the final amount was -300".

It also preserves which gross semantic member versions were accepted as the
basis of that final settlement.

The retained physical Effect alone cannot reconstruct that composition.
-/

theorem publication_retains_exact_finalized_member_versions :
    publication.memberVersions =
      [.outgoingOriginal, .incomingOriginal] ∧
    (do
      let members ← publicationMembers? correctedHistory publication
      pure (members.map NettingMember.quantity)) =
      some [Quantity.ofQuanta 1000, Quantity.ofQuanta 700] := by
  native_decide

/-!
## Finding

Settlement finality earns an independently retained publication layer for
workflows that explicitly promise finality.

It does not change the live netting algebra.

The two views intentionally answer different questions:

    current-restated
      what does the current corrected member evidence imply now?

    as-finalized
      what exact member versions and physical settlement were finalized then?

A later source/member correction may therefore produce:

    current-restated = -200 JPY
    as-finalized     = -300 JPY

without contradiction.

The publication can remain small:

    FinalizedSettlementPublication
      NettingContext
      exact member version identities
      exact physical Effect anchor

The signed amount remains derived from those retained member versions.

This does not earn a mutable aggregate net row.

It also does not mean every household reconciliation or card payment needs a
formal finality publication. The layer is justified only where the workflow
itself has an explicit final / acknowledged / irrevocable boundary.

## Relation to earlier LOAM semantics

This is structurally similar to the investment distinction already observed
between:

    current-restated result
    historically filed result

but the semantic authority is different.

A filed result is evidence about what was reported.

A finalized settlement publication is evidence about which obligation
composition and physical settlement became final under that settlement workflow.

Mechanics may be shared. Authority should remain separate.

## Still not earned

- production FinalizedSettlementPublication;
- one universal legal-finality type for all domains;
- settlement-law or jurisdiction rules;
- automatic inference that an ordinary payment is final;
- aggregate NettingVersionId;
- mutable/reopenable finality;
- correction semantics for mis-recorded finality evidence;
- multi-currency finality;
- close-out/default netting;
- production writer or TUI.

The next pressure should distinguish two very different post-finality events:

1. source evidence was corrected later, while the original final settlement
   remains historically true;
2. the recorded finality publication itself was wrong and must be corrected.

Only the second case may earn version identity for the finality publication.
-/

end Loam.Observation368
