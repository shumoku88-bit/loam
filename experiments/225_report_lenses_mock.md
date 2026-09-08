# Observation 225 — Can a small verified report algebra expose distinct household dynamics?

Status: **MOCK COMPARISON; MATHEMATICAL PRESSURE IDENTIFIED; NO PRODUCTION REPORT ENGINE**

Research starting point:

- LOAM `cb59fde977ddadf71b6227c3d046396909a2d71e`
- Observation 110 already qualified double-entry closure as a derived accounting view over signed Effects rather than Core debit/credit ontology.
- Observation 221 already rejected a generic household `Coverage` ontology.
- Observation 224 classified zero-origin completeness, observed-state evidence, overlap evidence, and import identity as distinct entry concerns.

## Question

The production TUI is growing in parallel. Before choosing a conventional report menu, ask a different question:

> Can a very small number of reports expose substantially different ways of understanding household money, and can the nontrivial calculations live in a dedicated verified analytical layer without becoming a second canonical semantic engine?

The immediate candidates are:

1. **Stock–Flow Bridge** — why did the tracked holdings change?
2. **Liquidity Ladder** — where is the future low-water mark within the known horizon?
3. **Effect / Transactions-Flow Matrix** — how does a whole period close as a system rather than as isolated transactions?
4. ordinary balance / expense / scheduled lists as a control surface.

This observation is deliberately a mock. It does not add production report types, persistence, CLI, TUI state, Mathlib, probability distributions, valuation semantics, or optimization policy.

## External pressure

### Stock-flow consistent accounting

Godley/Lavoie-style stock-flow consistent models use balance-sheet and transactions-flow matrices to make sure that stocks and flows agree and that every represented flow has a counterpart. The relevant pressure for LOAM is not macroeconomic sector ontology. It is the mathematical discipline:

```text
stock at later boundary
=
stock at earlier boundary
+
net represented flows between the boundaries
```

and the ability to inspect closure across a matrix rather than only one transaction at a time.

### Liquidity gap / maturity ladder

Liquidity management uses dated inflows and outflows, cumulative gaps, and time buckets to expose a low point that a current balance alone cannot show.

The relevant pressure for LOAM is:

```text
current liquid quantity
+
prefix sum of known future flows
->
future path over the qualified horizon
```

The report must not extend a numeric path beyond the evidence horizon merely because a UI wants a smooth line.

### First-passage / ruin theory

Risk theory studies the first time a reserve process crosses a harmful boundary and, with a stochastic model, the probability and severity of ruin.

LOAM is **not** ready to claim a stochastic household process. But the deterministic precursor already matters:

```text
known future path
-> minimum prefix quantity
-> date of minimum

policy threshold, if separately supplied
-> first known threshold crossing
```

This is a natural mathematical extension of a liquidity ladder, not a reason to add probabilities now.

## Synthetic household specimen

All values below are exact JPY quantities. The specimen is intentionally small enough to inspect by eye.

The starting values are report-boundary inputs. They are not proposed as new canonical starting-balance facts and this mock does not choose their origin evidence.

### Opening tracked holdings

```text
cash        8,000
paypay     12,000
smbc      100,000
investment 40,000
------------------
total     160,000
```

### Period Movements

Every selected practical Movement is balanced as signed Effects in this specimen.

```text
M1 income received
  smbc            +120,000
  pension-income  -120,000

M2 food purchase
  smbc             -12,000
  food             +12,000

M3 books purchase
  paypay            -5,000
  books             +5,000

M4 internal funding transfer
  smbc             -20,000
  paypay           +20,000

M5 move quantity into investment holding
  smbc             -10,000
  investment       +10,000

M6 food refund
  paypay            +2,000
  food              -2,000
```

Each row sums to exact zero.

### Closing tracked holdings

```text
cash        8,000
paypay     29,000
smbc      178,000
investment 50,000
------------------
total     265,000
```

Tracked holdings therefore changed by:

```text
+105,000
```

The non-holding period totals are:

```text
pension-income  -120,000
food             +10,000
books             +5,000
-------------------------
net              -105,000
```

The complete selected Movement world still closes:

```text
holding delta +105,000
+
non-holding delta -105,000
=
0
```

## Mock 0 — ordinary control reports

### Balances

