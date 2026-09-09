import Loam.ActualRoutingPublisher
import Loam.ActualRoutingReview
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.ActualRoutingAdministration

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Layout
open Loam.Tui.Terminal

set_option autoImplicit false

/-!
# Actual routing administration

Presentation-only workspace over `ActualRoutingReview.Snapshot`.

The surface shows every currently admitted Locus that explicit AccountingRole
evidence classifies as Expense, including managed, unmanaged, and unrouted rows.
It can append one explicit dated routing assertion through the shared
`ActualRoutingPublisher`; it does not infer Purpose from spelling and it does not
rename Purpose identity.
-/

inductive TargetChoice where
  | managed
  | unmanaged
  deriving Repr, DecidableEq

inductive Phase where
  | selectLocus
  | selectTarget
  | selectPurpose
  | preview
  deriving Repr, DecidableEq

structure State where
  snapshot : Loam.ActualRoutingReview.Snapshot
  phase : Phase := .selectLocus
  locusIndex : Nat := 0
  targetChoice : TargetChoice := .managed
  purposeIndex : Nat := 0
  notice : String := ""
  deriving Repr

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ActualRoutingPublisher.Draft := none
  deriving Repr


def initial (snapshot : Loam.ActualRoutingReview.Snapshot) : State :=
  { snapshot := snapshot }


def selectedRow? (state : State) : Option Loam.ActualRoutingReview.Row :=
  state.snapshot.rows[state.locusIndex]?


def selectedPurpose? (state : State) : Option PurposeId :=
  state.snapshot.purposes[state.purposeIndex]?


def draft? (state : State) : Option Loam.ActualRoutingPublisher.Draft := do
  let row ← selectedRow? state
  let target ←
    match state.targetChoice with
    | .unmanaged => some Loam.ActualRoutingPublisher.Target.unmanaged
    | .managed => do
        let purpose ← selectedPurpose? state
        some (Loam.ActualRoutingPublisher.Target.managed purpose)
  return {
    locus := row.locus
    effectiveOn := .dated state.snapshot.observedAt
    target := target
  }


