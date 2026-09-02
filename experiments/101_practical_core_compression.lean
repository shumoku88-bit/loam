import Loam.Core

namespace Loam.Experiments.Observation101

open Loam.Core

set_option autoImplicit false

/--
Experiment-local evidence selecting which neutral loci participate in one
balance query.

This is deliberately not a production Account declaration, AccountType,
registry, or persistence shape. Observation 101 asks how little structure is
needed before any of those larger concepts are earned.
-/
structure BalanceScope where
  loci : List LocusId
  nodup : loci.Nodup

/-- Sum exact Event effects at one ordinary LOAM coordinate. -/
def totalAt
    (events : List Event) (locus : LocusId) (measure : MeasureId) : Quantity :=
  Quantity.ofQuanta <|
    events.foldr
      (fun event total => (event.quantityAt locus measure).quanta + total)
      0

/--
Expose a quantity only when the selected query explicitly includes the locus.
The Event and Locus themselves remain accounting-role neutral.
-/
def BalanceScope.quantity?
    (scope : BalanceScope) (events : List Event)
    (locus : LocusId) (measure : MeasureId) : Option Quantity :=
  if locus ∈ scope.loci then
    some (totalAt events locus measure)
  else
    none

private def assetA : LocusId := ⟨"asset-a"⟩
private def assetB : LocusId := ⟨"asset-b"⟩
private def useA : LocusId := ⟨"use-a"⟩
private def useB : LocusId := ⟨"use-b"⟩
private def unit : MeasureId := ⟨"unit"⟩

private def effect (key : String) (locus : LocusId) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ locus unit (Quantity.ofQuanta quanta)

/-- One balance locus to one use locus. -/
private def purchase : Event :=
  { id := ⟨"purchase"⟩
    effects :=
      [effect "purchase-source" assetA (-7),
       effect "purchase-use" useA 7]
    keyNodup := by decide }

/-- One balance locus to another balance locus. -/
private def transfer : Event :=
  { id := ⟨"transfer"⟩
    effects :=
      [effect "transfer-from" assetA (-5),
       effect "transfer-to" assetB 5]
    keyNodup := by decide }

/-- One balance locus split across two use loci. -/
private def splitPurchase : Event :=
  { id := ⟨"split-purchase"⟩
    effects :=
      [effect "split-source" assetB (-11),
       effect "split-use-a" useA 4,
       effect "split-use-b" useB 7]
    keyNodup := by decide }

private def balanceScope : BalanceScope :=
  { loci := [assetA, assetB]
    nodup := by decide }

/-- A selected source locus remains visible after an ordinary purchase. -/
example :
    balanceScope.quantity? [purchase] assetA unit =
      some (Quantity.ofQuanta (-7)) := by
  decide

/-- The use locus is retained by the Event but is not silently promoted into the balance view. -/
example :
    balanceScope.quantity? [purchase] useA unit = none := by
  decide

/-- A transfer can expose both selected balance loci without a transfer-specific Account type. -/
example :
    balanceScope.quantity? [transfer] assetA unit =
      some (Quantity.ofQuanta (-5)) := by
  decide

example :
    balanceScope.quantity? [transfer] assetB unit =
      some (Quantity.ofQuanta 5) := by
  decide

/-- A multi-effect use split still changes only the selected balance coordinate in this query. -/
example :
    balanceScope.quantity? [splitPurchase] assetB unit =
      some (Quantity.ofQuanta (-11)) := by
  decide

example :
    balanceScope.quantity? [splitPurchase] useA unit = none := by
  decide

example :
    balanceScope.quantity? [splitPurchase] useB unit = none := by
  decide

/--
Selection is query evidence: changing it changes the view without changing any
retained Event or Effect.
-/
private def narrowerScope : BalanceScope :=
  { loci := [assetA]
    nodup := by decide }

example :
    narrowerScope.quantity? [transfer] assetB unit = none := by
  decide

end Loam.Experiments.Observation101
