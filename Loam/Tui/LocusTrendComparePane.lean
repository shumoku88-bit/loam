import Loam.LocusTrendCompareReview
import Loam.LocusCatalog
import Loam.Tui.Chart
import Loam.Tui.CyclicIndex
import Loam.Tui.LocusPicker
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.LocusTrendComparePane

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Full-screen multi-Locus Trend

Presentation-only comparison of several exact Locus/Measure series over the same
configured historical windows.

Pointer and keyboard navigation select one time window shared by every series.
Series identity is expressed by both a standard ANSI style and a marker glyph so
the chart does not rely on color alone.
-/

structure Overlay where
  name : String
  /-- Calendar month chosen from the selected Day point, in YYYY-MM form. -/
  month : String
  days : List Nat
  deriving Repr, DecidableEq

structure OverlayDraft where
  month : String
  name : String := ""
  daysText : String := ""
  editingDays : Bool := false
  deriving Repr, DecidableEq

structure State where
  snapshot : Option Loam.LocusTrendCompareReview.Snapshot := none
  selected : Nat := 0
  /-- Presentation-only first point in the Day viewport. Cycle/Month always use zero. -/
  viewportStart : Nat := 0
  granularity : Loam.LocusTrendCompareReview.Granularity := .cycle
  scope : Loam.LocusTrendCompareReview.Scope := .allHistory
  candidateCatalog : Loam.LocusCatalog.Catalog := []
  pickerOpen : Bool := false
  pickerSlot : Nat := 0
  pickerIndex : Nat := 0
  /-- Session-only observation overlays. They are never loaded from or written to household data. -/
  overlays : List Overlay := []
  /-- Presentation switch for thin vertical guides through every active overlay date. -/
  overlayGuides : Bool := false
  overlayDraft : Option OverlayDraft := none
  deriving Repr, DecidableEq

def initial : State := {}

def maxSeries : Nat := 5
def maxOverlays : Nat := 3

def withCatalog
    (state : State) (catalog : Loam.LocusCatalog.Catalog) : State :=
  { state with candidateCatalog := catalog, pickerIndex := 0 }

def isPickerOpen (state : State) : Bool := state.pickerOpen

def openSeriesPicker (state : State) (activeCount : Nat) : State :=
  let slot := if activeCount < maxSeries then activeCount else 0
  { state with pickerOpen := true, pickerSlot := slot, pickerIndex := 0 }

def closeSeriesPicker (state : State) : State :=
  { state with pickerOpen := false, pickerIndex := 0 }

def selectPickerSlot (state : State) (slot : Nat) : State :=
  if slot < maxSeries then { state with pickerSlot := slot } else state

def movePicker (state : State) (back : Bool) : State :=
  let options := state.candidateCatalog
  if options.isEmpty then { state with pickerIndex := 0 }
  else
    { state with pickerIndex :=
        Loam.Tui.CyclicIndex.move options.length state.pickerIndex back }

def selectedPickerEntry? (state : State) : Option Loam.LocusCatalog.Entry :=
  if state.candidateCatalog.isEmpty then none
  else state.candidateCatalog[state.pickerIndex % state.candidateCatalog.length]?

/-- One calendar-month-ish inspection window without inventing aggregation semantics. -/
def dayViewportSize : Nat := 31

def clear (state : State) : State :=
  { state with
      snapshot := none
      selected := 0
      viewportStart := 0
      pickerOpen := false
      pickerIndex := 0
      overlayDraft := none }

private def maxDayViewportStart (count : Nat) : Nat :=
  count - min dayViewportSize count

private def usesSlidingDayViewport
    (granularity : Loam.LocusTrendCompareReview.Granularity)
    (scope : Loam.LocusTrendCompareReview.Scope) : Bool :=
  granularity == .day && scope == .allHistory

