import Loam.Tui.CyclicIndex
import Loam.Tui.ReportWindow

namespace Loam.Tui.ReportComparison

set_option autoImplicit false

/-!
# Two explicit report windows

This is replaceable presentation/query state only. It owns four editable date
coordinates plus focus. Report semantics, evidence, comparison arithmetic and
persistence remain elsewhere.
-/

structure State where
  leftStart : String := ""
  leftEndExclusive : String := ""
  rightStart : String := ""
  rightEndExclusive : String := ""
  focus : Fin 5 := ⟨4, by decide⟩
  deriving Repr, DecidableEq

/--
Seed Left from the current report window. When that window is a shiftable
calendar month, seed Right from the following month; otherwise copy the current
explicit coordinates. Both sides remain freely editable afterwards.
-/
def fromWindow (window : Loam.Tui.ReportWindow.State) : State :=
  let shifted := Loam.Tui.ReportWindow.shiftCalendarMonth window true
  let right :=
    if shifted.state = window then window else shifted.state
  {
    leftStart := window.form.start
    leftEndExclusive := window.form.endExclusive
    rightStart := right.form.start
    rightEndExclusive := right.form.endExclusive
    focus := ⟨4, by decide⟩
  }

/-- Move among Left Start/End, Right Start/End, and Run. -/
def moveFocus (state : State) (back : Bool) : State :=
  let next :=
    if back then Loam.Tui.CyclicIndex.backward 5 state.focus.val
    else Loam.Tui.CyclicIndex.forward 5 state.focus.val
  { state with focus := ⟨next, by
      dsimp [next]
      split
      · exact Loam.Tui.CyclicIndex.backward_lt 5 state.focus.val (by decide)
      · exact Loam.Tui.CyclicIndex.forward_lt 5 state.focus.val (by decide)⟩ }

/-- Edit only the active date coordinate. Run focus is inert. -/
def editActive (state : State) (edit : String → String) : State :=
  match state.focus.val with
  | 0 => { state with leftStart := edit state.leftStart }
  | 1 => { state with leftEndExclusive := edit state.leftEndExclusive }
  | 2 => { state with rightStart := edit state.rightStart }
  | 3 => { state with rightEndExclusive := edit state.rightEndExclusive }
  | _ => state

end Loam.Tui.ReportComparison
