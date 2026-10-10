import Loam.ActualDate
import Loam.Review.ActualReview
import Loam.Publisher.AttentionPublisher
import Loam.Review.AttentionReview
import Loam.Tui.CyclicIndex
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Scroll
import Loam.Tui.Terminal

namespace Loam.Tui.AttentionAdministration

open Loam.Core Loam.Tui.Kernel
set_option autoImplicit false

/-!
# Attention administration

Presentation-only Add / Resolve / Drop over the shared Attention model. No
priority, taxonomy, amount, selected-day membership, editing or reopening is
introduced. Focus, viewport and input tails do not acquire publication authority.
-/

inductive Mode where
  | browse
  | newContext (text : String)
  | newDue (context : String)
  | newDate (context date : String)
  | confirmClose (attention : AttentionId) (kind : AttentionClosureKind)
  deriving Repr, DecidableEq

structure State where
  evidence : Loam.AttentionReview.Availability
  today : String
  cursor : Nat := 0
  mode : Mode := .browse
  notice : String := ""
  detailFocused : Bool := false
  contentScroll : Nat := 0

structure Step where
  state : State
  back : Bool := false
  add : Option Loam.AttentionPublisher.AddDraft := none
  close : Option Loam.AttentionPublisher.CloseDraft := none

def initial (evidence : Loam.AttentionReview.Availability) (today : String) : State :=
  {evidence, today}

private def openItems (state : State) : List (Attention String) :=
  match state.evidence with | .unavailable => [] | .available snapshot => snapshot.openItems

/-- Row identity remains the retained AttentionId, independently of clipping. -/
def selected? (state : State) : Option (Attention String) := (openItems state)[state.cursor]?

private def moveCursor (state : State) (back : Bool) (amount : Nat := 1) : State :=
  let count := (openItems state).length
  let next := if count == 0 then 0 else
    (List.range (amount % count)).foldl (fun index _ => Loam.Tui.CyclicIndex.move count index back) state.cursor
  {state with cursor := next, contentScroll := 0, notice := ""}

private def emitAdd (state : State) (context : String) (due : AttentionDue String) : Step :=
  {state := {state with mode := .browse, notice := ""}, add := some {context, due}}

private def beginClose (state : State) (kind : AttentionClosureKind) : Step :=
  match selected? state with
  | none => {state := {state with notice := "No open Attention item is selected."}}
  | some item => {state := {state with mode := .confirmClose item.id kind, notice := ""}}

