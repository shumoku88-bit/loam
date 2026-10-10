import Loam.Tui.Layout
import Loam.Tui.Main
import Loam.Tui.Scroll

namespace Loam.Tui.SelectedDay

open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

inductive Pane where
  | actual
  | scheduled
  deriving Repr, DecidableEq, BEq

structure State where
  focusDate : String
  pane : Pane := .actual
  actualRow : Nat := 0
  scheduledRow : Nat := 0
  /-- Ephemeral detail focus and wrapped-line offset; never household state. -/
  detailFocused : Bool := false
  detailScroll : Nat := 0
  notice : String := ""
  deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
  | pageUp
  | pageDown
  | home
  | «end»
  | focusLeft
  | focusRight
  | focusDetails
  | recordNew
  | createScheduled
  | correctActual
  | reverseActual
  | correctDate
  | classifyMerchant
  | manageLoci
  | completeScheduled
  | cancelScheduled
  | replaceScheduled
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | recordNew
  | createScheduled
  | correctActual
  | reverseActual
  | correctDate
  | classifyMerchant
  | manageLoci
  | completeScheduled
  | cancelScheduled
  | replaceScheduled
  | back
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  command : Command := .stay


def initial (focusDate : String) : State :=
  { focusDate := focusDate }

/-- Open one dated current Actual with that exact Event selected in the day workspace. -/
def initialForActual? (snapshot : Snapshot) (record : ReviewRecord) : Option State := do
  let date ← record.date
  let index ← (recordsForDay snapshot date).findIdx? fun item =>
    item.event.id == record.event.id
  some { focusDate := date, pane := .actual, actualRow := index }

/-- Selected-day Actual is exactly the existing shared ActualReview day answer. -/
def actualRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  recordsForDay snapshot state.focusDate

/-- Selected-day Scheduled evidence preserves both startup refusal and the shared open-world answer. -/
def scheduledEvidence
    (snapshot : Snapshot) (state : State) : Except String ScheduledEvidence :=
  match snapshot.scheduled with
  | .error message => .error message
  | .ok scheduled => Loam.ScheduledReview.dayEvidence scheduled state.focusDate


def scheduledRecords (snapshot : Snapshot) (state : State) : List ScheduledRecord :=
  match scheduledEvidence snapshot state with
  | .error _ => []
  | .ok evidence => Loam.ScheduledReview.explicitDueRecords evidence


def selectedActual? (snapshot : Snapshot) (state : State) : Option ReviewRecord :=
  (actualRecords snapshot state)[state.actualRow]?


def selectedScheduled? (snapshot : Snapshot) (state : State) : Option ScheduledRecord :=
  (scheduledRecords snapshot state)[state.scheduledRow]?

private def scheduledUnavailableNotice? (snapshot : Snapshot) : Option String :=
  match snapshot.scheduled with
  | .error message => some ("[Unavailable] Scheduled: " ++ message)
  | .ok _ => none

private def clampState (snapshot : Snapshot) (state : State) : State :=
  let actualCount := (actualRecords snapshot state).length
  let scheduledCount := (scheduledRecords snapshot state).length
  let actualRow := if actualCount = 0 then 0 else min state.actualRow (actualCount - 1)
  let scheduledRow := if scheduledCount = 0 then 0 else min state.scheduledRow (scheduledCount - 1)
  { state with actualRow := actualRow, scheduledRow := scheduledRow }

