import Loam.ActualReview
import Loam.AttentionReview
import Loam.CapacityReview
import Loam.CycleBudgetReview
import Loam.PurposeCatalog
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
  budget : Loam.CycleBudgetReview.Snapshot
  capacity : Except String Loam.CapacityReview.Snapshot
  purposeMetadata : List Loam.PurposeCatalog.Metadata := []

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

private def quantityText (quantity : Quantity) : String :=
  escapeHtml (toString quantity.quanta ++ " jpy")

private def tableCell (content : String) : String :=
  "<td>" ++ content ++ "</td>"

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
      renderRows <| (records.take 12).map fun record =>
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

private def renderBudgetWindow (snapshot : Loam.CycleBudgetReview.Snapshot) : String :=
  match snapshot.window with
  | .error message => unavailable ("Current cycle boundary: " ++ message)
  | .ok window =>
      "<p><span class=\"coordinate\">" ++ escapeHtml window.source ++ " Cycle</span> " ++
      escapeHtml window.start ++ " to " ++ escapeHtml window.endExclusive ++
      " (end exclusive)</p>"

private def renderBudgetFunding (snapshot : Loam.CycleBudgetReview.Snapshot) : String :=
  match snapshot.funding with
  | .error message => unavailable ("Funding: " ++ message)
  | .ok summary =>
      "<table class=\"facts\" summary=\"Current budget funding\">\n" ++
      "<tr><th>Budgetable backing</th>" ++ tableCell (quantityText summary.budgetableBacking) ++ "</tr>\n" ++
      "<tr><th>Remaining assigned</th>" ++ tableCell (quantityText summary.remainingAssigned) ++ "</tr>\n" ++
      "<tr><th>Residual before unresolved</th>" ++
        tableCell (quantityText summary.residualBeforeUnresolved) ++ "</tr>\n" ++
      "</table>"

private def renderBudgetPressure (snapshot : Loam.CycleBudgetReview.Snapshot) : String :=
  match snapshot.coverage with
  | .error message => unavailable ("Current coverage: " ++ message)
  | .ok coverage =>
      let scheduled :=
        match coverage.scheduledFrontier with
        | none => unavailable "Future pressure: Scheduled frontier is unavailable."
        | some frontier =>
            "<table class=\"facts\" summary=\"Future pressure\">\n" ++
            "<tr><th>Unresolved future pressure</th>" ++
              tableCell (quantityText frontier.unresolvedEligibility) ++ "</tr>\n" ++
            "<tr><th>Unrouted future pressure</th>" ++
              tableCell (quantityText frontier.unrouted) ++ "</tr>\n" ++
            "<tr><th>Unmanaged future pressure</th>" ++
              tableCell (quantityText frontier.unmanaged) ++ "</tr>\n" ++
            "</table>"
      let expenseCount := coverage.actualRoutingFrontier.unroutedExpense.length
      let unresolvedRoleCount := coverage.actualRoutingFrontier.unresolvedRole.length
      let routing :=
        if expenseCount == 0 && unresolvedRoleCount == 0 then ""
        else
          "<p class=\"note\">Actual routing frontier: " ++
          escapeHtml (toString expenseCount) ++ " unrouted Expense row(s); " ++
          escapeHtml (toString unresolvedRoleCount) ++ " role-unresolved row(s).</p>"
      scheduled ++ routing

