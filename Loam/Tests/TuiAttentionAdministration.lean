import Loam.Review.AttentionReview
import Loam.HouseholdCommand
import Loam.Tui.AttentionAdministration
import Loam.Authority.HouseholdAuthority

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def due : Attention String :=
  { id := ⟨"attention-due"⟩
    context := "cancel subscription"
    due := .dueOn "2026-10-01" }

private def noDue : Attention String :=
  { id := ⟨"attention-no-due"⟩
    context := "watch refund"
    due := .noDueDate }

private def unknownDue : Attention String :=
  { id := ⟨"attention-unknown"⟩
    context := "watch unexpected income timing"
    due := .dueUndetermined }

private def typeText
    (state : Loam.Tui.AttentionAdministration.State)
    (text : String) : Loam.Tui.AttentionAdministration.State :=
  text.toList.foldl
    (fun current char =>
      (Loam.Tui.AttentionAdministration.update current (.input char)).state)
    state

private def compact (text : String) : String :=
  String.ofList (text.toList.filter fun char => char != ' ' && char != '\n' && char != '│')

private def contentRows (view : Widget) (title : String) : List String :=
  let rows := view.lines.map fun cells => String.ofList (cells.map Cell.glyph)
  ((rows.dropWhile fun row => !contains ("╭ " ++ title) row).drop 1).takeWhile fun row => !contains "╰" row

