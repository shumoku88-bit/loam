import Std

namespace Loam

set_option autoImplicit false

/-!
# Fresh numbered token enumeration

This module owns only one representation-level mechanic used by practical
identity allocators: enumerate `prefix ++ Nat` candidates until a caller-supplied
collision predicate accepts one or fuel is exhausted.

It does not define an identity namespace, collision domain, global registry,
starting index, fuel policy, or typed identity wrapper. Those remain explicit at
each domain entrance.
-/

/-- Return the first numbered token not reserved by `used?`, within explicit fuel. -/
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
