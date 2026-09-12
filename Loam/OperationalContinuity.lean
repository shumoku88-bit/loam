import Loam.ActualDate
import Loam.ActualReview
import Loam.ScheduledReview

namespace Loam.OperationalContinuity

set_option autoImplicit false

/-!
# Read-only operational continuity diagnosis

This boundary does not weaken LOAM's fail-closed semantics and does not repair,
rewrite, migrate, or select household authority. It translates a failed production
startup read into a human-operable diagnosis while preserving the exact technical
message for inspection.

The safety statement is deliberately narrow: `diagnoseStartupRead` only performs
reads, so a failure here cannot itself create or alter a household fact.
-/

structure Diagnosis where
  area : String
  situation : String
  safety : String
  nextAction : String
  technical : String
  deriving Repr, DecidableEq

private def readOnlySafety : String :=
  "This diagnosis is read-only. It did not create, change, repair, or discard any household fact."

/-- Translate one exact fail-closed read refusal without hiding its technical cause. -/
def explainReadFailure (area message : String) : Diagnosis :=
  let situation :=
    if message.startsWith "loam: actual authority not found:" then
      "The actual.loam authority file is missing, so LOAM will not guess household actual facts."
    else if message.startsWith "loam: malformed or unsupported actual file:" then
      "The actual.loam authority file cannot be verified, so LOAM refused to treat it as current household data."
    else if message == "loam: selected Movement manifest CURRENT is missing" then
      "The selected Movement authority is unavailable, so LOAM will not guess which household generation is current."
    else if message == "loam: selected Movement manifest CURRENT is malformed or unsupported" then
      "The selected Movement authority cannot be verified, so LOAM refused to treat it as current household data."
    else if message.startsWith "loam: selected Movement object is missing:" then
      "The selected Movement generation is incomplete because one of its referenced objects is missing."
    else if message.startsWith "loam: selected Movement object failed digest verification:" then
      "The selected Movement generation failed integrity verification and was not trusted."
    else if message == "loam: selected Movement generation failed production typed decoding" then
      "The selected Movement generation is present but cannot be decoded as the production household model."
    else if message == "loam: Scheduled lifecycle authority is missing, malformed, or unsupported" then
      "Scheduled household evidence cannot be verified. LOAM will not reinterpret missing or malformed Scheduled data as an empty schedule."
    else if message.startsWith "loam: Scheduled completion refers to an unknown" ||
        message.startsWith "loam: Scheduled retirement refers to an unknown" ||
        message.startsWith "loam: Scheduled replacement refers to an unknown" then
      "Scheduled lifecycle evidence refers to an identity that its retained occurrence evidence does not justify."
    else if message == "loam: Scheduled replacement graph is cyclic or otherwise invalid" then
      "Scheduled replacement evidence is internally inconsistent, so the current-open view cannot be trusted."
    else if message == "loam: Scheduled terminal evidence conflicts across completion, retirement, or replacement" then
      "Scheduled lifecycle evidence contains conflicting terminal claims, so LOAM refused to choose one silently."
    else if message == "loam: could not determine the local date" then
      "LOAM could not determine the local calendar date needed to open the current household view."
    else
      "LOAM could not verify the household evidence needed for this view and stopped instead of manufacturing an answer."
  let nextAction :=
    if message == "loam: selected Movement manifest CURRENT is missing" then
      "Check the configured Movement authority root. Select or restore a previously qualified CURRENT generation before attempting a write."
    else if message.startsWith "loam: selected Movement manifest CURRENT" ||
        message.startsWith "loam: selected Movement object" ||
        message == "loam: selected Movement generation failed production typed decoding" then
      "Keep the failing generation unchanged for diagnosis. Select or restore a previously qualified Movement generation, then retry the read before writing."
    else if message.startsWith "loam: Scheduled" then
      "Inspect the retained Scheduled lifecycle authority and restore or migrate it through a qualified path. Do not replace the failure with an empty schedule."
    else if message == "loam: could not determine the local date" then
      "Correct the local date/time environment, then retry."
    else
      "Inspect the technical detail below and correct the source evidence before retrying. Do not bypass the refusal by inventing replacement data."
  { area := area
    situation := situation
    safety := readOnlySafety
    nextAction := nextAction
    technical := message }

/--
Exercise the same authority families required to open the production TUI Home view.
No projection result is retained: success means only that the startup read boundary
is currently coherent enough to open.
-/
def diagnoseStartupRead
    (dataDir manifestRoot : System.FilePath) : IO (Except Diagnosis Unit) := do
  let some _today ← Loam.ActualDate.todayIso?
    | return .error (explainReadFailure "Environment" "loam: could not determine the local date")
  match ← Loam.ActualReview.loadRecordsFromManifest
      manifestRoot (some ((dataDir / "corrections.loam").toString)) with
  | .error message =>
      return .error (explainReadFailure "Actual / Movement" message)
  | .ok _ => pure ()
  match ← Loam.ScheduledReview.loadEvidenceFromManifest
      (dataDir / "scheduled.loam") manifestRoot with
  | .error message =>
      return .error (explainReadFailure "Scheduled" message)
  | .ok _ => return .ok ()

/-- Human-facing rendering with exact diagnosis preserved at the bottom. -/
def renderDiagnosis (diagnosis : Diagnosis) : String :=
  "LOAM operational diagnosis\n" ++
  "Status: blocked\n" ++
  "Area: " ++ diagnosis.area ++ "\n\n" ++
  "What happened:\n  " ++ diagnosis.situation ++ "\n\n" ++
  "What did not happen:\n  " ++ diagnosis.safety ++ "\n\n" ++
  "Next safe action:\n  " ++ diagnosis.nextAction ++ "\n\n" ++
  "Technical detail:\n  " ++ diagnosis.technical

/-- Success rendering remains explicit that diagnosis itself performed no writes. -/
def renderReady : String :=
  "LOAM operational diagnosis\n" ++
  "Status: ready\n" ++
  "The production startup read boundary is coherent.\n" ++
  readOnlySafety

end Loam.OperationalContinuity
