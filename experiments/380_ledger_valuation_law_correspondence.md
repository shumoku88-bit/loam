# Observation 380 — Ledger valuation-law correspondence

Status: **LEAN CORRESPONDENCE PROBE — balance algebra only; no production vocabulary change**

Baseline:

```text
main  a51c9f96daa7b7d3be036f4cf2df08f637339c09
#1448 Observation 379 merged
```

External reference inspected:

```text
ledger/ledger-semantics
main f5d891ef2dca358951780dab4ba0a80073b31964
```

## Trigger

The current `ledger/ledger-semantics` repository is a useful independent Lean
formalization of double-entry plain-text accounting.

Its public theory distinguishes:

- a richer transaction/morphism structure;
- an additive valuation;
- a Pacioli-group balance denotation;
- reporting / pricing layers outside the smallest compositional core.

The important current theorems include:

```text
balanced_generators_balance
trial_balance
pacioli_equation
balance_sheet_independent_of_composition_order
reversal_correctness
aggregation_correctness

flow_comp
flow_inv
flow_tensor
flow_add

zero_absorption_degenerates
comp_not_zero_absorbing
tensor_not_additive
```

LOAM had already studied the same neighborhood independently:

```text
O159     retained list -> finite-vector meaning
O250     BalancedMovement -> Ledger/Pacioli-shaped balance projection
O253     generic mediated accounting-view commutation
O254-256 balance image is intentionally weaker than retained Event history
O276     proof-carrying finite conservation
O278     exact reversal cancellation, including coordinate-wise
CSA-006  augmentation factors through vector meaning and append is additive
O142-143 valuation coordinate / rate-source authority separation
O210     acquisition basis / market valuation / report-policy composition
```

So the question is not whether LOAM should adopt Ledger's category/groupoid
ontology.

It is:

> Which exact valuation equations are already true of LOAM's existing
> Observation-250 projection, and where must the correspondence stop?

## Selected correspondence

Observation 380 proves directly on the existing
`ledgerFlowQuantaAtChanges` / `ledgerFlowAtChanges` bridge:

```text
empty
  -> zero

left ++ right
  -> flow(left) + flow(right)

negate every quantity
  -> -flow

Observation-159 VectorEquivalent
  -> equal flow at every mapped same-Measure coordinate
```

These correspond to the zero/additive/inverse behavior visible in
`ledger-semantics` valuation and Pacioli layers.

## Critical non-correspondence

The current Ledger formalization deliberately retains several structurally
different operations whose valuations all become addition:

```text
composition
tensor
hom-set addition
```

Its negative theorems are important here. In particular,
`zero_absorption_degenerates` shows that adding an intuitively tempting
composition/zero absorption law collapses every valuation to zero, while the free
model separately refutes zero absorption and tensor bilinearity.

LOAM should therefore **not** reason backwards from:

```text
same additive balance equation
```

to:

```text
same upper semantic operation
```

LOAM's movement change list retains evidence/presentation; Observation 159's
finite vector is its selected balance meaning. Neither is automatically a
Ledger categorical morphism.

## Independent convergence already present

The comparison found several stronger correspondences that need no new proof:

### Balance versus history

`ledger-semantics` explicitly states that its Pacioli skeleton loses morphism
identity and that the current executable oracle compares balances rather than
register rows.

LOAM O254-256 independently established:

```text
retained Event/effect history
        -> Event-indexed quantity view
        -> balance image

each downward step may lose information
```

So O250's bridge is correctly scoped as a projection, not a round-trip encoding.

### Reversal

Ledger proves `reversal_correctness`.

LOAM O278 already proves the stronger domain-local fact needed by LOAM:
negating the retained movement payload cancels the target at every coordinate.

O380 merely states that this exact negation also commutes through the
Ledger-shaped balance projection.

### Aggregation

Ledger proves `aggregation_correctness`.

LOAM CSA-006 already proves exact total additivity under concatenation. O380
lifts the same law to every Ledger-shaped account coordinate.

### Pricing / valuation

The Ledger theory keeps pricing outside its smallest compositional core and
provides explicit price/revaluation machinery.

LOAM's prior valuation research likewise keeps occurrence, acquisition basis,
valuation coordinate, rate/source authority, and report policy separate rather
than baking implicit valuation into neutral Event history.

This is useful independent architectural convergence, not evidence that the two
systems have identical semantics.

## Production consequence

None.

Do not add:

- `Account` to Core;
- debit/credit primitives;
- Ledger category/groupoid structures;
- Mathlib merely for this correspondence;
- an external `ledger-semantics` dependency;
- composition/tensor operators for movements;
- pricing or valuation authority to Event Core.

The current useful bridge remains one-way and balance-level.

## Stop condition

If the Lean laws compile:

1. retain O380 as an executable correspondence witness;
2. keep O250 / O253 as the primary balance bridge;
3. treat `ledger-semantics` as an external semantic reference/oracle, not LOAM
   architecture;
4. do not duplicate Ledger's richer algebra unless a concrete LOAM household
   query requires one of the distinctions it preserves.
