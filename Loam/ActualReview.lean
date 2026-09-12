import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualEvidence
import Loam.Application.ActualValidityFrontier
import Loam.Application.CorrectionFrontier
import Loam.Persistence.TextEscape
import Loam.Persistence.TokenSyntax

namespace Loam.ActualReview

open Loam.Core

set_option autoImplicit false

/-!
# Actual review projection and read boundary

The line CLI and TUI share this correction-aware, occurrence-date-aware answer.
Authoritative Actual evidence is loaded from `actual.loam`.
`Record` is transient review evidence only.
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
    if c.toNat < 32 || (c.toNat >= 127 && c.toNat < 160) then '\uFFFD' else c

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

/--
Project transient review records from authoritative Actual evidence.
-/
def recordsFromActualEvidence?
    (evidence : ActualEvidence) : Except String (List Record) :=
  match Loam.Application.correctionFrontierMemory? evidence.events evidence.corrections with
  | none =>
      .error "loam: movement corrections do not justify one current record frontier"
  | some frontier =>
      match Loam.Application.admittedActualValidityMemory? evidence.validity with
      | none =>
          .error "loam: actual-validity corrections do not justify one current date per event"
      | some validities =>
          .ok (evidence.events.events.map fun event => {
            event := event
            date := validities.findByEventId? event.id
            description := (evidence.descriptions.findText? event.id).getD ""
            replacement := (evidence.corrections.corrections.find? fun c => c.target == event.id).map (·.replacement)
            isCurrent := (frontier.findById? event.id).isSome
          })

/--
Load authoritative review records from the normalized Actual authority file.
-/
def loadRecordsFromActual
    (root : System.FilePath) : IO (Except String (List Record)) := do
  let path :=
    if root.fileName == some Loam.ActualAuthority.actualFileName then root
    else Loam.ActualAuthority.actualPath root
  match ← Loam.ActualAuthority.loadActualFile? path with
  | .error message => return .error message
  | .ok evidence => return recordsFromActualEvidence? evidence

/--
Load records from repository root or actual.loam path.
-/
def loadRecords
    (path : String)
    (_correctionPath : Option String := none) : IO (Except String (List Record)) :=
  loadRecordsFromActual (System.FilePath.mk path)

/-- Backward-compatible alias for existing call sites. -/
def loadRecordsFromManifest
    (manifestRoot : System.FilePath)
    (_correctionPath : Option String := none) : IO (Except String (List Record)) :=
  loadRecordsFromActual manifestRoot

end Loam.ActualReview
