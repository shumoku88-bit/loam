import Loam.Core.Event

namespace Loam.Observation292

open Loam.Core

set_option autoImplicit false

/-!
# Observation 292 — externally observed lot identity is not derivable from provenance

Observations 287–291 pressure-tested lot-like continuity using physical Effects,
quantity-bearing provenance, basis evidence, and one-to-one / one-to-many /
many-to-one transformations.

Those observations left one deliberate question open:

> Can a selected query require a stable lot reference that is independently
> observed rather than reconstructed from the retained provenance graph?

Real custodial data formats provide exactly that pressure. Some brokers/custody
feeds publish stable tax-lot identifiers and references between open and closed
lot records.

This observation does not model any particular vendor format. It tests only the
information boundary exposed by such formats.

Two worlds retain the exact same:

- acquisition origin;
- current quantity-bearing Effect;
- quantity-bearing provenance edge;
- acquisition basis;
- current quantity.

They differ only in the externally observed lot identifier.

If the query "what lot identifier did this custodian report?" changes while the
internal graph does not, then provenance does not determine external lot
identity.
-/

structure EffectAnchor where
  event : EventId
  effect : EffectKey
deriving Repr, DecidableEq

private def origin : EffectAnchor :=
  ⟨⟨"origin-acquisition"⟩, ⟨"origin-held"⟩⟩

private def current : EffectAnchor :=
  ⟨⟨"current-position"⟩, ⟨"current-held"⟩⟩

structure LineageEdge where
  origin : EffectAnchor
  current : EffectAnchor
  units : Quantity
deriving Repr, DecidableEq

private def lineage : List LineageEdge := [
  {
    origin := origin
    current := current
    units := Quantity.ofQuanta 3
  }
]

structure BasisEvidence where
  acquisition : EffectAnchor
  basisJpy : Int
deriving Repr, DecidableEq

private def basis : List BasisEvidence := [
  {
    acquisition := origin
    basisJpy := 1200
  }
]

/--
One externally reported lot identifier.

The identifier is namespaced by the reporting custodian and account. The raw
text therefore does not pretend to be a globally unique LOAM identity.
-/
structure ExternalLotIdentityEvidence where
  custodian : String
  account : String
  lotId : String
  subject : EffectAnchor
deriving Repr, DecidableEq

structure World where
  lineage : List LineageEdge
  basis : List BasisEvidence
  externalLots : List ExternalLotIdentityEvidence
deriving Repr, DecidableEq

private def worldA : World := {
  lineage := lineage
  basis := basis
  externalLots := [{
    custodian := "custodian-x"
    account := "account-1"
    lotId := "LOT-ALPHA"
    subject := origin
  }]
}

private def worldB : World := {
  lineage := lineage
  basis := basis
  externalLots := [{
    custodian := "custodian-x"
    account := "account-1"
    lotId := "LOT-BETA"
    subject := origin
  }]
}

private def internalProjection
    (world : World) : List LineageEdge × List BasisEvidence :=
  (world.lineage, world.basis)

private def reportedLotId?
    (world : World)
    (custodian account : String)
    (subject : EffectAnchor) : Option String := do
  let row ← world.externalLots.find? fun item =>
    item.custodian = custodian &&
    item.account = account &&
    item.subject = subject
  pure row.lotId

/--
The complete selected internal provenance/basis graph is identical.
-/
theorem same_internal_graph_and_basis :
    internalProjection worldA = internalProjection worldB := by
  native_decide

/--
But the independently observed external lot-reference answer differs.

Therefore the external identifier is not reconstructable from the selected
internal provenance graph.
-/
theorem same_graph_different_external_lot_identity :
    reportedLotId? worldA "custodian-x" "account-1" origin =
        some "LOT-ALPHA" ∧
    reportedLotId? worldB "custodian-x" "account-1" origin =
        some "LOT-BETA" := by
  native_decide

/--
A raw lot-id string is not assumed globally meaningful.

Two custodians may use the same spelling while still reporting different
external identities.
-/
private def sameRawIdDifferentCustodianWorld : World := {
  lineage := lineage
  basis := basis
  externalLots := [
    {
      custodian := "custodian-x"
      account := "account-1"
      lotId := "LOT-42"
      subject := origin
    },
    {
      custodian := "custodian-y"
      account := "account-9"
      lotId := "LOT-42"
      subject := origin
    }
  ]
}

theorem external_lot_identity_requires_source_namespace :
    reportedLotId?
        sameRawIdDifferentCustodianWorld
        "custodian-x" "account-1" origin = some "LOT-42" ∧
    reportedLotId?
        sameRawIdDifferentCustodianWorld
        "custodian-y" "account-9" origin = some "LOT-42" := by
  native_decide

/--
Open/closed lifecycle references are also independently observable external
facts, not consequences of the physical/provenance graph.
-/
structure ExternalLotLifecycleEvidence where
  custodian : String
  account : String
  closedLotId : String
  priorOpenLotId : String
deriving Repr, DecidableEq

private def closedReference : ExternalLotLifecycleEvidence := {
  custodian := "custodian-x"
  account := "account-1"
  closedLotId := "CLOSED-7"
  priorOpenLotId := "OPEN-3"
}

theorem external_closed_to_open_reference_is_retained_as_given :
    closedReference.closedLotId = "CLOSED-7" ∧
    closedReference.priorOpenLotId = "OPEN-3" := by
  native_decide

/-!
## Finding

This is the first pressure in the practical lot sequence where a stable lot-like
identifier is independently observable even after the selected provenance graph
is fully retained.

The graph answers questions such as:

- which acquisition origin feeds the current quantity;
- how much quantity descends from each origin;
- which basis belongs to each origin.

It cannot answer:

> What stable lot identifier did the external custodian report?

unless that identifier itself is retained.

So the graph-only hypothesis is incomplete for interoperability.

However this result still does **not** force a universal production `LotId`
inside neutral Core.

The smallest earned shape is closer to:

```text
internal provenance subject
    +
external identity evidence
    (custodian, account, external lot id)
```

The namespace matters because the same raw lot-id spelling can exist under
different external authorities.

A first-class internal `LotId` would become independently earned only if LOAM
itself needs a stable referent that is:

- not merely one physical Effect;
- not merely an acquisition origin;
- not reconstructable as a selected provenance component;
- and not merely the identifier assigned by one external source.

Possible future pressures include user annotations, correction targets, or
multiple external identities that must all attach to one LOAM-owned stable
lot-like subject.

Not earned here:

- production `ExternalLotIdentityEvidence`;
- production `LotId`;
- broker/custodian registry;
- tax-lot persistence;
- automatic reconciliation between external and internal lot identity;
- authority rules when two external sources disagree;
- corporate-action rewrite rules for external lot ids.
-/

end Loam.Observation292
