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

/-- Independent funding quantities, not permission to spend or publication authority. -/
structure Summary where
  budgetableBacking : Quantity
  remainingAssigned : Quantity
  deriving Repr, DecidableEq

/-- Successful CycleFunding summaries are currently JPY-only by admission. -/
def Summary.measure (_summary : Summary) : MeasureId :=
  ⟨"jpy"⟩

/-- Residual is uniquely derived from backing and assigned quantity. -/
def Summary.residualBeforeUnresolved (summary : Summary) : Quantity :=
  summary.budgetableBacking - summary.remainingAssigned

@[simp] theorem Summary.measure_eq_jpy (summary : Summary) :
    summary.measure = (⟨"jpy"⟩ : MeasureId) :=
  rfl

@[simp] theorem Summary.residualBeforeUnresolved_eq_components (summary : Summary) :
    summary.residualBeforeUnresolved = summary.budgetableBacking - summary.remainingAssigned :=
  rfl

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
unknown, not zero. The frontier remains owned by CurrentCoverage rather than
being copied into this funding summary.

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
  if current.scheduledFrontier.isNone then
    throw "loam: cycle funding Scheduled frontier is unavailable"
  let balances ← Loam.BalanceReview.project events corrections zeroOrigin selection
  let backing := balances.rows.foldl (fun total row => total + row.quantity.quanta) (0 : Int)
  let assigned := current.rows.foldl (fun total row => total + max row.remaining.quanta 0) (0 : Int)
  return {
    budgetableBacking := Quantity.ofQuanta backing
    remainingAssigned := Quantity.ofQuanta assigned
  }

end Loam.CycleFundingInspection
