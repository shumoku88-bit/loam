import Loam.LocusTrendCompareReview

open Loam.Core

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type}
    (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

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

  let tobacco ← requireSome snapshot.series[0]?
    "Trend Compare lost tobacco series"
  let coffee ← requireSome snapshot.series[1]?
    "Trend Compare lost coffee series"
  let food ← requireSome snapshot.series[2]?
    "Trend Compare lost food series"
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

  expect (snapshot.granularity == .cycle)
    "Trend Compare changed the backwards-compatible projection granularity"

  let calendarPreset : Loam.BoundaryPresetConfig.Preset := {
    name := "Pension"
    boundaries := ["2026-04-01", "2026-06-01"]
  }
  let calendarRecords :=
    [ record "mt1" "2026-04-01" "tobacco" 300
    , record "mt2" "2026-04-30" "tobacco" 300
    , record "mt3" "2026-05-01" "tobacco" 100
    , record "mt4" "2026-05-02" "tobacco" 300
    , record "mc1" "2026-04-01" "coffee" 60
    , record "mc2" "2026-04-30" "coffee" 240
    , record "mc3" "2026-05-01" "coffee" 50
    , record "mc4" "2026-05-02" "coffee" 150
    , record "mf1" "2026-04-15" "food" 900
    , record "mf2" "2026-05-02" "food" 600
    ]

  let monthly ←
    match Loam.LocusTrendCompareReview.projectAtGranularity
        calendarRecords calendarPreset "2026-05-02" .month specs with
    | .ok result => pure result
    | .error message => throw (IO.userError message)
  expect (monthly.granularity == .month && monthly.pointCount == 2)
    "Trend Compare did not align calendar-month comparison points"
  let monthlyTobacco ← requireSome monthly.series[0]?
    "Trend Compare lost monthly tobacco series"
  let monthlyCoffee ← requireSome monthly.series[1]?
    "Trend Compare lost monthly coffee series"
  expect
    (monthlyTobacco.points.map (·.dailyAverageQuanta) == [20, 200])
    "Trend Compare changed monthly tobacco averages"
  expect
    (monthlyCoffee.points.map (·.dailyAverageQuanta) == [10, 100])
    "Trend Compare changed monthly coffee averages"
  match monthlyTobacco.points[1]? with
  | none => throw (IO.userError "Trend Compare lost current calendar month")
  | some point =>
      expect (!point.complete && point.start == "2026-05-01" &&
          point.throughExclusive == "2026-05-03")
        "Trend Compare lost current partial-month semantics"

  let daily ←
    match Loam.LocusTrendCompareReview.projectAtGranularity
        calendarRecords calendarPreset "2026-05-02" .day specs with
    | .ok result => pure result
    | .error message => throw (IO.userError message)
  expect (daily.granularity == .day && daily.pointCount == 32)
    "Trend Compare did not preserve one point per calendar day"
  let dailyTobacco ← requireSome daily.series[0]?
    "Trend Compare lost daily tobacco series"
  expect
    (dailyTobacco.points[0]?.map (·.dailyAverageQuanta) == some 300 &&
      dailyTobacco.points[1]?.map (·.dailyAverageQuanta) == some 0 &&
      dailyTobacco.points[30]?.map (·.dailyAverageQuanta) == some 100 &&
      dailyTobacco.points[31]?.map (·.dailyAverageQuanta) == some 300)
    "Trend Compare changed exact calendar-day values or zero days"
  match dailyTobacco.points[31]? with
  | none => throw (IO.userError "Trend Compare lost the observation day")
  | some point =>
      expect (!point.complete && point.start == "2026-05-02")
        "Trend Compare did not mark the observation day as current"

  let partialPreset : Loam.BoundaryPresetConfig.Preset := {
    name := "Pension"
    boundaries := ["2026-04-15", "2026-06-15"]
  }
  let partialMonthly ←
    match Loam.LocusTrendCompareReview.projectAtGranularity
        calendarRecords partialPreset "2026-05-02" .month specs with
    | .ok result => pure result
    | .error message => throw (IO.userError message)
  match partialMonthly.selectedWindow? 0 with
  | none => throw (IO.userError "Trend Compare lost first partial month")
  | some point =>
      expect (!point.complete && point.start == "2026-04-15" &&
          point.endExclusive == "2026-05-01")
        "Trend Compare overstated a mid-month history start as a complete month"

  IO.println "Trend Compare: aligned exact-Locus cycle/month/day projections passed."
