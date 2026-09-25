import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.MovementAdmission
import Loam.Presentation.Record
import Loam.Web.Snapshot

namespace Loam.Web.Record

set_option autoImplicit false

/-!
# Web Record form, review, and explicit confirmation

This module adapts one conservative HTML form to the shared
`Loam.Presentation.Record` boundary. It owns no household publication,
canonical path, writer lock, or accounting semantics. It carries only the
opaque logical operation identity needed for retry-safe confirmation.
-/

structure Request where
  date : String
  description : String := ""
  measure : String := "jpy"
  fromLocus : String := ""
  toLocus : String := ""
  amount : String := ""
  deriving Repr, DecidableEq, Inhabited

/--
Signed posting entry for the explicit multi-posting Web path.

The fixed six-row presentation window matches the current TUI's practical editing
bound without imposing that bound on the shared Record semantics.
-/
structure PostingRequest where
  date : String
  description : String := ""
  measure : String := "jpy"
  rows : Array Loam.Presentation.Record.Row :=
    #[{}, {}, {}, {}, {}, {}]
  deriving Repr, DecidableEq, Inhabited

inductive ReviewState where
  | editing
  | rejected (message : String)
  | ready (preview : Loam.Presentation.Record.Preview)

structure Model where
  operation : String
  request : Request
  catalog : Loam.LocusCatalog.Catalog
  measurePresentation : List Loam.MeasurePresentation.Metadata
  review : ReviewState := .editing

structure PostingModel where
  operation : String
  request : PostingRequest
  catalog : Loam.LocusCatalog.Catalog
  measurePresentation : List Loam.MeasurePresentation.Metadata
  review : ReviewState := .editing

def initial (operation date : String)
    (catalog : Loam.LocusCatalog.Catalog)
    (measurePresentation : List Loam.MeasurePresentation.Metadata) : Model := {
  operation := operation
  request := { date := date }
  catalog := catalog
  measurePresentation := measurePresentation
}

def postingsInitial (operation date : String)
    (catalog : Loam.LocusCatalog.Catalog)
    (measurePresentation : List Loam.MeasurePresentation.Metadata) : PostingModel := {
  operation := operation
  request := { date := date }
  catalog := catalog
  measurePresentation := measurePresentation
}

private def magnitude?
    (label text : String) : Except String String := do
  if text.isEmpty then
    throw ("Enter " ++ label ++ ".")
  match text.toList with
  | '-' :: _ | '+' :: _ =>
      throw ("Enter " ++ label ++ " without a sign; From/To supplies the direction.")
  | _ => pure text

/--
Translate the Web's recognition-friendly From/To + one Amount grammar into the
shared signed posting input. The same human-entered magnitude becomes the
negative From posting and positive To posting. This is presentation grammar only;
the shared Record boundary
still owns exact quantity parsing and Movement validation.
-/
def Request.toInput? (request : Request) :
    Except String Loam.Presentation.Record.Input := do
  let amount ← magnitude? "the amount" request.amount
  pure {
    date := request.date
    description := request.description
    measure := request.measure
    rows := #[
      { locus := request.fromLocus, amount := "-" ++ amount },
      { locus := request.toLocus, amount := amount }
    ]
  }

/--
Drop only completely unused presentation rows. A partially completed row remains
visible to the shared parser and is refused there rather than guessed or repaired.
-/
def PostingRequest.toInput (request : PostingRequest) :
    Loam.Presentation.Record.Input := {
  date := request.date
  description := request.description
  measure := request.measure
  rows := request.rows.filter fun row =>
    !(row.locus.isEmpty && row.amount.isEmpty)
}

/-- Check one Web request through the same read-only admission preview as the TUI. -/
def review
    (world : Loam.MovementAdmission.World)
    (model : Model) : Model :=
  match model.request.toInput? with
  | .error message => { model with review := .rejected message }
  | .ok input =>
      match Loam.Presentation.Record.preview?
          world model.measurePresentation input with
      | .error message => { model with review := .rejected message }
      | .ok preview => { model with review := .ready preview }

def reviewPostings
    (world : Loam.MovementAdmission.World)
    (model : PostingModel) : PostingModel :=
  match Loam.Presentation.Record.preview?
      world model.measurePresentation model.request.toInput with
  | .error message => { model with review := .rejected message }
  | .ok preview => { model with review := .ready preview }

private def esc (text : String) : String :=
  Loam.Web.Snapshot.escapeHtml text

private def inputText
    (name value : String) (size : Nat := 20) : String :=
  "<input type=\"text\" name=\"" ++ esc name ++ "\" value=\"" ++ esc value ++
    "\" size=\"" ++ toString size ++ "\">"

