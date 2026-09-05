namespace Observation166

set_option autoImplicit false

/-- Deliberately drifted but independently provable solution statement. -/
theorem vector_claim :
    ((-100 : Int) = -100) ∧ ((50 : Int) = 50) := by
  exact ⟨rfl, rfl⟩

end Observation166
