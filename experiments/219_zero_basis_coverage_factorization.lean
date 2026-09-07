import Loam.Application.CurrentQuantity

namespace Loam.Experiments.Observation219

open Loam.Core
open Loam.Application

set_option autoImplicit false

/--
Experiment-local evidence that one finite set of neutral quantity coordinates is
known to begin at exact zero for the selected retained-history image.

This is deliberately not an Account registry, balance-view policy, or accounting
role. It carries no quantity other than the common zero and no per-coordinate
stable identity.
-/
structure ZeroOriginCoverage where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup

private def liftInspection : QuantityInspectionAnswer → CurrentQuantityAnswer
  | .recorded quantity => .current quantity
  | .singleCorrectionEffective quantity => .current quantity
  | .frontierEffective quantity => .current quantity
  | .missingCorrectionEndpoint => .missingEventCorrectionEndpoint
  | .frontierRequired => .eventFrontierRequired

/--
Use ordinary correction-aware Event quantity only for coordinates explicitly
covered by the zero-origin boundary. An uncovered coordinate remains
`basisMissing`; absence is never strengthened into zero.
-/
def ZeroOriginCoverage.inspect
    (coverage : ZeroOriginCoverage)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) : CurrentQuantityAnswer :=
  if coordinate ∈ coverage.coordinates then
    liftInspection <|
      inspectQuantity events eventCorrections coordinate.locus coordinate.measure
  else
    .basisMissing

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

private def noEventCorrections : EventCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def basis (id : String) (locus : LocusId) (quanta : Int) : QuantityBasis :=
  QuantityBasis.ofQuantity ⟨id⟩ locus unit (Quantity.ofQuanta quanta)

private def zeroBases : QuantityBasisMemory :=
  { bases :=
      [basis "wallet-zero" wallet 0,
       basis "reserve-zero" reserve 0]
    idNodup := by decide }

private def zeroCoverage : ZeroOriginCoverage :=
  { coordinates := [coordinate wallet, coordinate reserve]
    nodup := by decide }

/--
For a covered coordinate, an explicit zero QuantityBasis contributes no numeric
information beyond the correction-aware Event quantity.
-/
example :
    inspectCurrentQuantity
        events noEventCorrections zeroBases wallet unit =
      zeroCoverage.inspect events noEventCorrections (coordinate wallet) := by
  decide

/-- The same factorization preserves an explicitly-known zero with no activity. -/
example :
    inspectCurrentQuantity
        events noEventCorrections zeroBases reserve unit =
      zeroCoverage.inspect events noEventCorrections (coordinate reserve) := by
  decide

/--
The domain cannot be erased: a coordinate outside the retained zero-origin
coverage remains missing rather than becoming an implicit zero/current answer.
-/
example :
    inspectCurrentQuantity
        events noEventCorrections zeroBases use unit =
      zeroCoverage.inspect events noEventCorrections (coordinate use) := by
  decide

example :
    zeroCoverage.inspect events noEventCorrections (coordinate use) =
      .basisMissing := by
  decide

private def nonzeroBases : QuantityBasisMemory :=
  { bases :=
      [basis "wallet-start" wallet 100,
       basis "reserve-zero" reserve 0]
    idNodup := by decide }

/--
Negative witness: the factorization is not a replacement for general
QuantityBasis. A non-zero observed starting quantity carries information that a
zero-origin domain cannot reconstruct.
-/
example :
    inspectCurrentQuantity
        events noEventCorrections nonzeroBases wallet unit =
      .current (Quantity.ofQuanta 93) := by
  decide

example :
    zeroCoverage.inspect events noEventCorrections (coordinate wallet) =
      .current (Quantity.ofQuanta (-7)) := by
  decide

example :
    inspectCurrentQuantity
        events noEventCorrections nonzeroBases wallet unit ≠
      zeroCoverage.inspect events noEventCorrections (coordinate wallet) := by
  decide

end Loam.Experiments.Observation219
