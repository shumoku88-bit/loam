import Loam.ActualDate
import Loam.Application.OpenRelationFrontier
import Loam.Application.RelationDischargeFrontier
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.MovementEntry
import Loam.MovementRelationEntry
import Loam.MovementDischargeEntry
import Loam.MovementUi
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.MovementCli

set_option autoImplicit false

private structure MovementDraft where
  validOn : String
  description : Option String
  effects : List Loam.Core.Effect
  relations : List Loam.MovementRelationEntry.Draft
  discharges : List Loam.MovementDischargeEntry.Draft
  total : Int

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

private def historyMentionsEvent
    (history : Loam.Core.ActualValidityHistory String)
    (id : Loam.Core.EventId) : Bool :=
  history.facts.any fun fact => decide (fact.event = id)

private def relationsMentionEvent
    (relations : List Loam.Core.RelationUnit)
    (id : Loam.Core.EventId) : Bool :=
  relations.any fun relation => decide (relation.sourceEvent = id)

private def dischargesMentionEvent
    (discharges : List Loam.Core.RelationDischarge)
    (id : Loam.Core.EventId) : Bool :=
  discharges.any fun discharge => decide (discharge.event = id)

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

/--
Search the bounded operational Event-id namespace used by the practical CLI.
A candidate must be unused by Event memory, retained validity history, the
adjacent description stream, every retained raw RelationUnit source Event, and
every retained raw RelationDischarge later Event.

The relation and discharge checks are essential for Event-last crash residue:
supporting evidence that survived before Event publication reserves that EventId
so a later unrelated movement cannot accidentally activate old raw provenance.
-/
private def freshRecordEventIdFrom
    (memory : Loam.Core.EventMemory)
    (history : Loam.Core.ActualValidityHistory String)
    (descriptions : Loam.Core.EventDescriptionMemory)
    (relations : List Loam.Core.RelationUnit)
    (discharges : List Loam.Core.RelationDischarge) :
    Nat → Nat → Option Loam.Core.EventId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventId := ⟨"record-" ++ toString index⟩
      match Loam.Core.EventMemory.findById? memory candidate with
      | none =>
          if historyMentionsEvent history candidate ||
              (Loam.Core.EventDescriptionMemory.findText? descriptions candidate).isSome ||
              relationsMentionEvent relations candidate ||
              dischargesMentionEvent discharges candidate then
            freshRecordEventIdFrom
              memory history descriptions relations discharges (index + 1) fuel
          else
            some candidate
      | some _ =>
          freshRecordEventIdFrom
            memory history descriptions relations discharges (index + 1) fuel

private def freshRecordEventId?
    (memory : Loam.Core.EventMemory)
    (history : Loam.Core.ActualValidityHistory String)
    (descriptions : Loam.Core.EventDescriptionMemory)
    (relations : List Loam.Core.RelationUnit)
    (discharges : List Loam.Core.RelationDischarge) : Option Loam.Core.EventId :=
  freshRecordEventIdFrom memory history descriptions relations discharges 1
    (memory.events.length + history.facts.length + descriptions.entries.length +
      relations.length + discharges.length + 1)

private def relationIdUsed
    (used : List Loam.Core.RelationUnitId)
    (id : Loam.Core.RelationUnitId) : Bool :=
  used.any fun candidate => decide (candidate = id)

private def freshRelationUnitIdFrom
    (used : List Loam.Core.RelationUnitId) :
    Nat → Nat → Option Loam.Core.RelationUnitId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.RelationUnitId :=
        ⟨"relation-" ++ toString index⟩
      if relationIdUsed used candidate then
        freshRelationUnitIdFrom used (index + 1) fuel
      else
        some candidate

private def freshRelationUnitIdsFrom
    (used : List Loam.Core.RelationUnitId) :
    Nat → Nat → Option (List Loam.Core.RelationUnitId)
  | 0, _ => some []
  | remaining + 1, index => do
      let id ← freshRelationUnitIdFrom used index (used.length + 1)
      let rest ← freshRelationUnitIdsFrom (id :: used) remaining (index + 1)
      some (id :: rest)

