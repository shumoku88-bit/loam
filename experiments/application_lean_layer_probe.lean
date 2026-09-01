import Loam.Core.CorrectionQuantity
import Loam.Core.EventCorrectionMemory

namespace Loam.ApplicationProbe

open Loam.Core

set_option autoImplicit false

/-!
# Lean application-layer probe

This experiment repeats the Application 001 query boundary and Application 002
writer-admission boundary inside the existing Lean type universe.

Unlike the Dafny probes, these operations do not reconstruct recorded quantity,
effective quantity, correction count, or duplicate-identity status as parallel
host-language summaries. They consume the existing Practical Core values and
call the existing Core operations directly.
-/

inductive QuantityInspectionAnswer where
  | recorded (quantity : Quantity)
  | singleCorrectionEffective (quantity : Quantity)
  | missingCorrectionEndpoint
  | frontierRequired

deriving Repr, DecidableEq

/--
Application 001 expressed directly over the retained Core memories.

Zero corrections exposes the recorded projection. Exactly one correction may
expose the existing single-correction effective projection. A missing endpoint
is an explicit refusal, while two or more correction facts require a frontier
rather than an arbitrary winner.
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
      match EventCorrection.quantityAtEffective? events correction locus measure with
      | some quantity => .singleCorrectionEffective quantity
      | none => .missingCorrectionEndpoint
  | _ =>
      .frontierRequired

/-- With no correction facts, Application 001 exposes exactly the Core recorded projection. -/
theorem inspectQuantity_noCorrections
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = []) :
    inspectQuantity events corrections locus measure =
      .recorded (EventMemory.quantityAtRecorded events locus measure) := by
  simp [inspectQuantity, hCorrections]

/-- One closed correction exposes exactly the existing Core effective projection. -/
theorem inspectQuantity_singleEffective
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (quantity : Quantity)
    (hCorrections : corrections.corrections = [correction])
    (hEffective :
      EventCorrection.quantityAtEffective? events correction locus measure = some quantity) :
    inspectQuantity events corrections locus measure =
      .singleCorrectionEffective quantity := by
  simp [inspectQuantity, hCorrections, hEffective]

/-- One correction with an unavailable endpoint remains an explicit refusal. -/
theorem inspectQuantity_singleMissing
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (correction : EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = [correction])
    (hMissing :
      EventCorrection.quantityAtEffective? events correction locus measure = none) :
    inspectQuantity events corrections locus measure = .missingCorrectionEndpoint := by
  simp [inspectQuantity, hCorrections, hMissing]

/-- Two or more correction facts refuse to invent a current frontier. -/
theorem inspectQuantity_multiple
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (first second : EventCorrection)
    (rest : List EventCorrection)
    (locus : LocusId)
    (measure : MeasureId)
    (hCorrections : corrections.corrections = first :: second :: rest) :
    inspectQuantity events corrections locus measure = .frontierRequired := by
  simp [inspectQuantity, hCorrections]

/--
A publication snapshot is application-local concurrency evidence.

Only equality is observed. The token does not become Event identity, semantic
time, authority, provenance, or a persistent revision format.
-/
structure PublicationSnapshot where
  token : String
deriving Repr, DecidableEq

inductive WriterDecision where
  | publishCandidate (updated : EventMemory)
  | refuseStaleSnapshot
  | refuseDuplicateEventIdentity

/--
Application 002 over the real Core admission operation.

A stale preparation refuses before interpreting candidate admission against the
new state. For a current snapshot, `EventMemory.add?` itself decides whether the
candidate identity is distinct and, on success, supplies the actual admitted
memory that a later physical publication boundary could attempt to publish.
-/
def authorizeWriter
    (observed current : PublicationSnapshot)
    (memory : EventMemory)
    (candidate : Event) : WriterDecision :=
  if observed = current then
    match EventMemory.add? memory candidate with
    | some updated => .publishCandidate updated
    | none => .refuseDuplicateEventIdentity
  else
    .refuseStaleSnapshot

/-- Stale preparation never reaches Core candidate admission. -/
theorem authorizeWriter_stale
    (observed current : PublicationSnapshot)
    (memory : EventMemory)
    (candidate : Event)
    (hStale : observed ≠ current) :
    authorizeWriter observed current memory candidate = .refuseStaleSnapshot := by
  simp [authorizeWriter, hStale]

