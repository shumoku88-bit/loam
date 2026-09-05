namespace Observation168

set_option autoImplicit false

/-- Proof candidate checked by both the Lean kernel and Nanoda. -/
theorem vector_claim :
    ((-100 : Int) = -100) ∧ ((100 : Int) = 100) := by
  exact ⟨rfl, rfl⟩

end Observation168
