import Loam.Application.QuantityInspection
import Loam.Core.QuantityBasisMemory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-- Human-facing current-quantity answer after anchoring Event activity to a basis. -/
inductive CurrentQuantityAnswer where
  | current (quantity : Quantity)
  | basisMissing
  | basisAmbiguous
  | missingEventCorrectionEndpoint
  | eventFrontierRequired
deriving Repr, DecidableEq

private def matchingBases
    (memory : QuantityBasisMemory)
    (locus : LocusId)
    (measure : MeasureId) : List QuantityBasis :=
  memory.bases.filter fun basis =>
    decide (basis.coordinate = ⟨locus, measure⟩)

private def addQuantities (left right : Quantity) : Quantity :=
  Quantity.ofQuanta (left.quanta + right.quanta)

/--
Compose one explicit starting basis with the already-qualified effective Event
quantity at the same coordinate.

Unlike the lower-level Application 008 arithmetic probe, this production
human-facing `current` boundary requires exactly one basis fact for every
coordinate it claims to make current. Missing basis is not silently interpreted
as zero. That keeps an unconfigured pre-existing holding from being presented as
an ordinary current quantity.

Several raw same-coordinate basis facts are retained by `QuantityBasisMemory`
for future append-only revision, but remain ambiguous until a qualified basis
revision frontier is connected in production.
-/
def inspectCurrentQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (locus : LocusId)
    (measure : MeasureId) : CurrentQuantityAnswer :=
  match matchingBases bases locus measure with
  | [] => .basisMissing
  | [basis] =>
      match inspectQuantity events corrections locus measure with
      | .recorded quantity => .current (addQuantities basis.quantity quantity)
      | .singleCorrectionEffective quantity => .current (addQuantities basis.quantity quantity)
      | .frontierEffective quantity => .current (addQuantities basis.quantity quantity)
      | .missingCorrectionEndpoint => .missingEventCorrectionEndpoint
      | .frontierRequired => .eventFrontierRequired
  | _ => .basisAmbiguous

/-- No basis is never silently interpreted as a zero starting holding. -/
theorem inspectCurrentQuantity_missingBasis
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) :
    inspectCurrentQuantity
      events corrections { bases := [], idNodup := by simp } locus measure =
      .basisMissing := by
  simp [inspectCurrentQuantity, matchingBases]

end Loam.Application