/-- A current snapshot plus failed Core Event admission is a duplicate-identity refusal. -/
theorem authorizeWriter_current_duplicate
    (snapshot : PublicationSnapshot)
    (memory : EventMemory)
    (candidate : Event)
    (hAdd : EventMemory.add? memory candidate = none) :
    authorizeWriter snapshot snapshot memory candidate = .refuseDuplicateEventIdentity := by
  simp [authorizeWriter, hAdd]

/-- A current snapshot plus successful Core admission carries that exact admitted memory forward. -/
theorem authorizeWriter_current_publish
    (snapshot : PublicationSnapshot)
    (memory updated : EventMemory)
    (candidate : Event)
    (hAdd : EventMemory.add? memory candidate = some updated) :
    authorizeWriter snapshot snapshot memory candidate = .publishCandidate updated := by
  simp [authorizeWriter, hAdd]

/-- While preparation is stale, changing the candidate cannot escape stale refusal. -/
theorem authorizeWriter_stale_ignoresCandidate
    (observed current : PublicationSnapshot)
    (memory : EventMemory)
    (left right : Event)
    (hStale : observed ≠ current) :
    authorizeWriter observed current memory left =
      authorizeWriter observed current memory right := by
  simp [authorizeWriter, hStale]

-- Synthetic executable witnesses. These values contain no household data.

def originalEvent : Event :=
  { id := ⟨"synthetic-original"⟩, effects := [], keyNodup := by simp }

def replacementEvent : Event :=
  { id := ⟨"synthetic-replacement"⟩, effects := [], keyNodup := by simp }

def candidateEvent : Event :=
  { id := ⟨"synthetic-candidate"⟩, effects := [], keyNodup := by simp }

def effectiveMemory : EventMemory :=
  { events := [originalEvent, replacementEvent],
    idNodup := by simp [originalEvent, replacementEvent] }

def duplicateMemory : EventMemory :=
  { events := [candidateEvent], idNodup := by simp }

def emptyMemory : EventMemory :=
  { events := [], idNodup := by simp }

def correction : EventCorrection :=
  { id := ⟨"synthetic-correction-a"⟩,
    target := originalEvent.id,
    replacement := replacementEvent.id }

def secondCorrection : EventCorrection :=
  { id := ⟨"synthetic-correction-b"⟩,
    target := originalEvent.id,
    replacement := replacementEvent.id }

def noCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

def oneCorrection : EventCorrectionMemory :=
  { corrections := [correction], idNodup := by simp }

def twoCorrections : EventCorrectionMemory :=
  { corrections := [correction, secondCorrection],
    idNodup := by simp [correction, secondCorrection] }

def currentSnapshot : PublicationSnapshot := ⟨"synthetic-current"⟩
def staleSnapshot : PublicationSnapshot := ⟨"synthetic-stale"⟩

def quantityAnswerName : QuantityInspectionAnswer → String
  | .recorded _ => "RecordedQuantity"
  | .singleCorrectionEffective _ => "SingleCorrectionEffectiveQuantity"
  | .missingCorrectionEndpoint => "MissingCorrectionEndpoint"
  | .frontierRequired => "FrontierRequired"

def writerDecisionName : WriterDecision → String
  | .publishCandidate _ => "PublishCandidate"
  | .refuseStaleSnapshot => "RefuseStaleSnapshot"
  | .refuseDuplicateEventIdentity => "RefuseDuplicateEventIdentity"

end Loam.ApplicationProbe

open Loam.Core
open Loam.ApplicationProbe

def main : IO Unit := do
  let locus : LocusId := ⟨"synthetic-locus"⟩
  let measure : MeasureId := ⟨"synthetic-measure"⟩

  IO.println <| quantityAnswerName <|
    inspectQuantity emptyMemory noCorrections locus measure
  IO.println <| quantityAnswerName <|
    inspectQuantity effectiveMemory oneCorrection locus measure
  IO.println <| quantityAnswerName <|
    inspectQuantity emptyMemory oneCorrection locus measure
  IO.println <| quantityAnswerName <|
    inspectQuantity emptyMemory twoCorrections locus measure

  IO.println <| writerDecisionName <|
    authorizeWriter currentSnapshot currentSnapshot emptyMemory candidateEvent
  IO.println <| writerDecisionName <|
    authorizeWriter currentSnapshot currentSnapshot duplicateMemory candidateEvent
  IO.println <| writerDecisionName <|
    authorizeWriter staleSnapshot currentSnapshot emptyMemory candidateEvent
