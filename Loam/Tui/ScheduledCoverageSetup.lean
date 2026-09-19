import Loam.ScheduledCoverageConfig
import Loam.ScheduledReview
import Loam.Tui.Kernel
import Loam.Tui.Main
import Loam.Tui.Terminal

namespace Loam.Tui.ScheduledCoverageSetup

open Loam.Tui.Kernel

set_option autoImplicit false

abbrev Record := Loam.Tui.Main.ScheduledRecord

structure CadenceChoice where
  label : String
  months : Nat
  deriving Repr, DecidableEq

def choices : List CadenceChoice :=
  [ { label := "Monthly", months := 1 }
  , { label := "Every 2 months", months := 2 }
  , { label := "Every 3 months", months := 3 }
  , { label := "Every 6 months", months := 6 }
  , { label := "Yearly", months := 12 }
  ]

structure State where
  source : Record
  selection : Nat := 0
  notice : String := ""

inductive Action where
  | save (months : Nat)
  | cancel
  deriving Repr, DecidableEq

structure Step where
  state : State
  action : Option Action := none

def initial (source : Record) : State := { source := source }

def cadenceLabel (months : Nat) : String :=
  match choices.find? (fun choice => choice.months == months) with
  | some choice => choice.label
  | none => "Every " ++ toString months ++ " months"

private def signedLoci (record : Record) (positive : Bool) : List String :=
  ((record.movement.changes.filterMap fun change =>
      if positive then
        if change.quantity.quanta > 0 then some change.coordinate.token else none
      else
        if change.quantity.quanta < 0 then some change.coordinate.token else none).eraseDups)
    |>.mergeSort (fun left right => left <= right)

/--
Build one monitoring rule from an already explicit Scheduled occurrence.

The selected occurrence supplies the anchor and exact signed-Locus shape. The
human supplies only the expected month cadence. Amounts are deliberately absent
because coverage monitoring already ignores them.
-/
def ruleFor? (source : Record) (months : Nat) :
    Except String Loam.ScheduledCoverageConfig.Rule := do
  if months = 0 then
    throw "Monitoring cadence must be at least one month."
  let negativeLoci := signedLoci source false
  let positiveLoci := signedLoci source true
  if negativeLoci.isEmpty || positiveLoci.isEmpty then
    throw "The selected Scheduled occurrence has no usable signed-Locus shape."
  let name :=
    match positiveLoci with
    | [only] => only
    | _ => source.id.token
  return {
    name := name
    anchor := source.scheduledOn
    everyMonths := months
    negativeLoci := negativeLoci
    positiveLoci := positiveLoci
  }

private def moveSelection (state : State) (back : Bool) : State :=
  if choices.isEmpty then state
  else
    let next :=
      if back then
        if state.selection = 0 then choices.length - 1 else state.selection - 1
      else if state.selection + 1 >= choices.length then
        0
      else
        state.selection + 1
    { state with selection := next, notice := "" }

def update (state : State) (key : Loam.Tui.Terminal.Key) : Step :=
  match key with
  | .escape | .input 'q' | .input 'Q' =>
      { state, action := some .cancel }
  | .up | .input 'k' | .input 'K' | .shiftTab =>
      { state := moveSelection state true }
  | .down | .input 'j' | .input 'J' | .tab =>
      { state := moveSelection state false }
  | .enter =>
      match choices[state.selection]? with
      | some choice => { state, action := some (.save choice.months) }
      | none => { state := { state with notice := "No monitoring cadence is selected." } }
  | _ => { state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]

private def choiceLine (state : State) (index : Nat) : Option Widget := do
  let choice ← choices[index]?
  let prefix := if index = state.selection then "> " else "  "
  some <| .row
    [ span (prefix ++ choice.label)
        (if index = state.selection then .selected else .normal) ]

def view (state : State) : Widget :=
  .column <|
    [ line "Scheduled / Plan Monitoring"
    , line ("Selected: " ++ state.source.scheduledOn ++ "  " ++
        Loam.ScheduledReview.summary state.source)
    , muted "Choose how often you normally expect an explicit plan."
    , muted "This only monitors coverage. It does not create plans or claim recurrence."
    , line ""
    ] ++
    (List.range choices.length).filterMap (choiceLine state) ++
    [ line ""
    , muted "Enter save monitoring   j/k or arrows choose   q/Esc cancel"
    ] ++
    (if state.notice.isEmpty then [] else [line state.notice])

end Loam.Tui.ScheduledCoverageSetup
