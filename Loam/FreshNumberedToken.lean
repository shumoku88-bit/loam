import Std

namespace Loam

set_option autoImplicit false

/-!
Shares only deterministic `stem ++ Nat` candidate enumeration. Identity
namespace, collision policy, starting index, and typed wrapper stay local.
-/

/--
Return the first numbered token absent from one finite represented namespace.

On collision the selected token is erased before trying the next number, so the
represented namespace strictly shrinks on every recursive call. The operation is
therefore total without a caller-supplied fuel budget or an unreachable `none`.
-/
def firstUnusedNumberedToken
    (stem : String) (used : List String) (index : Nat) : String :=
  let candidate := stem ++ toString index
  if h : candidate ∈ used then
    firstUnusedNumberedToken stem (used.erase candidate) (index + 1)
  else
    candidate
termination_by used.length
decreasing_by
  rw [List.length_erase_of_mem h]
  exact Nat.sub_lt (List.length_pos_of_mem h) (by decide)

end Loam
