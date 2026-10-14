import Loam.Review.AttentionReview
import Loam.Review.ScheduledReview
import Loam.Tui.Home
import Loam.Tui.HomeCommandPalette
import Loam.Tui.AttentionAdministration
import Loam.Tui.ScheduledContinuationSession
import Loam.Authority.HouseholdAuthority

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def movement?
    (toLocus : String) (amount : Int) : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨"smbc"⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount } ]

private def occurrence
    (id date toLocus : String) (amount : Int) : IO (ScheduledOccurrence String) := do
  let movement ← requireSome (movement? toLocus amount) "balanced Scheduled movement"
  pure { id := ⟨id⟩, scheduledOn := date, movement }

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

def main : IO Unit := do
  let source ← occurrence "source" "2026-09-15" "gpt-plus" 3000
  let nextRaised ← occurrence "next-raised" "2026-10-15" "gpt-plus" 6000
  let laterRaised ← occurrence "later-raised" "2026-11-15" "gpt-plus" 6000
  let other ← occurrence "other" "2026-10-10" "service" 4000
  let earlierSame ← occurrence "earlier-same" "2026-09-10" "gpt-plus" 3000

  let scheduled ← requireSome
    (ScheduledMemory.ofOccurrences? [laterRaised, other, nextRaised, earlierSame])
    "Scheduled memory"
  let terminals ← requireSome
    (ScheduledTerminalMemory.ofTerminals? [])
    "Scheduled terminal memory"
  let events ← requireSome
    (EventMemory.ofEvents? [])
    "Event memory"
  let snapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled, terminals, events
  }

  let .ok candidates := Loam.ScheduledReview.laterSimilarOpenRecords snapshot source
    | throw (IO.userError "later similar Scheduled projection refused")
  expect (candidates.map (fun row => row.id.token) == ["next-raised", "later-raised"])
    "later similar projection did not use positive Locus + later date ordering"
  let firstCandidate ← requireSome candidates.head?
    "later similar projection unexpectedly returned no first candidate"
  expect (firstCandidate.movement.changes.any fun change =>
      change.coordinate.token == "gpt-plus" && change.quantity.quanta == 6000)
    "amount-changing later Scheduled was not retained as an awareness candidate"
  expect (!(candidates.any fun row => row.id.token == "other"))
    "different positive Locus leaked into continuation awareness"
  expect (!(candidates.any fun row => row.id.token == "earlier-same"))
    "earlier same-Locus Scheduled leaked into later awareness"

  let wide : Bounds := { width := 100, height := 42 }
  let tiny : Bounds := { width := 32, height := 9 }
  let prompt := Loam.Tui.ScheduledContinuationSession.initialPrompt candidates
  let promptText := widgetText (Loam.Tui.ScheduledContinuationSession.promptView wide prompt)
  expect (contains "next-raised" promptText && contains "2026-10-15" promptText)
    "continuation prompt did not show the earliest similar later Scheduled"
  expect (contains "does not claim this is the same series or contract" promptText)
    "continuation prompt did not preserve non-series semantics"

  let keep := Loam.Tui.ScheduledContinuationSession.updatePrompt wide prompt .enter
  expect (keep.action == some .keep)
    "existing-plan prompt did not default to Keep as is"

  let addState := (Loam.Tui.ScheduledContinuationSession.updatePrompt wide prompt .right).state
  let add := Loam.Tui.ScheduledContinuationSession.updatePrompt wide addState .enter
  expect (add.action == some .add)
    "existing-plan prompt could not explicitly choose Add another"

  let reviewState :=
    (Loam.Tui.ScheduledContinuationSession.updatePrompt wide addState .right).state
  let review := Loam.Tui.ScheduledContinuationSession.updatePrompt wide reviewState .enter
  expect (review.action.isNone && review.state.mode == .review)
    "existing-plan prompt did not enter read-only Review"
  let reviewText := widgetText (Loam.Tui.ScheduledContinuationSession.promptView wide review.state)
  expect (contains "Expected effects:" reviewText && contains "6000 jpy" reviewText)
    "existing-plan Review did not show explicit retained movement"
  expect (contains "Esc back" reviewText && !(contains "Enter / Esc back" reviewText))
    "existing-plan Review still advertised Enter as back"
  let reviewEnter := Loam.Tui.ScheduledContinuationSession.updatePrompt wide review.state .enter
  expect (reviewEnter.state.mode == .review)
    "Enter unexpectedly left read-only Review"
  let reviewEsc := Loam.Tui.ScheduledContinuationSession.updatePrompt wide review.state .escape
  expect (reviewEsc.state.mode == .choice)
    "Esc did not return from read-only Review"

  -- Bounded continuation review is always read-only, including narrow/resized
  -- terminals. The final evidence remains reachable without changing actions.
  let reviewBottom :=
    Loam.Tui.ScheduledContinuationSession.updatePrompt tiny review.state .«end»
  expect (reviewBottom.state.reviewRow > 0 && reviewBottom.action.isNone)
    "continuation review did not scroll to its final evidence row"
  let lastEvidence :=
    widgetText (Loam.Tui.ScheduledContinuationSession.promptView tiny reviewBottom.state)
  expect (contains "same-series claim." lastEvidence &&
      contains "Esc back" lastEvidence)
    "continuation review lost its final evidence or Esc on a 32x9 terminal"
  let reviewUp :=
    Loam.Tui.ScheduledContinuationSession.updatePrompt tiny reviewBottom.state (.input 'k')
  expect (reviewUp.state.reviewRow < reviewBottom.state.reviewRow &&
      reviewUp.action.isNone)
    "continuation review scroll changed a Scheduled action"
  let reviewEnter :=
    Loam.Tui.ScheduledContinuationSession.updatePrompt tiny reviewBottom.state .enter
  expect (reviewEnter.action.isNone && reviewEnter.state.mode == .review)
    "continuation review Enter unexpectedly published or left read-only mode"
  for bounds in ([wide, { width := 48, height := 14 }, tiny] : List Bounds) do
    for promptState in [prompt, review.state, reviewBottom.state] do
      let rendered := Loam.Tui.ScheduledContinuationSession.promptView bounds promptState
      expect (rendered.lines.length == bounds.height - 1)
        "continuation viewport exceeded or failed to fill the safe terminal height"
      for cells in rendered.lines do
        expect (Loam.Tui.Layout.displayWidth (String.ofList (cells.map Cell.glyph)) <=
          bounds.width - 1)
          "continuation viewport wrote beyond the safe terminal width"
    let options := widgetText
      (Loam.Tui.ScheduledContinuationSession.promptView bounds prompt)
    expect (contains "Keep as is" options && contains "Add another" options &&
      contains "Review" options)
      "continuation choices were hidden at narrow terminal dimensions"

  let nonePrompt := Loam.Tui.ScheduledContinuationSession.initialPrompt []
  let noneText := widgetText (Loam.Tui.ScheduledContinuationSession.promptView wide nonePrompt)
  expect (contains "No similar later current-open Scheduled was found" noneText)
    "no-candidate prompt did not state absence explicitly"
  expect (contains "Done" noneText && contains "Defer" noneText && contains "Add next" noneText)
    "no-candidate prompt did not expose Done / Defer / Add next choices"
  for bounds in ([wide, { width := 48, height := 14 }, tiny] : List Bounds) do
    let rendered := Loam.Tui.ScheduledContinuationSession.promptView bounds nonePrompt
    let message := widgetText rendered
    expect (rendered.lines.length == bounds.height - 1 &&
      contains "Done" message && contains "Defer" message && contains "Add next" message)
      "no-candidate continuation choices were cropped on a compact terminal"

  let done := Loam.Tui.ScheduledContinuationSession.updatePrompt wide nonePrompt .enter
  expect (done.action == some .done)
    "no-candidate prompt did not default to Done"

  let noneDeferState :=
    (Loam.Tui.ScheduledContinuationSession.updatePrompt wide nonePrompt .right).state
  let noneDefer := Loam.Tui.ScheduledContinuationSession.updatePrompt wide noneDeferState .enter
  expect (noneDefer.action == some .defer)
    "no-candidate prompt could not explicitly choose Defer"

  let noneAddState :=
    (Loam.Tui.ScheduledContinuationSession.updatePrompt wide noneDeferState .right).state
  let noneAdd := Loam.Tui.ScheduledContinuationSession.updatePrompt wide noneAddState .enter
  expect (noneAdd.action == some .add)
    "no-candidate prompt could not explicitly choose Add next"

  let deferDraft := Loam.Tui.ScheduledContinuationSession.deferredAttentionDraft source
  expect (deferDraft.due == .dueUndetermined)
    "deferred continuation invented a due date or no-due claim"
  expect (contains "source" deferDraft.context && contains "gpt-plus" deferDraft.context)
    "deferred continuation Attention context lost the completed Scheduled identity or summary"

  let root ← IO.FS.createTempDir
  let .ok _ ← Loam.HouseholdAuthority.installInitial? root { sections := [] }
    | throw (IO.userError "Scheduled continuation HouseholdImage bootstrap failed")
  let .ok deferredId ←
      Loam.Tui.ScheduledContinuationSession.publishDeferredContinuation root source
    | throw (IO.userError "deferred continuation Attention publication was refused")
  let attentionAvailability ←
    match ← Loam.AttentionReview.loadHouseholdEvidence root with
    | .error message => throw (IO.userError message)
    | .ok .unavailable =>
        throw (IO.userError "deferred continuation did not create Attention authority")
    | .ok (.available attention) =>
        let some item := attention.openItems.find? (fun item => item.id == deferredId)
          | throw (IO.userError "deferred continuation Attention was not current-open")
        expect (item.due == .dueUndetermined)
          "published deferred continuation lost unknown due timing"
        expect (contains "source" item.context && contains "gpt-plus" item.context)
          "published deferred continuation lost human-identifiable context"
        pure (Loam.AttentionReview.Availability.available attention)

  let actual : Loam.Tui.Main.ActualSnapshot := {
    today := "2026-09-15"
    allRecords := []
  }
  let homeSnapshot : Loam.Tui.Main.Snapshot := {
    actual := actual
    scheduled := .ok snapshot
  }
  -- Home exposes Commands; the Plans group reaches the existing Attention workspace.
  let homeState := Loam.Tui.Main.initialState "2026-09-15"
  let homeText := widgetText
    (Loam.Tui.Home.view { width := 100, height := 42 } homeSnapshot homeState)
  expect (contains "[Space] commands" homeText)
    "Calendar Home lost its Commands entrance"
  let paletteRoot : Loam.Tui.HomeCommandPalette.State := { selected := 1 }
  expect (Loam.Tui.HomeCommandPalette.update paletteRoot .enter ==
    .stay { page := .planning })
    "Commands did not reach the Plans and attention group"
  expect (Loam.Tui.HomeCommandPalette.update { page := .planning, selected := 1 } .enter ==
    .open .attention)
    "Plans and attention no longer opens the deferred-continuation Attention workspace"
  let attentionText := widgetText (Loam.Tui.AttentionAdministration.view
    (Loam.Tui.AttentionAdministration.initial attentionAvailability "2026-09-15"))
  expect (contains "due unknown" attentionText && contains "source" attentionText)
    "Attention workspace did not rediscover the deferred continuation"

  let .ok _secondAttention ← Loam.HouseholdCommand.addAttention root {
      context := "second open attention"
      due := .noDueDate
    }
    | throw (IO.userError "second Attention publication was refused")
  let multiAvailability ←
    match ← Loam.AttentionReview.loadHouseholdEvidence root with
    | .ok (.available attention) => pure (Loam.AttentionReview.Availability.available attention)
    | .error message => throw (IO.userError message)
    | .ok .unavailable => throw (IO.userError "published Attention authority became unavailable")
  let multiText := widgetText (Loam.Tui.AttentionAdministration.view
    (Loam.Tui.AttentionAdministration.initial multiAvailability "2026-09-15"))
  expect (contains "source" multiText && contains "second open attention" multiText)
    "Attention workspace did not preserve both open matters"

  let unavailableText := widgetText (Loam.Tui.AttentionAdministration.view
    (Loam.Tui.AttentionAdministration.initial .unavailable "2026-09-15"))
  expect (contains "No canonical Attention stream yet" unavailableText)
    "Attention workspace collapsed a missing stream into an empty one"

  let emptyAttention : Loam.AttentionReview.Snapshot := { openItems := [] }
  let emptyText := widgetText (Loam.Tui.AttentionAdministration.view
    (Loam.Tui.AttentionAdministration.initial (.available emptyAttention) "2026-09-15"))
  expect (contains "0 open" emptyText)
    "Attention workspace lost the configured-empty distinction"

  IO.println "TUI Scheduled continuation awareness: explicit Defer survives Attention reload and workspace rediscovery."
