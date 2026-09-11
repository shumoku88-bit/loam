import Loam.Persistence.EventCorrectionPersistence
import Loam.Persistence.EventPersistence
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.MovementManifestAuthority

namespace Loam.ActualReview

open Loam.Core

set_option autoImplicit false

/-!
# Actual review projection and read boundary

The line CLI and TUI share this correction-aware, occurrence-date-aware answer.
Retained Event / ActualValidity / EventDescription / EventCorrection evidence
remains authoritative. `Record` is transient review evidence only.
-/

structure Record where
  event : Event
  date : Option String
  description : String
  replacement : Option EventId
  isCurrent : Bool := true

inductive Query where
  | week (ending : String)
  | day (date : String)
  | search (text : String)
  | undated
  deriving BEq

def weekDays (ending : String) : List String :=
  (List.range 7).filterMap fun n => Loam.ActualDate.shiftDays? ending (Int.ofNat n - 6)

def displayText (text : String) : String :=
  (Loam.Persistence.escapeText text).map fun c =>
    if c.toNat < 32 || (c.toNat >= 127 && c.toNat < 160) then '�' else c

def shortText (limit : Nat) (text : String) : String :=
  let text := displayText text
  if text.length <= limit then text
  else String.ofList (text.toList.take limit) ++ "…"

def effectText (effect : Effect) : String :=
  effect.locus.token ++ ": " ++ toString effect.quantity.quanta ++ " " ++ effect.measure.token

def containsText (text : String) (record : Record) : Bool :=
  let fields := [record.event.id.token, record.date.getD "", record.description] ++
    record.event.effects.flatMap fun effect =>
      [effect.locus.token, effect.measure.token, toString effect.quantity.quanta]
  fields.any fun field => (field.toLower.splitOn text.toLower).length > 1

def select (records : List Record) (query : Query) : List Record :=
  let days := match query with
    | .week ending => weekDays ending
    | _ => []
  let selected := records.filter fun record =>
    match query with
    | .search text => containsText text record
    | .undated => record.isCurrent && record.date.isNone
    | .day date => record.isCurrent && record.date == some date
    | .week _ => record.isCurrent && (record.date.any fun date => date ∈ days)
  selected.mergeSort fun a b =>
    if a.date == b.date then a.event.id.token <= b.event.id.token
    else a.date.getD "" > b.date.getD ""

def correctionLabel (record : Record) : String :=
  match record.replacement with
  | some id => "  [corrected -> #" ++ displayText id.token ++ "]"
  | none => ""

def summary (record : Record) : String :=
  let effects := record.event.effects
  let lines := effects.take 2 |>.map fun effect =>
    shortText 24 effect.locus.token ++ ": " ++ toString effect.quantity.quanta ++
      " " ++ shortText 12 effect.measure.token
  let more := if effects.length > 2 then "  (+" ++ toString (effects.length - 2) ++ " effects)" else ""
  let description := if record.description.isEmpty then "(no description)" else shortText 36 record.description
  description ++ "  | " ++
    (if effects.isEmpty then "(no quantity effects)" else String.intercalate "; " lines) ++
    more ++ correctionLabel record

def detailLines (records : List Record) (record : Record) : List String :=
  let heading :=
    record.date.getD "date unknown" ++ "  " ++
      (if record.description.isEmpty then "" else displayText record.description ++ "  ") ++
      "[" ++ displayText record.event.id.token ++ "]" ++ correctionLabel record
  let corrects := records.filterMap fun original =>
    if original.replacement == some record.event.id then
      some ("  corrects #" ++ displayText original.event.id.token)
    else
      none
  let effects :=
    if record.event.effects.isEmpty then
      ["  (no quantity effects)"]
    else
      record.event.effects.map fun effect => "  " ++ displayText (effectText effect)
  [heading] ++ corrects ++ effects

private def loadOrEmpty {α : Type} (path : System.FilePath)
    (loader : System.FilePath → IO (Option α)) (empty : α) : IO (Option α) := do
  if ← path.pathExists then loader path else return some empty

