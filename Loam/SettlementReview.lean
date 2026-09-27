import Loam.ActualAuthority
import Loam.Application.SettlementFrontier

namespace Loam.SettlementReview

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared settlement review

This is the presentation-neutral read boundary for the promoted settlement
family.

It consumes only one fully admitted `ActualAuthority.Image`. Retained
superseded correspondence/member rows therefore remain historical provenance but
do not reappear as current settlement allocations.

The review adds no matching, valuation, accounting recognition, or finality
semantics. It only names already-admitted quantities and provenance so TUI, CLI,
GUI, or AI surfaces can share one answer.
-/

/-- One current direct allocation from a physical Event/Effect to a commitment. -/
structure DirectAllocation where
  correspondence : SettlementCorrespondenceId
  event : EventId
  effect : EffectKey
  quantity : Quantity
deriving Repr, DecidableEq

/-- One current participation of a commitment in an admitted netting context. -/
structure NettingAllocation where
  member : SettlementNettingMemberId
  context : SettlementNettingContextId
  quantity : Quantity
  outcome : NetSettlementOutcome
deriving Repr, DecidableEq

/--
One current commitment summary.

`committed`, `settled`, and `outstanding` all use the commitment's explicit
settlement Measure. Direct and netting details explain the exact current
allocation that produced `settled`.
-/
structure Row where
  id : SettlementCommitmentId
  sourceEvent : EventId
  sourceEffect : EffectKey
  debtor : RelationEndpoint
  creditor : RelationEndpoint
  measure : MeasureId
  committed : Quantity
  settled : Quantity
  outstanding : Quantity
  direct : List DirectAllocation
  netting : List NettingAllocation
deriving Repr, DecidableEq

structure Snapshot where
  rows : List Row
deriving Repr, DecidableEq

private def directAllocations
    (image : AdmittedSettlementImage)
    (target : SettlementCommitmentId) : List DirectAllocation :=
  image.correspondences.filterMap fun admitted =>
    if admitted.correspondence.target = target then
      some {
        correspondence := admitted.correspondence.id
        event := admitted.correspondence.event
        effect := admitted.correspondence.effect
        quantity := admitted.correspondence.quantity
      }
    else
      none

private def nettingAllocations
    (image : AdmittedSettlementImage)
    (target : SettlementCommitmentId) : List NettingAllocation :=
  image.netting.flatMap fun admittedContext =>
    admittedContext.members.filterMap fun admittedMember =>
      if admittedMember.member.target = target then
        some {
          member := admittedMember.member.id
          context := admittedContext.context.id
          quantity := admittedMember.member.quantity
          outcome := admittedContext.context.outcome
        }
      else
        none

private def row
    (image : AdmittedSettlementImage)
    (admitted : AdmittedSettlementCommitment) : Row :=
  let commitment := admitted.commitment
  let settledQuanta := image.settledQuanta commitment.id
  {
    id := commitment.id
    sourceEvent := commitment.sourceEvent
    sourceEffect := commitment.sourceEffect
    debtor := commitment.debtor
    creditor := commitment.creditor
    measure := commitment.measure
    committed := commitment.quantity
    settled := Quantity.ofQuanta settledQuanta
    outstanding := Quantity.ofQuanta
      (commitment.quantity.quanta - settledQuanta)
    direct := directAllocations image commitment.id
    netting := nettingAllocations image commitment.id
  }

/-- Project every current settlement commitment from one canonical Actual image. -/
def projectImage (image : Loam.ActualAuthority.Image) : Snapshot :=
  {
    rows := image.settlement.commitments.map (row image.settlement)
  }

/-- Find one commitment summary by stable retained identity. -/
def Snapshot.find? (snapshot : Snapshot) (id : SettlementCommitmentId) : Option Row :=
  snapshot.rows.find? fun row => row.id = id

/-- Current commitments with a positive outstanding quantity. -/
def Snapshot.openRows (snapshot : Snapshot) : List Row :=
  snapshot.rows.filter fun row => row.outstanding.quanta > 0

/--
Load the canonical normalized Actual authority and project settlement review
rows. The caller may supply either the household root or explicit `actual.loam`
path, matching other shared Actual reviews.
-/
def loadSnapshot (rootOrFile : System.FilePath) : IO (Except String Snapshot) := do
  let path := Loam.ActualAuthority.actualPathFromRootOrFile rootOrFile
  match ← Loam.ActualAuthority.loadImageFile? path with
  | .error message => return .error message
  | .ok image => return .ok (projectImage image)

end Loam.SettlementReview