private def testBoundedPresentation : IO Unit := do
  let items : List (Attention String) := (List.range 30).map fun i => {
    id := ⟨s!"attention-{i + 1}"⟩
    context := s!"MATTER-{i + 1}#"
    due := if i % 3 == 0 then .dueOn "2026-10-01" else if i % 3 == 1 then .noDueDate else .dueUndetermined
  }
  let initial := Loam.Tui.AttentionAdministration.initial (.available {openItems := items}) "2026-09-16"
  for bounds in [{width := 48, height := 14}, {width := 80, height := 24},
      {width := 100, height := 30}, {width := 150, height := 45}] do
    let step := Loam.Tui.AttentionAdministration.updateForBounds bounds initial .«end»
    expect (!step.back && step.add.isNone && step.close.isNone && step.state.cursor == 29)
      "Attention endpoint navigation emitted intent or missed the last item"
    let view := Loam.Tui.AttentionAdministration.viewForBounds bounds step.state
    expect (view.lines.length == bounds.height - 1 && view.lines.all fun cells =>
      Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ bounds.width - 1)
      "Attention frame escaped usable terminal geometry"
    expect (contains "MATTER-30#" (widgetText view) && contains "╭ Open [active]" (widgetText view) &&
      !contains "====" (widgetText view)) "Attention selection remained outside the quiet bounded list"
    expect (view.lines.flatten.all fun cell => cell.style == .normal || cell.style == .muted ||
      cell.style == .series1 || cell.style == .selected) "Attention added decorative colors"
    let first := (Loam.Tui.AttentionAdministration.updateForBounds bounds step.state .home).state
    let paged := Loam.Tui.AttentionAdministration.updateForBounds bounds first .pageDown
    expect (paged.state.cursor > 0 && paged.state.cursor < 30 && paged.add.isNone && paged.close.isNone)
      "Attention paging manufactured a target or publication"
    let focused := (Loam.Tui.AttentionAdministration.updateForBounds bounds step.state (.input 'i')).state
    expect (focused.detailFocused && focused.cursor == 29) "Attention Detail changed identity"
    let detail := Loam.Tui.AttentionAdministration.viewForBounds bounds focused
    expect (!detail.lines.flatten.any fun cell => cell.style == .selected) "inactive Attention list kept selection background"
    let back := Loam.Tui.AttentionAdministration.updateForBounds bounds focused .escape
    expect (!back.back && !back.state.detailFocused && back.state.cursor == 29) "Detail back escaped the workspace"
    let confirm := (Loam.Tui.AttentionAdministration.updateForBounds bounds step.state (.input 'x')).state
    let scrolled := Loam.Tui.AttentionAdministration.updateForBounds bounds confirm .«end»
    expect (scrolled.close.isNone && scrolled.add.isNone && scrolled.state.mode == confirm.mode)
      "confirmation review changed frozen target or emitted a write"
    let published := Loam.Tui.AttentionAdministration.updateForBounds bounds scrolled.state .enter
    expect (published.close.map (·.attention) == some ⟨"attention-30"⟩) "closure confirmed an off-screen/wrong identity"
    let oneLine := Loam.Tui.AttentionAdministration.viewForBounds bounds {step.state with notice := "Publication refused."}
    let borders : Widget → List Nat := fun widget => widget.lines.zipIdx.filterMap fun (cells, i) =>
      let row := String.ofList (cells.map Cell.glyph)
      if contains "╭" row || contains "╰" row then some i else none
    expect (borders view == borders oneLine) "one-line Attention feedback shifted the frames"
  let bounds : Bounds := {width := 48, height := 14}
  let longContext := String.ofList (List.replicate 90 '界') ++ "-context-tail"
  let longId := "attention-" ++ String.ofList (List.replicate 60 'x') ++ "-id-tail"
  let item : Attention String := {id := ⟨longId⟩, context := longContext, due := .dueUndetermined}
  let longState := Loam.Tui.AttentionAdministration.initial (.available {openItems := [item]}) "2026-09-16"
  for (mode, title) in [(Loam.Tui.AttentionAdministration.Mode.browse, "Selected matter"),
      (.newDue longContext, "Due meaning"), (.newDate longContext "2026-10-01", "Due date"),
      (.confirmClose item.id .resolved, "resolve confirmation"), (.confirmClose item.id .dropped, "drop confirmation")] do
    let mut state := {longState with mode, detailFocused := mode == .browse}
    let mut seen := String.intercalate "\n" (contentRows (Loam.Tui.AttentionAdministration.viewForBounds bounds state) title)
    for _ in List.range 100 do
      let next := Loam.Tui.AttentionAdministration.updateForBounds bounds state .down
      -- Due/date modes review using pages, since j/k remain ordinary input.
      let next := if mode == .browse || (match mode with | .confirmClose _ _ => true | _ => false) then next
        else Loam.Tui.AttentionAdministration.updateForBounds bounds state .pageDown
      expect (next.add.isNone && next.close.isNone && !next.back) "review navigation published/cancelled a draft"
      if next.state.contentScroll == state.contentScroll then break
      if mode == .browse || (match mode with | .confirmClose _ _ => true | _ => false) then
        seen := seen ++ "\n" ++ (contentRows (Loam.Tui.AttentionAdministration.viewForBounds bounds next.state) title).getLast!
      else
        seen := seen ++ "\n" ++ String.intercalate "\n" (contentRows (Loam.Tui.AttentionAdministration.viewForBounds bounds next.state) title)
      state := next.state
    expect (contains "-context-tail" seen) "Attention full review lost the context tail"
    if mode == .browse then
      expect (contains longContext (compact seen) && contains longId (compact seen))
        "Attention Detail lost full Unicode context or identity"
    let endState := Loam.Tui.AttentionAdministration.updateForBounds bounds state .«end»
    expect ((Loam.Tui.AttentionAdministration.updateForBounds bounds endState.state .«end»).state.contentScroll == endState.state.contentScroll)
      "Attention review exceeded true bottom"
    let cancel := Loam.Tui.AttentionAdministration.updateForBounds bounds endState.state .escape
    expect (cancel.add.isNone && cancel.close.isNone) "review cancel emitted a publication"
  let typed := Loam.Tui.AttentionAdministration.updateForBounds bounds {longState with mode := .newContext ""}
    (.paste (longContext ++ "\nnot part of a single-line field"))
  expect (typed.state.mode == .newContext longContext && typed.add.isNone) "paste changed context or published before due choice"
  expect (contains "-context-tail" (widgetText (Loam.Tui.AttentionAdministration.viewForBounds bounds typed.state)))
    "Attention input tail/IME focus disappeared"
  let qText := Loam.Tui.AttentionAdministration.updateForBounds bounds typed.state (.input 'q')
  expect (!qText.back && qText.state.mode == .newContext (longContext ++ "q")) "text q became application back"
  let next := Loam.Tui.AttentionAdministration.updateForBounds bounds typed.state .enter
  expect (next.add.isNone && next.state.mode == .newDue longContext) "Context Enter acquired publication authority"
  let published := Loam.Tui.AttentionAdministration.updateForBounds bounds next.state (.input 'u')
  expect (published.add.map (·.context) == some longContext &&
    published.add.map (·.due) == some AttentionDue.dueUndetermined)
    "input-tail/full-review presentation clipped the emitted context or changed due meaning"
  let notice := String.ofList (List.replicate 80 '界') ++ "通知末尾"
  let notified := Loam.Tui.AttentionAdministration.viewForBounds bounds {longState with notice}
  expect (contains notice (compact (widgetText notified))) "Attention feedback lost Japanese cause"
  let overflow := Loam.Tui.AttentionAdministration.viewForBounds bounds {longState with notice := String.ofList (List.replicate 600 '界')}
  expect (overflow.lines.length == 13 && contains "more feedback/help; enlarge terminal" (widgetText overflow))
    "Attention over-height feedback silently disappeared"
  for small in [{width := 12, height := 5}, {width := 24, height := 8}] do
    for mode in [Loam.Tui.AttentionAdministration.Mode.browse, .newContext longContext, .newDue longContext,
        .newDate longContext "2026-10-01", .confirmClose item.id .dropped] do
      let view := Loam.Tui.AttentionAdministration.viewForBounds small {longState with mode}
      expect (view.lines.length ≤ small.height - 1 && view.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) ≤ small.width - 1)
        "Attention editor escaped tiny bounds"

