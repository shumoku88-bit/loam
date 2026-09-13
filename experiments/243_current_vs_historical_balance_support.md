# Observation 243 — Current versus historical balance support

Status: **QUALIFIED — current-balance support and zero-origin historical support are distinct**

Baseline:

```text
b52e76bf9fd29bc0f9a5f8e0f730d3b608f6fc4c
feat(reports): show Income and Expense breakdown (#815)
```

Qualified model head:

```text
624388de101c08ed12b1ad9fb74f40bbb1c9860f
```

Qualified CI:

```text
workflow: Observation 243
run:      34743232468
job:      103686389571
result:   SUCCESS
Alloy:    6.2.0 / Sat4j
```

## Trigger

Real-data dogfooding of `RoleBalanceReview` initially surfaced 38 unsupported coordinates. That number was too coarse for deciding whether a Balance Sheet-shaped report was actually blocked.

Observation 242 already distinguishes report-specific support frontiers:

```text
Balance Sheet -> Asset / Liability / Equity support
Net Worth     -> Asset / Liability support
Trial Balance -> all coordinate support
```

The current household AccountingRole map contains 40 classified Loci, while zero-origin coverage contains only five JPY holding coordinates. Income / Expense coordinates therefore dominate the shared `RoleBalanceReview.unsupportedBalances` frontier, even though they are not Balance Sheet stock rows.

After filtering to Balance Sheet roles, the concrete pressure is much smaller. Current canonical Actual contains the important examples:

```text
2026-04-04
  equity:opening-balances +217706
  debt-friend-k          -217706

2026-06-14
  tobacco                 +500
  debt-mother             -500

2026-06-15
  debt-mother             +500
  smbc                    -500
```

`debt-friend-k` therefore has a retained non-zero opening/reconstruction entry. `debt-mother` has visible borrow/repay activity but no independent machine-readable proof that the retained stream begins at exact zero.

This exposes a narrower question than Observation 242:

> Is exact-zero origin support the only legitimate way to justify a current balance, or can a later/non-zero anchor justify the current answer without justifying every earlier historical boundary?

## Why this matters

Production currently reuses `BalanceReview` inside `RoleBalanceReview`. `BalanceReview` deliberately requires `ZeroOriginCoverage`, and `StockFlowReview` relies on that stronger fact to reconstruct arbitrary historical boundaries by summing retained Events from the origin.

That guarantee must not be weakened accidentally.

A later balance anchor has a different temporal shape:

```text
zero-origin support
  -> supports origin and every later boundary

later/current anchor
  -> supports the anchor and later boundaries
  -> does NOT justify earlier boundaries
```

If these are observationally different, widening the meaning of `ZeroOriginCoverage` to mean generic current-balance support would collapse a real distinction and could make Stock-Flow historical reconstruction overclaim.

## Alloy vocabulary

The model keeps only the distinction under test:

```text
Coordinate
AccountingRole
Moment
zeroOrigin : set Coordinate
anchorAt   : Coordinate -> lone Moment
```

A coordinate is supported at time `t` when either:

- it has exact zero-origin support; or
- it has an anchor at or before `t`.

Current support is support at the last Moment.

Balance Sheet completeness considers only Asset / Liability / Equity coordinates. Historical Stock-Flow support is evaluated at arbitrary Moments, including the origin.

## Executed result

Alloy produced the expected matrix:

```text
anchoredCurrentWithoutZeroOrigin                     SAT
sameCurrentSupportDifferentHistoricalSupport         SAT
completeBalanceSheetButIncompleteOriginHistory       SAT

ZeroOriginIsRequiredForEveryCurrentBalance            SAT counterexample
CurrentSupportDeterminesHistoricalSupport             SAT counterexample
BalanceSheetCompletenessImpliesOriginCompleteness     SAT counterexample

SeparateSupportEvidenceDeterminesAllSupportQuestions  UNSAT counterexample
```

