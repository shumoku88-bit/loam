import Loam.ActualDate
import Loam.ActualAuthority
import Loam.MovementAdmission
import Loam.MovementPublisher
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

/-- Resolve the single supported Movement publication authority. -/
private def manifestRoot? : IO (Except String String) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | none =>
      return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT is required for Movement publication"
  | some rootPath =>
      if rootPath.isEmpty then
        return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      return .ok rootPath

/--
Verify the selected manifest generation before human input.

This is observational only. `MovementPublisher` re-reads current selected
authority under writer ownership after the draft is complete, so human think time
does not authorize publication from stale state.
-/
private def preflightForDraft (rootPath : String) : IO (Except String Unit) := do
  match ← Loam.ActualAuthority.loadSelectedWorld? (System.FilePath.mk rootPath) with
  | .error message => return .error message
  | .ok _ => return .ok ()

private def showDraftProgress (progress : Loam.MovementUi.Progress) : IO Unit := do
  IO.println ""
  IO.println "Movement draft"
  match progress.validOn with
  | none => IO.println "  [?] occurrence date"
  | some validOn => IO.println ("  [ok] occurrence date: " ++ validOn)
  match progress.movementTotal with
  | none => IO.println "  [?] balanced FROM / TO movement"
  | some total => IO.println ("  [ok] balanced movement: " ++ toString total ++ " jpy")
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
          match ← Loam.MovementEntry.collectMovementEffects with
          | .error message => return .error message
          | .ok (effects, total) =>
              let ready : Loam.MovementUi.Progress := {
                validOn := some validOn
                movementTotal := some total
              }
              showDraftProgress ready
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
Expose only admission boundaries crossed before publication. Relation and
discharge evidence are reported separately from signed Movement Effects; no
sign-based or automatic settlement interpretation is introduced.
-/
private def showAdmissionPreview
    (total : Int)
    (validOn : String)
    (description : Option String)
    (relationCount : Nat)
    (dischargeCount : Nat)
    (eventId : Loam.Core.EventId) : IO Unit := do
  IO.println ""
  IO.println "Admission preview"
  IO.println ("  movement: " ++ toString total ++ " jpy")
  IO.println ("  date: " ++ validOn)
  match description with
  | some text => IO.println ("  description: " ++ text)
  | none => pure ()
  IO.println ("  event: " ++ eventId.token)
  IO.println "  [ok] movement totals agree"
  IO.println "  [ok] effect identities admitted"
  IO.println "  [ok] Event identity admitted in memory"
  IO.println "  [ok] occurrence-date evidence admitted"
  if relationCount = 0 then
    IO.println "  [ok] open relation decision: none"
  else
    IO.println ("  [ok] open relation evidence admitted: " ++ toString relationCount)
  if dischargeCount = 0 then
    IO.println "  [ok] relation discharge decision: none"
  else
    IO.println ("  [ok] relation discharge evidence admitted: " ++ toString dischargeCount)
  IO.println "  ready to publish"

/--
Record one balanced human-facing JPY movement with one occurrence date, optional
human-recognition description, zero or more explicit open relations, and zero or
more explicit relation discharges.

The CLI is now a thin presentation adapter over the same manifest-aware
`MovementPublisher` used by the production TUI. It owns no sidecar publication
protocol. `LOAM_MOVEMENT_MANIFEST_ROOT` is required; selected authority is
verified before input and re-read by the publisher under writer ownership before
publication.

The legacy `MEMORY_FILE` argument is retained only as a script-compatibility
placeholder in this slice and is not consulted for Movement authority.
-/
def recordMovement (_memoryPath : String) : IO UInt32 := do
  match ← manifestRoot? with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok rootPath =>
      match ← collectMovementDraft rootPath with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok draft =>
          match ← Loam.MovementPublisher.publishManifestDraftWithPreview
              rootPath draft fun receipt =>
                showAdmissionPreview
                  draft.total draft.validOn draft.description
                  receipt.relationCount receipt.dischargeCount receipt.eventId with
          | .error message =>
              IO.eprintln message
              return 2
          | .ok _ =>
              IO.println
                ("Recorded movement: " ++ toString draft.total ++
                  " jpy. Date: " ++ draft.validOn ++ ".")
              return 0

private def usage : String :=
  "Record one balanced JPY movement:\n" ++
  "  LOAM_MOVEMENT_MANIFEST_ROOT=DIR ./tools/loam movement MEMORY_FILE\n\n" ++
  "MEMORY_FILE is retained as a compatibility placeholder and is not Movement authority.\n" ++
  "Interactive recording: press Enter at Date [today], optionally enter a description, then optionally add open relation and relation discharge evidence.\n" ++
  "Scripted recording: set LOAM_OCCURRENCE_DATE=YYYY-MM-DD, LOAM_DESCRIPTION, and optionally LOAM_RELATIONS / LOAM_DISCHARGES.\n" ++
  "LOAM_RELATIONS rows: EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>POSITIVE_QUANTITY.\n" ++
  "LOAM_DISCHARGES rows: RELATION_ID<TAB>POSITIVE_QUANTITY.\n" ++
  "Enter one or more FROM loci and amounts, blank the next FROM locus, then\n" ++
  "enter one or more TO loci and amounts and blank the next TO locus.\n" ++
  "The FROM and TO totals must match exactly."

def run (args : List String) : IO UInt32 :=
  match args with
  | [memoryPath] => recordMovement memoryPath
  | _ => do
      IO.eprintln usage
      return 2

end Loam.MovementCli

def main (args : List String) : IO UInt32 :=
  Loam.MovementCli.run args