private def renderBudgetCoverage
    (metadata : List Loam.PurposeCatalog.Metadata)
    (snapshot : Loam.CycleBudgetReview.Snapshot) : String :=
  match snapshot.coverage with
  | .error message => unavailable ("Purpose coverage: " ++ message)
  | .ok coverage =>
      if coverage.rows.isEmpty then
        empty "No current Purpose coverage rows."
      else
        let rows := coverage.rows.map fun row =>
          "<tr>" ++
          "<td class=\"purpose\">" ++
            escapeHtml (Loam.PurposeCatalog.labelFor metadata row.purpose) ++ "</td>" ++
          tableCell (quantityText row.entitlement) ++
          tableCell (quantityText row.consumption) ++
          tableCell (quantityText row.remaining) ++
          tableCell (quantityText row.commitment) ++
          tableCell (quantityText row.headroom) ++
          "</tr>"
        "<table class=\"budget\" summary=\"Current cycle Purpose budget coverage\">\n" ++
        "<tr><th>Purpose</th><th>Cap</th><th>Spent</th><th>Now</th>" ++
        "<th>Known future</th><th>After-known</th></tr>\n" ++
        String.intercalate "\n" rows ++
        "\n</table>"

private def renderBudget
    (metadata : List Loam.PurposeCatalog.Metadata)
    (snapshot : Loam.CycleBudgetReview.Snapshot) : String :=
  renderBudgetWindow snapshot ++
  "<h3>Funding</h3>\n" ++ renderBudgetFunding snapshot ++
  "<h3>Purpose coverage</h3>\n" ++ renderBudgetCoverage metadata snapshot ++
  "<h3>Unresolved pressure</h3>\n" ++ renderBudgetPressure snapshot

private def renderCapacity
    (metadata : List Loam.PurposeCatalog.Metadata)
    (result : Except String Loam.CapacityReview.Snapshot) : String :=
  match result with
  | .error message => unavailable message
  | .ok snapshot =>
      "<p class=\"note\">All-retained Capacity entitlement. This is not the current-cycle budget.</p>\n" ++
      (renderRows <| snapshot.rows.map fun row =>
        "<span class=\"coordinate\">" ++
        escapeHtml (Loam.PurposeCatalog.labelFor metadata row.purpose) ++ "</span> " ++
        quantityText row.entitlement)

def render (snapshot : Snapshot) : String :=
  String.intercalate "\n"
    [ "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
    , "<html lang=\"en\">"
    , "<head>"
    , "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"
    , "  <title>LOAM Web</title>"
    , "  <style type=\"text/css\">"
    , "    body { font-family: monospace; margin: 0; padding: 1em; line-height: 1.4; color: #111; background: #fff; }"
    , "    #page { max-width: 78em; margin: 0 auto; }"
    , "    #header { border-bottom: 1px solid #888; margin-bottom: 1em; padding-bottom: .5em; }"
    , "    h1 { font-size: 1.5em; margin: 0 0 .25em 0; }"
    , "    h3 { font-size: 1em; margin: 1em 0 .4em 0; }"
    , "    .subtitle, .footer, .empty, .note { color: #555; }"
    , "    .card { border: 1px solid #999; margin: 0 0 1em 0; padding: .75em 1em; }"
    , "    .card h2 { font-size: 1.1em; margin: 0 0 .5em 0; }"
    , "    ul { margin: .25em 0; padding-left: 1.5em; }"
    , "    li { margin: .3em 0; }"
    , "    .coordinate { font-weight: bold; }"
    , "    .unavailable { border-left: .25em solid #666; padding-left: .75em; }"
    , "    table { border-collapse: collapse; margin: .4em 0 .8em 0; width: 100%; }"
    , "    th, td { border: 1px solid #aaa; padding: .3em .45em; text-align: right; vertical-align: top; }"
    , "    th:first-child, td:first-child, .facts th { text-align: left; }"
    , "    .facts { width: auto; }"
    , "    .purpose { font-weight: bold; }"
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
    , renderCard "Current Budget" (renderBudget snapshot.purposeMetadata snapshot.budget)
    , renderCard "Open Attention" (renderAttention snapshot.attention)
    , renderCard "Raw Capacity (all retained)" (renderCapacity snapshot.purposeMetadata snapshot.capacity)
    , "<p class=\"footer\">Presentation only. This page does not own household authority and performs no writes.</p>"
    , "</div>"
    , "</body>"
    , "</html>"
    ]

end Loam.Web.Snapshot
