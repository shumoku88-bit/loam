import Loam.Application.CurrentQuantity

namespace Loam.Experiments.Observation220

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-- One coordinate/value line in an application-origin snapshot. -/
structure OriginLine where
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

/--
Experiment-local finite starting-state image.

Unlike `QuantityBasisMemory`, this has no stable identity per line and no
append-only correction ancestry. It retains only the information needed by a
pointwise current-quantity read: which coordinates are covered and the exact
starting quantity at each covered coordinate.
-/
structure OriginSnapshot where
  lines : List OriginLine
  coordinateNodup : (lines.map OriginLine.coordinate).Nodup

private def findLine? : List OriginLine → EffectCoordinate → Option OriginLine
  | [], _ => none
  | line :: rest, coordinate =>
      if line.coordinate = coordinate then some line else findLine? rest coordinate

private def addQuantities (left right : Quantity) : Quantity :=
  Quantity.ofQuanta (left.quanta + right.quanta)

private def liftWithOrigin
    (origin : Quantity) : QuantityInspectionAnswer → CurrentQuantityAnswer
  | .recorded quantity => .current (addQuantities origin quantity)
  | .singleCorrectionEffective quantity => .current (addQuantities origin quantity)
  | .frontierEffective quantity => .current (addQuantities origin quantity)
  | .missingCorrectionEndpoint => .missingEventCorrectionEndpoint
  | .frontierRequired => .eventFrontierRequired

/--
Inspect one coordinate from an explicit finite origin snapshot plus the existing
correction-aware Event quantity. Missing snapshot coverage remains
`basisMissing`; it is never strengthened into zero.
-/
def OriginSnapshot.inspect
    (snapshot : OriginSnapshot)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) : CurrentQuantityAnswer :=
  match findLine? snapshot.lines coordinate with
  | none => .basisMissing
  | some line =>
      liftWithOrigin line.quantity <|
        inspectQuantity events eventCorrections coordinate.locus coordinate.measure

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

/-- Same coordinate/value facts, first arbitrary set of per-line identities. -/
private def basesA : QuantityBasisMemory :=
  { bases :=
      [basis "wallet-a" wallet 100,
       basis "reserve-a" reserve 0]
    idNodup := by decide }

/-- Same coordinate/value facts, completely different per-line identities. -/
private def basesB : QuantityBasisMemory :=
  { bases :=
      [basis "wallet-b" wallet 100,
       basis "reserve-b" reserve 0]
    idNodup := by decide }

private def snapshot : OriginSnapshot :=
  { lines :=
      [{ coordinate := coordinate wallet,
         quantity := Quantity.ofQuanta 100 },
       { coordinate := coordinate reserve,
         quantity := Quantity.ofQuanta 0 }]
    coordinateNodup := by decide }

/-- A non-zero starting quantity factors through the finite origin snapshot. -/
example :
    inspectCurrentQuantity events noEventCorrections basesA wallet unit =
      snapshot.inspect events noEventCorrections (coordinate wallet) := by
  decide

/-- The same factorization preserves a covered explicit zero. -/
example :
    inspectCurrentQuantity events noEventCorrections basesA reserve unit =
      snapshot.inspect events noEventCorrections (coordinate reserve) := by
  decide

/-- Coverage remains explicit even when Event activity exists outside it. -/
example :
    inspectCurrentQuantity events noEventCorrections basesA use unit =
      snapshot.inspect events noEventCorrections (coordinate use) := by
  decide

example :
    snapshot.inspect events noEventCorrections (coordinate use) =
      .basisMissing := by
  decide

/-- Distinct stable basis identities are retained evidence, but not observed here. -/
example : basesA ≠ basesB := by
  decide

example :
    inspectCurrentQuantity events noEventCorrections basesA wallet unit =
      inspectCurrentQuantity events noEventCorrections basesB wallet unit := by
  decide

example :
    inspectCurrentQuantity events noEventCorrections basesA reserve unit =
      inspectCurrentQuantity events noEventCorrections basesB reserve unit := by
  decide

/--
Correction ancestry is a stronger piece of evidence than the current snapshot.
The corrected history below starts at 100 and replaces that basis with 120.
-/
private def correctedBases : QuantityBasisMemory :=
  { bases :=
      [basis "wallet-v1" wallet 100,
       basis "wallet-v2" wallet 120,
       basis "reserve-v1" reserve 0]
    idNodup := by decide }

private def correctedBasisMemory : QuantityBasisCorrectionMemory :=
  { corrections :=
      [{ target := ⟨"wallet-v1"⟩,
         replacement := ⟨"wallet-v2"⟩ }]
    idNodup := by decide }

/-- A direct current image with no ancestry can have the same selected value. -/
private def directCurrentBases : QuantityBasisMemory :=
  { bases :=
      [basis "wallet-direct" wallet 120,
       basis "reserve-direct" reserve 0]
    idNodup := by decide }

private def noBasisCorrections : QuantityBasisCorrectionMemory :=
  { corrections := []
    idNodup := by simp }

private def correctedSnapshot : OriginSnapshot :=
  { lines :=
      [{ coordinate := coordinate wallet,
         quantity := Quantity.ofQuanta 120 },
       { coordinate := coordinate reserve,
         quantity := Quantity.ofQuanta 0 }]
    coordinateNodup := by decide }

/-- The correction-aware production answer is the current snapshot answer. -/
example :
    inspectCurrentQuantityWithBasisCorrections
        events noEventCorrections correctedBases correctedBasisMemory wallet unit =
      correctedSnapshot.inspect events noEventCorrections (coordinate wallet) := by
  decide

/-- A direct 120 start yields the same current answer without the correction ancestry. -/
example :
    inspectCurrentQuantityWithBasisCorrections
        events noEventCorrections correctedBases correctedBasisMemory wallet unit =
      inspectCurrentQuantityWithBasisCorrections
        events noEventCorrections directCurrentBases noBasisCorrections wallet unit := by
  decide

/-- But the retained histories themselves are not the same evidence. -/
example : correctedBases ≠ directCurrentBases := by
  decide

example : correctedBasisMemory ≠ noBasisCorrections := by
  decide

end Loam.Experiments.Observation220
