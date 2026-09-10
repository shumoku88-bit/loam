import Std

namespace Loam.Persistence

set_option autoImplicit false

/-!
# Token syntax for text-facing LOAM boundaries

This module owns only the representation rule shared by current persistence,
configuration, and human-input adapters when one opaque identity must fit in a
single unescaped text field.

It does not admit domain identity, assign household meaning, select authority,
or define persistence semantics. Callers remain responsible for every semantic
law beyond text representability.
-/

/-- Whether one opaque identity token fits in an unescaped single text field. -/
def validToken (token : String) : Bool :=
  !token.isEmpty &&
    !token.contains '\t' &&
    !token.contains '\n' &&
    !token.contains '\r'

end Loam.Persistence
