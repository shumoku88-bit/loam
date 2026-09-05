# Observation 174: Does overlay meaning need to reuse the source Effect sign?

Status: bounded Alloy observation stacked on Observation 173.

Observation 173 qualified a smaller quantity shape than one universal identity-bearing partition:

```text
source Effect
  signed physical quantity

burden plane
  exact allocation by bearer

open-relation plane
  relation identity
  + exact quantity
  + endpoints
```

It deliberately left one representation question unresolved:

> Should burden/relation overlay quantities preserve the signed source `Quantity`, or is exact magnitude plus family-specific semantic structure enough?

Production `Loam.Core.Quantity` is intentionally an exact signed integer whose sign has no built-in accounting or physical meaning. `Effect` likewise gives its sign no built-in debit, credit, inflow, outflow, or accounting meaning.

Observation 174 therefore asks whether source sign and semantic orientation are actually the same information in the household cases already observed.

## Observation-local reduction

This observation is about orientation, not arithmetic. To avoid irrelevant Alloy symmetry, the model abstracts production signed `Quantity` into:

```text
Effect {
  (Event, Key)
  sourceSign : PositiveSource | NegativeSource
}
```

Every Effect is treated as carrying the same representative exact magnitude `10`.

Observation 173 already qualified plane-local exact magnitude and source bounds, so Observation 174 does not re-prove those arithmetic laws. It isolates only whether the sign bit carries semantic direction.

Burden remains an exact representative allocation:

```text
10 = Household burden + Outside burden
```

Open relation keeps semantic endpoint direction directly:

```text
RelationUnit {
  source Effect
  debtor
  creditor
}
```

All relation witnesses use the same representative exact magnitude `4`; magnitude is intentionally constant because it is not the variable under test.

The source sign remains retained physical provenance in production. The question is only whether an overlay needs to copy or reinterpret that sign.

## Probe 1: negative source can carry a receivable-like relation

The model admits:

```text
source sign = negative
relation    = Outside -> Household
```

Expected: **SAT**.

So negative source sign does not imply `Household -> Outside`.

## Probe 2: positive source can carry the same relation direction

The model also admits:

```text
source sign = positive
relation    = Outside -> Household
```

Expected: **SAT**.

Thus receivable-like direction does not determine source sign either.

## Probe 3: same source sign supports opposite relation directions

Two negative source Effects can respectively carry:

```text
Outside -> Household
Household -> Outside
```

Expected: **SAT**.

Therefore source sign is not a second debtor/creditor coordinate.

## Probe 4: same relation direction can occur across opposite source signs

The same outside-to-household direction is admitted over one positive and one negative source Effect.

Expected: **SAT**.

This is the converse pressure: semantic direction is not a source-sign projection.

## Probe 5: burden can stay the same across opposite source signs

Two Effects with opposite source signs may both have:

```text
Household burden 6
Outside burden   4
```

Expected: **SAT**.

So source sign also does not determine bearer allocation.

## Probe 6: signed edge + endpoint order double-encodes orientation

The model includes one deliberately redundant candidate representation:

```text
(first endpoint, second endpoint, encoding sign)
```

where positive means `first -> second` and negative reverses the direction.

Then these two raw encodings have the same semantic result:

```text
Outside, Household, positive
Household, Outside, negative
```

Both project to:

```text
Outside -> Household
```

Expected: **SAT**.

Exact duplicate raw tuples are forbidden, so this duplicate semantic encoding comes specifically from retaining both endpoint order and sign as orientation coordinates.

This does not prove that signed relation quantities are impossible. It shows that if sign and endpoint order both encode orientation, the representation is non-canonical unless another convention is added.

A canonical convention such as "relation quantity is positive magnitude" collapses directly to:

```text
explicit debtor
explicit creditor
positive exact magnitude
```

which is already the smaller candidate shape from Observations 172–173.

## Deliberately too-strong checks

The model checks three tempting derivations:

```text
source sign -> relation direction
relation direction -> source sign
source sign -> burden split
```

Expected for all three: **SAT counterexample**.

It also checks:

```text
semantic directed edge -> unique signed raw encoding
```

Expected: **SAT counterexample**.

Together these checks expose that source sign, burden meaning, relation direction, and redundant encoding polarity are distinct coordinates.

## Candidate finding

If the matrix holds, the smallest currently qualified distinction is:

```text
physical source
  Effect.quantity : signed exact Quantity
  sign retained as source-coordinate provenance

burden overlay
  exact nonnegative magnitude allocation
  bearer supplies burden meaning

open-relation overlay
  exact positive magnitude
  debtor / creditor supply semantic direction
```

This is not a claim that sign can never matter in a future overlay family. A future relation-delta, netting, reversal, or another genuinely signed semantic operation could create new pressure.

For the currently observed **open relation unit** and **burden allocation**, however, copying source sign into overlay meaning is not earned.

## Production pressure

Observation 174 therefore adds no pressure for:

- `SignedRelationQuantity`;
- `SignedBurdenQuantity`;
- a rule mapping negative Effect to payable;
- a rule mapping positive Effect to receivable;
- a rule mapping Effect sign to burden bearer;
- a second orientation field beside debtor/creditor;
- stripping sign from production `Effect`;
- changing `Loam.Core.Quantity`.

The likely future representation remains closer to:

```text
RelationUnit
  source: (EventId, EffectKey)
  debtor: endpoint identity
  creditor: endpoint identity
  quantity: exact positive magnitude
```

and, independently:

```text
BurdenAllocation
  source: (EventId, EffectKey)
  exact magnitude allocation by bearer
```

without a generic cross-plane quantity-part identity.

## Stack

This observation is stacked on Observation 173 / PR #356 at exact head:

`d3f1efbe0a89c926798244337a3497fa51d1f103`

PR #356 remains unmerged by this observation.

## What this does not earn

Observation 174 does **not** earn:

- production relation or burden types;
- endpoint persistence;
- relation persistence;
- a positive-to-none retraction representation;
- relation completeness cutover;
- writer qualification changes;
- CLI/TUI changes;
- historical backfill;
- a universal claim that every future semantic quantity must be nonnegative.
