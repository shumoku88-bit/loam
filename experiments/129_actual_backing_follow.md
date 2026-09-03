# Observation 129 — Does Actual spending determine how Backing follows?

Status: qualified bounded Alloy observation

## Question

Observation 128 left a compact candidate for budget mechanics:

```text
Capacity movement coordinate = Purpose
Backing movement coordinate  = Holding x Purpose
```

with shared balanced signed movement mechanics.

That still leaves an important practical question before LOAM grows a Backing writer:

> When an Actual spend reduces a physical Holding and is routed to one budget Purpose, does the Backing allocation follow automatically from that Actual, or is another piece of authority required?

A useful tool should not require a second manual entry after every purchase if the Backing consequence is already determined. But it also should not silently invent a Backing history that the evidence does not determine.

Observation 129 therefore attacks the strongest automatic-follow rule before introducing any production Backing type.

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

The Actual, its spending Holding, its Purpose routing, the prior Backing, the post-Actual holdings, and Remaining are fixed for every post-spend world.

## Why the obvious local rule fails

A tempting automatic rule is:

```text
Actual spends 1 from Bank for Food
    ->
Bank x Food Backing decreases by 1
```

But the specimen begins with:

```text
Bank x Food Backing = 0
```

so the local rule would require `-1` Backing.

Alloy confirms that the candidate `samePurposeLocalAutoFollowAdmissible` is UNSAT in this fixed household state. The Actual itself is ordinary; what fails is the attempted universal coupling law.

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

Every remaining physical unit is still assigned, but:

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

Both post-spend worlds are physically admissible and fully assign exactly the same post-Actual holdings.

## Executed result

Alloy 6.2.0 + Sat4j:

```text
twoValidBackingResponsesSameActual                    SAT
sameActualDifferentBudgetGap                           SAT
globalRebalanceCanRestoreCoverage                      SAT
samePurposeLocalAutoFollowAdmissible                    UNSAT
inhabitedPostBackingCopy                               SAT
ActualAndPriorBackingDeterminePostBacking              SAT counterexample
ActualAndPriorBackingDetermineBudgetGap                SAT counterexample
ExplicitPostBackingDeterminesSelectedProjection        UNSAT counterexample
```

The complete expected result set passed in CI on the PR merge ref against `main`.

## Finding

The strong automatic-follow hypothesis is false in the bounded specimen:

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

The selected separation is:

```text
Actual consumption
    !=
Backing evolution
```

The counterexample is not caused by unassigned money. Every post-spend Holding unit is assigned in both worlds. The difference is the household choice about whether and how to rebalance support across `(Holding, Purpose)` coordinates.

Once the post-spend Backing allocation itself is fixed, Alloy finds no bounded counterexample for the selected `Backed / FundedRemaining / Gap` projection. `Rebalanced` and `CopyRebalanced` keep this sufficiency check inhabited.

## What this does not force

This result does **not** prove that every purchase needs a second manual Backing entry.

A smaller implementation remains possible:

```text
prior Backing
+ Actual / routing
+ explicit deterministic Backing policy
    -> post Backing
```

For example, a policy could automatically preserve coverage when possible, prefer the spending Holding, or expose a choice only when several admissible responses remain.

But such a policy would be additional authority. It cannot be presented as something already contained in the Actual evidence.

Another possibility is that Backing remains replaceable current allocation rather than durable historical evidence if later household questions never need historical Backing provenance. Observation 129 does not decide that question.

## Practical product consequence

A future budget UI can still make ordinary spending nearly frictionless. The result only says the convenience layer must know when it is applying policy rather than merely replaying evidence.

For example:

```text
Pay 1 from Bank for Food
```

may automatically update the budget under a selected policy in the common case, while an ambiguous or policy-sensitive case can be surfaced rather than silently forging one canonical history.

This preserves the product goal:

```text
simple operation for the user
small retained vocabulary underneath
no duplicate EnvelopeBalance / Gap truth
```

without pretending that Actual and Backing are the same authority.

## Boundaries

Observation 129 does not establish:

- a production Backing writer;
- that every spend needs a separate manual Backing entry;
- a Backing policy type;
- which automatic rebalancing policy is desirable;
- historical Backing persistence;
- whether Backing is current policy, durable evidence, or reconstructible from finer evidence;
- credit / liabilities / negative holdings;
- multi-Measure valuation;
- ownership / Agent semantics;
- Practical Core, persistence, CLI, or canonical household-data changes.

The qualified result is only that Actual spending and Purpose routing do not uniquely determine the Backing response in the selected bounded household state.
