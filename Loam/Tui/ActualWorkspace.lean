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

/-- Re-clamp only local cursor coordinates after canonical evidence is reloaded. -/
def refreshed (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot { state with notice := "" }

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

private def moveNext (snapshot : Snapshot) (state : State) : State :=
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
      { state with detailScroll := state.detailScroll + 1, notice := "" }

private def movePageUp (snapshot : Snapshot) (state : State) (pageSize : Nat := 10) : State :=
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

private def movePageDown (snapshot : Snapshot) (state : State) (pageSize : Nat := 10) : State :=
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
      { state with detailScroll := state.detailScroll + pageSize, notice := "" }

private def moveHome (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci => clampState snapshot { state with locusRow := 0, transactionRow := 0, detailScroll := 0, notice := "" }
  | .transactions => { state with transactionRow := 0, detailScroll := 0, notice := "" }
  | .details => { state with detailScroll := 0, notice := "" }

private def moveEnd (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      clampState snapshot { state with locusRow := count, transactionRow := 0, detailScroll := 0, notice := "" }
  | .transactions =>
      let count := (visibleRecords snapshot state).length
      let row := if count == 0 then 0 else count - 1
      { state with transactionRow := row, detailScroll := 0, notice := "" }
  | .details =>
      { state with detailScroll := state.detailScroll + 20, notice := "" }

private def cycleFilter (snapshot : Snapshot) (state : State) : State :=
  let scope := match state.scope with
    | .focusDay => Scope.allCurrent
    | .allCurrent => Scope.focusDay
  clampState snapshot { state with scope := scope, locusRow := 0, transactionRow := 0, notice := "" }

private def cycleOrder (snapshot : Snapshot) (state : State) : State :=
  let order := match state.order with
    | .asc => SortOrder.desc
    | .desc => SortOrder.asc
  clampState snapshot { state with order := order, transactionRow := 0, notice := "" }


private def beginSearch (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot {
    state with
      scope := .allCurrent
      pane := .transactions
      locusRow := 0
      transactionRow := 0
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
      notice := ""
  }

def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := movePrevious snapshot state }
  | .next => { state := moveNext snapshot state }
  | .pageUp => { state := movePageUp snapshot state }
  | .pageDown => { state := movePageDown snapshot state }
  | .home => { state := moveHome snapshot state }
  | .«end» => { state := moveEnd snapshot state }
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
      let cleared := { resetRow with notice := "" }
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
  | .other => { state }

/-- Update workspace state, optionally scaling directional navigation by repeat count. -/
def updateWithRepeat (snapshot : Snapshot) (state : State) (event : Event) (repeatCount : Nat := 1) : Step :=
  if repeatCount <= 1 then update snapshot state event
  else
    match event with
    | .previous => { state := movePageUp snapshot state repeatCount }
    | .next => { state := movePageDown snapshot state repeatCount }
    | other => update snapshot state other

private def fit (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padRight width text

private def displayLocus (state : State) (token : String) : String :=
  let label := Loam.LocusCatalog.labelForToken state.locusMetadata token
  if label == token then token else label ++ " [" ++ token ++ "]"

private def scopeText (snapshot : Snapshot) (state : State) : String :=
  match state.scope with
  | .focusDay => "Focus Day (" ++ state.focusDate ++ ")"
  | .allCurrent => "All Current (known through " ++ snapshot.actual.today ++ ")"

private def currentLocusName (snapshot : Snapshot) (state : State) : String :=
  match selectedLocus? snapshot state with
  | none => "All loci"
  | some token => displayLocus state token

private def positiveSummary (record : ReviewRecord) : String :=
  match record.event.effects.find? (fun effect => 0 < effect.quantity.quanta) with
  | some effect => toString effect.quantity.quanta ++ " " ++ effect.measure.token
  | none =>
      match record.event.effects.head? with
      | some effect => toString effect.quantity.quanta ++ " " ++ effect.measure.token
      | none => "0"

private def txSummary (record : ReviewRecord) : String :=
  let description :=
    if record.description.isEmpty then "(no description)"
    else Loam.ActualReview.displayText record.description
  record.date.getD "date unknown" ++ "  " ++ positiveSummary record ++ "  " ++ description

private def paneWindowStart (selected visibleRows : Nat) : Nat :=
  Loam.Tui.Layout.trailingWindowStart selected (max 1 visibleRows)

private def locusLabel (state : State) (loci : List String) (row : Nat) : Option String :=
  if row = 0 then some "[All loci]"
  else loci[row - 1]?.map (displayLocus state)

private def listPanel
    (state : State) (records : Array ReviewRecord) (loci : List String)
    (pane : Pane) (width height : Nat) (title : String) : Widget :=
  let selected := if pane == .loci then state.locusRow else state.transactionRow
  let rows := height - 2
  let start := paneWindowStart selected rows
  let content := (List.range rows).map fun row =>
    let index := start + row
    let label := if pane == .loci then locusLabel state loci index
      else records[index]?.map txSummary
    let isSelected := index == selected && label.isSome
    let active := pane == state.pane
    let marker := if isSelected then (if active then " > " else " * ") else "   "
    let text := match label with
      | some text => marker ++ text
      | none => if row == 0 && pane == .transactions then " (no matching Actual records)" else ""
    .row [span (fit (width - 2) text) (if isSelected && active then .selected else .normal)]
  Loam.Tui.Layout.framedPanel width height title (.column content) (pane == state.pane)

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
  let effectLine := fun (effect : Loam.Core.Effect) =>
    let amount := toString effect.quantity.quanta ++ " " ++ effect.measure.token
    let labelWidth := width - Loam.Tui.Layout.displayWidth amount - 3
    plainLine (" " ++ fit labelWidth (displayLocus state effect.locus.token) ++ "  " ++ amount)
  match record? with
  | none =>
      [ plainLine " Selected Actual Details:"
      , mutedLine "   (no Actual selected)"
      ]
  | some record =>
      let effects := record.event.effects
      let renderedEffects : List Widget := effects.map effectLine
      [ plainLine " Selected Actual Details:"
      , plainLine (" Date: " ++ record.date.getD "date unknown")
      , plainLine (" " ++ if record.description.isEmpty then "(no description)" else Loam.ActualReview.displayText record.description)
      , plainLine (" ID: " ++ record.event.id.token)
      , plainLine " Status: Current"
      , plainLine " Effects:"
      ] ++ renderedEffects

private def fixedDetailLines
    (state : State) (record? : Option ReviewRecord) (capacity : Nat)
    (width : Nat := 80) : List Widget :=
  let allLines := detailRawLines state record? width
  let total := allLines.length
  let maxScroll := if total > capacity then total - capacity else 0
  let scroll := min state.detailScroll maxScroll
  let visibleBase := (allLines.drop scroll).take capacity
  let padding := capacity - visibleBase.length
  visibleBase ++ List.replicate padding blankLine

def detailLines (snapshot : Snapshot) (state : State) : List Widget :=
  fixedDetailLines state (selectedRecord? snapshot state) 8

private def detailHasMore
    (state : State) (record? : Option ReviewRecord) (capacity : Nat)
    (width : Nat := 80) : Bool :=
  let allLines := detailRawLines state record? width
  let total := allLines.length
  let maxScroll := if total > capacity then total - capacity else 0
  let scroll := min state.detailScroll maxScroll
  total > scroll + capacity

private def footer (bounds : Bounds) (state : State) : List Widget :=
  if state.searchEditing then
    [ mutedLine "Search input: type text   Backspace delete   Enter keep   Esc clear"
    , mutedLine "Matches update live across all current Actual evidence."
    ]
  else if state.pane == .details then
    [ mutedLine "[j/k] scroll details  [h/l] pane  [Esc/i] return to Actuals"
    , mutedLine "[Enter] open selected  [n] new  [q] back to Home"
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
  let writable := Loam.Tui.Layout.contentWidth bounds
  let leftWidth := max 34 (writable * 35 / 100)
  let rightWidth := writable - leftWidth - 1
  let leftHeader :=
    "Loci" ++ (if state.pane == .loci then " [active]" else "") ++ s!" ({lociCount})"
  let orderTag := match state.order with
    | .asc => "asc"
    | .desc => "desc"
  let rightHeader :=
    "Actuals" ++ (if state.pane == .transactions then " [active]" else "") ++
      s!" ({txCount}, {orderTag})"
  let searchLine :=
    if state.searchQuery.isEmpty && !state.searchEditing then []
    else
      let cursor := if state.searchEditing then "_" else ""
      [plainLine (Loam.Tui.Layout.clip writable
        (" Search: /" ++ state.searchQuery ++ cursor))]
  let selectedRecord := recordsArr[state.transactionRow]?
  let footerLines := (footer bounds state).take (bounds.height - 1)
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length
  let header :=
    [ plainLine " Household Actuals Workspace"
    , mutedLine (" Horizon: " ++ snapshot.actual.today ++ "  |  " ++ scopeText snapshot state)
    , mutedLine (" Locus: " ++ currentLocusName snapshot state ++ "  |  Order: " ++ orderText state)
    ]
  -- Tiny terminals retain a list row before spending space on context or details.
  let context := header.take (if bodyCapacity >= 9 then 3 else min 1 (bodyCapacity - 3))
  let search := searchLine.take (bodyCapacity - context.length - 3)
  let notice := if state.notice.isEmpty then [] else
    [plainLine state.notice].take (bodyCapacity - context.length - search.length - 3)
  let panelHeight := bodyCapacity - context.length - search.length - notice.length
  let wide := writable >= 98 && panelHeight >= 16
  let detailHeight := if panelHeight >= 16 then detailCapacityForBounds bounds + 1 else 0
  let detailPanel := fun width =>
    let isFocused := state.pane == .details
    let lines := fixedDetailLines state selectedRecord (detailHeight - 1) (width - 2)
    let hasMore := detailHasMore state selectedRecord (detailHeight - 1) (width - 2)
    let canScrollUp := state.detailScroll > 0
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
    let title := "Selected Actual Details:" ++ (if isFocused then " [active]" else "")
    Loam.Tui.Layout.framedPanel width detailHeight title
      (.column (lines.drop 1)) isFocused bottomLabel
  let panels :=
    if wide then
      let left : Widget := .column [
        listPanel state recordsArr loci .loci leftWidth (panelHeight - detailHeight) leftHeader,
        detailPanel leftWidth]
      joinPanels left (listPanel state recordsArr loci .transactions rightWidth panelHeight rightHeader)
    else
      let title := if state.pane == .loci then leftHeader else rightHeader
      [listPanel state recordsArr loci state.pane writable (panelHeight - detailHeight) title] ++
        (if detailHeight > 0 then [detailPanel writable] else [])
  -- Flatten before footer fitting: a panel is many physical terminal rows.
  let body := (Widget.column (context ++ search ++ panels ++ notice)).lines.map fun cells =>
    .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)
  let fitted := Loam.Tui.Layout.fitWithFooter bounds body footerLines
  .column (fitted.map fun row =>
    .column (row.lines.map fun cells =>
      .row ((Loam.Tui.Layout.clipCells writable cells).map fun cell =>
        span (String.singleton cell.glyph) cell.style)))

end Loam.Tui.ActualWorkspace
