import Loam.Web.Snapshot

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def contains (text needle : String) : Bool :=
  (text.splitOn needle).length > 1

def main (_args : List String) : IO Unit := do
  let snapshot : Loam.Web.Snapshot.Snapshot := {
    observedAt := "2026-09-19"
    actual := .error "<actual&unavailable>"
    scheduled := .ok []
    attention := .ok .unavailable
    capacity := .ok { rows := [] }
  }

  let html := Loam.Web.Snapshot.render snapshot

  expect (contains html "HTML 4.01")
    "Web snapshot did not retain the lightweight-browser HTML baseline"
  expect (contains html "<title>LOAM Web</title>")
    "Web snapshot did not render its document identity"
  expect (contains html "Recent Actual")
    "Web snapshot did not expose the Actual section"
  expect (contains html "Current-open Scheduled")
    "Web snapshot did not expose the Scheduled section"
  expect (contains html "Open Attention")
    "Web snapshot did not expose the Attention section"
  expect (contains html "Capacity")
    "Web snapshot did not expose the Capacity section"
  expect (contains html "&lt;actual&amp;unavailable&gt;")
    "Web snapshot did not HTML-escape unavailable evidence"
  expect (!contains html "<actual&unavailable>")
    "Web snapshot leaked unescaped evidence into HTML"
  expect (contains html "Attention authority is not configured.")
    "Web snapshot collapsed missing Attention authority into an empty answer"
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

  IO.println "Web snapshot: lightweight HTML baseline, explicit unavailability, and HTML escaping passed."