/-- Re-clamp only process-local selection after canonical evidence changes. -/
def refreshed (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot { state with notice := "", detailScroll := 0 }

private def movePrevious (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      if state.actualRow = 0 then { state with notice := "No previous Actual row on this day." }
      else { state with actualRow := state.actualRow - 1, notice := "" }
  | .scheduled =>
      if state.scheduledRow = 0 then { state with notice := "No previous Scheduled row on this day." }
      else { state with scheduledRow := state.scheduledRow - 1, notice := "" }

private def moveNext (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      let count := (actualRecords snapshot state).length
      if state.actualRow + 1 < count then
        { state with actualRow := state.actualRow + 1, notice := "" }
      else
        { state with notice := "No next Actual row on this day." }
  | .scheduled =>
      let count := (scheduledRecords snapshot state).length
      if state.scheduledRow + 1 < count then
        { state with scheduledRow := state.scheduledRow + 1, notice := "" }
      else
        { state with notice := "No next Scheduled row on this day." }

private def movePageUp (snapshot : Snapshot) (state : State) (pageSize : Nat := 8) : State :=
  match state.pane with
  | .actual =>
      if state.actualRow == 0 then { state with notice := "Top of Actual list." }
      else { state with actualRow := state.actualRow - min state.actualRow pageSize, notice := "" }
  | .scheduled =>
      if state.scheduledRow == 0 then { state with notice := "Top of Scheduled list." }
      else { state with scheduledRow := state.scheduledRow - min state.scheduledRow pageSize, notice := "" }

private def movePageDown (snapshot : Snapshot) (state : State) (pageSize : Nat := 8) : State :=
  match state.pane with
  | .actual =>
      let count := (actualRecords snapshot state).length
      if count == 0 || state.actualRow + 1 >= count then { state with notice := "End of Actual list." }
      else { state with actualRow := min (count - 1) (state.actualRow + pageSize), notice := "" }
  | .scheduled =>
      let count := (scheduledRecords snapshot state).length
      if count == 0 || state.scheduledRow + 1 >= count then { state with notice := "End of Scheduled list." }
      else { state with scheduledRow := min (count - 1) (state.scheduledRow + pageSize), notice := "" }

private def moveHome (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual => { state with actualRow := 0, notice := "" }
  | .scheduled => { state with scheduledRow := 0, notice := "" }

private def moveEnd (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .actual =>
      let count := (actualRecords snapshot state).length
      let row := if count == 0 then 0 else count - 1
      { state with actualRow := row, notice := "" }
  | .scheduled =>
      let count := (scheduledRecords snapshot state).length
      let row := if count == 0 then 0 else count - 1
      { state with scheduledRow := row, notice := "" }

private def updateIntent (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := movePrevious snapshot state }
  | .next => { state := moveNext snapshot state }
  | .pageUp => { state := movePageUp snapshot state }
  | .pageDown => { state := movePageDown snapshot state }
  | .home => { state := moveHome snapshot state }
  | .«end» => { state := moveEnd snapshot state }
  | .focusLeft => { state := { state with pane := .actual, detailFocused := false, notice := "" } }
  | .focusRight => { state := { state with pane := .scheduled, detailFocused := false, notice := "" } }
  | .focusDetails => { state := { state with detailFocused := !state.detailFocused, notice := "" } }
  | .recordNew =>
      match state.pane with
      | .actual => { state, command := .recordNew }
      | .scheduled =>
          { state := { state with notice := "New Actual is available from the Actual pane." } }
  | .createScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "New Scheduled is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none => { state, command := .createScheduled }
  | .correctActual =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Correction is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for correction." } }
          | some _ => { state, command := .correctActual }
  | .reverseActual =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Reversal is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for reversal." } }
          | some _ => { state, command := .reverseActual }
  | .correctDate =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Date correction is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for date correction." } }
          | some _ => { state, command := .correctDate }
  | .classifyMerchant =>
      match state.pane with
      | .scheduled =>
          { state := { state with notice := "Merchant classification is available from the Actual pane." } }
      | .actual =>
          match selectedActual? snapshot state with
          | none =>
              { state := { state with notice := "No current Actual is selected for Merchant classification." } }
          | some _ => { state, command := .classifyMerchant }
  | .manageLoci =>
      match state.pane with
      | .actual => { state, command := .manageLoci }
      | .scheduled =>
          { state := { state with notice := "Locus management is available from the Actual pane." } }
  | .completeScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Completion is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none =>
              match selectedScheduled? snapshot state with
              | none =>
                  { state := { state with notice := "No current-open Scheduled occurrence is selected for completion." } }
              | some _ => { state, command := .completeScheduled }
  | .cancelScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Cancellation is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none =>
              match selectedScheduled? snapshot state with
              | none =>
                  { state := { state with notice := "No current-open Scheduled occurrence is selected for cancellation." } }
              | some _ => { state, command := .cancelScheduled }
  | .replaceScheduled =>
      match state.pane with
      | .actual =>
          { state := { state with notice := "Supersede is available from the Scheduled pane." } }
      | .scheduled =>
          match scheduledUnavailableNotice? snapshot with
          | some notice => { state := { state with notice := notice } }
          | none =>
              match selectedScheduled? snapshot state with
              | none =>
                  { state := { state with notice := "No current-open Scheduled occurrence is selected for supersede." } }
              | some _ => { state, command := .replaceScheduled }
  | .back =>
      if state.detailFocused then { state := {state with detailFocused := false, notice := ""} }
      else { state, command := .back }
  | .other => { state }

/-- Geometry-free action/selection entrance used by shared-boundary interaction tests. -/
def update (snapshot : Snapshot) (rawState : State) (event : Event) : Step :=
  let state := clampState snapshot rawState
  let step := updateIntent snapshot state event
  if step.state.pane != state.pane || step.state.actualRow != state.actualRow ||
      step.state.scheduledRow != state.scheduledRow then
    {step with state := {step.state with detailScroll := 0}}
  else step

private def fitText (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text ≤ width then Loam.Tui.Layout.padRight width text
  else Loam.Tui.Layout.padRight width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

private def wrapped (width : Nat) (text : String) (style : Style := .normal) : List Widget :=
  (Loam.Tui.Layout.wrapColumns (width - 1) text).map fun line =>
    .row [span " ", span line style]

private def widgetRows (widget : Widget) : List Widget :=
  widget.lines.map fun cells => .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)

private def quantaText (measure : Loam.Core.MeasureId) (quanta : Int) : String :=
  Loam.MeasurePresentation.groupDisplayedNumber (toString quanta) ++ " " ++ measure.token

private def descriptionText (record : ReviewRecord) : String :=
  if record.description.isEmpty then "(no description)" else Loam.ActualReview.displayText record.description

/-- One explicit receiving Effect, not expense classification or a sum across Measures. -/
private def actualQuantity (record : ReviewRecord) : String :=
  let effects := record.event.effects
  let measures := (effects.map fun effect => effect.measure.token).eraseDups
  let positive := effects.filter fun effect => effect.quantity.quanta > 0
  let negative := effects.filter fun effect => effect.quantity.quanta < 0
  if measures.length > 1 then s!"multi ({measures.length})"
  else if positive.length > 1 || negative.length > 1 then "split"
  else match positive.head? with
    | some effect => quantaText effect.measure effect.quantity.quanta
    | none => if effects.isEmpty then "—" else "see details"

private def scheduledShape (record : ScheduledRecord) : String :=
  let sources := record.movement.changes.filter fun change => change.quantity.quanta < 0
  let destinations := record.movement.changes.filter fun change => change.quantity.quanta > 0
  match sources, destinations with
  | [source], [destination] => source.coordinate.token ++ " -> " ++ destination.coordinate.token
  | _, _ => s!"split ({record.movement.changes.length} changes)"

private def scheduledQuantity (record : ScheduledRecord) : String :=
  let sources := record.movement.changes.filter fun change => change.quantity.quanta < 0
  let destinations := record.movement.changes.filter fun change => change.quantity.quanta > 0
  match sources, destinations with
  | [_], [destination] => quantaText record.measure destination.quantity.quanta
  | _, _ => "split"

private def effectLines
    (width : Nat) (locus : String) (measure : Loam.Core.MeasureId) (quanta : Int) : List Widget :=
  let quantity := (if quanta > 0 then "+" else "") ++ quantaText measure quanta
  let quantityWidth := Loam.Tui.Layout.displayWidth quantity
  if Loam.Tui.Layout.displayWidth locus + quantityWidth + 4 ≤ width then
    [plainLine (" " ++ Loam.Tui.Layout.padRight (width - quantityWidth - 3) locus ++ "  " ++ quantity)]
  else wrapped width locus ++ wrapped width ("Quanta: " ++ quantity)

private def detailRawLines (width : Nat) (snapshot : Snapshot) (state : State) : List Widget :=
  match state.pane with
  | .actual =>
      match selectedActual? snapshot state with
      | none => wrapped width "(no Actual selected)" .muted
      | some record =>
          wrapped width s!"Effects ({record.event.effects.length}, exact quanta):" .muted ++
          (record.event.effects.flatMap fun effect =>
            effectLines (min width 80) effect.locus.token effect.measure effect.quantity.quanta) ++
          [blankLine] ++ wrapped width (descriptionText record) ++
          wrapped width ("Date: " ++ record.date.getD "date unknown") .muted ++
          wrapped width ("ID: " ++ record.event.id.token) .muted
  | .scheduled =>
      match selectedScheduled? snapshot state with
      | none =>
          match scheduledEvidence snapshot state with
          | .error message => wrapped width ("[Unavailable] " ++ message)
          | .ok .unknown =>
              wrapped width "Unknown: absence of an explicit due occurrence is not NotDue." .muted
          | .ok (.due _ _) => wrapped width "(no Scheduled selected)" .muted
      | some record =>
          wrapped width s!"Expected Effects ({record.movement.changes.length}, exact quanta):" .muted ++
          (record.movement.changes.flatMap fun change =>
            effectLines (min width 80) change.coordinate.token record.measure change.quantity.quanta) ++
          wrapped width ("Due: " ++ record.scheduledOn) .muted ++
          wrapped width ("ID: " ++ record.id.token) .muted

/-- Bounds, not the selected record, determine the ordinary detail rectangle. -/
def detailCapacityForBounds (bounds : Bounds) : Nat :=
  if bounds.height ≥ 48 then 10 else if bounds.height ≥ 36 then 8 else 6

private def operationRows (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let navigation := if state.detailFocused then
      [("j/k", "scroll"), ("h/l", "pane"), ("Esc/i/q", "list")]
    else if width ≥ 100 then
      [("j/k", "select"), ("h/l", "Actual/Scheduled"), ("i/Tab", "details"), ("q", "back")]
    else [("j/k", "select"), ("h/l", "pane"), ("i", "details"), ("q", "back")]
  let navigation := if width < 79 && !state.detailFocused then
      [("j/k", "sel"), ("h/l", "pane"), ("i", "info"), ("q", "back")]
    else navigation
  let actions := match state.pane with
    | .actual => if width ≥ 79 then
        [("n", "new"), ("c", "correct"), ("r", "reverse"), ("d", "date"), ("m", "merchant"), ("g", "loci")]
      else if width ≥ 46 then
        [("n", "new"), ("c", "fix"), ("r", "rev"), ("d", "date"), ("m", ""), ("g", "loci")]
      else [("n", ""), ("c", ""), ("r", ""), ("d", ""), ("m", ""), ("g", "")]
    | .scheduled => if width ≥ 79 then
        [("n", "new"), ("c/Enter", "complete"), ("r", "replace"), ("x", "cancel")]
      else [("n", "new"), ("c/Enter", "done"), ("r", "repl"), ("x", "cancel")]
  [Loam.Tui.Layout.shortcutRow navigation " ", Loam.Tui.Layout.shortcutRow actions " "]

/-- Empty and one-line feedback reserve exactly the same rows above fixed operations. -/
private def footer (bounds : Bounds) (state : State) : List Widget :=
  let feedback := if state.notice.isEmpty then [blankLine]
    else wrapped (Loam.Tui.Layout.contentWidth bounds) state.notice .muted
  let rows := feedback ++ operationRows bounds state
  let capacity := bounds.height - 1
  if rows.length ≤ capacity then rows
  else if capacity == 0 then []
  else rows.take (capacity - 1) ++ [mutedLine " … more feedback/help; enlarge terminal"]

private structure Geometry where
  width : Nat
  panelHeight : Nat
  detailHeight : Nat
  listHeight : Nat
  contextRows : Nat
  wide : Bool
  detailOnly : Bool

private def geometry (bounds : Bounds) (state : State) : Geometry :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let bodyRows := Loam.Tui.Layout.footerBodyCapacity bounds (footer bounds state).length
  let contextRows := if bodyRows ≥ 5 then 2 else if bodyRows ≥ 4 then 1 else 0
  let panelHeight := bodyRows - contextRows
  let detailHeight := if panelHeight ≥ 12 then detailCapacityForBounds bounds + 2 else 0
  let detailOnly := state.detailFocused && detailHeight == 0
  {width, panelHeight, contextRows, detailOnly
   wide := width ≥ 99
   detailHeight := if detailOnly then panelHeight else detailHeight
   listHeight := if detailOnly then 0 else panelHeight - detailHeight - (if detailHeight > 0 then 1 else 0)}

private def detailLimit (g : Geometry) (snapshot : Snapshot) (state : State) : Nat :=
  if g.detailHeight < 3 then 0
  else Loam.Tui.Scroll.maxOffset (detailRawLines (g.width - 2) snapshot state).length (g.detailHeight - 2)

/-- Geometry normalization never changes the selected day or evidence identity. -/
def normalizedForBounds (bounds : Bounds) (snapshot : Snapshot) (state : State) : State :=
  let state := clampState snapshot state
  {state with detailScroll := min state.detailScroll (detailLimit (geometry bounds state) snapshot state)}

private def listCapacity (height : Nat) : Nat :=
  height - 2 - (if height ≥ 4 then 1 else 0)

private def quantityCell (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padLeft width
    (if Loam.Tui.Layout.displayWidth text ≤ width then text else "see details")

private def tableRow (width quantityWidth : Nat) (label quantity : String) : String :=
  fitText (width - quantityWidth - 2) label ++ "  " ++ quantityCell quantityWidth quantity

private def positionLabel (selected start visible total : Nat) : String :=
  (if total == 0 then "0/0" else s!"{selected + 1}/{total}") ++
    (if start > 0 then " ↑" else "") ++ (if start + visible < total then " ↓" else "")

private def listPanel
    (width height : Nat) (pane : Pane) (snapshot : Snapshot) (state : State) : Widget :=
  let actuals := (actualRecords snapshot state).toArray
  let scheduled := (scheduledRecords snapshot state).toArray
  let total := if pane == .actual then actuals.size else scheduled.size
  let selected := if pane == .actual then state.actualRow else state.scheduledRow
  let visible := listCapacity height
  let start := Loam.Tui.Layout.trailingWindowStart selected (max 1 visible)
  let focused := state.pane == pane && !state.detailFocused
  let rowWidth := width - 5
  let tabular := rowWidth ≥ 32
  let quantities := if pane == .actual then actuals.toList.map actualQuantity else scheduled.toList.map scheduledQuantity
  let quantityWidth := min 22 (max 12 (quantities.foldl (fun n value => max n (Loam.Tui.Layout.displayWidth value)) 0))
  let header := if height < 4 then [] else
    [mutedLine ("   " ++ (if tabular then tableRow rowWidth quantityWidth
      (if pane == .actual then "Description" else "Shape") "Quanta"
      else if pane == .actual then "Description" else "Shape"))]
  let emptyLines := if pane == .actual then wrapped (width - 2) "(none recorded)" .muted
    else match scheduledEvidence snapshot state with
      | .error message => wrapped (width - 2) ("[Unavailable] " ++ message)
      | .ok .unknown => wrapped (width - 2) "(Unknown; no completeness horizon claimed)" .muted
      | .ok (.due _ _) => wrapped (width - 2) "(no Scheduled selected)" .muted
  let rows := if total == 0 then emptyLines.take visible else
    (List.range visible).map fun row =>
      let index := start + row
      let entry := if pane == .actual then actuals[index]?.map fun record =>
          (descriptionText record, actualQuantity record)
        else scheduled[index]?.map fun record => (scheduledShape record, scheduledQuantity record)
      let chosen := index == selected && entry.isSome
      let rowMarker := if chosen then (if focused then " > " else " * ") else "   "
      let line := match entry with
        | none => ""
        | some (label, quantity) => rowMarker ++
            (if tabular then tableRow rowWidth quantityWidth label quantity else fitText rowWidth label)
      .row [span (Loam.Tui.Layout.padRight (width - 2) line) (if chosen && focused then .selected else .normal)]
  let availability := if pane == .actual then "" else match scheduledEvidence snapshot state with
    | .error _ => " [Unavailable]"
    | .ok .unknown => " [Unknown]"
    | .ok (.due _ _) => ""
  let title := (if pane == .actual then "Actual" else "Scheduled") ++ availability ++
    (if focused then " [active]" else "")
  let position := if total > 0 || pane == .actual then positionLabel selected start visible total
    else (if availability == " [Unknown]" then "Unknown" else "Unavailable") ++ "; i details" ++
      (if emptyLines.length > visible then " ↓" else "")
  Loam.Tui.Layout.framedPanel width height title (.column (header ++ rows)) focused (some position)

private def detailPanel (g : Geometry) (snapshot : Snapshot) (state : State) : Widget :=
  let raw := detailRawLines (g.width - 2) snapshot state
  let visible := g.detailHeight - 2
  let offset := Loam.Tui.Scroll.clamp raw.length visible state.detailScroll
  let title := (if state.pane == .actual then "Selected Actual" else "Selected Scheduled") ++
    (if state.detailFocused then " [active]" else "")
  let position := s!"{if visible == 0 then 0 else offset + 1}-{min (offset + visible) raw.length}/{raw.length}" ++
    (if offset > 0 then " ↑" else "") ++ (if offset + visible < raw.length then " ↓" else "")
  Loam.Tui.Layout.framedPanel g.width g.detailHeight title
    (.column ((raw.drop offset).take visible)) state.detailFocused (some position)

/-- Visible-row paging and detail scrolling share the exact geometry used by rendering. -/
def updateForBounds (bounds : Bounds) (snapshot : Snapshot) (rawState : State)
    (event : Event) (repeatCount : Nat := 1) : Step :=
  let state := normalizedForBounds bounds snapshot rawState
  let clean := {state with notice := ""}
  let g := geometry bounds clean
  let directional := event == .previous || event == .next || event == .pageUp ||
    event == .pageDown || event == .home || event == .«end»
  let step := if state.detailFocused && directional then
      let maximum := detailLimit g snapshot clean
      let count := (detailRawLines (g.width - 2) snapshot clean).length
      let visible := g.detailHeight - 2
      let amount := if event == .pageUp || event == .pageDown then max 1 visible else max 1 repeatCount
      let scroll := if event == .home then 0 else if event == .«end» then maximum
        else if event == .previous || event == .pageUp then
          Loam.Tui.Scroll.backward count visible state.detailScroll amount
        else Loam.Tui.Scroll.forward count visible state.detailScroll amount
      {state := {clean with detailScroll := scroll}}
    else
      let selected := match event with
        | .pageUp => movePageUp snapshot state (max 1 (listCapacity g.listHeight))
        | .pageDown => movePageDown snapshot state (max 1 (listCapacity g.listHeight))
        | .previous => if repeatCount > 1 then movePageUp snapshot state repeatCount else (update snapshot state event).state
        | .next => if repeatCount > 1 then movePageDown snapshot state repeatCount else (update snapshot state event).state
        | .home | .«end» => (update snapshot state event).state
        | _ => state
      if directional then
        {state := if selected.actualRow != state.actualRow || selected.scheduledRow != state.scheduledRow then
          {selected with detailScroll := 0} else selected}
      else update snapshot state event
  {step with state := normalizedForBounds bounds snapshot step.state}

/-- One-date projection and local UI intents; all authoritative reads/writes stay shared. -/
def view (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let state := normalizedForBounds bounds snapshot rawState
  let g := geometry bounds state
  let context :=
    [plainLine " Household Day Workspace",
     .row [span " Focus: " .muted, span state.focusDate,
       span (if g.width ≥ 79 then "   Known through: " else "  Through: ") .muted, span snapshot.actual.today]]
  let lists := if g.detailOnly then [] else if g.wide then
      let leftWidth := (g.width - 1) / 2
      Loam.Tui.Layout.sideBySide g.listHeight leftWidth (g.width - 1 - leftWidth)
        (listPanel leftWidth g.listHeight .actual snapshot state)
        (listPanel (g.width - 1 - leftWidth) g.listHeight .scheduled snapshot state) " "
    else widgetRows (listPanel g.width g.listHeight state.pane snapshot state)
  let details := if g.detailHeight == 0 then [] else
    (if g.detailOnly then [] else [blankLine]) ++ widgetRows (detailPanel g snapshot state)
  let body := context.take g.contextRows ++ lists ++ details
  .column ((Loam.Tui.Layout.fitWithFooter bounds body (footer bounds state)).map fun row =>
    .row ((Loam.Tui.Layout.clipCells g.width row.lines.flatten).map fun cell =>
      span (String.singleton cell.glyph) cell.style))

end Loam.Tui.SelectedDay