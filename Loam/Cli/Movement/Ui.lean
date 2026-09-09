import Std

namespace Loam.MovementUi

set_option autoImplicit false

/--
The two household-facing obligations that must be discharged before one ordinary
movement draft can be submitted for admission.

This is intentionally Movement-specific. It is not a generic UI action or proof
framework, and it carries no accounting role beyond the current practical
movement entrance.
-/
inductive Obligation where
  | occurrenceDate
  | balancedMovement
  deriving DecidableEq, Repr

/--
Small read-only UI state for the practical movement entrance.

`Progress` is not canonical household data and is never persisted. It only lets
the interface expose which inputs have already been supplied and which
obligations remain before admission can even be attempted.
-/
structure Progress where
  validOn : Option String := none
  movementTotal : Option Int := none
  deriving Repr

/-- Remaining input obligations for the current draft state. -/
def obligations (progress : Progress) : List Obligation :=
  let dateNeed :=
    match progress.validOn with
    | none => [Obligation.occurrenceDate]
    | some _ => []
  let movementNeed :=
    match progress.movementTotal with
    | none => [Obligation.balancedMovement]
    | some _ => []
  dateNeed ++ movementNeed

/-- Human-facing wording for the tiny Movement-specific obligation surface. -/
def obligationLabel : Obligation → String
  | .occurrenceDate => "occurrence date"
  | .balancedMovement => "balanced FROM / TO movement"

example : obligations {} = [.occurrenceDate, .balancedMovement] := by native_decide
example : obligations { validOn := some "2026-09-03" } = [.balancedMovement] := by
  native_decide
example : obligations { validOn := some "2026-09-03", movementTotal := some 1000 } = [] := by
  native_decide

end Loam.MovementUi