private def freshRelationUnitIds?
    (relations : List Loam.Core.RelationUnit)
    (count : Nat) : Option (List Loam.Core.RelationUnitId) :=
  freshRelationUnitIdsFrom (relations.map (fun relation => relation.id)) count 1

private def materializeRelationUnits? :
    Loam.Core.EventId →
    List Loam.Core.RelationUnitId →
    List Loam.MovementRelationEntry.Draft →
    Option (List Loam.Core.RelationUnit)
  | _, [], [] => some []
  | eventId, id :: ids, draft :: drafts => do
      let rest ← materializeRelationUnits? eventId ids drafts
      some ({
        id := id
        sourceEvent := eventId
        sourceEffect := draft.sourceEffect
        debtor := draft.debtor
        creditor := draft.creditor
        quantity := draft.quantity
      } :: rest)
  | _, _, _ => none

private def materializeRelationDischarges
    (eventId : Loam.Core.EventId)
    (drafts : List Loam.MovementDischargeEntry.Draft) :
    List Loam.Core.RelationDischarge :=
  drafts.map fun draft => {
    event := eventId
    target := draft.target
    quantity := draft.quantity
  }

/--
Allocate a compatibility identity for the in-memory ActualValidityHistory shape.
V1 persists this identity. V2 persistence normalizes an initial/source date to
Event-rooted representation and does not serialize this token.
-/
private def freshValidityFactIdFrom
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.ActualValidityFactId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.ActualValidityFactId :=
        ⟨"validity-" ++ toString index⟩
      match history.findFactById? candidate with
      | none => some candidate
      | some _ => freshValidityFactIdFrom history (index + 1) fuel

private def freshValidityFactId?
    (history : Loam.Core.ActualValidityHistory String) : Option Loam.Core.ActualValidityFactId :=
  freshValidityFactIdFrom history 1 (history.facts.length + 1)

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
    (memoryFile : System.FilePath) : IO (Except String MovementDraft) := do
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

private def uncoveredRelationSource
    (_ : Loam.Core.EventId) (_ : Loam.Core.EffectKey) : Bool := false

private def relationSourceResolved?
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (eventId : Loam.Core.EventId)
    (effectKey : Loam.Core.EffectKey) : Bool :=
  (Loam.Application.currentRelationState?
    events relations [] uncoveredRelationSource eventId effectKey).isSome

private def relationSourcePositive?
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (eventId : Loam.Core.EventId)
    (effectKey : Loam.Core.EffectKey) : Bool :=
  match Loam.Application.currentRelationState?
      events relations [] uncoveredRelationSource eventId effectKey with
  | some (.knownPositive _) => true
  | _ => false

/--
Require the proposed Event to have one resolvable relation state on every Effect,
and require every newly materialized RelationUnit to land on a known-positive
source frontier.

Completeness is deliberately false here. This writer does not create a relation
cutover merely by supporting relation publication.
-/
private def relationPublicationAdmissible
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (event : Loam.Core.Event)
    (newRelations : List Loam.Core.RelationUnit) : Bool :=
  event.effects.all (fun effect =>
    relationSourceResolved? events relations event.id effect.key) &&
  newRelations.all (fun relation =>
    relationSourcePositive? events relations event.id relation.sourceEffect)

private def dischargePublicationAdmissible
    (events : Loam.Core.EventMemory)
    (relations : List Loam.Core.RelationUnit)
    (discharges : List Loam.Core.RelationDischarge)
    (newDischarges : List Loam.Core.RelationDischarge) : Bool :=
  newDischarges.all fun discharge =>
    match Loam.Application.admittedRelationDischargesFor?
        events relations [] discharges discharge.target with
    | none => false
    | some admitted =>
        admitted.any fun item =>
          decide
            (item.discharge.event = discharge.event ∧
              item.discharge.target = discharge.target ∧
              item.discharge.quantity = discharge.quantity)

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

Fresh Event/RelationUnit identities are chosen here, not while the user types.
Raw RelationUnit source EventIds and raw RelationDischarge later EventIds both
reserve Event identity after interrupted Event-last publication.

