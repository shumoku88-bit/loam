import Loam.ActualReview
import Loam.AttentionReview
import Loam.CapacityReview
import Loam.ScheduledReview

namespace Loam.Web.Snapshot

open Loam.Core

set_option autoImplicit false

/-!
# Read-only Web snapshot

This module is deliberately presentation-only. It consumes the same shared Review
answers used by existing frontends and renders one static HTML document.

The first Web slice intentionally targets a conservative HTML 4.01 / CSS 2.1-style
baseline so lightweight browsers can render the same semantic document without
JavaScript. Richer browser presentation must remain progressive enhancement.

It owns no household semantics, persistence, publication, recurrence, account
classification, or authority selection.
-/

structure Snapshot where
  observedAt : String
  actual : Except String (List Loam.ActualReview.Record)
  scheduled : Except String (List Loam.ScheduledReview.Record)
  attention : Except String Loam.AttentionReview.Availability
  capacity : Except String Loam.CapacityReview.Snapshot

private def escapeHtmlChar : Char → String
  | '&' => "&amp;"
  | '<' => "&lt;"
  | '>' => "&gt;"
  | '"' => "&quot;"
  | '\'' => "&#39;"
  | c => String.singleton c

def escapeHtml (text : String) : String :=
  String.intercalate "" (text.toList.map escapeHtmlChar)

private def unavailable (message : String) : String :=
  "<p class=\"unavailable\">Unavailable: " ++ escapeHtml message ++ "</p>"

private def empty (message : String) : String :=
  "<p class=\"empty\">" ++ escapeHtml message ++ "</p>"

private def renderRows (rows : List String) : String :=
  if rows.isEmpty then
    empty "No current items."
  else
    "<ul>\n" ++
      String.intercalate "\n" (rows.map fun row => "  <li>" ++ row ++ "</li>") ++
      "\n</ul>"

private def renderCard (title body : String) : String :=
  "<div class=\"card\">\n" ++
  "  <h2>" ++ escapeHtml title ++ "</h2>\n" ++
  body ++ "\n" ++
  "</div>"

private def renderActual
    (observedAt : String)
    (result : Except String (List Loam.ActualReview.Record)) : String :=
  match result with
  | .error message => unavailable message
  | .ok records =>
      let selected := (Loam.ActualReview.select records (.week observedAt)).take 12
      renderRows <| selected.map fun record =>
        "<span class=\"coordinate\">" ++ escapeHtml (record.date.getD "date unknown") ++ "</span> " ++
        escapeHtml (Loam.ActualReview.summary record)

private def renderScheduled
    (result : Except String (List Loam.ScheduledReview.Record)) : String :=
  match result with
  | .error message => unavailable message
  | .ok records =>
      let ordered := records.mergeSort fun left right =>
        if left.scheduledOn = right.scheduledOn then
          left.id.token <= right.id.token
        else
          left.scheduledOn <= right.scheduledOn
      renderRows <| (ordered.take 12).map fun record =>
        "<span class=\"coordinate\">" ++ escapeHtml record.scheduledOn ++ "</span> " ++
        escapeHtml (Loam.ScheduledReview.summary record)

private def renderAttention
    (result : Except String Loam.AttentionReview.Availability) : String :=
  match result with
  | .error message => unavailable message
  | .ok .unavailable => unavailable "Attention authority is not configured."
  | .ok (.available snapshot) =>
      renderRows <| snapshot.openItems.map fun item =>
        escapeHtml (Loam.AttentionReview.summary item)

private def renderCapacity
    (result : Except String Loam.CapacityReview.Snapshot) : String :=
  match result with
  | .error message => unavailable message
  | .ok snapshot =>
      renderRows <| snapshot.rows.map fun row =>
        "<span class=\"coordinate\">" ++ escapeHtml row.purpose.token ++ "</span> " ++
        escapeHtml (toString row.entitlement.quanta ++ " jpy")

def render (snapshot : Snapshot) : String :=
  String.intercalate "\n"
    [ "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
    , "<html lang=\"en\">"
    , "<head>"
    , "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"
    , "  <title>LOAM Web</title>"
    , "  <style type=\"text/css\">"
    , "    body { font-family: monospace; margin: 0; padding: 1em; line-height: 1.4; color: #111; background: #fff; }"
    , "    #page { max-width: 70em; margin: 0 auto; }"
    , "    #header { border-bottom: 1px solid #888; margin-bottom: 1em; padding-bottom: .5em; }"
    , "    h1 { font-size: 1.5em; margin: 0 0 .25em 0; }"
    , "    .subtitle, .footer, .empty { color: #555; }"
    , "    .card { border: 1px solid #999; margin: 0 0 1em 0; padding: .75em 1em; }"
    , "    .card h2 { font-size: 1.1em; margin: 0 0 .5em 0; }"
    , "    ul { margin: .25em 0; padding-left: 1.5em; }"
    , "    li { margin: .3em 0; }"
    , "    .coordinate { font-weight: bold; }"
    , "    .unavailable { border-left: .25em solid #666; padding-left: .75em; }"
    , "    .footer { border-top: 1px solid #aaa; margin-top: 1.5em; padding-top: .75em; font-size: .9em; }"
    , "  </style>"
    , "</head>"
    , "<body>"
    , "<div id=\"page\">"
    , "<div id=\"header\">"
    , "  <h1>LOAM</h1>"
    , "  <div class=\"subtitle\">read-only household web snapshot | observed " ++ escapeHtml snapshot.observedAt ++ "</div>"
    , "</div>"
    , renderCard "Recent Actual" (renderActual snapshot.observedAt snapshot.actual)
    , renderCard "Current-open Scheduled" (renderScheduled snapshot.scheduled)
    , renderCard "Open Attention" (renderAttention snapshot.attention)
    , renderCard "Capacity" (renderCapacity snapshot.capacity)
    , "<p class=\"footer\">Presentation only. This page does not own household authority and performs no writes.</p>"
    , "</div>"
    , "</body>"
    , "</html>"
    ]

end Loam.Web.Snapshot
