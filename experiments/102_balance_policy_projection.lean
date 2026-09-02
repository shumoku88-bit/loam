import Loam.Application.CurrentQuantity

namespace Loam.Experiments.Observation102

open Loam.Core
open Loam.Application

set_option autoImplicit false

/--
Experiment-local policy selecting which neutral coordinates one balance view
asks about.

Unlike `QuantityBasis`, this carries no quantity evidence. Unlike an Account
registry, it carries no Asset/Liability/Income/Expense role, hierarchy, display
name, ownership, or writer semantics.
-/
structure BalancePolicy where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup

/--
Ask the production current-quantity projection only when this balance query
selects the coordinate. `none` means "not part of this view", while a selected
coordinate retains the production projection's explicit success/failure answer.
-/
def BalancePolicy.inspect?
    (policy : BalancePolicy)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (coordinate : EffectCoordinate) : Option CurrentQuantityAnswer :=
  if coordinate ∈ policy.coordinates then
    some <|
      inspectCurrentQuantityWithBasisCorrections
        events eventCorrections bases basisCorrections
        coordinate.locus coordinate.measure
  else
    none

private def wallet : LocusId := ⟨"wallet"⟩
private def reserve : LocusId := ⟨"reserve"⟩
private def use : LocusId := ⟨"use"⟩
private def unit : MeasureId := ⟨"unit"⟩

private def coordinate (locus : LocusId) : EffectCoordinate :=
  ⟨locus, unit⟩

private def effect (key : String) (locus : LocusId) (quanta : Int) : Effect :=
  Effect.ofQuantity ⟨key⟩ locus unit (Quantity.ofQuanta quanta)

private def purchase : Event :=
  { id := ⟨"purchase"⟩
    effects :=
      [effect "source" wallet (-7),
       effect "use" use 7]
    keyNodup := by decide }

private def events : EventMemory :=
  { events := [purchase]
    idNodup := by decide }

private def basis (id : String) (locus : LocusId) (quanta : Int) : QuantityBasis :=
  QuantityBasis.ofQuantity ⟨id⟩ locus unit (Quantity.ofQuanta quanta)

/--
All three coordinates deliberately have explicit basis evidence.

`reserve` is an explicitly-zero balance candidate. `use` also has explicit zero
basis, representing the old dogfood shape where zero basis was added only to
satisfy an anchored-current premise. Basis presence therefore cannot distinguish
the two application intentions.
-/
private def bases : QuantityBasisMemory :=
  { bases :=
      [basis "wallet-basis" wallet 100,
       basis "reserve-basis" reserve 0,
       basis "use-basis" use 0]
    idNodup := by decide }

private def eventCorrections : EventCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def basisCorrections : QuantityBasisCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def balances : BalancePolicy :=
  { coordinates := [coordinate wallet, coordinate reserve]
    nodup := by decide }

/-- The selected wallet composes its basis with the recorded purchase effect. -/
example :
    balances.inspect?
        events eventCorrections bases basisCorrections (coordinate wallet) =
      some (.current (Quantity.ofQuanta 93)) := by
  decide

/-- An explicitly-zero selected balance remains a real zero row. -/
example :
    balances.inspect?
        events eventCorrections bases basisCorrections (coordinate reserve) =
      some (.current (Quantity.ofQuanta 0)) := by
  decide

/--
A basis-bearing use coordinate is not promoted into this balance view merely
because its basis exists.
-/
example :
    balances.inspect?
        events eventCorrections bases basisCorrections (coordinate use) = none := by
  decide

/--
The same retained Event and Basis facts can support another query policy. Only
the question changes; the physical evidence does not.
-/
private def alternate : BalancePolicy :=
  { coordinates := [coordinate wallet, coordinate use]
    nodup := by decide }

example :
    alternate.inspect?
        events eventCorrections bases basisCorrections (coordinate use) =
      some (.current (Quantity.ofQuanta 7)) := by
  decide

end Loam.Experiments.Observation102
