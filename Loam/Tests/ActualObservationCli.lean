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

  IO.println "Actual observation transport: current monthly rows and completion framing passed."
