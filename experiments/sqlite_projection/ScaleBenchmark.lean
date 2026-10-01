import Loam.Authority.ActualAuthority
import Loam.Review.ActualReview
import SQLite

open Loam.Core
open SQLite

set_option autoImplicit false

namespace Loam.SqliteProjectionScaleBenchmark

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def timed {α : Type} (action : IO α) : IO (Nat × α) := do
  let t0 ← IO.monoNanosNow
  let value ← action
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, value)

private def median (values : List Nat) : Nat :=
  if h : values.isEmpty then
    0
  else
    let sorted := values.toArray.qsort (· < ·)
    sorted[sorted.size / 2]!

private def medianTimedNat (repetitions : Nat) (action : IO Nat) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut answer : Nat := 0
  for _ in List.range repetitions do
    let (us, value) ← timed action
    times := us :: times
    answer := value
  pure (median times, answer)

private def medianTimedInt (repetitions : Nat) (action : IO Int) : IO (Nat × Int) := do
  let mut times : List Nat := []
  let mut answer : Int := 0
  for _ in List.range repetitions do
    let (us, value) ← timed action
    times := us :: times
    answer := value
  pure (median times, answer)

private def pad2 (n : Nat) : String :=
  if n < 10 then "0" ++ toString n else toString n

/--
Use a deterministic 336-day synthetic calendar: twelve 28-day months.

Every generated date is a real ISO date. The benchmark intentionally repeats
this calendar for long histories so date selectivity stays proportional as N
grows rather than turning the latest-window query into a fixed-size tail.
-/
private def dateFor (i : Nat) : String :=
  let month := ((i / 28) % 12) + 1
  let day := (i % 28) + 1
  "2026-" ++ pad2 month ++ "-" ++ pad2 day

private def categoryFor (i : Nat) : String :=
  match i % 8 with
  | 0 => "food"
  | 1 => "coffee"
  | 2 => "books"
  | 3 => "transport"
  | 4 => "household"
  | 5 => "clothing"
  | 6 => "medical"
  | _ => "other"

private def profileIndex (i : Nat) : Nat :=
  if i % 100 == 1 then i - 1 else i

private def makeEffect (locus : String) (quanta : Int) : Effect :=
  Effect.ofAnonymousQuantity ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)

private def eventFor (i : Nat) : IO Event := do
  let p := profileIndex i
  let amount : Int := Int.ofNat ((p % 1000) + 1)
  requireSome
    (Event.ofEffects? ⟨s!"event-{i}"⟩ [
      makeEffect "wallet" (-amount),
      makeEffect (categoryFor p) amount
    ])
    s!"could not construct event-{i}"

private def correctionsFor (n : Nat) : List EventCorrection :=
  (List.range n).filterMap fun i =>
    if i % 100 == 0 && i + 1 < n then
      some {
        target := ⟨s!"event-{i}"⟩
        replacement := ⟨s!"event-{i + 1}"⟩
      }
    else
      none

private def buildEvidence (n : Nat) : IO Loam.ActualEvidence := do
  let eventsList ← (List.range n).mapM eventFor
  let events ← requireSome
    (EventMemory.ofEvents? eventsList)
    "synthetic EventMemory admission failed"

  let facts := (List.range n).map fun i =>
    let p := profileIndex i
    ActualValidityFact.base (EventId.mk s!"event-{i}") (dateFor p)
  let validity ← requireSome
    (ActualValidityHistory.ofParts? facts [])
    "synthetic ActualValidityHistory admission failed"

  let descriptionsList := (List.range n).map fun i => {
    event := EventId.mk s!"event-{i}"
    text := s!"synthetic {categoryFor (profileIndex i)} {profileIndex i}"
  }
  let descriptions ← requireSome
    (EventDescriptionMemory.ofEntries? descriptionsList)
    "synthetic EventDescriptionMemory admission failed"

  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections? (correctionsFor n))
    "synthetic EventCorrectionMemory admission failed"

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

private def latestWindowCount
    (records : List Loam.ActualReview.Record) : Nat :=
  records.foldl
    (fun count record =>
      if record.isCurrent &&
          record.date.any (fun d => d >= "2026-12-01" && d <= "2026-12-31") then
        count + 1
      else
        count)
    0