```text
BALANCES

smbc        ¥178,000
investment   ¥50,000
paypay       ¥29,000
cash          ¥8,000
-------------------
tracked     ¥265,000
```

### Expense-like uses

```text
USES

food         ¥10,000
books         ¥5,000
-------------------
             ¥15,000
```

### Upcoming known items

```text
UPCOMING

Sep 10  rent          -¥70,000
Sep 12  income       +¥120,000
Sep 15  phone          -¥8,000
Sep 20  card          -¥60,000
```

These are useful controls. But they leave three questions scattered:

```text
Why did tracked holdings become ¥265,000?
Where is the lowest known future liquid point?
How did the period close as one conserved system?
```

## Mock 1 — Stock–Flow Bridge

The first report treats holdings as a stock and selected period effects as the changes that bridge two boundaries.

```text
STOCK–FLOW BRIDGE
Tracked holdings · JPY

Opening                                      ¥160,000
                                              │
External source effects                      +120,000
  pension-income                 +120,000     │
                                              │
Household-use effects                         -15,000
  food                             -10,000     │
  books                             -5,000     │
                                              │
Internal reallocations                           ¥0
  smbc -> paypay                    20,000     │  no total-holding change
  smbc -> investment                10,000     │  no total-holding change
                                              ▼
Closing                                      ¥265,000

Net change                                   +¥105,000
```

The arrows in the explanatory labels above are human shorthand only. The report calculation does **not** require LOAM to infer pairwise source→destination edges from a multi-Effect Event. For this specimen the two internal Movements happen to have exactly two Effects and are unambiguous to a human, but that shape must not become a universal report assumption.

A safer computation is only:

```text
opening selected holding quantity
+
sum(period Effects projected to selected holding coordinates)
=
closing selected holding quantity
```

The bridge teaches a distinction the balance report does not:

```text
ending quantity
!=
period gain
```

and another distinction the expense list does not:

```text
holding reallocation
!=
household use
```

For this exact specimen:

```text
160,000 + 105,000 = 265,000
```

No valuation gain, market-price change, depreciation, accrual recognition, or inflation adjustment is asserted. Those would require additional evidence/semantics and must not be smuggled into the bridge as a fake zero-valued component.

## Mock 2 — Liquidity Ladder

For this mock, liquid holdings are the selected set:

```text
cash + paypay + smbc
```

Investment is deliberately excluded by the report selection. That selection is not Core ontology.

Current liquid quantity after the historical period:

```text
cash     8,000
paypay  29,000
smbc   178,000
--------------
       215,000
```

Synthetic Scheduled evidence is qualified only through **Sep 20**:

```text
Sep 10  rent          -70,000
Sep 12  income       +120,000
Sep 15  phone          -8,000
Sep 20  card          -60,000
```

The cumulative report is:

```text
LIQUIDITY LADDER
Known scheduled path through Sep 20

now     start                         ¥215,000
Sep 10  rent             -¥70,000     ¥145,000  ◀ lowest known point
Sep 12  income          +¥120,000     ¥265,000
Sep 15  phone             -¥8,000     ¥257,000
Sep 20  card             -¥60,000     ¥197,000
─────────────────────────────────────────────
after Sep 20                           UNKNOWN
                                      evidence horizon ends
```

The report exposes information absent from both current balances and the Scheduled list:

```text
minimum known future liquid quantity = ¥145,000
minimum known date                   = Sep 10
```

But it refuses a stronger claim:

```text
"the household will never fall below ¥145,000"
```

because the Scheduled world is not known complete after Sep 20.

This is the report-level use of:

```text
Unknown != zero
```

A smooth chart continuing beyond Sep 20 at ¥197,000 would be visually attractive and semantically false.

### Threshold extension, not yet production meaning

If a future report receives an explicit policy threshold, e.g.:

```text
minimum desired liquid reserve = ¥100,000
```

then it may derive within the known horizon:

```text
known minimum margin = ¥45,000
first known crossing = none through Sep 20
```

The threshold must be supplied as policy/evidence. It is not inferred from balances.

## Mock 3 — Effect / Transactions-Flow Matrix

A Sankey-style graph is tempting, but a multi-Effect Movement does not in general identify pairwise source→destination edges.

A matrix can stay closer to the evidence.

