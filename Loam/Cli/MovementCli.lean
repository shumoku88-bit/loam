import Loam.MovementPublisher
import Loam.ActualDate
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.MovementAdmission
import Loam.MovementManifestAuthority
import Loam.MovementEntry
import Loam.MovementRelationEntry
import Loam.MovementDischargeEntry
import Loam.MovementUi
import Loam.Persistence
import Loam.WriterOwnership

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
callers remain backward compatible: they retain no description unless
`LOAM_DESCRIPTION` is explicitly supplied. Empty text means no description;
Core continues to allow zero or one EventDescription per Event.
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

private def loadEventDescriptionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option Loam.Core.EventDescriptionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventDescriptionMemory? path
  else
    return some Loam.Core.EventDescriptionMemory.empty

private def loadOpenRelationUnitsOrEmpty?
    (path : System.FilePath) : IO (Option (List Loam.Core.RelationUnit)) := do
  if ← path.pathExists then
    Loam.Persistence.loadOpenRelationUnits? path
  else
    return some []

private def loadRelationDischargesOrEmpty?
    (path : System.FilePath) : IO (Option (List Loam.Core.RelationDischarge)) := do
  if ← path.pathExists then
    Loam.Persistence.loadRelationDischarges? path
  else
    return some []

private def loadEventMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return Loam.Core.EventMemory.ofEvents? []

/--
Read exactly one Movement authority backend before interactive input.

Without a manifest root this retains the sidecar behavior used by isolated
regression fixtures. With `LOAM_MOVEMENT_MANIFEST_ROOT`, the selected manifest
generation supplies the hints and verifies its selected families before human
input. The same selected authority, including current Locus publication policy,
is re-read under writer ownership after human think time, so preflight remains
observational rather than publication authority. There is no fallback to
sidecars in manifest mode.
-/
private def preflightForDraft
    (memoryFile : System.FilePath) : IO (Except String Loam.Core.EventMemory) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some rootPath =>
      if rootPath.isEmpty then
        return Except.error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      match ← Loam.MovementManifestAuthority.loadSelectedWorld? (System.FilePath.mk rootPath) with
      | Except.error message => return Except.error message
      | Except.ok world => return Except.ok world.events
  | none =>
      match ← loadEventMemoryForEntry? memoryFile with
      | none =>
          return Except.error "loam: malformed or unsupported event-memory file"
      | some memory =>
          let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
          let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
          let relationFile := Loam.Persistence.openRelationUnitPathForEventMemory memoryFile
          let dischargeFile := Loam.Persistence.relationDischargePathForEventMemory memoryFile
          match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
          | none =>
              return Except.error "loam: malformed or unsupported actual-validity history"
          | some _ =>
              match ← loadEventDescriptionMemoryOrEmpty? descriptionFile with
              | none =>
                  return Except.error "loam: malformed or unsupported event-description memory"
              | some _ =>
                  match ← loadOpenRelationUnitsOrEmpty? relationFile with
                  | none =>
                      return Except.error "loam: malformed or unsupported open-relation stream"
                  | some _ =>
                      match ← loadRelationDischargesOrEmpty? dischargeFile with
                      | none =>
                          return Except.error "loam: malformed or unsupported relation-discharge stream"
                      | some _ =>
                          return Except.ok memory

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
from payment shape, endpoint label, source sign, or amount. The resulting draft
carries no durable Event, validity, RelationUnit, or discharge Event identity.
-/
private def collectMovementDraft
    (memoryFile : System.FilePath) : IO (Except String Loam.MovementAdmission.Draft) := do
  match ← preflightForDraft memoryFile with
  | Except.error message =>
      return Except.error message
  | Except.ok hintMemory =>
      IO.println "Record one movement. Add FROM entries, then TO entries."
      let initial : Loam.MovementUi.Progress := {}
      showDraftProgress initial
      match ← Loam.ActualDate.practicalOccurrenceDate with
      | Except.error message =>
          return Except.error message
      | Except.ok validOn =>
          let afterDate : Loam.MovementUi.Progress := { validOn := some validOn }
          showDraftProgress afterDate
          let description ← practicalDescription
          let knownLoci := Loam.CompletionPrompt.knownLoci hintMemory
          match ← Loam.MovementEntry.collectMovementEffects knownLoci with
          | Except.error message =>
              return Except.error message
          | Except.ok (effects, total) =>
              let ready : Loam.MovementUi.Progress := {
                validOn := some validOn
                movementTotal := some total
              }
              showDraftProgress ready
              match ← Loam.MovementRelationEntry.collect effects with
              | Except.error message => return Except.error message
              | Except.ok relations =>
                  match ← Loam.MovementDischargeEntry.collect with
                  | Except.error message => return Except.error message
                  | Except.ok discharges =>
                      return Except.ok {
                        validOn := validOn
                        description := description
                        effects := effects
                        relations := relations
                        discharges := discharges
                        total := total
                      }