private def viewportStartFor
    (granularity : Loam.LocusTrendCompareReview.Granularity)
    (scope : Loam.LocusTrendCompareReview.Scope)
    (count selected currentStart : Nat) : Nat :=
  if !usesSlidingDayViewport granularity scope || count == 0 then
    0
  else
    let size := min dayViewportSize count
    let maxStart := maxDayViewportStart count
    let start := min currentStart maxStart
    if selected < start then
      selected
    else if start + size <= selected then
      min maxStart (selected + 1 - size)
    else
      start

private def selectedAnchor? (state : State) : Option String := do
  let snapshot ← state.snapshot
  let point ← snapshot.selectedWindow? state.selected
  pure point.start

private def indexContainingFrom?
    (anchor : String) :
    List Loam.LocusTrendReview.OverviewPoint → Nat → Option Nat
  | [], _ => none
  | point :: rest, index =>
      if decide (point.start <= anchor && anchor < point.throughExclusive) then
        some index
      else
        indexContainingFrom? anchor rest (index + 1)

def withSnapshot
    (state : State)
    (snapshot : Loam.LocusTrendCompareReview.Snapshot) : State :=
  let fallback := if snapshot.pointCount = 0 then 0 else snapshot.pointCount - 1
  let selected :=
    match selectedAnchor? state, snapshot.series.head? with
    | some anchor, some first =>
        (indexContainingFrom? anchor first.points 0).getD fallback
    | _, _ => fallback
  let viewportStart :=
    viewportStartFor
      snapshot.granularity snapshot.scope
      snapshot.pointCount selected state.viewportStart
  let rememberedScope :=
    if snapshot.granularity == .day then snapshot.scope else state.scope
  {
    state with
      snapshot := some snapshot
      selected := selected
      viewportStart := viewportStart
      granularity := snapshot.granularity
      scope := rememberedScope
  }

def changeGranularity (state : State) (finer : Bool) : State :=
  let granularity :=
    if finer then state.granularity.finer else state.granularity.coarser
  { state with
      granularity := granularity
      viewportStart :=
        if usesSlidingDayViewport granularity state.scope then
          state.viewportStart
        else 0 }

/-- The chosen Range is a Day-view preference. Cycle and Month stay all-history. -/
def effectiveScope (state : State) : Loam.LocusTrendCompareReview.Scope :=
  if state.granularity == .day then state.scope else .allHistory

def changeScope (state : State) (forward : Bool) : State :=
  if state.granularity != .day then
    state
  else
    let scope :=
      if forward then state.scope.next else state.scope.previous
    { state with scope := scope, viewportStart := 0 }

def moveSelection (state : State) (back : Bool) : State :=
  match state.snapshot with
  | none => state
  | some snapshot =>
      let count := snapshot.pointCount
      if count = 0 then { state with selected := 0 }
      else
        let last := count - 1
        let current := min state.selected last
        let next := if back then current - 1 else min last (current + 1)
        let viewportStart :=
          viewportStartFor
            state.granularity state.scope count next state.viewportStart
        { state with selected := next, viewportStart := viewportStart }

def plotLeft : Nat := 11

def plotWidth (bounds : Bounds) : Nat :=
  max 1 (Loam.Tui.Layout.contentWidth bounds - plotLeft)

private def pointCount (state : State) : Nat :=
  state.snapshot.map (·.pointCount) |>.getD 0

def visibleStart (state : State) : Nat :=
  if usesSlidingDayViewport state.granularity state.scope then
    min state.viewportStart (maxDayViewportStart (pointCount state))
  else
    0

def visibleCount (state : State) : Nat :=
  let count := pointCount state
  if usesSlidingDayViewport state.granularity state.scope then
    min dayViewportSize count
  else
    count

private def visiblePoints
    (state : State)
    (points : List Loam.LocusTrendReview.OverviewPoint) :
    List Loam.LocusTrendReview.OverviewPoint :=
  (points.drop (visibleStart state)).take (visibleCount state)

private def localSelected (state : State) : Nat :=
  state.selected - visibleStart state