def main : IO Unit := do
  testBoundedPresentation
  let admin0 := Loam.Tui.AttentionAdministration.initial .unavailable "2026-09-16"
  let adminText := widgetText (Loam.Tui.AttentionAdministration.view admin0)
  expect (contains "No canonical Attention stream yet" adminText && !contains "0 open" adminText)
    "administration hid the unavailable bootstrap state or relabelled it as zero open"
  expect (contains "Press n to create the first household matter" adminText)
    "administration did not expose the first-write entrance"

  let emptyAdmin := Loam.Tui.AttentionAdministration.initial
    (.available { openItems := [] }) "2026-09-16"
  let emptyText := widgetText (Loam.Tui.AttentionAdministration.view emptyAdmin)
  expect (contains "0 open" emptyText)
    "explicit empty Attention source did not remain distinct from unavailable"
  expect (!contains "No canonical Attention stream yet" emptyText)
    "explicit empty Attention source collapsed into unavailable"

  let new0 := (Loam.Tui.AttentionAdministration.update admin0 (.input 'n')).state
  let new1 := typeText new0 "watch refund"
  let new2 := (Loam.Tui.AttentionAdministration.update new1 .enter).state
  let addUnknown := Loam.Tui.AttentionAdministration.update new2 (.input 'u')
  match addUnknown.add with
  | some draft =>
      expect (draft.context == "watch refund") "new Attention context changed before publication"
      expect (draft.due == AttentionDue.dueUndetermined)
        "unknown due meaning collapsed during TUI creation"
  | none => throw (IO.userError "Attention new-item wizard did not emit publication intent")

  let dated0 := (Loam.Tui.AttentionAdministration.update admin0 (.input 'n')).state
  let dated1 := typeText dated0 "cancel subscription"
  let dated2 := (Loam.Tui.AttentionAdministration.update dated1 .enter).state
  let dated3 := (Loam.Tui.AttentionAdministration.update dated2 (.input 'd')).state
  let dated4 := typeText dated3 "2026-10-01"
  let datedStep := Loam.Tui.AttentionAdministration.update dated4 .enter
  match datedStep.add with
  | some draft =>
      expect (draft.context == "cancel subscription") "dated Attention context changed"
      expect (draft.due == AttentionDue.dueOn "2026-10-01")
        "known due date changed before publication"
  | none => throw (IO.userError "dated Attention wizard did not emit publication intent")

  let noDue0 := (Loam.Tui.AttentionAdministration.update admin0 (.input 'n')).state
  let noDue1 := typeText noDue0 "watch refund without promised date"
  let noDue2 := (Loam.Tui.AttentionAdministration.update noDue1 .enter).state
  let addNoDue := Loam.Tui.AttentionAdministration.update noDue2 (.input 'n')
  match addNoDue.add with
  | some draft =>
      expect (draft.due == AttentionDue.noDueDate)
        "no-due meaning collapsed during TUI creation"
  | none => throw (IO.userError "no-due Attention wizard did not emit publication intent")

  -- Empty context is refused before choosing due meaning.
  let emptyContext := (Loam.Tui.AttentionAdministration.update new0 .enter).state
  expect (emptyContext.mode == .newContext "") "empty context advanced to due meaning"
  expect (contains "Enter a short household matter" emptyContext.notice)
    "empty context did not show descriptive feedback"

  -- Invalid calendar date is refused in dated due mode.
  let invalidDate0 := typeText dated3 "2026-02-31"
  let invalidStep := Loam.Tui.AttentionAdministration.update invalidDate0 .enter
  expect (invalidStep.add.isNone) "invalid date emitted publication intent"
  expect (invalidStep.state.mode == .newDate "cancel subscription" "2026-02-31")
    "invalid date left date editor"
  expect (contains "Enter a real calendar date in YYYY-MM-DD form" invalidStep.state.notice)
    "invalid date did not produce calendar feedback"

  -- Back navigation from browse mode.
  expect (Loam.Tui.AttentionAdministration.update admin0 .escape).back
    "Esc did not return back intent"
  expect (Loam.Tui.AttentionAdministration.update admin0 (.input 'q')).back
    "q did not return back intent"
  expect (!(Loam.Tui.AttentionAdministration.update admin0 (.input 'b')).back)
    "retired b back alias survived"

  -- Selection bounds: moveCursor cycles.
  let openEvidence : Loam.AttentionReview.Availability :=
    .available { openItems := [due, noDue, unknownDue] }
  let adminOpen := Loam.Tui.AttentionAdministration.initial openEvidence "2026-09-16"
  let upSelected := (Loam.Tui.AttentionAdministration.update adminOpen .up).state
  expect (upSelected.cursor == 2) "Up from top did not cycle to bottom"
  let downSelected := (Loam.Tui.AttentionAdministration.update upSelected .down).state
  expect (downSelected.cursor == 0) "Down from bottom did not cycle to top"
  let kSelected := (Loam.Tui.AttentionAdministration.update adminOpen (.input 'k')).state
  expect (kSelected.cursor == 2) "k from top did not match Up navigation"
  let jSelected := (Loam.Tui.AttentionAdministration.update kSelected (.input 'j')).state
  expect (jSelected.cursor == 0) "j from bottom did not match Down navigation"

  let resolveConfirm :=
    (Loam.Tui.AttentionAdministration.update adminOpen (.input 'r')).state
  let resolveStep := Loam.Tui.AttentionAdministration.update resolveConfirm .enter
  match resolveStep.close with
  | some draft =>
      expect (draft.attention == due.id) "resolve intent changed selected Attention identity"
      expect (draft.knownOn == "2026-09-16") "resolve intent lost explicit current date"
      expect (draft.kind == AttentionClosureKind.resolved) "resolve intent changed closure kind"
  | none => throw (IO.userError "resolve confirmation did not emit closure intent")

  let secondSelected := (Loam.Tui.AttentionAdministration.update adminOpen .down).state
  let dropConfirm :=
    (Loam.Tui.AttentionAdministration.update secondSelected (.input 'x')).state
  let dropStep := Loam.Tui.AttentionAdministration.update dropConfirm .enter
  match dropStep.close with
  | some draft =>
      expect (draft.attention == noDue.id) "drop intent changed selected Attention identity"
      expect (draft.kind == AttentionClosureKind.dropped) "drop intent changed closure kind"
  | none => throw (IO.userError "drop confirmation did not emit closure intent")

  -- Publisher refusal leaves evidence untouched and displays the error notice.
  let errorState := Loam.Tui.AttentionAdministration.withPublishError adminOpen "publication refused"
  expect (errorState.mode == .browse) "error did not return to browse mode"
  expect (errorState.notice == "publication refused") "error notice was not preserved"
  match errorState.evidence with
  | .available snap =>
      expect (snap.openItems.map Attention.id == [due.id, noDue.id, unknownDue.id])
        "publisher refusal corrupted evidence"
  | .unavailable => throw (IO.userError "publisher refusal made evidence unavailable")

  -- Attention / Manage entrance view verification.
  let manageText := widgetText (Loam.Tui.AttentionAdministration.view adminOpen)
  expect (contains "Attention / Manage" manageText) "view missing Attention / Manage heading"
  expect (contains "Household matters that should not disappear from view" manageText)
    "view missing descriptive subtitle"
  expect (contains "[j/k] select" manageText && contains "[n] new [r] resolve [x] drop" manageText)
    "view missing stable action help footer"
  expect (contains "due 2026-10-01" manageText)
    "known due meaning was not rendered in the production Attention surface"
  expect (contains "no due date" manageText)
    "no-due meaning was not rendered in the production Attention surface"
  expect (contains "due unknown" manageText)
    "unknown-due meaning was not rendered in the production Attention surface"

  -- End-to-end lifecycle in an isolated temporary directory:
  -- 1. Installed HouseholdImage with absent Attention produces unavailable bootstrap view.
  -- 2. addAttention installs the first HouseholdImage Attention section.
  -- 3. Reloading HouseholdImage evidence reflects the new item in Attention / Manage.
  -- 4. closeAttention resolves the item.
  -- 5. Reloading evidence reflects 0 open items.
  let tmpRoot ← IO.FS.createTempDir
  try

    let .ok _ ← Loam.HouseholdAuthority.installInitial? tmpRoot { sections := [] }
      | throw (IO.userError "TUI Attention HouseholdImage bootstrap failed")
    let initialLoad ← Loam.AttentionReview.loadHouseholdEvidence tmpRoot
    match initialLoad with
    | .ok .unavailable => pure ()
    | _ => throw (IO.userError "bootstrap did not report unavailable")
    let bootstrapAdmin := Loam.Tui.AttentionAdministration.initial .unavailable "2026-09-16"
    let bootstrapText := widgetText (Loam.Tui.AttentionAdministration.view bootstrapAdmin)
    expect (contains "Attention / Manage" bootstrapText) "view missing Attention / Manage heading"
    expect (contains "No canonical Attention stream yet" bootstrapText) "bootstrap missing stream text"

    -- Publish a new attention item
    let addDraft : Loam.AttentionPublisher.AddDraft := {
      context := "renew passport"
      due := .dueOn "2026-11-20"
    }
    let addedId ←
      match ← Loam.HouseholdCommand.addAttention tmpRoot addDraft with
      | .ok id => pure id
      | .error message => throw (IO.userError message)
    expect (addedId.token == "attention-1") "first attention id unexpected"

    -- Reload evidence and refresh administration view
    let reloadedLoad ← Loam.AttentionReview.loadHouseholdEvidence tmpRoot
    let .ok reloadedEvidence := reloadedLoad | throw (IO.userError "reloading evidence failed")
    let adminRefreshed := Loam.Tui.AttentionAdministration.initial reloadedEvidence "2026-09-16"
    let refreshedText := widgetText (Loam.Tui.AttentionAdministration.view adminRefreshed)
    expect (contains "renew passport" refreshedText) "refreshed view missing newly added item"
    expect (contains "due 2026-11-20" refreshedText) "refreshed view missing due date"

    -- Close (resolve) the item
    let closeDraft : Loam.AttentionPublisher.CloseDraft := {
      attention := addedId
      knownOn := "2026-09-16"
      kind := .resolved
    }
    match ← Loam.HouseholdCommand.closeAttention tmpRoot closeDraft with
    | .ok () => pure ()
    | .error message => throw (IO.userError message)

    -- Reload evidence and refresh administration view
    let closedLoad ← Loam.AttentionReview.loadHouseholdEvidence tmpRoot
    let .ok closedEvidence := closedLoad | throw (IO.userError "reloading closed evidence failed")
    let adminClosed := Loam.Tui.AttentionAdministration.initial closedEvidence "2026-09-16"
    let closedText := widgetText (Loam.Tui.AttentionAdministration.view adminClosed)
    expect (contains "0 open" closedText) "closed item remained open in view"
    expect (!contains "renew passport" closedText) "resolved item context remained visible in open view"
  finally
    if ← tmpRoot.pathExists then
      IO.FS.removeDirAll tmpRoot

  IO.println "Attention administration TUI: HouseholdImage bootstrap, due choices, invalid date refusal, selection, resolve/drop intents, and end-to-end publication passed."
