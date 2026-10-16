import Loam.ActualDate
import Loam.Authority.ActualAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.Review.ScheduledReview

namespace Loam.ResumeCli

open Loam.Core

set_option autoImplicit false

/-!
# Review an existing household before resuming ordinary recording

No resume marker or guessed pause dates are stored. A household may have a quiet
year with no transactions, or an unrecorded year. The missing transactions cannot
be inferred from a last-Event timestamp, so this report never certifies coverage.

The same selected Household generation supplies Actual, Scheduled and the
current-support snapshot. Nothing is written, retired, completed, reset, or
re-anchored by this read-only report.
-/

structure Snapshot where
  observedOn : String
  currentOpen : List Loam.ScheduledReview.Record
  overdue : List Loam.ScheduledReview.Record
  exactAnchors : List EffectCoordinate
  boundedClaims : List Loam.BoundedHistorySupport.Support
 
/-- Inspect the user's *existing* root at an explicit day without interpreting gaps. -/
def inspectAt (root : System.FilePath) (observedOn : String) :
    IO (Except String Snapshot) := do
  if !Loam.ActualDate.validIsoDate observedOn then
    return .error "loam: resume requires a real YYYY-MM-DD observation date"
  let observed ←
    match ← Loam.ActualAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return .error message
  let currentSupport ←
    match Loam.CurrentSupportAuthority.decodeGeneration? observed.generation with
    | .ok support => pure support
    | .error message => return .error message
  let scheduled ←
    match Loam.ScheduledReview.fromGenerationForEvents
        observed.generation observed.image.evidence.events with
    | .ok snapshot => pure snapshot
    | .error message => return .error message
  let currentOpen ←
    match Loam.ScheduledReview.orderedCurrentOpenRecords scheduled with
    | .ok rows => pure rows
    | .error message => return .error message
  return .ok {
    at := at
    currentOpen := currentOpen
    overdue := currentOpen.filter (fun row => decide (row.scheduledOn < observedOn))
    exactAnchors := currentSupport.anchor.assertions.map (·.coordinate)
    boundedClaims := currentSupport.bounded.supports
  }

private def coordinateText (coordinate : EffectCoordinate) : String :=
  coordinate.locus.token ++ " / " ++ coordinate.measure.token

/-- A guide, not a repair report or a claim that inactive days were complete. -/
def render (root : System.FilePath) (snapshot : Snapshot) : String := Id.run do
  let mut lines := [
    "LOAM / Resume existing household (read-only)",
    "Household: " ++ root.toString,
    "Review day: " ++ snapshot.observedOn,
    "No past entry, Scheduled status, or current balance was modified.",
    "",
    "Exact current quantity anchor coordinates: " ++ toString snapshot.exactAnchors.length,
    "Certified bounded-history coordinates: " ++ toString snapshot.boundedClaims.length,
    "Current-open Scheduled occurrences: " ++ toString snapshot.currentOpen.length,
    "Overdue current-open Scheduled occurrences: " ++ toString snapshot.overdue.length
  ]
  if !snapshot.overdue.isEmpty then
    lines := lines ++ ["", "Overdue (open, NOT assumed paid):"]
    for row in snapshot.overdue.take 8 do
      lines := lines ++ ["  " ++ row.scheduledOn ++ "  " ++ row.id.token]
    if snapshot.overdue.length > 8 then
      lines := lines ++ ["  ... inspect the remaining items in Scheduled"]
  if !snapshot.boundedClaims.isEmpty then
    lines := lines ++ ["", "Review older completeness claims if recording was interrupted:"]
    for support in snapshot.boundedClaims.take 8 do
      lines := lines ++ [
        "  " ++ coordinateText support.coordinate ++ "  complete-since " ++ support.startDay
      ]
    if snapshot.boundedClaims.length > 8 then
      lines := lines ++ ["  ... inspect the remaining claims in history-support administration"]
  lines := lines ++ [
    "",
    "Continue from today:",
    "  1. Open the SAME household: loam tui " ++ root.toString,
    "  2. Inspect overdue Scheduled items. Do not mark a bill paid without evidence.",
    "  3. If you missed transactions after a certified history start, remove or",
    "     correct the affected completeness claim via Home > Manage Loci > Shift-Tab.",
    "     Do this BEFORE re-observing a differing current balance.",
    "  4. Observe known current bank/cash quantities via Home > Observe quantities.",
    "     Unknown amounts stay unknown; no balancing transactions are invented.",
    "  5. Update future Scheduled items and record new purchases normally.",
    "",
    "A quiet year and an unrecorded year are not distinguishable from Event dates.",
    "This report does NOT declare missing days complete or historical Daily Pace known."
  ]
  return String.intercalate "\n" lines

private def resolveRoot (args : List String) : IO (Except String System.FilePath) := do
  match args with
  | [] =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some value =>
          if value.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk value)
      | none => return .ok (System.FilePath.mk "../loam-data")
  | [value] =>
      if value.isEmpty then return .error "loam: resume path must not be empty"
      return .ok (System.FilePath.mk value)
  | _ => return .error "Usage: loam resume [LOAM_DATA_DIR]"

/-- Explicit, read-only entry; it never invokes new household initialization. -/
def run (args : List String) : IO UInt32 := do
  let root ←
    match ← resolveRoot args with
    | .ok root => pure root
    | .error message => IO.eprintln message; return 2
  let some today ← Loam.ActualDate.todayIso?
    | IO.eprintln "loam: could not determine the local date"
      return 2
  match ← inspectAt root today with
  | .error message =>
      IO.eprintln ("loam: resume cannot verify existing household: " ++ message)
      IO.eprintln "Use loam doctor on this SAME root; do not initialize over it."
      return 2
  | .ok snapshot =>
      IO.println (render root snapshot)
      return 0

end Loam.ResumeCli
