import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-!
# Open relation vocabulary

Observations 172–176 qualified the minimum semantic vocabulary needed to retain
one directional household open relation without introducing a general Party,
Fact, Revision, quantity-slice, or persistence framework.

This module contains raw semantic provenance only. In particular it deliberately
does not decide whether referenced Event / Effect identities are present,
whether a quantity is positive or bounded by its source Effect, whether a
revision is current or conflicting, or whether absence means known-none. Those
are later admission / projection questions.
-/

/--
Stable opaque identity for one external endpoint of an open relation.

The token is identity only. It is not a display name and carries no built-in
person, merchant, institution, account, debtor, creditor, or other role meaning.
-/
structure ExternalEndpointId where
  token : String
deriving Repr, DecidableEq

/--
The minimum endpoint space currently earned for household open relations.

`household` is the distinguished household endpoint. External identity remains
opaque; debtor / creditor role belongs to each relation unit rather than to the
endpoint itself.
-/
inductive RelationEndpoint where
  | household
  | external (id : ExternalEndpointId)
deriving Repr, DecidableEq

/--
Stable identity for one retained positive-relation candidate.

Relation identity is independent of source Effect, endpoint pair, and scalar
quantity. Distinct relation units may therefore have otherwise equal fields.
-/
structure RelationUnitId where
  token : String
deriving Repr, DecidableEq

/--
One raw directional open-relation candidate anchored to one observed Effect.

`sourceEvent` together with `sourceEffect` names the existing Effect-level
coordinate without introducing a generic `EffectRef` wrapper. `quantity` keeps
ordinary exact `Quantity`; positivity and the source-magnitude bound are not raw
construction laws and must be checked by semantic admission before this value is
used as a current positive relation.

The source Effect already carries its `MeasureId`, so this raw relation does not
duplicate measure identity. Direction is expressed once by debtor / creditor;
the quantity sign carries no relation-direction meaning here.
-/
structure RelationUnit where
  id : RelationUnitId
  sourceEvent : EventId
  sourceEffect : EffectKey
  debtor : RelationEndpoint
  creditor : RelationEndpoint
  quantity : Quantity
deriving Repr, DecidableEq

/-- Stable identity for one retained relation revision claim. -/
structure RelationRevisionId where
  token : String
deriving Repr, DecidableEq

/--
One append-only raw revision of a retained relation unit.

A present `replacement` offers another positive-relation candidate. `none`
records an explicit retraction outcome for the target; it is not silent deletion
and does not by itself mean that the source Effect is globally known to have no
open relation. Same-source replacement, reference closure, acyclicity, conflict
handling, and currentness remain later admission / frontier laws.
-/
structure RelationRevision where
  id : RelationRevisionId
  target : RelationUnitId
  replacement : Option RelationUnitId
deriving Repr, DecidableEq

end Loam.Core
