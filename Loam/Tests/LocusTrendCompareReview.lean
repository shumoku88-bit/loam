import Loam.LocusTrendCompareReview

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def record
    (id date locus : String) (quanta : Int) :
    Loam.ActualReview.Record :=
  let effect := Effect.ofAnonymousQuantity
    ⟨locus⟩ ⟨"jpy"⟩ (Quantity.ofQuanta quanta)
  {
    event := {
      id := ⟨id⟩
      effects := [effect]
      keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
    }
    date := some date
    description := ""
    replacement := none
  }

def main : IO Unit := do
  let preset : Loam.BoundaryPresetConfig.Preset := {
    name := "Pension"
    boundaries := ["2026-04-15", "2026-04-17", "2026-04-19"]
  }
  let records :=
    [ record "t1" "2026-04-15" "tobacco" 500
    , record "t2" "2026-04-16" "tobacco" 500
    , record "t3" "2026-04-17" "tobacco" 600
    , record "c1" "2026-04-15" "coffee" 100
    , record "c2" "2026-04-17" "coffee" 200
    , record "f1" "2026-04-15" "food" 800
    , record "f2" "2026-04-16" "food" 400
    , record "f3" "2026-04-17" "food" 600
    ]
  let specs : List Loam.LocusTrendCompareReview.SeriesSpec :=
    [ { label := "Tobacco", coordinate := ⟨⟨"tobacco"⟩, ⟨"jpy"⟩⟩ }
    , { label := "Coffee", coordinate := ⟨⟨"coffee"⟩, ⟨"jpy"⟩⟩ }
    , { label := "Food", coordinate := ⟨⟨"food"⟩, ⟨"jpy"⟩⟩ }
    ]
  let snapshot ←
    match Loam.LocusTrendCompareReview.project
        records preset "2026-04-17" specs with
    | .ok snapshot => pure snapshot
    | .error message => throw (IO.userError message)

  expect (snapshot.source == "Pension" && snapshot.series.length == 3)
    "Trend Compare lost the configured source or exact series"
  expect (snapshot.pointCount == 2)
    "Trend Compare did not align every series on the same configured windows"

  let tobacco := snapshot.series[0]!
  let coffee := snapshot.series[1]!
  let food := snapshot.series[2]!
  expect
    (tobacco.points.map (·.dailyAverageQuanta) == [500, 600])
    "Trend Compare changed tobacco cycle averages"
  expect
    (coffee.points.map (·.dailyAverageQuanta) == [50, 200])
    "Trend Compare changed coffee cycle averages"
  expect
    (food.points.map (·.dailyAverageQuanta) == [600, 600])
    "Trend Compare changed food cycle averages"

  match snapshot.selectedWindow? 1 with
  | none => throw (IO.userError "Trend Compare lost selected window metadata")
  | some point =>
      expect (!point.complete && point.throughExclusive == "2026-04-18")
        "Trend Compare lost partial current-window semantics"

  IO.println "Trend Compare: aligned exact-Locus cycle averages passed."
