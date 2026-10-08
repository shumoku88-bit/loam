import Loam.Tui.Home
import Loam.Tui.DailyPaceTrend
import Loam.Tui.Terminal

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

/-- Inspect structured glyph/style cells rather than terminal escape output. -/
private def hasStyledText (widget : Widget) (text : String) (style : Style) : Bool :=
  widget.lines.any fun cells =>
    (List.range (cells.length + 1)).any fun start =>
      let segment := (cells.drop start).take text.length
      String.ofList (segment.map Cell.glyph) == text &&
        segment.all (fun cell => cell.style == style)

private def yen : MeasureId := ⟨"jpy"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def groceries : LocusId := ⟨"groceries"⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled? (index : Nat) : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen
    [change paypay (-100), change groceries 100]
  pure {
    id := ⟨"scheduled-" ++ toString index⟩
    scheduledOn := "2026-09-07"
    movement := movement
  }

private def fixtureSnapshot : IO Loam.Tui.Main.Snapshot := do
  let records ← requireSome ((List.range 12).mapM scheduled?)
    "Scheduled fixtures were not admitted"
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? records)
    "Scheduled memory fixture was not admitted"
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals? [])
    "empty terminal memory was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "empty Event memory was not admitted"
  let scheduledSnapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduled
    terminals := terminals
    events := events
  }
  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-07"
    allRecords := []
  }
  let pace : Loam.CycleSpendingPaceReview.Snapshot := {
    observedAt := "2026-09-07"
    endExclusive := "2026-09-17"
    remainingDays := 10
    eligiblePool := Quantity.ofQuanta 2500
    automaticDeductions := Quantity.ofQuanta 800
    availableThroughEnd := Quantity.ofQuanta 1700
  }
  let paceHistory : List Loam.CycleSpendingPaceReview.Snapshot := [
    { observedAt := "2026-09-05"
      endExclusive := "2026-09-17"
      remainingDays := 12
      eligiblePool := Quantity.ofQuanta 2600
      automaticDeductions := Quantity.ofQuanta 800
      availableThroughEnd := Quantity.ofQuanta 1800 },
    { observedAt := "2026-09-06"
      endExclusive := "2026-09-17"
      remainingDays := 11
      eligiblePool := Quantity.ofQuanta 2560
      automaticDeductions := Quantity.ofQuanta 800
      availableThroughEnd := Quantity.ofQuanta 1760 },
    pace
  ]
  pure {
    actual := actual
    scheduled := .ok scheduledSnapshot
    pace := .loaded pace
    paceHistory := .loaded paceHistory
  }