/--
Record one balanced human-facing JPY movement with one occurrence date, optional
human-recognition description, zero or more explicit open relations, and zero or
more explicit relation discharges.

Interactive input is collected without writer ownership. Only once the draft is
complete does the entrance acquire ownership, re-read current canonical state,
re-run world-dependent admission, allocate fresh durable identities, and
publish.

The occurrence date remains separate evidence from the date-free `Event`.
Interactive terminals may add relation evidence and discharge evidence only by
explicitly supplying their semantic coordinates and exact positive quantities.
Redirected callers remain relation/discharge-free unless `LOAM_RELATIONS` or
`LOAM_DISCHARGES` is supplied.

The entrance still persists one generic Event containing negative Effects for
the FROM side and positive Effects for the TO side. This adapter does not infer
open-relation direction or discharge matching from those signs and does not add
Account, ExpenseCategory, EventKind, debit/credit, Transfer, Income, Spending,
Settlement, or a global conservation law to Core.

Household production supplies `LOAM_MOVEMENT_MANIFEST_ROOT` and uses selected
manifest authority for preflight and publication. When that variable is absent,
the sidecar backend remains available only as the existing isolated regression
fixture surface. In manifest mode `MEMORY_FILE` is not consulted for
Movement-family preflight or completion hints.
-/
def recordMovement (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  match ← collectMovementDraft memoryFile with
  | Except.error message =>
      IO.eprintln message
      return 2
  | Except.ok draft =>
      let result ←
        match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
        | none => Loam.MovementPublisher.publishSidecar memoryFile draft
        | some rootPath =>
            if rootPath.isEmpty then
              pure (.error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty")
            else
              Loam.MovementPublisher.publishManifest (System.FilePath.mk rootPath) draft
      match result with
      | .error message => IO.eprintln message; return 2
      | .ok _ =>
          IO.println ("Recorded movement: " ++ toString draft.total ++
            " jpy. Date: " ++ draft.validOn ++ ".")
          return 0


private def usage : String :=
  "Record one balanced JPY movement:\n" ++
  "  ./tools/loam movement MEMORY_FILE\n\n" ++
  "Interactive recording: press Enter at Date [today], optionally enter a description, then optionally add open relation and relation discharge evidence.\n" ++
  "Scripted recording: set LOAM_OCCURRENCE_DATE=YYYY-MM-DD, LOAM_DESCRIPTION, and optionally LOAM_RELATIONS / LOAM_DISCHARGES.\n" ++
  "LOAM_RELATIONS rows: EFFECT_KEY<TAB>E2H|H2E<TAB>EXTERNAL_ID<TAB>POSITIVE_QUANTITY.\n" ++
  "LOAM_DISCHARGES rows: RELATION_ID<TAB>POSITIVE_QUANTITY.\n" ++
  "Manifest authority: LOAM_MOVEMENT_MANIFEST_ROOT=DIR selects initialized manifest authority without legacy fallback.\n" ++
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