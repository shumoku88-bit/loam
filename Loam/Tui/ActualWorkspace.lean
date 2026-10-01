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
  deriving Repr, DecidableEq, BEq

structure State where
  focusDate : String
  scope : Scope := .focusDay
  order : SortOrder := .desc
  pane : Pane := .loci
  locusRow : Nat := 0
  transactionRow : Nat := 0
  searchQuery : String := ""
  searchEditing : Bool := false
  notice : String := ""
  /-- Presentation-only dictionary may include read-only historical identities. -/
  locusMetadata : List Loam.LocusCatalog.Metadata := []
  deriving Repr, DecidableEq

inductive Event where
  | previous
  | next
  | focusLeft
  | focusRight
  | cycleFilter
  | cycleOrder
  | beginSearch
  | searchInput (char : Char)
  | searchBackspace
  | acceptSearch
  | cancelSearch
  | openSelected
  | recordNew
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
  | openSelected
  | recordNew
  | back
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

private def clampState (snapshot : Snapshot) (state : State) : State :=
  let lociCount := (lociForScope snapshot state).length
  let locusRow := min state.locusRow lociCount
  let withLocus := { state with locusRow := locusRow }
  let txCount := (visibleRecords snapshot withLocus).length
  let transactionRow :=
    if txCount = 0 then 0 else min withLocus.transactionRow (txCount - 1)
  { withLocus with transactionRow := transactionRow }

/-- Re-clamp only local cursor coordinates after canonical evidence is reloaded. -/
def refreshed (snapshot : Snapshot) (state : State) : State :=
  clampState snapshot { state with notice := "" }