private def indexWithStartFrom?
    (date : String) :
    List Loam.LocusTrendReview.OverviewPoint → Nat → Option Nat
  | [], _ => none
  | point :: rest, index =>
      if point.start == date then some index
      else indexWithStartFrom? date rest (index + 1)

def selectColumn (bounds : Bounds) (state : State) (column : Nat) : State :=
  if column < plotLeft then state
  else
    let count := visibleCount state
    if count = 0 then state
    else
      let localIndex :=
        Loam.Tui.Chart.nearestIndex
          (plotWidth bounds) count (column - plotLeft)
      { state with selected := visibleStart state + localIndex }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def seriesStyle (index : Nat) : Style :=
  match index % 5 with
  | 0 => .series1
  | 1 => .series2
  | 2 => .series3
  | 3 => .series4
  | _ => .series5

private def seriesMarker (index : Nat) : Char :=
  match index % 5 with
  | 0 => '●'
  | 1 => '◆'
  | 2 => '▲'
  | 3 => '■'
  | _ => '□'

private def commaEveryThreeFromRight : List Char → Nat → List Char
  | [], _ => []
  | char :: rest, count =>
      if count = 3 then
        ',' :: char :: commaEveryThreeFromRight rest 1
      else
        char :: commaEveryThreeFromRight rest (count + 1)

private def groupedNat (value : Nat) : String :=
  let reversed :=
    commaEveryThreeFromRight (toString value).toList.reverse 0
  String.ofList reversed.reverse

private def amountText (value : Int) : String :=
  if value < 0 then "-¥" ++ groupedNat (-value).natAbs
  else "¥" ++ groupedNat value.natAbs

private def monthLabel : String → String
  | "01" => "Jan" | "02" => "Feb" | "03" => "Mar" | "04" => "Apr"
  | "05" => "May" | "06" => "Jun" | "07" => "Jul" | "08" => "Aug"
  | "09" => "Sep" | "10" => "Oct" | "11" => "Nov" | "12" => "Dec"
  | value => value

private def shortDate (date : String) : String :=
  match date.splitOn "-" with
  | [_, month, day] =>
      monthLabel month ++ " " ++
        (day.toNat?.map toString |>.getD day)
  | _ => date

private def longDate (date : String) : String :=
  match date.splitOn "-" with
  | [year, _, _] =>
      shortDate date ++ ", " ++ year
  | _ => date

private def spaces (count : Nat) : String :=
  String.ofList (List.replicate count ' ')

private def centered (width : Nat) (text : String) : String :=
  let clipped := Loam.Tui.Layout.clip width text
  let remaining := width - Loam.Tui.Layout.displayWidth clipped
  let left := remaining / 2
  spaces left ++ clipped ++ spaces (remaining - left)

private def selectedWindow?
    (state : State) : Option Loam.LocusTrendReview.OverviewPoint := do
  let snapshot ← state.snapshot
  snapshot.selectedWindow? state.selected

private def monthOfDate? (date : String) : Option String :=
  match date.splitOn "-" with
  | [year, month, _] => some (year ++ "-" ++ month)
  | _ => none

private def trimAscii (text : String) : String :=
  text.trimAsciiEnd.toString.trimAsciiStart.toString

private def twoDigitDay (day : Nat) : String :=
  if day < 10 then "0" ++ toString day else toString day

private def normalizeDaySeparators (text : String) : String :=
  String.ofList <| text.toList.map fun char =>
    if char == ',' || char == '.' then ' ' else char

private def parseOverlayDays
    (month text : String) : Except String (List Nat) := do
  let tokens :=
    (normalizeDaySeparators text).splitOn " " |>.filter (fun token => !token.isEmpty)
  if tokens.isEmpty then
    throw "Enter at least one day number."
  let rec parse : List String → Except String (List Nat)
    | [] => pure []
    | token :: rest => do
        let some day := token.toNat?
          | throw ("Day must be a number: " ++ token)
        return day :: (← parse rest)
  let parsed ← parse tokens
  let days :=
    parsed.foldl
      (fun kept day => if kept.contains day then kept else kept ++ [day]) []
  match days.find? fun day =>
      day == 0 ||
        !Loam.ActualDate.validIsoDate (month ++ "-" ++ twoDigitDay day) with
  | some day =>
      throw ("Day " ++ toString day ++ " is not in " ++ month ++ ".")
  | none => return days

