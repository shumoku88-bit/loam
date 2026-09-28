import Loam.Application.ReplacementFrontier
import Loam.Core.EventMemory
import Loam.Core.OpenRelation

namespace Loam.Observation367

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 367 — netting correction belongs to member rows, not necessarily the aggregate snapshot

Observation 365 earned explicit gross membership for opposite-direction net
settlement.

Observation 366 then separated the settlement outcome:

    signed member total = 0
      -> zero outcome, no physical Effect required

    signed member total != 0
      -> exact physical Effect required

The next question is correction.

Selected physical fact:

    one bank Effect = -270 JPY

Original netting membership:

    household -> broker   1000
    broker -> household    700
    household -> broker     20
    broker -> household     50

    signed total = -270

Corrected semantic attribution:

    household -> broker    900
    broker -> household    600
    household -> broker     20
    broker -> household     50

    signed total = -270

The physical Effect does not change.

One possible design versions the entire aggregate netting snapshot.

A different design gives the netting occasion one stable context identity,
retains independently versioned member rows inside that context, and derives the
net amount from the current member frontier.

Real settlement systems provide pressure for the latter interpretation. DTC
settling-bank documentation describes recalculating a net balance when a member
balance is refused rather than treating the displayed net amount as an
independent mutable cash fact.

This observation asks:

1. Does correction require a version identity for the whole aggregate snapshot?
2. Or can generic ReplacementFrontier mechanics revise member rows while the
   aggregate net result remains derived?
3. If members become independent rows, what identity distinctions are actually
   earned?
-/

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩

private def settlementEventId : EventId := ⟨"o367-net-settlement"⟩
private def settlementEffectKey : EffectKey := ⟨"o367-net-cash"⟩

private def settlementEvent? : Option Event :=
  Event.ofEffects? settlementEventId [
    Effect.ofQuantity
      settlementEffectKey bank yen (Quantity.ofQuanta (-270))
  ]

private def events? : Option EventMemory := do
  let settlement ← settlementEvent?
  EventMemory.ofEvents? [settlement]

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

private def buyId : SettlementCommitmentId := ⟨"buy"⟩
private def saleId : SettlementCommitmentId := ⟨"sale"⟩
private def feeId : SettlementCommitmentId := ⟨"fee"⟩
private def creditId : SettlementCommitmentId := ⟨"credit"⟩

private def buy1000 : SettlementCommitment := {
  id := buyId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 1000
}

private def sale700 : SettlementCommitment := {
  id := saleId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 700
}

private def fee20 : SettlementCommitment := {
  id := feeId
  debtor := .household
  creditor := .external broker
  measure := yen
  quantity := Quantity.ofQuanta 20
}

private def credit50 : SettlementCommitment := {
  id := creditId
  debtor := .external broker
  creditor := .household
  measure := yen
  quantity := Quantity.ofQuanta 50
}

private def commitments : List SettlementCommitment :=
  [buy1000, sale700, fee20, credit50]

private def findCommitment?
    (id : SettlementCommitmentId) : Option SettlementCommitment :=
  commitments.find? fun commitment => commitment.id = id

structure NettingContextId where
  token : String
deriving Repr, DecidableEq

private def context : NettingContextId := ⟨"o367-context"⟩
private def laterContext : NettingContextId := ⟨"o367-later-context"⟩

inductive NettingMemberVersionId where
  | buyOriginal
  | saleOriginal
  | feeOriginal
  | creditOriginal
  | buyCorrected
  | saleCorrected
  | buyAlternative
  | laterBuy
deriving Repr, DecidableEq

structure NettingMember where
  id : NettingMemberVersionId
  context : NettingContextId
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

private def buyOriginal : NettingMember := {
  id := .buyOriginal
  context := context
  target := buyId
  quantity := Quantity.ofQuanta 1000
}

private def saleOriginal : NettingMember := {
  id := .saleOriginal
  context := context
  target := saleId
  quantity := Quantity.ofQuanta 700
}

private def feeOriginal : NettingMember := {
  id := .feeOriginal
  context := context
  target := feeId
  quantity := Quantity.ofQuanta 20
}

private def creditOriginal : NettingMember := {
  id := .creditOriginal
  context := context
  target := creditId
  quantity := Quantity.ofQuanta 50
}

