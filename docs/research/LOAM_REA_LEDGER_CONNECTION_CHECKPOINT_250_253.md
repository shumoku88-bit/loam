# LOAM–REA–Ledger connection checkpoint — Observations 250–253

Baseline: `331f3f3f3de107f7de3e1e07d4effdc47c607d2f`

This checkpoint freezes the result of the first connection study before the next question moves from balance semantics to history semantics.

## Qualified connection

Observation 250 establishes a direct additive projection from a qualified LOAM `BalancedMovement` into a Ledger/Pacioli-shaped balance image without adding Account, debit/credit, or transaction-kind meaning to LOAM Core.

Observation 251 shows by bounded Alloy counterexample that neutral LOAM evidence does not uniquely determine selected REA distinctions such as Resource interpretation, Agent participation, or duality. REA therefore enters as independent economic interpretation rather than as a synonym for LOAM coordinates.

Observation 252 shows that selected REA interpretation likewise does not uniquely determine a Ledger account surface. An explicit accounting-view policy is required. When that policy agrees with the direct LOAM coordinate view, the bounded triangle commutes.

Observation 253 promotes the positive commutation result to Lean. For an arbitrary intermediate `Resource` type, agreement is required only on changes actually present in the selected movement. Unobserved Loci and other Measures are irrelevant to that query. Lean also proves that a compatible Resource-only bridge cannot collapse two Loci whose direct Ledger coordinates are distinct.

The resulting shape is:

```text
                     LOAM retained evidence
                    /                      \
                   /                        \
      economic interpretation          additive denotation
                 /                            \
                v                              v
              REA                         Ledger/Pacioli
                \
                 \
          accounting-view policy
                   \
                    v
              Ledger/Pacioli
```

The bridge is query-local, not an ontology identity claim.

## What is established

At the selected balance level:

```text
direct LOAM -> Ledger image
=
LOAM -> interpretation -> accounting view -> Ledger image
```

whenever coordinate selection agrees on the actually observed changes.

This gives the layers different jobs:

- LOAM retains neutral evidence, identity, and independently earned provenance distinctions;
- an REA-shaped layer can supply economic interpretation;
- an accounting-view policy chooses an account surface;
- the Ledger/Pacioli-shaped layer supplies additive balance denotation.

No result says that `LocusId = Account`, `LocusId = Resource`, `MeasureId = Commodity`, or `Event = Transaction`.

## Explicit non-results

The first connection study does **not** establish commutation for:

- Event or transaction identity;
- register rows or event-by-event reporting;
- correction and replacement provenance;
- historical `as-known` state;
- valuation or prices;
- lots, booking, or cost basis;
- recognition policy;
- tax or localization;
- ordering, causality, or posting order.

This boundary matters because Ledger's current public semantics explicitly distinguishes its balance oracle from register comparison, while LOAM Core retains stable `EventId` independently of its additive coordinate projections.

## Next pressure

Observation 254 starts the second connection study:

> Can two distinct LOAM event histories have the same balance image, and what is the smallest event/register evidence required to distinguish them again?

The expected answer is not assumed. The first task is to construct or reject a counterexample rather than to add a production register abstraction.