def isOverlayEditing (state : State) : Bool :=
  state.overlayDraft.isSome

def beginOverlay (state : State) : Except String State := do
  if state.granularity != .day then
    throw "Trend overlays are available in Day grain."
  if state.overlays.length >= maxOverlays then
    throw ("Trend keeps at most " ++ toString maxOverlays ++ " session overlays.")
  match selectedWindow? state with
  | none => throw "Trend has no selected Day for an overlay."
  | some point =>
      match monthOfDate? point.start with
      | none => throw "Selected Trend day has no calendar month."
      | some month =>
          return { state with overlayDraft := some { month := month } }

def cancelOverlay (state : State) : State :=
  { state with overlayDraft := none }

def clearOverlays (state : State) : State :=
  { state with overlays := [], overlayGuides := false, overlayDraft := none }

def toggleOverlayGuides (state : State) : State :=
  if state.overlays.isEmpty then state
  else { state with overlayGuides := !state.overlayGuides }

def toggleOverlayField (state : State) : State :=
  match state.overlayDraft with
  | none => state
  | some draft =>
      { state with
          overlayDraft := some { draft with editingDays := !draft.editingDays } }

private def dropLastChar (text : String) : String :=
  String.ofList text.toList.dropLast

def backspaceOverlay (state : State) : State :=
  match state.overlayDraft with
  | none => state
  | some draft =>
      let next :=
        if draft.editingDays then
          { draft with daysText := dropLastChar draft.daysText }
        else
          { draft with name := dropLastChar draft.name }
      { state with overlayDraft := some next }

def pushOverlayChar (state : State) (char : Char) : State :=
  match state.overlayDraft with
  | none => state
  | some draft =>
      if draft.editingDays then
        if (char.isDigit || char == ' ' || char == ',' || char == '.') &&
            draft.daysText.length < 96 then
          { state with overlayDraft := some { draft with daysText := draft.daysText.push char } }
        else
          state
      else if draft.name.length < 32 then
        { state with overlayDraft := some { draft with name := draft.name.push char } }
      else
        state

def acceptOverlayDraft (state : State) : Except String State := do
  match state.overlayDraft with
  | none => return state
  | some draft =>
      let name := trimAscii draft.name
      if name.isEmpty then
        throw "Overlay name is required."
      else if !draft.editingDays then
        return { state with
          overlayDraft := some { draft with name := name, editingDays := true } }
      else
        let days ← parseOverlayDays draft.month draft.daysText
        return {
          state with
            overlays := state.overlays ++ [{ name := name, month := draft.month, days := days }]
            overlayDraft := none
        }

private def overlayContainsDate (overlay : Overlay) (date : String) : Bool :=
  match date.splitOn "-" with
  | [year, month, dayText] =>
      overlay.month == year ++ "-" ++ month &&
        match dayText.toNat? with
        | some day => overlay.days.contains day
        | none => false
  | _ => false

private def overlayMarker : Nat → Char
  | 0 => 'A'
  | 1 => 'B'
  | _ => 'C'

private def overlayMarkerForDate (state : State) (date : String) : Option Char :=
  let matching :=
    state.overlays.zipIdx.filterMap fun (overlay, index) =>
      if overlayContainsDate overlay date then some index else none
  match matching with
  | [] => none
  | [index] => some (overlayMarker index)
  | _ => some '*'

private def overlayDaysText (overlay : Overlay) : String :=
  String.intercalate " " (overlay.days.map toString)

private def rackLabel (label : String) : String :=
  Loam.Tui.Layout.clip 14 label

