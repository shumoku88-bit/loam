import Loam.BalanceReview
import Loam.CurrentCoverageReview

namespace Loam.CycleFundingInspection

open Loam.Core

set_option autoImplicit false

/-!
# Current cycle funding inspection

A pure composition of the shared physical-balance and current-coverage answers.
The caller supplies a finite budgetable coordinate selection explicitly; neither
balance-view configuration, accounting roles, nor account names supply it.

This module lives beside the shared Reviews it composes, not below them in
Application. It performs no IO and introduces no retained Funding/Cycle state.
-/

/-- Derived quantities, not permission to spend or publication authority. -/
structure Summary where
  measure : MeasureId
  budgetableBacking : Quantity
  remainingAssigned : Quantity
  residualBeforeUnresolved : Quantity
  unmanagedFuturePressure : Quantity
  unroutedFuturePressure : Quantity
  unresolvedFuturePressure : Quantity
  deriving Repr, DecidableEq

/--
Inspect current physical evidence and an already-projected CurrentCoverage
snapshot from the same caller-owned current observation.

`measure` is explicit and must be JPY: CurrentCoverageReview currently projects
JPY only. Every selected coordinate must use that measure. Duplicate selection
is refused before BalanceReview's presentation normalization can hide it.
BalanceReview.project requires independent zero-origin coverage, so an unknown
selected balance cannot silently become zero. An explicitly covered coordinate
with no activity, however, is an evidenced zero.

An empty list deliberately selects no backing; it must not stand in for absent
configuration. The caller must supply the complete CurrentCoverage snapshot,
not just visible/selected Purpose rows. Missing global Scheduled frontier is
unknown, not zero. Its three quantities are copied once, not summed per Purpose.

Remaining assigned uses positive remaining, never headroom: managed Scheduled
pressure is already inside assigned Capacity. Unclassified future pressure is
kept separate and is not automatically deducted from the residual.
-/
def project
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (zeroOrigin : ZeroOriginCoverage)
    (selection : List EffectCoordinate)
    (measure : MeasureId)
    (current : Loam.CurrentCoverageReview.Snapshot) : Except String Summary := do
  if measure != (⟨"jpy"⟩ : MeasureId) then
    throw "loam: cycle funding requires explicit JPY measure for CurrentCoverage"
  if !selection.all (fun coordinate => coordinate.measure == measure) then
    throw "loam: cycle funding selection has a wrong measure"
  if !decide selection.Nodup then
    throw "loam: cycle funding selection contains duplicate coordinates"
  if !decide (current.rows.map (·.purpose)).Nodup then
    throw "loam: cycle funding coverage contains duplicate Purpose rows"
  let some frontier := current.scheduledFrontier
    | throw "loam: cycle funding Scheduled frontier is unavailable"
  let balances ← Loam.BalanceReview.project events corrections zeroOrigin selection
  let backing := balances.rows.foldl (fun total row => total + row.quantity.quanta) (0 : Int)
  let assigned := current.rows.foldl (fun total row => total + max row.remaining.quanta 0) (0 : Int)
  return {
    measure := measure
    budgetableBacking := Quantity.ofQuanta backing
    remainingAssigned := Quantity.ofQuanta assigned
    residualBeforeUnresolved := Quantity.ofQuanta (backing - assigned)
    unmanagedFuturePressure := frontier.unmanaged
    unroutedFuturePressure := frontier.unrouted
    unresolvedFuturePressure := frontier.unresolvedEligibility
  }

end Loam.CycleFundingInspection
