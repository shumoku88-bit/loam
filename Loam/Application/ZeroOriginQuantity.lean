import Loam.Application.QuantityInspection
import Loam.Core.ZeroOriginCoverage

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Zero-origin current quantity

This application boundary uses ordinary correction-aware Event quantity only
when an independent finite zero-origin evidence set admits the coordinate.
Event activity itself never creates known origin completeness.
-/

inductive ZeroOriginQuantityAnswer where
  | current (quantity : Quantity)
  | coverageMissing
  | missingEventCorrectionEndpoint
  | eventFrontierRequired
deriving Repr, DecidableEq

private def liftInspection : QuantityInspectionAnswer → ZeroOriginQuantityAnswer
  | .recorded quantity => .current quantity
  | .singleCorrectionEffective quantity => .current quantity
  | .frontierEffective quantity => .current quantity
  | .missingCorrectionEndpoint => .missingEventCorrectionEndpoint
  | .frontierRequired => .eventFrontierRequired

/--
Inspect one current coordinate only after explicit zero-origin admission.
Uncovered coordinates remain unknown even when selected Events mention them.
-/
def inspectZeroOriginQuantity
    (coverage : ZeroOriginCoverage)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) : ZeroOriginQuantityAnswer :=
  if coverage.covers coordinate then
    liftInspection <|
      inspectQuantity events eventCorrections coordinate.locus coordinate.measure
  else
    .coverageMissing

/-- Event activity cannot strengthen an uncovered coordinate into a known zero origin. -/
theorem inspectZeroOriginQuantity_missing
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) :
    inspectZeroOriginQuantity ZeroOriginCoverage.empty events eventCorrections coordinate =
      .coverageMissing := by
  simp [inspectZeroOriginQuantity, ZeroOriginCoverage.covers, ZeroOriginCoverage.empty]

end Loam.Application
