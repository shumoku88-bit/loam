import Loam.ActualDate
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

The default surface preserves the established Expense-routing administration
contract. A separate explicitly-entered `Other admitted loci` surface exposes
known non-Expense Loci without treating them as routing obligations. This makes
Asset/Income/Liability/Equity routing available for generic Purpose questions
such as savings or investment contribution while keeping default unrouted audits
Expense-scoped.

Publication still delegates to `ActualRoutingPublisher`. The user explicitly
chooses the routing effective coordinate; no route is silently backdated.
-/

inductive LocusScope where
  | expense
  | other
  deriving Repr, DecidableEq

inductive TargetChoice where
  | managed
  | unmanaged
  deriving Repr, DecidableEq

inductive Phase where
  | selectLocus
  | selectTarget
  | selectPurpose
  | editEffective (inputBuffer : String)
  | preview
  deriving Repr, DecidableEq

structure State where
  snapshot : Loam.ActualRoutingReview.Snapshot
  scope : LocusScope := .expense
  phase : Phase := .selectLocus
  locusIndex : Nat := 0
  targetChoice : TargetChoice := .managed
  purposeIndex : Nat := 0
  effectiveOn : RoutingEffective String
  notice : String := ""
  deriving Repr

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ActualRoutingPublisher.Draft := none
  deriving Repr

private def effectiveText : RoutingEffective String → String
  | .initial => "initial"
  | .dated date => date

private def roleText : AccountingRole → String
  | .asset => "Asset"
  | .liability => "Liability"
  | .equity => "Equity"
  | .income => "Income"
  | .expense => "Expense"


def initial (snapshot : Loam.ActualRoutingReview.Snapshot) : State :=
  { snapshot := snapshot
    effectiveOn := .dated snapshot.observedAt }


def activeRows (state : State) : List Loam.ActualRoutingReview.Row :=
  match state.scope with
  | .expense => state.snapshot.rows
  | .other => state.snapshot.otherRows


def selectedRow? (state : State) : Option Loam.ActualRoutingReview.Row :=
  (activeRows state)[state.locusIndex]?


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
    effectiveOn := state.effectiveOn
    target := target
  }

private def startEffectiveEdit (state : State) : Step :=
  { state := { state with phase := .editEffective "", notice := "" } }

private def backFromEffective (state : State) : Step :=
  match state.targetChoice with
  | .managed => { state := { state with phase := .selectPurpose, notice := "" } }
  | .unmanaged => { state := { state with phase := .selectTarget, notice := "" } }

private def toggleScope (state : State) : State :=
  let next :=
    match state.scope with
    | .expense => LocusScope.other
    | .other => LocusScope.expense
  { state with scope := next, locusIndex := 0, notice := "" }


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
              let rows := activeRows state
              let next :=
                if state.locusIndex + 1 < rows.length then state.locusIndex + 1
                else state.locusIndex
              { state := { state with locusIndex := next, notice := "" } }
          | .input 'a' | .input 'A' =>
              { state := toggleScope state }
          | .enter =>
              if (activeRows state).isEmpty then
                let label :=
                  match state.scope with
                  | .expense => "No current Expense Locus is available for routing."
                  | .other => "No admitted non-Expense Locus with a known AccountingRole is available."
                { state := { state with notice := label } }
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
              | .unmanaged => startEffectiveEdit state
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
                startEffectiveEdit state
              else
                { state := { state with notice := "Invalid Purpose selection." } }
          | .escape | .input 'b' | .input 'B' =>
              { state := { state with phase := .selectTarget, notice := "" } }
          | _ => { state := state }

      | .editEffective buffer =>
          match key with
          | .input 'i' | .input 'I' =>
              { state := { state with effectiveOn := .initial, phase := .preview, notice := "" } }
          | .input char =>
              if char.isDigit || char == '-' then
                { state := { state with phase := .editEffective (buffer.push char), notice := "" } }
              else
                { state := state }
          | .backspace =>
              let next := String.ofList buffer.toList.dropLast
              { state := { state with phase := .editEffective next, notice := "" } }
          | .enter =>
              let date := if buffer.isEmpty then state.snapshot.observedAt else buffer
              if Loam.ActualDate.validIsoDate date then
                { state := { state with effectiveOn := .dated date, phase := .preview, notice := "" } }
              else
                { state := { state with notice := "Effective date must be a real YYYY-MM-DD date, or press i for initial." } }
          | .escape | .input 'b' | .input 'B' => backFromEffective state
          | _ => { state := state }

      | .preview =>
          match key with
          | .enter =>
              match draft? state with
              | some draft => { state := state, publish := some draft }
              | none => { state := { state with notice := "Incomplete Actual routing draft." } }
          | .input 'd' | .input 'D' =>
              { state := { state with phase := .editEffective "", notice := "" } }
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