```text
EFFECT MATRIX · JPY

              cash  paypay    smbc  invest   income    food   books   row Σ
M1 income        0       0 +120000       0  -120000       0       0       0
M2 food          0       0  -12000       0        0  +12000       0       0
M3 books         0   -5000       0       0        0       0   +5000       0
M4 transfer      0  +20000  -20000       0        0       0       0       0
M5 invest        0       0  -10000  +10000        0       0       0       0
M6 refund        0   +2000       0       0        0   -2000       0       0
────────────────────────────────────────────────────────────────────────────
column Σ         0  +17000  +78000  +10000  -120000  +10000   +5000       0
```

Two different invariants become visible at once.

### Row closure

For every admitted Movement in this specimen:

```text
row sum = 0
```

This is the familiar double-entry/conservation check recovered from signed Effects, consistent with Observation 110.

### Column accumulation

The column sums are the period quantity deltas per Locus:

```text
paypay      +17,000
smbc        +78,000
investment  +10,000
income     -120,000
food        +10,000
books        +5,000
```

The holding columns sum to:

```text
+105,000
```

and the non-holding columns sum to:

```text
-105,000
```

So the period can be read as one closed surface rather than six unrelated records.

### Aggregated two-block view

A further report projection may aggregate the columns into a selected `holding` block and its selected complement:

```text
              holdings   non-holdings   total
M1 income     +120,000       -120,000       0
M2 food        -12,000        +12,000       0
M3 books        -5,000         +5,000       0
M4 transfer          0              0       0
M5 invest            0              0       0
M6 refund       +2,000         -2,000       0
─────────────────────────────────────────────
period         +105,000       -105,000       0
```

This is surprisingly information-dense:

- income-like effects expand holdings;
- use-like effects contract holdings;
- internal reallocations disappear from the aggregate holding delta;
- refunds reverse part of a prior use without pretending the original occurrence never happened;
- total closure remains visible.

The aggregation requires an explicit selection/classification boundary. It must not infer accounting meaning merely from sign.

## What the three mocks teach differently

```text
Stock–Flow Bridge
  asks: why did the stock change between boundaries?

Liquidity Ladder
  asks: where does the known future path become thinnest?

Effect Matrix
  asks: how does the period close as one system?
```

They are not three skins over one report.

A current-balance list cannot reconstruct the period matrix.
A period matrix without Scheduled timing cannot locate a future low-water date.
A Scheduled list without an opening liquid quantity cannot produce a liquidity path.

The selected report questions therefore observe different retained information.

## Candidate mathematical layer

The mocks suggest that a report engine can be mathematically substantial without becoming a competing source of truth.

A useful architecture would be:

```text
canonical evidence
      │
      ▼
shared Application read boundaries
      │
      ▼
Report Input
  typed, finite, explicit evidence
      │
      ▼
Verified Report Algebra
  pure calculations + theorems
      │
      ▼
Report Answers
  stocks / bridges / paths / matrices / witnesses
      │
      ▼
TUI / CLI / export rendering
```

The report algebra must not:

- read canonical files directly;
- invent missing completeness;
- write canonical evidence;
- repair malformed evidence;
- infer pairwise transfers that the input does not contain;
- turn presentation selection into Core meaning;
- silently convert unknown future facts into zeros;
- become a second EventCorrection, Scheduled, or quantity frontier implementation.

A **second calculator** is not the same thing as a **second semantic engine**.

The former is acceptable if every input comes through a shared semantic boundary and every output is a proved derived answer.

## Mathematical structure 1 — finite signed quantity vectors

For one Measure, a report period can be viewed as finitely supported signed quantities over coordinates:

```text
EffectCoordinate ->₀ ℤ
```

or an equivalent small sparse representation.

Each selected practical Movement contributes a finite vector.

Period accumulation is vector addition:

```text
periodDelta = Σ movementVector
```

A report selection/aggregation is a map from one finite coordinate space to another.

The important report laws are not exotic formulas. They are compositional guarantees such as:

```text
project (Σ movements)
=
Σ (project movement)
```

and:

```text
closing
=
opening + periodDelta
```

when the opening/closing question is qualified for the same selected coordinate set and period.

This is precisely where Lean can turn an implementation detail into a reusable theorem.

### Free-abelian-group intuition

Signed Effects naturally suggest a free additive structure over coordinates:

```text
formal finite integer combinations of coordinates
```

