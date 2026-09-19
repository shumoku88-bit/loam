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

  IO.println "Web snapshot: presentation-only sections, explicit unavailability, and HTML escaping passed."