private structure ReviewMovementWorld where
  events : EventMemory
  validity : Loam.Core.ActualValidityHistory String
  descriptions : EventDescriptionMemory

private def loadSidecarWorld?
    (memoryFile : System.FilePath) : IO (Except String ReviewMovementWorld) := do
  if !(← memoryFile.pathExists) then
    return .error ("loam: file not found: " ++ memoryFile.toString)
  let some memory ← Loam.Persistence.loadEventMemory? memoryFile
    | return .error "loam: malformed or unsupported event-memory file"
  let some history ← Loam.Persistence.loadActualValidityHistoryOrEmpty?
      (Loam.Persistence.actualValidityPathForEventMemory memoryFile)
    | return .error "loam: malformed or unsupported actual-validity history"
  let some descriptions ← loadOrEmpty
      (Loam.Persistence.eventDescriptionPathForEventMemory memoryFile)
      Loam.Persistence.loadEventDescriptionMemory? EventDescriptionMemory.empty
    | return .error "loam: malformed or unsupported event-description memory"
  return .ok { events := memory, validity := history, descriptions := descriptions }

private def loadManifestWorld?
    (manifestRoot : System.FilePath) : IO (Except String ReviewMovementWorld) := do
  match ← Loam.MovementManifestAuthority.loadSelectedEvidence? manifestRoot with
  | .error message => return .error message
  | .ok evidence =>
      return .ok {
        events := evidence.events
        validity := evidence.validity
        descriptions := evidence.descriptions
      }

private def loadCorrections?
    (correctionPath : Option String) : IO (Option EventCorrectionMemory) := do
  let emptyCorrections : EventCorrectionMemory := { corrections := [], idNodup := by simp }
  match correctionPath with
  | some path =>
      loadOrEmpty (System.FilePath.mk path) Loam.Persistence.loadEventCorrectionMemory? emptyCorrections
  | none => pure (some emptyCorrections)

private def recordsFromWorld?
    (world : ReviewMovementWorld)
    (corrections : EventCorrectionMemory) : Except String (List Record) :=
  match Loam.Application.correctionFrontierMemory? world.events corrections with
  | none =>
      .error "loam: movement corrections do not justify one current record frontier"
  | some frontier =>
      match Loam.Application.admittedActualValidityMemory? world.validity with
      | none =>
          .error "loam: actual-validity corrections do not justify one current date per event"
      | some validities =>
          .ok (world.events.events.map fun event => {
            event := event
            date := validities.findByEventId? event.id
            description := (world.descriptions.findText? event.id).getD ""
            replacement := (corrections.corrections.find? fun c => c.target == event.id).map (·.replacement)
            isCurrent := (frontier.findById? event.id).isSome
          })

private def finishLoad?
    (worldResult : Except String ReviewMovementWorld)
    (correctionPath : Option String) : IO (Except String (List Record)) := do
  let world ←
    match worldResult with
    | .error message => return .error message
    | .ok world => pure world
  let some corrections ← loadCorrections? correctionPath
    | return .error "loam: malformed or unsupported correction-memory file"
  return recordsFromWorld? world corrections

def loadRecordsFromManifest
    (manifestRoot : System.FilePath)
    (correctionPath : Option String) : IO (Except String (List Record)) := do
  finishLoad? (← loadManifestWorld? manifestRoot) correctionPath

def loadRecordsFromSidecar
    (memoryFile : System.FilePath)
    (correctionPath : Option String) : IO (Except String (List Record)) := do
  finishLoad? (← loadSidecarWorld? memoryFile) correctionPath

def loadRecords
    (memoryPath : String)
    (correctionPath : Option String) : IO (Except String (List Record)) := do
  match ← IO.getEnv "LOAM_MOVEMENT_MANIFEST_ROOT" with
  | some rootPath =>
      if rootPath.isEmpty then
        return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
      loadRecordsFromManifest (System.FilePath.mk rootPath) correctionPath
  | none =>
      loadRecordsFromSidecar (System.FilePath.mk memoryPath) correctionPath

end Loam.ActualReview
