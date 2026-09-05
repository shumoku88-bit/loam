namespace Observation165

set_option autoImplicit false

/-- Untrusted-side proof candidate for the reviewed Observation 165 statement. -/
theorem vector_claim :
    ((-100 : Int) = -100) ∧ ((100 : Int) = 100) := by
  exact ⟨rfl, rfl⟩

end Observation165
