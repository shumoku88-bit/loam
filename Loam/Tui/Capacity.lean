import Loam.CapacityReview
import Loam.ActualReview
import Loam.Tui.Kernel

namespace Loam.Tui.Capacity

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Read-only Capacity workspace

This surface consumes the shared all-retained `CapacityReview` answer. It does
not choose a cycle, infer a time window, classify operation kinds, or publish
Capacity movements.
-/

structure State where
  snapshot : Loam.CapacityReview.Snapshot

inductive Step where
  | stay (state : State)
  | back


def initial (snapshot : Loam.CapacityReview.Snapshot) : State :=
  { snapshot := snapshot }


def update (state : State) (back : Bool) : Step :=
  if back then .back else .stay state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def rowLine (row : Loam.CapacityReview.Row) : Widget :=
  let purpose := Loam.ActualReview.shortText 46 row.purpose.token
  line ("- " ++ purpose ++ ": " ++ toString row.entitlement.quanta ++ " jpy")

/-- Render the current all-retained JPY entitlement projection only. -/
def view (state : State) : Widget :=
  if state.snapshot.rows.isEmpty then
    .column
      [ line "Capacity / Current"
      , muted "Home > Capacity"
      , muted "0 remembered purposes"
      , blank
      , line "No spending-purpose capacity is retained."
      , blank
      , muted "All-retained view; no cycle or time window is inferred."
      , muted "b home   q quit"
      ]
  else
    .column <|
      [ line "Capacity / Current"
      , muted "Home > Capacity"
      , muted (toString state.snapshot.rows.length ++ " remembered purpose(s)")
      , blank
      ] ++
      (state.snapshot.rows.take 12).map rowLine ++
      [ blank
      , muted "Entitlement is derived from all retained JPY Capacity movements."
      , muted "Order shown is first retained appearance, not priority."
      , muted "No cycle, period, or selected-day meaning is inferred here."
      , muted "Read-only: Capacity publication remains outside this surface."
      , muted "b home   q quit"
      ]

end Loam.Tui.Capacity
