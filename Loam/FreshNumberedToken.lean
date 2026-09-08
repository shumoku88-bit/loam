import Std

namespace Loam

set_option autoImplicit false

/-!
Shares only deterministic `stem ++ Nat` candidate enumeration. Identity
namespace, collision policy, starting index, fuel, and typed wrapper stay local.
-/

def firstUnusedNumberedToken?
    (stem : String)
    (used? : String → Bool) : Nat → Nat → Option String
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate := stem ++ toString index
      if used? candidate then
        firstUnusedNumberedToken? stem used? (index + 1) fuel
      else
        some candidate

end Loam
