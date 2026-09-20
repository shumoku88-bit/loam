import Loam.ActualDate
import Loam.ActualAuthority
import Loam.MovementAdmission
import Loam.MovementDraftReview
import Loam.HouseholdCommand
import Loam.Cli.Movement.Entry
import Loam.Cli.Movement.RelationEntry
import Loam.Cli.Movement.DischargeEntry
import Loam.Cli.Movement.Ui

namespace Loam.MovementCli

set_option autoImplicit false

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

/--
Collect optional EventDescription text for one practical Movement draft.

Interactive terminals expose a small human-recognition field. Redirected/scripted
callers retain no description unless `LOAM_DESCRIPTION` is explicitly supplied.
Empty text means no description; Core continues to allow zero or one
EventDescription per Event.
-/
private def practicalDescription : IO (Option String) := do
  match ← IO.getEnv "LOAM_DESCRIPTION" with
  | some text =>
      if text.isEmpty then return none else return some text
  | none =>
      let stdin ← IO.getStdin
      let stdout ← IO.getStdout
      if (← stdin.isTty) && (← stdout.isTty) then
        let text ← promptLine "Description (optional): "
        if text.isEmpty then return none else return some text
      else
        return none


/--
Select one Measure for the practical movement entrance.

JPY remains the no-configuration default. Interactive callers may replace it,
and scripted callers may set `LOAM_MEASURE`. This selects quantity identity
only; it does not imply currency, valuation, FX, or display-scale semantics.
-/
private def practicalMeasure : IO (Except String Loam.Core.MeasureId) := do
  let selected ←
    match ← IO.getEnv "LOAM_MEASURE" with
    | some token => pure token
    | none =>
        let stdin ← IO.getStdin
        let stdout ← IO.getStdout
        if (← stdin.isTty) && (← stdout.isTty) then
          let entered ← promptLine "Measure [jpy]: "
          pure (if entered.isEmpty then "jpy" else entered)
        else
          pure "jpy"
  if !Loam.Persistence.validToken selected then
    return .error "loam: Measure must be a nonempty single-line token"
  return .ok ⟨selected⟩

private structure RunOptions where
  rootPath : String
  dryRun : Bool

private def resolveRootPath (explicit : Option String) : IO (Except String String) := do
  match explicit with
  | some path =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok path
  | none =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok path
      | none => return .ok "../loam-data"

/-- Resolve publication versus proposal-only mode and the canonical data directory. -/
private def resolveOptions (args : List String) : IO (Except String RunOptions) := do
  let parsed : Except String (Bool × Option String) :=
    match args with
    | [] => .ok (false, none)
    | ["--dry-run"] => .ok (true, none)
    | [path] => .ok (false, some path)
    | ["--dry-run", path] => .ok (true, some path)
    | _ => .error "loam: movement accepts optional --dry-run and at most one LOAM_DATA_DIR argument"
  match parsed with
  | .error message => return .error message
  | .ok (dryRun, explicit) =>
      match ← resolveRootPath explicit with
      | .error message => return .error message
      | .ok rootPath => return .ok { rootPath := rootPath, dryRun := dryRun }

/--
Verify the current normalized Actual authority before human input.

This is observational only. The canonical command path re-reads current
authority under writer ownership after the draft is complete, so human think
time does not authorize publication from stale state.
-/
private def preflightForDraft (rootPath : String) : IO (Except String Unit) := do
  match ← Loam.ActualAuthority.loadSelectedWorld? (System.FilePath.mk rootPath) with
  | .error message => return .error message
  | .ok _ => return .ok ()

private def showDraftProgress
    (progress : Loam.MovementUi.Progress)
    (measure : Option Loam.Core.MeasureId := none) : IO Unit := do
  IO.println ""
  IO.println "Movement draft"
  match progress.validOn with
  | none => IO.println "  [?] occurrence date"
  | some validOn => IO.println ("  [ok] occurrence date: " ++ validOn)
  match progress.movementTotal with
  | none => IO.println "  [?] balanced FROM / TO movement"
  | some total =>
      let unit := (measure.map fun item => " " ++ item.token).getD ""
      IO.println ("  [ok] balanced movement: " ++ toString total ++ unit)
  match Loam.MovementUi.obligations progress with
  | [] => IO.println "  ready to request admission"
  | pending =>
      IO.println
        ("  outstanding: " ++
          String.intercalate ", " (pending.map Loam.MovementUi.obligationLabel))

/--
Collect a complete Movement draft without holding cross-process writer
ownership across human think time.

After signed Movement Effects exist, open-relation and relation-discharge meaning
are collected as separate optional overlays. No discharge target is inferred
from payment shape, endpoint label, source sign, or amount.
-/
private def collectMovementDraft
    (rootPath : String) : IO (Except String Loam.MovementAdmission.Draft) := do
  match ← preflightForDraft rootPath with
  | .error message => return .error message
  | .ok () =>
      IO.println "Record one movement. Add FROM entries, then TO entries."
      let initial : Loam.MovementUi.Progress := {}
      showDraftProgress initial
      match ← Loam.ActualDate.practicalOccurrenceDate with
      | .error message => return .error message
      | .ok validOn =>
          let afterDate : Loam.MovementUi.Progress := { validOn := some validOn }
          showDraftProgress afterDate
          let description ← practicalDescription
          let .ok measure ← practicalMeasure
            | .error message => return .error message
          match ← Loam.MovementEntry.collectMovementEffects measure with
          | .error message => return .error message
          | .ok (effects, total) =>
              let ready : Loam.MovementUi.Progress := {
                validOn := some validOn
                movementTotal := some total
              }
              showDraftProgress ready (some measure)
              match ← Loam.MovementRelationEntry.collect effects with
              | .error message => return .error message
              | .ok relations =>
                  match ← Loam.MovementDischargeEntry.collect with
                  | .error message => return .error message
                  | .ok discharges =>
                      return .ok {
                        validOn := validOn
                        description := description
                        effects := effects
                        relations := relations
                        discharges := discharges
                        total := total
                      }

