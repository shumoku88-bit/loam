import Loam.Tests.ActualWorldFixture
import Loam.Tui.Record
import Loam.Tui.RecordSession
import Loam.Tui.UnresolvedActivation
import Loam.Review.MovementDraftReview
import Loam.Publisher.MovementPublisher
import Loam.Review.ActualReview

open Loam.Core Loam.Tui.Record

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Loam.Tui.Kernel.Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Loam.Tui.Kernel.Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

open Loam.Tui.Kernel

private def world : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"books"⟩]
    | throw (IO.userError "vocabulary")
  return {
    events := events
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def readyForm : Form := {
  date := "2026-09-06"
  description := "数学ガール"
  rows := #[
    { locus := "paypay", amount := "-2470" },
    { locus := "books", amount := "2470" }] }

private def checkBoundedEditing : IO Unit := do
  let bounds : Bounds := { width := 80, height := 24 }
  let opened := initial "2026-09-06"
  let frame := Loam.Tui.Runtime.compileWidget (viewForBounds bounds [] opened)
  expect (Loam.Tui.RecordSession.focusedCursorPosition? 0 0 frame == some (3, 15))
    "bounded Record did not anchor the initial Description caret"
  let japanese := { opened with form := { opened.form with description := "食事" } }
  let japaneseFrame := Loam.Tui.Runtime.compileWidget (viewForBounds bounds [] japanese)
  expect (Loam.Tui.RecordSession.focusedCursorPosition? 5 10 japaneseFrame == some (8, 28))
    "bounded Record lost CJK caret width or floating origin"
  let catalog : Loam.LocusCatalog.Catalog := (List.range 12).map fun index =>
    { locus := ⟨s!"locus-{index}"⟩, label := "日本語の長い候補ラベル",
      help := "候補の意味を説明する長い日本語のヘルプ" }
  let sixRows : Form := { readyForm with rows := Array.replicate 6 {}, focus := ⟨1, by simp⟩ }
  for width in [48, 80, 120] do
    for height in [14, 24, 40] do
      let active : Bounds := { width, height }
      for index in List.range (3 + sixRows.rows.size * 2 + 4) do
        have count : 0 < 3 + sixRows.rows.size * 2 + 4 := by omega
        let form := { sixRows with focus := ⟨index % _, Nat.mod_lt _ count⟩ }
        let state : State := { form, candidateCatalog := catalog }
        let widget := viewForBounds active [] state
        expect (widget.lines.length == height - 1 && widget.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= width - 1))
          s!"editing escaped {width}x{height} at focus {index}"
        let some (row, col) := Loam.Tui.RecordSession.focusedCursorPosition? 0 0
            (Loam.Tui.Runtime.compileWidget widget)
          | throw (IO.userError s!"focus {index} was hidden at {width}x{height}")
        expect (row < height - 1 && col < width - 1)
          "editing caret escaped usable terminal bounds"
  let focusLocus := { readyForm with rows := #[{}, {}], focus := ⟨3, by decide⟩ }
  let first : State := { form := focusLocus, candidateCatalog := catalog }
  let last := { first with candidateIndex := 11 }
  let firstView := viewForBounds bounds [] first
  let lastView := viewForBounds bounds [] last
  expect (contains "12/12" (widgetText lastView) && contains "locus-11" (widgetText lastView))
    "candidate viewport did not follow the selected canonical token"
  expect (firstView.lines.drop 18 == lastView.lines.drop 18)
    "candidate count or selection moved the fixed editing footer"
  expect (contains "…" (widgetText lastView)) "long candidate labels lost their truncation indicator"
  let noticed := { first with notice := "Invalid quantity." }
  expect (firstView.lines.drop 20 == (viewForBounds bounds [] noticed).lines.drop 20)
    "ordinary feedback moved editing actions or navigation"
  let longDescription := String.join (List.replicate 50 "日本語") ++ "末尾"
  let long := { opened with form := { opened.form with description := longDescription } }
  let compact : Bounds := { width := 48, height := 14 }
  let longText := widgetText (viewForBounds compact [] long)
  expect (contains "…" longText && contains "末尾" longText &&
    long.form.description == longDescription)
    "editing a long field hid its tail or changed stored input"

private def checkOriginalAmountSurface (w : Loam.MovementAdmission.World) : IO Unit := do
  let editor : OriginalAmountEditor := { measure := "usd", amount := "30.00" }
  let base : State := { form := readyForm, mode := .originalAmount editor }
  let bounds : Bounds := { width := 80, height := 24 }
  let frame := Loam.Tui.Runtime.compileWidget (viewForBounds bounds [] base)
  expect (Loam.Tui.RecordSession.focusedCursorPosition? 0 0 frame == some (2, 17))
    "Original amount Measure caret lost aligned field geometry"
  let focused : State := { base with mode := .originalAmount { editor with focus := ⟨1, by decide⟩ } }
  let amountFrame := Loam.Tui.Runtime.compileWidget (viewForBounds bounds [] focused)
  expect (Loam.Tui.RecordSession.focusedCursorPosition? 5 10 amountFrame == some (8, 29))
    "Original amount caret lost Amount focus or floating origin"
  let japanese : State := { base with mode := .originalAmount { editor with measure := "原通貨" } }
  expect (Loam.Tui.RecordSession.focusedCursorPosition? 0 0
    (Loam.Tui.Runtime.compileWidget (viewForBounds bounds [] japanese)) == some (2, 20))
    "Original amount caret lost CJK terminal width"
  for width in [48, 80, 120] do
    for height in [14, 24, 40] do
      let active : Bounds := { width, height }
      for index in [0, 1] do
        let next := { editor with focus := ⟨index % 2, Nat.mod_lt _ (by decide)⟩ }
        let state : State := { base with mode := .originalAmount next }
        let widget := viewForBounds active [] state
        let text := widgetText widget
        expect (widget.lines.length == height - 1 && widget.lines.all (fun cells =>
          Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= width - 1))
          "Original amount escaped terminal bounds"
        expect (contains "╭" text && contains "not another posting" text &&
          contains "No FX inference" text && contains "Publish later in Preview" text &&
          contains "[Enter] next/attach" text && contains "[Esc] cancel" text)
          "Original amount lost its meaning hierarchy or complete operation bar"
        let some (row, col) := Loam.Tui.RecordSession.focusedCursorPosition? 0 0
            (Loam.Tui.Runtime.compileWidget widget)
          | throw (IO.userError "Original amount hid its active field")
        expect (row < height - 1 && col < width - 1)
          "Original amount caret escaped usable terminal bounds"
        let noticed := { state with notice := "Original amount must be positive." }
        let longNotice := "Enter a positive original amount with at most 2 decimal places."
        let refused := { state with notice := longNotice }
        expect (widget.lines.drop (height - 3) ==
          (viewForBounds active [] noticed).lines.drop (height - 3) &&
          widget.lines.drop (height - 3) ==
          (viewForBounds active [] refused).lines.drop (height - 3))
          "Original amount feedback moved its two navigation rows"
        let refusalText := widgetText (viewForBounds active [] refused)
        expect (contains "positive original amount" refusalText && contains "decimal places." refusalText)
          "Original amount clipped its complete validation cause"
  let longMeasure := String.join (List.replicate 30 "通貨") ++ "末尾"
  let longAmount := String.join (List.replicate 10 "1234567890") ++ "99"
  let compact : Bounds := { width := 48, height := 14 }
  for (index, measure, amount, tail) in [(0, longMeasure, "30", "末尾"), (1, "usd", longAmount, "99")] do
    let next : OriginalAmountEditor := { measure, amount, focus := ⟨index % 2, Nat.mod_lt _ (by decide)⟩ }
    let text := widgetText (viewForBounds compact [] { base with mode := .originalAmount next })
    expect (contains "…" text && contains tail text)
      "Original amount hid a long active field's tail"
  let returned := update w [] base (.ctrl 'o')
  expect (returned.publish.isNone && returned.state.form.rows == readyForm.rows &&
    returned.state.form.description == readyForm.description)
    "returning from Original amount changed postings or published"
  expect ((update w [] base .escape).publish.isNone && (update w [] base .escape).cancel)
    "Original amount cancellation emitted publication"

private def checkUnresolvedEnableSurface (w : Loam.MovementAdmission.World) : IO Unit := do
  let prompted := update w [] { form := readyForm } (.ctrl 'u')
  expect (prompted.publish.isNone && !prompted.enableUnresolved)
    "opening unresolved confirmation activated policy or published"
  let state := prompted.state
  for width in [48, 80, 120] do
    for height in [14, 24, 40] do
      let bounds : Bounds := { width, height }
      let widget := viewForBounds bounds [] state
      let text := widgetText widget
      expect (widget.lines.length == height - 1 && widget.lines.all (fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= width - 1))
        "unresolved confirmation escaped terminal bounds"
      expect (contains "Household vocabulary" text && contains "Admit ordinary Locus: suspense." text &&
        contains "does not record the Movement" text && contains "No Measure change or category guessing" text &&
        contains "Preview before Publish" text && contains "[Enter] enable" text &&
        contains "[e/E] return" text && contains "[Backspace] return" text && contains "[Esc] cancel Record" text)
        "unresolved confirmation lost its household-change boundary or operation bar"
      expect (Loam.Tui.RecordSession.focusedCursorPosition? 0 0
        (Loam.Tui.Runtime.compileWidget widget) ==
        some (height - 4, Loam.Tui.Layout.displayWidth "[Enable unresolved recording]"))
        "unresolved confirmation lost its fixed action caret"
      for notice in ["Confirmation required.",
          "Read failed: この世帯の語彙を読み込めません。No authority was guessed."] do
        let noticed := { state with notice }
        let next := viewForBounds bounds [] noticed
        expect (widget.lines.drop (height - 3) == next.lines.drop (height - 3))
          "unresolved confirmation feedback moved its navigation rows"
        expect (contains notice ((widgetText next).replace "\n" ""))
          "unresolved confirmation clipped wrapped feedback"
  for key in [Loam.Tui.Terminal.Key.input 'e', .input 'E', .backspace] do
    let returned := update w [] state key
    expect (!returned.enableUnresolved && returned.publish.isNone && !returned.cancel &&
      returned.state.form.rows == readyForm.rows && returned.state.form.description == readyForm.description &&
      returned.state.form.date == readyForm.date && returned.state.form.measure == readyForm.measure)
      "returning from unresolved confirmation changed input or requested a write"
    match returned.state.mode with
    | .editing => pure ()
    | _ => throw (IO.userError "unresolved confirmation return did not restore editing")
  let confirmed := update w [] state .enter
  expect (confirmed.enableUnresolved && confirmed.publish.isNone && confirmed.state.form.rows == readyForm.rows)
    "explicit unresolved confirmation changed Movement publication semantics"
  let cancelled := update w [] state .escape
  expect (cancelled.cancel && !cancelled.enableUnresolved && cancelled.publish.isNone)
    "unresolved confirmation cancellation requested a write"

private def checkBoundedConfirmation (w : Loam.MovementAdmission.World) : IO Unit := do
  let bounds : Bounds := { width := 80, height := 24 }
  let editor := preview w { form := readyForm }
  let rendered := viewForBounds bounds [] editor
  let text := widgetText rendered
  expect (contains "╭" text && contains "Movement / signed postings" text &&
    contains "-2,470 jpy  paypay" text && contains "+2,470 jpy  books" text)
    "bounded confirmation lost its quiet frame or signed Effects"
  expect (rendered.lines.length == bounds.height - 1 &&
    rendered.lines.all (fun cells => Loam.Tui.Layout.displayWidth
      (String.ofList (cells.map Cell.glyph)) <= bounds.width - 1))
    "confirmation escaped terminal bounds"
  expect (contains "[Publish] [Edit] [Cancel]" text && contains "[Enter] confirm" text)
    "bounded confirmation hid its publication controls"
  let longDescription := String.intercalate " " (List.replicate 20 "長い確認内容")
  let longForm := { readyForm with description := longDescription }
  let longEditor := preview w { form := longForm }
  let compact : Bounds := { width := 48, height := 14 }
  let limit := previewScrollLimit compact longEditor
  expect (limit > 0) "long confirmation did not expose a review viewport"
  let some tail := scrollPreview compact longEditor .«end»
    | throw (IO.userError "End did not review confirmation")
  expect (tail.previewScroll == limit && tail.form.rows == longEditor.form.rows &&
    tail.form.description == longEditor.form.description && tail.form.date == longEditor.form.date &&
    tail.form.measure == longEditor.form.measure)
    "review scrolling changed recording inputs"
  let startRows := (viewForBounds compact [] longEditor).lines
  let endRows := (viewForBounds compact [] tail).lines
  expect (startRows.drop (startRows.length - 6) == endRows.drop (endRows.length - 6))
    "review scrolling moved confirmation controls"
  expect (contains "Balanced total" (widgetText (viewForBounds compact [] tail)))
    "End did not reach the complete confirmation tail"
  let some atEnd := scrollPreview compact tail .down
    | throw (IO.userError "Down did not handle confirmation review")
  expect (atEnd.previewScroll == limit) "review scrolling overshot its visible bounds"
  let some atStart := scrollPreview compact tail .home
    | throw (IO.userError "Home did not handle confirmation review")
  expect (atStart.previewScroll == 0) "Home did not return to confirmation start"
  expect ((update w [] tail .enter).publish.isSome &&
    (update w [] tail .escape).publish.isNone)
    "review scrolling changed explicit publication or cancellation"
  let hugeForm := { readyForm with rows := #[
    { locus := "paypay", amount := "-12345678901234567890" },
    { locus := "books", amount := "12345678901234567890" }] }
  let huge := preview w { form := hugeForm }
  expect (contains "12,345,678,901,234,567,890" (widgetText (viewForBounds bounds [] huge)) &&
    contains "12,345,678,901,234,567,890" (widgetText (view [] huge)))
    "confirmation clipped a large exact amount into a different quantity"

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let w ← world
  checkBoundedEditing
  checkOriginalAmountSurface w
  checkUnresolvedEnableSurface w
  checkBoundedConfirmation w
  let compactBounds : Bounds := { width := 80, height := 24 }
  expect (Loam.Tui.RecordSession.floatingGeometry? compactBounds).isNone
    "compact terminal unexpectedly forced floating Record"
  let largeBounds : Bounds := { width := 120, height := 40 }
  let geometry ←
    match Loam.Tui.RecordSession.floatingGeometry? largeBounds with
    | some geometry => pure geometry
    | none => throw (IO.userError "large terminal did not admit floating Record")
  expect
    (geometry.top + geometry.height <= largeBounds.height &&
      geometry.left + geometry.width <= Loam.Tui.Layout.contentWidth largeBounds)
    "floating Record geometry escaped the visible terminal"
  -- Only outer styling may change, not glyphs, editor size, field focus or caret.
  let editor := initial "2026-09-06"
  let inner : Bounds := { width := geometry.width - 1, height := geometry.height - 1 }
  let previous : Widget := Loam.Tui.Layout.framedPanel geometry.width geometry.height
    "Record movement" (viewForBounds inner [] editor)
  let current := Loam.Tui.RecordSession.floatingRecordView geometry [] editor
  expect (previous.lines.map (fun cells => cells.map Cell.glyph) ==
    current.lines.map (fun cells => cells.map Cell.glyph) &&
    current.lines.length == geometry.height)
    "floating Record changed editor text or frame geometry"
  let oldCursor := Loam.Tui.RecordSession.focusedCursorPosition? geometry.top geometry.left
    (Loam.Tui.Runtime.compileWidget previous)
  let newCursor := Loam.Tui.RecordSession.focusedCursorPosition? geometry.top geometry.left
    (Loam.Tui.Runtime.compileWidget current)
  expect (oldCursor == newCursor && newCursor.isSome)
    "floating Record accent displaced its active input caret"
  let top := current.lines.head!
  let corners := top.filter fun cell => cell.glyph == '╭' || cell.glyph == '╮'
  expect (corners.length == 2 && corners.all (fun cell => cell.style == .series1))
    "floating Record outer frame did not indicate focus"
  expect ((current.lines.flatten.filter fun cell => cell.style == .selected).length > 0)
    "floating Record lost active input highlighting"

  let openedText := widgetText (view [] (initial "2026-09-06"))
  expect
    (contains "Measure: jpy\n\nPosting 1:" openedText &&
      contains "decimal input follows the Measure presentation scale.\nCtrl-U fill unresolved remainder\n\nLocus catalog:" openedText &&
      contains "Up / Down choose candidate   Enter accept candidate\n\nOriginal amount: (none)   Ctrl-O add" openedText &&
      contains "[Cancel] \nCtrl-N add row   Ctrl-D drop row   Drop keeps at least two postings\n\nTab / Shift-Tab focus   Enter next / preview   Esc cancel   Backspace delete" openedText)
    "Record editing surface lost contextual help placement"

  let helpCatalog : Loam.LocusCatalog.Catalog :=
    [{ locus := ⟨"food"⟩, label := "食費", help := "日常の食事・食材" }]
  let helpForm : Form := {
    readyForm with
    rows := #[
      { locus := "f", amount := "-2470" },
      { locus := "books", amount := "2470" }]
    focus := ⟨3, by decide⟩ }
  let helpText :=
    widgetText (view [] (withCatalog { form := helpForm } helpCatalog))
  expect
    (contains "> food  食費\n\n  ↳ 日常の食事・食材\nUp / Down choose candidate" helpText)
    "Record Locus help was not visually separated from catalog candidates"

  let imeFrame :=
    Loam.Tui.Runtime.compileWidget (view [] (initial "2026-09-06"))
  expect
    (Loam.Tui.RecordSession.focusedCursorPosition? 0 0 imeFrame == some (2, 14))
    "Record cursor did not return to the active Description field"
  let japaneseState :=
    { initial "2026-09-06" with form := { (initial "2026-09-06").form with description := "食事" } }
  let japaneseFrame := Loam.Tui.Runtime.compileWidget (view [] japaneseState)
  expect
    (Loam.Tui.RecordSession.focusedCursorPosition? 5 10 japaneseFrame == some (7, 27))
    "Record cursor lost CJK display width or floating origin"

  let opened := initial "2026-09-06"
  expect (opened.form.date == "2026-09-06" && opened.form.focus.val == 1)
    "Record must start at Description with the selected date intact"
  let usdOpened := initialWithMeasure ⟨"usd"⟩ "2026-09-06"
  expect (usdOpened.form.measure == "usd" && usdOpened.form.focus.val == 1)
    "Record did not retain the configured default Measure"
  let typed := update w [] opened (.input 'A')
  expect (typed.state.form.description == "A" && typed.state.form.date == "2026-09-06")
    "first keystroke must edit Description, not the prefilled date"
  let dateFocus := update w [] opened .shiftTab
  expect (dateFocus.state.form.focus.val == 0)
    "Shift-Tab must still allow editing the prefilled date"
  let restored := update w [] dateFocus.state .tab
  expect (restored.state.form.focus.val == 1)
    "Tab must return from Date to Description"
  let sharedInput : Loam.Presentation.Record.Input := {
    date := "2026-09-06"
    description := "数学ガール"
    rows := #[
      { locus := "paypay", amount := "-2470" },
      { locus := "books", amount := "2470" }]
  }
  let .ok sharedPreview := Loam.Presentation.Record.preview? w [] sharedInput
    | throw (IO.userError "shared Record preview")
  let .ok draft := draft? readyForm | throw (IO.userError "form parsing")
  expect
    (sharedPreview.draft.validOn == draft.validOn &&
      sharedPreview.draft.description == draft.description &&
      sharedPreview.draft.total == draft.total &&
      sharedPreview.draft.effects.map (fun effect =>
        (effect.locus.token, effect.measure.token, effect.quantity.quanta)) ==
      draft.effects.map (fun effect =>
        (effect.locus.token, effect.measure.token, effect.quantity.quanta)))
    "TUI Record draft diverged from shared Record preview"
  expect (draft.effects.map (fun effect => effect.quantity.quanta) == [-2470, 2470])
    "signed postings did not preserve their quantities"

  let paddedForm : Form := {
    readyForm with
    rows := #[
      { locus := "paypay", amount := "  -2470 " },
      { locus := "books", amount := " 2470  " }] }
  let .ok paddedDraft := draft? paddedForm
    | throw (IO.userError "Record amount edge whitespace was not tolerated")
  expect (paddedDraft.effects.map (fun effect => effect.quantity.quanta) == [-2470, 2470])
    "Record amount edge trimming changed exact signed quantities"
  match draft? { readyForm with rows := #[
      { locus := "paypay", amount := "-2470" },
      { locus := "books", amount := "oops" }] } with
  | .error message =>
      expect (message.startsWith "Posting 2 amount 'oops'")
        "Record invalid amount feedback did not identify the failing posting"
  | .ok _ => throw (IO.userError "invalid Record amount unexpectedly parsed")
  let usdForm : Form := {
    readyForm with
    measure := "usd"
    rows := #[
      { locus := "paypay", amount := "-25" },
      { locus := "books", amount := "25" }] }
  let .ok usdDraft := draft? usdForm
    | throw (IO.userError "USD form parsing")
  expect (usdDraft.effects.all fun effect => effect.measure == ⟨"usd"⟩)
    "TUI Record did not preserve selected Measure"

  let decimalPresentation : List Loam.MeasurePresentation.Metadata :=
    [ { measure := ⟨"usd"⟩, scale := 2 }
    , { measure := ⟨"ils"⟩, scale := 2 }
    ]
  let decimalUsdForm : Form := {
    readyForm with
    measure := "usd"
    rows := #[
      { locus := "paypay", amount := "-12.34" },
      { locus := "books", amount := "12.34" }] }
  let .ok decimalUsdDraft := draftWithPresentation? decimalPresentation decimalUsdForm
    | throw (IO.userError "decimal USD form parsing")
  expect
    (decimalUsdDraft.effects.map (fun effect => effect.quantity.quanta) == [-1234, 1234])
    "decimal USD input did not map exactly to quanta"
  expect
    (Loam.MeasurePresentation.formatQuanta decimalPresentation ⟨"usd"⟩ (-5) == "-0.05")
    "decimal USD formatting did not zero-pad exact quanta"
  expect
    (Loam.MeasurePresentation.formatGroupedQuanta [] ⟨"jpy"⟩ (-240000) == "-240,000")
    "grouped quantity formatting misplaced the sign"
  expect
    (Loam.MeasurePresentation.formatGroupedQuanta
      decimalPresentation ⟨"usd"⟩ 123456 == "1,234.56")
    "grouped quantity formatting lost the configured decimal scale"
  expect
    (Loam.MeasurePresentation.formatGroupedAmount [] ⟨"jpy"⟩ (-240000) == "-¥240,000")
    "JPY symbol formatting misplaced the sign or grouping"
  expect
    (Loam.MeasurePresentation.formatGroupedAmount
      decimalPresentation ⟨"usd"⟩ 123456 == "$1,234.56")
    "USD symbol formatting lost the configured decimal scale"
  expect
    (Loam.MeasurePresentation.formatAmount
      [{ measure := ⟨"eur"⟩, scale := 2 }] ⟨"eur"⟩ 1850 == "€18.50")
    "EUR symbol formatting lost exact decimal presentation"
  expect
    (Loam.MeasurePresentation.formatAmount
      decimalPresentation ⟨"ils"⟩ 2790 == "₪27.90")
    "ILS symbol formatting lost exact decimal presentation"
  expect
    (Loam.Tui.Layout.displayWidth "₪27.90" == 6)
    "ILS symbol did not occupy one terminal column"
  expect
    (Loam.MeasurePresentation.formatAmount [] ⟨"points"⟩ 12 == "12 points")
    "unknown Measure did not fall back to its explicit token"
  expect
    ((draftWithPresentation? decimalPresentation
      { decimalUsdForm with rows := #[
          { locus := "paypay", amount := "-12.345" },
          { locus := "books", amount := "12.345" }] }).isOk == false)
    "decimal input accepted more fractional digits than the configured scale"
  expect
    (Loam.MeasurePresentation.parseQuanta? decimalPresentation ⟨"ils"⟩ "27.9" == some 2790)
    "ILS scale did not right-pad a shorter exact fractional input"

  let originalBase : State := {
    form := readyForm
    measurePresentation := decimalPresentation
  }
  let openedOriginal := update w [] originalBase (.ctrl 'o')
  match openedOriginal.state.mode with
  | .originalAmount editor =>
      expect (editor.measure.isEmpty && editor.amount.isEmpty)
        "Ctrl-O did not open an empty original amount editor"
  | _ => throw (IO.userError "Ctrl-O did not open original amount editor")

  let originalEditor : OriginalAmountEditor := {
    measure := "usd"
    amount := "30.00"
    focus := ⟨1, by decide⟩
  }
  let attached := update w []
    { originalBase with mode := .originalAmount originalEditor } .enter
  let original ←
    match attached.state.originalAmount with
    | some value => pure value
    | none => throw (IO.userError "valid original amount was not attached")
  expect (original.measure == ⟨"usd"⟩ && original.quantity.quanta == 3000)
    "decimal original amount did not retain exact USD quanta"
  match attached.state.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "attaching original amount did not return to ordinary editor")

  let invalidOriginal : OriginalAmountEditor := {
    measure := "usd"
    amount := "30.001"
    focus := ⟨1, by decide⟩
  }
  expect
    ((attachOriginalAmount? originalBase invalidOriginal).isOk == false)
    "original amount accepted too many decimal places"

  let originalPreview := preview w attached.state
  let originalPublish := update w [] originalPreview .enter
  match originalPublish.publish with
  | some (.movementWithOriginalAmount publishedDraft publishedOriginal) =>
      expect (publishedDraft.total == 2470)
        "original amount changed the ordinary Movement total"
      expect
        (publishedOriginal.measure == ⟨"usd"⟩ &&
          publishedOriginal.quantity.quanta == 3000)
        "preview lost attached original amount"
  | _ => throw (IO.userError "attached original amount did not emit atomic publication intent")

  let cleared := update w []
    { attached.state with mode := .originalAmount originalEditor } (.ctrl 'd')
  expect cleared.state.originalAmount.isNone
    "Ctrl-D did not clear attached original amount"
  match cleared.state.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "clearing original amount did not return to editor")
  let previewText := widgetText (view [] (preview w { form := readyForm }))
  expect
    (contains "Record / Preview\n\nMovement\n" previewText &&
      contains "Date         2026-09-06" previewText &&
      contains "Description  数学ガール" previewText &&
      contains "Measure      jpy\n\nPostings\n" previewText)
    "Record preview lost its ledger header"
  expect
    (contains "-2,470 jpy" previewText &&
      contains "2,470 jpy" previewText &&
      contains "Balanced total" previewText)
    "Record preview lost aligned grouped posting amounts"
  expect
    (contains "Publication gate\n  recheck current evidence\n  recheck Locus admission\n\n[Publish]" previewText &&
      contains "[Cancel] \n\nTab / Shift-Tab select   Enter confirm   Esc cancel" previewText)
    "Record preview lost publication-gate hierarchy"

  let editor := preview w { form := readyForm }
  match (update w [] editor .enter).publish with
  | some (.movement _) => pure ()
  | _ => throw (IO.userError "ordinary preview no longer emits ordinary Movement intent")
  expect ((update w [] editor .escape).publish.isNone) "cancel must not publish"
  let edited := update w [] (update w [] editor .tab).state .enter
  expect (edited.state.form.description == readyForm.description) "Edit lost description"
  expect (edited.state.form.rows == readyForm.rows) "Edit lost rows"

  let finalAmountForm := { readyForm with focus := ⟨6, by decide⟩ }
  let directPreview := update w [] { form := finalAmountForm } .enter
  match directPreview.state.mode with
  | .preview _ choice => expect (choice.val == 0) "direct preview did not select Publish"
  | .editing => throw (IO.userError "final amount Enter did not open preview")
  | .enableUnresolved => throw (IO.userError "final amount Enter opened unresolved activation")
  | .originalAmount _ => throw (IO.userError "final amount Enter opened original amount editor")
  expect (directPreview.publish.isNone) "direct preview published without confirmation"
  expect ((update w [] directPreview.state .enter).publish.isSome)
    "direct preview did not preserve explicit publish confirmation"
  let finalAmountTab := update w [] { form := finalAmountForm } .tab
  expect (finalAmountTab.state.form.focus.val == 7)
    "Tab from final amount reaches Preview action"
  let previewActionForm := { readyForm with focus := ⟨7, by decide⟩ }
  let previewed := update w [] { form := previewActionForm } .enter
  match previewed.state.mode with
  | .preview _ choice => expect (choice.val == 0) "Preview action did not open preview"
  | .editing => throw (IO.userError "Preview action did not open preview")
  | .enableUnresolved => throw (IO.userError "Preview action opened unresolved activation")
  | .originalAmount _ => throw (IO.userError "Preview action opened original amount editor")

  let addPostingForm := { readyForm with focus := ⟨8, by decide⟩ }
  let added := update w [] { form := addPostingForm } .enter
  expect (added.state.form.rows.size == 3) "Add posting did not append one row"
  expect (added.state.form.focus.val == 7) "Add posting did not focus the new Locus"
  expect (added.state.form.rows[2]!.locus.isEmpty && added.state.form.rows[2]!.amount.isEmpty)
    "Add posting did not append one neutral row"

  let reversedForm : Form := {
    readyForm with
    rows := #[
      { locus := "books", amount := "2470" },
      { locus := "paypay", amount := "-2470" }] }
  expect ((draft? reversedForm).isOk) "posting order became semantic"
  expect ((draft? { readyForm with rows := #[
    { locus := "paypay", amount := "2470" },
    { locus := "books", amount := "2470" }] }).isOk == false)
    "unbalanced same-sign postings were accepted"
  expect ((draft? { readyForm with rows := #[
    { locus := "paypay", amount := "0" },
    { locus := "books", amount := "0" }] }).isOk == false)
    "zero postings were accepted"

  expect ((Loam.MovementAdmission.admit? w { draft with total := 1 }).isOk == false)
    "forged total admitted"
  expect ((Loam.MovementAdmission.admit? w { draft with effects := draft.effects.take 1 }).isOk == false)
    "unbalanced draft admitted"
  expect ((Loam.MovementAdmission.admit? w { draft with validOn := "2026-02-29" }).isOk == false)
    "impossible date admitted"
  let invalid := preview w { form := { readyForm with date := "bad" } }
  expect ((update w [] invalid .enter).publish.isNone) "invalid preview emitted publication"

  let unresolvedStartForm : Form := {
    readyForm with
    description := "bulk purchase"
    rows := #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" }] }
  let unresolvedPrompt := update w [] { form := unresolvedStartForm } (.ctrl 'u')
  expect (unresolvedPrompt.state.form.rows == unresolvedStartForm.rows)
    "unresolved activation prompt changed rows before policy admission"
  expect (!unresolvedPrompt.enableUnresolved)
    "unresolved activation prompt requested durable policy without confirmation"
  match unresolvedPrompt.state.mode with
  | .enableUnresolved => pure ()
  | _ => throw (IO.userError "missing suspense Locus did not open explicit activation confirmation")
  let unresolvedEnable := update w [] unresolvedPrompt.state .enter
  expect unresolvedEnable.enableUnresolved
    "explicit unresolved confirmation did not emit activation intent"
  expect (unresolvedEnable.publish.isNone)
    "unresolved activation confirmation also emitted Actual publication"
  let unresolvedBack := update w [] unresolvedPrompt.state (.input 'e')
  match unresolvedBack.state.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "unresolved activation return did not restore editing")

  let activationRoot := root / "unresolved-activation"
  IO.FS.createDirAll activationRoot
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? activationRoot w
    | throw (IO.userError "initialize unresolved activation fixture")
  let actualBeforeActivation ← IO.FS.readFile (activationRoot / "actual.loam")
  let .ok enabled ← Loam.Tui.UnresolvedActivation.enable? activationRoot
    | throw (IO.userError "enable unresolved recording")
  expect (enabled.world.locusAdmission.allows unresolvedLocus)
    "unresolved activation did not survive canonical world reload"
  expect ((← IO.FS.readFile (activationRoot / "actual.loam")) == actualBeforeActivation)
    "unresolved activation changed Actual authority"
  let .ok enabledAgain ← Loam.Tui.UnresolvedActivation.enable? activationRoot
    | throw (IO.userError "repeat unresolved activation did not converge")
  expect (enabledAgain.world.locusAdmission.allows unresolvedLocus)
    "repeat unresolved activation lost admitted suspense Locus"
  expect ((← IO.FS.readFile (activationRoot / "actual.loam")) == actualBeforeActivation)
    "repeat unresolved activation changed Actual authority"

  let some unresolvedVocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"books"⟩, ⟨"food"⟩, unresolvedLocus]
    | throw (IO.userError "unresolved vocabulary")
  let unresolvedWorld : Loam.MovementAdmission.World := {
    w with locusAdmission := unresolvedVocabulary }

  let unresolvedFilled := update unresolvedWorld [] { form := unresolvedStartForm } (.ctrl 'u')
  expect (unresolvedFilled.state.form.rows == #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" },
      { locus := "suspense", amount := "4600" }])
    "unresolved remainder did not append the exact balancing posting"
  let .ok unresolvedDraft := draft? unresolvedFilled.state.form
    | throw (IO.userError "filled unresolved Movement did not parse")
  expect ((Loam.MovementAdmission.admit? unresolvedWorld unresolvedDraft).isOk)
    "filled unresolved Movement did not pass ordinary Movement admission"

  let partialForm : Form := replaceRows unresolvedStartForm #[
    { locus := "paypay", amount := "-5800" },
    { locus := "books", amount := "1200" },
    { locus := "food", amount := "2000" },
    { locus := "suspense", amount := "4600" }]
  let partialAdjusted := update unresolvedWorld [] { form := partialForm } (.ctrl 'u')
  expect (partialAdjusted.state.form.rows == #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" },
      { locus := "food", amount := "2000" },
      { locus := "suspense", amount := "2600" }])
    "unresolved remainder did not adjust an existing suspense posting"

  let resolvedForm : Form := replaceRows unresolvedStartForm #[
    { locus := "paypay", amount := "-5800" },
    { locus := "books", amount := "1200" },
    { locus := "food", amount := "4600" },
    { locus := "suspense", amount := "2600" }]
  let resolvedFilled := update unresolvedWorld [] { form := resolvedForm } (.ctrl 'u')
  expect (resolvedFilled.state.form.rows == #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" },
      { locus := "food", amount := "4600" }])
    "zero unresolved remainder did not remove the suspense posting"
  let .ok resolvedDraft := draft? resolvedFilled.state.form
    | throw (IO.userError "fully classified Movement did not parse")
  expect ((Loam.MovementAdmission.admit? unresolvedWorld resolvedDraft).isOk)
    "fully classified Movement failed ordinary admission after suspense removal"

  let blankCandidateForm : Form := {
    readyForm with
    rows := #[
      { locus := "", amount := "-2470" },
      { locus := "books", amount := "2470" }]
    focus := ⟨3, by decide⟩ }
  let pickerKnown := ["paypay", "books", "point"]
  let pickerStart : State := { form := blankCandidateForm }
  let pickerDown := (update w pickerKnown pickerStart .down).state
  expect ((catalogCandidates pickerDown).map (fun entry => entry.locus.token) == ["paypay", "books"])
    "Record catalog was not reduced to current LocusAdmission"
  expect ((selectedCatalogCandidate? pickerDown).map (fun entry => entry.locus.token) == some "books")
    "Down did not move the catalog candidate cursor"
  let pickerWrapped := (update w pickerKnown pickerDown .down).state
  expect ((selectedCatalogCandidate? pickerWrapped).map (fun entry => entry.locus.token) == some "paypay")
    "catalog cursor escaped current LocusAdmission into recognition-only history"
  let pickerAccepted := (update w pickerKnown pickerDown .right).state
  expect (pickerAccepted.form.rows[0]!.locus == "books")
    "Right did not accept the selected catalog candidate"
  expect (pickerAccepted.form.rows[1]! == blankCandidateForm.rows[1]!)
    "catalog candidate selection changed another posting row"

  -- Exact matching token must not be substituted by a prefix neighbor on Enter or Right
  let some foodVocab := LocusAdmissionVocabulary.ofLoci? [⟨"food"⟩, ⟨"food-stock"⟩]
    | throw (IO.userError "prefix vocabulary")
  let foodWorld : Loam.MovementAdmission.World := { w with locusAdmission := foodVocab }
  let exactTypedForm : Form := {
    readyForm with
    rows := #[
      { locus := "food", amount := "170" },
      { locus := "paypay", amount := "-170" }]
    focus := ⟨3, by decide⟩ }
  let exactKnown := ["food", "food-stock"]
  let exactStart : State := { form := exactTypedForm }
  let exactPrepared := (update foodWorld exactKnown exactStart .other).state
  expect ((catalogCandidates exactPrepared).map (fun entry => entry.locus.token) == ["food", "food-stock"])
    "exact match was not ordered first in catalog candidates"
  expect ((selectedCatalogCandidate? exactPrepared).map (fun entry => entry.locus.token) == some "food")
    "exact match was not the default selected candidate"
  let exactEnter := (update foodWorld exactKnown exactStart .enter).state
  expect (exactEnter.form.rows[0]!.locus == "food")
    "Enter substituted exact typed Locus with another candidate"
  expect (exactEnter.form.focus.val == 4)
    "Enter from Locus did not advance to Amount field"
  let exactRight := (update foodWorld exactKnown exactStart .right).state
  expect (exactRight.form.rows[0]!.locus == "food")
    "Right substituted exact typed Locus with another candidate"
  expect (exactRight.form.focus.val == 4)
    "Right from Locus did not advance to Amount field"
  let exactDown := (update foodWorld exactKnown exactStart .down).state
  expect ((selectedCatalogCandidate? exactDown).map (fun entry => entry.locus.token) == some "food-stock")
    "Down did not select prefix neighbor candidate"
  let chosenEnter := (update foodWorld exactKnown exactDown .enter).state
  expect (chosenEnter.form.rows[0]!.locus == "food-stock")
    "Enter did not accept explicitly chosen candidate"

  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root w
    | throw (IO.userError "initialize fixture")
  let beforeReview ← IO.FS.readFile (root / "actual.loam")
  let .ok () ← Loam.MovementDraftReview.check root draft
    | throw (IO.userError "read-only Movement draft review")
  expect ((← IO.FS.readFile (root / "actual.loam")) == beforeReview)
    "Movement draft review changed Actual authority"
  -- An already-previewed draft must be re-admitted against policy changed during think time.
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root
      { w with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "change fixture policy")
  let before ← IO.FS.readFile (root / "actual.loam")
  let refusedReview ← Loam.MovementDraftReview.check root draft
  expect (!refusedReview.isOk) "Movement draft review bypassed current Locus policy"
  expect ((← IO.FS.readFile (root / "actual.loam")) == before)
    "refused Movement draft review changed authority"
  let refused ← Loam.MovementPublisher.publishDraft root.toString draft
  expect (!refused.isOk) "stale preview bypassed current Locus policy"
  expect ((← IO.FS.readFile (root / "actual.loam")) == before) "refusal changed authority"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root w
    | throw (IO.userError "restore fixture policy")
  let .ok eventId ← Loam.MovementPublisher.publishDraft root.toString draft
    | throw (IO.userError "canonical publish")
  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "canonical review reload")
  expect (records.length == 1) "reload did not see exactly one record"
  expect (records.any fun record => record.event.id.token == eventId.token &&
    record.description == "数学ガール" && record.date == some "2026-09-06")
    "fresh review lost published evidence"
  IO.println "TUI Record: signed postings, canonical catalog selection, read-only proposal review, admission, stale policy rejection, publication and fresh review passed."
