# Observation 219 — can zero-only QuantityBasis be eliminated after historical reconstruction?

Status: **QUALIFIED REWRITE CANDIDATE**

Research starting point: LOAM `b95e2b418365b7960b0087a1b9329b52578f16b5`

## Question

LOAM introduced `QuantityBasis` for an important reason:

```text
an exact quantity already present when the selected application image begins
```

is not itself an Event/change.

That remains a valid distinction in general. But the current household image has changed shape after historical reconstruction. The retained historical Event world now includes opening entries and the current `loam-data/basis.loam` contains only five exact-zero rows:

```text
cash         jpy  0
paypay       jpy  0
smbc         jpy  0
yucho        jpy  0
all-country  jpy  0
```

The question is therefore narrower than deleting `QuantityBasis` from LOAM:

> When every selected basis quantity is exact zero and historical Event evidence supplies all retained quantity movement, does one basis fact per coordinate retain any quantity information beyond explicit admission of the coordinate into a known-zero application-start domain?

## Existing law that must survive

Production deliberately distinguishes:

```text
missing basis != exact zero basis
```

So this experiment must not replace missing basis with implicit global zero.

The smaller candidate, if any, must preserve a finite explicit domain:

```text
D : finite set of Locus × Measure coordinates

c in D
  -> application-start quantity is known exactly zero

c not in D
  -> no zero-origin claim
```

## Synthetic Lean probe

`219_zero_basis_elimination.lean` introduces only one experiment-local shape:

```text
ZeroOriginDomain
  coordinates : finite Nodup list of EffectCoordinate
```

For a coordinate in that domain it derives:

```text
current = EventMemory.quantityAtRecorded
```

which is the same arithmetic as:

```text
current = zero QuantityBasis + EventMemory.quantityAtRecorded
```

The probe checks:

1. a zero QuantityBasis adds no arithmetic information;
2. one explicit finite zero-origin domain produces the same answer for admitted coordinates;
3. a coordinate outside the domain remains `none`, not zero;
4. a nonzero QuantityBasis cannot be eliminated;
5. therefore erasing the domain entirely would strengthen unknown coordinates into known-zero origins.

## Qualified result

The Lean probe compiles and all executable witnesses pass against production `EventMemory` and `QuantityBasis` types.

The qualified factorization is therefore:

```text
zero-only QuantityBasis
  = quantity contribution 0
  + coordinate membership / coverage evidence
```

For exact-zero basis rows, the quantity contribution is extensionally neutral for the current recorded-Event arithmetic. The independently meaningful remainder is the finite set of coordinates for which the application-start quantity is known exactly zero.

The negative controls matter equally:

```text
nonzero QuantityBasis
  != eliminable quantity evidence

coordinate outside explicit domain
  != known zero
```

So Observation 219 does not earn a global zero default.

## What this does and does not show

For the current zero-only shape it supports this factorization:

```text
current zero-only basis memory

  five stable QuantityBasis identities
  five quantities all equal 0
  five coordinates

may factor into

  one application-start zero interpretation
  + one explicit finite coordinate domain
```

It does **not** show that the domain can be inferred from:

- AccountingRole;
- `balance-view.tsv`;
- Locus spelling;
- current Event support;
- all possible future coordinates.

Those would each erase independent absence/coverage meaning.

It also does not show that nonzero starting quantities, basis correction, or basis-cut evidence are obsolete in all possible LOAM worlds.

## Accounting comparison

The result is consistent with a familiar ledger shape after historical reconstruction:

```text
opening entries + retained movements
```

When historical Event evidence itself carries the opening quantities, a separate zero-valued quantity basis is no longer quantity evidence. What remains is an evidence question about coverage:

> For which coordinates is the selected retained history known to start from exact zero?

That convergence is useful even though it resembles ordinary bookkeeping rather than inventing a new accounting structure.

## Practical promotion criterion

Production/data simplification is now a qualified candidate, not yet a production change.

A follow-up practical check must establish for the current household image that:

1. the five selected bases are all exact zero;
2. no selected/current basis correction depends on their stable ids;
3. no basis-cut evidence depends on their stable ids;
4. the same five coordinates remain explicit as a coverage domain somewhere that is not inferred from presentation or accounting classification;
5. practical balance answers are identical before and after the representation change;
6. an unadmitted coordinate still refuses instead of becoming zero.

If those hold, the current household path can plausibly retire the five `QuantityBasisId` facts and preserve only the smaller zero-origin domain evidence.

## Non-goals

Observation 219 does not introduce:

- a production `Origin` abstraction;
- a global zero default;
- Account or AccountType;
- Event chronology;
- deletion of `QuantityBasis` for every possible LOAM dataset;
- inference of completeness from Git history;
- inference of the zero-origin domain from `balance-view.tsv` or AccountingRole.

## Practical Core impact

None yet. The candidate is Application/data-shape pressure until the practical household check earns a production replacement.
