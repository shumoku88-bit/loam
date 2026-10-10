import Loam.Review.CurrentBalanceReview
import Loam.Presentation.MeasurePresentation
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.PlainTextPrint
import Loam.Tui.Scroll

namespace Loam.Tui.Balances

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Selected current balances

The replaceable balance-view selects neutral Locus × Measure coordinates, not
Accounts or roles. CurrentBalanceReview owns exact / present-but-amount-unknown /
unsupported answers. Selection, detail focus and offsets below are ephemeral UI
state only; printing stays a bounded read-only projection of all selected rows.
-/

inductive Row where
  | exact (coordinate : EffectCoordinate) (quantity : Quantity)
  | knownPresent (coordinate : EffectCoordinate)
  | unsupported (coordinate : EffectCoordinate)
  deriving Repr, DecidableEq

structure State where
  rows : List Row
  selectedRow : Nat := 0
  detailFocused : Bool := false
  detailScroll : Nat := 0
  notice : String := ""
  deriving Repr, DecidableEq

inductive Step where
  | stay (state : State)
  | back

private def rowFor (snapshot : Loam.CurrentBalanceReview.Snapshot)
    (coordinate : EffectCoordinate) : Row :=
  match snapshot.exactRowFor? coordinate with
  | some row => .exact coordinate row.quantity
  | none => if snapshot.knownPresent.contains coordinate then .knownPresent coordinate
      else .unsupported coordinate

/-- Select shared current answers in configuration order, normalizing duplicates only. -/
def initial (snapshot : Loam.CurrentBalanceReview.Snapshot)
    (coordinates : List EffectCoordinate) : State :=
  { rows := coordinates.eraseDups.map (rowFor snapshot) }

private def rowCoordinate : Row → EffectCoordinate
  | .exact coordinate _ | .knownPresent coordinate | .unsupported coordinate => coordinate

/-- The row identity remains the exact selected Locus × Measure coordinate. -/
def selectedRow? (state : State) : Option Row :=
  state.rows[state.selectedRow]?

private def quantityText : Row → String
  | .exact _ quantity => Loam.MeasurePresentation.groupDisplayedNumber (toString quantity.quanta)
  | .knownPresent _ | .unsupported _ => "?"

private def stateText (row : Row) (compact : Bool := false) : String :=
  match row with
  | .exact _ _ => "exact"
  | .knownPresent _ => if compact then "present, ?" else "present, amount unknown"
  | .unsupported _ => "unsupported"

