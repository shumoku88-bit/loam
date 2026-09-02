namespace Loam.Core

set_option autoImplicit false

/-!
# Purpose identity

Stable identity for one household purpose coordinate. Observation 106 and
Observation 111 qualify `PurposeId` as a shared coordinate across Capacity
authority and Historical Routing.

A Purpose is not a physical Locus or Account. No registry is introduced.
-/

/-- Stable identity for one household purpose coordinate. -/
structure PurposeId where
  token : String
deriving Repr, DecidableEq

end Loam.Core
