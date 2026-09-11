import Loam.LocusCatalog
import Loam.Tui.Layout
import Loam.Tui.Main

namespace Loam.Tui.HraActual

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
  order : SortOrder := .asc
  pane : Pane := .loci
  locusRow : Nat := 0
  transactionRow : Nat := 0
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
  | recordNew
  | back
  | other
  deriving Repr, DecidableEq, BEq

inductive Command where
  | stay
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


def visibleRecords (snapshot : Snapshot) (state : State) : List ReviewRecord :=
  let base :=
    match selectedLocus? snapshot state with
    | none => recordsForScope snapshot state
    | some locus =>
        (recordsForScope snapshot state).filter fun record =>
          record.event.effects.any fun effect => effect.locus.token == locus
  match state.order with
  | .asc => base
  | .desc => base.reverse


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


def update (snapshot : Snapshot) (state : State) (event : Event) : Step :=
  match event with
  | .previous => { state := movePrevious snapshot state }
  | .next => { state := moveNext snapshot state }
  | .focusLeft => { state := { state with pane := .loci, notice := "" } }
  | .focusRight => { state := { state with pane := .transactions, notice := "" } }
  | .cycleFilter => { state := cycleFilter snapshot state }
  | .cycleOrder => { state := cycleOrder snapshot state }
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

private def locusWindowStart (state : State) : Nat :=
  if state.locusRow > 6 then state.locusRow - 5 else 0

private def txWindowStart (state : State) : Nat :=
  if state.transactionRow > 6 then state.transactionRow - 5 else 0

private def locusLabel (snapshot : Snapshot) (state : State) (row : Nat) : Option String :=
  if row = 0 then some "[All loci]"
  else (lociForScope snapshot state)[row - 1]?.map (displayLocus state)

private def paneRow (snapshot : Snapshot) (state : State)
    (leftWidth rightWidth row : Nat) : Widget :=
  let locusIndex := locusWindowStart state + row
  let txIndex := txWindowStart state + row
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

private def footer (bounds : Bounds) : List Widget :=
  let detailedRow1 := "[j/k] select  [h/l] pane  [f] filter  [o] order"
  if Loam.Tui.Layout.displayWidth detailedRow1 ≤ Loam.Tui.Layout.contentWidth bounds then
    [ mutedLine detailedRow1
    , mutedLine "[n] new  [q] back"
    ]
  else
    [ mutedLine "[j/k] sel [h/l] pane [f] filter [o] ord"
    , mutedLine "[n] new [q] back"
    ]

private def fitWithFooter (bounds : Bounds) (body footerRows : List Widget) : List Widget :=
  let available := if bounds.height > 0 then bounds.height - 1 else 0
  let bodyCapacity := available - footerRows.length
  let visibleBody := body.take bodyCapacity
  let padding := bodyCapacity - visibleBody.length
  visibleBody ++ List.replicate padding blankLine ++ footerRows

private def orderText (state : State) : String :=
  match state.order with
  | .asc => "oldest first"
  | .desc => "newest first"

/--
HRA-shaped Actual workspace over the shared ActualReview answer. Stable tokens
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
  let body :=
    [ rule bounds '='
    , plainLine " Household Actuals Workspace"
    , plainLine (" Horizon: " ++ snapshot.actual.today ++ "  |  " ++ scopeText snapshot state)
    , plainLine (" Locus: " ++ currentLocusName snapshot state ++ "  |  Order: " ++ orderText state)
    , rule bounds '='
    , .row [span leftHeader, span " | ", span rightHeader]
    ] ++
    (List.range 8).map (paneRow snapshot state leftWidth rightWidth) ++
    [rule bounds '-'] ++ detailLines snapshot state ++
    (if state.notice.isEmpty then [] else [plainLine state.notice])
  .column (fitWithFooter bounds body (footer bounds))

end Loam.Tui.HraActual
