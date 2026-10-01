import Loam.Core
import Loam.Cli.ActualObservationCli
import Loam.Review.ActualReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def record?
    (id date description fromLocus toLocus : String)
    (quanta : Int)
    (replacement : Option EventId := none) :
    Option Loam.ActualReview.Record := do
  let event ← Event.ofEffects? ⟨id⟩
    [ Effect.ofQuantity ⟨id ++ "-from"⟩ ⟨fromLocus⟩ ⟨"jpy"⟩
        (Quantity.ofQuanta (-quanta))
    , Effect.ofQuantity ⟨id ++ "-to"⟩ ⟨toLocus⟩ ⟨"jpy"⟩
        (Quantity.ofQuanta quanta)
    ]
  pure { event, date := some date, description, replacement }

def main : IO Unit := do
  expect (Loam.ActualObservationCli.validMonth "2026-10")
    "valid GUI month was rejected"
  expect (!Loam.ActualObservationCli.validMonth "2026-13")
    "invalid GUI month was accepted"

  let first ← requireSome
    (record? "event-1" "2026-10-01" "groceries" "paypay" "food" 680)
    "first Actual observation fixture failed"
  let second ← requireSome
    (record? "event-2" "2026-10-07" "book" "paypay" "books" 2470)
    "second Actual observation fixture failed"
  let old ← requireSome
    (record? "event-old" "2026-09-30" "old" "cash" "food" 140)
    "old Actual observation fixture failed"
  let corrected ← requireSome
    (record? "event-corrected" "2026-10-02" "superseded" "cash" "food" 100
      (some ⟨"event-replacement"⟩))
    "corrected Actual observation fixture failed"

  let rows := Loam.ActualObservationCli.monthRecords "2026-10"
    [second, corrected, old, first]
  expect (rows.map (·.event.id.token) == ["event-1", "event-2"])
    "Actual month projection was not current-only and chronological"

  let output := Loam.ActualObservationCli.machineText "2026-10"
    [second, corrected, old, first]
  expect (contains "ACTUAL1\tmeta\tmonth\t2026-10" output)
    "ACTUAL1 month metadata missing"
  expect (contains "ACTUAL1\trecord\tevent-1\t2026-10-01\tgroceries" output)
    "ACTUAL1 record missing"
  expect (contains "ACTUAL1\teffect\tevent-1\tpaypay\tjpy\t-680" output)
    "ACTUAL1 effect missing"
  expect (!contains "event-corrected" output && !contains "event-old" output)
    "ACTUAL1 leaked corrected or out-of-month records"
  expect ((output.splitOn "\n").getLast? ==
      some "ACTUAL1\tmeta\tstatus\tcomplete")
    "ACTUAL1 completion marker missing"
  expect (contains "ACTUAL1\tmeta\tschema\t2" output)
    "ACTUAL1 schema 2 framing missing"

  let original ← requireSome
    (record? "original" "2026-09-28" "old\\nrecognition" "cash" "food" 100
      (some ⟨"middle"⟩))
    "cross-month ancestor fixture failed"
  let middleBase ← requireSome
    (record? "middle" "2026-10-03" "intermediate" "cash" "food" 200
      (some first.event.id))
    "intermediate ancestor fixture failed"
  let middle : Loam.ActualReview.Record := { middleBase with date := none }
  -- Representation and date order deliberately disagree with correction-edge order.
  let withHistory := Loam.ActualObservationCli.machineText "2026-10"
    [middle, second, corrected, first, old, original]
  let historyLines := (withHistory.splitOn "\n").filter fun line =>
    line.startsWith "ACTUAL1\thistory\t"
  expect (historyLines ==
    [ "ACTUAL1\thistory\tevent-1\toriginal\tmiddle\t2026-09-28\told\\\\nrecognition"
    , "ACTUAL1\thistory\tevent-1\tmiddle\tevent-1\t\tintermediate"
    ])
    "correction ancestry lost owner, unknown date, escaped text or relation order"
  expect (contains "ACTUAL1\thistory-effect\tevent-1\toriginal\tcash\tjpy\t-100" withHistory)
    "historical Effects were not retained in the transport"
  expect (!contains "event-corrected" withHistory && !contains "event-old" withHistory)
    "unrelated historical records leaked into monthly ancestry"
  expect ((Loam.ActualObservationCli.monthRecords "2026-10"
      [original, first, middle]).map (·.event.id.token) == ["event-1"])
    "historical ancestors became current monthly rows"
  expect (Loam.ActualObservationCli.machineText "2026-08" [original, middle, first] ==
      Loam.ActualObservationCli.machineText "2026-08" [])
    "an empty month leaked ancestors of another month's current records"

  let exact ← requireSome
    (record? "large" "2026-10-05" "exact" "cash" "food" 900719925474099312345)
    "large exact quantity fixture failed"
  expect (contains "\tjpy\t900719925474099312345"
      (Loam.ActualObservationCli.machineText "2026-10" [exact]))
    "presentation transport rounded exact quantities"

  let multiline : Loam.ActualReview.Record := {
    first with description := "a\nb\tc\rd\\e" }
  expect (contains "ACTUAL1\trecord\tevent-1\t2026-10-01\ta\\nb\\tc\\rd\\\\e"
      (Loam.ActualObservationCli.machineText "2026-10" [multiline]))
    "description separators or backslashes broke lossless single-line framing"

  let controlBefore : Loam.ActualReview.Record := { first with description := "a\x1b" }
  let controlAfter : Loam.ActualReview.Record := { first with description := "a\x07" }
  expect (Loam.ActualObservationCli.machineText "2026-10" [controlBefore] !=
      Loam.ActualObservationCli.machineText "2026-10" [controlAfter])
    "different retained descriptions collapsed during presentation escaping"

  IO.println "Actual observation: current month, retained correction ancestry, unknown dates, exact quantities, lossless descriptions and completion framing passed."