/-- Existing writer intents: due-choice n/u or valid-date Enter; close Enter only. -/
private def updateIntent (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match state.mode with
  | .browse =>
      match key with
      | .escape | .input 'q' | .input 'Q' => {state, back := true}
      | .up | .input 'k' | .input 'K' => {state := moveCursor state true}
      | .down | .input 'j' | .input 'J' => {state := moveCursor state false}
      | .input 'n' | .input 'N' => {state := {state with mode := .newContext "", notice := ""}}
      | .input 'r' | .input 'R' => beginClose state .resolved
      | .input 'x' | .input 'X' => beginClose state .dropped
      | _ => {state}
  | .newContext text =>
      match key with
      | .escape => {state := {state with mode := .browse, notice := ""}}
      | .backspace => {state := {state with mode := .newContext (Loam.Tui.Terminal.backspaceText text), notice := ""}}
      | .input char => {state := {state with mode := .newContext (text.push char), notice := ""}}
      | .paste payload => {state := {state with mode := .newContext (text ++ Loam.Tui.Terminal.singleLinePaste payload), notice := ""}}
      | .enter =>
          if text.isEmpty then {state := {state with notice := "Enter a short household matter before choosing due meaning."}}
          else {state := {state with mode := .newDue text, notice := ""}}
      | _ => {state}
  | .newDue context =>
      match key with
      | .escape => {state := {state with mode := .browse, notice := ""}}
      | .input 'd' | .input 'D' => {state := {state with mode := .newDate context "", notice := ""}}
      | .input 'n' | .input 'N' => emitAdd state context .noDueDate
      | .input 'u' | .input 'U' => emitAdd state context .dueUndetermined
      | _ => {state}
  | .newDate context date =>
      match key with
      | .escape => {state := {state with mode := .browse, notice := ""}}
      | .backspace => {state := {state with mode := .newDate context (Loam.Tui.Terminal.backspaceText date), notice := ""}}
      | .input char => {state := {state with mode := .newDate context (date.push char), notice := ""}}
      | .paste text => {state := {state with mode := .newDate context (date ++ Loam.Tui.Terminal.singleLinePaste text), notice := ""}}
      | .enter =>
          if Loam.ActualDate.validIsoDate date then emitAdd state context (.dueOn date)
          else {state := {state with notice := "Enter a real calendar date in YYYY-MM-DD form."}}
      | _ => {state}
  | .confirmClose attention kind =>
      match key with
      | .escape => {state := {state with mode := .browse, notice := ""}}
      | .enter => {
          state := {state with mode := .browse, notice := ""}
          close := some {attention, knownOn := state.today, kind}}
      | _ => {state}

/-- Only accepted publication replaces the cached read answer. -/
def refreshed (evidence : Loam.AttentionReview.Availability) (notice : String) (state : State) : State :=
  {state with evidence, cursor := 0, mode := .browse, notice, detailFocused := false, contentScroll := 0}

def withPublishError (state : State) (message : String) : State :=
  {state with mode := .browse, notice := message, detailFocused := false, contentScroll := 0}

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []
private def kindLabel : AttentionClosureKind → String | .resolved => "resolve" | .dropped => "drop"

private def wrapped (width : Nat) (text : String) (style : Style := .normal) : List Widget :=
  (Loam.Tui.Layout.wrapColumns (width - 1) text).map fun part => .row [span " ", span part style]

private def fitText (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text ≤ width then Loam.Tui.Layout.padRight width text
  else Loam.Tui.Layout.padRight width (Loam.Tui.Layout.clip (width - 1) text ++ "…")

/-- Same end-visible input convention as Record; the retained text is never clipped. -/
private def fieldTail (width : Nat) (text : String) : String :=
  if Loam.Tui.Layout.displayWidth text ≤ width then text else if width == 0 then "" else
    let (chars, _, _) := text.toList.reverse.foldl
      (fun (acc : List Char × Nat × Bool) char =>
        let (chars, used, stopped) := acc
        let next := used + Loam.Tui.Layout.charWidth char
        if stopped || next > width - 1 then (chars, used, true) else (char :: chars, next, false)) ([], 0, false)
    "…" ++ String.ofList chars

private def field (width : Nat) (label value : String) : Widget :=
  let labelWidth := min 10 (width / 2)
  .row [span (Loam.Tui.Layout.padRight labelWidth (label ++ ": ")) .muted,
    span (fieldTail (width - labelWidth) (if value.isEmpty then "_" else value)) .selected]

private def itemLines (width : Nat) (item : Attention String) : List Widget :=
  wrapped width ("Context: " ++ item.context) ++
  wrapped width ("ID: " ++ item.id.token) .muted ++
  wrapped width ("Due: " ++ Loam.AttentionReview.dueLabel item.due) .muted

private def noItems (width : Nat) (state : State) : List Widget :=
  match state.evidence with
  | .unavailable => wrapped width "No canonical Attention stream yet." ++
      wrapped width "Press n to create the first household matter." .muted
  | .available _ => wrapped width "0 open" ++ wrapped width "Press n to add a household matter." .muted

private def contentLines (width : Nat) (state : State) : List Widget :=
  match state.mode with
  | .browse =>
      (match selected? state with | some item => itemLines width item | none => noItems width state) ++
      wrapped width "Unknown timing is distinct from no due date." .muted
  | .newContext text => wrapped width ("Full context: " ++ text)
  | .newDue context => wrapped width ("Context: " ++ context) ++
      wrapped width "Unknown timing is distinct from no due date." .muted
  | .newDate context _ => wrapped width ("Context: " ++ context) ++
      wrapped width "Enter a real date in YYYY-MM-DD form." .muted
  | .confirmClose id _ =>
      (match (openItems state).find? (fun item => item.id == id) with
       | some item => itemLines width item
       | none => wrapped width ("Target: " ++ id.token)) ++
      wrapped width "The item is retained; closure is recorded." .muted

private def pinnedLines (width : Nat) (state : State) : List Widget :=
  match state.mode with
  | .newContext text => [field width "Context" text]
  | .newDate _ date => [field width "Due date" date]
  | .newDue _ =>
      [line " [d] due on a known date", line " [n] no due date", line " [u] due timing unknown"]
  | _ => []

private def footer (bounds : Bounds) (state : State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let feedback := if state.notice.isEmpty then [blank] else wrapped width state.notice .muted
  let operations := match state.mode with
    | .browse =>
        let nav := if state.detailFocused then [("j/k", "scroll"), ("i/q", "list"), ("C-u/d", "page")]
          else if width ≥ 79 then [("j/k", "select"), ("C-u/d", "page"), ("Home/End", "ends"), ("i", "info"), ("q", "back")]
          else [("j/k", "sel"), ("C-u/d", "page"), ("i", "info"), ("q", "back")]
        [Loam.Tui.Layout.shortcutRow nav " ", Loam.Tui.Layout.shortcutRow [("n", "new"), ("r", "resolve"), ("x", "drop")] " "]
    | .newContext _ =>
        [Loam.Tui.Layout.shortcutRow [("Enter", "next"), ("Esc", "cancel")] " ",
         Loam.Tui.Layout.shortcutRow [("Backspace", "delete"), ("C-u/d", "review")] " "]
    | .newDue _ =>
        [Loam.Tui.Layout.shortcutRow [("d", "enter date"), ("n", "publish no due")] " ",
         Loam.Tui.Layout.shortcutRow [("u", "publish unknown"), ("Esc", "cancel")] " "]
    | .newDate _ _ =>
        [Loam.Tui.Layout.shortcutRow [("Enter", "publish"), ("Esc", "cancel")] " ",
         Loam.Tui.Layout.shortcutRow [("Backspace", "delete"), ("C-u/d", "review")] " "]
    | .confirmClose _ _ =>
        [Loam.Tui.Layout.shortcutRow [("Enter", "confirm"), ("Esc", "cancel")] " ",
         Loam.Tui.Layout.shortcutRow [("j/k", "review"), ("C-u/d", "page"), ("Home/End", "ends")] " "]
  let rows := feedback ++ operations
  Loam.Tui.Layout.boundFeedbackFooter bounds rows

private structure Geometry where
  width : Nat
  panelHeight : Nat
  contextRows : Nat
  listWidth : Nat
  listHeight : Nat
  detailWidth : Nat
  detailHeight : Nat
  wide : Bool
  detailOnly : Bool

private def geometry (bounds : Bounds) (state : State) : Geometry :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let rows := Loam.Tui.Layout.footerBodyCapacity bounds (footer bounds state).length
  let contextRows := if rows ≥ 5 then 2 else if rows ≥ 4 then 1 else 0
  let panelHeight := rows - contextRows
  let browse := state.mode == .browse
  let wide := browse && width ≥ 99 && panelHeight ≥ 10
  let detailWidth := if wide then min 60 (max 48 (width * 40 / 100)) else width
  let detailHeight := if wide then panelHeight else if browse && panelHeight ≥ 16 then 6 else 0
  let detailOnly := browse && state.detailFocused && detailHeight == 0
  { width, panelHeight, contextRows, wide, detailOnly, detailWidth
    listWidth := if wide then width - 1 - detailWidth else width
    listHeight := if detailOnly then 0 else if wide then panelHeight
      else panelHeight - detailHeight - (if detailHeight > 0 then 1 else 0)
    detailHeight := if detailOnly then panelHeight else detailHeight }

private def listCapacity (height : Nat) : Nat := height - 2 - (if height ≥ 4 then 1 else 0)

private def contentGeometry (g : Geometry) (state : State) : Nat × Nat :=
  if state.mode == .browse then (g.detailWidth - 2, g.detailHeight - 2)
  else (g.width - 2, (g.panelHeight - 2) - (pinnedLines (g.width - 2) state).length)

private def scrollLimit (g : Geometry) (state : State) : Nat :=
  let (width, visible) := contentGeometry g state
  if visible == 0 then 0 else Loam.Tui.Scroll.maxOffset (contentLines width state).length visible

/-- Geometry normalization cannot create an item or change a closure target. -/
def normalizedForBounds (bounds : Bounds) (state : State) : State :=
  let state := {state with cursor := min state.cursor ((openItems state).length - 1)}
  {state with contentScroll := min state.contentScroll (scrollLimit (geometry bounds state) state)}

private def scrollStep (bounds : Bounds) (state : State) (key : Loam.Tui.Terminal.Key) (repeatCount : Nat) : State :=
  let g := geometry bounds state
  let (width, visible) := contentGeometry g state
  let count := (contentLines width state).length
  let page := key == .pageUp || key == .pageDown || key == .ctrl 'u' || key == .ctrl 'd'
  let amount := if page then max 1 visible else max 1 repeatCount
  let forward := key == .down || key == .input 'j' || key == .input 'J' || key == .pageDown || key == .ctrl 'd'
  {state with contentScroll := if key == .home then 0 else if key == .«end» then scrollLimit g state
    else if forward then Loam.Tui.Scroll.forward count visible state.contentScroll amount
    else Loam.Tui.Scroll.backward count visible state.contentScroll amount}

/-- Local navigation and review never emit drafts; original explicit write keys remain. -/
def updateForBounds (bounds : Bounds) (rawState : State) (key : Loam.Tui.Terminal.Key)
    (repeatCount : Nat := 1) : Step :=
  let state := normalizedForBounds bounds rawState
  let vertical := key == .up || key == .down || key == .input 'j' || key == .input 'J' || key == .input 'k' || key == .input 'K'
  let paging := key == .pageUp || key == .pageDown || key == .ctrl 'u' || key == .ctrl 'd' || key == .home || key == .«end»
  if state.mode == .browse then
    if key == .enter || key == .tab || key == .shiftTab || key == .input 'i' || key == .input 'I' then
      {state := normalizedForBounds bounds {state with detailFocused := !state.detailFocused, notice := ""}}
    else if state.detailFocused && (key == .escape || key == .input 'q' || key == .input 'Q') then
      {state := normalizedForBounds bounds {state with detailFocused := false, notice := ""}}
    else if state.detailFocused && (vertical || paging) then
      {state := normalizedForBounds bounds (scrollStep bounds {state with notice := ""} key repeatCount)}
    else if !state.detailFocused && (vertical || paging) then
      let back := key == .up || key == .input 'k' || key == .input 'K' || key == .pageUp || key == .ctrl 'u'
      let next := if key == .home || key == .«end» then
          {state with cursor := if key == .home then 0 else (openItems state).length - 1, contentScroll := 0, notice := ""}
        else if paging then
          let amount := max 1 (listCapacity (geometry bounds state).listHeight)
          {state with
            cursor := if back then state.cursor - amount else min ((openItems state).length - 1) (state.cursor + amount)
            contentScroll := 0
            notice := ""}
        else moveCursor state back (max 1 repeatCount)
      {state := normalizedForBounds bounds next}
    else
      let step := updateIntent state key
      {step with state := normalizedForBounds bounds (if step.state.mode != state.mode then
        {step.state with detailFocused := false, contentScroll := 0} else step.state)}
  else if paging || (vertical && match state.mode with | .confirmClose _ _ => true | _ => false) then
    {state := normalizedForBounds bounds (scrollStep bounds state key repeatCount)}
  else
    let step := updateIntent state key
    {step with state := normalizedForBounds bounds (if step.state.mode != state.mode then
      {step.state with detailFocused := false, contentScroll := 0} else step.state)}

/-- Default bounds used by existing interaction tests, not production tty observation. -/
def update (state : State) (key : Loam.Tui.Terminal.Key) : Step := updateForBounds {width := 80, height := 24} state key

private def scrolled (width visible : Nat) (state : State) : List Widget × String :=
  let raw := contentLines width state
  let offset := Loam.Tui.Scroll.clamp raw.length visible state.contentScroll
  ((raw.drop offset).take visible,
    s!"{if visible == 0 then 0 else offset + 1}-{min (offset + visible) raw.length}/{raw.length}" ++
    (if offset > 0 then " ↑" else "") ++ (if offset + visible < raw.length then " ↓" else ""))

private def listPanel (g : Geometry) (state : State) : Widget :=
  let items := openItems state
  let capacity := listCapacity g.listHeight
  let start := Loam.Tui.Layout.trailingWindowStart state.cursor (max 1 capacity)
  let width := g.listWidth - 2
  let dueWidth := min 14 ((width - 5) / 2)
  let contextWidth := width - dueWidth - 5
  let heading := if g.listHeight ≥ 4 then
    [muted ("   " ++ fitText dueWidth "Due" ++ "  " ++ fitText contextWidth "Context")] else []
  let rows := if items.isEmpty then (noItems width state).take capacity else
    (items.drop start |>.take capacity |>.zipIdx).map fun (item, offset) =>
      let selected := start + offset == state.cursor
      let marker := if selected then (if state.detailFocused then " * " else " > ") else "   "
      .row [span (marker ++ fitText dueWidth (Loam.AttentionReview.dueLabel item.due) ++ "  " ++ fitText contextWidth item.context)
        (if selected && !state.detailFocused then .selected else .normal)]
  let position := (match state.evidence with
    | .unavailable => "unavailable"
    | .available _ => if items.isEmpty then "0 open" else s!"{state.cursor + 1}/{items.length} open") ++
    (if start > 0 then " ↑" else "") ++ (if start + capacity < items.length then " ↓" else "")
  Loam.Tui.Layout.framedPanel g.listWidth g.listHeight ("Open" ++ (if state.detailFocused then "" else " [active]"))
    (.column (heading ++ rows)) (!state.detailFocused) (some position)

private def detailPanel (g : Geometry) (state : State) : Widget :=
  let (rows, position) := scrolled (g.detailWidth - 2) (g.detailHeight - 2) state
  Loam.Tui.Layout.framedPanel g.detailWidth g.detailHeight ("Selected matter" ++ (if state.detailFocused then " [active]" else ""))
    (.column rows) state.detailFocused (some position)

private def editorPanel (g : Geometry) (state : State) : Widget :=
  let pinned := pinnedLines (g.width - 2) state
  let (rows, position) := scrolled (g.width - 2) ((g.panelHeight - 2) - pinned.length) state
  let title := match state.mode with
    | .newContext _ => "Context [active]"
    | .newDue _ => "Due meaning"
    | .newDate _ _ => "Due date [active]"
    | .confirmClose _ kind => kindLabel kind ++ " confirmation"
    | _ => "Review"
  Loam.Tui.Layout.framedPanel g.width g.panelHeight title (.column (pinned ++ rows)) true (some position)

private def widgetRows (widget : Widget) : List Widget :=
  widget.lines.map fun cells => .row (cells.map fun cell => span (String.singleton cell.glyph) cell.style)

/-- All modes are bounded; full text lives in a scrollable review, not a clipped draft. -/
def viewForBounds (bounds : Bounds) (rawState : State) : Widget :=
  let state := normalizedForBounds bounds rawState
  let g := geometry bounds state
  let context := match state.mode with
    | .browse => [line " Attention / Manage", muted " Household matters that should not disappear from view"]
    | .newContext _ => [line " Attention / New", muted " Enter chooses due meaning; no write yet."]
    | .newDue _ => [line " Attention / New / Due meaning", muted " n/u publishes now; d enters a known date."]
    | .newDate _ _ => [line " Attention / New / Due date", muted " Enter publishes due-on; Esc cancels."]
    | .confirmClose _ kind => [line (" Attention / " ++ kindLabel kind), line (" Record " ++ kindLabel kind ++ " on " ++ state.today ++ "?")]
  let panels := if state.mode != .browse then widgetRows (editorPanel g state)
    else if g.wide then Loam.Tui.Layout.sideBySide g.listHeight g.listWidth g.detailWidth (listPanel g state) (detailPanel g state) " "
    else if g.detailOnly then widgetRows (detailPanel g state)
    else widgetRows (listPanel g state) ++ (if g.detailHeight == 0 then [] else [blank] ++ widgetRows (detailPanel g state))
  .column ((Loam.Tui.Layout.fitWithFooter bounds (context.take g.contextRows ++ panels) (footer bounds state)).map fun row =>
    .row ((Loam.Tui.Layout.clipCells g.width row.lines.flatten).map fun cell => span (String.singleton cell.glyph) cell.style))

def view (state : State) : Widget := viewForBounds {width := 80, height := 24} state

end Loam.Tui.AttentionAdministration
