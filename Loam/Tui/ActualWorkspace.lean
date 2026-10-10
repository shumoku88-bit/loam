import Loam.Presentation.LocusCatalog
import Loam.Tui.Layout
import Loam.Tui.Main
import Loam.Tui.Terminal

namespace Loam.Tui.ActualWorkspace

open Loam.Tui.Kernel
open Loam.Tui.Main

set_option autoImplicit false

inductive Scope where
  | focusDay
  | allCurrent
  deriving Repr, DecidableEq, BEq

inductive SortOrder where
  | asc
  | desc
  deriving Repr, DecidableEq, BEq

inductive Pane where
  | loci
  | transactions
  | details
  deriving Repr, DecidableEq, BEq

structure State where
  focusDate : String
  scope : Scope := .focusDay
  order : SortOrder := .desc
  pane : Pane := .transactions
  locusRow : Nat := 0
  transactionRow : Nat := 0
  detailScroll : Nat := 0
  searchQuery : String := ""
  searchEditing : Bool := false
  notice : String := ""
  /-- Presentation-only dictionary may include read-only historical identities. -/
  locusMetadata : List Loam.LocusCatalog.Metadata := []
  /-- Exact display conventions only; quantities and Measure identities stay unchanged. -/
  measurePresentation : List Loam.MeasurePresentation.Metadata := []
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
  | cyclePane
  | cyclePaneBack
  | toggleDetails
  | cycleFilter
  | cycleOrder
  | beginSearch
  | searchInput (char : Char)
  | searchPaste (text : String)
  | searchBackspace
  | acceptSearch
  | cancelSearch
  | openSelected
  | recordNew
  | back
  | redraw
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | openSelected
  | recordNew
  | back
  | redraw
  deriving Repr, DecidableEq, BEq

structure Step where
  state : State
  command : Command := .stay


def initial (focusDate : String) : State :=
  { focusDate := focusDate }

/-- Attach human-facing history metadata without changing filtering identity or write admission. -/
def withMetadata (state : State) (metadata : List Loam.LocusCatalog.Metadata) : State :=
  { state with locusMetadata := metadata }

def withMeasurePresentation
    (state : State) (metadata : List Loam.MeasurePresentation.Metadata) : State :=
  { state with measurePresentation := metadata }

private def currentRecords (snapshot : Snapshot) : List ReviewRecord :=
  snapshot.actual.allRecords.filter (fun record => record.isCurrent)

