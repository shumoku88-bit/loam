import Loam.Web.Snapshot

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (text needle : String) : Bool :=
  (text.splitOn needle).length > 1

def main (_args : List String) : IO Unit := do
  let budget : Loam.CycleBudgetReview.Snapshot := {
    observedAt := "2026-09-19"
    window := .error "<budget-window>"
    coverage := .error "<budget-coverage>"
    physical := .error "<budget-physical>"
    selection := .error "<budget-selection>"
    funding := .error "<budget-funding>"
  }

  let jpy : Loam.Core.MeasureId := { token := "jpy" }
  let cash : Loam.Core.LocusId := { token := "cash" }
  let food : Loam.Core.LocusId := { token := "food" }
  let some flowEvent1 := Loam.Core.Event.ofEffects? { token := "flow-1" } [
      Loam.Core.Effect.ofAnonymousQuantity cash jpy (Loam.Core.Quantity.ofQuanta 500),
      Loam.Core.Effect.ofAnonymousQuantity food jpy (Loam.Core.Quantity.ofQuanta (-500))
    ]
    | throw (IO.userError "could not build first Web Transactions Flow fixture Event")
  let some flowEvent2 := Loam.Core.Event.ofEffects? { token := "flow-2" } [
      Loam.Core.Effect.ofAnonymousQuantity cash jpy (Loam.Core.Quantity.ofQuanta (-200)),
      Loam.Core.Effect.ofAnonymousQuantity food jpy (Loam.Core.Quantity.ofQuanta 200)
    ]
    | throw (IO.userError "could not build second Web Transactions Flow fixture Event")
  let transactionsFlow : Loam.TransactionsFlowReview.Snapshot := {
    start := "2026-09-01"
    endExclusive := "2026-10-01"
    columns := [
      { event := flowEvent1, date := "2026-09-10", description := "first" },
      { event := flowEvent2, date := "2026-09-11", description := "second" }
    ]
  }

  let snapshot : Loam.Web.Snapshot.Snapshot := {
    observedAt := "2026-09-19"
    actual := .failed "<actual&unavailable>"
    scheduled := .loaded []
    attention := .unavailable
    budget := budget
    capacity := .loaded { rows := [] }
    pace := .loaded {
      observedAt := "2026-09-19"
      endExclusive := "2026-09-23"
      remainingDays := 4
      eligiblePool := Loam.Core.Quantity.ofQuanta 5000
      automaticDeductions := Loam.Core.Quantity.ofQuanta 1000
      availableThroughEnd := Loam.Core.Quantity.ofQuanta 4000
    }
    stockFlow := .loaded {
      start := "2026-09-01"
      endExclusive := "2026-10-01"
      reconstructedStart := Loam.Core.Quantity.ofQuanta 10000
      increasesAcrossEvents := Loam.Core.Quantity.ofQuanta 5000
      decreasesAcrossEvents := Loam.Core.Quantity.ofQuanta (-3000)
      currentTracked := Loam.Core.Quantity.ofQuanta 12000
    }
    transactionsFlow := .loaded transactionsFlow
    roleFlow := .loaded {
      start := "2026-09-01"
      endExclusive := "2026-10-01"
      rows := [
        { coordinate := {
            locus := { token := "salary" }
            measure := { token := "jpy" } }
          role := .income
          quantity := Loam.Core.Quantity.ofQuanta (-5000) },
        { coordinate := {
            locus := { token := "food" }
            measure := { token := "jpy" } }
          role := .expense
          quantity := Loam.Core.Quantity.ofQuanta 1200 },
        { coordinate := {
            locus := { token := "salary" }
            measure := { token := "usd" } }
          role := .income
          quantity := Loam.Core.Quantity.ofQuanta (-20) }
      ]
      unresolvedEffects := []
    }
    roleBalances := .loaded {
      rows := [
        { coordinate := {
            locus := { token := "cash" }
            measure := { token := "jpy" } }
          role := .asset
          quantity := Loam.Core.Quantity.ofQuanta 12000 }
      ]
      unresolvedRoles := [
        { coordinate := {
            locus := { token := "unknown" }
            measure := { token := "jpy" } }
          quantity := Loam.Core.Quantity.ofQuanta 300 }
      ]
      unsupportedBalances := [
        { coordinate := {
            locus := { token := "future" }
            measure := { token := "jpy" } }
          role := some .liability }
      ]
    }
    purposeMetadata := []
  }

  let html := Loam.Web.Snapshot.render snapshot

  expect (contains html "HTML 4.01")
    "Web snapshot did not retain the lightweight-browser HTML baseline"
  expect (contains html "<title>LOAM Web</title>")
    "Web snapshot did not render its document identity"
  expect (contains html "href=\"#home\"")
    "Web snapshot did not expose lightweight section navigation"
  expect (contains html "href=\"/record\"")
    "Web snapshot did not place the Record action near Home"
  expect (contains html ">[Record]</a>")
    "Web Home did not expose the frequent Record action"
  expect (contains html "id=\"home\" class=\"card\"")
    "Web snapshot did not expose the Lean-derived Home section"
  expect (contains html "Current household orientation derived from shared Lean Review answers.")
    "Web snapshot did not identify the Home presentation boundary"
  expect (contains html "Daily Pace")
    "Web snapshot did not expose Daily Pace on Home"
  expect (contains html "1000 jpy/day")
    "Web snapshot did not render the Lean-derived Daily Pace quotient"
  expect (contains html "href=\"#reports\"")
    "Web snapshot did not expose Reports navigation"
  expect (contains html "Current Cycle Stock-Flow")
    "Web snapshot did not expose the Stock-Flow report"
  expect (contains html "Opening tracked")
    "Web snapshot did not label the Stock-Flow opening"
  expect (contains html "12000 jpy")
    "Web snapshot did not render the reconstructed/current Stock-Flow quantity"
  expect (contains html "Transactions Flow")
    "Web snapshot did not expose Transactions Flow"
  expect (contains html "700 jpy")
    "Web snapshot did not preserve gross Transactions Flow activity"
  expect (contains html "300 jpy")
    "Web snapshot did not render Transactions Flow net activity"
  expect (contains html "2 selected Event(s)")
    "Web snapshot did not render Transactions Flow Event count"
  expect (contains html "Income &amp; Expense")
    "Web snapshot did not expose Income & Expense"
  expect (contains html "3800 jpy")
    "Web snapshot did not render the JPY Income & Expense result"
  expect (contains html "20 usd")
    "Web snapshot did not keep USD Income separate from JPY"
  expect (contains html "Evidence-aware current accounting balances")
    "Web snapshot did not expose evidence-aware Balances"
  expect (contains html "cash")
    "Web snapshot did not render the supported Balance row"
  expect (contains html "Unresolved roles: 1; unsupported balances: 1.")
    "Web snapshot did not preserve Balance evidence gaps"
  expect (contains html "Recent Actual")
    "Web snapshot did not expose the Actual section"
  expect (contains html "Current-open Scheduled")
    "Web snapshot did not expose the Scheduled section"
  expect (contains html "Current Budget")
    "Web snapshot did not expose the shared current-cycle Budget"
  expect (contains html "Raw Capacity (all retained)")
    "Web snapshot did not distinguish all-retained Capacity from current Budget"
  expect (contains html "This is not the current-cycle budget.")
    "Web snapshot did not explain the Raw Capacity distinction"
  expect (contains html "Open Attention")
    "Web snapshot did not expose the Attention section"
  expect (contains html "&lt;actual&amp;unavailable&gt;")
    "Web snapshot did not HTML-escape unavailable evidence"
  expect (!contains html "<actual&unavailable>")
    "Web snapshot leaked unescaped evidence into HTML"
  expect (contains html "Attention authority is not configured.")
    "Web snapshot collapsed missing Attention authority into an empty answer"
  expect (contains html "&lt;budget-coverage&gt;")
    "Web snapshot did not preserve Budget coverage failure as unavailable"
  expect (contains html "Presentation only.")
    "Web snapshot did not state its authority boundary"

  expect (!contains html "<main")
    "Web snapshot introduced an HTML5-only main wrapper into the baseline"
  expect (!contains html "<section")
    "Web snapshot introduced HTML5 section elements into the baseline"
  expect (!contains html "<header")
    "Web snapshot introduced HTML5 header elements into the baseline"
  expect (!contains html "display: grid")
    "Web snapshot introduced CSS Grid before progressive enhancement"
  expect (!contains html "color-mix(")
    "Web snapshot introduced modern color mixing into the baseline"
  expect (!contains html ":root")
    "Web snapshot introduced a modern root styling dependency into the baseline"
  expect (!contains html "border-radius")
    "Web snapshot introduced rounded-corner CSS into the baseline"

  IO.println "Web snapshot: lightweight HTML baseline, shared current Budget, explicit unavailability, and HTML escaping passed."
