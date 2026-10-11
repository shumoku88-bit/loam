import Loam.Tui.ScheduledPostingForm

open Loam.Tui.ScheduledPostingForm

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

/-- Compare the shared cyclic navigation with the former form-local arithmetic. -/
private def checkNavigation (form : Form) (count : Nat) : IO Unit := do
  for index in List.range (count + 4) do
    let focused := { form with focus := index }
    for back in [false, true] do
      let old := if back then (index + count - 1) % count
                 else (index + 1) % count
      let moved := moveFocus focused back
      expect (moved.focus == old && moved.rows == form.rows &&
        moved.date == form.date)
        s!"Scheduled focus moved or mutated form unexpectedly: {count}/{index}/{back}"

def main : IO Unit := do
  let two : Form := { date := "2026-10-11", rows := #[{}, {}] }
  expect (firstAction two == 5) "two-row Scheduled Preview action moved"
  expect ((moveFocus two false).focus == 1)
    "Tab did not move Scheduled focus to its first Locus"
  expect ((moveFocus two true).focus == 8)
    "Shift-Tab did not wrap to the last Scheduled action"
  expect ((moveFocus {two with focus := 8} false).focus == 0)
    "Tab did not wrap the last Scheduled action to due date"
  checkNavigation two 9

  let six : Form := { date := "2026-10-11", rows := #[{}, {}, {}, {}, {}, {}] }
  expect (firstAction six == 13) "six-row Scheduled Preview action moved"
  expect ((moveFocus six true).focus == 16)
    "Shift-Tab did not wrap six-row Scheduled editing"
  checkNavigation six 17

  let posting := { two with focus := 1 }
  let edited := editActive posting (fun text => text ++ "food")
  expect (edited.rows[0]!.locus == "food" && edited.focus == 1 &&
    edited.rows[1]!.locus.isEmpty)
    "Scheduled focus rewire changed the active Posting Locus identity"
  let amount := moveFocus edited false
  expect (amount.focus == 2 && (activeLocus? amount).isNone)
    "Scheduled Tab did not advance to Amount without changing the saved token"
  let appended := appendRow two
  expect (appended.rows.size == 3 && appended.focus == 5)
    "appending Scheduled Posting did not focus its new Locus"
  IO.println "Scheduled posting focus: wrap, dynamic rows and unchanged active-field identity passed."