private def seriesSlot
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (index : Nat) : Span :=
  match snapshot.series[index]? with
  | some series =>
      span
        ("[" ++ toString (index + 1) ++ " " ++
          String.ofList [seriesMarker index] ++ " " ++ rackLabel series.spec.label ++ "] ")
        (seriesStyle index)
  | none =>
      span ("[" ++ toString (index + 1) ++ " + Add] ") .muted

private def seriesRack
    (snapshot : Loam.LocusTrendCompareReview.Snapshot) : List Widget :=
  [ .row
      ([span "Series  " .muted] ++
        (List.range 3).map (seriesSlot snapshot))
  , .row
      ([span "        " .muted] ++
        (List.range 2).map fun offset => seriesSlot snapshot (offset + 3))
  ]

private def overlayMonthLabel (month : String) : String :=
  match month.splitOn "-" with
  | [year, monthNumber] => monthLabel monthNumber ++ " " ++ year
  | _ => month

private def overlayEditorRows (state : State) : List Widget :=
  match state.overlayDraft with
  | none => []
  | some draft =>
      [ line "Overlay   session only · not saved"
      , muted ("Month   " ++ overlayMonthLabel draft.month ++ "   ·   selected Day month")
      , .row
          [ span "Name    " .muted
          , span (if draft.name.isEmpty then "_" else draft.name)
              (if draft.editingDays then .normal else .selected)
          ]
      , .row
          [ span "Days    " .muted
          , span (if draft.daysText.isEmpty then "_" else draft.daysText)
              (if draft.editingDays then .selected else .normal)
          ]
      , muted "Enter day numbers such as: 3 4 6 8 9   (spaces, commas, or periods)"
      , muted "Tab field   Enter next/apply   Esc cancel"
      ]

private def pickerRows (state : State) : List Widget :=
  if !state.pickerOpen then []
  else
    let count := state.candidateCatalog.length
    if count = 0 then
      [ muted "Series picker: no currently admitted Locus is available."
      , muted "Esc cancel"
      ]
    else
      let selected := state.pickerIndex % count
      let start := selected - min selected 3
      let visible := (state.candidateCatalog.drop start).take 7
      [ line ("Series picker   slot " ++ toString (state.pickerSlot + 1) ++
          " / " ++ toString maxSeries ++ "   ·   exact Locus / inherited Measure") ] ++
      visible.zipIdx.map (fun (entry, localIndex) =>
        let absoluteIndex := start + localIndex
        let marker := if absoluteIndex == selected then "› " else "  "
        .row
          [ span (marker ++ Loam.Tui.LocusPicker.display entry)
              (if absoluteIndex == selected then .selected else .normal) ])

private def selectedSeriesRows (state : State) : List Widget :=
  match state.snapshot with
  | none => []
  | some snapshot =>
      snapshot.series.zipIdx.map fun (series, index) =>
        let value := series.valueAt? state.selected |>.getD 0
        let suffix := if snapshot.granularity == .day then "" else "/day"
        .row
          [ span (String.ofList [seriesMarker index] ++ " " ++ series.spec.label ++ "  ")
              (seriesStyle index)
          , span (amountText value ++ suffix)
          ]

private def isCurrentPartial
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (point : Loam.LocusTrendReview.OverviewPoint) : Bool :=
  !point.complete && snapshot.observedAt < point.throughExclusive

private def periodStatus
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (point : Loam.LocusTrendReview.OverviewPoint) : String :=
  if point.complete then "complete"
  else if isCurrentPartial snapshot point then "current partial"
  else "partial coverage"

private def heading :
    Loam.LocusTrendCompareReview.Granularity → String
  | .cycle => "Trend   cycle average / day"
  | .month => "Trend   month average / day"
  | .day => "Trend   daily amount"

private def scopeEndLabel
    (snapshot : Loam.LocusTrendCompareReview.Snapshot) : String :=
  match Loam.ActualDate.shiftDays? snapshot.scopeEndExclusive (-1) with
  | some date => shortDate date
  | none => shortDate snapshot.scopeEndExclusive