The expected-result checker passed in CI.

## Findings

### 1. A current balance can be justified without exact zero-origin support

Alloy found a coordinate with a later anchor that is supported at the current boundary while lacking zero-origin support.

Therefore the production equation

```text
current-balance support = ZeroOriginCoverage
```

is stronger than the abstract support law qualified by Observation 242.

That does **not** mean the current production code is wrong. It means the reuse is conservative and may refuse legitimately supportable accounting balances whose evidence is a later/non-zero anchor.

### 2. Same current support does not determine historical support

Alloy found two worlds with identical current support but different support at the origin.

Therefore a generic boolean such as

```text
CurrentQuantityCovered
```

cannot silently replace `ZeroOriginCoverage` for every consumer. `StockFlowReview` needs the stronger temporal fact because it reconstructs earlier boundaries.

### 3. Balance Sheet completeness need not imply full origin-history completeness

The model found a world in which every Balance Sheet-relevant coordinate is supported **now**, while at least one of those coordinates is unsupported at the origin.

So a current Balance Sheet-shaped projection can, in principle, be complete under evidence that is insufficient for arbitrary historical Stock-Flow reconstruction.

The two report questions have different support domains.

### 4. The two evidence families are sufficient in the bounded model

Once both `zeroOrigin` and `anchorAt` are fixed, Alloy found no world where current support, Balance Sheet frontier, or historical support answers differ.

The missing distinction is therefore not another named report engine. It is temporal support evidence.

## Real-data reading

The earlier 38-row `RoleBalanceReview.unsupportedBalances` count should not be read as "38 missing Balance Sheet facts".

The shared frontier intentionally contains coordinates needed by different potential views. Observation 242 already limits Balance Sheet completeness to Asset / Liability / Equity coordinates, while Trial Balance remains broader.

For current household data, the interesting Balance Sheet pressure is concentrated in the non-zero / non-zero-origin side, especially:

```text
debt-friend-k
debt-mother
equity:opening-balances
```

The first is especially important because canonical Actual already retains a reconstruction entry for a non-zero liability opening balance. Treating that coordinate as exact-zero-origin would be false, yet the retained ledger contains stronger current-balance evidence than a plain uncovered coordinate.

`debt-mother` is different: visible borrow/repay activity does not by itself prove there was no earlier liability. The model therefore does not authorize treating it as supported merely because the current net happens to be zero.

## Production gate

This observation deliberately stops before implementation.

The next production investigation should obey four constraints:

1. keep `ZeroOriginCoverage` semantics strong enough for `StockFlowReview` historical reconstruction;
2. do not mark a non-zero anchored coordinate as zero-origin merely to make Accounting complete;
3. if current-only balance support is needed, test the smallest independent relation that can express it without reviving retired QuantityBasis identity/correction machinery;
4. do not infer anchors from Event description text, Locus spelling, sign, or AccountingRole.

A useful candidate shape is **not yet a decision**, but the pressure now looks closer to:

```text
historical support
  ZeroOriginCoverage

current/as-of support
  zero-origin evidence
  + independently admitted anchor/reconciliation evidence
```

rather than one overloaded coverage relation.

## Non-claims

This observation does not establish:

- conventional Balance Sheet completeness;
- period closing or retained earnings;
- accrual recognition;
- full Trial Balance completeness;
- that every Event paired with Equity is an opening anchor;
- that `debt-mother` begins at zero;
- that a new persistent support family is required;
- that retired QuantityBasis should return.

The selected result is only:

> **current/as-of support and full-origin historical support are independently observable temporal facts.**

## Verdict

```text
current balance requires exact zero origin             NO
same current support determines historical support     NO
B/S completeness implies origin-history completeness   NO
one overloaded zero-origin/current support relation    NOT JUSTIFIED
separate temporal support evidence sufficient          YES (bounded)
next pressure                                           smallest typed current-anchor witness
```
