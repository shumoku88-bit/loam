import Loam.ScheduledCreationPublisher
import Loam.ScheduledReview
import Loam.Tui.ScheduledGeneration
import Loam.Tui.ScheduledGenerationSession

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def source? : Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-3000) }
    , { coordinate := ⟨"gpt-plus"⟩, quantity := Quantity.ofQuanta 3000 } ]
  pure {
    id := ⟨"scheduled-source"⟩
    scheduledOn := "2026-08-15"
    movement := movement
  }

private def typeText
    (state : Loam.Tui.ScheduledGeneration.State)
    (text : String) : Loam.Tui.ScheduledGeneration.State :=
  text.toList.foldl
    (fun state char =>
      (Loam.Tui.ScheduledGeneration.update state (.input char)).state)
    state

def main : IO Unit := do
  let some source := source? | throw (IO.userError "Scheduled generation source fixture")
  let suggestions : List Loam.BoundaryPresetConfig.HorizonSuggestion :=
    [ { source := "Pension", start := "2026-08-14", endExclusive := "2026-10-15" }
    , { source := "Pension", start := "2026-08-14", endExclusive := "2026-12-15" }
    , { source := "Pension", start := "2026-08-14", endExclusive := "2027-02-15" }
    ]

  let state := Loam.Tui.ScheduledGeneration.initial source suggestions "2026-09-18"
  let horizonText := widgetText (Loam.Tui.ScheduledGeneration.view state)
  expect (contains "through 2026-10-15" horizonText &&
      contains "through 2026-12-15" horizonText &&
      contains "through 2027-02-15" horizonText &&
      contains "Custom date" horizonText)
    "Scheduled generation did not show boundary suggestions plus Custom date"
  expect (contains "Boundary dates are suggestions only" horizonText)
    "Scheduled generation view promoted boundary suggestions into generation authority"

  let suggestion2 := Loam.Tui.ScheduledGeneration.update state .down
  let suggestion3 := Loam.Tui.ScheduledGeneration.update suggestion2.state .down
  let selectedSuggestion := Loam.Tui.ScheduledGeneration.update suggestion3.state .enter
  expect (selectedSuggestion.state.limit.endExclusive == "2027-02-15")
    "Scheduled generation did not adapt the far boundary suggestion to a fill limit"

  let cadenceText := widgetText (Loam.Tui.ScheduledGeneration.view selectedSuggestion.state)
  expect (contains "Monthly" cadenceText &&
      contains "Every 2 months" cadenceText &&
      contains "Yearly" cadenceText)
    "Scheduled generation cadence choices were not visible after suggestion selection"
  expect (contains "no recurrence authority is retained" cadenceText)
    "Scheduled generation cadence view implied retained recurrence"

  let twoMonth := Loam.Tui.ScheduledGeneration.update selectedSuggestion.state .right
  let chosen := Loam.Tui.ScheduledGeneration.update twoMonth.state .enter
  expect (decide (chosen.cadence = some .everyTwoMonths))
    "Scheduled generation cadence selection did not preserve explicit input choice"

  let customChoice1 := Loam.Tui.ScheduledGeneration.update state .down
  let customChoice2 := Loam.Tui.ScheduledGeneration.update customChoice1.state .down
  let customChoice3 := Loam.Tui.ScheduledGeneration.update customChoice2.state .down
  let customStart := Loam.Tui.ScheduledGeneration.update customChoice3.state .enter
  match customStart.state.mode with
  | .customDate _ => pure ()
  | _ => throw (IO.userError "Scheduled generation Custom date choice did not enter date editing")

  let typedCustom := typeText customStart.state "2027-01-20"
  let acceptedCustom := Loam.Tui.ScheduledGeneration.update typedCustom .enter
  expect (acceptedCustom.state.limit.endExclusive == "2027-01-20")
    "Scheduled generation did not retain an arbitrary custom fill limit"
  expect (acceptedCustom.state.limitLabel == "custom 2027-01-20")
    "Scheduled generation did not distinguish custom fill-limit provenance for presentation"
  let customCadenceText := widgetText (Loam.Tui.ScheduledGeneration.view acceptedCustom.state)
  expect (contains "Fill through: 2027-01-20" customCadenceText)
    "Scheduled generation did not present the accepted custom fill limit"

  let noSuggestions := Loam.Tui.ScheduledGeneration.initial source [] "2026-09-18"
  let noSuggestionText := widgetText (Loam.Tui.ScheduledGeneration.view noSuggestions)
  expect (contains "Custom date" noSuggestionText)
    "Scheduled generation became unavailable when boundary suggestions were absent"
  let noSuggestionCustom := Loam.Tui.ScheduledGeneration.update noSuggestions .enter
  match noSuggestionCustom.state.mode with
  | .customDate _ => pure ()
  | _ => throw (IO.userError "Custom date was not directly usable without boundary suggestions")

  let invalidTyped := typeText noSuggestionCustom.state "2026-09-18"
  let invalidAccepted := Loam.Tui.ScheduledGeneration.update invalidTyped .enter
  expect (contains "must be later than the observation date" invalidAccepted.state.notice)
    "Scheduled generation accepted a custom fill limit at the observation date"

  let draft1 : Loam.ScheduledCreationPublisher.Draft := {
    scheduledOn := "2026-10-15"
    movement := source.movement
  }
  let draft2 : Loam.ScheduledCreationPublisher.Draft := {
    scheduledOn := "2026-11-15"
    movement := source.movement
  }
  let preview :=
    Loam.Tui.ScheduledGeneration.withDrafts
      selectedSuggestion.state .monthly [draft1, draft2]
  let previewText := widgetText (Loam.Tui.ScheduledGeneration.view preview)
  expect (contains "2026-10-15" previewText && contains "2026-11-15" previewText)
    "Scheduled generation final review did not show individually edited dates"
  expect (contains "Cadence will not be stored" previewText)
    "Scheduled generation final review implied retained recurrence"

  let publish := Loam.Tui.ScheduledGeneration.update preview .enter
  expect publish.publish
    "Scheduled generation final review did not emit publication intent"

  let some raisedMovement := BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-6000) }
      , { coordinate := ⟨"gpt-plus"⟩, quantity := Quantity.ofQuanta 6000 } ]
    | throw (IO.userError "Scheduled generation awareness movement fixture")
  let existing : ScheduledOccurrence String := {
    id := ⟨"already-planned"⟩
    scheduledOn := draft2.scheduledOn
    movement := raisedMovement
  }
  let some scheduled := ScheduledMemory.ofOccurrences? [existing]
    | throw (IO.userError "Scheduled generation awareness Scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "Scheduled generation awareness terminal memory")
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "Scheduled generation awareness Event memory")
  let snapshot : Loam.ScheduledReview.EvidenceSnapshot := {
    scheduled, terminals, events
  }

  let .ok overlaps :=
      Loam.ScheduledReview.sameDateSimilarOpenRecords
        snapshot draft2.scheduledOn draft2.movement
    | throw (IO.userError "Scheduled generation exact-date awareness refused")
  expect (overlaps.map (fun record => record.id.token) == ["already-planned"])
    "Scheduled generation awareness did not surface retained same-date plan"
  let some overlap := overlaps.head?
    | throw (IO.userError "Scheduled generation awareness overlap unexpectedly missing")
  expect (overlap.movement.changes.any fun change =>
      change.coordinate.token == "gpt-plus" && change.quantity.quanta == 6000)
    "Scheduled generation awareness incorrectly required equal amounts"

  let .ok differentDate :=
      Loam.ScheduledReview.sameDateSimilarOpenRecords
        snapshot "2026-11-16" draft2.movement
    | throw (IO.userError "Scheduled generation different-date awareness refused")
  expect differentDate.isEmpty
    "Scheduled generation awareness matched a retained plan on a different date"

  let some wifiMovement := BalancedMovement.ofChanges? ⟨"jpy"⟩
      [ { coordinate := ⟨"paypay"⟩, quantity := Quantity.ofQuanta (-3000) }
      , { coordinate := ⟨"wifi"⟩, quantity := Quantity.ofQuanta 3000 } ]
    | throw (IO.userError "Scheduled generation different-Locus movement fixture")
  let .ok differentLocus :=
      Loam.ScheduledReview.sameDateSimilarOpenRecords
        snapshot draft2.scheduledOn wifiMovement
    | throw (IO.userError "Scheduled generation different-Locus awareness refused")
  expect differentLocus.isEmpty
    "Scheduled generation awareness matched a different positive Locus set"

  let some awareness :=
      Loam.Tui.ScheduledGenerationSession.initialAwarenessPrompt? draft2 overlaps
    | throw (IO.userError "Scheduled generation awareness prompt missing")
  let awarenessText :=
    widgetText (Loam.Tui.ScheduledGenerationSession.awarenessPromptView awareness)
  expect (contains "already-planned" awarenessText &&
      contains "Keep existing" awarenessText &&
      contains "Add another" awarenessText)
    "Scheduled generation awareness prompt did not expose evidence and explicit choice"
  expect (contains "does not claim this is the same series, contract, or obligation" awarenessText)
    "Scheduled generation awareness prompt overstated the advisory match"

  let keep :=
    Loam.Tui.ScheduledGenerationSession.updateAwarenessPrompt awareness .enter
  expect (keep.action == some .keepExisting)
    "Scheduled generation awareness did not default to keeping existing evidence"

  let addState :=
    (Loam.Tui.ScheduledGenerationSession.updateAwarenessPrompt awareness .right).state
  let add :=
    Loam.Tui.ScheduledGenerationSession.updateAwarenessPrompt addState .enter
  expect (add.action == some .addAnother)
    "Scheduled generation awareness could not explicitly add another Scheduled"

  let reviewState :=
    (Loam.Tui.ScheduledGenerationSession.updateAwarenessPrompt addState .right).state
  let review :=
    Loam.Tui.ScheduledGenerationSession.updateAwarenessPrompt reviewState .enter
  expect (review.action.isNone && review.state.mode == .review)
    "Scheduled generation awareness could not review retained evidence"
  let reviewText :=
    widgetText (Loam.Tui.ScheduledGenerationSession.awarenessPromptView review.state)
  expect (contains "Expected effects:" reviewText && contains "6000 jpy" reviewText)
    "Scheduled generation awareness Review did not show retained movement evidence"

  IO.println "TUI Scheduled generation: suggestions, custom limit, cadence, review, and awareness passed."
