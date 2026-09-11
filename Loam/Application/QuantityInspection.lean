import Loam.Application.CorrectionFrontier
import Loam.Core.EventCorrectionMemory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Quantity inspection

The first production application operation stays inside the existing Lean type
world. It consumes retained Practical Core memories directly and returns a
small household-facing answer vocabulary without promoting that vocabulary
into the Core.

The operation is deliberately read-only. It does not load files, publish data,
or claim that a recorded/effective quantity is a balance or universally current
state. For multiple corrections it exposes a quantity only when the correction
facts justify one disjoint-path frontier; otherwise it refuses explicitly.
-/

inductive QuantityInspectionAnswer where
  | recorded (quantity : Quantity)
  | singleCorrectionEffective (quantity : Quantity)
  | frontierEffective (quantity : Quantity)
  | missingCorrectionEndpoint
  | frontierRequired
deriving Repr, DecidableEq

/--
Historical single-correction quantity projection, now owned by the only
Application operation that consumes it.

Both endpoint Events remain recorded. A distinct correction therefore removes
the superseded target contribution without adding the already-recorded
replacement again. The qualified legacy self-relation behavior is retained
unchanged here; this refactor does not reinterpret self-correction as an
admitted frontier.
-/
private def singleCorrectionQuantity?
    (memory : EventMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let projected ← EventCorrection.project? memory correction
  let recorded := EventMemory.quantityAtRecorded memory locus measure
  let effective :=
    if correction.target = correction.replacement then
      recorded
    else
      recorded - Event.quantityAt projected.original locus measure
  return effective

/--
Inspect one explicit locus/measure coordinate using retained Core facts and the
qualified correction projections owned by this Application boundary.

Zero corrections exposes the recorded projection. Exactly one correction keeps
the previously qualified single-correction behavior, including its existing
self-relation behavior. Two or more corrections expose a frontier quantity only
when they form closed, non-branching, non-merging, acyclic correction paths.
Any unsupported multi-correction shape remains fail-closed rather than acquiring
an arrival-order winner.
-/
def inspectQuantity
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId) : QuantityInspectionAnswer :=
  match corrections.corrections with
  | [] =>
      .recorded (EventMemory.quantityAtRecorded events locus measure)
  | [correction] =>
      match singleCorrectionQuantity? events correction locus measure with
      | some quantity => .singleCorrectionEffective quantity
      | none => .missingCorrectionEndpoint
  | _ =>
      match quantityAtCorrectionFrontier? events corrections locus measure with
      | some quantity => .frontierEffective quantity
      | none => .frontierRequired

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

/-- One closed correction exposes exactly the local single-correction projection. -/
private theorem inspectQuantity_singleEffective
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (quantity : Quantity)
    (hCorrections : corrections.corrections = [correction])
    (hEffective :
      singleCorrectionQuantity? events correction locus measure = some quantity) :
    inspectQuantity events corrections locus measure =
      .singleCorrectionEffective quantity := by
  simp [inspectQuantity, hCorrections, hEffective]

/-- One correction with an unavailable endpoint remains an explicit refusal. -/
private theorem inspectQuantity_singleMissing
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = [correction])
    (hMissing :
      singleCorrectionQuantity? events correction locus measure = none) :
    inspectQuantity events corrections locus measure = .missingCorrectionEndpoint := by
  simp [inspectQuantity, hCorrections, hMissing]

/-- A qualified multi-correction frontier exposes exactly its derived quantity. -/
theorem inspectQuantity_multipleEffective
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (first second : EventCorrection)
    (rest : List EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (quantity : Quantity)
    (hCorrections : corrections.corrections = first :: second :: rest)
    (hEffective :
      quantityAtCorrectionFrontier? events corrections locus measure = some quantity) :
    inspectQuantity events corrections locus measure = .frontierEffective quantity := by
  simp [inspectQuantity, hCorrections, hEffective]

/-- An unsupported multi-correction shape remains an explicit frontier refusal. -/
theorem inspectQuantity_multipleRequired
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (first second : EventCorrection)
    (rest : List EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = first :: second :: rest)
    (hMissing :
      quantityAtCorrectionFrontier? events corrections locus measure = none) :
    inspectQuantity events corrections locus measure = .frontierRequired := by
  simp [inspectQuantity, hCorrections, hMissing]

end Loam.Application
