import Std

namespace Loam.ScheduledCompletionUi

set_option autoImplicit false

/-- Inputs that can still be required before one Scheduled completion draft may be activated. -/
inductive Obligation where
  | actualDate
  | actualMovement
  deriving DecidableEq, Repr

/--
The completion affordance changes wording once a retained completion relation
shows that publication had already started. This is UI state only, not a
canonical lifecycle enum.
-/
inductive Action where
  | complete
  | resumeCompletion
  deriving DecidableEq, Repr

/--
Small read-only progress surface for one Scheduled completion interaction.

`actualDate` may be absent, newly entered for this draft, or observed from
retained publication evidence. `dateRetained` records only that provenance for
the UI; it is not a household status fact. `movementTotal` likewise exists only
while the current human-entered draft is in memory.
-/
structure Progress where
  completionRetained : Bool := false
  actualDate : Option String := none
  dateRetained : Bool := false
  movementTotal : Option Int := none
  deriving Repr

/-- Choose the human-facing completion action without inventing a stored status. -/
def action (progress : Progress) : Action :=
  if progress.completionRetained then .resumeCompletion else .complete

/-- Human-facing action wording for the current observed evidence. -/
def actionLabel : Action → String
  | .complete => "Complete"
  | .resumeCompletion => "Resume completion"

/-- Remaining draft inputs implied by the current preflight/draft state. -/
def obligations (progress : Progress) : List Obligation :=
  let dateNeed :=
    match progress.actualDate with
    | none => [Obligation.actualDate]
    | some _ => []
  let movementNeed :=
    match progress.movementTotal with
    | none => [Obligation.actualMovement]
    | some _ => []
  dateNeed ++ movementNeed

/-- Human-facing wording for the tiny Scheduled-completion obligation surface. -/
def obligationLabel : Obligation → String
  | .actualDate => "Actual date"
  | .actualMovement => "Actual movement"

example :
    action ({ } : Progress) = .complete := by native_decide

example :
    obligations ({ } : Progress) = [.actualDate, .actualMovement] := by native_decide

example :
    action ({ completionRetained := true } : Progress) = .resumeCompletion := by
  native_decide

example :
    obligations ({ completionRetained := true } : Progress) =
      [.actualDate, .actualMovement] := by native_decide

example :
    obligations
        ({ completionRetained := true,
           actualDate := some "2026-09-21",
           dateRetained := true } : Progress) =
      [.actualMovement] := by native_decide

example :
    obligations
        ({ completionRetained := true,
           actualDate := some "2026-09-21",
           dateRetained := true,
           movementTotal := some 2800 } : Progress) = [] := by native_decide

end Loam.ScheduledCompletionUi
