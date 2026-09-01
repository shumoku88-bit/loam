import Loam.Application.QuantityBasisFrontier
import Loam.Application.QuantityInspection

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-- Human-facing current-quantity answer after anchoring Event activity to a basis. -/
inductive CurrentQuantityAnswer where
  | current (quantity : Quantity)
  | basisMissing
  | basisFrontierRequired
  | missingEventCorrectionEndpoint
  | eventFrontierRequired
deriving Repr, DecidableEq

private def matchingBases
    (bases : List QuantityBasis)
    (locus : LocusId)
    (measure : MeasureId) : List QuantityBasis :=
  bases.filter fun basis =>
    decide (basis.coordinate = ⟨locus, measure⟩)

private def addQuantities (left right : Quantity) : Quantity :=
  Quantity.ofQuanta (left.quanta + right.quanta)

/--
Compose one admitted current basis with the already-qualified effective Event
quantity at the same coordinate.

Historical same-coordinate basis facts may coexist in raw memory. They are
therefore projected through an explicit append-only basis-correction frontier
before one basis is selected. A missing basis is still not silently interpreted
as zero, and an inadmissible basis frontier does not produce a partial answer.
-/
def inspectCurrentQuantityWithBasisCorrections
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) : CurrentQuantityAnswer :=
  match admittedQuantityBasisFrontier? bases basisCorrections with
  | none => .basisFrontierRequired
  | some frontier =>
      match matchingBases frontier locus measure with
      | [] => .basisMissing
      | [basis] =>
          match inspectQuantity events eventCorrections locus measure with
          | .recorded quantity => .current (addQuantities basis.quantity quantity)
          | .singleCorrectionEffective quantity => .current (addQuantities basis.quantity quantity)
          | .frontierEffective quantity => .current (addQuantities basis.quantity quantity)
          | .missingCorrectionEndpoint => .missingEventCorrectionEndpoint
          | .frontierRequired => .eventFrontierRequired
      | _ => .basisFrontierRequired

/--
Backward-compatible no-basis-correction boundary. Once historical duplicate
basis facts exist, this boundary fails closed rather than choosing one by raw
memory order.
-/
def inspectCurrentQuantity
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (locus : LocusId)
    (measure : MeasureId) : CurrentQuantityAnswer :=
  inspectCurrentQuantityWithBasisCorrections
    events eventCorrections bases
    { corrections := [], idNodup := by simp }
    locus measure

/-- No basis is never silently interpreted as a zero starting holding. -/
theorem inspectCurrentQuantity_missingBasis
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) :
    inspectCurrentQuantity
      events corrections { bases := [], idNodup := by simp } locus measure =
      .basisMissing := by
  simp [inspectCurrentQuantity, inspectCurrentQuantityWithBasisCorrections, matchingBases]

end Loam.Application