private def buyCorrected : NettingMember := {
  id := .buyCorrected
  context := context
  target := buyId
  quantity := Quantity.ofQuanta 900
}

private def saleCorrected : NettingMember := {
  id := .saleCorrected
  context := context
  target := saleId
  quantity := Quantity.ofQuanta 600
}

private def buyAlternative : NettingMember := {
  id := .buyAlternative
  context := context
  target := buyId
  quantity := Quantity.ofQuanta 950
}

private def laterBuy : NettingMember := {
  id := .laterBuy
  context := laterContext
  target := buyId
  quantity := Quantity.ofQuanta 100
}

structure NettingMemberCoordinate where
  context : NettingContextId
  target : SettlementCommitmentId
deriving Repr, DecidableEq

private def coordinate (member : NettingMember) : NettingMemberCoordinate := {
  context := member.context
  target := member.target
}

private def targetOnlyCoordinate
    (member : NettingMember) : SettlementCommitmentId :=
  member.target

/-!
## Pressure 1 — correction repeats the semantic member coordinate

The corrected buy membership is still the same:

    netting context + target commitment

Only its exact attributed quantity changes.

So if correction is retained append-only, that coordinate cannot also be the
replacement-graph identity.
-/

theorem corrected_member_keeps_semantic_coordinate :
    coordinate buyOriginal = coordinate buyCorrected ∧
    buyOriginal ≠ buyCorrected := by
  native_decide

/-!
## Pressure 2 — context identity is independent from target identity

The same commitment may contribute to more than one settlement/netting occasion.

Therefore target commitment alone is not enough to group member rows.
-/

theorem same_target_can_belong_to_distinct_netting_contexts :
    targetOnlyCoordinate buyCorrected = targetOnlyCoordinate laterBuy ∧
    coordinate buyCorrected ≠ coordinate laterBuy := by
  native_decide

private structure MembershipHistory where
  retained : List NettingMember
  replacements : List (ReplacementFrontier.Edge NettingMemberVersionId)

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

private def originalHistory : MembershipHistory := {
  retained := [
    buyOriginal,
    saleOriginal,
    feeOriginal,
    creditOriginal
  ]
  replacements := []
}

private def correctedHistory : MembershipHistory := {
  retained := [
    buyOriginal,
    saleOriginal,
    feeOriginal,
    creditOriginal,
    buyCorrected,
    saleCorrected
  ]
  replacements := [
    { source := .buyOriginal, successor := .buyCorrected },
    { source := .saleOriginal, successor := .saleCorrected }
  ]
}

private def competingHistory : MembershipHistory := {
  retained := [
    buyOriginal,
    buyCorrected,
    buyAlternative
  ]
  replacements := [
    { source := .buyOriginal, successor := .buyCorrected },
    { source := .buyOriginal, successor := .buyAlternative }
  ]
}

theorem generic_replacement_frontier_revises_members_independently :
    currentMembers? originalHistory =
      some [buyOriginal, saleOriginal, feeOriginal, creditOriginal] ∧
    currentMembers? correctedHistory =
      some [feeOriginal, creditOriginal, buyCorrected, saleCorrected] := by
  native_decide

theorem competing_member_corrections_reuse_generic_conflict_refusal :
    currentMembers? competingHistory = none := by
  native_decide

private def memberLocallyAdmissible (member : NettingMember) : Bool :=
  match findCommitment? member.target with
  | none => false
  | some commitment =>
      member.quantity.quanta > 0 &&
      member.quantity.quanta <= commitment.quantity.quanta &&
      commitment.measure = yen

private def signedContribution? (member : NettingMember) : Option Int := do
  let commitment ← findCommitment? member.target
  if !memberLocallyAdmissible member then
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

private def currentForContext?
    (history : MembershipHistory)
    (selected : NettingContextId) : Option (List NettingMember) := do
  let current ← currentMembers? history
  some (current.filter fun member => member.context = selected)

private def projectedNet?
    (history : MembershipHistory)
    (selected : NettingContextId) : Option Int := do
  let members ← currentForContext? history selected
  signedTotal? members

/-!
## Pressure 3 — aggregate net remains a projection of the current member frontier

The original and corrected gross attributions are different, but both produce
the same physical -270 JPY outcome.

No mutable aggregate "net amount row" needs to be corrected.
-/