The report layer does not need to rename the Core around that mathematics. It can simply exploit the algebra when proving projections and aggregations.

## Mathematical structure 2 — matrices and linear maps

The Effect Matrix is a finite matrix:

```text
Movement × Coordinate -> ℤ
```

Useful identities include:

```text
row sums      -> per-Movement closure witness
column sums   -> per-coordinate period delta
block sums    -> selected aggregate deltas
```

An aggregation can be represented mathematically as a linear/additive map.

That makes several desirable commute diagrams testable:

```text
raw Movements ──sum──> period vector
     │                    │
   project              project
     │                    │
     ▼                    ▼
projected rows ─sum──> projected period vector
```

If both paths are supposed to answer the same question, Lean can prove that they commute rather than relying on duplicate test fixtures forever.

Observation 110 already anticipated this kind of composition/commutation pressure without promoting category-theory vocabulary into production Core.

## Mathematical structure 3 — discrete integration over time

The Liquidity Ladder is mathematically a prefix-sum operator.

Let:

```text
B0 = current liquid quantity
f1, f2, ..., fn = ordered known scheduled net flows
```

Then:

```text
Bk = B0 + Σ(i <= k) fi
```

This is a discrete stock/flow relation:

```text
flow   ~ finite difference
stock  ~ discrete integral of flow
```

That is genuinely close to a conservation equation in physics: changes in stored quantity are explained by represented inflows/outflows.

Useful verified answers are:

```text
path             = [B0, B1, ..., Bn]
minimum          = min path
argmin           = first/selected date attaining minimum
```

If completeness is qualified only through horizon `H`, the theorem contract should stop at `H`.

```text
exact prefix path through H
-/-> exact path after H
```

## Mathematical structure 4 — information order before probability

Future finance invites probability very quickly. LOAM should resist fake precision.

Before stochastic models, there is already useful order structure:

```text
unknown
  < more constrained scenario set
  < exact known future value
```

or other question-specific information orders.

This can support future report answers such as:

```text
exact known path through H
scenario envelope after H
unknown beyond another boundary
```

without pretending one guessed forecast is truth.

Observation 221 remains a warning: a useful order pattern does not automatically earn one global `Coverage` or `Knowledge` ontology.

## Mathematical structure 5 — scenario envelopes

A later experiment could accept several explicitly named scenarios rather than probabilities:

```text
baseline
high-utilities
unexpected-medical-cost
income-delay
```

Each scenario is simply another flow path.

Then the report can derive:

```text
per-date minimum across scenarios
per-date maximum across scenarios
worst low-water point
first threshold crossing per scenario
```

This is robust/scenario analysis without a probability distribution.

Only if empirical or declared probabilistic evidence is later introduced should LOAM ask for Monte Carlo, stochastic processes, ruin probabilities, VaR-like quantities, or expected utility.

## Mathematical structure 6 — first passage, later

Given an explicit threshold `L` and an exact or scenario path `B(t)`, define:

```text
firstPassage(L)
=
first t where B(t) < L
```

For an exact known Scheduled path this is deterministic.

For a family of scenarios it becomes a set/family of crossing times.

For a genuinely stochastic process it can become a random variable and lead toward ruin theory.

The order matters:

```text
exact evidence
-> deterministic prefix path
-> scenario family
-> only then probabilistic process, if earned
```

## Where advanced Lean mathematics may help

The current `lakefile.lean` has no Mathlib dependency. That is a useful constraint, not a permanent ban.

If the report experiments earn enough pressure, Mathlib already has relevant machinery such as:

- finitely supported functions (`Finsupp`);
- finite sums;
- matrices and linear algebra;
- additive / linear maps;
- order and lattice structures;
- probability and measure theory if that future boundary is ever earned.

But importing a large mathematical dependency merely to render three tables would be backwards.

A better sequence is:

```text
1. mock reports
2. identify reusable laws
3. write the smallest executable Lean probe
4. measure whether existing Lean/Core structures are sufficient
5. only then run a Mathlib dependency spike if the proofs become materially smaller/clearer
```

The selection criterion should be conceptual compression and theorem reuse, not mathematical impressiveness.

## Candidate production boundary if the research survives

Do not add this yet. A future shape might look like:

```text
Loam/Report/
  Input.lean
  QuantityVector.lean
  StockFlow.lean
  Liquidity.lean
  EffectMatrix.lean
  Scenario.lean          -- only if later earned
```