/-- Scope is presentation-only. No retained chronology or new authority is inferred. -/
def recordsForScope (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  match state.scope with
  | .focusDay => recordsForDay snapshot state.focusDate
  | .allCurrent => currentRecords snapshot

/-- Stable Locus tokens visible in the current Actual scope, in first representation appearance. -/
def lociForScope (snapshot : Snapshot) (state : State) : List String :=
  (recordsForScope snapshot state).flatMap (fun record =>
    record.event.effects.map (fun effect => effect.locus.token)) |>.eraseDups


def selectedLocus? (snapshot : Snapshot) (state : State) : Option String :=
  if state.locusRow = 0 then none
  else (lociForScope snapshot state)[state.locusRow - 1]?


private def containsInsensitive (needle haystack : String) : Bool :=
  if needle.isEmpty then true
  else (haystack.toLower.splitOn needle.toLower).length > 1

private def matchesSearch (state : State) (record : ReviewRecord) : Bool :=
  if state.searchQuery.isEmpty then true
  else
    Loam.ActualReview.containsText state.searchQuery record ||
    record.event.effects.any fun effect =>
      containsInsensitive state.searchQuery
        (Loam.LocusCatalog.labelForToken state.locusMetadata effect.locus.token)

def visibleRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  let byLocus :=
    match selectedLocus? snapshot state with
    | none => recordsForScope snapshot state
    | some locus =>
        (recordsForScope snapshot state).filter fun record =>
          record.event.effects.any fun effect => effect.locus.token == locus
  let base := byLocus.filter (matchesSearch state)
  base.mergeSort fun a b =>
    match a.date, b.date with
    | some aDate, some bDate =>
        if aDate == bDate then
          match state.order with
          | .asc => b.event.id.token <= a.event.id.token
          | .desc => a.event.id.token <= b.event.id.token
        else
          match state.order with
          | .asc => aDate < bDate
          | .desc => aDate > bDate
    | some _, none => true
    | none, some _ => false
    | none, none =>
        match state.order with
        | .asc => b.event.id.token <= a.event.id.token
        | .desc => a.event.id.token <= b.event.id.token


def selectedRecord? (snapshot : Snapshot) (state : State) : Option ReviewRecord :=
  (visibleRecords snapshot state)[state.transactionRow]?

def clampStateWithCounts (lociCount txCount : Nat) (state : State) : State :=
  let locusRow := min state.locusRow lociCount
  let withLocus := { state with locusRow := locusRow }
  let transactionRow :=
    if txCount = 0 then 0 else min withLocus.transactionRow (txCount - 1)
  { withLocus with transactionRow := transactionRow }

private def clampState (snapshot : Snapshot) (state : State) : State :=
  let lociCount := (lociForScope snapshot state).length
  let withLocus := { state with locusRow := min state.locusRow lociCount }
  let txCount := (visibleRecords snapshot withLocus).length
  clampStateWithCounts lociCount txCount withLocus

/-- Re-clamp local cursors and restart Details after canonical evidence is reloaded. -/
def refreshed (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot { state with detailScroll := 0, notice := "" }

/-- Return from a single Event without resetting search/order/focus or an unchanged preview.
    Re-anchor filters and selection by token; otherwise keep the nearest visible row. -/
def returnedFromDetail (before after : Snapshot) (state : State) : State :=
  let locus := selectedLocus? before state
  let loci := lociForScope after state
  let locusRow := match locus with
    | none => 0
    | some token => (loci.findIdx? (· == token)).map (· + 1) |>.getD 0
  let base := { state with
    locusRow := locusRow
    notice := if locus.isSome && locusRow == 0 then
      "Selected Locus is no longer in scope; showing all loci." else "" }
  let target := (selectedRecord? before state).map (·.event.id)
  let row := (visibleRecords after base).findIdx? fun record => some record.event.id == target
  match row with
  | some transactionRow => {base with transactionRow}
  | none =>
      let fresh := refreshed after base
      {fresh with notice := "Selected Event no longer matches this list; selection moved to the nearest row."}

private def movePrevious (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci =>
      if state.locusRow = 0 then { state with notice := "No previous Locus row." }
      else clampState snapshot { state with locusRow := state.locusRow - 1, transactionRow := 0, detailScroll := 0, notice := "" }
  | .transactions =>
      if state.transactionRow = 0 then { state with notice := "No previous Actual row." }
      else { state with transactionRow := state.transactionRow - 1, detailScroll := 0, notice := "" }
  | .details =>
      if state.detailScroll = 0 then { state with notice := "Top of Details." }
      else { state with detailScroll := state.detailScroll - 1, notice := "" }

private def moveNext (snapshot : Snapshot) (state : State) (detailEnd : Nat) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      if state.locusRow < count then
        clampState snapshot { state with locusRow := state.locusRow + 1, transactionRow := 0, detailScroll := 0, notice := "" }
      else
        { state with notice := "No next Locus row." }
  | .transactions =>
      let count := (visibleRecords snapshot state).length
      if state.transactionRow + 1 < count then
        { state with transactionRow := state.transactionRow + 1, detailScroll := 0, notice := "" }
      else
        { state with notice := "No next Actual row." }
  | .details =>
      if state.detailScroll >= detailEnd then { state with notice := "End of Details." }
      else { state with detailScroll := state.detailScroll + 1, notice := "" }

private def movePageUp (snapshot : Snapshot) (state : State) (pageSize : Nat) : State :=
  match state.pane with
  | .loci =>
      if state.locusRow == 0 then { state with notice := "Top of Locus list." }
      else clampState snapshot { state with locusRow := state.locusRow - min state.locusRow pageSize, transactionRow := 0, detailScroll := 0, notice := "" }
  | .transactions =>
      if state.transactionRow == 0 then { state with notice := "Top of Actual list." }
      else { state with transactionRow := state.transactionRow - min state.transactionRow pageSize, detailScroll := 0, notice := "" }
  | .details =>
      if state.detailScroll == 0 then { state with notice := "Top of Details." }
      else { state with detailScroll := state.detailScroll - min state.detailScroll pageSize, notice := "" }

private def movePageDown
    (snapshot : Snapshot) (state : State) (pageSize detailEnd : Nat) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      if state.locusRow >= count then { state with notice := "End of Locus list." }
      else clampState snapshot { state with locusRow := min count (state.locusRow + pageSize), transactionRow := 0, detailScroll := 0, notice := "" }
  | .transactions =>
      let count := (visibleRecords snapshot state).length
      if count == 0 || state.transactionRow + 1 >= count then { state with notice := "End of Actual list." }
      else { state with transactionRow := min (count - 1) (state.transactionRow + pageSize), detailScroll := 0, notice := "" }
  | .details =>
      if state.detailScroll >= detailEnd then { state with notice := "End of Details." }
      else { state with detailScroll := min detailEnd (state.detailScroll + pageSize), notice := "" }

private def moveHome (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci => clampState snapshot { state with locusRow := 0, transactionRow := 0, detailScroll := 0, notice := "" }
  | .transactions => { state with transactionRow := 0, detailScroll := 0, notice := "" }
  | .details => { state with detailScroll := 0, notice := "" }

private def moveEnd (snapshot : Snapshot) (state : State) (detailEnd : Nat) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      clampState snapshot { state with locusRow := count, transactionRow := 0, detailScroll := 0, notice := "" }
  | .transactions =>
      let count := (visibleRecords snapshot state).length
      let row := if count == 0 then 0 else count - 1
      { state with transactionRow := row, detailScroll := 0, notice := "" }
  | .details =>
      { state with detailScroll := detailEnd, notice := "" }

private def cycleFilter (snapshot : Snapshot) (state : State) : State :=
  let scope := match state.scope with
    | .focusDay => Scope.allCurrent
    | .allCurrent => Scope.focusDay
  clampState snapshot { state with scope := scope, locusRow := 0, transactionRow := 0, detailScroll := 0, notice := "" }

private def cycleOrder (snapshot : Snapshot) (state : State) : State :=
  let order := match state.order with
    | .asc => SortOrder.desc
    | .desc => SortOrder.asc
  clampState snapshot { state with order := order, transactionRow := 0, detailScroll := 0, notice := "" }


private def beginSearch (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot {
    state with
      scope := .allCurrent
      pane := .transactions
      locusRow := 0
      transactionRow := 0
      detailScroll := 0
      searchQuery := ""
      searchEditing := true
      notice := ""
  }

private def editSearch
    (snapshot : Snapshot) (state : State) (edit : String → String) : State :=
  clampState snapshot {
    state with
      searchQuery := edit state.searchQuery
      transactionRow := 0
      detailScroll := 0
      notice := ""
  }

private def updateIntent (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .focusLeft =>
      let prevPane := match state.pane with
        | .loci => Pane.details
        | .transactions => Pane.loci
        | .details => Pane.transactions
      { state := { state with pane := prevPane, notice := "" } }
  | .focusRight =>
      let nextPane := match state.pane with
        | .loci => Pane.transactions
        | .transactions => Pane.details
        | .details => Pane.loci
      { state := { state with pane := nextPane, notice := "" } }
  | .cyclePane =>
      let nextPane := match state.pane with
        | .loci => Pane.transactions
        | .transactions => Pane.details
        | .details => Pane.loci
      { state := { state with pane := nextPane, notice := "" } }
  | .cyclePaneBack =>
      let prevPane := match state.pane with
        | .loci => Pane.details
        | .transactions => Pane.loci
        | .details => Pane.transactions
      { state := { state with pane := prevPane, notice := "" } }
  | .toggleDetails =>
      let nextPane := match state.pane with
        | .details => Pane.transactions
        | .loci | .transactions => Pane.details
      { state := { state with pane := nextPane, notice := "" } }
  | .cycleFilter => { state := cycleFilter snapshot state }
  | .cycleOrder => { state := cycleOrder snapshot state }
  | .beginSearch => { state := beginSearch snapshot state }
  | .searchInput char =>
      if state.searchEditing then
        { state := editSearch snapshot state (fun text => text.push char) }
      else
        { state }
  | .searchPaste text =>
      if state.searchEditing then
        let clean := Loam.Tui.Terminal.singleLinePaste text
        { state := editSearch snapshot state (fun curr => curr ++ clean) }
      else
        { state }
  | .searchBackspace =>
      if state.searchEditing then
        { state := editSearch snapshot state
            (fun text => Loam.Tui.Terminal.backspaceText text) }
      else
        { state }
  | .acceptSearch =>
      if state.searchEditing then
        { state := { state with searchEditing := false, notice := "" } }
      else
        { state }
  | .cancelSearch =>
      let clearedQuery := { state with searchQuery := "" }
      let stopped := { clearedQuery with searchEditing := false }
      let resetRow := { stopped with transactionRow := 0 }
      let cleared := { resetRow with detailScroll := 0, notice := "" }
      { state := clampState snapshot cleared }
  | .openSelected =>
      match state.pane with
      | .transactions =>
          match selectedRecord? snapshot state with
          | some _ => { state, command := .openSelected }
          | none => { state := { state with notice := "No current Actual is selected to open." } }
      | .details =>
          match selectedRecord? snapshot state with
          | some _ => { state, command := .openSelected }
          | none => { state := { state with notice := "No current Actual is selected to open." } }
      | .loci =>
          { state := { state with notice := "Move to the Actuals pane before opening a record." } }
  | .recordNew => { state, command := .recordNew }
  | .back =>
      if state.pane == .details then
        { state := { state with pane := .transactions, notice := "" } }
      else
        { state, command := .back }
  | .redraw => { state, command := .redraw }
  -- Directional events are handled by the bounds-aware entrance below.
  | .previous | .next | .pageUp | .pageDown | .home | .«end» | .other => { state }

private def fit (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padRight width text

private def displayLocus (state : State) (token : String) : String :=
  let label := Loam.LocusCatalog.labelForToken state.locusMetadata token
  if label == token then token else label ++ " [" ++ token ++ "]"

private def scopeText (state : State) : String :=
  match state.scope with
  | .focusDay => "Focus Day (" ++ state.focusDate ++ ")"
  | .allCurrent => "All Current"

private def currentLocusName (snapshot : Snapshot) (state : State) : String :=
  match selectedLocus? snapshot state with
  | none => "All loci"
  | some token => displayLocus state token

private def effectAmount (state : State) (effect : Loam.Core.Effect) : String :=
  Loam.MeasurePresentation.formatGroupedQuanta state.measurePresentation
    effect.measure effect.quantity.quanta ++ " " ++ effect.measure.token

/-- A simple receiving amount, never a sum across split Effects or Measures. -/
private def amountSummary (state : State) (record : ReviewRecord) : String :=
  let effects := record.event.effects
  let measures := (effects.map (fun effect => effect.measure.token)).eraseDups
  let positive := effects.filter (fun effect => 0 < effect.quantity.quanta)
  let negative := effects.filter (fun effect => effect.quantity.quanta < 0)
  if measures.length > 1 then s!"multi ({measures.length})"
  else if positive.length > 1 || negative.length > 1 then "split"
  else
    match positive.head? with
    | some effect => effectAmount state effect
    | none =>
        match effects with
        | [effect] => effectAmount state effect
        | [] => "—"
        | _ => "see details"

private def descriptionText (record : ReviewRecord) : String :=
  if record.description.isEmpty then "(no description)"
  else Loam.ActualReview.displayText record.description

/-- Ellipsis makes description truncation visible without splitting wide glyphs. -/
private def fitDescription (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text <= width then fit width text
  else fit width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

/-- Date and amount columns stay fixed while Description receives the remaining space. -/
private def tableRow
    (width amountWidth : Nat) (date description amount : String) : String :=
  let descriptionWidth := width - 10 - amountWidth - 4
  fit 10 date ++ "  " ++ fitDescription descriptionWidth description ++ "  " ++
    Loam.Tui.Layout.padLeft amountWidth
      (if Loam.Tui.Layout.displayWidth amount <= amountWidth then amount else "see details")

private def paneWindowStart (selected visibleRows : Nat) : Nat :=
  Loam.Tui.Layout.trailingWindowStart selected (max 1 visibleRows)

private def locusLabel (state : State) (loci : List String) (row : Nat) : Option String :=
  if row = 0 then some "[All loci]"
  else loci[row - 1]?.map (displayLocus state)

private def listCapacity (pane : Pane) (height : Nat) : Nat :=
  height - 2 - (if pane == .loci || height < 4 then 0 else 1)

private def listPanel
    (state : State) (records : Array ReviewRecord) (loci : List String)
    (pane : Pane) (width height : Nat) (title : String) : Widget :=
  let selected := if pane == .loci then state.locusRow else state.transactionRow
  let rowWidth := width - 5 -- two borders and the three-column selection marker
  let tabular := rowWidth >= 40
  let amountWidth := if pane == .loci then 0 else
    min 22 (max 12 (records.foldl
      (fun widest record => max widest (Loam.Tui.Layout.displayWidth (amountSummary state record))) 0))
  let amountWidth := min amountWidth (rowWidth - 26)
  let columnHeader : List Widget :=
    if pane == .loci || height < 4 then []
    else [mutedLine ("   " ++ (if tabular then
      tableRow rowWidth amountWidth "Date" "Description" "Amount"
      else "Description"))]
  let rows := listCapacity pane height
  let start := paneWindowStart selected rows
  let content := (List.range rows).map fun row =>
    let index := start + row
    let label := if pane == .loci then
        (locusLabel state loci index).map (fitDescription rowWidth)
      else records[index]?.map fun record =>
        if tabular then
          tableRow rowWidth amountWidth (record.date.getD "unknown")
            (descriptionText record) (amountSummary state record)
        else fitDescription rowWidth (descriptionText record)
    let isSelected := index == selected && label.isSome
    let active := pane == state.pane
    let marker := if isSelected then (if active then " > " else " * ") else "   "
    let text := match label with
      | some text => marker ++ text
      | none => if row == 0 && pane == .transactions then " (no matching Actual records)" else ""
    .row [span (fit (width - 2) text) (if isSelected && active then .selected else .normal)]
  let total := if pane == .loci then loci.length + 1 else records.size
  let position := if total == 0 then "0/0" else s!"{selected + 1}/{total}"
  let remaining := if start + rows < total then " ▼" else ""
  Loam.Tui.Layout.framedPanel width height title (.column (columnHeader ++ content))
    (pane == state.pane) (some (position ++ remaining))

/-- Frames already own their borders; leave just one blank column between them. -/
private def joinPanels (left right : Widget) : List Widget :=
  left.lines.zipWith (fun l r =>
    .row ((l.map fun c => span (String.singleton c.glyph) c.style) ++ [span " "] ++
      (r.map fun c => span (String.singleton c.glyph) c.style))) right.lines

/--
Stable details presentation. By fixing the allocated rows across records,
vertical geometry (divider position and pane rows) remains stationary during
scrolling, preventing whole-screen layout jitter and dirty-diff desynchronization.
-/
def detailCapacityForBounds (bounds : Bounds) : Nat :=
  if bounds.height ≥ 48 then 12 else if bounds.height ≥ 36 then 10 else 8

private def detailRawLines
    (state : State) (record? : Option ReviewRecord)
    (width : Nat := 80) : List Widget :=
  let wrapped : String → Style → List Widget := fun text style =>
    (Loam.Tui.Layout.wrapColumns (width - 1) text).map fun line =>
      .row [span " ", span line style]
  let effectLines : Loam.Core.Effect → List Widget := fun effect =>
    let amount := effectAmount state effect
    let label := displayLocus state effect.locus.token
    let amountWidth := Loam.Tui.Layout.displayWidth amount
    if amountWidth + 4 <= width then
      let labelWidth := width - amountWidth - 3
      [plainLine (" " ++ fitDescription labelWidth label ++ "  " ++ amount)]
    else
      -- The complete value remains scrollable, never a silently clipped number.
      wrapped label .normal ++ wrapped "Amount (wrapped):" .muted ++ wrapped amount .normal
  match record? with
  | none => wrapped "(no Actual selected)" .muted
  | some record =>
      let effects := record.event.effects
      wrapped ("Date: " ++ record.date.getD "date unknown") .muted ++
        wrapped s!"Effects ({effects.length}):" .muted ++
        (if effects.isEmpty then wrapped "(no Effects)" .muted
         else effects.flatMap effectLines) ++
        [blankLine] ++
        wrapped (descriptionText record) .normal ++
        wrapped ("ID: " ++ record.event.id.token) .muted

private def scrollLimit (rowCount capacity : Nat) : Nat :=
  if capacity == 0 then 0 else rowCount - capacity

/-- One geometry-derived window shared by content and overflow indicators. -/
private structure DetailWindow where
  lines : List Widget
  scroll : Nat
  maxScroll : Nat

private def detailWindow
    (state : State) (record? : Option ReviewRecord) (capacity width : Nat) : DetailWindow :=
  let allLines := detailRawLines state record? width
  let maxScroll := scrollLimit allLines.length capacity
  let scroll := min state.detailScroll maxScroll
  let visible := (allLines.drop scroll).take capacity
  { lines := visible ++ List.replicate (capacity - visible.length) blankLine
    scroll, maxScroll }

def detailLines (snapshot : Snapshot) (state : State) : List Widget :=
  (detailWindow state (selectedRecord? snapshot state) 8 80).lines

private def footer (bounds : Bounds) (state : State) : List Widget :=
  if state.searchEditing then
    [ mutedLine "Search input: type text   Backspace delete   Enter keep   Esc clear"
    , mutedLine "Matches update live across all current Actual evidence."
    ]
  else if state.pane == .details then
    [ mutedLine "[j/k] scroll details  [h/l] pane  [Esc/i] return to Actuals"
    , mutedLine "[Enter] open selected  [n] new  [q] back"
    ]
  else
    let detailedRow1 := "[j/k] select  [h/l] pane  [Tab] cycle  [i] details  [f] filter  [s] sort  [/] search"
    if Loam.Tui.Layout.displayWidth detailedRow1 ≤ Loam.Tui.Layout.contentWidth bounds then
      [ mutedLine detailedRow1
      , mutedLine "[Enter] open selected  [n] new  [q] back"
      ]
    else
      [ mutedLine "[j/k] sel [h/l] pane [Tab] cycle [i] info [f] filter [s] sort [/] search"
      , mutedLine "[Enter] open [n] new [q] back"
      ]

/-- Bounds alone determine pane geometry; search and notices never resize a panel. -/
private structure Geometry where
  writable : Nat
  leftWidth : Nat
  panelHeight : Nat
  detailHeight : Nat
  contextRows : Nat
  statusRows : Nat
  wide : Bool

private def geometryForBounds (bounds : Bounds) : Geometry :=
  let writable := Loam.Tui.Layout.contentWidth bounds
  let footerRows := min 2 (bounds.height - 1)
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerRows
  -- Keep one record row on tiny terminals; reserve quiet status space when it fits.
  let contextRows := if bodyCapacity >= 5 then 2 else if bodyCapacity >= 4 then 1 else 0
  let statusRows := if bodyCapacity >= 7 then 1 else 0
  let panelHeight := bodyCapacity - contextRows - statusRows
  { writable
    leftWidth := min 50 (max 34 (writable * 30 / 100))
    panelHeight
    detailHeight := if panelHeight >= 16 then detailCapacityForBounds bounds + 1 else 0
    contextRows, statusRows
    wide := writable >= 98 && panelHeight >= 16 }

private def Geometry.detailBounds (geometry : Geometry) (pane : Pane) : Bounds :=
  { width := if geometry.wide then geometry.leftWidth else geometry.writable
    height := if geometry.detailHeight > 0 then geometry.detailHeight
      else if pane == .details then geometry.panelHeight else 0 }

private def Geometry.listHeight (geometry : Geometry) (pane : Pane) : Nat :=
  if geometry.wide && pane == .transactions then geometry.panelHeight
  else geometry.panelHeight - geometry.detailHeight

private def Geometry.pageSize (geometry : Geometry) (pane : Pane) : Nat :=
  max 1 (match pane with
    | .details => (geometry.detailBounds pane).height - 2
    | other => listCapacity other (geometry.listHeight other))

private def detailScrollLimit (geometry : Geometry) (snapshot : Snapshot) (state : State) : Nat :=
  let bounds := geometry.detailBounds state.pane
  if bounds.width < 3 || bounds.height < 3 then 0
  else scrollLimit (detailRawLines state (selectedRecord? snapshot state) (bounds.width - 2)).length
    (bounds.height - 2)

/-- Resize normalization changes only the local Details offset, never selected evidence. -/
def normalizedForBounds (bounds : Bounds) (snapshot : Snapshot) (state : State) : State :=
  if state.detailScroll == 0 then state
  else
    let maximum := detailScrollLimit (geometryForBounds bounds) snapshot state
    { state with detailScroll := min state.detailScroll maximum }

/-- Navigation uses the same pane dimensions and wrapped rows as rendering. -/
def updateWithRepeat (bounds : Bounds) (snapshot : Snapshot) (rawState : State)
    (event : Event) (repeatCount : Nat := 1) : Step :=
  let geometry := geometryForBounds bounds
  let detailEnd := if rawState.pane == .details then detailScrollLimit geometry snapshot rawState else 0
  let state := if rawState.pane == .details then
      { rawState with detailScroll := min rawState.detailScroll detailEnd }
    else rawState
  let step := match event with
    | .previous =>
        if repeatCount <= 1 then { state := movePrevious snapshot state }
        else { state := movePageUp snapshot state repeatCount }
    | .next =>
        if repeatCount <= 1 then { state := moveNext snapshot state detailEnd }
        else { state := movePageDown snapshot state repeatCount detailEnd }
    | .pageUp => { state := movePageUp snapshot state (geometry.pageSize state.pane) }
    | .pageDown => { state := movePageDown snapshot state (geometry.pageSize state.pane) detailEnd }
    | .home => { state := moveHome snapshot state }
    | .«end» => { state := moveEnd snapshot state detailEnd }
    | intent => updateIntent snapshot state intent
  if state.pane != .details && step.state.pane == .details then
    { step with state := normalizedForBounds bounds snapshot step.state }
  else step

def update (bounds : Bounds) (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  updateWithRepeat bounds snapshot state event

private def orderText (state : State) : String :=
  match state.order with
  | .asc => "oldest first"
  | .desc => "newest first"

/--
Production Actual workspace over the shared ActualReview answer. Stable tokens
still own filtering/selection identity; catalog labels alter presentation only.
-/
def view (bounds : Bounds) (snapshot : Snapshot) (rawState : State) : Widget :=
  let loci := lociForScope snapshot rawState
  let lociCount := loci.length
  let withLocus := { rawState with locusRow := min rawState.locusRow lociCount }
  let records := visibleRecords snapshot withLocus
  let recordsArr := records.toArray
  let txCount := recordsArr.size
  let state := clampStateWithCounts lociCount txCount withLocus
  let geometry := geometryForBounds bounds
  let writable := geometry.writable
  let leftWidth := geometry.leftWidth
  let rightWidth := writable - leftWidth - 1
  let leftHeader :=
    "Loci" ++ (if state.pane == .loci then " [active]" else "") ++ s!" ({lociCount})"
  let orderTag := match state.order with
    | .asc => "asc"
    | .desc => "desc"
  let rightHeader :=
    "Actuals" ++ (if state.pane == .transactions then " [active]" else "") ++
      s!" ({txCount}, {orderTag}, {orderText state})"
  let searching := !state.searchQuery.isEmpty || state.searchEditing
  let scopeLine := " " ++ scopeText state ++ "  |  " ++ currentLocusName snapshot state
  let contextLine :=
    if searching then
      let cursor := if state.searchEditing then "_" else ""
      .row [span (" Search: /" ++ state.searchQuery ++ cursor), span ("  |" ++ scopeLine) .muted]
    else mutedLine scopeLine
  let header :=
    [ .row [span " Household Actuals Workspace",
        span ("  |  known through " ++ snapshot.actual.today) .muted]
    , contextLine
    ]
  let context :=
    if geometry.contextRows == 1 && searching then [contextLine]
    else header.take geometry.contextRows
  let baseFooter := (footer bounds state).take (bounds.height - 1)
  let footerLines :=
    if geometry.statusRows == 0 && !state.notice.isEmpty && !baseFooter.isEmpty then
      baseFooter.take (baseFooter.length - 1) ++ [mutedLine state.notice]
    else baseFooter
  let notice := if geometry.statusRows == 0 then [] else
    [if state.notice.isEmpty then blankLine else mutedLine state.notice]
  let selectedRecord := recordsArr[state.transactionRow]?
  let wide := geometry.wide
  let detailHeight := geometry.detailHeight
  let detailBounds := geometry.detailBounds state.pane
  let detailPanel := fun width height =>
    let isFocused := state.pane == .details
    let window := detailWindow state selectedRecord (height - 2) (width - 2)
    let hasMore := window.scroll < window.maxScroll
    let canScrollUp := window.scroll > 0
    let bottomLabel :=
      if isFocused then
        let scrollIndicator :=
          if hasMore && canScrollUp then "▲▼"
          else if hasMore then "▼"
          else if canScrollUp then "▲"
          else ""
        some (if scrollIndicator.isEmpty then "[j/k] scroll  [Esc] back" else s!"[j/k] scroll {scrollIndicator}  [Esc] back")
      else if hasMore then
        some "▼ [i] more"
      else none
    let title := "Details" ++ (if isFocused then " [active]" else "")
    Loam.Tui.Layout.framedPanel width height title
      (.column window.lines) isFocused bottomLabel
  let panels :=
    if wide then
      let left : Widget := .column [
        listPanel state recordsArr loci .loci leftWidth (geometry.listHeight .loci) leftHeader,
        detailPanel detailBounds.width detailBounds.height]
      joinPanels left (listPanel state recordsArr loci .transactions rightWidth
        (geometry.listHeight .transactions) rightHeader)
    else if state.pane == .details && detailHeight == 0 then
      -- Never direct scrolling into an invisible Details region on a low terminal.
      [detailPanel detailBounds.width detailBounds.height]
    else
      let listPane := if state.pane == .loci then Pane.loci else Pane.transactions
      let title := if listPane == .loci then leftHeader else rightHeader
      [listPanel state recordsArr loci listPane writable (geometry.listHeight listPane) title] ++
        (if detailHeight > 0 then [detailPanel detailBounds.width detailBounds.height] else [])
  -- Flatten before footer fitting: a panel is many physical terminal rows.
  let body := (Widget.column (context ++ panels ++ notice)).lines.map fun cells =>
    .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)
  let fitted := Loam.Tui.Layout.fitWithFooter bounds body footerLines
  .column (fitted.map fun row =>
    .column (row.lines.map fun cells =>
      .row ((Loam.Tui.Layout.clipCells writable cells).map fun cell =>
        span (String.singleton cell.glyph) cell.style)))

end Loam.Tui.ActualWorkspace