/--
Render the semantic admission result after authoritative publication succeeds.
Relation and discharge evidence remain separate from signed Movement Effects; no
sign-based or automatic settlement interpretation is introduced.
-/
private def showAdmissionResult
    (measure : Loam.Core.MeasureId)
    (total : Int)
    (validOn : String)
    (description : Option String)
    (relationCount : Nat)
    (dischargeCount : Nat)
    (eventId : Loam.Core.EventId) : IO Unit := do
  IO.println ""
  IO.println "Admission result"
  IO.println ("  movement: " ++ toString total ++ " " ++ measure.token)
  IO.println ("  date: " ++ validOn)
  match description with
  | some text => IO.println ("  description: " ++ text)
  | none => pure ()
  IO.println ("  event: " ++ eventId.token)
  IO.println "  [ok] movement totals agree"
  IO.println "  [ok] effect identities admitted"
  IO.println "  [ok] Event identity admitted"
  IO.println "  [ok] occurrence-date evidence admitted"
  if relationCount = 0 then
    IO.println "  [ok] open relation decision: none"
  else
    IO.println ("  [ok] open relation evidence admitted: " ++ toString relationCount)
  if dischargeCount = 0 then
    IO.println "  [ok] relation discharge decision: none"
  else
    IO.println ("  [ok] relation discharge evidence admitted: " ++ toString dischargeCount)
  IO.println "  [ok] authoritative Actual publication complete"

private def showDryRunResult (draft : Loam.MovementAdmission.Draft) : IO Unit := do
  IO.println ""
  IO.println "Movement proposal"
  let measure := (draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩
  IO.println ("  movement: " ++ toString draft.total ++ " " ++ measure.token)
  IO.println ("  date: " ++ draft.validOn)
  match draft.description with
  | some text => IO.println ("  description: " ++ text)
  | none => pure ()
  IO.println "  [ok] admissible against current household evidence"
  IO.println "  [ok] persistence: none"
  IO.println "  [ok] Event identity: not reserved"
  IO.println "  proposal only; a later publication must re-check current authority"

/--
Record one balanced human-facing single-Measure movement with one occurrence date, optional
human-recognition description, zero or more explicit open relations, and zero or
more explicit relation discharges against the New-only canonical data directory.
-/
def recordMovement (rootPath : String) : IO UInt32 := do
  match ← collectMovementDraft rootPath with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok draft =>
      match ← Loam.HouseholdCommand.record (System.FilePath.mk rootPath) draft with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok eventId =>
          let measure := (draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩
          showAdmissionResult
            measure draft.total draft.validOn draft.description
            draft.relations.length draft.discharges.length eventId
          IO.println
            ("Recorded movement: " ++ toString draft.total ++ " " ++
              measure.token ++ ". Date: " ++ draft.validOn ++ ".")
          return 0

/--
Collect and check one Movement proposal against current authority without
publishing, reserving identity, or retaining any external-source mapping.
-/
def reviewMovement (rootPath : String) : IO UInt32 := do
  match ← collectMovementDraft rootPath with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok draft =>
      match ← Loam.MovementDraftReview.check (System.FilePath.mk rootPath) draft with
      | .error message =>
          IO.eprintln message
          IO.eprintln "loam: movement proposal not admitted; no LOAM persistence was written"
          return 2
      | .ok () =>
          showDryRunResult draft
          return 0

private def usage : String :=
  "Record or review one balanced single-Measure movement:\n" ++
  "  ./tools/loam movement [LOAM_DATA_DIR]\n" ++
  "  ./tools/loam movement --dry-run [LOAM_DATA_DIR]\n\n" ++
  "Dry-run uses the same draft and admission rules but writes no LOAM persistence and reserves no EventId.\n" ++
  "If LOAM_DATA_DIR is omitted, the LOAM_DATA_DIR environment variable is used, then ../loam-data.\n" ++
  "Interactive recording: press Enter at Date [today], optionally enter a description, then optionally add open relation and relation discharge evidence.\n" ++
  "Scripted recording: set LOAM_OCCURRENCE_DATE=YYYY-MM-DD, optional LOAM_MEASURE (default jpy), LOAM_DESCRIPTION, and optionally LOAM_RELATIONS / LOAM_DISCHARGES.\n" ++
  "LOAM_RELATIONS rows: EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>POSITIVE_QUANTITY.\n" ++
  "LOAM_DISCHARGES rows: RELATION_ID<TAB>POSITIVE_QUANTITY.\n" ++
  "Enter one or more FROM loci and amounts, blank the next FROM locus, then\n" ++
  "enter one or more TO loci and amounts and blank the next TO locus.\n" ++
  "The FROM and TO totals must match exactly."

def run (args : List String) : IO UInt32 := do
  match ← resolveOptions args with
  | .error _ =>
      IO.eprintln usage
      return 2
  | .ok options =>
      if options.dryRun then
        reviewMovement options.rootPath
      else
        recordMovement options.rootPath

end Loam.MovementCli

def main (args : List String) : IO UInt32 :=
  Loam.MovementCli.run args
