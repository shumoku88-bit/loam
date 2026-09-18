import Loam.ScheduledReview
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
  expect (candidates[0]!.movement.changes.any fun change =>
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
  let done := Loam.Tui.ScheduledContinuationSession.updatePrompt nonePrompt .enter
  expect (done.action == some .done)
    "no-candidate prompt did not default to Done"
  let noneAddState :=
    (Loam.Tui.ScheduledContinuationSession.updatePrompt nonePrompt .right).state
  let noneAdd := Loam.Tui.ScheduledContinuationSession.updatePrompt noneAddState .enter
  expect (noneAdd.action == some .add)
    "no-candidate prompt could not explicitly choose Add next"

  IO.println "TUI Scheduled continuation awareness: similar-plan projection and explicit Keep/Add/Review/Done choices passed."
