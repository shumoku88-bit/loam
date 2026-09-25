import Loam.Web.Record

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (text needle : String) : Bool :=
  (text.splitOn needle).length > 1

private def world : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"books"⟩]
    | throw (IO.userError "vocabulary")
  return {
    events := events
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp
    }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary
  }

def main (_args : List String) : IO Unit := do
  let w ← world
  let catalog := Loam.LocusCatalog.fallback w.locusAdmission
  let request : Loam.Web.Record.Request := {
    date := "2026-09-25"
    description := "<book&tea>"
    measure := "jpy"
    fromLocus := "paypay"
    fromAmount := "2470"
    toLocus := "books"
    toAmount := "2470"
  }
  let model : Loam.Web.Record.Model := {
    request := request
    catalog := catalog
    measurePresentation := []
  }
  let reviewed := Loam.Web.Record.review w model
  let html := Loam.Web.Record.render reviewed

  let .ok input := request.toInput?
    | throw (IO.userError "Web request did not produce shared Record input")
  expect (input.rows[0]!.amount == "-2470" && input.rows[1]!.amount == "2470")
    "Web From/To grammar did not become signed shared Record rows"

  expect (contains html "action=\"/record/preview\"")
    "Web Record form does not post to the preview route"
  expect (contains html "Choose Locus")
    "Web Record form did not expose admitted Locus recognition"
  expect (contains html "Exact balance</th><td>yes")
    "Web Record review did not expose successful exact balance"
  expect (contains html "-2470 jpy")
    "Web Record review did not render the admitted signed From posting"
  expect (contains html "&lt;book&amp;tea&gt;")
    "Web Record review did not escape human description text"
  expect (contains html "No Event identity is reserved")
    "Web Record review did not state its read-only identity boundary"
  expect (contains html "Publication is deliberately unavailable")
    "Web Record preview accidentally implied publication availability"
  expect (!contains html "HouseholdCommand")
    "Web Record presentation leaked internal writer vocabulary"

  let signedRequest := { request with fromAmount := "-2470" }
  expect (signedRequest.toInput?.isOk == false)
    "Web From field accepted a second direction sign"

  let unbalanced := Loam.Web.Record.review w {
    model with request := { request with toAmount := "2400" }
  }
  let unbalancedHtml := Loam.Web.Record.render unbalanced
  expect (contains unbalancedHtml "Not ready:")
    "Web Record did not preserve shared refusal as a visible review state"
  expect (contains unbalancedHtml "Nothing was written.")
    "Web Record refusal did not state the no-write result"

  IO.println "Web Record: From/To transport, shared admission preview, escaping, refusal, and no-write review passed."
