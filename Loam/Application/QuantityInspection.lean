import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Quantity inspection

This read-only application boundary consumes retained Core memories and returns a
small household-facing answer vocabulary without promoting that vocabulary into
the Core.

Correction count carries no semantic authority. With no corrections the recorded
projection is exposed directly. With one or more corrections, all effective
quantity calculation goes through the same fail-closed Correction frontier.
-/

inductive QuantityInspectionAnswer where
  | recorded (quantity : Quantity)
  | frontierEffective (quantity : Quantity)
  | missingCorrectionEndpoint
  | frontierRequired
deriving Repr, DecidableEq

/--
Inspect one explicit locus/measure coordinate using retained Core facts.

Missing endpoint references remain a distinct diagnostic because they are useful
to household-facing reports. Other unsupported shapes, including branching,
merging and cycles, remain one frontier refusal. No correction-count-specific
quantity algorithm or winner is selected.
-/
def inspectQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) : QuantityInspectionAnswer :=
  match corrections.corrections with
  | [] =>
      .recorded (EventMemory.quantityAtRecorded events locus measure)
  | _ =>
      if correctionReferencesClosed events corrections then
        match quantityAtCorrectionFrontier? events corrections locus measure with
        | some quantity => .frontierEffective quantity
        | none => .frontierRequired
      else
        .missingCorrectionEndpoint

/-- With no correction facts, expose exactly the Core recorded projection. -/
theorem inspectQuantity_noCorrections
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = []) :
    inspectQuantity events corrections locus measure =
      .recorded (EventMemory.quantityAtRecorded events locus measure) := by
  simp [inspectQuantity, hCorrections]

end Loam.Application
