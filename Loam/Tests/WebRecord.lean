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
      [⟨"paypay"⟩, ⟨"books"⟩, ⟨"food"⟩, ⟨"shipping"⟩]
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

  let postingRequest : Loam.Web.Record.PostingRequest := {
    date := "2026-09-25"
    description := "split purchase"
    measure := "jpy"
    rows := #[
      { locus := "paypay", amount := "-3000" },
      { locus := "books", amount := "2000" },
      { locus := "food", amount := "700" },
      { locus := "shipping", amount := "300" },
      {},
      {}
    ]
  }
  let postingInput := postingRequest.toInput
  expect (postingInput.rows.size == 4)
    "Web multiple-posting input did not drop only unused rows"
  expect (postingInput.rows[0]!.amount == "-3000" &&
      postingInput.rows[3]!.amount == "300")
    "Web multiple-posting input changed signed amounts"
  let postingModel : Loam.Web.Record.PostingModel := {
    operation := "web-postings-operation"
    request := postingRequest
    catalog := catalog
    measurePresentation := []
  }
  let postingReviewed := Loam.Web.Record.reviewPostings w postingModel
  let postingHtml := Loam.Web.Record.renderPostings postingReviewed
  expect (contains postingHtml "action=\"/record/postings/preview\"")
    "Web multiple-posting form does not post to its preview route"
  expect (contains postingHtml "action=\"/record/postings/confirm\"")
    "Web multiple-posting review did not expose explicit confirmation"
  expect (contains postingHtml "-3000 jpy" &&
      contains postingHtml "2000 jpy" &&
      contains postingHtml "700 jpy" &&
      contains postingHtml "300 jpy")
    "Web multiple-posting review did not preserve all signed postings"
  expect (contains postingHtml "Leave unused rows empty")
    "Web multiple-posting form did not explain its bounded optional rows"

  let partialPosting : Loam.Web.Record.PostingRequest := {
    postingRequest with
    rows := #[
      { locus := "paypay", amount := "-3000" },
      { locus := "books", amount := "" },
      {}, {}, {}, {}
    ]
  }
  expect (partialPosting.toInput.rows.size == 2)
    "Web multiple-posting input silently dropped a partially completed row"
  let partialHtml := Loam.Web.Record.renderPostings
    (Loam.Web.Record.reviewPostings w { postingModel with request := partialPosting })
  expect (contains partialHtml "Not ready:")
    "Web multiple-posting path did not visibly refuse a partial row"

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

  IO.println "Web Record: ordinary and multiple-posting transport, shared admission preview, explicit confirmation, escaping, and refusal passed."