private def hiddenInput (name value : String) : String :=
  "<input type=\"hidden\" name=\"" ++ esc name ++ "\" value=\"" ++ esc value ++ "\">"

private def locusLabel (entry : Loam.LocusCatalog.Entry) : String :=
  if entry.label == entry.locus.token then entry.locus.token
  else entry.locus.token ++ "  " ++ entry.label

private def locusSelect
    (name selected : String) (catalog : Loam.LocusCatalog.Catalog) : String :=
  let selectedPresent := catalog.any fun entry => entry.locus.token == selected
  let stale :=
    if selected.isEmpty || selectedPresent then ""
    else
      "<option value=\"" ++ esc selected ++ "\" selected>" ++
        esc (selected ++ "  (not currently admitted)") ++ "</option>\n"
  let options :=
    catalog.map fun entry =>
      let selectedAttr := if entry.locus.token == selected then " selected" else ""
      "<option value=\"" ++ esc entry.locus.token ++ "\"" ++ selectedAttr ++ ">" ++
        esc (locusLabel entry) ++ "</option>"
  "<select name=\"" ++ esc name ++ "\">\n" ++
    "<option value=\"\"" ++ (if selected.isEmpty then " selected" else "") ++
      ">Choose Locus</option>\n" ++
    stale ++ String.intercalate "\n" options ++ "\n</select>"

private def scaleNote
    (metadata : List Loam.MeasurePresentation.Metadata)
    (measureText : String) : String :=
  if measureText.isEmpty then ""
  else
    let measure : Loam.Core.MeasureId := ⟨measureText⟩
    let scale := Loam.MeasurePresentation.scaleFor metadata measure
    "<span class=\"note\">exact display scale: " ++ esc (toString scale) ++ "</span>"

private def renderForm (model : Model) : String :=
  let request := model.request
  "<h2>Record</h2>\n" ++
  "<p class=\"note\">Build one balanced Movement. Review is read-only; no household write occurs here.</p>\n" ++
  "<form id=\"record-form\" action=\"/record/preview\" method=\"post\" accept-charset=\"UTF-8\">\n" ++
  hiddenInput "operation" model.operation ++ "\n" ++
  "<table class=\"facts\" summary=\"Record one household Movement\">\n" ++
  "<tr><th>Date</th><td>" ++ inputText "date" request.date 12 ++ "</td></tr>\n" ++
  "<tr><th>Description</th><td>" ++ inputText "description" request.description 40 ++ "</td></tr>\n" ++
  "<tr><th>Measure</th><td>" ++ inputText "measure" request.measure 10 ++
    " " ++ scaleNote model.measurePresentation request.measure ++ "</td></tr>\n" ++
  "<tr><th>From</th><td>" ++ locusSelect "from_locus" request.fromLocus model.catalog ++ "</td></tr>\n" ++
  "<tr><th>To</th><td>" ++ locusSelect "to_locus" request.toLocus model.catalog ++ "</td></tr>\n" ++
  "<tr><th>Amount</th><td>" ++ inputText "amount" request.amount 14 ++ "</td></tr>\n" ++
  "</table>\n" ++
  "<p><input type=\"submit\" value=\"Review\"> " ++
    "<a href=\"/record/postings\">Multiple postings</a> | " ++
    "<a href=\"/\">Back to Home</a></p>\n" ++
  "</form>"

private def postingFieldRows (model : PostingModel) : String :=
  String.intercalate "\n" <| (List.range model.request.rows.size).map fun index =>
    let row := model.request.rows[index]!
    let number := toString (index + 1)
    "<tr><th>Posting " ++ number ++ "</th><td>" ++
      locusSelect ("posting_" ++ number ++ "_locus") row.locus model.catalog ++
      " " ++ inputText ("posting_" ++ number ++ "_amount") row.amount 14 ++
      "</td></tr>"

private def renderPostingsForm (model : PostingModel) : String :=
  let request := model.request
  "<h2>Record / Multiple postings</h2>\n" ++
  "<p class=\"note\">Enter two to six signed postings. Negative moves value from a Locus; positive moves value to a Locus. Leave unused rows empty.</p>\n" ++
  "<form id=\"record-postings-form\" action=\"/record/postings/preview\" method=\"post\" accept-charset=\"UTF-8\">\n" ++
  hiddenInput "operation" model.operation ++ "\n" ++
  "<table class=\"facts\" summary=\"Record one household Movement with multiple signed postings\">\n" ++
  "<tr><th>Date</th><td>" ++ inputText "date" request.date 12 ++ "</td></tr>\n" ++
  "<tr><th>Description</th><td>" ++ inputText "description" request.description 40 ++ "</td></tr>\n" ++
  "<tr><th>Measure</th><td>" ++ inputText "measure" request.measure 10 ++
    " " ++ scaleNote model.measurePresentation request.measure ++ "</td></tr>\n" ++
  postingFieldRows model ++ "\n</table>\n" ++
  "<p><input type=\"submit\" value=\"Review\"> " ++
    "<a href=\"/record\">Ordinary Record</a> | <a href=\"/\">Back to Home</a></p>\n" ++
  "</form>"

