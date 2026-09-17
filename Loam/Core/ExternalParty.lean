namespace Loam.Core

set_option autoImplicit false

/-!
# External party identity

Observations 263–269 qualified one role-free external identity coordinate shared
across independently retained household semantics.

This module contains identity only. It does not introduce a Party registry,
display-name authority, role taxonomy, lifecycle, aliasing, or inference policy.
Those meanings belong to the specific relations or evidence families that
reference this coordinate.
-/

/--
Stable opaque identity for one external party.

The token is identity only. It is not a display name and carries no built-in
person, merchant, institution, account, debtor, creditor, payee, or other role
meaning.
-/
structure ExternalPartyId where
  token : String
deriving Repr, DecidableEq

end Loam.Core
