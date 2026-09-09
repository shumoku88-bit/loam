import Loam.CapacityPublisher
import Loam.CapacityReview
import Loam.CurrentCoverageReview
import Loam.ActualReview
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal
import Lean.Elab.Tactic.Omega

namespace Loam.Tui.CapacityRebalance

open Loam.Core Loam.Tui.Kernel Loam.Tui.Layout Loam.Tui.Terminal

set_option autoImplicit false

/-!
# Capacity Rebalance workspace

This is presentation-only state for multi-coordinate Capacity rebalancing.
It operates over the shared `CapacityReview.Snapshot` (and optional
`CurrentCoverageReview.Snapshot`), allowing the user to propose signed JPY
deltas across remembered purposes.

No new Core concept or domain primitive is created; publication delegates
to the shared `CapacityPublisher.publishBalanced` atomic entrance.
-/

inductive Mode where
  | selecting
  | editingDelta (inputBuffer : String)
  | preview (draft : Loam.CapacityPublisher.BalancedDraft) (choice : Fin 3)
  deriving Repr, DecidableEq

structure State where
  snapshot : Loam.CapacityReview.Snapshot
  coverage : Option Loam.CurrentCoverageReview.Snapshot := none
  effectiveOn : String
  proposal : Loam.CapacityPublisher.Proposal := Loam.CapacityPublisher.Proposal.empty
  selected : Option (Fin snapshot.rows.length)
  mode : Mode := .selecting
  notice : String := ""

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.CapacityPublisher.BalancedDraft := none

private def stay (s : State) : Step := { state := s }
private def cancelStep (s : State) : Step := { state := s, cancel := true }
private def publishStep (s : State) (draft : Loam.CapacityPublisher.BalancedDraft) : Step :=
  { state := s, publish := some draft }

def initial
    (snapshot : Loam.CapacityReview.Snapshot)
    (coverage : Option Loam.CurrentCoverageReview.Snapshot)
    (effectiveOn : String)
    (initialPurpose? : Option PurposeId := none) : State :=
  let selected : Option (Fin snapshot.rows.length) :=
    match initialPurpose? with
    | some p =>
        match snapshot.rows.findIdx? (fun r => r.purpose = p) with
        | some idx => if h : idx < snapshot.rows.length then some ⟨idx, h⟩ else none
        | none => if h : 0 < snapshot.rows.length then some ⟨0, h⟩ else none
    | none =>
        if h : 0 < snapshot.rows.length then some ⟨0, h⟩ else none
  { snapshot := snapshot
  , coverage := coverage
  , effectiveOn := effectiveOn
  , selected := selected }

def selectedPurpose? (state : State) : Option PurposeId := do
  let index ← state.selected
  let row ← state.snapshot.rows[index.val]?
  pure row.purpose

def movePrevious (state : State) : State :=
  match state.selected with
  | none => state
  | some index =>
      if h : index.val = 0 then state
      else { state with selected := some ⟨index.val - 1, by omega⟩, notice := "" }

def moveNext (state : State) : State :=
  match state.selected with
  | none => state
  | some index =>
      if h : index.val + 1 < state.snapshot.rows.length then
        { state with selected := some ⟨index.val + 1, h⟩, notice := "" }
      else state

