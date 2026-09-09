import Loam.Application.ScheduledOpenWorldInspection

namespace Loam.Observation237

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
Observation 237 tests three ways to connect an independently reviewed semantic
statement to current production Scheduled semantics without introducing a new
Core or Application ontology.

A. concrete-only statement: maximally independent, but it can be proved without
   touching production at all;
B. direct-import statement: production-relevant, but it shares LOAM vocabulary;
C. neutral judgement + explicit bridge: independent review vocabulary remains
   small while the proof is forced through the production result.
-/

namespace Independent

/-- Minimal review vocabulary. `negative` is deliberately present even though the
current production Scheduled surface has no constructor that may justify it. -/
inductive Judgement where
  | positive
  | negative
  | unknown
  | refused
deriving Repr, DecidableEq

/-- A deliberately concrete claim. It is independently reviewable, but has no
mechanical dependency on the production implementation. -/
def concreteOnlyClaim : Bool := true

theorem concreteOnlyCanPassWithoutProduction : concreteOnlyClaim = true := by
  rfl

end Independent

/-! ## Production fixture -/

private def emptyScheduled : ScheduledMemory Nat :=
  { occurrences := [], idNodup := by simp }

private def emptyCompletions : ScheduledCompletionMemory :=
  { completions := [], scheduledNodup := by simp, actualNodup := by simp }

private def emptyRetirements : ScheduledRetirementMemory :=
  { retirements := [], scheduledNodup := by simp }

private def emptyReplacements : ScheduledReplacementMemory :=
  { replacements := [], sourceNodup := by simp, replacementNodup := by simp }

private def emptyEvents : EventMemory :=
  { events := [], idNodup := by simp }

private def productionEmptyDay : CurrentScheduledDayEvidenceResult Nat :=
  currentScheduledDayEvidenceWithReplacement
    emptyScheduled emptyCompletions emptyRetirements emptyReplacements emptyEvents 7

/-- B: this checks the current production implementation directly, but the claim
is written in LOAM's own result vocabulary. -/
def directImportIsUnknown : Bool :=
  match productionEmptyDay with
  | .unknown => true
  | _ => false

theorem directImportTouchesProduction : directImportIsUnknown = true := by
  native_decide

/-! ## Neutral correspondence bridge -/

/--
The bridge is the intentionally visible correspondence edge. It is experiment-
local and does not enter Core or Application.

Malformed lifecycle/replacement evidence remains refusal rather than ordinary
unknown. No current production result maps to an independently reviewed negative
claim because current production has no completeness-authorized NotDue result.
-/
def bridge {Time : Type} :
    CurrentScheduledDayEvidenceResult Time → Independent.Judgement
  | .due _ _ => .positive
  | .unknown => .unknown
  | .unknownCompletionScheduled => .refused
  | .unknownRetirementScheduled => .refused
  | .unknownReplacementScheduled => .refused
  | .invalidReplacementGraph => .refused
  | .conflictingTerminalEvidence => .refused

/-- C: the reviewed judgement is independent, while this proof must evaluate the
actual production Scheduled reader before crossing the explicit bridge. -/
theorem bridgedProductionAbsenceIsUnknown :
    bridge productionEmptyDay = Independent.Judgement.unknown := by
  native_decide

/-- The bridge cannot manufacture a negative household claim from any result the
current production surface can express. -/
theorem bridgeNeverNegative {Time : Type}
    (result : CurrentScheduledDayEvidenceResult Time) :
    bridge result ≠ Independent.Judgement.negative := by
  cases result <;> simp [bridge]

/-- Malformed production evidence remains distinguishable from ordinary absence
at the independent review surface. -/
theorem malformedReplacementRemainsRefused {Time : Type} :
    bridge (CurrentScheduledDayEvidenceResult.unknownReplacementScheduled :
      CurrentScheduledDayEvidenceResult Time) = Independent.Judgement.refused := by
  rfl

end Loam.Observation237
