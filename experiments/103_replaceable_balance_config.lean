import Loam.Application.CurrentQuantity

namespace Loam.Experiments.Observation103

open Loam.Core
open Loam.Application

set_option autoImplicit false

/--
The smallest experiment-local representation of one current balance-query
configuration: just the neutral coordinates selected by the application.

There is deliberately no policy identity, Account type, registry, append-only
memory, correction relation, provenance, or chronology here. List order and
repetition are representation details only because selection is membership.
-/
abbrev BalanceConfig := List EffectCoordinate

/--
Feed one replaceable application configuration into the existing production
current-quantity projection. The retained Event/Basis facts remain unchanged.
-/
def inspect?
    (config : BalanceConfig)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (coordinate : EffectCoordinate) : Option CurrentQuantityAnswer :=
  if coordinate ∈ config then
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

/-- One current application configuration selects the two balance coordinates. -/
private def dailyBalances : BalanceConfig :=
  [coordinate wallet, coordinate reserve]

/-- Another replaceable configuration can ask a different question over exactly the same facts. -/
private def alternateView : BalanceConfig :=
  [coordinate wallet, coordinate use]

example :
    inspect? dailyBalances
        events eventCorrections bases basisCorrections (coordinate wallet) =
      some (.current (Quantity.ofQuanta 93)) := by
  decide

example :
    inspect? dailyBalances
        events eventCorrections bases basisCorrections (coordinate reserve) =
      some (.current (Quantity.ofQuanta 0)) := by
  decide

/-- Basis-bearing `use` stays outside the ordinary daily balance configuration. -/
example :
    inspect? dailyBalances
        events eventCorrections bases basisCorrections (coordinate use) = none := by
  decide

/-- Replacing only configuration changes the selected question, not retained facts. -/
example :
    inspect? alternateView
        events eventCorrections bases basisCorrections (coordinate use) =
      some (.current (Quantity.ofQuanta 7)) := by
  decide

/-- Repeated rows do not create another semantic selection or require admission machinery. -/
example :
    inspect? [coordinate wallet, coordinate wallet]
        events eventCorrections bases basisCorrections (coordinate wallet) =
      inspect? [coordinate wallet]
        events eventCorrections bases basisCorrections (coordinate wallet) := by
  decide

/-- Configuration order also does not change the selected quantity answer. -/
example :
    inspect? [coordinate reserve, coordinate wallet]
        events eventCorrections bases basisCorrections (coordinate wallet) =
      inspect? [coordinate wallet, coordinate reserve]
        events eventCorrections bases basisCorrections (coordinate wallet) := by
  decide

end Loam.Experiments.Observation103
