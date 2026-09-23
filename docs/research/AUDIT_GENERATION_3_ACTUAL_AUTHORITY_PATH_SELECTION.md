# Generation 3 — Actual authority path-selection fanout

Status: **CENTRALIZATION EXPERIMENT**

## Question

When shared readers accept either a household root or the canonical
`actual.loam` file, who owns the decision that both inputs identify the same
Actual authority?

## Discovery

After the normalized Actual cutover, the same lexical decision was repeated in
eleven read paths:

```text
if input.fileName == "actual.loam"
  then input
  else input / "actual.loam"
```

The copies appeared in:

- `ActualReview`;
- `BalanceReview`;
- `BudgetWindowReview`;
- `ConditionalBalancePathReview`;
- `CurrentCoverageReview`;
- `CycleBudgetReview`;
- `CycleSpendingPaceReview`;
- `MerchantExpenseReview`;
- `RoleBalanceReview`;
- `ScheduledReview`;
- `StockFlowReview`.

Some paths use the selected file not only for reading but also for
`ActualAuthority.withActualFileOwnership`. Therefore this is authority identity
selection, not merely string formatting.

## History

PR #756 graduated Actual to one canonical `actual.loam` file and explicitly
retired legacy fallback readers and dual-format runtime behavior.

Later Review work retained a convenient caller contract where some shared readers
accept either the household root or the canonical file path. That compatibility
decision accumulated locally as Review boundaries grew.

## Experiment

Add one pure lexical helper:

```text
ActualAuthority.actualPathFromRootOrFile
```

and route all eleven readers through it.

The helper performs no filesystem probing and introduces no fallback:

```text
canonical filename -> preserve path
anything else       -> append actual.loam
```

This exactly preserves the existing contract.

A direct ActualAuthority regression pins both supported forms:

```text
root        -> root/actual.loam
actual.loam -> actual.loam
```

## Why the owner is ActualAuthority

The selected path names the canonical Actual authority file and is also used by
authority-scoped observation locks. A Review should decide what household
question to ask, not independently decide which physical path counts as the
Actual authority.

## Tool choice

This is an ownership/topology question.

- dependency and exact-code search found the eleven copies;
- Git history established that single-file Actual is already the production
  boundary;
- D2 records the fan-out before/after;
- Lean builds and existing executable Review tests qualify behavior preservation.

No Alloy/TLA+/SPIN model is added because no new state-space, temporal protocol,
or domain distinction is proposed.

## Decision rule

Keep this centralization only if the existing Review, TUI, report, and
ActualAuthority qualifications remain green.

If any caller turns out to intentionally interpret a non-canonical
`actual.loam`-named path differently, that is evidence that the current
root-or-file convenience contract needs explicit redesign rather than a forced
shared helper.
