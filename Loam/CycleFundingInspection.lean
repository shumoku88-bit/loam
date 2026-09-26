import Loam.BalanceReview
import Loam.CurrentCoverageReview

namespace Loam.CycleFundingInspection

open Loam.Core

set_option autoImplicit false

/-!
# Current cycle funding inspection

A pure composition of one already-qualified exact current-balance selection and
the current-coverage answer. The balance support family is deliberately not
re-opened here: ZeroOriginCoverage, OpeningSupport, and CurrentQuantityAnchor are
all current-quantity evidence once admitted by `CurrentBalanceReview`.

Historical completeness is not required by this current funding question.
-/

/-- Independent funding quantities, not permission to spend or publication authority. -/
structure Summary where
  budgetableBacking : Quantity
  remainingAssigned : Quantity
  deriving Repr, DecidableEq

def Summary.measure (_summary : Summary) : MeasureId := ⟨"jpy"⟩

def Summary.residualBeforeUnresolved (summary : Summary) : Quantity :=
  summary.budgetableBacking - summary.remainingAssigned

@[simp] theorem Summary.measure_eq_jpy (summary : Summary) :
    summary.measure = (⟨"jpy"⟩ : MeasureId) := rfl

@[simp] theorem Summary.residualBeforeUnresolved_eq_components (summary : Summary) :
    summary.residualBeforeUnresolved = summary.budgetableBacking - summary.remainingAssigned := rfl

private def selectedRowsMatch
    (selection : List EffectCoordinate)
    (balances : Loam.BalanceReview.Snapshot) : Bool :=
  balances.rows.map (·.coordinate) == selection

/--
Inspect exact current backing and already-projected CurrentCoverage.

The caller must supply exactly the configured selection in caller order. Any
amount-unknown or unsupported coordinate must have been refused before this
function is called rather than silently becoming zero.
-/
def project
    (balances : Loam.BalanceReview.Snapshot)
    (selection : List EffectCoordinate)
    (measure : MeasureId)
    (current : Loam.CurrentCoverageReview.Snapshot) : Except String Summary := do
  if measure != (⟨"jpy"⟩ : MeasureId) then
    throw "loam: cycle funding requires explicit JPY measure for CurrentCoverage"
  if !selection.all (fun coordinate => coordinate.measure == measure) then
    throw "loam: cycle funding selection has a wrong measure"
  if !decide selection.Nodup then
    throw "loam: cycle funding selection contains duplicate coordinates"
  if !selectedRowsMatch selection balances then
    throw "loam: cycle funding balance answer does not match the selected pool"
  if !decide (current.rows.map (·.purpose)).Nodup then
    throw "loam: cycle funding coverage contains duplicate Purpose rows"
  if current.scheduledFrontier.isNone then
    throw "loam: cycle funding Scheduled frontier is unavailable"

  let backing := balances.rows.foldl (fun total row => total + row.quantity.quanta) (0 : Int)
  let assigned := current.rows.foldl (fun total row => total + max row.remaining.quanta 0) (0 : Int)
  return {
    budgetableBacking := Quantity.ofQuanta backing
    remainingAssigned := Quantity.ofQuanta assigned
  }

end Loam.CycleFundingInspection