with presentation elsewhere:

```text
Loam/Tui/Reports/...
Loam/Cli/Reports/...
```

The important dependency direction is:

```text
Core / Application
      ↓
Report calculations
      ↓
TUI / CLI rendering
```

never:

```text
TUI state -> repair Report semantics -> invent canonical meaning
```

## Mock comparison result

The three candidate reports survive the first paper mock because each exposes a different invariant or temporal fact from the same small household specimen.

### Stock–Flow Bridge survives

It compresses opening quantity, net period change, and closing quantity into one causal accounting bridge without requiring new canonical facts.

### Liquidity Ladder survives

It exposes the low-water point and evidence horizon, neither of which is visible in a current balance or plain Scheduled list.

### Effect Matrix survives

It exposes row closure, coordinate accumulation, and selected aggregate closure without inventing pairwise flow edges.

### Conventional controls remain useful

Balances, use summaries, and Upcoming lists are still useful as direct lookup surfaces. The mock does not replace them. It shows that they are not the whole report vocabulary.

## Strongest emerging hypothesis

The most promising shared mathematical shape is not one giant `Report` ontology.

It is:

```text
finite signed evidence
+
explicit projection
+
composition laws
+
ordered prefix accumulation where time is relevant
+
question-specific completeness boundary
```

From those few operations, several information-dense reports may be derivable.

This is a plausible place for a dedicated verified calculation layer because the value of the layer would come from proving that different computation paths agree and that reports refuse claims outside their evidence boundary.

## What would falsify the idea

A dedicated mathematical report layer should be rejected or kept trivial if later prototypes show any of the following:

1. each report requires unrelated semantic classifications and shares almost no reusable algebra;
2. the mathematical abstraction is larger than direct transparent calculations;
3. TUI/report needs repeatedly force the layer to reconstruct canonical Event/Scheduled/correction semantics;
4. useful reports require unrecorded pairwise transaction edges or fabricated chronology;
5. the same report cannot explain its answer back to concrete source evidence;
6. advanced mathematics mainly hides simple household arithmetic rather than making laws explicit.

## Next executable probes

The next step should remain synthetic and cheap.

### Probe A — Stock/flow commutation

In Lean, prove for a finite Movement specimen:

```text
project (sum movements)
=
sum (map project movements)
```

and derive opening + delta = closing.

### Probe B — Matrix equivalence

Show that matrix column sums equal the ordinary period quantity projection for the same Effects.

This guards against a report-specific second quantity engine.

### Probe C — Liquidity prefix law

Show that every adjacent liquidity point satisfies:

```text
B(k+1) = B(k) + flow(k+1)
```

and that the reported minimum is a member of the exact prefix path.

### Probe D — Horizon negative control

Construct two future worlds identical through the known-through horizon and different after it.

The report must give the same exact path through the horizon and must not claim the same path after it.

### Probe E — no invented pairwise edges

Construct one balanced multi-Effect Movement with at least two negative and two positive Effects.

Two different pairwise Sankey decompositions should fit the same retained Effects.

Therefore an Effect Matrix is determined while a pairwise flow graph is not.

## Non-goals

Observation 225 does not establish:

- a final production report set;
- a production `Report` root abstraction;
- a generic time-series engine;
- a canonical holding / liquid / expense ontology;
- valuation, depreciation, market prices, recognition time, or accrual accounting;
- a probabilistic household model;
- a household risk tolerance threshold;
- Monte Carlo simulation;
- stochastic control or automatic spending optimization;
- a generic information lattice in Core;
- a Mathlib dependency;
- pairwise flow edges for arbitrary Movements;
- that every Core Event is balanced;
- that advanced mathematics is useful merely because it exists.

The mock only identifies a promising boundary where mathematically verified derived reports may create more understanding per report while leaving canonical household semantics in the existing shared evidence/read layers.

## External references used for pressure

- Wynne Godley / Marc Lavoie stock-flow consistent work and transactions-flow matrices, Levy Economics Institute.
- Basel Committee liquidity gap / maturity ladder guidance, Bank for International Settlements.
- Classical and modern ruin / first-passage literature as future mathematical pressure, not current LOAM semantics.
- Mathlib documentation for finite support, linear algebra, order/lattice, and related formal machinery.