theorem corrected_members_change_gross_semantics_without_changing_net :
    projectedNet? originalHistory context = some (-270) ∧
    projectedNet? correctedHistory context = some (-270) ∧
    currentForContext? originalHistory context ≠
      currentForContext? correctedHistory context := by
  native_decide

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def physicalNet? : Option Int := do
  let memory ← events?
  let event ← memory.findById? settlementEventId
  let effect ← findEffectByKey? event settlementEffectKey
  if effect.measure != yen then
    none
  else
    some effect.quantity.quanta

theorem both_member_frontiers_match_the_same_retained_physical_effect :
    projectedNet? originalHistory context = physicalNet? ∧
    projectedNet? correctedHistory context = physicalNet? ∧
    physicalNet? = some (-270) := by
  native_decide

/-!
## Pressure 4 — the aggregate snapshot does not need its own current frontier for
## the selected correction

The current aggregate answer is completely determined by:

    stable netting context
    + current versioned member rows
    + retained commitment directions / quantities

Changing the member frontier changes the semantic attribution. Re-running the
projection yields the net answer.

There is no independent aggregate payload in this witness whose replacement must
be remembered separately.
-/

structure ProjectedNettingState where
  context : NettingContextId
  signedTotal : Int
deriving Repr, DecidableEq

private def projectedState?
    (history : MembershipHistory)
    (selected : NettingContextId) : Option ProjectedNettingState := do
  let total ← projectedNet? history selected
  some {
    context := selected
    signedTotal := total
  }

theorem aggregate_state_is_rederived_from_member_frontier :
    projectedState? originalHistory context =
      some { context := context, signedTotal := -270 } ∧
    projectedState? correctedHistory context =
      some { context := context, signedTotal := -270 } := by
  native_decide

/-!
## Finding

The selected correction does not earn a version identity for an aggregate
SettlementNettingEvidence snapshot.

The stronger decomposition is:

    stable NettingContext
      identifies which settlement/netting occasion members belong to

    versioned NettingMember rows
      context
      target commitment
      exact positive contributed Quantity

    generic ReplacementFrontier
      revises one member row append-only

    derived signed net
      sum(current member quantities with debtor/creditor sign)

    Observation-366 outcome rule
      zero -> no physical Effect
      nonzero -> exact physical Effect

Two identity distinctions are independently observable.

### 1. Stable netting-context identity is pressured

Once netting membership is row-shaped, target commitment alone is not enough.

The same commitment may contribute to separate settlement occasions, especially
under partial or multi-cycle settlement.

The wire form is not selected here. A production context might eventually be
named by a retained settlement-cycle identity, statement/batch identity, or a
dedicated opaque NettingContextId.

### 2. Member-version identity is pressured by correction

Old and corrected membership rows deliberately share:

    context + target

while differing in Quantity.

So, exactly as production settlement correspondence correction now does,
append-only one-to-one replacement needs a version identity distinct from the
semantic member coordinate.

### What is not earned

The aggregate net amount itself remains derived.

For the selected correction:

    original gross members  -> -270
    corrected gross members -> -270
    retained physical Effect -> -270

No independent aggregate replacement frontier is needed.

This also matches an observed operational pattern: settlement systems may
recalculate a displayed net balance when the included participant/member set
changes.

Therefore the minimum candidate is now closer to:

    SettlementCommitment
      independent gross obligation

    direct SettlementEffectCorrespondence
      direct physical settlement

    NettingContext
      stable grouping identity if row persistence is promised

    NettingMember
      version identity if correction is promised
      target commitment
      exact contributed Quantity

    derived signed net
      from current member frontier

    NetSettlementOutcome
      zero
      | exact physical Effect

rather than one mutable/versioned aggregate Netting snapshot.

Still not earned:

- production NettingContext persistence;
- a specific context coordinate such as date or statement id;
- aggregate NettingVersionId;
- automatic membership discovery;
- cross-counterparty netting;
- multi-currency netting;
- legal close-out/default netting;
- settlement finality state;
- reopening a finalized settlement cycle;
- production writers or TUI.

The next pressure should test finality.

If a netting context is explicitly acknowledged/finalized and later source facts
change, should its historical membership remain frozen like an as-filed result,
or should it always restate from current member evidence?

That distinction may determine whether netting needs an independently retained
publication/finality layer after all.
-/

end Loam.Observation367
