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
    toLocus := "books"
    amount := "2470"
  }
  let model : Loam.Web.Record.Model := {
    operation := "web-test-operation"
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
  expect (contains html "action=\"/record/confirm\"")
    "Web Record review did not expose explicit confirmation"
  expect (contains html "name=\"operation\" value=\"web-test-operation\"")
    "Web Record review did not preserve its retry-safe operation identity"
  expect (contains html "writer re-reads authority before publication")
    "Web Record review did not explain authoritative re-admission"
  expect (contains html "value=\"Record\"")
    "Web Record review did not expose the consequential Record action"
  expect (!contains html "HouseholdCommand")
    "Web Record presentation leaked internal writer vocabulary"
  expect (!contains html "web-test-operation</")
    "Web Record exposed its opaque operation identity as visible content"

  expect (contains html "name=\"amount\" value=\"2470\"")
    "Web Record did not retain the single human-entered amount"
  expect (!contains html "from_amount")
    "Web Record still exposed a redundant From amount field"
  expect (!contains html "to_amount")
    "Web Record still exposed a redundant To amount field"

  let signedRequest := { request with amount := "-2470" }
  expect (signedRequest.toInput?.isOk == false)
    "Web Amount accepted a second direction sign"

  let missingAmount := Loam.Web.Record.review w {
    model with request := { request with amount := "" }
  }
  let missingAmountHtml := Loam.Web.Record.render missingAmount
  expect (contains missingAmountHtml "Not ready:")
    "Web Record did not preserve missing Amount as a visible review state"
  expect (contains missingAmountHtml "Nothing was written.")
    "Web Record refusal did not state the no-write result"

  IO.println "Web Record: From/To transport, shared admission preview, explicit confirmation, escaping, and refusal passed."
