import Loam.Application.ScheduledCommitmentInspection
import Loam.Core
import Loam.Core.ScheduledRouting
import Loam.CurrentCoverageReview
import Loam.ScheduledRoutingPublisher
import Loam.Tui.Kernel
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledRouting

open Loam.Core
open Loam.Application
open Loam.Tui.Kernel
open Loam.Tui.Terminal

set_option autoImplicit false

/-!
# Interactive Scheduled routing workspace

This surface allows the user to inspect unresolved Scheduled pressure rows
(`ScheduledId × LocusId`) and preview/publish an explicit routing assertion
(`managed -> Purpose` or `unmanaged`).

Presentation-only state: no IO, no persistence, and no new Core primitives.
The effective date is strictly fixed to the current observation date (`observedAt`),
never the occurrence's `scheduledOn` date and never hardcoded.
-/

inductive TargetChoice where
  | managed
  | unmanaged
  deriving Repr, DecidableEq

inductive Phase where
  | selectSubject
  | selectTarget
  | selectPurpose
  | preview
  deriving Repr, DecidableEq

structure State where
  coverage : Loam.CurrentCoverageReview.Snapshot
  effectiveOn : String
  phase : Phase := .selectSubject
  subjectIndex : Nat := 0
  targetChoice : TargetChoice := .managed
  purposeIndex : Nat := 0
  notice : String := ""
  deriving Repr

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.ScheduledRoutingPublisher.Draft := none
  deriving Repr

def initial (coverage : Loam.CurrentCoverageReview.Snapshot) (effectiveOn : String) : State :=
  { coverage := coverage, effectiveOn := effectiveOn }

def unresolvedRows (state : State) : List (UnresolvedScheduledPressureRow String) :=
  state.coverage.unresolvedScheduled

def availablePurposes (state : State) : List PurposeId :=
  state.coverage.rows.map (fun row => row.purpose) |>.eraseDups

def selectedRow? (state : State) : Option (UnresolvedScheduledPressureRow String) :=
  (unresolvedRows state)[state.subjectIndex]?

def selectedPurpose? (state : State) : Option PurposeId :=
  (availablePurposes state)[state.purposeIndex]?

def draft? (state : State) : Option Loam.ScheduledRoutingPublisher.Draft := do
  let row ← selectedRow? state
  let target ←
    match state.targetChoice with
    | .unmanaged => some Loam.ScheduledRoutingPublisher.Target.unmanaged
    | .managed => do
        let purpose ← selectedPurpose? state
        some (Loam.ScheduledRoutingPublisher.Target.managed purpose)
  return {
    subject := row.subject
    effectiveOn := state.effectiveOn
    target := target
  }

def update (bounds : Bounds) (state : State) (key : Key) : Step :=
  let _ := bounds
  match key with
  | .input 'q' | .input 'Q' =>
      { state := state, cancel := true }
  | _ =>
      match state.phase with
      | .selectSubject =>
          let rows := unresolvedRows state
          match key with
          | .up | .input 'k' | .input 'K' =>
              let next := if state.subjectIndex == 0 then 0 else state.subjectIndex - 1
              { state := { state with subjectIndex := next, notice := "" } }
          | .down | .input 'j' | .input 'J' =>
              let next := if state.subjectIndex + 1 < rows.length then state.subjectIndex + 1 else state.subjectIndex
              { state := { state with subjectIndex := next, notice := "" } }
          | .enter =>
              if rows.isEmpty then
                { state := { state with notice := "No unresolved Scheduled routing subjects." } }
              else
                { state := { state with phase := .selectTarget, notice := "" } }
          | .escape | .input 'b' | .input 'B' =>
              { state := state, cancel := true }
          | _ => { state := state }

      | .selectTarget =>
          match key with
          | .up | .down | .input 'k' | .input 'j' | .input 'K' | .input 'J' | .tab | .shiftTab =>
              let nextChoice :=
                match state.targetChoice with
                | .managed => TargetChoice.unmanaged
                | .unmanaged => TargetChoice.managed
              { state := { state with targetChoice := nextChoice, notice := "" } }
          | .enter =>
              match state.targetChoice with
              | .unmanaged =>
                  { state := { state with phase := .preview, notice := "" } }
              | .managed =>
                  let purposes := availablePurposes state
                  if purposes.isEmpty then
                    { state := { state with notice := "No managed Purpose available in coverage." } }
                  else
                    { state := { state with phase := .selectPurpose, notice := "" } }
          | .escape | .input 'b' | .input 'B' =>
              { state := { state with phase := .selectSubject, notice := "" } }
          | _ => { state := state }

      | .selectPurpose =>
          let purposes := availablePurposes state
          match key with
          | .up | .input 'k' | .input 'K' =>
              let next := if state.purposeIndex == 0 then 0 else state.purposeIndex - 1
              { state := { state with purposeIndex := next, notice := "" } }
          | .down | .input 'j' | .input 'J' =>
              let next := if state.purposeIndex + 1 < purposes.length then state.purposeIndex + 1 else state.purposeIndex
              { state := { state with purposeIndex := next, notice := "" } }
          | .enter =>
              if state.purposeIndex < purposes.length then
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
              | none => { state := { state with notice := "Incomplete routing draft." } }
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

private def padded (width : Nat) (text : String) : String :=
  if text.length >= width then text
  else text ++ String.ofList (List.replicate (width - text.length) ' ')

private def paddedLeft (width : Nat) (text : String) : String :=
  if text.length >= width then text
  else String.ofList (List.replicate (width - text.length) ' ') ++ text

