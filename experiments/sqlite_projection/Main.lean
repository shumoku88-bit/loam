import Loam.Authority.ActualAuthority
import Loam.Review.ActualReview
import SQLite

open Loam.Core
open SQLite

set_option autoImplicit false

namespace Loam.SqliteProjectionExperiment

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def makeEffect (locus : String) (quanta : Int) : Effect :=
  Effect.ofAnonymousQuantity ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def balancedEvent
    (id source destination : String)
    (amount : Int) : IO Event :=
  requireSome
    (Event.ofEffects? ⟨id⟩ [
      makeEffect source (-amount),
      makeEffect destination amount
    ])
    ("could not construct balanced Event " ++ id)

private def syntheticEvidence : IO Loam.ActualEvidence := do
  let grocery ← balancedEvent "event-grocery" "wallet" "food" 1000
  let coffeeOld ← balancedEvent "event-coffee-old" "wallet" "coffee" 150
  let coffeeNew ← balancedEvent "event-coffee-new" "wallet" "coffee" 140
  let topup ← balancedEvent "event-topup" "bank" "wallet" 5000
  let book ← balancedEvent "event-book" "wallet" "books" 800

  let events ← requireSome
    (EventMemory.ofEvents? [grocery, coffeeOld, coffeeNew, topup, book])
    "synthetic EventMemory admission failed"

  let validity ← requireSome
    (ActualValidityHistory.ofParts? [
      .base grocery.id "2026-09-28",
      .base coffeeOld.id "2026-09-29",
      .base coffeeNew.id "2026-09-29",
      .base topup.id "2026-09-30",
      .base book.id "2026-10-01"
    ] [])
    "synthetic ActualValidityHistory admission failed"

  let descriptions ← requireSome
    (EventDescriptionMemory.ofEntries? [
      { event := grocery.id, text := "grocery" },
      { event := coffeeOld.id, text := "coffee original" },
      { event := coffeeNew.id, text := "coffee corrected" },
      { event := topup.id, text := "wallet topup" },
      { event := book.id, text := "book" }
    ])
    "synthetic EventDescriptionMemory admission failed"

  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? [
      { target := coffeeOld.id, replacement := coffeeNew.id }
    ])
    "synthetic correction memory admission failed"

  pure {
    Loam.ActualEvidence.empty with
    events := events
    validity := validity
    descriptions := descriptions
    corrections := corrections
  }

private def currentRecords
    (records : List Loam.ActualReview.Record) : List Loam.ActualReview.Record :=
  records.filter (·.isCurrent)

private def sortedCurrentIds
    (records : List Loam.ActualReview.Record) : List String :=
  let current := currentRecords records
  let sorted := current.mergeSort fun a b =>
    if a.date == b.date then
      a.event.id.token <= b.event.id.token
    else
      a.date.getD "" > b.date.getD ""
  sorted.map (·.event.id.token)

private def quantityAtCurrent
    (records : List Loam.ActualReview.Record)
    (locus measure : String) : Int :=
  (currentRecords records).foldl
    (fun total record =>
      record.event.effects.foldl
        (fun subtotal effect =>
          if effect.locus.token == locus && effect.measure.token == measure then
            subtotal + effect.quantity.quanta
          else
            subtotal)
        total)
    0

private def removeIfExists (path : System.FilePath) : IO Unit := do
  if ← path.pathExists then
    IO.FS.removeFile path

private def createSchema (db : SQLite) : IO Unit := do
  db.exec "
    PRAGMA foreign_keys = ON;

    CREATE TABLE actual_records (
      event_id TEXT PRIMARY KEY,
      valid_on TEXT,
      description TEXT NOT NULL,
      replacement_event_id TEXT
    );

    CREATE TABLE effects (
      event_id TEXT NOT NULL,
      ordinal INTEGER NOT NULL,
      locus TEXT NOT NULL,
      measure TEXT NOT NULL,
      quantity_quanta INTEGER NOT NULL,
      PRIMARY KEY (event_id, ordinal),
      FOREIGN KEY (event_id) REFERENCES actual_records(event_id)
    );

    CREATE INDEX actual_records_valid_on
      ON actual_records(valid_on, event_id);

    CREATE INDEX effects_locus_measure
      ON effects(locus, measure, event_id);
  "

private def insertRecords
    (db : SQLite)
    (records : List Loam.ActualReview.Record) : IO Unit := do
  let recordInsert ← db.prepare "
    INSERT INTO actual_records
      (event_id, valid_on, description, replacement_event_id)
    VALUES (?, ?, ?, ?)
  "
  let effectInsert ← db.prepare "
    INSERT INTO effects
      (event_id, ordinal, locus, measure, quantity_quanta)
    VALUES (?, ?, ?, ?, ?)
  "

  db.transaction do
    for record in records do
      recordInsert.bindText 1 record.event.id.token
      match record.date with
      | some date => recordInsert.bindText 2 date
      | none => recordInsert.bindNull 2
      recordInsert.bindText 3 record.description
      match record.replacement with
      | some replacement => recordInsert.bindText 4 replacement.token
      | none => recordInsert.bindNull 4
      recordInsert.exec
      recordInsert.reset
      recordInsert.clearBindings

      let mut ordinal : Nat := 0
      for effect in record.event.effects do
        effectInsert.bindText 1 record.event.id.token
        effectInsert.bindText 2 (toString ordinal)
        effectInsert.bindText 3 effect.locus.token
        effectInsert.bindText 4 effect.measure.token
        effectInsert.bindText 5 (toString effect.quantity.quanta)
        effectInsert.exec
        effectInsert.reset
        effectInsert.clearBindings
        ordinal := ordinal + 1

