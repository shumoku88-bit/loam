# LOAM Explain v1

`EXPLAIN1` is a read-only machine-facing explanation surface.

It is not canonical household data, a repair format, or a second accounting
engine. The first v1 question is balance answerability:

```text
loam explain balances [LOAM_DATA_DIR]
loam explain balances --machine [LOAM_DATA_DIR]
```

Both the human-facing Reports > Balances Answerability Map and the machine
surface consume the same `RoleBalanceAnswerability.Summary`, itself derived
only from one qualified `RoleBalanceReview.Snapshot`.

## Framing

Machine output is UTF-8, one tab-separated record per line. Every record starts
with `EXPLAIN1`.

A complete document ends with exactly:

```text
EXPLAIN1<TAB>meta<TAB>status<TAB>complete
```

Consumers should reject a stream without this terminal record.

## Metadata

```text
EXPLAIN1  meta  schema          1
EXPLAIN1  meta  implementation  loam
EXPLAIN1  meta  question        balances
```

## Question status

```text
EXPLAIN1  status  balance-sheet  ANSWERABLE|BLOCKED
EXPLAIN1  status  net-worth      ANSWERABLE|BLOCKED
```

These statuses are not AI judgments. They are the same blocker classification
used by the TUI Answerability Map.

## Scalars

```text
EXPLAIN1  scalar  total_coordinates                count  N
EXPLAIN1  scalar  exact_current_quantity_support   count  N
EXPLAIN1  scalar  accounting_role_coverage         count  N
EXPLAIN1  scalar  flow_role_quantity_gaps          count  N
```

Flow-role quantity gaps are Income / Expense coordinates without exact current
quantity support. They remain visible but do not block Balance Sheet or Net
Worth.

## Blockers

Amount known present but exact quantity unknown:

```text
EXPLAIN1  blocker  balance-sheet  amount-unknown  LOCUS  MEASURE  ROLE
EXPLAIN1  blocker  net-worth      amount-unknown  LOCUS  MEASURE  ROLE
```

Current quantity support absent:

```text
EXPLAIN1  blocker  balance-sheet  unsupported  LOCUS  MEASURE  ROLE
EXPLAIN1  blocker  net-worth      unsupported  LOCUS  MEASURE  ROLE
```

AccountingRole unresolved:

```text
EXPLAIN1  blocker  balance-sheet+net-worth  role-unresolved  LOCUS  MEASURE  quantity-known|quantity-unsupported
```

A single coordinate may appear in both Balance Sheet and Net Worth blocker
records when both questions depend on it. Consumers should compare semantic
keys, not line positions.

## Nonblocking flow gaps

```text
EXPLAIN1  gap  flow-role-quantity  LOCUS  MEASURE  ROLE  nonblocking-stock
```

## Interpretation rule

The surface explains why the existing production answer is or is not justified.
It does not:

- infer a missing quantity;
- infer AccountingRole;
- recommend adding zero-origin evidence;
- repair or rewrite household facts;
- turn current support into a claim of complete history;
- ask an AI to choose between conflicting evidence families.

Future Locus- or Event-specific explanation should reuse existing typed
production evidence and extend this pattern rather than add retained Explain
state.
