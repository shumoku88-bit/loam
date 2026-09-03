# Observation 129 — Does Actual spending determine how Backing follows?

## Question

Observation 128 left a compact candidate for budget mechanics:

```text
Capacity movement coordinate = Purpose
Backing movement coordinate  = Holding x Purpose
```

with shared balanced signed movement mechanics.

That still leaves an important practical question before LOAM grows a Backing writer:

> When an Actual spend reduces a physical Holding and is routed to one budget Purpose, does the Backing allocation follow automatically from that Actual, or is another piece of authority required?

This matters directly for ordinary envelope-style use. A useful tool should not require a second manual entry after every purchase if the Backing consequence is already determined. But it also should not silently invent a Backing history that the evidence does not determine.

Observation 129 therefore tries to refute the strongest automatic-follow rule before introducing any production Backing type.

## Fixed household specimen

Before the spend:

```text
Holdings
  Bank = 4
  Cash = 6

Capacity
  Food   = 6
  Travel = 4

Backing
  Bank -> Food   0
  Bank -> Travel 4

  Cash -> Food   6
  Cash -> Travel 0
```

All physical quantity is assigned as Backing.

Now one ordinary Actual happens:

```text
spend 1
from Holding: Bank
routed Purpose: Food
```

After that Actual:

```text
Holdings
  Bank = 3
  Cash = 6

Consumption
  Food = 1

Remaining
  Food   = 5
  Travel = 4
```

The Actual, its spending Holding, and its Purpose routing are fixed in every post-spend world.

## Why the obvious local rule is under pressure

A tempting rule is:

```text
Actual spends 1 from Bank for Food
    ->
Bank x Food Backing decreases by 1
```

But this specimen begins with:

```text
Bank x Food Backing = 0
```

so the local rule would require `-1` Backing.

The Actual itself is still perfectly ordinary. Therefore any general rule that says spending must always consume Backing from exactly the same `(Holding, Purpose)` coordinate is too strong for this household state.

## Two admissible Backing responses

### ReleaseTravel

Make only the minimum physical response to Bank losing one unit:

```text
Bank
  Food   0
  Travel 3

Cash
  Food   6
  Travel 0
```

Every remaining physical unit is still assigned, but the selected budget projection is:

```text
Food   Remaining 5, Backed 6, Gap 0
Travel Remaining 4, Backed 3, Gap 1
```

### Rebalanced

Use the same Actual but also move one Cash unit of Backing from Food to Travel:

```text
Bank
  Food   0
  Travel 3

Cash
  Food   5
  Travel 1
```

Now:

```text
Food   Remaining 5, Backed 5, Gap 0
Travel Remaining 4, Backed 4, Gap 0
```

Both post-spend worlds are physically admissible and fully assign the same post-Actual holdings. They differ only in how Backing is allowed to respond.

## Qualification target

Expected witnesses:

```text
twoValidBackingResponsesSameActual       SAT
sameActualDifferentBudgetGap              SAT
globalRebalanceCanRestoreCoverage         SAT
inhabitedPostBackingCopy                   SAT
```

The naive local same-purpose auto-follow candidate should be impossible in this fixed specimen:

```text
samePurposeLocalAutoFollowAdmissible       UNSAT
```

Expected counterexamples to automatic derivation:

```text
ActualAndPriorBackingDeterminePostBacking  SAT counterexample
ActualAndPriorBackingDetermineBudgetGap    SAT counterexample
```

Once the post-spend Backing allocation itself is fixed:

```text
ExplicitPostBackingDeterminesSelectedProjection  UNSAT counterexample
```

## What would the expected result mean?

If qualified, the strong rule fails:

```text
Actual
+ spending Holding
+ Purpose routing
+ prior Backing
+ post-Actual holdings
+ Remaining

    do not determine

post-Actual Backing allocation
```

and therefore do not determine every Backing / Gap answer.

The useful separation would be:

```text
Actual consumption
    !=
Backing evolution
```

But that would **not** yet prove that LOAM must persist a new Backing movement for every spend.

Another smaller design remains possible:

```text
prior Backing
+ Actual / routing
+ explicit deterministic Backing policy
    -> post Backing
```

or Backing may remain a replaceable current allocation if historical Backing questions never require durable provenance.

Those are later questions. Observation 129 only tests whether Actual evidence by itself supplies the missing choice.

## Practical product consequence if qualified

A future budget UI should not silently assume that this operation:

```text
Pay 1 from Bank for Food
```

has exactly one Backing interpretation in every household state.

A practical system may still make the common case effortless. For example it could apply an explicit policy, or prompt only when the automatic candidate is underdetermined or inadmissible.

The important constraint is that convenience should not be mistaken for canonical evidence.

## Boundaries

Observation 129 does not establish:

- a production Backing writer;
- that every spend needs a separate manual Backing entry;
- a Backing policy type;
- automatic rebalancing priorities;
- historical Backing persistence;
- whether Backing is current policy, durable evidence, or reconstructible from finer evidence;
- credit / liabilities / negative holdings;
- multi-Measure valuation;
- ownership / Agent semantics;
- Practical Core, persistence, CLI, or canonical household-data changes.

The question is only whether Actual spending and Purpose routing uniquely determine the Backing response in the selected bounded household state.
