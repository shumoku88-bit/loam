import Loam.BalanceReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.Balances

open Loam.Tui.Kernel

set_option autoImplicit false

structure State where
  snapshot : Loam.BalanceReview.Snapshot
  deriving Repr, DecidableEq

inductive Step where
  | stay (state : State)
  | back


def initial (snapshot : Loam.BalanceReview.Snapshot) : State :=
  { snapshot := snapshot }


def update (state : State) (back : Bool) : Step :=
  if back then .back else .stay state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def rowLine (row : Loam.BalanceReview.Row) : Widget :=
  line
    ("  " ++ Loam.Tui.Layout.padRight 20 row.coordinate.locus.token ++
      Loam.Tui.Layout.padLeft 12 (toString row.quantity.quanta) ++
      " " ++ row.coordinate.measure.token)

/-- Render the replaceable current balance view without accounting-role inference. -/
def view (state : State) : Widget :=
  .column <|
    [ line "Balances / Current"
    , muted "Home > Balances"
    , muted "Selected neutral Locus × Measure coordinates; not an Account taxonomy."
    , blank
    ] ++
    (if state.snapshot.rows.isEmpty then
      [muted "No balances are selected in the current balance view."]
    else
      (state.snapshot.rows.take 12).map rowLine) ++
    [ blank
    , muted "Zero is shown when explicitly derived; rows follow balance-view order only."
    , muted "b / Esc home   q quit"
    ]

end Loam.Tui.Balances
