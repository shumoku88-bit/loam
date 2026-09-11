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

/--
A covered coordinate delegates exactly to the ordinary correction-aware Event
quantity inspection. Zero-origin evidence gates the question; it does not add a
second quantity engine or alter the selected Event frontier.
-/
theorem inspectZeroOriginQuantity_covered
    (coverage : ZeroOriginCoverage)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate)
    (hCovered : coverage.covers coordinate = true) :
    inspectZeroOriginQuantity coverage events eventCorrections coordinate =
      (match inspectQuantity events eventCorrections coordinate.locus coordinate.measure with
       | .recorded quantity => .current quantity
       | .frontierEffective quantity => .current quantity
       | .missingCorrectionEndpoint => .missingEventCorrectionEndpoint
       | .frontierRequired => .eventFrontierRequired) := by
  simp [inspectZeroOriginQuantity, hCovered, liftInspection]

/--
An uncovered coordinate remains unavailable regardless of Event or correction
memory. Activity is not evidence that retained history begins at exact zero.
-/
theorem inspectZeroOriginQuantity_uncovered
    (coverage : ZeroOriginCoverage)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate)
    (hUncovered : coverage.covers coordinate = false) :
    inspectZeroOriginQuantity coverage events eventCorrections coordinate =
      .coverageMissing := by
  simp [inspectZeroOriginQuantity, hUncovered]

/-- Event activity cannot strengthen an uncovered coordinate into a known zero origin. -/
theorem inspectZeroOriginQuantity_missing
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) :
    inspectZeroOriginQuantity ZeroOriginCoverage.empty events eventCorrections coordinate =
      .coverageMissing := by
  simp [inspectZeroOriginQuantity, ZeroOriginCoverage.covers, ZeroOriginCoverage.empty]

end Loam.Application
