import Loam.LocusTrendReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def record
    (id date locus measure : String)
    (quanta : Int)
    (replacement : Option EventId := none) : Loam.ActualReview.Record :=
  let effect := Effect.ofAnonymousQuantity
    ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)
  {
    event := {
      id := ⟨id⟩
      effects := [effect]
      keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
    }
    date := some date
    description := ""
    replacement := replacement
  }

private def undatedRecord
    (id locus measure : String) (quanta : Int) : Loam.ActualReview.Record :=
  let base := record id "2026-09-01" locus measure quanta
  { base with date := none }

def main : IO Unit := do
  let records :=
    [ record "day-1" "2026-09-01" "tobacco" "jpy" 500
    , record "old-day-2" "2026-09-02" "tobacco" "jpy" 500 (some ⟨"new-day-2"⟩)
    , record "new-day-2" "2026-09-02" "tobacco" "jpy" 600
    , record "other" "2026-09-03" "coffee" "jpy" 140
    , record "day-4" "2026-09-04" "tobacco" "jpy" 500
    , undatedRecord "undated" "tobacco" "jpy" 500
    ]
  let coordinate : EffectCoordinate := ⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩
  let snapshot ←
    match Loam.LocusTrendReview.project
        records "2026-09-01" "2026-09-05" coordinate with
    | .ok snapshot => pure snapshot
    | .error message => throw (IO.userError message)

  expect (snapshot.points.length == 4)
    "Locus Trend did not preserve one point per calendar day"
  expect (snapshot.points.map (·.daily.quanta) == [500, 600, 0, 500])
    "Locus Trend did not use the correction-aware exact coordinate projection"
  expect (snapshot.points.map (·.cumulative.quanta) == [500, 1100, 1100, 1600])
    "Locus Trend cumulative quantity drifted"
  expect
    (snapshot.points.map (·.runningDailyAverageQuanta) == [500, 550, 366, 400])
    "Locus Trend running daily average compressed away zero days"
  expect (snapshot.total.quanta == 1600)
    "Locus Trend total did not equal the final cumulative point"
  expect (snapshot.undatedMatchingCurrentRecords == 1)
    "Locus Trend hid matching current evidence with unknown occurrence date"

  match Loam.LocusTrendReview.project
      records "2026-09-05" "2026-09-01" coordinate with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "Locus Trend accepted a reversed explicit window")

  IO.println "Locus Trend: correction-aware daily quantity projection passed."
