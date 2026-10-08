import Loam.Tui.ScheduledBulkEdit

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) : IO α :=
  match value with
  | .ok result => pure result
  | .error message => throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError "fixture admission")

private def change (locus : String) (amount : Int) : MovementChange LocusId :=
  { coordinate := ⟨locus⟩, quantity := Quantity.ofQuanta amount }

private def occurrence
    (id date : String) (amount : Int) (measure : String := "jpy") :
    IO (ScheduledOccurrence String) := do
  let movement ← requireSome (BalancedMovement.ofChanges? ⟨measure⟩
    [change "bank" (-amount), change "wifi" amount])
  return { id := ⟨id⟩, scheduledOn := date, movement }

private def press (state : Loam.Tui.ScheduledBulkEdit.State) (key : Loam.Tui.Terminal.Key) :
    Loam.Tui.ScheduledBulkEdit.State :=
  (Loam.Tui.ScheduledBulkEdit.update state key).state

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells => String.ofList (cells.map Cell.glyph)

private def contains (needle text : String) : Bool := (text.splitOn needle).length > 1

def main : IO Unit := do
  let first ← occurrence "first" "2026-11-08" 4800
  let second ← occurrence "second" "2026-12-08" 4800
  let exception ← occurrence "exception" "2027-01-08" 6000
  let overdue ← occurrence "overdue" "2026-09-08" 4800
  let paid ← occurrence "paid" "2026-10-08" 4800
  let cancelled ← occurrence "cancelled" "2026-11-09" 4800
  let old ← occurrence "old" "2026-11-08" 4800
  let usd ← occurrence "usd" "2026-11-08" 4800 "usd"
  let reverseMovement ← requireSome (BalancedMovement.ofChanges? ⟨"jpy"⟩
    [change "wifi" (-4800), change "bank" 4800])
  let reverse := { first with id := ⟨"reverse"⟩, movement := reverseMovement }
  let otherMovement ← requireSome (BalancedMovement.ofChanges? ⟨"jpy"⟩
    [change "other-bank" (-4800), change "wifi" 4800])
  let other := { first with id := ⟨"other-source"⟩, movement := otherMovement }
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences?
    [usd, cancelled, old, paid, overdue, exception, second, first, reverse, other])
  let terminals ← requireSome (ScheduledTerminalMemory.ofTerminals?
    [{ source := paid.id, target := some (.actual ⟨"actual-paid"⟩) },
     { source := cancelled.id, target := none },
     { source := old.id, target := some (.scheduled first.id) }])
  let event ← requireSome (Event.ofEffects? ⟨"actual-paid"⟩ [])
  let events ← requireSome (EventMemory.ofEvents? [event])
  let snapshot : Loam.ScheduledReview.EvidenceSnapshot := { scheduled, terminals, events }
  let candidates ← requireOk (Loam.ScheduledBulkEdit.candidates snapshot paid)
  expect (candidates.map (·.id.token) == ["overdue", "first", "second", "exception"])
    "candidate search guessed identity from amount, ignored Measure/signs, or included terminal sources"
  let initial := Loam.Tui.ScheduledBulkEdit.initial "reviewed-wire" paid candidates "2026-11-01"
  expect (initial.selected.isEmpty) "candidate sheet started with implicit selections"
  expect ((Loam.Tui.ScheduledBulkEdit.visibleCandidates initial).map (·.id.token) == ["first", "second", "exception"])
    "explicit start period was ignored"
  let invalid := press initial .enter
  expect (!invalid.notice.isEmpty) "empty amount entered selection"
  expect (!(Loam.ScheduledBulkEdit.validatePeriod "2026-02-29" "").isOk &&
    !(Loam.ScheduledBulkEdit.validatePeriod "2026-11-01" "2026-10-01").isOk)
    "invalid/reversed period admitted"
  let configured := { initial with amount := "5200", throughDate := "2027-01-08" }
  let selection := press configured .enter
  expect (selection.selected.isEmpty) "transition to selection checked candidates automatically"
  let all := press selection (.input 'a')
  let exceptional := press (press all .«end») (.input ' ')
  expect (exceptional.selected.map (·.token) == ["first", "second"])
    "mark sheet did not exclude the checked exception"
  let preview := press exceptional .enter
  let draft ← match preview.mode with
    | .preview draft => pure draft
    | _ => throw (IO.userError "preview was not constructed")
  expect (draft.observedWire == "reviewed-wire" && draft.drafts.map (·.source.token) == ["first", "second"])
    "preview widened selection or rebound its observed wire"
  for replacement in draft.drafts do
    expect ((replacement.movement.quantityAt ⟨"wifi"⟩).quanta == 5200 &&
      replacement.movement.measure == first.measure) "preview changed Measure or amount"
  expect ((Loam.Tui.ScheduledBulkEdit.update preview .enter).publish.isNone)
    "preview default action published without a deliberate choice"
  let publishStep := Loam.Tui.ScheduledBulkEdit.update (press preview .tab) .enter
  expect (publishStep.publish.isSome && !publishStep.cancel) "Publish all did not emit batch intent"
  expect ((Loam.Tui.ScheduledBulkEdit.update (press (press preview .tab) .tab) .enter).cancel)
    "preview Cancel did not cancel"
  let back := press preview .escape
  expect (back.selected == exceptional.selected) "back from preview lost explicit checks"
  let parameters := press back (.input 'e')
  let reset := press { parameters with fromDate := "2026-12-08", throughDate := "2026-12-08" } .enter
  expect (reset.selected.isEmpty && (Loam.Tui.ScheduledBulkEdit.visibleCandidates reset).map (·.id.token) == ["second"])
    "changing period retained hidden selected IDs or ignored inclusive date bounds"
  expect ((press (press selection (.input 'a')) (.input 'd')).selected.isEmpty)
    "clear did not uncheck all candidates"
  let overdueState := press { configured with fromDate := "2026-09-08" } .enter
  expect ((Loam.Tui.ScheduledBulkEdit.visibleCandidates overdueState).head?.map (·.id.token) == some "overdue")
    "explicitly widened period silently dropped overdue evidence"
  expect (!(Loam.ScheduledBulkEdit.amountDrafts candidates [] 5200).isOk &&
    !(Loam.ScheduledBulkEdit.amountDrafts candidates [first.id, first.id] 5200).isOk &&
    !(Loam.ScheduledBulkEdit.amountDrafts [first] [second.id] 5200).isOk &&
    !(Loam.ScheduledBulkEdit.withAmount first 0).isOk)
    "empty/duplicated/missing/zero selection was admitted"
  let noOpDrafts ← requireOk (Loam.ScheduledBulkEdit.amountDrafts [first, exception] [first.id, exception.id] 4800)
  expect (noOpDrafts.map (·.source.token) == ["exception"])
    "unchanged amounts generated unnecessary replacement facts"
  let splitMovement ← requireSome (BalancedMovement.ofChanges? ⟨"jpy"⟩
    [change "bank" (-4800), change "wifi" 4000, change "wifi" 800])
  let split := { first with id := ⟨"split"⟩, movement := splitMovement }
  expect (!(Loam.ScheduledBulkEdit.withAmount split 5200).isOk)
    "bulk amount silently allocated a split movement"

  -- Decimal Measures use exact existing presentation, never integer-only currency assumptions.
  let usdState := Loam.Tui.ScheduledBulkEdit.initial "usd-wire" usd [usd] "2026-11-01"
    [{ measure := ⟨"usd"⟩, scale := 2 }]
  let usdPreview := press (press (press { usdState with amount := "52.01" } .enter) (.input 'a')) .enter
  match usdPreview.mode with
  | .preview draft =>
      let replacement ← requireSome draft.drafts.head?
      expect ((replacement.movement.quantityAt ⟨"wifi"⟩).quanta == 5201)
        "decimal amount was rounded or interpreted as integer units"
  | _ => throw (IO.userError "decimal preview")
  expect (!(press { usdState with amount := "52.001" } .enter).notice.isEmpty)
    "excess decimal precision was rounded"

  -- Every candidate and preview remains reachable in a short terminal viewport.
  let longCandidates ← (List.range 30).mapM fun index => occurrence
    ("candidate-" ++ toString index) "2026-11-08" (4800 + Int.ofNat index)
  let longState := Loam.Tui.ScheduledBulkEdit.initial "long-wire" first longCandidates "2026-11-01"
  let longSheet := press (press { longState with amount := "5200" } .enter) .«end»
  for bounds in ([{ width := 80, height := 18 }, { width := 40, height := 18 }] : List Bounds) do
    let sheetWidget := Loam.Tui.ScheduledBulkEdit.view bounds longSheet
    expect (sheetWidget.lines.length == bounds.height - 1) "candidate footer escaped finite viewport"
    for cells in sheetWidget.lines do
      expect (Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <= bounds.width - 1)
        "candidate view overflowed the reserved terminal width"
    let text := widgetText sheetWidget
    expect (contains "[Space] check" text && contains "[Enter] preview" text)
      "candidate actions were clipped on a narrow terminal"
  let bounds : Bounds := { width := 80, height := 18 }
  expect (contains "candidate-29" (widgetText (Loam.Tui.ScheduledBulkEdit.view bounds longSheet)))
    "candidate cursor became invisible below viewport"
  let longPreview := press (press (press longSheet (.input 'a')) .enter) .«end»
  let text := widgetText (Loam.Tui.ScheduledBulkEdit.view bounds longPreview)
  expect (contains "candidate-29" text && contains "Publish all" text && contains "30 replacements" text)
    "preview truncated targets or lost its final action"

  IO.println "Scheduled bulk edit TUI: advisory candidates, explicit checks/range, safe preview, exception/no-op/split behavior, exact decimal amounts and bounded viewports passed."