private def sourceLine
    (state : State)
    (snapshot : Loam.LocusTrendCompareReview.Snapshot) : String :=
  match snapshot.granularity with
  | .day =>
      let viewport :=
        if usesSlidingDayViewport snapshot.granularity snapshot.scope then
          "   ·   " ++ toString (visibleCount state) ++ "-day viewport"
        else
          ""
      snapshot.source ++
        "   ·   Range " ++ snapshot.scope.label ++
        "   " ++ shortDate snapshot.scopeStart ++ " → " ++ scopeEndLabel snapshot ++
        "   ·   Grain Day   ·   jpy   ·   braille" ++ viewport
  | granularity =>
      snapshot.source ++
        "   ·   Grain " ++ granularity.label ++
        "   ·   jpy   ·   braille"

private def selectedLine
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (point : Loam.LocusTrendReview.OverviewPoint) : String :=
  match snapshot.granularity with
  | .day =>
      "Selected   " ++ longDate point.start ++
        (if isCurrentPartial snapshot point then "   ·   current day" else "")
  | _ =>
      let endLabel :=
        if isCurrentPartial snapshot point then snapshot.observedAt
        else point.endExclusive
      "Selected   " ++ shortDate point.start ++ " → " ++
        shortDate endLabel ++ "   ·   " ++ periodStatus snapshot point

private def header (state : State) : List Widget :=
  match state.snapshot, selectedWindow? state with
  | some snapshot, some point =>
      [ line (heading snapshot.granularity) ] ++
      seriesRack snapshot ++
      [ muted (sourceLine state snapshot)
      , line (selectedLine snapshot point)
      ] ++ selectedSeriesRows state ++
      [ muted "Exact Locus series; no alias, description, or historical reclassification is inferred." ] ++
      pickerRows state ++ overlayEditorRows state
  | _, _ =>
      [ line ("Trend   " ++ state.granularity.label)
      , muted "Multi-series history unavailable."
      ] ++ pickerRows state ++ overlayEditorRows state

private def allValues (state : State) : List Int :=
  match state.snapshot with
  | none => []
  | some snapshot =>
      snapshot.series.flatMap fun series =>
        (visiblePoints state series.points).map (·.dailyAverageQuanta)

private def plotSeries (state : State) : List Loam.Tui.Chart.PlotSeries :=
  match state.snapshot with
  | none => []
  | some snapshot =>
      snapshot.series.zipIdx.map fun (series, index) =>
        {
          values := (visiblePoints state series.points).map (·.dailyAverageQuanta)
          style := seriesStyle index
          marker := seriesMarker index
        }

private def chartScale (state : State) : Loam.Tui.Chart.Scale :=
  Loam.Tui.Chart.scaleFor (allValues state) 4

private def tickForRow?
    (height row : Nat) (scale : Loam.Tui.Chart.Scale) : Option Int :=
  scale.ticks.find? fun tick =>
    Loam.Tui.Chart.rowForValue height scale.range tick = row

private def axisText
    (height row : Nat) (scale : Loam.Tui.Chart.Scale) : String :=
  match tickForRow? height row scale with
  | some tick =>
      Loam.Tui.Layout.padLeft 8 (amountText tick) ++ " ┤ "
  | none => "         │ "

private def overlayGuideColumns (bounds : Bounds) (state : State) : List Nat :=
  if state.granularity != .day || !state.overlayGuides then
    []
  else
    match state.snapshot with
    | none => []
    | some snapshot =>
        match snapshot.series.head? with
        | none => []
        | some first =>
            let width := plotWidth bounds
            let points := visiblePoints state first.points
            let count := points.length
            points.zipIdx.filterMap fun (point, index) =>
              if state.overlays.any fun overlay =>
                  overlayContainsDate overlay point.start then
                some (Loam.Tui.Chart.xForIndex width count index)
              else
                none

