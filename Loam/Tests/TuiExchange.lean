import Loam.Tui.Exchange
import Loam.Tui.ExchangeSession
import Loam.Tui.Layout

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def world : IO Loam.ExchangeAdmission.World := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "empty EventMemory")
  let some loci := LocusAdmissionVocabulary.ofLoci? [
      ⟨"cash-jpy"⟩,
      ⟨"cash-usd"⟩,
      ⟨"cash-eur"⟩
    ]
    | throw (IO.userError "Locus admission fixture")
  return {
    events := events
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp
    }
    descriptions := .empty
    exchanges := .empty
    corrections := { corrections := [], idNodup := by simp }
    locusAdmission := loci
  }

private def usdScale : List Loam.MeasurePresentation.Metadata := [
  { measure := ⟨"usd"⟩, scale := 2 },
  { measure := ⟨"eur"⟩, scale := 2 }
]

def main : IO Unit := do
  let usdOpened := Loam.Tui.Exchange.initialWithMeasure ⟨"usd"⟩ "2026-09-26"
  expect (usdOpened.form.sourceMeasure == "usd")
    "Exchange did not retain the configured source Measure"
  -- Exchange now uses the existing adaptive modal shell with compact fallback.
  let compact : Loam.Tui.Kernel.Bounds := { width := 80, height := 24 }
  expect ((Loam.Tui.ExchangeSession.floatingGeometry? compact).isNone)
    "Exchange must retain full-screen fallback on small terminals"
  let large : Loam.Tui.Kernel.Bounds := { width := 100, height := 40 }
  let some panel := Loam.Tui.ExchangeSession.floatingGeometry? large
    | throw (IO.userError "Exchange floating geometry missing at 100x40")
  -- The final terminal column is reserved to avoid autowrap. Centering
  -- therefore uses Layout.contentWidth, not the raw 100-column width.
  expect (Loam.Tui.Layout.contentWidth large == 99)
    "Exchange test assumes a reserved terminal autowrap column"
  expect (panel.width == 84 && panel.height == 25 &&
      panel.top == (large.height - panel.height) / 2 &&
      panel.left == (Loam.Tui.Layout.contentWidth large - panel.width) / 2)
    "Exchange floating geometry changed"

  let w ← world

  let state : Loam.Tui.Exchange.State :=
    Loam.Tui.Exchange.withMeasurePresentation {
      form := {
        date := "2026-09-26"
        description := "cash exchange"
        sourceLocus := "cash-jpy"
        sourceMeasure := "jpy"
        sourceAmount := "15000"
        destinationLocus := "cash-usd"
        destinationMeasure := "usd"
        destinationAmount := "100.00"
        focus := 7
      }
    } usdScale

  let compactLines := (Loam.Tui.ExchangeSession.viewForBounds compact state).lines
  let largeLines := (Loam.Tui.ExchangeSession.viewForBounds large state).lines
  expect (!compactLines.isEmpty && !largeLines.isEmpty)
    "Exchange modal lost the editing form in compact or floating geometry"
  let longText := String.ofList (List.replicate 100 '界') ++ "-tail"
  for bounds in [({width := 32, height := 9} : Loam.Tui.Kernel.Bounds),
      {width := 48, height := 14}, {width := 80, height := 24}, {width := 120, height := 40}] do
    for focus in List.range 10 do
      let longValue := String.ofList (List.replicate 100 '1') ++ "-tail"
      let form : Loam.Tui.Exchange.Form := {
        date := longValue,
        description := longText,
        sourceLocus := longValue,
        sourceMeasure := longValue,
        sourceAmount := longValue,
        destinationLocus := longValue,
        destinationMeasure := longValue,
        destinationAmount := longValue,
        focus := focus
      }
      let editing := { state with form := form }
      let widget := Loam.Tui.ExchangeSession.viewForBounds bounds editing
      let markers := widget.lines.flatten.filter (·.caret)
      expect (markers.length == (if focus < 8 then 1 else 0) &&
          markers.all (fun cell => cell.glyph == ' '))
        "Exchange focus lost its insertion cell or put a caret on an action"
      expect (widget.lines.all fun cells =>
        Loam.Tui.Layout.displayWidth (String.ofList (cells.map (·.glyph))) ≤ bounds.width - 1)
        "Exchange field escaped live columns"
      if focus == 1 then
        expect (widget.lines.any fun cells => cells.any (·.caret) &&
          ((String.ofList (cells.map (·.glyph))).splitOn "-tail").length > 1)
          "Exchange long CJK description did not keep the tail and insertion cell together"
      let pasted := Loam.Tui.Exchange.update w editing (.paste "ignored")
      expect (pasted.state.form.description == longText && pasted.state.form.focus == focus && pasted.publish.isNone)
        "Exchange changed historically unsupported paste or published from text"
      let cancel := Loam.Tui.Exchange.update w editing .escape
      expect (cancel.cancel && cancel.publish.isNone && cancel.state.form.description == longText)
        "Exchange cancellation changed input bytes or emitted a write"

  let .ok draft := Loam.Tui.Exchange.draft? state
    | throw (IO.userError "valid JPY -> USD exchange form did not parse")
  expect (draft.effects.length == 2)
    "exchange draft did not retain exactly two direct Effects"
  let some source := draft.effects[0]?
    | throw (IO.userError "exchange source Effect missing")
  let some destination := draft.effects[1]?
    | throw (IO.userError "exchange destination Effect missing")
  expect
    (source.measure == ⟨"jpy"⟩ &&
      source.quantity.quanta == -15000 &&
      destination.measure == ⟨"usd"⟩ &&
      destination.quantity.quanta == 10000)
    "exchange editor did not convert positive human amounts into exact signed quanta"

  let preview := Loam.Tui.Exchange.update w state .enter
  match preview.state.mode with
  | .preview previewDraft choice =>
      expect (choice == 0)
        "exchange preview did not default to Publish"
      let some previewSource := previewDraft.effects[0]?
        | throw (IO.userError "exchange preview source Effect missing")
      let some previewDestination := previewDraft.effects[1]?
        | throw (IO.userError "exchange preview destination Effect missing")
      expect
        (previewSource.quantity.quanta == -15000 &&
          previewDestination.quantity.quanta == 10000)
        "exchange preview changed the parsed Effects"
  | _ => throw (IO.userError "destination amount Enter did not open Exchange preview")
  expect (!(Loam.Tui.Exchange.view preview.state).lines.flatten.any (·.caret))
    "Exchange preview displayed a text caret"
  let returned := Loam.Tui.Exchange.update w preview.state (.input 'e')
  let refusedEdit := Loam.Tui.Exchange.withPublishError preview.state "Publication refused"
  for editing in [returned.state, refusedEdit] do
    expect (((Loam.Tui.Exchange.view editing).lines.flatten.filter (·.caret)).length == 1)
      "Exchange review return or refusal did not restore the text field"

  let published := Loam.Tui.Exchange.update w preview.state .enter
  expect published.publish.isSome
    "Exchange preview did not emit an explicit publication intent"

  let sameMeasure : Loam.Tui.Exchange.State := {
    state with form := {
      state.form with
      destinationMeasure := "jpy"
      destinationAmount := "100"
    }
  }
  expect ((Loam.Tui.Exchange.draft? sameMeasure).isOk == false)
    "Exchange editor accepted equal source and destination Measures"

  let tooPrecise : Loam.Tui.Exchange.State := {
    state with form := { state.form with destinationAmount := "100.001" }
  }
  expect ((Loam.Tui.Exchange.draft? tooPrecise).isOk == false)
    "Exchange editor accepted more precision than the USD Measure scale"

  let unknownLocus : Loam.Tui.Exchange.State := {
    state with
    form := {
      state.form with
      destinationLocus := "unknown-cash"
      focus := 7
    }
  }
  let refused := Loam.Tui.Exchange.update w unknownLocus .enter
  match refused.state.mode with
  | .editing =>
      expect (!refused.state.notice.isEmpty)
        "unknown exchange Locus was refused without a visible explanation"
  | _ => throw (IO.userError "unknown exchange Locus crossed preview admission")

  -- Reverse geographic direction uses the same editor semantics.
  let reverse : Loam.Tui.Exchange.State :=
    Loam.Tui.Exchange.withMeasurePresentation {
      form := {
        date := "2026-09-26"
        description := "Japan trip exchange"
        sourceLocus := "cash-eur"
        sourceMeasure := "eur"
        sourceAmount := "50.00"
        destinationLocus := "cash-jpy"
        destinationMeasure := "jpy"
        destinationAmount := "8000"
        focus := 7
      }
    } usdScale
  let .ok reverseDraft := Loam.Tui.Exchange.draft? reverse
    | throw (IO.userError "EUR -> JPY reverse-direction exchange form did not parse")
  let some reverseSource := reverseDraft.effects[0]?
    | throw (IO.userError "reverse exchange source Effect missing")
  let some reverseDestination := reverseDraft.effects[1]?
    | throw (IO.userError "reverse exchange destination Effect missing")
  expect
    (reverseSource.quantity.quanta == -5000 &&
      reverseDestination.quantity.quanta == 8000)
    "reverse-direction exchange lost Measure-neutral exact quantities"

  IO.println "TUI Exchange: exact scaled input, preview, refusal and Measure symmetry passed."