private def movePrevious (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci =>
      if state.locusRow = 0 then { state with notice := "No previous Locus row." }
      else clampState snapshot { state with locusRow := state.locusRow - 1, transactionRow := 0, notice := "" }
  | .transactions =>
      if state.transactionRow = 0 then { state with notice := "No previous Actual row." }
      else { state with transactionRow := state.transactionRow - 1, notice := "" }

private def moveNext (snapshot : Snapshot) (state : State) : State :=
  match state.pane with
  | .loci =>
      let count := (lociForScope snapshot state).length
      if state.locusRow < count then
        clampState snapshot { state with locusRow := state.locusRow + 1, transactionRow := 0, notice := "" }
      else
        { state with notice := "No next Locus row." }
  | .transactions =>
      let count := (visibleRecords snapshot state).length
      if state.transactionRow + 1 < count then
        { state with transactionRow := state.transactionRow + 1, notice := "" }
      else
        { state with notice := "No next Actual row." }

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
  | .focusLeft => { state := { state with pane := .loci, notice := "" } }
  | .focusRight => { state := { state with pane := .transactions, notice := "" } }
  | .cycleFilter => { state := cycleFilter snapshot state }
  | .cycleOrder => { state := cycleOrder snapshot state }
  | .beginSearch => { state := beginSearch snapshot state }
  | .searchInput char =>
      if state.searchEditing then
        { state := editSearch snapshot state (fun text => text.push char) }
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
      match state.pane, selectedRecord? snapshot state with
      | .transactions, some _ => { state, command := .openSelected }
      | .transactions, none =>
          { state := { state with notice := "No current Actual is selected to open." } }
      | .loci, _ =>
          { state := { state with notice := "Move to the Actuals pane before opening a record." } }
  | .recordNew => { state, command := .recordNew }
  | .back => { state, command := .back }
  | .other => { state }

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def fit (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padRight width text

private def rule (bounds : Bounds) (char : Char) : Widget :=
  plainLine (repeatChar (Loam.Tui.Layout.contentWidth bounds) char)

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

private def locusLabel (snapshot : Snapshot) (state : State) (row : Nat) : Option String :=
  if row = 0 then some "[All loci]"
  else (lociForScope snapshot state)[row - 1]?.map (displayLocus state)

private def paneRow (snapshot : Snapshot) (state : State)
    (leftWidth rightWidth visibleRows row : Nat) : Widget :=
  let locusIndex := paneWindowStart state.locusRow visibleRows + row
  let txIndex := paneWindowStart state.transactionRow visibleRows + row
  let leftPrefix :=
    if locusIndex = state.locusRow then
      if state.pane == .loci then " > " else " * "
    else "   "
  let rightPrefix :=
    if txIndex = state.transactionRow && (visibleRecords snapshot state).length > 0 then
      if state.pane == .transactions then " > " else " * "
    else "   "
  let leftText :=
    match locusLabel snapshot state locusIndex with
    | some label => leftPrefix ++ label
    | none => ""
  let rightText :=
    match (visibleRecords snapshot state)[txIndex]? with
    | some record => rightPrefix ++ txSummary record
    | none => if row = 0 && (visibleRecords snapshot state).isEmpty then " (no matching Actual records)" else ""
  .row [span (fit leftWidth leftText), span " | ", span (fit rightWidth rightText)]

private def detailLines (snapshot : Snapshot) (state : State) : List Widget :=
  match selectedRecord? snapshot state with
  | none =>
      [ plainLine " Selected Actual Details:"
      , mutedLine "   (no Actual selected)"
      ]
  | some record =>
      [ plainLine " Selected Actual Details:"
      , plainLine ("   Date        : " ++ record.date.getD "date unknown")
      , plainLine ("   Description : " ++ if record.description.isEmpty then "(no description)" else Loam.ActualReview.displayText record.description)
      , plainLine ("   Identity    : " ++ record.event.id.token)
      , plainLine "   Status      : Current"
      , plainLine "   Effects:"
      ] ++
      (record.event.effects.map fun effect =>
        plainLine ("     " ++ fit 38 (displayLocus state effect.locus.token) ++ " " ++
          toString effect.quantity.quanta ++ " " ++ effect.measure.token))

private def footer (bounds : Bounds) (state : State) : List Widget :=
  if state.searchEditing then
    [ mutedLine "Search input: type text   Backspace delete   Enter keep   Esc clear"
    , mutedLine "Matches update live across all current Actual evidence."
    ]
  else
    let detailedRow1 := "[j/k] select  [h/l] pane  [f] filter  [s] sort  [/] search"
    if Loam.Tui.Layout.displayWidth detailedRow1 ≤ Loam.Tui.Layout.contentWidth bounds then
      [ mutedLine detailedRow1
      , mutedLine "[Enter] open selected  [n] new  [q] back"
      ]
    else
      [ mutedLine "[j/k] sel [h/l] pane [f] filter [s] sort [/] search"
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
  let state := clampState snapshot rawState
  let writable := Loam.Tui.Layout.contentWidth bounds
  let leftWidth :=
    if writable >= 70 then min 32 (writable / 3) else min 24 (writable / 2)
  let rightWidth := if writable > leftWidth + 3 then writable - leftWidth - 3 else 0
  let lociCount := (lociForScope snapshot state).length
  let txCount := (visibleRecords snapshot state).length
  let leftHeader :=
    fit leftWidth
      (if state.pane == .loci then " Loci [active] (" ++ toString lociCount ++ ")"
       else " Loci (" ++ toString lociCount ++ ")")
  let orderTag := match state.order with
    | .asc => "asc"
    | .desc => "desc"
  let rightHeaderBase :=
    if state.pane == .transactions then " Actuals [active] (" ++ toString txCount ++ ")"
    else " Actuals (" ++ toString txCount ++ ")"
  let rightHeaderWithOrder :=
    if state.pane == .transactions then " Actuals [active] (" ++ toString txCount ++ ", " ++ orderTag ++ ")"
    else " Actuals (" ++ toString txCount ++ ", " ++ orderTag ++ ")"
  let rightHeader :=
    fit rightWidth
      (if rightWidth ≥ Loam.Tui.Layout.displayWidth rightHeaderWithOrder then
         rightHeaderWithOrder
       else
         rightHeaderBase)
  let searchLine :=
    if state.searchQuery.isEmpty && !state.searchEditing then []
    else
      let cursor := if state.searchEditing then "_" else ""
      [plainLine (Loam.Tui.Layout.clip writable
        (" Search: /" ++ state.searchQuery ++ cursor))]
  let details := detailLines snapshot state
  let footerLines := footer bounds state
  let noticeRows := if state.notice.isEmpty then 0 else 1
  let fixedBodyRows := 7 + searchLine.length + details.length + noticeRows
  let bodyCapacity := Loam.Tui.Layout.footerBodyCapacity bounds footerLines.length
  let paneRows := max 1 (bodyCapacity - fixedBodyRows)
  let body :=
    [ rule bounds '='
    , plainLine " Household Actuals Workspace"
    , plainLine (" Horizon: " ++ snapshot.actual.today ++ "  |  " ++ scopeText snapshot state)
    , plainLine (" Locus: " ++ currentLocusName snapshot state ++ "  |  Order: " ++ orderText state)
    ] ++ searchLine ++
    [ rule bounds '='
    , .row [span leftHeader, span " | ", span rightHeader]
    ] ++
    (List.range paneRows).map (paneRow snapshot state leftWidth rightWidth paneRows) ++
    [rule bounds '-'] ++ details ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (Loam.Tui.Layout.fitWithFooter bounds body footerLines)

end Loam.Tui.ActualWorkspace
