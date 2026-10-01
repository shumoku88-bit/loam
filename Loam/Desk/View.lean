import Loam.Desk.Model
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Desk.View

open Loam.Tui.Kernel

set_option autoImplicit false

private def plainLine (text : String) : Widget := .row [span text]
private def mutedLine (text : String) : Widget := .row [span text .muted]
private def blankLine : Widget := .row []

private def repeatChar (count : Nat) (char : Char) : String :=
  String.ofList (List.replicate count char)

private def rule (bounds : Bounds) (char : Char) : Widget :=
  plainLine (repeatChar (Loam.Tui.Layout.contentWidth bounds) char)

private def dateDayText (date : String) : String :=
  match Loam.Tui.Calendar.parseDate? date with
  | some (_, _, day) => Loam.Tui.Calendar.padded 2 day
  | none => "??"

private def hasActual (snapshot : Loam.Desk.Model.Snapshot) (date : String) : Bool :=
  !(Loam.Desk.Model.recordsForDate snapshot date).isEmpty

private def calendarDaySpan
    (snapshot : Loam.Desk.Model.Snapshot)
    (state : Loam.Desk.Model.State)
    (date? : Option String) : Span :=
  match date? with
  | none => span "  "
  | some date =>
      let selected := date == state.focusDate
      let recorded := hasActual snapshot date
      let style :=
        if selected && recorded then .selectedUnderlined
        else if selected then .selected
        else if recorded then .underlined
        else .normal
      span (dateDayText date) style

private def calendarRow
    (snapshot : Loam.Desk.Model.Snapshot)
    (state : Loam.Desk.Model.State)
    (week : Nat) : Widget :=
  let slots := Loam.Tui.Calendar.slots
    ((Loam.Desk.Model.focusedMonth? state).getD { year := 1970, month := 1 })
  let spans :=
    (List.range 7).flatMap fun col =>
      let day := slots[week * 7 + col]?.join
      if col = 6 then [calendarDaySpan snapshot state day]
      else [calendarDaySpan snapshot state day, span " "]
  .row spans

private def calendarPane
    (snapshot : Loam.Desk.Model.Snapshot)
    (state : Loam.Desk.Model.State) : Widget :=
  let month :=
    (Loam.Desk.Model.focusedMonth? state).getD { year := 1970, month := 1 }
  let count := (Loam.Desk.Model.recordsForDate snapshot state.focusDate).length
  .column <|
    [ plainLine (" " ++ Loam.Tui.Calendar.monthLabel month)
    , mutedLine " Mo Tu We Th Fr Sa Su"
    ] ++
    (List.range 6).map (calendarRow snapshot state) ++
    [ blankLine
    , plainLine (" Focus: " ++ state.focusDate)
    , mutedLine (" Actual on day: " ++ toString count)
    ]

private def recordText (record : Loam.Desk.Model.ReviewRecord) : String :=
  record.date.getD "undated" ++ "  " ++ Loam.ActualReview.summary record

private def ledgerPane
    (height width : Nat)
    (snapshot : Loam.Desk.Model.Snapshot)
    (state : Loam.Desk.Model.State) : Widget :=
  let records := Loam.Desk.Model.visibleRecords snapshot state
  let selected := state.selectedRow.getD 0
  let capacity := if height > 2 then height - 2 else 0
  let rows := Loam.Tui.Layout.centeredListWindow records selected capacity
  let body :=
    if records.isEmpty then
      [mutedLine " (no current Actual in this month)"]
    else
      rows.map fun (index, record) =>
        let marker := if state.selectedRow == some index then "> " else "  "
        let style := if state.selectedRow == some index then Style.selected else Style.normal
        .row [span (Loam.Tui.Layout.padRight width (marker ++ recordText record)) style]
  .column <| [plainLine " Actual", mutedLine " date        description / effects"] ++ body

private def selectedContext
    (snapshot : Loam.Desk.Model.Snapshot)
    (state : Loam.Desk.Model.State) : List Widget :=
  match Loam.Desk.Model.selectedRecord? snapshot state with
  | none =>
      [ plainLine " Selected"
      , mutedLine "   (no Actual selected for the focused date)"
      ]
  | some record =>
      if state.showEvidence then
        [plainLine " Evidence"] ++
          ((Loam.ActualReview.detailLines snapshot.records record).take 6).map plainLine
      else
        [ plainLine " Selected"
        , plainLine ("   Date        : " ++ record.date.getD "(undated)")
        , plainLine ("   Description : " ++
            (if record.description.isEmpty then "(no description)"
             else Loam.ActualReview.shortText 52 record.description))
        , plainLine ("   Identity    : " ++ record.event.id.token)
        , mutedLine "   [Enter/e] show evidence"
        ]

private def footer
    (bounds : Bounds) (state : Loam.Desk.Model.State) : List Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  if state.jumpEditing then
    [mutedLine (Loam.Tui.Layout.clip width
      (" Jump to date: " ++ state.jumpText ++ "_  [Enter] go  [Esc] cancel"))]
  else
    let detailed :=
      "[j/k] row  [h/l] day  [H/L] month  [g] date  [Enter/e] evidence  [q] quit"
    let compact :=
      "[j/k] row [h/l] day [H/L] month [g] date [e] evidence [q] quit"
    [mutedLine (if Loam.Tui.Layout.displayWidth detailed ≤ width then detailed else compact)]

/--
Read-only experimental household desk.

Actual Review supplies the evidence projection. This surface owns only focus,
selection and responsive terminal geometry.
-/
def view
    (bounds : Bounds)
    (snapshot : Loam.Desk.Model.Snapshot)
    (state : Loam.Desk.Model.State) : Widget :=
  let width := Loam.Tui.Layout.contentWidth bounds
  let paneHeight := min 12 (bounds.height - 9)
  let ledgerWidth :=
    if width >= 92 then width - 27
    else if width >= 72 then width - 23
    else width
  let deskRows :=
    if width >= 92 then
      Loam.Tui.Layout.sideBySide paneHeight 24 ledgerWidth
        (calendarPane snapshot state)
        (ledgerPane paneHeight ledgerWidth snapshot state)
    else if width >= 72 then
      Loam.Tui.Layout.sideBySide paneHeight 20 ledgerWidth
        (calendarPane snapshot state)
        (ledgerPane paneHeight ledgerWidth snapshot state)
    else
      (ledgerPane paneHeight ledgerWidth snapshot state).lines.map fun cells =>
        Widget.row (cells.map fun cell => span (String.ofList [cell.glyph]) cell.style)
  let body :=
    [ rule bounds '='
    , plainLine (" LOAM Desk  |  " ++
        (Loam.Desk.Model.focusedMonth? state |>.map Loam.Tui.Calendar.monthLabel |>.getD "invalid month") ++
        "  |  read-only")
    , rule bounds '='
    ] ++ deskRows ++
    [rule bounds '-'] ++ selectedContext snapshot state ++
    (if state.notice.isEmpty then [] else [plainLine (" " ++ state.notice)])
  .column (Loam.Tui.Layout.fitWithFooter bounds body (footer bounds state))

end Loam.Desk.View
