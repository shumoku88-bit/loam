# Observation 233 — Can a Transactions-Flow Matrix expose household movement without inventing source/destination edges?

Status: **QUALIFIED MECHANICAL SEMANTICS — incidence matrix survives / RESEARCH_ONLY**

Research baseline: LOAM `8e7f85c0c0607e8d63cf484914207fa77d5c2330`

Qualified Lean head: `fd9d40e751310f85412dd1d3b2a70c9151632366`

Dedicated workflow: Observation 233 run `34320355132`, job `102365393440`, **SUCCESS**.

## Trigger

The current Reports surface already has a Stock–Flow reconstruction and a conditional Liquidity path. The remaining candidate from the Report Semantics backlog is a Transactions-Flow Matrix intended to answer:

> During one period, what changed across the household system as a whole?

A tempting representation is a Locus-to-Locus flow matrix or Sankey-style source/destination graph. That representation is not generally justified by LOAM's canonical Event evidence.

A three-posting Event such as:

```text
cash  -1000 jpy
food    600 jpy
book    400 jpy
```

does not contain two canonical edges `cash -> food` and `cash -> book`. It contains three signed Effects. Core also states that Effect list order carries no temporal, causal, debit/credit, or posting-order meaning.

Observation 233 therefore asks for a smaller representation that preserves the canonical evidence exactly without creating pairings that are not there.

## Candidate

Use an incidence matrix:

```text
row    = EffectCoordinate = (LocusId, MeasureId)
column = Event
cell   = exact signed Quantity at that coordinate in that Event
```

The Measure coordinate is part of the row. A bare `Locus × Event` matrix would be too weak because independent Measures must not be silently summed.

The candidate intentionally has no:

```text
source Locus
recipient Locus
edge
transfer pair
posting order
```

Those concepts cannot therefore leak into the result by accident.

## Selected witnesses

The Lean probe contains four deliberately different Events.

### 1. Three-posting balanced Event

```text
cash/jpy  -1000
food/jpy    600
book/jpy    400
```

This is the key anti-pairing witness. The matrix exposes all three Effects while refusing to say which positive posting is the destination of which negative posting.

### 2. Neutral Core Event with a nonzero residual

```text
income/jpy  +500
```

Practical Movement admission requires balanced JPY, but that is an entrance contract rather than a universal Core Event law. The matrix retains this Event and exposes a `+500 jpy` residual instead of rejecting it or silently manufacturing a balancing row.

### 3. Multi-Measure Event

```text
cash/jpy    -100
food/jpy     100
point/point    3
```

The JPY residual is zero while the point residual is +3. Summing these into one scalar residual would be dimensionally unjustified. Observation 233 therefore calculates residuals per Measure.

### 4. Repeated coordinate with distinct Effect identity

```text
cash/jpy       -500
food/jpy        200
food/jpy        300
```

Core permits distinct Effect keys at one `(LocusId, MeasureId)` coordinate. A matrix cell aggregates those Effects to `food/jpy = 500` without claiming that their Effect identities were the same.

## Selected matrix

The exact witness matrix is:

```text
                         split   unbalanced   mixed   repeated
cash/jpy                 -1000       0        -100      -500
food/jpy                   600       0         100       500
book/jpy                   400       0           0         0
income/jpy                   0     500           0         0
point/point                  0       0           3         0
```

Useful derived observations are then small and explicit.

### Row total

For one exact coordinate:

```text
rowTotal coordinate events
```

is the selected-period net change at that coordinate.

For the selected witnesses:

```text
food/jpy = 600 + 0 + 100 + 500 = 1200
```

This is a quantity fact, not an expense classification or Purpose claim.

### Column residual by Measure

For one Event and one Measure:

```text
measureResidual measure event
```

sums only Effects in that Measure.

The selected witnesses produce:

```text
split/jpy       = 0
unbalanced/jpy  = 500
mixed/jpy       = 0
mixed/point     = 3
repeated/jpy    = 0
```

A zero residual is observed conservation. It is not imposed as a global invariant on Core Event.

## Executed result

The dedicated Observation 233 workflow compiled the exact Lean probe successfully.

Mechanically established for the selected witnesses:

```text
three-posting Event             preserved without pairwise edges
non-balanced Core Event         retained with visible +500 JPY residual
multi-Measure Event             JPY residual 0 / point residual +3
same-coordinate Effect keys     aggregate to one cell quantity
row total                       exact additive coordinate change
Effect permutation              cell invariant by Event.quantityAt_perm
```

The initial hypothesis therefore survives: a Transactions-Flow Matrix does not need a Locus-to-Locus flow relation in order to expose system-wide structure.

## Mechanical laws in the Lean probe

The experiment checks:

```text
cell coordinate event
  = Event.quantityAt event coordinate.locus coordinate.measure

Effect permutation
  does not change a cell

row total
  is exact additive change over selected Event columns

same-coordinate distinct Effects
  aggregate in the cell without losing the underlying Event representation

nonzero Event/Measure residual
  remains visible

independent Measures
  retain independent residuals
```

The permutation result reuses Core's existing `Event.quantityAt_perm` theorem rather than proving a second matrix-specific posting-order semantics.

## What this can show

The qualified matrix can safely support questions such as:

- Which coordinates changed during the selected period?
- Which Events contributed to a coordinate's net change?
- Which Events exhibit zero-sum structure within a Measure?
- Where does retained evidence contain a nonzero residual?
- How do multi-posting Events appear as a whole rather than as invented pairwise transfers?

It may also provide a useful microscopic view beneath Stock–Flow reconstruction. Stock–Flow collapses a selected set of coordinates across time; this matrix keeps the Event dimension visible.

## What this cannot show by itself

The incidence matrix does **not** justify:

- `cash -> food` or any other pairwise source/destination relation;
- Sankey edges;
- transfer classification;
- income, expense, saving, acquisition, or valuation interpretation;
- accounting debit/credit direction;
- Purpose routing;
- chronological ordering from Event list position;
- a universal conservation law;
- addition across distinct Measures.

Some later projection may combine explicit AccountingRole, Routing, or other evidence with the matrix. That would be a separate qualified report question, not hidden semantics inside this primitive.

## Promotion gate

Do not add a production `TransactionsFlowReview` or TUI report merely because this probe compiles.

A production candidate must first show that it provides human understanding beyond an ordinary journal while retaining these constraints:

```text
no invented pairings
+ correction-aware current Event frontier
+ explicit time window
+ Measure separation
+ visible residuals
+ no second semantic engine
```

The next step after this mechanical qualification is therefore a small household-shaped read experiment against current Actual records, not a production surface.

## Non-claims

Observation 233 does not authorize:

- a Locus-to-Locus flow graph;
- a Sankey diagram;
- a new Core matrix ontology;
- a new persistence format;
- a writer;
- a new balance rule for Event;
- accounting classification inferred from sign or spelling;
- promotion into Reports before household dogfood demonstrates new explanatory value.
