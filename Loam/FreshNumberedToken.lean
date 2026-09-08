import Std

namespace Loam

set_option autoImplicit false

/-!
Shares only deterministic `prefix ++ Nat` candidate enumeration. Identity
namespace, collision policy, starting index, fuel, and typed wrapper stay local.
-/

def firstUnusedNumberedToken?
    (prefix : String)
    (used? : String → Bool) : Nat → Nat → Option String
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate := prefix ++ toString index
      if used? candidate then
        firstUnusedNumberedToken? prefix used? (index + 1) fuel
      else
        some candidate

end Loam
