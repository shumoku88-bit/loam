import Loam.Tui.Balances

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def coordinate (locus : String) : EffectCoordinate :=
  ⟨⟨locus⟩, ⟨"jpy"⟩⟩

private def exactRow
    (locus : String) (quanta : Int) : Loam.BalanceReview.Row :=
  {
    coordinate := coordinate locus
    quantity := Quantity.ofQuanta quanta
  }

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def press (bounds : Bounds) (state : Loam.Tui.Balances.State)
    (key : Loam.Tui.Terminal.Key) (repeatCount : Nat := 1) : IO Loam.Tui.Balances.State :=
  match Loam.Tui.Balances.update bounds state key repeatCount with
  | .stay next => pure next
  | .back => throw (IO.userError "unexpected parent back")

private def compact (text : String) : String :=
  String.ofList (text.toList.filter fun char => char != ' ' && char != '\n' && char != '│')

private def rowIndex (needle : String) (view : Widget) : IO Nat :=
  requireSome (view.lines.findIdx? fun cells => contains needle (String.ofList (cells.map Cell.glyph)))
    ("missing rendered row: " ++ needle)

private def testFramesAndPaging : IO Unit := do
  let rows : List Loam.Tui.Balances.Row := (List.range 30).map fun i =>
    .exact ⟨⟨s!"ROW-{i}#"⟩, ⟨if i % 2 == 0 then "jpy" else "usd"⟩⟩ (Quantity.ofQuanta (Int.ofNat i))
  let state : Loam.Tui.Balances.State := {rows}
  for bounds in [{width := 48, height := 14}, {width := 80, height := 24},
      {width := 119, height := 20}, {width := 120, height := 30}, {width := 150, height := 45}] do
    let before := Loam.Tui.Balances.viewForBounds bounds state
    let after := Loam.Tui.Balances.viewForBounds bounds {state with notice := "Print refused."}
    expect (before.lines.length == bounds.height - 1 && after.lines.length == before.lines.length)
      "Balances exceeded usable terminal height"
    expect (contains "╭" (widgetText before) && contains "╰" (widgetText before) &&
      !contains "====" (widgetText before)) "Balances lost quiet rounded frames"
    let borders : Widget → List Nat := fun view => view.lines.zipIdx.filterMap fun (cells, index) =>
      let line := String.ofList (cells.map Cell.glyph)
      if contains "╭" line || contains "╰" line then some index else none
    expect (borders before == borders after) "one-line balance feedback moved frame geometry"
    expect ((← rowIndex "[q] back" after) == bounds.height - 3 &&
      contains "Print refused." (widgetText after)) "fixed balance navigation/feedback disappeared"
    for cells in before.lines do
      expect (Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
        "Balances exceeded writable terminal columns"
    expect (before.lines.flatten.all fun cell => cell.style == .normal || cell.style == .muted ||
      cell.style == .series1 || cell.style == .selected) "Balances added decorative accent colors"
    let top ← rowIndex "╭ Balances" before
    let bottom ← rowIndex "╰ 1/30" before
    let visible := bottom - top - 2 -- borders and column heading
    let paged ← press bounds state .pageDown
    expect (paged.selectedRow == min 29 (max 1 visible) && paged.rows == rows) "balance page ignored visible data rows"
    let last ← press bounds paged .«end»
    expect (last.selectedRow == 29 && contains "ROW-29#" (widgetText (Loam.Tui.Balances.viewForBounds bounds last)))
      "selected final balance remained off-screen"
    let first ← press bounds last .home
    expect (first.selectedRow == 0) "balance Home missed first coordinate"
    let batched ← press bounds first .down 100
    expect (batched.selectedRow == 29 && batched.rows == rows) "batched balance movement changed evidence or escaped bounds"
    let detail ← press bounds batched .enter
    expect (detail.detailFocused && detail.selectedRow == 29 && detail.rows == rows)
      "balance Detail changed selected coordinate/evidence"
    let detailView := Loam.Tui.Balances.viewForBounds bounds detail
    expect (!detailView.lines.flatten.any fun cell => cell.style == .selected)
      "inactive balance table retained keyboard-focus selection background"
    let list ← press bounds detail .escape
    expect (!list.detailFocused && list.selectedRow == 29) "balance Detail back lost selection"
    expect (match Loam.Tui.Balances.update bounds list (.input 'q') with | .back => true | _ => false)
      "balance list back failed to return to parent"
    let fresh := Loam.Tui.Balances.normalizedForBounds bounds {last with rows := rows.take 2}
    expect (fresh.selectedRow == 1) "presentation refresh retained an invalid selection"

private def detailContent (view : Widget) : List String :=
  let lines := view.lines.map fun cells => String.ofList (cells.map Cell.glyph)
  ((lines.dropWhile fun line => !contains "╭ Selected balance" line).drop 1).takeWhile fun line => !contains "╰" line

private def testWrappedDetails : IO Unit := do
  let locus := String.ofList (List.replicate 60 '界') ++ "-locus-tail"
  let measure := "measure-" ++ String.ofList (List.replicate 50 'x') ++ "-measure-tail"
  let huge : Int := 12345678901234567890123456789012345678901234567890123456789012345678901234567890
  let row : Loam.Tui.Balances.Row := .exact ⟨⟨locus⟩, ⟨measure⟩⟩ (Quantity.ofQuanta (-huge))
  let state : Loam.Tui.Balances.State := {rows := [row]}
  for bounds in [{width := 48, height := 14}, {width := 80, height := 24}, {width := 119, height := 20}] do
    let listText := widgetText (Loam.Tui.Balances.viewForBounds bounds state)
    expect (contains "…" listText && contains "see details" listText)
      "balance table silently clipped full coordinate or quantity digits"
    let mut current ← press bounds state (.input 'i')
    let mut seen := String.intercalate "\n" (detailContent (Loam.Tui.Balances.viewForBounds bounds current))
    for _ in List.range 200 do
      let next ← press bounds current .down
      if next.detailScroll == current.detailScroll then break
      current := next
      seen := seen ++ "\n" ++ (detailContent (Loam.Tui.Balances.viewForBounds bounds current)).getLast!
    let grouped := Loam.MeasurePresentation.groupDisplayedNumber (toString (-huge))
    expect (contains locus (compact seen) && contains measure (compact seen) && contains grouped (compact seen))
      "wrapped balance Detail lost full Locus, Measure or exact signed digits"
    expect (current.rows == [row] && current.selectedRow == 0) "detail scroll changed balance evidence"
    let maximum := current.detailScroll
    let up ← press bounds current .up
    expect (up.detailScroll + 1 == maximum) "one up step did not leave exact balance Detail bottom"
    let top ← press bounds up .home
    expect (top.detailScroll == 0) "balance Detail Home missed top"
    let last ← press bounds top .«end»
    expect (last.detailScroll == maximum) "balance Detail End missed true bottom"
    let resized := Loam.Tui.Balances.normalizedForBounds {width := 150, height := 45} last
    expect (resized.detailFocused && resized.rows == [row] && resized.detailScroll ≤ maximum)
      "balance resize changed meaning or failed to clamp its offset"
  let notice := String.ofList (List.replicate 65 '界') ++ "通知末尾"
  let notified := Loam.Tui.Balances.viewForBounds {width := 48, height := 14} {state with notice}
  expect (contains notice (compact (widgetText notified))) "balance refusal feedback lost its cause"
  let overflow := Loam.Tui.Balances.viewForBounds {width := 48, height := 14}
    {state with notice := String.ofList (List.replicate 600 '界')}
  expect (overflow.lines.length == 13 && contains "more feedback/help; enlarge terminal" (widgetText overflow))
    "over-height balance feedback silently disappeared"
  match Loam.Tui.Balances.preparePrint state with
  | .error message => throw (IO.userError message)
  | .ok prepared =>
      let printed := String.intercalate "\n" prepared.lines
      let grouped := Loam.MeasurePresentation.groupDisplayedNumber (toString (-huge))
      expect (contains locus printed && contains measure printed && contains grouped printed)
        "Print clipped coordinate or exact quantity like the old table"

private def testPrintAndSupportStates : IO Unit := do
  let dollars : EffectCoordinate := ⟨⟨"wallet"⟩, ⟨"usd"⟩⟩
  let snapshot : Loam.CurrentBalanceReview.Snapshot := {
    rows := [exactRow "wallet" 70, {coordinate := dollars, quantity := Quantity.ofQuanta (-20)}]
  }
  let mixed := Loam.Tui.Balances.initial snapshot [dollars, coordinate "wallet", dollars]
  expect (mixed.rows == [.exact dollars (Quantity.ofQuanta (-20)),
    .exact (coordinate "wallet") (Quantity.ofQuanta 70)])
    "selection collapsed Measures, changed order, or fabricated a combined balance"
  let state : Loam.Tui.Balances.State := {
    rows := [.exact (coordinate "zero") (Quantity.ofQuanta 0),
      .knownPresent (coordinate "present"), .unsupported (coordinate "unsupported")]
  }
  let prepared ← match Loam.Tui.Balances.preparePrint state with
    | .ok report => pure report
    | .error message => throw (IO.userError message)
  let printText := String.intercalate "\n" prepared.lines
  expect (contains "zero  0 jpy  exact" printText && contains "? jpy  present, amount unknown" printText &&
    contains "? jpy  unsupported" printText) "Print collapsed support states or exact zero"
  for index in [1, 2] do
    let selected : Loam.Tui.Balances.State := {state with selectedRow := index, detailFocused := true}
    let bounds : Bounds := {width := 48, height := 14}
    let first := Loam.Tui.Balances.viewForBounds bounds selected
    let last ← press bounds selected .«end»
    let reviewed := widgetText first ++ "\n" ++ widgetText (Loam.Tui.Balances.viewForBounds bounds last)
    expect (contains (if index == 1 then "present, amount unknown" else "unsupported") reviewed &&
      contains "not" reviewed) "balance support distinction was not reviewable in compact Detail"
  let atLimit : Loam.Tui.Balances.State := {rows := List.replicate 194 (.exact (coordinate "cash") (Quantity.ofQuanta 0))}
  expect ((Loam.Tui.Balances.preparePrint atLimit).isOk) "bounded Print refused its allowed line count"
  expect (!(Loam.Tui.Balances.preparePrint {atLimit with rows := atLimit.rows ++ [.unsupported (coordinate "extra")]}).isOk)
    "bounded Print bypassed its 200-line refusal"
  let oversized : Loam.Tui.Balances.State := {
    rows := [.unsupported ⟨⟨String.ofList (List.replicate 32768 'x')⟩, ⟨"jpy"⟩⟩]
  }
  expect (!(Loam.Tui.Balances.preparePrint oversized).isOk) "unclipped Print bypassed its UTF-8 byte limit"

private def testEmptyAndTiny : IO Unit := do
  let empty : Loam.Tui.Balances.State := {rows := []}
  for bounds in [{width := 12, height := 5}, {width := 24, height := 8},
      {width := 48, height := 14}, {width := 80, height := 24}, {width := 150, height := 45}] do
    for focused in [false, true] do
      let state := {empty with detailFocused := focused}
      let view := Loam.Tui.Balances.viewForBounds bounds state
      expect (view.lines.length ≤ bounds.height - 1 && view.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
        "empty balance projection escaped tiny terminal bounds"
      expect (!contains "Quanta: 0" (widgetText view)) "empty selection manufactured exact zero"
      let last ← press bounds state .«end»
      expect (last.rows.isEmpty && last.selectedRow == 0)
        "empty balance endpoint manufactured a row"
      expect ((← press bounds last .«end») == last) "empty Detail scrolled beyond its wrapped explanation"
  expect (contains "No balances are selected" (widgetText (Loam.Tui.Balances.view empty)))
    "empty selection disappeared without explanation"

def main : IO Unit := do
  let snapshot : Loam.CurrentBalanceReview.Snapshot := {
    rows := [exactRow "wallet" 70, exactRow "cash" 0]
    knownPresent := [coordinate "wifi-debt"]
    unsupported := [coordinate "mystery"]
  }
  let selection :=
    [coordinate "wallet", coordinate "cash", coordinate "wifi-debt",
      coordinate "mystery", coordinate "wallet"]
  let state := Loam.Tui.Balances.initial snapshot selection
  let text := widgetText (Loam.Tui.Balances.view state)

  expect (state.rows.length == 4) "duplicate balance-view row was not normalized"
  expect (contains "Balances / Current" text) "Balances heading missing"
  expect (contains "wallet" text && contains "70 jpy" text) "exact current balance missing"
  expect (contains "cash" text && contains "0 jpy" text) "exact zero balance was hidden"
  expect (contains "wifi-debt" text && contains "present, amount unknown" text)
    "known-present amount-unknown balance was collapsed to unsupported"
  expect (contains "mystery" text && contains "unsupported" text)
    "unsupported selected balance was hidden"
  expect (contains "not an Account taxonomy" text) "neutral Locus boundary missing"
  expect (contains "balance-view order only" text) "presentation-order boundary missing"

  match Loam.Tui.Balances.update {width := 80, height := 24} state (.input 'q') with
  | .back => pure ()
  | _ => throw (IO.userError "Balances back intent failed")

  let emptyText :=
    widgetText
      (Loam.Tui.Balances.view
        (Loam.Tui.Balances.initial snapshot []))
  expect (contains "No balances are selected" emptyText) "empty balance-view message missing"

  testFramesAndPaging
  testWrappedDetails
  testPrintAndSupportStates
  testEmptyAndTiny
  IO.println
    "TUI Balances: quiet frames, paging/details, exact/unknown/unsupported states and bounded unclipped Print passed."
