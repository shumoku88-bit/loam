namespace Observation167

set_option autoImplicit false

/-- Deliberately unpermitted proof source for the negative axiom-policy trial. -/
axiom unpermitted_fact :
    ((-100 : Int) = -100) ∧ ((100 : Int) = 100)

/-- Same statement as the trusted Challenge, but proved through an unpermitted axiom. -/
theorem vector_claim :
    ((-100 : Int) = -100) ∧ ((100 : Int) = 100) := by
  exact unpermitted_fact

end Observation167
