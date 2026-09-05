# Observation 180 — observational closure and a minimal additive basis

Observation 179 established a preservation polarity at the free-Abelian
projection boundary:

```text
chosen observations
    <->
retained-evidence transformations that preserve them
```

It also showed that natural additive-image preservation is not generally a
symmetry group because normalization can be non-invertible.

Observation 180 asks the next smaller question:

> If we apply the observation/preserver polarity twice, which observations are
> already forced by the observations we chose, and can that distinguish a
> genuinely necessary report field from a redundant derived one?

## Double-polarity closure

For an observation family `O`, define:

```text
PreserverOf(O)
  = every retained-evidence endomap preserving every observation in O

Closure(O)
  = every observation preserved by every transform in PreserverOf(O)
```

Equivalently:

```text
Closure(O) = Invariants(PreserverOf(O))
```

The Lean field trial proves the three closure-operator laws:

```text
O subset Closure(O)                         extensivity
O1 subset O2 -> Closure(O1) subset Closure(O2)  monotonicity
Closure(Closure(O)) = Closure(O)            idempotence
```

This is the practical consequence of Observation 179's Galois polarity rather
than a new algebra imposed on Core.

## Concrete observation language

The field trial remains on Observation 159's finite two-coordinate presentation
plane:

```text
wallet
food
```

and admits four candidate observations:

```text
walletQuantity
foodQuantity
totalQuantity
representationLength
```

Here:

```text
totalQuantity = walletQuantity + foodQuantity
```

while `representationLength` observes retained list shape rather than the
free-Abelian image.

## Result 1: total is forced by the additive basis

Take:

```text
AdditiveBasis = { walletQuantity, foodQuantity }
```

Any evidence transformation preserving both coordinate quantities necessarily
preserves their sum. Lean therefore proves:

```text
totalQuantity in Closure(AdditiveBasis)
```

This is not merely a numerical example. `Closure` quantifies over **all**
endomaps of the retained presentation type.

## Result 2: retained representation shape is not forced

Observation 179's normalization is a concrete counterexample:

```text
compact
  wallet -100
  food   +100

split
  food   +100
  wallet  -40
  wallet  -60
```

Normalization preserves wallet and food quantities, but maps both retained
presentations to the same two-row representative.

Therefore:

```text
representationLength not in Closure(AdditiveBasis)
```

The additive basis does not silently entitle a caller to forget retained
representation evidence.

## Result 3: both coordinates are needed to force total

The observation adds two deliberately destructive comparison transforms:

```text
eraseFood
  retain exact wallet aggregate
  replace food aggregate by zero

eraseWallet
  retain exact food aggregate
  replace wallet aggregate by zero
```

The compact Observation-159 witness shows:

```text
totalQuantity not in Closure({walletQuantity})
totalQuantity not in Closure({foodQuantity})
```

but:

```text
totalQuantity in Closure({walletQuantity, foodQuantity})
```

So the two coordinate observations form a minimal sufficient basis for this
derived total within the field trial: neither coordinate alone is enough.

## Result 4: explicitly adding the derived total adds no distinguishing power

Define:

```text
AdditiveWithTotal
  = { walletQuantity, foodQuantity, totalQuantity }
```

Lean proves that a transform preserves `AdditiveBasis` iff it preserves
`AdditiveWithTotal`. Therefore:

```text
Closure(AdditiveBasis) = Closure(AdditiveWithTotal)
```

So `totalQuantity` is observationally redundant once the two coordinate
quantities are already present.

This does **not** mean a UI should never display a total. It means the total does
not add information or distinguishing power. It can still be valuable as a
human-facing derived convenience.

## Practical reading

This gives LOAM a possible future vocabulary for report/UI pressure:

```text
independent observation
  removing it changes what states can be distinguished

derived observation
  useful to display, but already forced by retained observations

representation observation
  may distinguish evidence that additive reports intentionally collapse
```

The important distinction is therefore not:

```text
show / hide
```

but:

```text
independent / derived / evidence-sensitive
```

A future report audit could ask whether two displayed fields contribute the
same distinguishing power before adding production machinery or removing a
field.

## What this does not earn

Observation 180 does not introduce:

- a production `Closure` type;
- automatic report minimization;
- automatic UI hiding;
- a claim that fewer displayed fields are always better;
- a universal finite observation basis for LOAM;
- quotienting canonical Event or Effect evidence;
- Mathlib algebra dependencies;
- a Galois group;
- changes to persistence, Application, CLI, TUI, or report code.

The witness observation language is deliberately tiny. The result earns only a
new question that can be asked of practical projections.

## Stop condition

Do not continue building abstract Galois machinery merely because the closure
laws are elegant.

The next observation is earned only if a real LOAM report, query, or UI surface
contains a concrete redundancy / distinguishability question where this closure
reading gives a smaller or clearer answer than ordinary dependency reasoning.

If no such practical case appears, keep Observations 159, 179, and 180 as
historical algebraic boundary markers and return to practical relation / budget /
UI work.