private def renderRejected (message : String) : String :=
  "<div class=\"review rejected\">\n" ++
  "<h2>Review</h2>\n" ++
  "<p class=\"unavailable\">Not ready: " ++ esc message ++ "</p>\n" ++
  "<p class=\"note\">Nothing was written.</p>\n" ++
  "</div>"

private def renderReady (model : Model)
    (preview : Loam.Presentation.Record.Preview) : String :=
  let draft := preview.draft
  let request := model.request
  let metadata := model.measurePresentation
  let measure := (draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩
  let rows :=
    draft.effects.map fun effect =>
      "<tr><td>" ++ esc effect.locus.token ++ "</td><td>" ++
        esc (Loam.MeasurePresentation.formatQuanta
          metadata effect.measure effect.quantity.quanta) ++
        " " ++ esc effect.measure.token ++ "</td></tr>"
  "<div class=\"review ready\">\n" ++
  "<h2>Review</h2>\n" ++
  "<table class=\"facts\" summary=\"Reviewed Movement\">\n" ++
  "<tr><th>Date</th><td>" ++ esc draft.validOn ++ "</td></tr>\n" ++
  "<tr><th>Description</th><td>" ++
    esc (draft.description.getD "(none)") ++ "</td></tr>\n" ++
  "<tr><th>Measure</th><td>" ++ esc measure.token ++ "</td></tr>\n" ++
  "<tr><th>Exact balance</th><td>yes</td></tr>\n" ++
  "<tr><th>Total</th><td>" ++
    esc (Loam.MeasurePresentation.formatQuanta metadata measure draft.total) ++
    " " ++ esc measure.token ++ "</td></tr>\n" ++
  "</table>\n" ++
  "<table summary=\"Reviewed signed postings\">\n" ++
  "<tr><th>Locus</th><th>Signed amount</th></tr>\n" ++
  String.intercalate "\n" rows ++ "\n</table>\n" ++
  "<p class=\"note\">Admissible against the household world read for this review. " ++
    "Confirm rebuilds the draft and the household writer re-reads authority before publication.</p>\n" ++
  "<form action=\"/record/confirm\" method=\"post\" accept-charset=\"UTF-8\">\n" ++
  hiddenInput "operation" model.operation ++ "\n" ++
  hiddenInput "date" request.date ++ "\n" ++
  hiddenInput "description" request.description ++ "\n" ++
  hiddenInput "measure" request.measure ++ "\n" ++
  hiddenInput "from_locus" request.fromLocus ++ "\n" ++
  hiddenInput "to_locus" request.toLocus ++ "\n" ++
  hiddenInput "amount" request.amount ++ "\n" ++
  "<p><input type=\"submit\" value=\"Record\"> " ++
    "<a href=\"#record-form\">Back to edit</a></p>\n" ++
  "</form>\n" ++
  "<p class=\"note\">The operation identity makes a repeated Confirm safe to retry.</p>\n" ++
  "</div>"

private def postingHiddenRows (request : PostingRequest) : String :=
  String.intercalate "\n" <| (List.range request.rows.size).flatMap fun index =>
    let row := request.rows[index]!
    let number := toString (index + 1)
    [ hiddenInput ("posting_" ++ number ++ "_locus") row.locus
    , hiddenInput ("posting_" ++ number ++ "_amount") row.amount
    ]

private def renderPostingsReady (model : PostingModel)
    (preview : Loam.Presentation.Record.Preview) : String :=
  let draft := preview.draft
  let request := model.request
  let metadata := model.measurePresentation
  let measure := (draft.effects.head?.map Loam.Core.Effect.measure).getD ⟨"?"⟩
  let rows :=
    draft.effects.map fun effect =>
      "<tr><td>" ++ esc effect.locus.token ++ "</td><td>" ++
        esc (Loam.MeasurePresentation.formatQuanta
          metadata effect.measure effect.quantity.quanta) ++
        " " ++ esc effect.measure.token ++ "</td></tr>"
  "<div class=\"review ready\">\n" ++
  "<h2>Review</h2>\n" ++
  "<table class=\"facts\" summary=\"Reviewed Movement\">\n" ++
  "<tr><th>Date</th><td>" ++ esc draft.validOn ++ "</td></tr>\n" ++
  "<tr><th>Description</th><td>" ++ esc (draft.description.getD "(none)") ++ "</td></tr>\n" ++
  "<tr><th>Measure</th><td>" ++ esc measure.token ++ "</td></tr>\n" ++
  "<tr><th>Exact balance</th><td>yes</td></tr>\n" ++
  "<tr><th>Total</th><td>" ++
    esc (Loam.MeasurePresentation.formatQuanta metadata measure draft.total) ++
    " " ++ esc measure.token ++ "</td></tr>\n</table>\n" ++
  "<table summary=\"Reviewed signed postings\">\n" ++
  "<tr><th>Locus</th><th>Signed amount</th></tr>\n" ++
  String.intercalate "\n" rows ++ "\n</table>\n" ++
  "<p class=\"note\">Admissible against the household world read for this review. Confirm rebuilds all signed postings and the household writer re-reads authority before publication.</p>\n" ++
  "<form action=\"/record/postings/confirm\" method=\"post\" accept-charset=\"UTF-8\">\n" ++
  hiddenInput "operation" model.operation ++ "\n" ++
  hiddenInput "date" request.date ++ "\n" ++
  hiddenInput "description" request.description ++ "\n" ++
  hiddenInput "measure" request.measure ++ "\n" ++
  postingHiddenRows request ++ "\n" ++
  "<p><input type=\"submit\" value=\"Record\"> <a href=\"#record-postings-form\">Back to edit</a></p>\n" ++
  "</form>\n" ++
  "<p class=\"note\">The operation identity makes a repeated Confirm safe to retry.</p>\n" ++
  "</div>"

private def renderPostingsReview (model : PostingModel) : String :=
  match model.review with
  | .editing => ""
  | .rejected message => renderRejected message
  | .ready preview => renderPostingsReady model preview

private def renderReview (model : Model) : String :=
  match model.review with
  | .editing => ""
  | .rejected message => renderRejected message
  | .ready preview => renderReady model preview

private def style : String :=
  String.intercalate "\n"
    [ "body { font-family: monospace; margin: 0; padding: 1em; line-height: 1.4; color: #111; background: #fff; }"
    , "#page { max-width: 60em; margin: 0 auto; }"
    , "#header { border-bottom: 1px solid #888; margin-bottom: .75em; padding-bottom: .5em; }"
    , "h1 { font-size: 1.5em; margin: 0 0 .25em 0; }"
    , "h2 { font-size: 1.1em; margin: 1em 0 .5em 0; }"
    , ".subtitle, .note { color: #555; }"
    , ".unavailable { border-left: .25em solid #666; padding-left: .75em; }"
    , "table { border-collapse: collapse; margin: .4em 0 .8em 0; }"
    , "th, td { border: 1px solid #aaa; padding: .3em .45em; text-align: left; vertical-align: top; }"
    , "input, select { font-family: monospace; }"
    ]

def render (model : Model) : String :=
  String.intercalate "\n"
    [ "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
    , "<html lang=\"en\">"
    , "<head>"
    , "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"
    , "  <title>LOAM Record</title>"
    , "  <style type=\"text/css\">" ++ style ++ "</style>"
    , "</head>"
    , "<body><div id=\"page\">"
    , "<div id=\"header\"><h1>LOAM</h1><div class=\"subtitle\">Record preview</div></div>"
    , renderForm model
    , renderReview model
    , "</div></body></html>"
    ]

def renderPostings (model : PostingModel) : String :=
  String.intercalate "\n"
    [ "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
    , "<html lang=\"en\">"
    , "<head>"
    , "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"
    , "  <title>LOAM Record / Multiple postings</title>"
    , "  <style type=\"text/css\">" ++ style ++ "</style>"
    , "</head>"
    , "<body><div id=\"page\">"
    , "<div id=\"header\"><h1>LOAM</h1><div class=\"subtitle\">Record multiple postings</div></div>"
    , renderPostingsForm model
    , renderPostingsReview model
    , "</div></body></html>"
    ]

def renderUnavailable (message : String) : String :=
  String.intercalate "\n"
    [ "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
    , "<html lang=\"en\"><head>"
    , "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"
    , "<title>LOAM Record</title>"
    , "<style type=\"text/css\">" ++ style ++ "</style>"
    , "</head><body><div id=\"page\">"
    , "<div id=\"header\"><h1>LOAM</h1><div class=\"subtitle\">Record preview</div></div>"
    , "<h2>Record</h2>"
    , "<p class=\"unavailable\">Unavailable: " ++ esc message ++ "</p>"
    , "<p><a href=\"/\">Back to Home</a></p>"
    , "</div></body></html>"
    ]

end Loam.Web.Record
