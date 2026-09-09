namespace Observation238

set_option autoImplicit false

/--
Counterexample Solution: this has the exact reviewed theorem name and statement,
but proves it without importing or evaluating LOAM production code at all.

If Comparator accepts this Solution, statement identity and kernel replay do not
by themselves establish production correspondence.
-/
theorem scheduled_absence_is_unknown : (0 : Nat) = 0 := by
  rfl

end Observation238