private def listWindow {α : Type} (items : List α) (selected : Nat) (maxVisible : Nat) : List (Nat × α) :=
  let total := items.length
  if total <= maxVisible then
    items.zipIdx.map fun (x, i) => (i, x)
  else
    let half := maxVisible / 2
    let start := if selected > half then min (selected - half) (total - maxVisible) else 0
    (items.drop start |>.take maxVisible).zipIdx.map fun (x, i) => (start + i, x)

private def subjectHeaderLine : Widget :=
  muted ("   " ++ padded 18 "ScheduledId" ++ padded 14 "Date" ++ padded 18 "Locus" ++ "Quantity")

private def subjectRowWidget
    (selected : Bool) (row : UnresolvedScheduledPressureRow String) : Widget :=
  let marker := if selected then "▶  " else "   "
  let content :=
    padded 18 row.subject.scheduled.token ++
    padded 14 row.scheduledOn ++
    padded 18 row.subject.locus.token ++
    paddedLeft 10 (toString row.quantity.quanta) ++ " " ++ row.measure.token
  .row [span (marker ++ content) (if selected then .selected else .normal)]

def view (bounds : Bounds) (state : State) : Widget :=
  let maxVisible := if bounds.height > 12 then bounds.height - 10 else 6
  match state.phase with
  | .selectSubject =>
      let rows := unresolvedRows state
      let visible := listWindow rows state.subjectIndex maxVisible
      let listWidgets :=
        if rows.isEmpty then
          [line "   No unresolved Scheduled routing subjects."]
        else
          visible.map fun (idx, row) => subjectRowWidget (idx == state.subjectIndex) row
      .column <|
        [ line "Scheduled Routing / Select Subject"
        , muted "Cycle Budget > Scheduled Routing"
        , blank
        , line "Unresolved Scheduled pressure subjects (ScheduledId × LocusId):"
        , subjectHeaderLine
        ] ++ listWidgets ++
        [ blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ (j/k) select   Enter select route type   Esc/b/q cancel"
        ]

  | .selectTarget =>
      let subjectDesc :=
        match selectedRow? state with
        | some row =>
            s!"Subject: {row.subject.scheduled.token} / {row.subject.locus.token} ({row.scheduledOn}, {row.quantity.quanta} {row.measure.token})"
        | none => "Subject: none"
      let managedSelected := state.targetChoice == .managed
      let unmanagedSelected := state.targetChoice == .unmanaged
      let managedWidget : Widget :=
        .row [span (if managedSelected then "▶  [x] " else "   [ ] ") (if managedSelected then .selected else .normal),
              span "managed: route future pressure to a specific Purpose" (if managedSelected then .selected else .normal)]
      let unmanagedWidget : Widget :=
        .row [span (if unmanagedSelected then "▶  [x] " else "   [ ] ") (if unmanagedSelected then .selected else .normal),
              span "unmanaged: resolve as non-managed future pressure" (if unmanagedSelected then .selected else .normal)]
      .column
        [ line "Scheduled Routing / Select Route Type"
        , muted "Cycle Budget > Scheduled Routing"
        , blank
        , line subjectDesc
        , blank
        , line "Select destination for this Scheduled commitment:"
        , managedWidget
        , unmanagedWidget
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ (j/k) or Tab toggle   Enter continue   Esc/b back   q cancel"
        ]

  | .selectPurpose =>
      let subjectDesc :=
        match selectedRow? state with
        | some row =>
            s!"Subject: {row.subject.scheduled.token} / {row.subject.locus.token} ({row.scheduledOn}, {row.quantity.quanta} {row.measure.token})"
        | none => "Subject: none"
      let purposes := availablePurposes state
      let visible := listWindow purposes state.purposeIndex maxVisible
      let purposeWidgets :=
        if purposes.isEmpty then
          [line "   No Purpose available in coverage."]
        else
          visible.map fun (idx, purpose) =>
            let sel := idx == state.purposeIndex
            let marker := if sel then "▶  " else "   "
            .row [span (marker ++ purpose.token) (if sel then .selected else .normal)]
      .column <|
        [ line "Scheduled Routing / Select Purpose"
        , muted "Cycle Budget > Scheduled Routing"
        , blank
        , line subjectDesc
        , blank
        , line "Select Purpose to manage this commitment:"
        ] ++ purposeWidgets ++
        [ blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "↑/↓ (j/k) select   Enter preview   Esc/b back   q cancel"
        ]

  | .preview =>
      let row := selectedRow? state
      let targetDesc :=
        match state.targetChoice with
        | .unmanaged => "unmanaged (non-managed pressure)"
        | .managed =>
            match selectedPurpose? state with
            | some p => s!"managed {p.token}"
            | none => "managed (none selected)"
      let details :=
        match row with
        | some r =>
            [ line s!"Scheduled Id:   {r.subject.scheduled.token}"
            , line s!"Locus:          {r.subject.locus.token}"
            , line s!"Scheduled On:   {r.scheduledOn}"
            , line s!"Amount:         {r.quantity.quanta} {r.measure.token}"
            , line s!"Effective On:   {state.effectiveOn}"
            , line s!"Route Target:   {targetDesc}"
            ]
        | none => [line "No subject selected."]
      .column <|
        [ line "Scheduled Routing / Preview"
        , muted "Cycle Budget > Scheduled Routing"
        , blank
        ] ++ details ++
        [ blank
        , muted "Publication appends this assertion to scheduled-routing.loam under writer ownership."
        , muted "Effective date is strictly the current observation date (observedAt)."
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "Enter publish   e edit   Esc/b back   q cancel"
        ]

end Loam.Tui.ScheduledRouting