private def locusQuantity
    (records : List Loam.ActualReview.Record)
    (locus measure : String) : Int :=
  records.foldl
    (fun total record =>
      if !record.isCurrent then total
      else
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

private def createTables (db : SQLite) : IO Unit := do
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
  "

private def createIndexes (db : SQLite) : IO Unit := do
  db.exec "
    CREATE INDEX actual_records_valid_on_current
      ON actual_records(valid_on, replacement_event_id, event_id);

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
  createTables db
  insertRecords db records
  createIndexes db
  pure db

private def sqliteLatestWindowCount (db : SQLite) : IO Nat := do
  let stmt ← db.prepare "
    SELECT COUNT(*)
    FROM actual_records
    WHERE replacement_event_id IS NULL
      AND valid_on >= '2026-12-01'
      AND valid_on <= '2026-12-31'
  "
  unless ← stmt.step do
    throw <| IO.userError "SQLite latest-window count returned no row"
  pure (← stmt.columnText 0).toNat!

private def sqliteLocusQuantity
    (db : SQLite)
    (locus measure : String) : IO Int := do
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
    throw <| IO.userError "SQLite locus quantity returned no row"
  match (← stmt.columnText 0).toInt? with
  | some value => pure value
  | none => throw <| IO.userError "SQLite locus quantity was not an Int"

private def fileBytes (path : System.FilePath) : IO Nat := do
  pure (← IO.FS.readBinFile path).size

private structure Result where
  n : Nat
  corrections : Nat
  generateUs : Nat
  publishUs : Nat
  loadUs : Nat
  reviewUs : Nat
  leanLatestUs : Nat
  sqliteBuildUs : Nat
  sqliteLatestUs : Nat
  sqliteColdLatestUs : Nat
  leanFoodUs : Nat
  sqliteFoodUs : Nat
  actualBytes : Nat
  sqliteBytes : Nat
  latestCount : Nat
  foodQuantity : Int
deriving Repr

private def printResult (r : Result) : IO Unit := do
  IO.println <|
    "E3" ++
    s!",events={r.n}" ++
    s!",corrections={r.corrections}" ++
    s!",generate_us={r.generateUs}" ++
    s!",publish_us={r.publishUs}" ++
    s!",load_us={r.loadUs}" ++
    s!",review_us={r.reviewUs}" ++
    s!",lean_latest30_median_us={r.leanLatestUs}" ++
    s!",sqlite_build_us={r.sqliteBuildUs}" ++
    s!",sqlite_latest30_median_us={r.sqliteLatestUs}" ++
    s!",sqlite_cold_latest30_us={r.sqliteColdLatestUs}" ++
    s!",lean_food_sum_median_us={r.leanFoodUs}" ++
    s!",sqlite_food_sum_median_us={r.sqliteFoodUs}" ++
    s!",actual_bytes={r.actualBytes}" ++
    s!",sqlite_bytes={r.sqliteBytes}" ++
    s!",latest30_count={r.latestCount}" ++
    s!",food_jpy={r.foodQuantity}"

def run (root : System.FilePath) (n : Nat) : IO Unit := do
  expect (n >= 2) "benchmark size must be at least 2"
  IO.FS.createDirAll root

  let actualFile := root / "actual.loam"
  let sqliteFile := root / "projection.sqlite"

  let (generateUs, evidence) ← timed (buildEvidence n)

  let (publishUs, publishResult) ← timed (Loam.ActualAuthority.publishActualFile? actualFile evidence)
  match publishResult with
  | .error message =>
      throw <| IO.userError ("synthetic Actual publication failed: " ++ message)
  | .ok () => pure ()

  let (loadUs, imageResult) ← timed (Loam.ActualAuthority.loadImageFile? actualFile)
  let image ← match imageResult with
    | .error message =>
        throw <| IO.userError ("synthetic Actual reload failed: " ++ message)
    | .ok image => pure image

  let (reviewUs, records) ← timed do
    pure (Loam.ActualReview.recordsFromActualImage image)

  let repetitions := if n <= 10000 then 7 else 3

  let (leanLatestUs, leanLatest) ←
    medianTimedNat repetitions do pure (latestWindowCount records)

  let (leanFoodUs, leanFood) ←
    medianTimedInt repetitions do pure (locusQuantity records "food" "jpy")

  let (sqliteBuildUs, db) ← timed (buildProjection sqliteFile records)

  let (sqliteLatestUs, sqliteLatest) ←
    medianTimedNat repetitions (sqliteLatestWindowCount db)

  let (sqliteFoodUs, sqliteFood) ←
    medianTimedInt repetitions (sqliteLocusQuantity db "food" "jpy")

  expect (sqliteLatest == leanLatest)
    s!"latest-window semantic mismatch at N={n}: LOAM={leanLatest}, SQLite={sqliteLatest}"
  expect (sqliteFood == leanFood)
    s!"food quantity semantic mismatch at N={n}: LOAM={leanFood}, SQLite={sqliteFood}"

  let (sqliteColdLatestUs, coldPair) ← timed do
    let cold ← SQLite.openWith sqliteFile SQLite.OpenFlags.readonly
    let value ← sqliteLatestWindowCount cold
    pure value
  expect (coldPair == leanLatest)
    s!"cold SQLite latest-window mismatch at N={n}"

  let actualBytes ← fileBytes actualFile
  let sqliteBytes ← fileBytes sqliteFile

  printResult {
    n := n
    corrections := correctionsFor n |>.length
    generateUs := generateUs
    publishUs := publishUs
    loadUs := loadUs
    reviewUs := reviewUs
    leanLatestUs := leanLatestUs
    sqliteBuildUs := sqliteBuildUs
    sqliteLatestUs := sqliteLatestUs
    sqliteColdLatestUs := sqliteColdLatestUs
    leanFoodUs := leanFoodUs
    sqliteFoodUs := sqliteFoodUs
    actualBytes := actualBytes
    sqliteBytes := sqliteBytes
    latestCount := leanLatest
    foodQuantity := leanFood
  }

end Loam.SqliteProjectionScaleBenchmark

def main (args : List String) : IO Unit := do
  match args with
  | [root, size] =>
      match size.toNat? with
      | none => throw <| IO.userError "size must be a natural number"
      | some n =>
          Loam.SqliteProjectionScaleBenchmark.run (System.FilePath.mk root) n
  | _ =>
      throw <| IO.userError "expected: <temporary-root> <event-count>"