def update (state : State) (key : Key) : Step :=
  match state.mode with
  | .selecting =>
      match key with
      | .up | .input 'k' | .input 'K' => stay (movePrevious state)
      | .down | .input 'j' | .input 'J' => stay (moveNext state)
      | .input 'e' | .input 'E' =>
          match selectedPurpose? state with
          | none => stay { state with notice := "No Purpose selected to edit." }
          | some p =>
              let cur := state.proposal.delta p
              let buf := if cur == 0 then "" else toString cur
              stay { state with mode := .editingDelta buf, notice := "" }
      | .input '0' =>
          match selectedPurpose? state with
          | none => stay state
          | some p =>
              let p' := state.proposal.clearPurpose p
              stay { state with proposal := p', notice := s!"Cleared delta for {p.token}." }
      | .input 'c' | .input 'C' =>
          stay { state with proposal := state.proposal.clear, notice := "Cleared proposal." }
      | .enter =>
          if !state.proposal.hasChanges then
            stay { state with notice := "No changes proposed in rebalance." }
          else if !state.proposal.isBalanced then
            stay { state with notice := s!"Proposal is unbalanced ({state.proposal.balance} JPY). ΣΔ must be 0." }
          else
            let currentEnts := state.snapshot.rows.map (fun r => (r.purpose, r.entitlement.quanta))
            let negs := state.proposal.negativePurposes currentEnts
            if !negs.isEmpty then
              let negDesc := String.intercalate ", " (negs.map (fun (purp, amt) => s!"{purp.token}: {amt}"))
              stay { state with notice := s!"Negative proposed entitlement: {negDesc}." }
            else
              match state.proposal.toBalancedDraft state.effectiveOn with
              | .error msg => stay { state with notice := msg }
              | .ok draft => stay { state with mode := .preview draft ⟨0, by decide⟩, notice := "" }
      | .input 'q' | .input 'Q' | .escape => cancelStep state
      | _ => stay state

  | .editingDelta buf =>
      match key with
      | .input char =>
          if char.isDigit || char == '-' || char == '+' then
            stay { state with mode := .editingDelta (buf.push char), notice := "" }
          else if char == 'q' && buf.isEmpty then
            stay { state with mode := .selecting, notice := "Edit cancelled." }
          else
            stay state
      | .backspace =>
          let buf' := String.ofList buf.toList.dropLast
          stay { state with mode := .editingDelta buf', notice := "" }
      | .escape =>
          stay { state with mode := .selecting, notice := "Edit cancelled." }
      | .enter =>
          match selectedPurpose? state with
          | none => stay { state with mode := .selecting }
          | some p =>
              if buf.isEmpty then
                let p' := state.proposal.set p 0
                stay { state with proposal := p', mode := .selecting, notice := "" }
              else
                match buf.toInt? with
                | some val =>
                    let p' := state.proposal.set p val
                    stay { state with proposal := p', mode := .selecting, notice := "" }
                | none =>
                    stay { state with notice := s!"Invalid integer: {buf}" }
      | _ => stay state

  | .preview draft choice =>
      match key with
      | .left | .input 'h' | .input 'H' =>
          let newChoice : Fin 3 :=
            if choice.val = 0 then ⟨2, by decide⟩
            else if choice.val = 1 then ⟨0, by decide⟩
            else ⟨1, by decide⟩
          stay { state with mode := .preview draft newChoice }
      | .right | .input 'l' | .input 'L' | .tab =>
          let newChoice : Fin 3 :=
            if choice.val = 0 then ⟨1, by decide⟩
            else if choice.val = 1 then ⟨2, by decide⟩
            else ⟨0, by decide⟩
          stay { state with mode := .preview draft newChoice }
      | .enter =>
          if choice.val = 0 then publishStep state draft
          else if choice.val = 1 then stay { state with mode := .selecting }
          else cancelStep state
      | .escape | .input 'q' | .input 'Q' =>
          stay { state with mode := .selecting }
      | _ => stay state

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := .row []

def windowSize : Nat := 12

def windowStart (state : State) : Nat :=
  match state.selected with
  | none => 0
  | some index =>
      if index.val < windowSize then 0
      else index.val + 1 - windowSize

def visibleRows (state : State) : List (Nat × Loam.CapacityReview.Row) :=
  let start := windowStart state
  (List.range windowSize).filterMap fun offset =>
    let index := start + offset
    match state.snapshot.rows[index]? with
    | none => none
    | some row => some (index, row)

private def coverageRow?
    (state : State) (purpose : PurposeId) : Option Loam.CurrentCoverageReview.Row := do
  let coverage ← state.coverage
  coverage.rows.find? fun row => row.purpose == purpose

private def tableHeader : Widget :=
  let marker := "  "
  let purpose := padRight 18 "Purpose"
  let cap := padLeft 9 "Cap"
  let now := padLeft 9 "Now"
  let afterKnown := padLeft 13 "After-known"
  let delta := padLeft 9 "Δ"
  let proposed := padLeft 10 "Proposed"
  .row [span (marker ++ purpose ++ cap ++ now ++ afterKnown ++ delta ++ proposed) .muted]

private def rowLine
    (state : State) (index : Nat) (row : Loam.CapacityReview.Row) : Widget :=
  let isSelected :=
    match state.selected with
    | none => false
    | some current => current.val == index
  let marker := if isSelected then "▶ " else "  "
  let purpose := padRight 18 (Loam.ActualReview.shortText 18 row.purpose.token)
  let cap := padLeft 9 (toString row.entitlement.quanta)
  let (now, afterKnown) :=
    match coverageRow? state row.purpose with
    | some cov => (padLeft 9 (toString cov.remaining.quanta), padLeft 13 (toString cov.headroom.quanta))
    | none => (padLeft 9 "-", padLeft 13 "-")
  let (deltaStr, isEditingThis) :=
    match state.mode with
    | .editingDelta buf =>
        if isSelected then
          (padLeft 9 ("[" ++ buf ++ "_]"), true)
        else
          let d := state.proposal.delta row.purpose
          (padLeft 9 (if d > 0 then "+" ++ toString d else toString d), false)
    | _ =>
        let d := state.proposal.delta row.purpose
        (padLeft 9 (if d > 0 then "+" ++ toString d else toString d), false)
  let propEnt := row.entitlement.quanta + state.proposal.delta row.purpose
  let proposedStr := padLeft 10 (toString propEnt)
  let text := marker ++ purpose ++ cap ++ now ++ afterKnown ++ deltaStr ++ proposedStr
  let style : Style :=
    if isEditingThis then .selectedUnderlined
    else if isSelected then .selected
    else .normal
  .row [span text style]

private def summaryLine (label text : String) : Widget :=
  .row [span (padRight 38 (label ++ ":")), span text]

def view (_bounds : Bounds) (state : State) : Widget :=
  match state.mode with
  | .preview draft choice =>
      .column <|
        [ line "Capacity / Rebalance / Preview"
        , muted ("Effective date: " ++ draft.effectiveOn)
        , blank
        , line "Proposed atomic Capacity movement:"
        ] ++
        (draft.changes.map fun change =>
          let cToken := match change.coordinate with
            | .unallocated => "unallocated"
            | .purpose p => p.token
          let q := change.quantity.quanta
          let qStr := if q > 0 then "+" ++ toString q else toString q
          line ("  " ++ padRight 20 cToken ++ qStr ++ " jpy")) ++
        [ blank
        , line "Publication re-reads current Capacity and effective evidence under ownership."
        , blank
        , .row ((["Publish", "Back to editing", "Cancel"].zipIdx).map fun (lbl, idx) =>
            span ("[" ++ lbl ++ "] ")
              (if choice.val = idx then .selected else .normal))
        , blank
        , muted "Left/Right/Tab select   Enter confirm   Esc/q back"
        , line state.notice
        ]
  | _ =>
      let bal := state.proposal.balance
      let balStr :=
        if bal == 0 then "0  ✓"
        else if bal > 0 then "+" ++ toString bal ++ " ✗ (unbalanced)"
        else toString bal ++ " ✗ (unbalanced)"

      let currentEnts := state.snapshot.rows.map (fun r => (r.purpose, r.entitlement.quanta))
      let negs := state.proposal.negativePurposes currentEnts
      let negStr :=
        if negs.isEmpty then "none ✓"
        else String.intercalate ", " (negs.map (fun (p, amt) => s!"{p.token} ({amt}) ✗"))

      let shortageStr :=
        match state.coverage with
        | none => "coverage unavailable"
        | some _ =>
            let shortages := state.snapshot.rows.filterMap fun r =>
              match coverageRow? state r.purpose with
              | none => none
              | some cov =>
                  let proposedHeadroom := cov.headroom.quanta + state.proposal.delta r.purpose
                  if proposedHeadroom < 0 then some (r.purpose, proposedHeadroom) else none
            if shortages.isEmpty then "none ✓"
            else String.intercalate ", " (shortages.map (fun (p, h) => s!"{p.token} ({h})"))

      let pressureStr :=
        match state.coverage with
        | none => "coverage unavailable"
        | some cov =>
            match cov.scheduledFrontier with
            | none => "none ✓"
            | some frontier =>
                let parts :=
                  (if frontier.unrouted.quanta > 0 then [s!"unrouted {frontier.unrouted.quanta} jpy"] else []) ++
                  (if frontier.unresolvedEligibility.quanta > 0 then [s!"unresolved {frontier.unresolvedEligibility.quanta} jpy"] else []) ++
                  (if frontier.unmanaged.quanta > 0 then [s!"unmanaged {frontier.unmanaged.quanta} jpy"] else [])
                if parts.isEmpty then "none ✓"
                else String.intercalate " | " parts

      let helpLine :=
        match state.mode with
        | .editingDelta _ =>
            "Editing Δ: digits/sign, Enter confirm, Esc cancel"
        | _ =>
            "j/k or arrows select   e edit signed Δ   0 clear selected Δ   c clear proposal   Enter preview/publish   q cancel/back"

      .column <|
        [ line "Capacity / Rebalance"
        , muted ("Effective: " ++ state.effectiveOn)
        , muted (toString state.snapshot.rows.length ++ " remembered purpose(s)")
        , blank
        , tableHeader
        ] ++
        ((visibleRows state).map fun row => rowLine state row.1 row.2) ++
        [ blank
        , summaryLine "Proposal balance" balStr
        , summaryLine "Negative proposed entitlement" negStr
        , summaryLine "Known future shortage after proposal" shortageStr
        , summaryLine "Unresolved future pressure" pressureStr
        , blank
        , muted helpLine
        , line state.notice
        ]

end Loam.Tui.CapacityRebalance