import Loam.Application.CapacityWindowInspection

namespace Loam.Observation196

open Loam.Application

set_option autoImplicit false

/-!
# Observation 196 — Budget-window selection pressure

Observation 158 showed that the current household budget question does not earn
retained `BudgetPeriod` identity merely to exclude facts outside a half-open
coordinate window. Production `CapacityWindowInspection` therefore accepts an
explicit `[start, end)` query.

The production TUI now has one selected day. Before using that day to place a
Budget Window / Remaining answer on Home, this observation asks the missing
information question:

> does a selected day uniquely determine the budget window whose answer should
> be shown?

The bounded witness below deliberately models only window membership and exact
integer contribution. Observation 158 already qualified that membership shape;
Observation 181 already qualified Remaining as a derived component answer. This
observation isolates only window *selection* information.
-/

structure Window where
  start : Nat
  endExclusive : Nat
  deriving Repr, DecidableEq

/-- Reuse the production validity rule for the observation's window coordinates. -/
def Window.valid (window : Window) : Bool :=
  validCapacityWindow window.start window.endExclusive

/-- Query-local half-open membership. This is observation scaffolding, not retained state. -/
def Window.contains (window : Window) (day : Nat) : Bool :=
  decide (window.start ≤ day) && !(decide (window.endExclusive ≤ day))

structure TimedAmount where
  day : Nat
  quanta : Int
  deriving Repr, DecidableEq

/-- Tiny additive witness for how window membership can change a report answer. -/
def project (window : Window) (facts : List TimedAmount) : Int :=
  facts.foldr
    (fun fact total => if window.contains fact.day then fact.quanta + total else total)
    0

private def selectedDay : Nat := 15
private def narrow : Window := { start := 10, endExclusive := 20 }
private def wide : Window := { start := 0, endExclusive := 20 }

private def facts : List TimedAmount :=
  [ { day := 5, quanta := 20 },
    { day := 12, quanta := 30 } ]

/-- Both candidate windows satisfy the same production window-validity shape. -/
theorem both_candidate_windows_valid :
    narrow.valid = true ∧ wide.valid = true := by
  native_decide

/-- The same Home-selected day lies inside both candidate windows. -/
theorem same_selected_day_is_in_both_windows :
    narrow.contains selectedDay = true ∧ wide.contains selectedDay = true := by
  native_decide

/-- The narrower candidate excludes the older fact. -/
theorem narrow_answer : project narrow facts = 30 := by
  native_decide

/-- The wider candidate includes that same retained fact. -/
theorem wide_answer : project wide facts = 50 := by
  native_decide

/--
A selected day therefore does not determine one budget-window answer. The
household facts and selected day are identical; only the query boundaries differ.
-/
theorem selected_day_alone_does_not_determine_budget_answer :
    project narrow facts ≠ project wide facts := by
  native_decide

/-! ## Period identity is a separate question -/

structure NamedWindow where
  name : String
  window : Window

/-- A label contributes no report information when membership is coordinate-derived. -/
def projectNamed (named : NamedWindow) (facts : List TimedAmount) : Int :=
  project named.window facts

/--
Two differently named Cycle/Period candidates with the same coordinates produce
exactly the same coordinate-derived answer. Identity alone adds no information.
-/
theorem name_does_not_change_coordinate_answer
    (left right : NamedWindow)
    (facts : List TimedAmount)
    (hWindow : left.window = right.window) :
    projectNamed left facts = projectNamed right facts := by
  simp [projectNamed, hWindow]

/-! ## Finding

The pressure now separates cleanly:

```text
selected day
    X  does not determine
[start, end) budget window

explicit window or shared window-selection policy
    -> can determine the query

Cycle / BudgetPeriod identity
    -> still not earned merely to name those coordinates
```

So a Home Budget / Remaining summary must not infer a month, cycle, or Capacity
epoch from `State.selectedDate` inside the TUI. It needs one of:

1. an explicit `[start, end)` supplied by the interaction; or
2. a shared Application query policy whose evidence/configuration justifies one
   window for the selected context.

This observation does not choose that policy. In particular, it does not claim
that host-local month boundaries, pension/payment dates, first Capacity date, or
TUI calendar month are household budget boundaries.

Retained Period identity remains subject to Observation 158's stronger stop
condition: earn it only when equal time coordinates and equal household facts can
still require different membership, such as parallel overlapping budget regimes.
-/

end Loam.Observation196