Publication order preserves the qualified activation boundaries:

```text
validity / optional description supporting evidence
-> required positive RelationUnit stream update when any
-> required RelationDischarge stream update when any
-> Event last as authority commit
```

The relative order among supporting families is not a cross-stream transaction.
If Event publication fails after a relation or discharge update, the retained
rows remain raw inert provenance and cannot be rebound because fresh Event-id
allocation scans both streams.
-/
private def publishDraftUnderOwnership
    (memoryPath : String)
    (draft : MovementDraft) : IO UInt32 := do
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
                      match freshRecordEventId?
                              memory history descriptions relations discharges,
                          freshValidityFactId? history,
                          freshRelationUnitIds? relations draft.relations.length with
                      | some eventId, some factId, some relationIds =>
                          match Loam.Core.Event.ofEffects? eventId draft.effects,
                              materializeRelationUnits? eventId relationIds draft.relations with
                          | some event, some newRelations =>
                              let newDischarges :=
                                materializeRelationDischarges eventId draft.discharges
                              let fact : Loam.Core.ActualValidityFact String := {
                                id := factId
                                event := eventId
                                validOn := draft.validOn
                              }
                              let updatedDescriptions? :=
                                match draft.description with
                                | none => some descriptions
                                | some text =>
                                    Loam.Core.EventDescriptionMemory.ofEntries?
                                      (descriptions.entries ++ [{ event := eventId, text := text }])
                              let updatedRelations := relations ++ newRelations
                              let updatedDischarges := discharges ++ newDischarges
                              match Loam.Core.EventMemory.add? memory event,
                                  history.addFact? fact, updatedDescriptions? with
                              | some updatedEvents, some updatedHistory, some updatedDescriptions =>
                                  if !relationPublicationAdmissible
                                      updatedEvents updatedRelations event newRelations then
                                    IO.eprintln
                                      "loam: open relation evidence did not justify one source-local frontier"
                                    return 2
                                  else if !dischargePublicationAdmissible
                                      updatedEvents updatedRelations updatedDischarges newDischarges then
                                    IO.eprintln
                                      "loam: relation discharge evidence did not justify one current target frontier"
                                    return 2
                                  else
                                    showAdmissionPreview
                                      draft.total draft.validOn draft.description
                                      newRelations.length newDischarges.length eventId
                                    if ← Loam.Persistence.saveActualValidityHistory?
                                        validityFile updatedHistory then
                                      let descriptionPublished ←
                                        match draft.description with
                                        | none => pure true
                                        | some _ =>
                                            Loam.Persistence.saveEventDescriptionMemory?
                                              descriptionFile updatedDescriptions
                                      if !descriptionPublished then
                                        IO.eprintln
                                          "loam: description was not published; the already-published date evidence remains inert"
                                        return 2
                                      else
                                        let relationPublished ←
                                          if newRelations.isEmpty then
                                            pure true
                                          else
                                            Loam.Persistence.saveOpenRelationUnits?
                                              relationFile updatedRelations
                                        if !relationPublished then
                                          IO.eprintln
                                            "loam: open relation evidence was not published; Event authority was not published"
                                          return 2
                                        else
                                          let dischargePublished ←
                                            if newDischarges.isEmpty then
                                              pure true
                                            else
                                              Loam.Persistence.saveRelationDischarges?
                                                dischargeFile updatedDischarges
                                          if !dischargePublished then
                                            IO.eprintln
                                              "loam: relation discharge evidence was not published; Event authority was not published"
                                            return 2
                                          else if ← Loam.Persistence.saveEventMemory?
                                              memoryFile updatedEvents then
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
                              | _, _, _ =>
                                  IO.eprintln
                                    "loam: could not append movement, occurrence-date, and description evidence"
                                  return 2
                          | _, _ =>
                              IO.eprintln "loam: could not admit generated movement or relation evidence"
                              return 2
                      | _, _, _ =>
                          IO.eprintln "loam: could not generate fresh recording identities"
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