private def overlayRows (bounds : Bounds) (state : State) : List Widget :=
  if state.granularity != .day || state.overlays.isEmpty then
    []
  else
    match state.snapshot with
    | none => []
    | some snapshot =>
        match snapshot.series.head? with
        | none => []
        | some first =>
            let width := plotWidth bounds
            let points := visiblePoints state first.points
            let count := points.length
            let placements :=
              points.zipIdx.filterMap fun (point, index) =>
                match overlayMarkerForDate state point.start with
                | none => none
                | some marker =>
                    some (Loam.Tui.Chart.xForIndex width count index, marker)
            let markerText :=
              String.ofList <| (List.range width).map fun column =>
                let here :=
                  placements.filterMap fun (x, marker) =>
                    if x == column then some marker else none
                match here with
                | [] => ' '
                | [marker] => marker
                | _ => '*'
            let markerRow :=
              .row [span (spaces plotLeft), span markerText]
            let legendTokens :=
              ("Overlay session-only · guides " ++
                (if state.overlayGuides then "on" else "off") ++ " · not saved") ::
                state.overlays.zipIdx.map fun (overlay, index) =>
                  String.ofList [overlayMarker index] ++ " " ++ overlay.name ++
                    " (" ++ overlayMonthLabel overlay.month ++ ": " ++
                    overlayDaysText overlay ++ ")"
            markerRow ::
              (Loam.Tui.Layout.flowTokens
                (Loam.Tui.Layout.contentWidth bounds) "   " legendTokens).map muted

private def footerTokens (state : State) : List String :=
  if isOverlayEditing state then
    ["Type overlay", "Tab field", "Enter next/apply", "Esc cancel"]
  else if state.pickerOpen then
    ["↑/↓ choose Locus", "1-5 slot", "Enter apply", "x remove", "Esc cancel"]
  else
    let common :=
      ["←/→ or wheel select period", "mouse click/drag scrub", "[ / ] grain",
       "a series"]
    let range :=
      if state.granularity == .day then ["s/S range"] else []
    let overlay :=
      if state.granularity == .day then
        if state.overlays.isEmpty then ["o overlay"]
        else
          ["o overlay",
           "v guides " ++ (if state.overlayGuides then "off" else "on"),
           "O clear overlays"]
      else
        []
    common ++ range ++ overlay ++ ["q/Esc Reports"]

private def footer (bounds : Bounds) (state : State) : List Widget :=
  (Loam.Tui.Layout.flowTokens
      (Loam.Tui.Layout.contentWidth bounds) "   " (footerTokens state)).map muted

private def headerLineCount (state : State) : Nat :=
  (header state).length

private def axisLineCount : Nat := 1

def plotTop (state : State) : Nat :=
  headerLineCount state

def plotHeight (bounds : Bounds) (state : State) : Nat :=
  let fixedRows :=
    headerLineCount state + axisLineCount +
      (overlayRows bounds state).length + (footer bounds state).length
  if bounds.height > fixedRows then bounds.height - fixedRows else 1

def pointerInPlot (bounds : Bounds) (state : State) (row : Nat) : Bool :=
  !isOverlayEditing state &&
    decide (plotTop state <= row && row < plotTop state + plotHeight bounds state)

private def chartRows (bounds : Bounds) (state : State) : List Widget :=
  let width := plotWidth bounds
  let height := plotHeight bounds state
  let scale := chartScale state
  let gridRows :=
    scale.ticks.map fun tick =>
      Loam.Tui.Chart.rowForValue height scale.range tick
  let rendered :=
    Loam.Tui.Chart.renderManyInRange
      .braille width height (plotSeries state) (localSelected state)
      scale.range gridRows (overlayGuideColumns bounds state)
  (List.range height).map fun row =>
    match rendered[row]? with
    | some widget =>
        match widget with
        | Widget.row spans =>
            Widget.row ([span (axisText height row scale)] ++ spans)
        | Widget.column _ => Widget.row [span (axisText height row scale)]
    | none => Widget.row [span (axisText height row scale)]

