import Loam.ActualDate
import Loam.Review.ActualReview

namespace Loam.ActualObservationCli

open Loam.Core

set_option autoImplicit false

private def usage : String :=
  "Usage: loam explain actual --machine --month YYYY-MM [LOAM_DATA_DIR]\n" ++
  "\n" ++
  "Emits one read-only ACTUAL1 month projection from the shared correction-aware\n" ++
  "ActualReview boundary, including retained Event-correction ancestors of those\n" ++
  "rows (not date-validity revision history). Schema 2 is presentation transport\n" ++
  "only and ends with meta status complete."

def validMonth (text : String) : Bool :=
  text.length == 7 && Loam.ActualDate.validIsoDate (text ++ "-01")

private def defaultDataDir : IO (Except String System.FilePath) := do
  match ← IO.getEnv "LOAM_DATA_DIR" with
  | some path =>
      if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
      return .ok (System.FilePath.mk path)
  | none => return .ok (System.FilePath.mk "../loam-data")

private def resolveDataDir (path? : Option String) : IO (Except String System.FilePath) := do
  match path? with
  | none => defaultDataDir
  | some path =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path)

private def inMonth (month : String) (record : Loam.ActualReview.Record) : Bool :=
  record.isCurrent &&
    (record.date.any fun date => date.startsWith (month ++ "-"))

def monthRecords
    (month : String)
    (records : List Loam.ActualReview.Record) : List Loam.ActualReview.Record :=
  (records.filter (inMonth month)).mergeSort fun a b =>
    if a.date == b.date then a.event.id.token <= b.event.id.token
    else a.date.getD "" <= b.date.getD ""

private def machineRecord (fields : List String) : String :=
  String.intercalate "\t" ("ACTUAL1" :: fields)

private def effectRecord
    (eventId : String)
    (effect : Effect) : String :=
  machineRecord [
    "effect",
    eventId,
    effect.locus.token,
    effect.measure.token,
    toString effect.quantity.quanta
  ]

/-- The inverse edge index reuses the already-admitted, disjoint correction paths. -/
private def predecessorIndex
    (records : List Loam.ActualReview.Record) :
    Std.HashMap String Loam.ActualReview.Record :=
  records.foldl (fun index record =>
    match record.replacement with
    | none => index
    | some replacement => index.insert replacement.token record) {}

/-- Relation order, never date or file order, determines oldest-to-newest ancestry. -/
private def ancestors
    (index : Std.HashMap String Loam.ActualReview.Record) :
    Nat → String → List Loam.ActualReview.Record → List Loam.ActualReview.Record
  | 0, _, collected => collected
  | fuel + 1, id, collected =>
      match index[id]? with
      | none => collected
      | some previous =>
          ancestors index fuel previous.event.id.token (previous :: collected)

private def historyText
    (owner : String)
    (record : Loam.ActualReview.Record) : List String :=
  let id := record.event.id.token
  machineRecord [
    "history", owner, id,
    (record.replacement.map (·.token)).getD "",
    record.date.getD "",
    Loam.Persistence.escapeText record.description
  ] :: record.event.effects.map (fun effect => machineRecord [
    "history-effect", owner, id, effect.locus.token, effect.measure.token,
    toString effect.quantity.quanta
  ])

/--
Current monthly rows plus only their retained correction ancestors. Historical dates
may be absent or outside the month. Canonical callers provide admitted ActualReview
records; no new correction authority or accounting arithmetic is introduced here.
-/
def machineText
    (month : String)
    (records : List Loam.ActualReview.Record) : String :=
  let rows := monthRecords month records
  let predecessors := predecessorIndex records
  let body := rows.flatMap fun record =>
    let id := record.event.id.token
    let header := machineRecord [
      "record",
      id,
      record.date.getD "",
      Loam.Persistence.escapeText record.description
    ]
    [header] ++ record.event.effects.map (effectRecord id) ++
      (ancestors predecessors records.length id []).flatMap (historyText id)
  String.intercalate "\n" <|
    [ machineRecord ["meta", "schema", "2"]
    , machineRecord ["meta", "implementation", "loam"]
    , machineRecord ["meta", "question", "actual-month"]
    , machineRecord ["meta", "month", month]
    ] ++ body ++
    [machineRecord ["meta", "status", "complete"]]

def run (args : List String) : IO UInt32 := do
  let (month, path?) ←
    match args with
    | ["--machine", "--month", month] => pure (month, none)
    | ["--machine", "--month", month, path] => pure (month, some path)
    | _ =>
        IO.eprintln usage
        return 2
  if !validMonth month then
    IO.eprintln "loam: actual month must be YYYY-MM"
    return 2
  let dataDir ←
    match ← resolveDataDir path? with
    | .ok path => pure path
    | .error message =>
        IO.eprintln message
        return 2
  match ← Loam.ActualReview.loadRecordsFromActual dataDir with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok records =>
      IO.println (machineText month records)
      return 0

end Loam.ActualObservationCli