private def fitText (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text ≤ width then Loam.Tui.Layout.padRight width text
  else Loam.Tui.Layout.padRight width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

private def wrapped (width : Nat) (text : String) (style : Style := .normal) : List Widget :=
  (Loam.Tui.Layout.wrapColumns (width - 1) text).map fun line =>
    .row [span " ", span line style]

private def detailRawLines (width : Nat) (state : State) : List Widget :=
  match selectedRow? state with
  | none => wrapped width "No balances are selected in the current balance view." .muted
  | some row =>
      let coordinate := rowCoordinate row
      wrapped width ("Locus: " ++ coordinate.locus.token) ++
      wrapped width ("Measure: " ++ coordinate.measure.token) .muted ++
      wrapped width ("Quanta: " ++ quantityText row ++ " " ++ coordinate.measure.token) ++
      wrapped width ("State: " ++ stateText row) .muted ++
      (match row with
       | .exact _ _ => []
       | .knownPresent _ =>
           wrapped width "Presence is known; the exact current amount is unknown, not zero." .muted
       | .unsupported _ =>
           wrapped width "No current quantity support is justified for this coordinate. Do not infer zero." .muted) ++
      wrapped width "Locus × Measure; not an Account taxonomy." .muted

/-- Print complete values, never the clipped table or the selected viewport. -/
private def printRow (row : Row) : Widget :=
  let coordinate := rowCoordinate row
  plainLine ("  " ++ coordinate.locus.token ++ "  " ++ quantityText row ++ " " ++
    coordinate.measure.token ++ "  " ++ stateText row)

/-- Existing finite print limits apply before any terminal output or file mutation. -/
def preparePrint (state : State) : Except String Loam.Tui.PlainTextPrint.Prepared := do
  if state.rows.length + 6 > Loam.Tui.PlainTextPrint.maxLines then
    throw "Print refused: more than 200 lines. Narrow the balance selection first."
  Loam.Tui.PlainTextPrint.prepareWidgets <|
    [ plainLine "Balances / Current"
    , mutedLine "Selected current Locus × Measure balances; not an Account taxonomy."
    , mutedLine "Exact / amount-unknown / unsupported states preserve current evidence."
    , blankLine
    ] ++
    (if state.rows.isEmpty then
      [mutedLine "No balances are selected in the current balance view."]
     else state.rows.map printRow) ++
    [blankLine, mutedLine "Rows follow balance-view order only."]

private def footer (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := if state.notice.isEmpty then [blankLine] else wrapped width state.notice .muted
  let navigation := if state.detailFocused then
      [("j/k", "scroll"), ("Esc/i/q", "list")]
    else if width ≥ 79 then [("j/k", "select"), ("i/Enter", "details"), ("q", "back")]
    else [("j/k", "sel"), ("i/Enter", "info"), ("q", "back")]
  let rows := feedback ++
    [ Loam.Tui.Layout.shortcutRow navigation " "
    , Loam.Tui.Layout.shortcutRow [("C-u/d", "page"), ("Home/End", "ends"), ("p", "print view")] " "
    ]
  let capacity := bounds.height - 1
  if rows.length ≤ capacity then rows
  else if capacity == 0 then []
  else rows.take (capacity - 1) ++ [mutedLine " … more feedback/help; enlarge terminal"]

private structure Geometry where
  width : Nat
  listWidth : Nat
  listHeight : Nat
  detailWidth : Nat
  detailHeight : Nat
  contextRows : Nat
  wide : Bool
  detailOnly : Bool

private def geometry (bounds : Bounds) (state : State) : Geometry :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let bodyRows := Loam.Tui.Layout.footerBodyCapacity bounds (footer bounds state).length
  let contextRows := if bodyRows ≥ 5 then 2 else if bodyRows ≥ 4 then 1 else 0
  let panelHeight := bodyRows - contextRows
  let wide := width ≥ 119 && panelHeight ≥ 10
  let detailWidth := if wide then min 60 (max 48 (width * 34 / 100)) else width
  let detailHeight := if wide then panelHeight else if panelHeight ≥ 12 then
      (if bounds.height ≥ 48 then 10 else if bounds.height ≥ 36 then 8 else 6) + 2
    else 0
  let detailOnly := state.detailFocused && detailHeight == 0
  { width, detailWidth, contextRows, wide, detailOnly
    listWidth := if wide then width - 1 - detailWidth else width
    listHeight := if detailOnly then 0 else if wide then panelHeight
      else panelHeight - detailHeight - (if detailHeight > 0 then 1 else 0)
    detailHeight := if detailOnly then panelHeight else detailHeight }

private def detailLimit (g : Geometry) (state : State) : Nat :=
  if g.detailHeight < 3 then 0 else
    Loam.Tui.Scroll.maxOffset (detailRawLines (g.detailWidth - 2) state).length (g.detailHeight - 2)

/-- Clamp UI geometry only; quantity support and configuration order are untouched. -/
def normalizedForBounds (bounds : Bounds) (state : State) : State :=
  let state := {state with selectedRow := min state.selectedRow (state.rows.length - 1)}
  {state with detailScroll := min state.detailScroll (detailLimit (geometry bounds state) state)}

private def listCapacity (height : Nat) : Nat :=
  height - 2 - (if height ≥ 4 then 1 else 0)

private def quantityCell (width : Nat) (text : String) : String :=
  Loam.Tui.Layout.padLeft width (if Loam.Tui.Layout.displayWidth text ≤ width then text
    else if width ≥ 11 then "see details" else "…")

private structure Columns where
  rowWidth : Nat
  quantityWidth : Nat
  measureWidth : Nat
  stateWidth : Nat
  full : Bool

private def columns (width : Nat) (state : State) : Columns :=
  let rowWidth := width - 5
  let full := rowWidth ≥ 54
  let measureWidth := min 12 (max 7 (state.rows.foldl (fun n row =>
    max n (Loam.Tui.Layout.displayWidth (rowCoordinate row).measure.token)) 0))
  let stateWidth := if rowWidth ≥ 74 then 23 else 11
  let desired := min 22 (max 12 (state.rows.foldl (fun n row =>
    max n (Loam.Tui.Layout.displayWidth (quantityText row))) 0))
  {rowWidth, measureWidth, stateWidth, full
   quantityWidth := if full then min desired (rowWidth - measureWidth - stateWidth - 5 - 8)
     else min 14 (rowWidth / 2)}

private def tableRow (c : Columns) (locus quantity measure status : String) : String :=
  if c.full then
    fitText (c.rowWidth - c.quantityWidth - c.measureWidth - c.stateWidth - 5) locus ++ "  " ++
      quantityCell c.quantityWidth quantity ++ " " ++ fitText c.measureWidth measure ++ "  " ++
      fitText c.stateWidth status
  else
    fitText (c.rowWidth - c.quantityWidth - 2) locus ++ "  " ++ quantityCell c.quantityWidth quantity

private def tableEntry (c : Columns) (row : Row) : String :=
  let coordinate := rowCoordinate row
  if c.full then tableRow c coordinate.locus.token (quantityText row) coordinate.measure.token
    (stateText row (c.stateWidth < 23))
  else tableRow c (coordinate.locus.token ++ " / " ++ coordinate.measure.token)
    (match row with | .exact _ _ => quantityText row | _ => stateText row true) "" ""

private def listPanel (g : Geometry) (state : State) : Widget :=
  let c := columns g.listWidth state
  let visible := listCapacity g.listHeight
  let start := Loam.Tui.Layout.trailingWindowStart state.selectedRow (max 1 visible)
  let focused := !state.detailFocused
  let header := if g.listHeight < 4 then [] else
    [mutedLine ("   " ++ tableRow c (if c.full then "Locus" else "Locus / Measure")
      (if c.full then "Quanta" else "Value / state") "Measure" "State")]
  let rows := if state.rows.isEmpty then
      (wrapped (g.listWidth - 2) "No balances are selected in the current balance view." .muted).take visible
    else (List.range visible).map fun offset =>
      let index := start + offset
      let row := state.rows[index]?
      let chosen := index == state.selectedRow && row.isSome
      let marker := if chosen then (if focused then " > " else " * ") else "   "
      let content := row.map (fun item => marker ++ tableEntry c item) |>.getD ""
      .row [span (Loam.Tui.Layout.padRight (g.listWidth - 2) content)
        (if chosen && focused then .selected else .normal)]
  let position := (if state.rows.isEmpty then "0/0" else s!"{state.selectedRow + 1}/{state.rows.length}") ++
    (if start > 0 then " ↑" else "") ++ (if start + visible < state.rows.length then " ↓" else "")
  Loam.Tui.Layout.framedPanel g.listWidth g.listHeight
    ("Balances" ++ (if focused then " [active]" else "")) (.column (header ++ rows)) focused (some position)

private def detailPanel (g : Geometry) (state : State) : Widget :=
  let raw := detailRawLines (g.detailWidth - 2) state
  let visible := g.detailHeight - 2
  let offset := Loam.Tui.Scroll.clamp raw.length visible state.detailScroll
  let position := s!"{if visible == 0 then 0 else offset + 1}-{min (offset + visible) raw.length}/{raw.length}" ++
    (if offset > 0 then " ↑" else "") ++ (if offset + visible < raw.length then " ↓" else "")
  Loam.Tui.Layout.framedPanel g.detailWidth g.detailHeight
    ("Selected balance" ++ (if state.detailFocused then " [active]" else ""))
    (.column ((raw.drop offset).take visible)) state.detailFocused (some position)

private def widgetRows (widget : Widget) : List Widget :=
  widget.lines.map fun cells => .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)

/-- Read-only selection/scroll intents; no household reads, writes or role inference. -/
def update (bounds : Bounds) (rawState : State) (key : Loam.Tui.Terminal.Key)
    (repeatCount : Nat := 1) : Step :=
  let state := normalizedForBounds bounds rawState
  let clean := {state with notice := ""}
  let g := geometry bounds clean
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      if state.detailFocused then .stay (normalizedForBounds bounds {clean with detailFocused := false}) else .back
  | .enter | .tab | .shiftTab | .input 'i' | .input 'I' =>
      .stay (normalizedForBounds bounds {clean with detailFocused := !state.detailFocused})
  | .up | .down | .input 'j' | .input 'J' | .input 'k' | .input 'K' |
    .pageUp | .pageDown | .ctrl 'u' | .ctrl 'd' | .home | .«end» =>
      let forward := key == .down || key == .input 'j' || key == .input 'J' || key == .pageDown || key == .ctrl 'd'
      let page := key == .pageUp || key == .pageDown || key == .ctrl 'u' || key == .ctrl 'd'
      let next := if state.detailFocused then
          let content := (detailRawLines (g.detailWidth - 2) clean).length
          let visible := g.detailHeight - 2
          let amount := if page then max 1 visible else max 1 repeatCount
          let scroll := if key == .home then 0 else if key == .«end» then detailLimit g clean
            else if forward then Loam.Tui.Scroll.forward content visible state.detailScroll amount
            else Loam.Tui.Scroll.backward content visible state.detailScroll amount
          {clean with detailScroll := scroll}
        else
          let amount := if page then max 1 (listCapacity g.listHeight) else max 1 repeatCount
          let row := if key == .home then 0 else if key == .«end» then state.rows.length - 1
            else if forward then min (state.rows.length - 1) (state.selectedRow + amount)
            else state.selectedRow - amount
          {clean with
            selectedRow := row
            detailScroll := if row == state.selectedRow then state.detailScroll else 0}
      .stay (normalizedForBounds bounds next)
  | _ => .stay state

/-- Geometry-sized quiet frames over already-derived selected current answers. -/
def viewForBounds (bounds : Bounds) (rawState : State) : Widget :=
  let state := normalizedForBounds bounds rawState
  let g := geometry bounds state
  let context := [plainLine " Balances / Current",
    mutedLine (if g.width ≥ 79 then " Selected Locus × Measure; balance-view order only."
      else " Selected Locus × Measure; configured order.")]
  let panels := if g.wide then
      Loam.Tui.Layout.sideBySide g.listHeight g.listWidth g.detailWidth
        (listPanel g state) (detailPanel g state) " "
    else if g.detailOnly then widgetRows (detailPanel g state)
    else widgetRows (listPanel g state) ++
      (if g.detailHeight == 0 then [] else [blankLine] ++ widgetRows (detailPanel g state))
  .column ((Loam.Tui.Layout.fitWithFooter bounds (context.take g.contextRows ++ panels) (footer bounds state)).map fun row =>
    .row ((Loam.Tui.Layout.clipCells g.width row.lines.flatten).map fun cell =>
      span (String.singleton cell.glyph) cell.style))

/-- Standard-bound rendering retained for current presentation/print boundary tests. -/
def view (state : State) : Widget := viewForBounds {width := 80, height := 24} state

end Loam.Tui.Balances
