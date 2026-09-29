import Loam.Tui.Record

namespace Loam.Tui.ScheduledPostingForm

set_option autoImplicit false

/--
Shared local form mechanics for the two Scheduled editors that edit one date
plus a bounded list of signed posting rows.

Creation/replacement semantics, candidate selection, validation, preview, and
publication stay in their owning editors.
-/
structure Form where
  date : String
  rows : Array Loam.Tui.Record.Row
  focus : Nat := 0
  deriving Repr, DecidableEq

private def focusCount (form : Form) : Nat :=
  1 + form.rows.size * 2 + 4

def firstAction (form : Form) : Nat :=
  1 + form.rows.size * 2

def moveFocus (form : Form) (back : Bool) : Form :=
  let count := focusCount form
  let next := if back then (form.focus + count - 1) % count
              else (form.focus + 1) % count
  { form with focus := next }

private def replaceRows (form : Form) (rows : Array Loam.Tui.Record.Row) : Form :=
  { form with rows := rows, focus := 0 }

def appendRow (form : Form) : Form :=
  let rows := form.rows.push {}
  { form with rows := rows, focus := 1 + form.rows.size * 2 }

def dropRow (form : Form) : Form :=
  if form.rows.size > 2 then replaceRows form form.rows.pop else form

def editActive (form : Form) (edit : String → String) : Form :=
  if form.focus = 0 then
    { form with date := edit form.date }
  else
    let offset := form.focus - 1
    let index := offset / 2
    if h : index < form.rows.size then
      let row := form.rows[index]
      let row := if offset % 2 = 0
        then { row with locus := edit row.locus }
        else { row with amount := edit row.amount }
      { form with rows := form.rows.set index row }
    else form

def activeLocus? (form : Form) : Option String := do
  if form.focus = 0 then none else do
    let offset := form.focus - 1
    if offset % 2 != 0 then none else do
      let row ← form.rows[offset / 2]?
      some row.locus

end Loam.Tui.ScheduledPostingForm
