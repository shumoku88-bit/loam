import Loam.LocusCatalog
import Loam.MeasurePresentation
import Loam.MovementAdmission
import Loam.Presentation.Record
import Loam.Web.Snapshot

namespace Loam.Web.Record

set_option autoImplicit false

/-!
# Web Record form and read-only review

This module adapts one conservative HTML form to the shared
`Loam.Presentation.Record` boundary. It owns no household publication,
canonical path, writer lock, durable identity, or accounting semantics.
-/

structure Request where
  date : String
  description : String := ""
  measure : String := "jpy"
  fromLocus : String := ""
  fromAmount : String := ""
  toLocus : String := ""
  toAmount : String := ""
  deriving Repr, DecidableEq, Inhabited

inductive ReviewState where
  | editing
  | rejected (message : String)
  | ready (preview : Loam.Presentation.Record.Preview)

structure Model where
  request : Request
  catalog : Loam.LocusCatalog.Catalog
  measurePresentation : List Loam.MeasurePresentation.Metadata
  review : ReviewState := .editing

def initial (date : String)
    (catalog : Loam.LocusCatalog.Catalog)
    (measurePresentation : List Loam.MeasurePresentation.Metadata) : Model := {
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
Translate the Web's recognition-friendly From/To grammar into the shared signed
posting input. This is presentation grammar only; the shared Record boundary
still owns exact quantity parsing and Movement validation.
-/
def Request.toInput? (request : Request) :
    Except String Loam.Presentation.Record.Input := do
  let fromAmount ← magnitude? "the From amount" request.fromAmount
  let toAmount ← magnitude? "the To amount" request.toAmount
  pure {
    date := request.date
    description := request.description
    measure := request.measure
    rows := #[
      { locus := request.fromLocus, amount := "-" ++ fromAmount },
      { locus := request.toLocus, amount := toAmount }
    ]
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

private def esc (text : String) : String :=
  Loam.Web.Snapshot.escapeHtml text

private def inputText
    (name value : String) (size : Nat := 20) : String :=
  "<input type=\"text\" name=\"" ++ esc name ++ "\" value=\"" ++ esc value ++
    "\" size=\"" ++ toString size ++ "\">"

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
  "<form action=\"/record/preview\" method=\"post\" accept-charset=\"UTF-8\">\n" ++
  "<table class=\"facts\" summary=\"Record one household Movement\">\n" ++
  "<tr><th>Date</th><td>" ++ inputText "date" request.date 12 ++ "</td></tr>\n" ++
  "<tr><th>Description</th><td>" ++ inputText "description" request.description 40 ++ "</td></tr>\n" ++
  "<tr><th>Measure</th><td>" ++ inputText "measure" request.measure 10 ++
    " " ++ scaleNote model.measurePresentation request.measure ++ "</td></tr>\n" ++
  "<tr><th>From</th><td>" ++ locusSelect "from_locus" request.fromLocus model.catalog ++
    " " ++ inputText "from_amount" request.fromAmount 14 ++ "</td></tr>\n" ++
  "<tr><th>To</th><td>" ++ locusSelect "to_locus" request.toLocus model.catalog ++
    " " ++ inputText "to_amount" request.toAmount 14 ++ "</td></tr>\n" ++
  "</table>\n" ++
  "<p><input type=\"submit\" value=\"Review\"> " ++
    "<a href=\"/\">Back to Home</a></p>\n" ++
  "</form>"

private def renderRejected (message : String) : String :=
  "<div class=\"review rejected\">\n" ++
  "<h2>Review</h2>\n" ++
  "<p class=\"unavailable\">Not ready: " ++ esc message ++ "</p>\n" ++
  "<p class=\"note\">Nothing was written.</p>\n" ++
  "</div>"

private def renderReady
    (metadata : List Loam.MeasurePresentation.Metadata)
    (preview : Loam.Presentation.Record.Preview) : String :=
  let draft := preview.draft
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
    "No Event identity is reserved and no household write has occurred.</p>\n" ++
  "<p class=\"note\">Publication is deliberately unavailable in this slice.</p>\n" ++
  "</div>"

private def renderReview (model : Model) : String :=
  match model.review with
  | .editing => ""
  | .rejected message => renderRejected message
  | .ready preview => renderReady model.measurePresentation preview

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
