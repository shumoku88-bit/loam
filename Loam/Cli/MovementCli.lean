import Loam.ActualDate
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.MovementAdmission
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
Read current files before interactive input only as a convenience and
malformation preflight. Returned Event memory feeds Locus completion hints; none
of these snapshots is publication authority. Canonical state is re-read under
writer ownership after human think time.
-/
private def preflightForDraft
    (memoryFile : System.FilePath) : IO (Except String Loam.Core.EventMemory) := do
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
Re-read current canonical state and publish one already-collected draft while
holding the existing writer-ownership boundary.

Fresh Event/RelationUnit identities are chosen by `MovementAdmission.admit?`, not
while the user types. The same typed admission seam is usable by a different
physical publisher without teaching admission about sidecars or authority
selectors.

Publication order remains the currently qualified sidecar protocol:

```text
validity / optional description supporting evidence
-> required positive RelationUnit stream update when any
-> required RelationDischarge stream update when any
-> Event last as authority commit
```

The relative order among supporting families is not a cross-stream transaction.
If Event publication fails after a relation or discharge update, retained rows
remain raw inert provenance under the existing sidecar recovery rules.
-/
private def publishDraftUnderOwnership
    (memoryPath : String)
    (draft : Loam.MovementAdmission.Draft) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
  let relationFile := Loam.Persistence.openRelationUnitPathForEventMemory memoryFile
  let dischargeFile := Loam.Persistence.relationDischargePathForEventMemory memoryFile
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      IO.eprintln "loam: malformed or unsupported event-memory file"
      return 2
  | some memory =>
      match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
      | none =>
          IO.eprintln "loam: malformed or unsupported actual-validity history"
          return 2
      | some history =>
          match ← loadEventDescriptionMemoryOrEmpty? descriptionFile with
          | none =>
              IO.eprintln "loam: malformed or unsupported event-description memory"
              return 2
          | some descriptions =>
              match ← loadOpenRelationUnitsOrEmpty? relationFile with
              | none =>
                  IO.eprintln "loam: malformed or unsupported open-relation stream"
                  return 2
              | some relations =>
                  match ← loadRelationDischargesOrEmpty? dischargeFile with
                  | none =>
                      IO.eprintln "loam: malformed or unsupported relation-discharge stream"
                      return 2
                  | some discharges =>
                      let world : Loam.MovementAdmission.World := {
                        events := memory
                        validity := history
                        descriptions := descriptions
                        relations := relations
                        discharges := discharges
                      }
                      match Loam.MovementAdmission.admit? world draft with
                      | Except.error message =>
                          IO.eprintln message
                          return 2
                      | Except.ok admitted =>
                          showAdmissionPreview
                            draft.total draft.validOn draft.description
                            admitted.newRelations.length admitted.newDischarges.length
                            admitted.event.id
                          if ← Loam.Persistence.saveActualValidityHistory?
                              validityFile admitted.world.validity then
                            let descriptionPublished ←
                              match draft.description with
                              | none => pure true
                              | some _ =>
                                  Loam.Persistence.saveEventDescriptionMemory?
                                    descriptionFile admitted.world.descriptions
                            if !descriptionPublished then
                              IO.eprintln
                                "loam: description was not published; the already-published date evidence remains inert"
                              return 2
                            else
                              let relationPublished ←
                                if admitted.newRelations.isEmpty then
                                  pure true
                                else
                                  Loam.Persistence.saveOpenRelationUnits?
                                    relationFile admitted.world.relations
                              if !relationPublished then
                                IO.eprintln
                                  "loam: open relation evidence was not published; Event authority was not published"
                                return 2
                              else
                                let dischargePublished ←
                                  if admitted.newDischarges.isEmpty then
                                    pure true
                                  else
                                    Loam.Persistence.saveRelationDischarges?
                                      dischargeFile admitted.world.discharges
                                if !dischargePublished then
                                  IO.eprintln
                                    "loam: relation discharge evidence was not published; Event authority was not published"
                                  return 2
                                else if ← Loam.Persistence.saveEventMemory?
                                    memoryFile admitted.world.events then
                                  IO.println
                                    ("Recorded movement: " ++ toString draft.total ++
                                      " jpy. Date: " ++ draft.validOn ++ ".")
                                  return 0
                                else
                                  IO.eprintln
                                    "loam: event was not published; already-published supporting, open-relation, and relation-discharge evidence remains inert until that EventId exists"
                                  return 2
                          else
                            IO.eprintln "loam: occurrence date evidence could not be published"
                            return 2

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
-/
def recordMovement (memoryPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  match ← collectMovementDraft memoryFile with
  | Except.error message =>
      IO.eprintln message
      return 2
  | Except.ok draft =>
      Loam.WriterOwnership.withOwnership
        memoryFile
        (publishDraftUnderOwnership memoryPath draft)

private def usage : String :=
  "Record one balanced JPY movement:\n" ++
  "  ./tools/loam movement MEMORY_FILE\n\n" ++
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
