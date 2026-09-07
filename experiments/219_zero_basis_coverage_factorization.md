# Observation 219 — Can pointwise-zero QuantityBasis factor into origin coverage?

Status: **PROBE**

## Question

`QuantityBasis` was introduced for a real distinction:

```text
quantity already present when the selected application image begins
    !=
Event / change
```

The current private dogfood has since changed shape. Historical household evidence
was imported into the selected Event world, and the remaining selected basis
frontier is pointwise zero with no retained basis-correction or basis-cut pressure.
No private coordinates or quantities are committed by this observation.

That creates a narrower question than "can QuantityBasis be deleted?":

> When every selected starting basis is exact zero, does the basis carry any
> information beyond the finite set of coordinates for which zero-origin
> coverage is actually known?

## Existing constraints

Several earlier results prevent an overly aggressive simplification.

- Application 008 earned `QuantityBasis` because starting state is not necessarily
  a historical change.
- Observation 090 showed that numeric zero does not determine which origin
  boundary is meant.
- `CurrentQuantity` deliberately preserves `basisMissing != zero`.
- Observation 102 separated balance-view selection from quantity evidence.
- AccountingRole is also independent: Asset classification does not prove
  quantity-history coverage.

Therefore neither of these is admissible:

```text
missing basis -> assume zero
selected balance coordinate -> assume zero
Asset role -> assume zero
```

## Candidate factorization

The experiment introduces only an observation-local value:

```text
ZeroOriginCoverage
  = finite explicit set of Locus × Measure coordinates
```

For a covered coordinate:

```text
current
  = 0 + correction-aware Event quantity
  = correction-aware Event quantity
```

For an uncovered coordinate:

```text
basisMissing
```

The common zero is therefore factored out, while the domain that distinguishes
known-zero origin from missing evidence remains explicit.

The candidate intentionally has:

- no Account or AccountingRole meaning;
- no balance-view meaning;
- no per-coordinate stable basis identity;
- no correction relation of its own;
- no stored quantity other than the common zero premise.

## Lean probe

`219_zero_basis_coverage_factorization.lean` uses only public synthetic values and
production `CurrentQuantity` / `QuantityInspection` boundaries.

The specimen contains:

```text
wallet Event quantity  = -7
reserve Event quantity =  0
use Event quantity     = +7
```

and two starting shapes.

### Shape A — pointwise-zero basis

```text
wallet  basis = 0
reserve basis = 0
```

with zero-origin coverage over exactly `wallet` and `reserve`.

The probe checks:

1. covered `wallet`: production zero-basis current equals the coverage-gated
   Event answer;
2. covered inactive `reserve`: explicit known zero remains current zero;
3. uncovered `use`: both paths return `basisMissing`, even though Event activity
   exists there.

The third check is the important open-world control. Removing basis quantity does
not authorize removing the coverage domain.

### Shape B — non-zero basis negative witness

The same Event world is paired with:

```text
wallet starting basis = 100
```

Production current becomes `93`, while zero-origin coverage gives `-7`.

So:

```text
pointwise-zero QuantityBasis
    may factor into
explicit zero-origin coverage + Event quantity

arbitrary QuantityBasis
    does not
```

## Accounting comparison

Conventional bookkeeping often resolves a bootstrap by introducing opening
entries. That can make a complete ledger numerically self-contained.

LOAM's evidence question is slightly different: an observed state at an
application boundary need not assert that a real-world change occurred there.
`QuantityBasis` was introduced precisely to retain that distinction.

Therefore Observation 219 does **not** conclude that opening entries make
QuantityBasis universally redundant. It asks whether a fully reconstructed
history whose remaining basis values are all zero still needs five or more
independent quantity facts merely to retain a completeness domain.

## Candidate finding if the Lean checks pass

The expected qualified result is:

```text
zero basis quantity
    -> numerically redundant

basis coordinate membership
    -> still semantically observable
       because missing != zero
```

This would make the current dogfood basis shape a factorization candidate rather
than justify deleting the general `QuantityBasis` type immediately.

A later production change would still need to choose explicitly between:

1. retaining general `QuantityBasis` for partial-history / non-zero bootstrap;
2. adopting a stronger LOAM operating invariant in which non-zero initial state
   is represented elsewhere, leaving only explicit history coverage;
3. supporting both without building two overlapping quantity engines.

Observation 219 should not choose among those before the current zero-only
factorization is mechanically established.

## Non-goals

This observation does not introduce or authorize:

- a production `HistoryCoverage` / `OriginCoverage` type;
- deletion of `QuantityBasis`, `QuantityBasisCorrection`, or `BasisCut`;
- implicit zero for arbitrary coordinates;
- inference from AccountingRole, Locus spelling, or balance-view configuration;
- a fictional historical Event merely to make a ledger close;
- Account, debit/credit, or opening-equity Core ontology;
- private household values in the public repository.

## Practical Core impact

None for the probe.

If qualified, the next question is practical and destructive:

> Does current LOAM still need the **general** partial-history bootstrap capability,
> or can the selected real-data operating model require explicit history coverage
> and reconstruct starting state without QuantityBasis?
