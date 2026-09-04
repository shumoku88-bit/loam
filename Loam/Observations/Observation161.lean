import Loam.Observations.Observation161Contract

namespace Loam.Observation161

open Loam.Core
open Loam.Observation161Contract

set_option autoImplicit false

/-!
# Observation 161 — statement alignment contract

A successful proof only says that Lean accepted the proposition written next to
that proof. It does not by itself show that this proposition is the proposition
a reviewer intended to ask.

This observation inserts one deliberately small boundary: the expected
proposition is named in an independent contract module, while the proof-bearing
theorem must inhabit that contract proposition.
-/

/-- The proof-bearing theorem produced by the observation implementation. -/
theorem observed_balance : ExpectedClaim := by
  decide

/--
Mechanical statement alignment: if `observed_balance` is changed to prove an
incompatible proposition while `ExpectedClaim` is left unchanged, this line no
longer type-checks.
-/
theorem proof_inhabits_reviewed_contract : ExpectedClaim :=
  observed_balance

/--
The contract remains ordinary Lean data: the expected proposition can be
unfolded and independently checked at the use site rather than inferred from a
workflow-success token.
-/
theorem reviewed_contract_is_exact_zero_total :
    ExpectedClaim ↔ movementTotalQuanta presentation = 0 := by
  rfl

end Loam.Observation161
