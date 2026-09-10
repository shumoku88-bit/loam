import Loam.Application.ZeroOriginQuantity

namespace Loam.Observations.Observation242

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
Observation 242

Global canonical-basis witness for ZeroOriginCoverage.

Two worlds keep Event and EventCorrection evidence exactly identical and differ
only in whether one coordinate has explicit zero-origin coverage. The current
production query vocabulary distinguishes those worlds.
-/

private def cashJpy : EffectCoordinate :=
  ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩

private def noEvents : EventMemory :=
  { events := [], idNodup := by simp }

private def noCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def cashCovered : ZeroOriginCoverage :=
  { coordinates := [cashJpy], nodup := by simp }

/--
With explicit coverage, the unchanged empty Event world answers exact current
zero. The zero comes from the Event projection; coverage only admits the current
question.
-/
theorem covered_world_answers_current_zero :
    inspectZeroOriginQuantity cashCovered noEvents noCorrections cashJpy =
      .current (Quantity.ofQuanta 0) := by
  have hCovered : ZeroOriginCoverage.covers cashCovered cashJpy = true := by
    simp [ZeroOriginCoverage.covers, cashCovered]
  rw [inspectZeroOriginQuantity_covered
    cashCovered noEvents noCorrections cashJpy hCovered]
  have hNoCorrections : noCorrections.corrections = [] := rfl
  rw [inspectQuantity_noCorrections
    noEvents noCorrections cashJpy.locus cashJpy.measure hNoCorrections]
  rfl

/--
With the same Event and Correction evidence but no coverage, the current query
must remain unavailable rather than manufacturing zero-origin history.
-/
theorem uncovered_world_refuses_current :
    inspectZeroOriginQuantity ZeroOriginCoverage.empty noEvents noCorrections cashJpy =
      .coverageMissing := by
  exact inspectZeroOriginQuantity_missing noEvents noCorrections cashJpy

/--
This is the indispensability witness: erasing ZeroOriginCoverage identifies two
worlds that the current production operation vocabulary can distinguish.
-/
theorem zero_origin_coverage_is_q_observable :
    inspectZeroOriginQuantity cashCovered noEvents noCorrections cashJpy ≠
      inspectZeroOriginQuantity ZeroOriginCoverage.empty noEvents noCorrections cashJpy := by
  rw [covered_world_answers_current_zero, uncovered_world_refuses_current]
  decide

end Loam.Observations.Observation242
