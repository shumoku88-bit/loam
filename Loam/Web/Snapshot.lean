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

private def section (title body : String) : String :=
  "<section class=\"card\">\n" ++
  "  <h2>" ++ escapeHtml title ++ "</h2>\n" ++
  body ++ "\n" ++
  "</section>"

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
    [ "<!doctype html>"
    , "<html lang=\"en\">"
    , "<head>"
    , "  <meta charset=\"utf-8\">"
    , "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    , "  <title>LOAM Web</title>"
    , "  <style>"
    , "    :root { color-scheme: light dark; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }"
    , "    body { max-width: 1100px; margin: 0 auto; padding: 2rem 1rem 4rem; line-height: 1.45; }"
    , "    header { margin-bottom: 1.5rem; }"
    , "    h1 { margin-bottom: .25rem; }"
    , "    .subtitle, .footer, .empty { opacity: .72; }"
    , "    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(290px, 1fr)); gap: 1rem; }"
    , "    .card { border: 1px solid color-mix(in srgb, currentColor 22%, transparent); border-radius: 12px; padding: 1rem 1.1rem; }"
    , "    .card h2 { margin-top: 0; font-size: 1rem; }"
    , "    ul { margin: 0; padding-left: 1.2rem; }"
    , "    li + li { margin-top: .55rem; }"
    , "    .coordinate { font-weight: 700; }"
    , "    .unavailable { border-left: 3px solid currentColor; padding-left: .75rem; }"
    , "    .footer { margin-top: 1.5rem; font-size: .9rem; }"
    , "  </style>"
    , "</head>"
    , "<body>"
    , "<header>"
    , "  <h1>LOAM</h1>"
    , "  <div class=\"subtitle\">read-only household web snapshot · observed " ++ escapeHtml snapshot.observedAt ++ "</div>"
    , "</header>"
    , "<main class=\"grid\">"
    , section "Recent Actual" (renderActual snapshot.observedAt snapshot.actual)
    , section "Current-open Scheduled" (renderScheduled snapshot.scheduled)
    , section "Open Attention" (renderAttention snapshot.attention)
    , section "Capacity" (renderCapacity snapshot.capacity)
    , "</main>"
    , "<p class=\"footer\">Presentation only. This page does not own household authority and performs no writes.</p>"
    , "</body>"
    , "</html>"
    ]

end Loam.Web.Snapshot
