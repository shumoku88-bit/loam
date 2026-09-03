# Observation 136 — Can Capacity authority boundaries remain policy-defined?

## Question

Observations 131–135 progressively removed canonical budget-cycle object families from the selected budget projection:

```text
selector -> ordinary DateRange
DateRange + formula -> base Capacity
base Capacity + timed Capacity adjustments -> Capacity state
```

Observation 135 also distinguished two ordinary query roles:

```text
authority DateRange
view DateRange
```

The next practical question appears when one authority range ends and an adjacent one begins:

> Must previous Capacity reallocations reset, carry, or selectively carry into the next authority, and does answering that question require a canonical Cycle kind?

The hypothesis is that the boundary choice is semantic authority, but it may remain a small policy definition rather than a new household object identity.

## Bounded specimen

Adjacent authority ranges:

```text
Previous [0,2)
Next     [2,4)
```

The next early view is:

```text
[2,3)
```

A fixed formula generates:

```text
Food   10
Travel  4
```

Two adjustments occur in the previous authority:

```text
day 0:
  Food   -2
  Travel +2

day 1:
  Food   +1
  Travel -1
```

One adjustment occurs exactly at the next authority boundary:

```text
day 2:
  Food   +1
  Travel -1
```

Because ranges are half-open, day 2 belongs to the next authority.

## Boundary definitions

The model does not introduce `ResetCycle`, `CarryCycle`, or `PartialCarryCycle` household objects. It uses a tiny definition that says whether a prior adjustment contributes across the selected boundary.

### Reset

Carry no prior adjustment.

Next early result:

```text
Food   11
Travel  3
```

Only the day-2 local adjustment changes the generated base.

### Carry all

Carry both previous adjustments.

The previous net delta is:

```text
Food   -1
Travel +1
```

After also applying day 2:

```text
Food   10
Travel  4
```

### Selective carry

Carry only the day-0 adjustment.

After day 2:

```text
Food    9
Travel  5
```

This is experiment scaffolding for a partial boundary rule. It is not a proposed user-facing policy language.

## Executed result

Alloy 6.2.0 + Sat4j on the PR merge ref against `main`:

```text
resetAndCarryProduceDifferentNextCapacity                SAT
selectiveCarryProducesThirdAnswer                        SAT
boundaryAdjustmentBelongsToNextAuthority                 SAT
equalPolicyDefinitionDifferentIdentitySameAnswer         SAT
RangesFormulaAndTimedAdjustmentsDetermineNextCapacity    SAT counterexample
EveryBoundaryResetsPriorAdjustments                       SAT counterexample
EveryBoundaryCarriesAllPriorAdjustments                   SAT counterexample
BoundaryPolicyDefinitionDeterminesNextCapacity            UNSAT counterexample
BoundaryPoliciesPreserveSelectedTotal                     UNSAT counterexample
```

The expected-result checker passed with the same classification.

## Finding

The bounded evidence establishes that adjacent DateRanges, one formula definition, and the same timed Capacity adjustments do not determine next-authority Capacity by themselves.

The same next range and local day-2 adjustment can yield:

```text
Reset
  Food 11 / Travel 3

Carry all
  Food 10 / Travel 4

Selective
  Food 9 / Travel 5
```

So cross-boundary treatment of earlier Capacity adjustments is independently meaningful authority.

Neither universal rule survives:

```text
every boundary resets
```

nor:

```text
every boundary carries everything
```

But once the boundary policy definition is fixed, Alloy found no bounded counterexample for the selected next-authority Capacity answer:

```text
next authority DateRange
+ selected view DateRange
+ formula definition
+ timed Capacity adjustments
+ boundary policy definition
    -> selected Capacity state
```

An identity-distinct policy with an equal carry definition produced the same selected answer. Policy identity itself is therefore not earned in this specimen once the definition is fixed.

All three bounded policies also preserve the selected total Capacity because every retained adjustment is balanced across Purpose coordinates.

This does not restore a canonical `Cycle` object. `authority` and `view` remain ordinary half-open DateRanges, while boundary semantics remain an explicit deterministic definition supplied as application/query authority.

## Important distinction

A boundary adjustment effective exactly at `next.start` is local to the next half-open authority. It is not carried from the previous authority.

This keeps the DateRange boundary law consistent with Observation 131.

## Qualification

- executable-model head `2b7115a5e81977807f7061fb67305639420b3276`
- executable PR merge ref `6fc3c2a4806e345960ade931a7479439b0f87c8e`
- base `main` `1672e83786b01c71f80d06bb56e03ffa29efe9c1`
- executable-head Observation 136: SUCCESS
- result-note head `616570cf6f6aba5fea750dddf44e28b0c981f95d`: SUCCESS
- final qualification head `9e87af23f873298f4f484b813ed30e1b63756656`: SUCCESS
- final-head solver execution and expected-result checker: SUCCESS

## Boundaries

Observation 136 does not establish:

- a production boundary-policy type or policy DSL;
- that carry decisions should be made per individual historical movement;
- the final user-facing meaning of selective carry;
- automatic pension-date generation;
- a canonical previous/next Cycle relation;
- whether base Capacity itself may carry independently of adjustment deltas;
- savings/reserve semantics;
- Capacity correction semantics;
- Backing interaction;
- historical policy provenance;
- persistence, CLI, TUI, or canonical household-data changes.

The model asks only whether cross-authority carry/reset information is independently observable and whether that information can remain a definition over ordinary DateRanges rather than requiring a new Cycle object family.