private def buildProjection
    (path : System.FilePath)
    (records : List Loam.ActualReview.Record) : IO SQLite := do
  removeIfExists path
  let db ← SQLite.open path
  createSchema db
  insertRecords db records
  pure db

private def scalarText
    (db : SQLite)
    (sql : String) : IO String := do
  let stmt ← db.prepare sql
  unless ← stmt.step do
    throw <| IO.userError ("SQLite scalar query returned no row: " ++ sql)
  stmt.columnText 0

private def latestCurrentIds (db : SQLite) : IO (List String) := do
  let stmt ← db.prepare "
    SELECT event_id
    FROM actual_records
    WHERE replacement_event_id IS NULL
    ORDER BY valid_on DESC, event_id ASC
  "
  let mut ids : List String := []
  let mut hasRow ← stmt.step
  while hasRow do
    let id ← stmt.columnText 0
    ids := ids ++ [id]
    hasRow ← stmt.step
  pure ids

private def currentQuantity
    (db : SQLite)
    (locus measure : String) : IO String := do
  let stmt ← db.prepare "
    SELECT CAST(COALESCE(SUM(e.quantity_quanta), 0) AS TEXT)
    FROM effects e
    JOIN actual_records r ON r.event_id = e.event_id
    WHERE r.replacement_event_id IS NULL
      AND e.locus = ?
      AND e.measure = ?
  "
  stmt.bindText 1 locus
  stmt.bindText 2 measure
  unless ← stmt.step do
    throw <| IO.userError "SQLite current quantity query returned no row"
  stmt.columnText 0

structure ProjectionAnswer where
  recordCount : String
  currentCount : String
  latestIds : List String
  walletJpy : String
deriving Repr, BEq

private def projectionAnswer (db : SQLite) : IO ProjectionAnswer := do
  pure {
    recordCount := ← scalarText db "SELECT CAST(COUNT(*) AS TEXT) FROM actual_records"
    currentCount := ← scalarText db "
      SELECT CAST(COUNT(*) AS TEXT)
      FROM actual_records
      WHERE replacement_event_id IS NULL
    "
    latestIds := ← latestCurrentIds db
    walletJpy := ← currentQuantity db "wallet" "jpy"
  }

private def loamAnswer
    (records : List Loam.ActualReview.Record) : ProjectionAnswer := {
  recordCount := toString records.length
  currentCount := toString (currentRecords records).length
  latestIds := sortedCurrentIds records
  walletJpy := toString (quantityAtCurrent records "wallet" "jpy")
}

private def publishAndReload
    (root : System.FilePath) : IO Loam.ActualAuthority.Image := do
  IO.FS.createDirAll root
  let actualFile := root / "actual.loam"
  let evidence ← syntheticEvidence
  match ← Loam.ActualAuthority.publishActualFile? actualFile evidence with
  | .error message =>
      throw <| IO.userError ("synthetic Actual publication failed: " ++ message)
  | .ok () => pure ()

  match ← Loam.ActualAuthority.loadImageFile? actualFile with
  | .error message =>
      throw <| IO.userError ("synthetic admitted Actual reload failed: " ++ message)
  | .ok image => pure image

def run (root : System.FilePath) : IO Unit := do
  let image ← publishAndReload root
  let records := Loam.ActualReview.recordsFromActualImage image
  let expected := loamAnswer records

  let first ← buildProjection (root / "projection-one.sqlite") records
  let firstAnswer ← projectionAnswer first
  expect (firstAnswer == expected)
    s!"first SQLite projection disagreed with LOAM\nLOAM: {repr expected}\nSQLite: {repr firstAnswer}"

  let second ← buildProjection (root / "projection-two.sqlite") records
  let secondAnswer ← projectionAnswer second
  expect (secondAnswer == expected)
    s!"rebuilt SQLite projection disagreed with LOAM\nLOAM: {repr expected}\nSQLite: {repr secondAnswer}"
  expect (secondAnswer == firstAnswer)
    "independently rebuilt SQLite projections produced different query-visible answers"

  IO.println s!"[ok] admitted Actual records: {records.length}"
  IO.println s!"[ok] current records: {expected.currentCount}"
  IO.println s!"[ok] newest-first current ids: {String.intercalate ", " expected.latestIds}"
  IO.println s!"[ok] wallet/jpy current quantity: {expected.walletJpy}"
  IO.println "[ok] two independently rebuilt SQLite projections equal LOAM answers"
  IO.println "[result] SQLite remained a disposable read model; actual.loam remained authority"

end Loam.SqliteProjectionExperiment

def main (args : List String) : IO Unit := do
  let root ←
    match args with
    | [path] => pure (System.FilePath.mk path)
    | _ => throw <| IO.userError "expected one temporary root path"
  Loam.SqliteProjectionExperiment.run root
