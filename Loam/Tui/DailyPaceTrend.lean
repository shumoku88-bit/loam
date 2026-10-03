import Loam.Tui.Layout
import Loam.Tui.Main

namespace Loam.Tui.DailyPaceTrend

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Daily Pace trend

A small read-only drill-down from Home.

Home keeps the current Daily Pace answer in the glance surface. This view exposes
the already-derived retrospective current-truth series without retaining a second
history or introducing another household calculation.
-/

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

private def paceLine
    (today : String)
    (snapshot : Loam.CycleSpendingPaceReview.Snapshot) : Widget :=
  let value :=
    match snapshot.dailyPaceQuanta? with
    | some quanta => toString quanta ++ " " ++ snapshot.measure.token ++ "/day"
    | none => "unavailable"
  let marker := if snapshot.observedAt == today then "  current" else ""
  line
    ("  " ++ Loam.Tui.Layout.padRight 12 snapshot.observedAt ++
      Loam.Tui.Layout.padLeft 16 value ++ marker)

/--
Render only the retrospective Daily Pace answer already loaded into the shared
Home snapshot. Failure remains visible here instead of competing with Home's
current household glance.
-/
def view (bounds : Bounds) (snapshot : Loam.Tui.Main.Snapshot) : Widget :=
  let body :=
    [ line "Daily Pace / Trend"
    , muted "How the current safe daily pace has changed"
    , blank
    ] ++
    (match snapshot.paceHistory with
     | .notRequested =>
         [muted "  history not requested"]
     | .unavailable =>
         [muted "  history unavailable"]
     | .failed message =>
         [ line "  history unavailable"
         , muted ("  " ++ Loam.Tui.Layout.clip
             (Loam.Tui.Layout.contentWidth bounds - 2) message)
         ]
     | .loaded history =>
         if history.isEmpty then
           [muted "  no reconstructed Daily Pace points"]
         else
           history.map (paceLine snapshot.actual.today)) ++
    [ blank
    , muted "Calculated from your current records each time; no separate daily snapshot is kept."
    ]
  let footer := [muted "q / Esc home"]
  .column (Loam.Tui.Layout.fitWithFooter bounds body footer)

end Loam.Tui.DailyPaceTrend