def update (state : State) (key : Key) : Step :=
  match key with
  | .input 'q' | .input 'Q' => { state := state, cancel := true }
  | _ =>
      match state.phase with
      | .selectLocus =>
          match key with
          | .up | .input 'k' | .input 'K' =>
              let next := if state.locusIndex == 0 then 0 else state.locusIndex - 1
              { state := { state with locusIndex := next, notice := "" } }
          | .down | .input 'j' | .input 'J' =>
              let next :=
                if state.locusIndex + 1 < state.snapshot.rows.length then state.locusIndex + 1
                else state.locusIndex
              { state := { state with locusIndex := next, notice := "" } }
          | .enter =>
              if state.snapshot.rows.isEmpty then
                { state := { state with notice := "No current Expense Locus is available for routing." } }
              else
                { state := { state with phase := .selectTarget, notice := "" } }
          | .escape | .input 'b' | .input 'B' => { state := state, cancel := true }
          | _ => { state := state }

      | .selectTarget =>
          match key with
          | .up | .down | .tab | .shiftTab
          | .input 'k' | .input 'K' | .input 'j' | .input 'J' =>
              let next :=
                match state.targetChoice with
                | .managed => TargetChoice.unmanaged
                | .unmanaged => TargetChoice.managed
              { state := { state with targetChoice := next, notice := "" } }
          | .enter =>
              match state.targetChoice with
              | .unmanaged => { state := { state with phase := .preview, notice := "" } }
              | .managed =>
                  if state.snapshot.purposes.isEmpty then
                    { state := { state with notice := "No retained Capacity Purpose is available." } }
                  else
                    { state := { state with phase := .selectPurpose, notice := "" } }
          | .escape | .input 'b' | .input 'B' =>
              { state := { state with phase := .selectLocus, notice := "" } }
          | _ => { state := state }

      | .selectPurpose =>
          match key with
          | .up | .input 'k' | .input 'K' =>
              let next := if state.purposeIndex == 0 then 0 else state.purposeIndex - 1
              { state := { state with purposeIndex := next, notice := "" } }
          | .down | .input 'j' | .input 'J' =>
              let next :=
                if state.purposeIndex + 1 < state.snapshot.purposes.length then state.purposeIndex + 1
                else state.purposeIndex
              { state := { state with purposeIndex := next, notice := "" } }
          | .enter =>
              if state.purposeIndex < state.snapshot.purposes.length then
                { state := { state with phase := .preview, notice := "" } }
              else
                { state := { state with notice := "Invalid Purpose selection." } }
          | .escape | .input 'b' | .input 'B' =>
              { state := { state with phase := .selectTarget, notice := "" } }
          | _ => { state := state }

      | .preview =>
          match key with
          | .enter =>
              match draft? state with
              | some draft => { state := state, publish := some draft }
              | none => { state := { state with notice := "Incomplete Actual routing draft." } }
          | .input 'e' | .input 'E' =>
              { state := { state with phase := .selectTarget, notice := "" } }
          | .escape | .input 'b' | .input 'B' =>
              match state.targetChoice with
              | .managed => { state := { state with phase := .selectPurpose, notice := "" } }
              | .unmanaged => { state := { state with phase := .selectTarget, notice := "" } }
          | _ => { state := state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := line ""

private def statusText : RoutingStatus → String
  | .managed purpose => "managed " ++ purpose.token
  | .unmanaged => "unmanaged"
  | .unrouted => "UNROUTED"

private def listWindow {α : Type} (items : List α) (selected maxVisible : Nat) : List (Nat × α) :=
  let total := items.length
  if total <= maxVisible then
    items.zipIdx.map fun (x, i) => (i, x)
  else
    let half := maxVisible / 2
    let start := if selected > half then min (selected - half) (total - maxVisible) else 0
    (items.drop start |>.take maxVisible).zipIdx.map fun (x, i) => (start + i, x)

private def rowWidget (selected : Bool) (row : Loam.ActualRoutingReview.Row) : Widget :=
  let marker := if selected then "▶  " else "   "
  let locus := padRight 28 row.locus.token
  let status := statusText row.status
  .row [span (marker ++ locus ++ status) (if selected then .selected else .normal)]


def view (bounds : Bounds) (state : State) : Widget :=
  let maxVisible := if bounds.height > 12 then bounds.height - 10 else 6
  match state.phase with
  | .selectLocus =>
      let visible := listWindow state.snapshot.rows state.locusIndex maxVisible
      let rows :=
        if state.snapshot.rows.isEmpty then [line "   No current Expense Locus is available."]
        else visible.map fun (idx, row) => rowWidget (idx == state.locusIndex) row
      .column <|
        [ line "Purpose Administration / Actual Routing"
        , muted "Capacity > Purpose Administration"
        , muted ("Observed: " ++ state.snapshot.observedAt)
        , blank
        , muted ("Expense Loci: " ++ toString state.snapshot.rows.length ++
            " | unrouted: " ++ toString (Loam.ActualRoutingReview.unroutedCount state.snapshot))
        , muted ("Unresolved AccountingRole: " ++ toString state.snapshot.unresolvedRoleLoci.length ++
            " | historical-only routes: " ++ toString state.snapshot.historicalOnlyRouteLoci.length)
        , blank
        , muted ("   " ++ padRight 28 "Locus" ++ "Current route")
        ] ++ rows ++
        [ blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "Enter edit selected route   ↑/↓ (j/k) select   Esc/b/q back"
        , muted "Only explicit AccountingRole=Expense Loci appear; no name/sign inference."
        ]

  | .selectTarget =>
      let locus := match selectedRow? state with | some row => row.locus.token | none => "none"
      let current := match selectedRow? state with | some row => statusText row.status | none => "none"
      let managed := state.targetChoice == .managed
      let unmanaged := state.targetChoice == .unmanaged
      .column
        [ line "Purpose Administration / Route Type"
        , muted "Capacity > Purpose Administration > Actual Routing"
        , blank
        , line ("Locus: " ++ locus)
        , line ("Current route: " ++ current)
        , blank
        , .row [span (if managed then "▶  [x] managed -> Purpose" else "   [ ] managed -> Purpose")
                    (if managed then .selected else .normal)]
        , .row [span (if unmanaged then "▶  [x] unmanaged" else "   [ ] unmanaged")
                    (if unmanaged then .selected else .normal)]
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ or Tab toggle   Enter continue   Esc/b back   q cancel"
        ]

  | .selectPurpose =>
      let visible := listWindow state.snapshot.purposes state.purposeIndex maxVisible
      let purposes :=
        if state.snapshot.purposes.isEmpty then [line "   No retained Capacity Purpose."]
        else visible.map fun (idx, purpose) =>
          let selected := idx == state.purposeIndex
          .row [span ((if selected then "▶  " else "   ") ++ purpose.token)
                    (if selected then .selected else .normal)]
      .column <|
        [ line "Purpose Administration / Select Purpose"
        , muted "Capacity > Purpose Administration > Actual Routing"
        , blank
        , line "Route selected Expense Locus to:"
        ] ++ purposes ++
        [ blank
        , muted "Purpose candidates come from retained Capacity evidence."
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ (j/k) select   Enter preview   Esc/b back   q cancel"
        ]

  | .preview =>
      let locus := match selectedRow? state with | some row => row.locus.token | none => "none"
      let target :=
        match state.targetChoice with
        | .unmanaged => "unmanaged"
        | .managed =>
            match selectedPurpose? state with
            | some purpose => "managed " ++ purpose.token
            | none => "managed (none selected)"
      .column
        [ line "Purpose Administration / Preview"
        , muted "Capacity > Purpose Administration > Actual Routing"
        , blank
        , line ("Locus:        " ++ locus)
        , line ("Effective On: " ++ state.snapshot.observedAt)
        , line ("Route Target: " ++ target)
        , blank
        , muted "This appends historical routing evidence; earlier assertions remain retained."
        , muted "A duplicate Locus/date coordinate is refused rather than silently overwritten."
        , muted "Purpose identity is stable; display-name/identity migration is not performed here."
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "Enter publish   e edit   Esc/b back   q cancel"
        ]

end Loam.Tui.ActualRoutingAdministration
