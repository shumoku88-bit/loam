import Loam.ConditionalBalancePathReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def yen : MeasureId := ⟨"jpy"⟩
private def bank : LocusId := ⟨"bank"⟩
private def wallet : LocusId := ⟨"wallet"⟩
private def rent : LocusId := ⟨"rent"⟩
private def external : LocusId := ⟨"external"⟩
private def investment : LocusId := ⟨"investment"⟩

private def coordinate (locus : LocusId) : EffectCoordinate := ⟨locus, yen⟩

private def change (locus : LocusId) (quanta : Int) : MovementChange LocusId :=
  { coordinate := locus, quantity := Quantity.ofQuanta quanta }

private def scheduled?
    (id day : String) (changes : List (MovementChange LocusId)) :
    Option (ScheduledOccurrence String) := do
  let movement ← BalancedMovement.ofChanges? yen changes
  pure { id := ⟨id⟩, scheduledOn := day, movement := movement }

private def evidence
    (occurrences : List (ScheduledOccurrence String)) : IO Loam.ScheduledReview.EvidenceSnapshot := do
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? occurrences)
    "Scheduled memory fixture was not admitted"
  let completions ← requireSome (ScheduledCompletionMemory.ofCompletions? [])
    "completion memory fixture was not admitted"
  let retirements ← requireSome (ScheduledRetirementMemory.ofRetirements? [])
    "retirement memory fixture was not admitted"
  let replacements ← requireSome (ScheduledReplacementMemory.ofReplacements? [])
    "replacement memory fixture was not admitted"
  let events ← requireSome (EventMemory.ofEvents? [])
    "Event memory fixture was not admitted"
  pure { scheduled, completions, retirements, replacements, events }

private def balances : Loam.BalanceReview.Snapshot := {
  rows :=
    [ { coordinate := coordinate bank, quantity := Quantity.ofQuanta 7 }
    , { coordinate := coordinate wallet, quantity := Quantity.ofQuanta 3 }
    ]
}


def main : IO Unit := do
  let payment ← requireSome
    (scheduled? "payment" "2026-09-10" [change bank (-3), change rent 3])
    "payment fixture was not admitted"
  let funding ← requireSome
    (scheduled? "funding" "2026-09-10" [change external (-4), change bank 4])
    "funding fixture was not admitted"
  let transfer ← requireSome
    (scheduled? "transfer" "2026-09-11" [change bank (-2), change wallet 2])
    "transfer fixture was not admitted"
  let invest ← requireSome
    (scheduled? "invest" "2026-09-12" [change bank (-5), change investment 5])
    "investment fixture was not admitted"
  let later ← requireSome
    (scheduled? "later" "2026-09-20" [change bank (-99), change rent 99])
    "later fixture was not admitted"
  let scheduled ← evidence [later, transfer, payment, invest, funding]

  match Loam.ConditionalBalancePathReview.project
      balances scheduled "2026-09-08" "2026-09-12" with
  | .error message => throw (IO.userError message)
  | .ok snapshot =>
      expect (snapshot.currentSelected.quanta == 10)
        "conditional path did not start from the shared current selected balance"
      expect (snapshot.assumedCompleteThrough == "2026-09-12")
        "conditional path lost the explicit assumption horizon"
      expect (snapshot.finalAtHorizon.quanta == 6)
        "conditional path final balance was wrong"
      expect (snapshot.lowWater.quanta == 6)
        "conditional day-boundary low-water was wrong"
      match snapshot.points with
      | [day10, day12] =>
          expect (day10.date == "2026-09-10")
            "conditional path was not sorted chronologically"
          expect (day10.scheduledChange.quanta == 1 && day10.balance.quanta == 11)
            "same-day Scheduled effects were not netted at the day boundary"
          expect (day12.date == "2026-09-12")
            "conditional path retained a neutral transfer day or lost the investment day"
          expect (day12.scheduledChange.quanta == -5 && day12.balance.quanta == 6)
            "conditional path second change point was wrong"
      | _ =>
          throw (IO.userError "conditional path emitted the wrong change-point shape")

  let overdue ← requireSome
    (scheduled? "overdue" "2026-09-07" [change bank (-2), change rent 2])
    "overdue fixture was not admitted"
  let withOverdue ← evidence [payment, overdue]
  match Loam.ConditionalBalancePathReview.project
      balances withOverdue "2026-09-08" "2026-09-12" with
  | .error message =>
      expect ((message.splitOn "overdue").length > 1)
        "overdue refusal lost its timing explanation"
  | .ok _ =>
      throw (IO.userError "overdue selected Scheduled effect was silently re-dated")

  match Loam.ConditionalBalancePathReview.project
      balances scheduled "2026-09-08" "2026-09-07" with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError "past conditional completeness horizon was accepted")

  let empty ← evidence []
  match Loam.ConditionalBalancePathReview.project
      balances empty "2026-09-08" "2026-09-12" with
  | .error message => throw (IO.userError message)
  | .ok snapshot =>
      expect (snapshot.points.isEmpty)
        "empty Scheduled evidence invented a conditional change point"
      expect (snapshot.finalAtHorizon.quanta == 10 && snapshot.lowWater.quanta == 10)
        "empty conditional path did not preserve the current selected balance"

  IO.println
    "Conditional selected-balance path: daily netting, chronological prefix, low-water and overdue refusal passed."
