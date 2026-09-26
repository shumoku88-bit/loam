import Loam.Tui.Exchange

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
    corrections := .empty
    locusAdmission := loci
  }

private def usdScale : List Loam.MeasurePresentation.Metadata := [
  { measure := ⟨"usd"⟩, scale := 2 },
  { measure := ⟨"eur"⟩, scale := 2 }
]

def main : IO Unit := do
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

  let .ok draft := Loam.Tui.Exchange.draft? state
    | throw (IO.userError "valid JPY -> USD exchange form did not parse")
  expect (draft.effects.length == 2)
    "exchange draft did not retain exactly two direct Effects"
  let source := draft.effects[0]!
  let destination := draft.effects[1]!
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
      expect (previewDraft.effects == draft.effects)
        "exchange preview changed the parsed Effects"
  | _ => throw (IO.userError "destination amount Enter did not open Exchange preview")

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
  expect
    (reverseDraft.effects[0]!.quantity.quanta == -5000 &&
      reverseDraft.effects[1]!.quantity.quanta == 8000)
    "reverse-direction exchange lost Measure-neutral exact quantities"

  IO.println "TUI Exchange: exact scaled input, preview, refusal and Measure symmetry passed."
