import Loam.Review.CycleSpendingPaceReview
import Loam.Presentation.ReadState
import Std.Data.HashMap

namespace Loam.DailyPacePeriods

set_option autoImplicit false

inductive Preset where
  | tenDays | thirtyDays | month | cycle | previousCycle
  deriving Repr, DecidableEq, BEq

def presets : List Preset := [.tenDays, .thirtyDays, .month, .cycle, .previousCycle]

def Preset.label : Preset → String
  | .tenDays => "10d"
  | .thirtyDays => "30d"
  | .month => "Month"
  | .cycle => "Cycle"
  | .previousCycle => "Previous Cycle"

/-- Inclusive display coordinates, not an aggregation grain or retained cycle. -/
structure Range where
  start : String
  through : String
  deriving Repr, DecidableEq

/-- Only the uniquely selected current preset supplies historical cycle boundaries. -/
def cyclePreset (configured : List Loam.BoundaryPresetConfig.Preset) (today : String) :
    Except String Loam.BoundaryPresetConfig.Preset := do
  let current ← Loam.BoundaryPresetConfig.currentWindowFor? configured today
  let some preset := configured.find? (fun preset => preset.name == current.source)
    | throw "Daily Pace: current boundary preset missing"
  return preset

def resolve (preset : Preset) (today : String)
    (configured : List Loam.BoundaryPresetConfig.Preset) : Except String Range := do
  if !Loam.ActualDate.validIsoDate today then throw "Daily Pace: invalid observation day"
  match preset with
  | .tenDays | .thirtyDays =>
      let some start := Loam.ActualDate.shiftDays? today (if preset == .tenDays then -9 else -29)
        | throw "Daily Pace: display range exceeds calendar bounds"
      return {start, through := today}
  | .month => return {start := String.ofList (today.toList.take 8) ++ "01", through := today}
  | .cycle =>
      let current ← Loam.BoundaryPresetConfig.currentWindowFor? configured today
      return {start := current.start, through := today}
  | .previousCycle =>
      let current ← Loam.BoundaryPresetConfig.currentWindowFor? configured today
      let source ← cyclePreset configured today
      let some through := Loam.ActualDate.shiftDays? current.start (-1)
        | throw "Daily Pace: previous cycle exceeds calendar bounds"
      let some (start, endExclusive) := Loam.BoundaryPresetConfig.windowForDate? source through
        | throw "Daily Pace: previous cycle boundary is not explicitly configured"
      if endExclusive != current.start then throw "Daily Pace: previous cycle is not adjacent"
      return {start, through}

def Range.dates (range : Range) : Except String (List String) := do
  let some distance := Loam.ActualDate.daysBetween? range.start range.through
    | throw "Daily Pace: invalid display range"
  if distance < 0 then throw "Daily Pace: reversed display range"
  (List.range (distance.toNat + 1)).mapM fun offset =>
    match Loam.ActualDate.shiftDays? range.start (Int.ofNat offset) with
    | some day => .ok day
    | none => .error "Daily Pace: day outside calendar bounds"

structure Period where
  preset : Preset
  range : Except String Range
  history : Loam.Presentation.ReadState (List Loam.CycleSpendingPaceReview.Snapshot)

/-- Reuse each day's reconstruction across overlapping presets in one read image.
A refused window is not truncated to the known part and no missing day becomes zero. -/
def project
    (measure : Loam.Core.MeasureId)
    (image : Loam.ActualAuthority.Image)
    (evidence : Loam.HistoricalBalanceReview.Evidence)
    (selection : List Loam.Core.EffectCoordinate)
    (balances : Loam.BalanceReview.Snapshot)
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot)
    (configured : List Loam.BoundaryPresetConfig.Preset)
    (today : String) : List Period := Id.run do
  let source := cyclePreset configured today
  let current := do
    let window ← Loam.BoundaryPresetConfig.currentWindowFor? configured today
    Loam.CycleSpendingPaceReview.projectForMeasure measure today window.endExclusive selection balances scheduled
  let ranges := presets.map fun preset => (preset, resolve preset today configured)
  let dates := (ranges.flatMap fun (_, range) => ((range.bind Range.dates).toOption).getD []).eraseDups
  let cycleEnds := dates.map fun day => do
    let source ← source
    let _ ← current
    let some (_, endExclusive) := Loam.BoundaryPresetConfig.windowForDate? source day
      | throw ("Daily Pace: no explicit cycle boundary for " ++ day)
    return (day, endExclusive)
  let known := cycleEnds.filterMap Except.toOption
  let reconstructed := Loam.CycleSpendingPaceReview.projectHistoricalDaysForMeasure
    measure image evidence selection scheduled known
  let mut cache : Std.HashMap String (Except String Loam.CycleSpendingPaceReview.Snapshot) := {}
  for (day, result) in dates.zip cycleEnds do
    if let .error message := result then cache := cache.insert day (.error (day ++ ": " ++ message))
  for ((day, _), result) in known.zip reconstructed do
    let result := do
      let point ← result
      if day == today then
        let current ← current
        if point != current then throw "Daily Pace history latest point disagrees with the current Daily Pace answer"
      return point
    cache := cache.insert day (result.mapError fun message => day ++ ": " ++ message)
  return ranges.map fun (preset, range) =>
    let history := do
      let days ← range.bind Range.dates
      days.mapM fun day => (cache[day]?).getD (.error "Daily Pace: reconstructed day missing")
    {preset, range, history := match history with
      | .ok points => .loaded points
      | .error message => .failed message}

/-- Load support/config once; callers supply the same admitted Actual/Scheduled generation. -/
def load (dataDir : System.FilePath) (today : String)
    (image : Loam.ActualAuthority.Image) (generation : Loam.HouseholdAuthority.Generation)
    (scheduled : Loam.ScheduledReview.EvidenceSnapshot) : IO (Except String (List Period)) := do
  try
    let configured ← Loam.BoundaryPresetConfig.load? (Loam.HouseholdPaths.boundaryPresets dataDir)
    let some configured := configured | return .error "boundary preset config is malformed"
    -- IO configuration reads do not reopen household evidence.
    let selection ← match ← Loam.DailyPaceConfig.loadForMeasure ⟨"jpy"⟩ (Loam.HouseholdPaths.dailyPace dataDir) with
      | .error message => return .error message
      | .ok value => pure value
    return do
      let current ← Loam.CurrentBalanceReview.projectFromGeneration generation image
      let balances ← Loam.CurrentBalanceReview.selectExact current selection
      let evidence ← Loam.HistoricalBalanceReview.evidenceFromGeneration generation
      return project ⟨"jpy"⟩ image evidence selection balances scheduled configured today
  catch error => return .error ("Daily Pace configuration unreadable: " ++ error.toString)

end Loam.DailyPacePeriods
