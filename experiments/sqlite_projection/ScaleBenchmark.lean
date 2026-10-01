import Loam.Authority.ActualAuthority
import Loam.Persistence.NormalizedActualAdmission
import Loam.Persistence.NormalizedActualPersistence
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
  if values.isEmpty then
    0
  else
    let sorted := values.toArray.qsort (· < ·)
    sorted[sorted.size / 2]!

@[noinline] private def forceImageScore
    (image : Loam.Persistence.AdmittedActualImage) : Nat :=
  image.evidence.events.events.length +
    image.currentEvents.events.length +
    image.currentValidities.entries.length +
    image.evidence.corrections.corrections.length

@[noinline] private def forceRecordScore
    (records : List Loam.ActualReview.Record) : Nat :=
  records.foldl
    (fun total record =>
      total +
        record.event.id.token.length +
        record.event.effects.length +
        record.date.map String.length |>.getD 0 +
        record.description.length +
        record.replacement.map (fun id => id.token.length) |>.getD 0)
    0

private def timedAdmission
    (evidence : Loam.ActualEvidence) :
    IO (Nat × Loam.Persistence.AdmittedActualImage) := do
  let t0 ← IO.monoNanosNow
  let image ← requireSome
    (Loam.Persistence.admitActualImage? evidence)
    "synthetic Actual admission failed"
  let score := forceImageScore image
  if score == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, image)

private def timedEncode
    (evidence : Loam.ActualEvidence) : IO (Nat × String) := do
  let t0 ← IO.monoNanosNow
  let wire ← requireSome
    (Loam.Persistence.encodeNormalizedActual? evidence)
    "synthetic Actual encoding failed"
  let bytes := wire.length
  if bytes == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, wire)

private def timedDecode
    (wire : String) :
    IO (Nat × Loam.Persistence.AdmittedActualImage) := do
  let t0 ← IO.monoNanosNow
  let image ← match Loam.Persistence.decodeNormalizedActualImageDetailed wire with
    | .ok image => pure image
    | .error err =>
        throw <| IO.userError ("synthetic staged decode failed: " ++ toString err)
  let score := forceImageScore image
  if score == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, image)

private def timedRecords
    (image : Loam.Persistence.AdmittedActualImage) :
    IO (Nat × List Loam.ActualReview.Record) := do
  let t0 ← IO.monoNanosNow
  let records := Loam.ActualReview.recordsFromActualImage image
  let score := forceRecordScore records
  if score == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, records)

private def timedForcedNat
    (action : Unit → Nat) : IO (Nat × Nat) := do
  let t0 ← IO.monoNanosNow
  let value := action ()
  if value == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, value)

private def timedForcedInt
    (action : Unit → Int) : IO (Nat × Int) := do
  let t0 ← IO.monoNanosNow
  let value := action ()
  if value == 999999999 then IO.println "unreachable" else pure ()
  let t1 ← IO.monoNanosNow
  pure ((t1 - t0) / 1000, value)

private def medianTimedNat
    (repetitions : Nat) (action : Unit → Nat) : IO (Nat × Nat) := do
  let mut times : List Nat := []
  let mut answer : Nat := 0
  for _ in List.range repetitions do
    let (us, value) ← timedForcedNat action
    times := us :: times
    answer := value
  pure (median times, answer)

private def medianTimedInt
    (repetitions : Nat) (action : Unit → Int) : IO (Nat × Int) := do
  let mut times : List Nat := []
  let mut answer : Int := 0
  for _ in List.range repetitions do
    let (us, value) ← timedForcedInt action
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
  admissionUs : Nat
  encodeWithReadmissionUs : Nat
  stageWriteUs : Nat
  stageReadUs : Nat
  stageVerifyUs : Nat
  stagedDecodeUs : Nat
  renameUs : Nat
  canonicalLoadUs : Nat
  reconstructedPublishUs : Nat
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
    "E3.1" ++
    s!",events={r.n}" ++
    s!",corrections={r.corrections}" ++
    s!",generate_us={r.generateUs}" ++
    s!",admission_us={r.admissionUs}" ++
    s!",encode_with_readmission_us={r.encodeWithReadmissionUs}" ++
    s!",stage_write_us={r.stageWriteUs}" ++
    s!",stage_read_us={r.stageReadUs}" ++
    s!",stage_verify_us={r.stageVerifyUs}" ++
    s!",staged_decode_us={r.stagedDecodeUs}" ++
    s!",rename_us={r.renameUs}" ++
    s!",canonical_load_us={r.canonicalLoadUs}" ++
    s!",reconstructed_publish_us={r.reconstructedPublishUs}" ++
    s!",review_forced_us={r.reviewUs}" ++
    s!",lean_latest30_forced_median_us={r.leanLatestUs}" ++
    s!",sqlite_build_us={r.sqliteBuildUs}" ++
    s!",sqlite_latest30_median_us={r.sqliteLatestUs}" ++
    s!",sqlite_cold_latest30_us={r.sqliteColdLatestUs}" ++
    s!",lean_food_sum_forced_median_us={r.leanFoodUs}" ++
    s!",sqlite_food_sum_median_us={r.sqliteFoodUs}" ++
    s!",actual_bytes={r.actualBytes}" ++
    s!",sqlite_bytes={r.sqliteBytes}" ++
    s!",latest30_count={r.latestCount}" ++
    s!",food_jpy={r.foodQuantity}"