def main : IO Unit := do
  let snapshot ← fixtureSnapshot
  let home := Loam.Tui.Main.initialState "2026-09-07"
  let bounds : Bounds := { width := 140, height := 42 }

  match Loam.Tui.Main.homeScheduledEvidence snapshot home with
  | .ok (.due _ rest) =>
      expect (rest.length + 1 == 12)
        "Home selected-day Scheduled evidence lost retained due occurrences"
  | _ => throw (IO.userError "Home selected-day Scheduled evidence stopped being Due")

  let dueTodayView := Loam.Tui.Home.view bounds snapshot home
  expect (contains "Scheduled: Due (12)" (widgetText dueTodayView))
    "Home status lost the selected-day Scheduled due count"
  expect (hasStyledText dueTodayView " 7 " .selectedUnderlined)
    "Large calendar lost today's selected/underlined day or marked it pending"
  let dueTodayText := widgetText dueTodayView
  let dailyState : Loam.Tui.Main.State := { home with homeMode := .daily }
  let dailyText := widgetText (Loam.Tui.Home.view bounds snapshot dailyState)
  expect (contains "Daily Pace" dailyText && contains "170 jpy/day" dailyText)
    "Daily Home did not expose the current Daily Pace answer"
  expect (!contains "Recent pace" dueTodayText &&
          !contains "09-05  150 jpy/day" dueTodayText)
    "Home let historical Daily Pace compete with the current glance"

  let paceTrendText :=
    widgetText (Loam.Tui.DailyPaceTrend.view bounds snapshot)
  expect (contains "Daily Pace / Trend" paceTrendText &&
          contains "2026-09-05" paceTrendText &&
          contains "150 jpy/day" paceTrendText &&
          contains "2026-09-06" paceTrendText &&
          contains "160 jpy/day" paceTrendText &&
          contains "2026-09-07" paceTrendText &&
          contains "170 jpy/day  current" paceTrendText)
    "Daily Pace trend did not preserve the reconstructed current-truth series"
  expect (contains "no separate daily snapshot is kept" paceTrendText)
    "Daily Pace trend lost its reconstruction disclosure"
  let usd : MeasureId := ⟨"usd"⟩
  let .loaded basePace := snapshot.pace
    | throw (IO.userError "fixture Daily Pace unavailable")
  let .loaded baseHistory := snapshot.paceHistory
    | throw (IO.userError "fixture Daily Pace history unavailable")
  let usdPace := { basePace with measure := usd }
  let usdHistory := baseHistory.map fun point => { point with measure := usd }
  let usdSnapshot := { snapshot with pace := .loaded usdPace, paceHistory := .loaded usdHistory }
  let usdHomeText := widgetText (Loam.Tui.Home.view bounds usdSnapshot dailyState)
  expect
    (contains "170 usd/day" usdHomeText &&
      contains "After scheduled: 1700 usd" usdHomeText &&
      !(contains "170 jpy/day" usdHomeText))
    "Home rewrote a non-JPY Daily Pace snapshot as JPY"
  let usdTrendText := widgetText (Loam.Tui.DailyPaceTrend.view bounds usdSnapshot)
  expect
    (contains "150 usd/day" usdTrendText &&
      contains "160 usd/day" usdTrendText &&
      contains "170 usd/day  current" usdTrendText &&
      !(contains "jpy/day" usdTrendText))
    "Daily Pace trend rewrote non-JPY history as JPY"
  expect (contains "Upcoming Scheduled" dailyText && contains "2026-09-07" dailyText)
    "Daily Home did not expose the earliest current-open Scheduled occurrence"

  let stateBounds : Bounds := { width := 100, height := 42 }

  let notRequestedSnapshot := { snapshot with attention := .notRequested }
  let notRequestedSnapshot := { notRequestedSnapshot with pace := .notRequested }
  let notRequestedSnapshot := { notRequestedSnapshot with paceHistory := .notRequested }
  let notRequestedText :=
    widgetText (Loam.Tui.Home.view stateBounds notRequestedSnapshot dailyState)
  expect (contains "Attention: not requested" notRequestedText &&
      contains "Daily Pace: not requested" notRequestedText &&
      !contains "Recent pace" notRequestedText)
    "Home collapsed current not-requested state or exposed historical pace"

  let unavailableSnapshot := { snapshot with attention := .unavailable }
  let unavailableSnapshot := { unavailableSnapshot with pace := .unavailable }
  let unavailableSnapshot := { unavailableSnapshot with paceHistory := .unavailable }
  let unavailableText :=
    widgetText (Loam.Tui.Home.view stateBounds unavailableSnapshot dailyState)
  expect (contains "Attention: not configured" unavailableText &&
      contains "Daily Pace: unavailable" unavailableText &&
      !contains "Recent pace" unavailableText)
    "Home lost typed current unavailable state or exposed historical pace"

  let failedSnapshot := { snapshot with attention := .failed "attention read failed" }
  let failedSnapshot := { failedSnapshot with pace := .failed "pace read failed" }
  let failedSnapshot := { failedSnapshot with paceHistory := .failed "pace history read failed" }
  let failedText :=
    widgetText (Loam.Tui.Home.view stateBounds failedSnapshot dailyState)
  expect (contains "Attention: failed" failedText &&
      contains "Daily Pace: calculation failed" failedText &&
      !contains "Recent pace" failedText &&
      !contains "pace history read failed" failedText)
    "Home exposed historical pace failure on the current glance surface"

  let unknownHome := Loam.Tui.Main.initialState "2026-09-08"
  match Loam.Tui.Main.homeScheduledEvidence snapshot unknownHome with
  | .ok .unknown => pure ()
  | _ => throw (IO.userError "Home Scheduled evidence collapsed an unknown day")
  let unknownText := widgetText (Loam.Tui.Home.view bounds snapshot unknownHome)
  expect (contains "unknown; no completeness horizon is claimed" unknownText)
    "Home collapsed Scheduled Unknown into an empty-day claim"

  let pendingActual : Loam.Tui.Main.ActualSnapshot := {
    snapshot.actual with today := "2026-09-08"
  }
  let pendingSnapshot : Loam.Tui.Main.Snapshot := {
    snapshot with actual := pendingActual
  }
  let pendingScheduled ←
    match pendingSnapshot.scheduled with
    | .error message => throw (IO.userError message)
    | .ok scheduled => pure scheduled
  match Loam.ScheduledReview.currentOpenBeforeDate pendingScheduled "2026-09-08" with
  | .error message => throw (IO.userError message)
  | .ok pending =>
      expect (pending.length == 12)
        "past-date current-open Scheduled projection lost retained occurrences"
  match Loam.ScheduledReview.currentOpenBeforeDate pendingScheduled "2026-09-07" with
  | .error message => throw (IO.userError message)
  | .ok pending =>
      expect pending.isEmpty
        "Scheduled due on the boundary was incorrectly classified as past-date pending"

  let pendingHome := Loam.Tui.Main.initialState "2026-09-08"
  let pendingText := widgetText (Loam.Tui.Home.view bounds pendingSnapshot pendingHome)
  expect (contains "Pending: 12" pendingText)
    "Home status did not expose the past-date current-open Scheduled count"
  expect (contains "Pending Scheduled:" pendingText)
    "Home did not expose its pending Scheduled section"
  expect (contains "2026-09-07  [Still open]" pendingText)
    "Home pending section lost the original expected date"
  expect (contains " 7!" pendingText)
    "Home calendar did not mark the original date of a past-date current-open Scheduled"
  expect (contains "! = Scheduled still open" pendingText)
    "Unified calendar marker lost its non-rescheduling explanation"

  let sameDayView := Loam.Tui.Home.view bounds pendingSnapshot pendingHome
  expect (hasStyledText sameDayView " 8 " .selectedUnderlined)
    "Unified grid lost Today + focus emphasis"
  expect (hasStyledText sameDayView " 7!" .normal)
    "Unified grid lost the past-date current-open Scheduled marker"
  let moved := (Loam.Tui.Main.update pendingHome .right).state
  expect (moved.selectedDate == "2026-09-09") "Home focus did not advance"
  let movedView := Loam.Tui.Home.view bounds pendingSnapshot moved
  expect (hasStyledText movedView " 8 " .underlined)
    "Today indication followed focus instead of the snapshot date"
  expect (hasStyledText movedView " 9 " .selected)
    "Focus-only cell lost the unified calendar selected style"
  let movedAgain := (Loam.Tui.Main.update moved .right).state
  let movedAgainView := Loam.Tui.Home.view bounds pendingSnapshot movedAgain
  expect (hasStyledText movedAgainView " 8 " .underlined &&
    hasStyledText movedAgainView " 10 " .selected &&
    hasStyledText movedAgainView " 9 " .normal)
    "Moving focus left stale emphasis or moved Today"

  -- A real Pending date is strictly before Today. Synthetic marker input checks
  -- presentation composition without weakening that evidence boundary.
  let overlap : Widget := .row [
    Loam.Tui.Home.moneyDateSpan 99 "2026-09-08" ["2026-09-08"]
      pendingSnapshot moved "2026-09-08" ]
  expect (hasStyledText overlap " 8!" .underlined)
    "Unified grid lost synthetic Today + Pending marker or underline"
  let focusedOverlap : Widget := .row [
    Loam.Tui.Home.moneyDateSpan 99 "2026-09-08" ["2026-09-08"]
      pendingSnapshot pendingHome "2026-09-08" ]
  expect (hasStyledText focusedOverlap " 8!" .selectedUnderlined)
    "Unified grid lost synthetic Today + Focus + Pending presentation"

  -- Review owns fail-closed lifecycle refusal for exact-day answers.
  let scheduledEvidence ←
    match snapshot.scheduled with
    | .error message => throw (IO.userError message)
    | .ok evidence => pure evidence
  let invalidTerminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals?
      [{ source := ⟨"scheduled-0"⟩, target := some (.scheduled ⟨"missing-scheduled"⟩) }])
    "invalid replacement fixture could not be retained for Review qualification"
  let invalidEvidence : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled := scheduledEvidence.scheduled
    terminals := invalidTerminals
    events := scheduledEvidence.events
  }
  match Loam.ScheduledReview.dayEvidence invalidEvidence "2026-09-07" with
  | .error message =>
      expect
        (message ==
          "loam: Scheduled replacement refers to an unknown Scheduled identity")
        "Scheduled Review changed the qualified unknown-replacement refusal"
  | .ok _ =>
      throw (IO.userError
        "Scheduled Review exposed malformed replacement topology as an ordinary day answer")

  -- SGR attributes accumulate: each style must clear the previous underline,
  -- background and dim attributes before setting its own (including dirty redraw).
  for style in [Style.normal, .selected, .muted, .underlined, .selectedUnderlined,
      .series1, .series2, .series3, .series4, .series5] do
    let sgr := Loam.Tui.Terminal.ansiStyle style
    expect (sgr.startsWith "\x1b[0;" || sgr == "\x1b[0m")
      "Terminal style can leak attributes into the next calendar cell"

  IO.println "TUI Scheduled: distilled Home glance, Unknown/Pending, and independent Today/focus presentation passed."
