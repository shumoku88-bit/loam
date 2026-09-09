# Observation 234 — Can the incidence matrix reuse the correction-aware Actual review boundary?

Status: **QUALIFIED REUSE BOUNDARY — ActualReview is sufficient / RESEARCH_ONLY**

Research baseline: LOAM `aea7368e183c8c0189b4a0cba6acfd11b6bbdde9`

Qualified Lean head: `b2472401c516351cd3695d1822a81739a640b467`

Dedicated workflow: Observation 234 run `34320982254`, job `102367324748`, **SUCCESS**.

## Trigger

Observation 233 qualified a mechanically safe matrix shape:

```text
EffectCoordinate × Event -> Quantity
```

with no Locus-to-Locus pairing, per-Measure separation, and visible Event/Measure residuals.

The next question is whether a household report would require a new semantic engine to choose the Event columns, or whether it can reuse the existing `ActualReview.Record` answer.

`ActualReview.Record` already carries:

```text
Event
occurrence date
human description
replacement link
isCurrent
```

and is produced from the correction-aware current Event frontier plus admitted Actual validity evidence.

Observation 234 asks only:

> Can one explicit half-open period matrix be a pure projection over that existing review answer?

## Candidate boundary

The experiment-local projection takes:

```text
List ActualReview.Record
start
endExclusive
```

and derives:

```text
current dated columns inside [start, endExclusive)
×
distinct EffectCoordinate rows represented by those columns
```

No new canonical reader is introduced.

## Refusal rule

A current quantity-bearing Event with no valid occurrence date refuses the matrix.

That refusal is necessary because the Event cannot safely be placed either inside or outside an explicit time window.

A superseded undated Event does not block the matrix because `isCurrent = false` already says it is not part of the correction-aware current frontier.

An empty current Event with no quantity Effects also does not block the quantity matrix because it contributes no matrix coordinate or cell.

## Household-shaped witness

The probe deliberately supplies Actual review records in non-chronological representation order.

Current selected Events:

```text
2026-09-05 replacement
  paypay/jpy  -1000
  food/jpy      600
  book/jpy      400

2026-09-15 later
  smbc/jpy    -2470
  book/jpy     2470
```

Also retained in the supplied review list:

```text
2026-09-04 original       superseded, contains food +9999
2026-08-31 before         current but before window
2026-10-01 after          current at exclusive end boundary
```

For `[2026-09-01, 2026-10-01)` the expected matrix is therefore:

```text
                 replacement   later
book/jpy              400       2470
food/jpy              600          0
paypay/jpy          -1000          0
smbc/jpy                0      -2470
```

Expected row totals:

```text
book/jpy    +2870
food/jpy     +600
paypay/jpy  -1000
smbc/jpy    -2470
```

The superseded `food +9999` must not leak into the answer.

## Ordering

Column order is derived from explicit occurrence date and Event identity, not from retained list position.

Row order is a deterministic presentation order over `(locus token, measure token)` only. It carries no accounting, causal, source/destination, or priority meaning.

## Executed result

The first workflow execution reached every definition but kernel `decide` could not fully reduce the concrete `mergeSort` witness. No semantic assertion had failed.

The witness checks were therefore switched to the repository's established `native_decide` execution style. The exact-head rerun completed **SUCCESS**.

Mechanically qualified:

```text
non-chronological input
  -> chronological selected columns

superseded in-window Event
  -> absent

before-window Event
  -> absent

exclusive-end Event
  -> absent

selected cells
  -> exact Event.quantityAt values

row totals
  -> exact additive coordinate change

current undated quantity Event
  -> refusal

current invalid-date quantity Event
  -> refusal

superseded undated Event
  -> does not block current projection

empty undated current Event
  -> does not block quantity matrix
```

## Result

For the selected boundary, Transactions-Flow does **not** need a second correction frontier, date resolver, or Event loader.

The qualified shape is:

```text
ActualReview.loadRecordsFromManifest
              |
              v
explicit half-open window selection
              |
              v
EffectCoordinate × current Event incidence projection
```

The matrix can therefore remain another read lens over shared evidence rather than another household engine.

## Still not authorized

Observation 234 does not yet authorize:

- `TransactionsFlowReview` production code;
- a Reports menu entry;
- Sankey or pairwise flow edges;
- AccountingRole decomposition;
- Purpose decomposition;
- aggregation across Measures;
- any new canonical authority or persistence.

The remaining gate is human value: run the same shape against real household Actual evidence and ask whether it reveals something not already obvious from Recent Journal or Stock–Flow.
