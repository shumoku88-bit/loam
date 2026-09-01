# Application 008: starting quantity basis

## Question

The practical daily-use entrance can now record:

```text
spend     Locus -q
income    Locus +q
transfer  source -q / destination +q
```

and the Application boundary can project safe correction frontiers.

One gap remains before those projections can resemble ordinary current holdings:
LOAM may begin while quantity already exists at a locus.

For example, if the user adopts LOAM while a bank locus already contains
`100000 jpy`, recording

```text
bank +100000
```

as an ordinary Event would make the arithmetic work, but it would assign the
wrong physical meaning. The production `Effect` vocabulary explicitly says that
it records **where a change is observed** and **how much changed**. A quantity
that merely already existed at the adoption boundary is not such a change.

The application question is therefore:

> Can a small independent quantity-basis family anchor current holdings without
> reclassifying pre-existing quantity as income or inventing a fictional Event?

## Existing evidence

This probe applies earlier results rather than opening a new Observation number.

- Observation 031 established that `Locus` is the needed neutral coordinate for
  where quantity resides; a conventional Account object is not required for the
  selected balance-by-locus vocabulary.
- Observation 049 established that accounting role is independent of physical
  placement.
- Observation 062 showed that a bookkeeping-shaped opening entry can later be
  recognized as `Asset +q / Equity -q` when an AccountingRole overlay is present,
  but it did not make that accounting representation a universal Core law.
- Observation 054 separated logical fact families, physical storage topology,
  and derived projections.
- Application 006 qualified conservative addition of a later typed fact family
  without changing existing Event or Correction meaning.

The practical bootstrap question is narrower than bookkeeping opening-entry
semantics. It asks only how to anchor physical quantity when LOAM starts partway
through an already-existing household life.

## Candidate boundary

Application 008 uses experiment-local vocabulary:

```text
QuantityBasisFact
  = explicit fact identity
  + Locus
  + Measure
  + Quantity
```

and composes it with the already-effective Event contribution:

```text
current coordinate quantity
  = selected starting basis
  + correction-aware Event quantity
```

The basis is deliberately **not** an Event and does not claim that its quantity
changed at LOAM adoption time.

The selected basis image admits at most one basis fact per `Locus × Measure`
coordinate and keeps basis fact identity unique. This prevents two simultaneous
starting values from silently becoming an additive double count.

## Lean probe

`application_008_starting_quantity_basis.lean` checks a small specimen:

```text
starting bank/jpy basis   +100000
income                     +20000
spend                       -5000
transfer bank -> wallet    -10000 / +10000
```

The resulting quantities are:

```text
bank     105000
wallet    10000
```

It also checks:

- a coordinate without a basis still receives ordinary Event changes;
- an empty basis exactly recovers the Event-only answer for the specimen;
- the same Event history with a different starting basis produces a different
  current holding;
- duplicate basis coordinates fail closed;
- duplicate basis fact identity fails closed.

The third check is the key information boundary: Event history alone cannot
reconstruct how much quantity already existed when this application image began.

## Interpretation

The smallest useful distinction is:

```text
change observed within represented activity
    !=
quantity already present at the projection origin
```

So the first daily-use bootstrap should not disguise starting quantity as
`income`, and it should not encode `opening`, `initial`, or similar meaning in
`EventId`, `EffectKey`, or `Locus` tokens.

A separate basis family also avoids forcing accounting semantics into the first
physical-balance slice. If a later query asks for a Balance Sheet or P&L, the
existing AccountingRole result can be introduced explicitly. A conventional
bookkeeping opening entry against Equity is one possible accounting reading,
not the physical bootstrap primitive established here.

## Why Lean, and why no Alloy/TLA+

The information distinction is already visible from the production type
meaning and earlier observations. Another Alloy two-world model would mostly
repeat Observation 049/072-style independence evidence, and no temporal protocol
changes here, so TLA+ would add machinery without answering a new question.

Lean is useful only for the small executable composition candidate:

- basis and Event contribution remain distinct inputs;
- no basis preserves the old Event-only projection;
- ambiguous basis images fail closed.

The probe does not pretend that theorem difficulty establishes the semantics.
The semantic reason comes from preserving the existing meaning of `Effect` as a
change.

## Important boundaries

Application 008 does **not** yet establish:

- the production name `QuantityBasisFact`;
- whether the basis family belongs in Core or only Application persistence;
- a persistence wire format;
- whether several historical/rebased basis images may coexist;
- append-only correction or revision semantics for an incorrectly entered basis;
- a timestamp, cycle, import boundary, or global chronology for the basis;
- how importing activity from before the current basis should behave;
- Account identity;
- Asset/Liability/Equity/Income/Expense roles;
- a double-entry or zero-sum law;
- whether the human-facing word `balance` is now fully earned.

For the first dogfood slice, the candidate is intentionally scoped to one
application origin: the basis anchors the EventMemory activity recorded after
that origin. Historical import or rebasing should earn a richer boundary later
rather than silently using storage order as time.

## Next practical step

If this probe qualifies, the next production change can stay small:

1. introduce one typed starting-quantity image with fail-closed persistence;
2. let the Application current-quantity projection add that basis to the
   existing correction-aware Event quantity;
3. add a human-facing setup entrance for the starting quantities;
4. only then decide whether the resulting view has earned the word `balance`.

No Account, Equity posting, generic metadata bag, or new EventKind is required
for that step.
