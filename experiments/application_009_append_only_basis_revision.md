# Application 009: append-only basis revision

## Question

Application 008 separated starting quantity from Event change:

```text
current coordinate quantity
  = starting basis
  + correction-aware Event quantity
```

It admitted at most one basis fact per `Locus × Measure` coordinate.

That is sufficient only while the first entered basis is correct. If a user
enters `100000 jpy` and later discovers that the starting quantity was actually
`95000 jpy`, destructive replacement would violate LOAM's append-only direction.

But append-only correction creates a new pressure:

```text
remembered basis facts
  bank/jpy 100000
  bank/jpy  95000
```

Raw memory now necessarily contains more than one basis fact at the same
coordinate.

The application question is therefore:

> Can basis correction remain append-only by moving coordinate uniqueness from
> raw remembered facts to the admitted correction frontier?

## Existing evidence

This probe applies earlier revision results rather than opening a new Observation
number.

- Observations 021–023 established append-only correction, frontier ambiguity,
  and explicit resolution for Event-shaped facts.
- Observations 042–043 showed that frontier/settlement structure can be stated
  generically over revision identity and parentage rather than household names.
- Application 007 already used a finite fail-closed correction forest to obtain
  one current quantity without list-order authority.
- Application 008 established that starting quantity is a separate typed fact
  family because production `Effect` means observed change.

The remaining question is not whether revision graphs work in general. It is how
that existing structure changes the basis admission boundary.

## Candidate boundary

The probe keeps two independently typed remembered families:

```text
BasisFact
  = BasisId + Locus + Measure + Quantity

BasisCorrection
  = target BasisId + replacement BasisId
```

Raw basis memory requires only unique `BasisId`. It no longer requires unique
coordinates.

A current basis frontier is admitted only when:

1. basis identity is unique;
2. each correction target has at most one outgoing correction;
3. every correction endpoint is remembered;
4. the correction graph is acyclic;
5. every correction in this narrow probe preserves `Locus × Measure`;
6. the surviving frontier contains at most one basis fact per coordinate.

The current frontier is exactly remembered basis facts that are not correction
targets.

## Representative specimen

Remembered basis facts:

```text
bank-v1    bank/jpy    100000
bank-v2    bank/jpy     95000
wallet-v1  wallet/jpy   10000
```

Correction:

```text
bank-v1 -> bank-v2
```

Raw memory contains two `bank/jpy` basis facts, but the admitted frontier is:

```text
bank-v2    bank/jpy     95000
wallet-v1  wallet/jpy   10000
```

If the already-effective Event contribution at `bank/jpy` is `+5000`, the
current quantity is therefore:

```text
95000 + 5000 = 100000
```

The Event contribution is not rewritten by the basis correction.

## Lean probe

`application_009_append_only_basis_revision.lean` checks:

- historical same-coordinate basis facts can coexist when only one survives the
  frontier;
- the replacement basis becomes current while the old fact remains remembered;
- basis correction composes with an independent effective Event quantity;
- a linear basis-correction chain has one current tip;
- reversing correction-list representation does not change that tip;
- two uncorrected terminal basis facts at one coordinate fail closed;
- sibling corrections fail closed rather than choosing a winner;
- cycles and dangling references fail closed;
- an empty basis/correction image still exactly recovers the old Event-only
  quantity;
- coordinate-changing basis correction is deliberately rejected by this probe.

## Finding candidate

The useful refinement is:

```text
raw basis-coordinate uniqueness
    is too strong for append-only correction

frontier basis-coordinate uniqueness
    is sufficient for the selected current projection
```

The invariant belongs to the admitted **current image**, not necessarily to all
historical facts that make that image recoverable.

That mirrors a broader LOAM pattern: historical multiplicity can be truthful
provenance while current multiplicity is either a meaningful frontier or a
reason to refuse a single current answer.

## Why Lean, and why no new Alloy/TLA+

The graph law itself is not new. Alloy and Lean already established the generic
frontier structure in Observations 042–043, and Application 007 exercised the
same fail-closed finite shape for Event quantity.

This probe asks for a small executable application consequence: move one
uniqueness check from raw basis memory to the current frontier while preserving
conservative composition with Event quantity. Lean is sufficient for that
candidate law.

No temporal protocol changes, so TLA+ is not earned here.

## Important boundaries

Application 009 does **not** yet establish:

- the production names `BasisFact` or `BasisCorrection`;
- a generic universal correction type shared by every fact family;
- coordinate-changing basis correction;
- sibling-conflict resolution for basis facts;
- rebasing or historical import before the application origin;
- learned time or valid time for a basis;
- persistence format or publication protocol;
- a human-facing correction command;
- Account, AccountingRole, Equity, or double-entry rules.

The same-coordinate restriction is intentional. A wrong quantity is enough to
test whether the Application 008 admission boundary survives append-only
correction. Correcting a wrong locus or measure can be observed separately if
real dogfood requires it.

## Next practical step

If this probe qualifies, production can still remain small:

1. introduce a typed starting-basis memory;
2. introduce an append-only typed basis-correction relation only if the setup
   workflow needs correction immediately;
3. admit one current basis frontier per coordinate fail-closed;
4. compose that frontier with the existing correction-aware Event quantity;
5. then add the human-facing starting-quantity setup entrance.

The probe does not require changing Event or EventCorrection representation.
