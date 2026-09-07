import Loam.AttentionReview
import Loam.ActualReview
import Loam.Tui.Kernel

namespace Loam.Tui.Attention

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Read-only Attention workspace

This surface consumes the shared `AttentionReview` answer. It does not decide
lifecycle, sort by due date, infer selected-day membership, or publish writes.
Representation order is shown only as representation order.
-/

structure State where
  evidence : Loam.AttentionReview.Availability

inductive Step where
  | stay (state : State)
  | back


def initial (evidence : Loam.AttentionReview.Availability) : State :=
  { evidence := evidence }


def update (state : State) (back : Bool) : Step :=
  if back then .back else .stay state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def itemLine (item : Loam.Core.Attention String) : Widget :=
  line ("- " ++ Loam.ActualReview.shortText 72 (Loam.AttentionReview.summary item))

/--
Render only the shared current-open answer.

Unavailable is deliberately not rendered as zero open items. An explicit empty
configured stream is rendered separately as `0 open`.
-/
def view (state : State) : Widget :=
  match state.evidence with
  | .unavailable =>
      .column
        [ line "Attention / Unavailable"
        , muted "Home > Attention"
        , blank
        , line "No canonical Attention stream is configured."
        , muted "Unavailable is not a claim that there are zero open matters."
        , blank
        , muted "b home   q quit"
        ]
  | .available snapshot =>
      if snapshot.openItems.isEmpty then
        .column
          [ line "Attention / Open"
          , muted "Home > Attention"
          , muted "0 open"
          , blank
          , line "The configured Attention stream has no currently open items."
          , blank
          , muted "b home   q quit"
          ]
      else
        .column <|
          [ line "Attention / Open"
          , muted "Home > Attention"
          , muted (toString snapshot.openItems.length ++ " open")
          , blank
          ] ++
          (snapshot.openItems.take 12).map itemLine ++
          [ blank
          , muted "Due / no due date / due unknown remain distinct."
          , muted "Order shown is representation order, not priority or due ordering."
          , muted "Read-only: no lifecycle or write decisions live in this surface."
          , muted "b home   q quit"
          ]

end Loam.Tui.Attention
