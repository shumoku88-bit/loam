import Loam.CurrentBalanceReview
import Loam.Tui.Kernel
import Loam.Tui.Layout

namespace Loam.Tui.Balances

open Loam.Core
open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Selected current balances

This is the compact Home > Balances presentation for the replaceable
`balance-view.tsv` selection.

The selection remains neutral `Locus × Measure` presentation configuration.
Current quantity support comes from the shared `RoleBalanceReview` answer so a
selected row may be:

- exact current quantity;
- known present with exact amount unknown;
- fully unsupported.

AccountingRole is not rendered or inferred here. The richer accounting
projection remains the Reports / Balances surface.
-/

inductive Row where
  | exact (coordinate : EffectCoordinate) (quantity : Quantity)
  | knownPresent (coordinate : EffectCoordinate)
  | unsupported (coordinate : EffectCoordinate)
  deriving Repr, DecidableEq

structure State where
  rows : List Row
  deriving Repr, DecidableEq

inductive Step where
  | stay (state : State)
  | back

private def exactQuantity?
    (snapshot : Loam.CurrentBalanceReview.Snapshot)
    (coordinate : EffectCoordinate) : Option Quantity :=
  match snapshot.rows.find? fun row => decide (row.coordinate = coordinate) with
  | some row => some row.quantity
  | none => none

private def rowFor
    (snapshot : Loam.CurrentBalanceReview.Snapshot)
    (coordinate : EffectCoordinate) : Row :=
  match exactQuantity? snapshot coordinate with
  | some quantity => .exact coordinate quantity
  | none =>
      if snapshot.knownPresent.contains coordinate then
        .knownPresent coordinate
      else
        .unsupported coordinate

/--
Project only the replaceable selected coordinates from the shared current
balance answer. Selection order remains presentation order and duplicates are
normalized.
-/
def initial
    (snapshot : Loam.CurrentBalanceReview.Snapshot)
    (coordinates : List EffectCoordinate) : State :=
  { rows := coordinates.eraseDups.map (rowFor snapshot) }

def update (state : State) (back : Bool) : Step :=
  if back then .back else .stay state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def exactLine (coordinate : EffectCoordinate) (quantity : Quantity) : Widget :=
  line
    ("  " ++ Loam.Tui.Layout.padRight 20 coordinate.locus.token ++
      Loam.Tui.Layout.padLeft 12 (toString quantity.quanta) ++
      " " ++ coordinate.measure.token)

private def knownPresentLine (coordinate : EffectCoordinate) : Widget :=
  line
    ("  " ++ Loam.Tui.Layout.padRight 20 coordinate.locus.token ++
      Loam.Tui.Layout.padLeft 12 "?" ++
      " " ++ coordinate.measure.token ++ "  present, amount unknown")

private def unsupportedLine (coordinate : EffectCoordinate) : Widget :=
  line
    ("  " ++ Loam.Tui.Layout.padRight 20 coordinate.locus.token ++
      Loam.Tui.Layout.padLeft 12 "?" ++
      " " ++ coordinate.measure.token ++ "  unsupported")

private def rowLine : Row → Widget
  | .exact coordinate quantity => exactLine coordinate quantity
  | .knownPresent coordinate => knownPresentLine coordinate
  | .unsupported coordinate => unsupportedLine coordinate

/-- Render selected current balances without strengthening their evidence. -/
def view (state : State) : Widget :=
  .column <|
    [ line "Balances / Current"
    , muted "Home > Balances"
    , muted "Selected neutral Locus × Measure coordinates; not an Account taxonomy."
    , blank
    ] ++
    (if state.rows.isEmpty then
      [muted "No balances are selected in the current balance view."]
    else
      (state.rows.take 12).map rowLine) ++
    [ blank
    , muted "Exact, amount-unknown, and unsupported states preserve current evidence."
    , muted "Rows follow balance-view order only."
    , muted "q / Esc home"
    ]

end Loam.Tui.Balances