private def rowWidget (selected : Bool) (row : Loam.ActualRoutingReview.Row) : Widget :=
  let marker := if selected then "▶  " else "   "
  let locus := padRight 24 row.locus.token
  let role := padRight 12 (roleText row.role)
  let status := statusText row.status
  .row [span (marker ++ locus ++ role ++ status) (if selected then .selected else .normal)]


def view (bounds : Bounds) (state : State) : Widget :=
  let maxVisible := if bounds.height > 12 then bounds.height - 10 else 6
  match state.phase with
  | .selectLocus =>
      let active := activeRows state
      let visible := centeredListWindow active state.locusIndex maxVisible
      let rows :=
        if active.isEmpty then
          match state.scope with
          | .expense => [line "   No current Expense Locus is available."]
          | .other => [line "   No admitted known-role non-Expense Locus is available."]
        else visible.map fun (idx, row) => rowWidget (idx == state.locusIndex) row
      let scopeSummary :=
        match state.scope with
        | .expense =>
            "Expense Loci: " ++ toString state.snapshot.rows.length ++
              " | unrouted: " ++ toString (Loam.ActualRoutingReview.unroutedCount state.snapshot)
        | .other =>
            "Other admitted loci: " ++ toString state.snapshot.otherRows.length ++
              " | optional routing only"
      let toggleHelp :=
        match state.scope with
        | .expense => "a show other admitted loci"
        | .other => "a return to Expense loci"
      .column <|
        [ line "Purpose Administration / Actual Routing"
        , muted "Capacity > Purpose Administration"
        , muted ("Observed: " ++ state.snapshot.observedAt)
        , blank
        , muted scopeSummary
        , muted ("Unresolved AccountingRole: " ++ toString state.snapshot.unresolvedRoleLoci.length ++
            " | historical-only routes: " ++ toString state.snapshot.historicalOnlyRouteLoci.length)
        , blank
        , muted ("   " ++ padRight 24 "Locus" ++ padRight 12 "Role" ++ "Current route")
        ] ++ rows ++
        [ blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted ("Enter edit selected route   ↑/↓ (j/k) select   " ++ toggleHelp)
        , muted "Esc/b/q back   Other admitted loci are optional; UNROUTED there is not a warning."
        ]

  | .selectTarget =>
      let locus := match selectedRow? state with | some row => row.locus.token | none => "none"
      let role := match selectedRow? state with | some row => roleText row.role | none => "none"
      let current := match selectedRow? state with | some row => statusText row.status | none => "none"
      let managed := state.targetChoice == .managed
      let unmanaged := state.targetChoice == .unmanaged
      .column
        [ line "Purpose Administration / Route Type"
        , muted "Capacity > Purpose Administration > Actual Routing"
        , blank
        , line ("Locus: " ++ locus ++ " [" ++ role ++ "]")
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
      let visible := centeredListWindow state.snapshot.purposes state.purposeIndex maxVisible
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
        , line "Route selected Locus to:"
        ] ++ purposes ++
        [ blank
        , muted "Purpose candidates come from retained Capacity evidence."
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ (j/k) select   Enter continue   Esc/b back   q cancel"
        ]

  | .editEffective buffer =>
      let shown := if buffer.isEmpty then "(blank = observed date)" else buffer
      .column
        [ line "Purpose Administration / Effective Coordinate"
        , muted "Capacity > Purpose Administration > Actual Routing"
        , blank
        , line ("Observed date: " ++ state.snapshot.observedAt)
        , line ("Effective from: " ++ shown)
        , blank
        , muted "Type YYYY-MM-DD and press Enter, or press Enter blank to use observed date."
        , muted "Press i for initial only when the routing policy truly applies from the retained origin."
        , muted "No historical route is inferred from today's choice."
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "digits/- edit   Backspace delete   i initial   Enter continue   Esc/b back   q cancel"
        ]

  | .preview =>
      let locus := match selectedRow? state with | some row => row.locus.token | none => "none"
      let role := match selectedRow? state with | some row => roleText row.role | none => "none"
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
        , line ("Locus:        " ++ locus ++ " [" ++ role ++ "]")
        , line ("Effective On: " ++ effectiveText state.effectiveOn)
        , line ("Route Target: " ++ target)
        , blank
        , muted "This appends historical routing evidence; earlier assertions remain retained."
        , muted "A duplicate Locus/effective coordinate is refused rather than silently overwritten."
        , muted "Purpose identity is stable; no account-name, sign, or AccountingRole inference is performed."
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "Enter publish   d edit date   e edit target   Esc/b back   q cancel"
        ]

end Loam.Tui.ActualRoutingAdministration