private def compactAxisRow
    (bounds : Bounds)
    (first : Loam.LocusTrendReview.OverviewPoint)
    (last : Loam.LocusTrendReview.OverviewPoint) : Widget :=
  let width := plotWidth bounds
  let text := shortDate first.start ++ "   …   " ++ shortDate last.start
  .row [span (spaces plotLeft), span (centered width text) .muted]

private def placedLabel
    (width center : Nat) (text : String) : Nat × String :=
  let clipped := Loam.Tui.Layout.clip width text
  let labelWidth := Loam.Tui.Layout.displayWidth clipped
  let half := labelWidth / 2
  let start := center - min center half
  let maxStart := width - min width labelWidth
  (min start maxStart, clipped)

private def labelCharAt?
    (column : Nat) (label : Nat × String) : Option Char :=
  if label.1 <= column then
    label.2.toList[column - label.1]?
  else
    none

private def overlaidLabels
    (width : Nat) (labels : List (Nat × String)) : String :=
  String.ofList <|
    (List.range width).map fun column =>
      (labels.findSome? (labelCharAt? column)).getD ' '

private def dayAxisRow
    (bounds : Bounds) (state : State)
    (snapshot : Loam.LocusTrendCompareReview.Snapshot)
    (points : List Loam.LocusTrendReview.OverviewPoint)
    (first last : Loam.LocusTrendReview.OverviewPoint) : Widget :=
  let width := plotWidth bounds
  let count := points.length
  let firstLabel := placedLabel width 0 (shortDate first.start)
  let rightLabel :=
    match indexWithStartFrom? snapshot.observedAt points 0 with
    | some index =>
        placedLabel width
          (Loam.Tui.Chart.xForIndex width count index)
          ("As of " ++ shortDate snapshot.observedAt)
    | none =>
        placedLabel width (width - 1) (shortDate last.start)
  let selectedLabel? :=
    match points[localSelected state]? with
    | some point =>
        let text :=
          if point.start == snapshot.observedAt then
            "As of " ++ shortDate snapshot.observedAt
          else
            shortDate point.start
        some <| placedLabel width
          (Loam.Tui.Chart.xForIndex width count (localSelected state)) text
    | none => none
  let labels :=
    match selectedLabel? with
    | some selectedLabel => [selectedLabel, rightLabel, firstLabel]
    | none => [rightLabel, firstLabel]
  .row [span (spaces plotLeft), span (overlaidLabels width labels) .muted]

private def axisRow
    (bounds : Bounds) (state : State) : Widget :=
  match state.snapshot with
  | none => muted ""
  | some snapshot =>
      match snapshot.series.head? with
      | none => muted ""
      | some first =>
          let width := plotWidth bounds
          let points := visiblePoints state first.points
          let count := points.length
          match points.head?, points.getLast? with
          | some firstPoint, some lastPoint =>
              if snapshot.granularity == .day then
                dayAxisRow bounds state snapshot points firstPoint lastPoint
              else if count > 0 && width / count < 8 then
                compactAxisRow bounds firstPoint lastPoint
              else
                let chunk := if count = 0 then width else max 1 (width / count)
                let labels := first.points.map fun point =>
                  let endLabel :=
                    if isCurrentPartial snapshot point then snapshot.observedAt
                    else point.endExclusive
                  centered chunk (shortDate point.start ++ " → " ++ shortDate endLabel)
                .row ([span (spaces plotLeft)] ++ labels.map fun text => span text .muted)
          | _, _ => muted ""

/-- Render Trend as a dedicated full-screen chart. -/
def viewFullScreen
    (bounds : Bounds) (state : State) (notice : String := "") : Widget :=
  let rows :=
    header state ++ chartRows bounds state ++ [axisRow bounds state] ++
      overlayRows bounds state ++ footer bounds state ++
      (if notice.isEmpty then [] else [line notice])
  .column (rows.take bounds.height)

end Loam.Tui.LocusTrendComparePane
