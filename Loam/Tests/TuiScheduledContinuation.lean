import Loam.AttentionReview
import Loam.ScheduledReview
import Loam.Tui.HraHome
import Loam.Tui.ScheduledContinuationSession

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
  let other ← occurrence "other" "2026-10-10" "wifi" 4810
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

  let prompt := Loam.Tui.ScheduledContinuationSession.initialPrompt candidates
  let promptText := widgetText (Loam.Tui.ScheduledContinuationSession.promptView prompt)
  expect (contains "next-raised" promptText && contains "2026-10-15" promptText)
    "continuation prompt did not show the earliest similar later Scheduled"
  expect (contains "does not claim this is the same series or contract" promptText)
    "continuation prompt did not preserve non-series semantics"

  let keep := Loam.Tui.ScheduledContinuationSession.updatePrompt prompt .enter
  expect (keep.action == some .keep)
    "existing-plan prompt did not default to Keep as is"

  let addState := (Loam.Tui.ScheduledContinuationSession.updatePrompt prompt .right).state
  let add := Loam.Tui.ScheduledContinuationSession.updatePrompt addState .enter
  expect (add.action == some .add)
    "existing-plan prompt could not explicitly choose Add another"

  let reviewState :=
    (Loam.Tui.ScheduledContinuationSession.updatePrompt addState .right).state
  let review := Loam.Tui.ScheduledContinuationSession.updatePrompt reviewState .enter
  expect (review.action.isNone && review.state.mode == .review)
    "existing-plan prompt did not enter read-only Review"
  let reviewText := widgetText (Loam.Tui.ScheduledContinuationSession.promptView review.state)
  expect (contains "Expected effects:" reviewText && contains "6000 jpy" reviewText)
    "existing-plan Review did not show explicit retained movement"

  let nonePrompt := Loam.Tui.ScheduledContinuationSession.initialPrompt []
  let noneText := widgetText (Loam.Tui.ScheduledContinuationSession.promptView nonePrompt)
  expect (contains "No similar later current-open Scheduled was found" noneText)
    "no-candidate prompt did not state absence explicitly"
  expect (contains "Done" noneText && contains "Defer" noneText && contains "Add next" noneText)
    "no-candidate prompt did not expose Done / Defer / Add next choices"
  let done := Loam.Tui.ScheduledContinuationSession.updatePrompt nonePrompt .enter
  expect (done.action == some .done)
    "no-candidate prompt did not default to Done"

  let noneDeferState :=
    (Loam.Tui.ScheduledContinuationSession.updatePrompt nonePrompt .right).state
  let noneDefer := Loam.Tui.ScheduledContinuationSession.updatePrompt noneDeferState .enter
  expect (noneDefer.action == some .defer)
    "no-candidate prompt could not explicitly choose Defer"

  let noneAddState :=
    (Loam.Tui.ScheduledContinuationSession.updatePrompt noneDeferState .right).state
  let noneAdd := Loam.Tui.ScheduledContinuationSession.updatePrompt noneAddState .enter
  expect (noneAdd.action == some .add)
    "no-candidate prompt could not explicitly choose Add next"

  let deferDraft := Loam.Tui.ScheduledContinuationSession.deferredAttentionDraft source
  expect (deferDraft.due == .dueUndetermined)
    "deferred continuation invented a due date or no-due claim"
  expect (contains "source" deferDraft.context && contains "gpt-plus" deferDraft.context)
    "deferred continuation Attention context lost the completed Scheduled identity or summary"

  let root ← IO.FS.createTempDir
  let .ok deferredId ←
      Loam.Tui.ScheduledContinuationSession.publishDeferredContinuation root source
    | throw (IO.userError "deferred continuation Attention publication was refused")
  let attentionAvailability ←
    match ← Loam.AttentionReview.loadEvidence (root / "attention.loam") with
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
    attention :=
      match attentionAvailability with
      | .unavailable => .unavailable
      | .available attention => .loaded attention
  }
  let homeState := Loam.Tui.Main.initialState "2026-09-15"
  let homeText := widgetText
    (Loam.Tui.HraHome.view { width := 100, height := 42 } homeSnapshot homeState)
  expect (contains "Attention: 1 open" homeText &&
      contains "due unknown" homeText && contains "source" homeText)
    "Home did not rediscover the deferred continuation Attention"

  let .ok _secondAttention ← Loam.HouseholdCommand.addAttention root {
      context := "second open attention"
      due := .noDueDate
    }
    | throw (IO.userError "second Attention publication was refused")
  let multiAvailability ←
    match ← Loam.AttentionReview.loadEvidence (root / "attention.loam") with
    | .ok (.available attention) => pure (Loam.AttentionReview.Availability.available attention)
    | .error message => throw (IO.userError message)
    | .ok .unavailable => throw (IO.userError "published Attention authority became unavailable")
  let multiText := widgetText
    (Loam.Tui.HraHome.view { width := 100, height := 42 }
      { homeSnapshot with attention :=
          match multiAvailability with
          | .unavailable => .unavailable
          | .available attention => .loaded attention } homeState)
  expect (contains "Attention: 2 open  [i] manage" multiText)
    "Home did not expose multiple open Attention items without inventing priority"
  expect (!contains "Decide continuation after source" multiText)
    "Home singled out representation-order Attention as if it were prioritized"

  let unavailableText := widgetText
    (Loam.Tui.HraHome.view { width := 100, height := 42 }
      { homeSnapshot with attention := .unavailable } homeState)
  expect (contains "Attention: not configured" unavailableText)
    "Home collapsed missing Attention configuration into an empty stream"

  let emptyAttention : Loam.AttentionReview.Snapshot := { openItems := [] }
  let emptyText := widgetText
    (Loam.Tui.HraHome.view { width := 100, height := 42 }
      { homeSnapshot with attention := .loaded emptyAttention } homeState)
  expect (contains "Attention: 0 open" emptyText)
    "Home lost the configured-empty Attention distinction"

  IO.println "TUI Scheduled continuation awareness: explicit Defer survives Attention reload and Home rediscovery."