def run (root : System.FilePath) (n : Nat) : IO Unit := do
  expect (n >= 2) "benchmark size must be at least 2"
  IO.FS.createDirAll root

  let actualFile := root / "actual.loam"
  let stageFile := System.FilePath.mk (actualFile.toString ++ ".loam-stage")
  let sqliteFile := root / "projection.sqlite"

  let (generateUs, evidence) ← timed (buildEvidence n)

  let (admissionUs, _) ← timedAdmission evidence

  let (encodeUs, wire) ← timedEncode evidence

  let (stageWriteUs, _) ← timed do
    IO.FS.writeFile stageFile wire

  let (stageReadUs, staged) ← timed do
    IO.FS.readFile stageFile

  let (stageVerifyUs, verified) ← timed do
    let same := staged == wire
    if same then pure true else pure false
  expect verified "staged Actual bytes differed from encoded bytes"

  let (stagedDecodeUs, stagedImage) ← timedDecode staged

  let (renameUs, _) ← timed do
    IO.FS.rename stageFile actualFile

  let reconstructedPublishUs :=
    encodeUs + stageWriteUs + stageReadUs + stageVerifyUs + stagedDecodeUs + renameUs

  let (canonicalLoadUs, canonicalResult) ← timed
    (Loam.ActualAuthority.loadImageFile? actualFile)
  let canonicalImage ← match canonicalResult with
    | .error message =>
        throw <| IO.userError ("synthetic canonical reload failed: " ++ message)
    | .ok image => pure image
  let canonicalScore := forceImageScore canonicalImage
  if canonicalScore == 999999999 then IO.println "unreachable" else pure ()

  expect (forceImageScore stagedImage == canonicalScore)
    "staged decode and canonical reload disagreed on admitted image shape"

  let (reviewUs, records) ← timedRecords canonicalImage

  let repetitions := if n <= 10000 then 7 else 3

  let (leanLatestUs, leanLatest) ←
    medianTimedNat repetitions fun _ => latestWindowCount records

  let (leanFoodUs, leanFood) ←
    medianTimedInt repetitions fun _ => locusQuantity records "food" "jpy"

  let (sqliteBuildUs, db) ← timed (buildProjection sqliteFile records)

  let (sqliteLatestUs, sqliteLatest) ← do
    let mut times : List Nat := []
    let mut answer : Nat := 0
    for _ in List.range repetitions do
      let (us, value) ← timed (sqliteLatestWindowCount db)
      times := us :: times
      answer := value
    pure (median times, answer)

  let (sqliteFoodUs, sqliteFood) ← do
    let mut times : List Nat := []
    let mut answer : Int := 0
    for _ in List.range repetitions do
      let (us, value) ← timed (sqliteLocusQuantity db "food" "jpy")
      times := us :: times
      answer := value
    pure (median times, answer)

  expect (sqliteLatest == leanLatest)
    s!"latest-window semantic mismatch at N={n}: LOAM={leanLatest}, SQLite={sqliteLatest}"
  expect (sqliteFood == leanFood)
    s!"food quantity semantic mismatch at N={n}: LOAM={leanFood}, SQLite={sqliteFood}"

  let (sqliteColdLatestUs, coldPair) ← timed do
    let cold ← SQLite.openWith sqliteFile SQLite.OpenFlags.readonly
    sqliteLatestWindowCount cold
  expect (coldPair == leanLatest)
    s!"cold SQLite latest-window mismatch at N={n}"

  let actualBytes ← fileBytes actualFile
  let sqliteBytes ← fileBytes sqliteFile

  printResult {
    n := n
    corrections := correctionsFor n |>.length
    generateUs := generateUs
    admissionUs := admissionUs
    encodeWithReadmissionUs := encodeUs
    stageWriteUs := stageWriteUs
    stageReadUs := stageReadUs
    stageVerifyUs := stageVerifyUs
    stagedDecodeUs := stagedDecodeUs
    renameUs := renameUs
    canonicalLoadUs := canonicalLoadUs
    reconstructedPublishUs := reconstructedPublishUs
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
