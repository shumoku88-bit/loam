# Accounting Capability Audit Checkpoint — September 2026

Status: **checkpoint after production/report capability audit**

Baseline main:

```text
31abd1acd0a4ad0ad10f8e4cd36d66c34d5478ff
refactor(publisher): hide publication telemetry (#809)
```

At the checkpoint, open PR count was zero.

## Question

This audit asks whether LOAM is missing major household/accounting capability, or whether much of the familiar reporting surface is already reconstructable from retained evidence and only lacks a production projection / presentation connection.

The working distinction is:

```text
A  already available in current production semantics / report surface
B  existing retained evidence appears sufficient; a small projection is still missing
C  a genuinely independent evidence / authority / policy distinction is still required
```

The classification is about semantic sufficiency, not UI completeness or feature parity with a named accounting product.

## Executive conclusion

The audit does **not** support the claim that LOAM is mainly blocked by missing accounting functionality.

The stronger reading is:

```text
LOAM already retains or qualifies a substantial accounting-capability basis
+
several conventional answers remain disconnected from production report projections
+
a smaller set of accounting questions genuinely require new independent evidence / authority
```

Therefore the next design pressure should prefer:

```text
connection / projection / compression
    before
new accounting subsystem / new retained report state
```

The important boundary is not “can LOAM print another report?” but:

> Which answer is already determined by retained evidence, and which answer still depends on an independently observable classification, completeness, valuation, recognition, or policy choice?

## Current production report surface

Current Reports already exposes:

- Stock-Flow;
- Transactions Flow;
- Budget Window;
- conditional selected-balance Liquidity;
- an explicit Accounting evidence-limit surface.

The Accounting surface currently says `Accounting projection: UNAVAILABLE`. This must **not** be interpreted as “LOAM has no accounting semantics”. It means the Reports workspace does not currently own a production role-aware report adapter, and it deliberately refuses to infer roles from Locus spelling, sign, Purpose, or presentation state.

That refusal is correct.

## AccountingRole status

Current Core retains the explicit partial relation:

```text
LocusId -> lone AccountingRole
```

with the currently earned vocabulary:

```text
Asset
Liability
Equity
Income
Expense
```

Missing role assignment remains unresolved classification evidence. It is not an `UnknownRole` value, zero, irrelevance, or permission for the report layer to guess.

AccountingRole is also not research-only decoration: current production code consumes it for selected Scheduled / Capacity pressure questions, and a guarded initial-role publication boundary exists for virgin Loci.

Current household data also contains explicit role assignments for ordinary Asset, Liability, Equity, Income, and Expense Loci.

## Partial accounting-report law already qualified

Observations 216 and 217 established an important result that any future production accounting report should preserve.

The smallest truthful role-aware report shape is conceptually:

```text
resolved role quantities
+
unresolved Effect frontier
```

not merely:

```text
role -> quantity
```

In particular:

```text
unresolved quantity total = 0
    !=
report complete
```

because unresolved positive and negative Effects may cancel numerically while retained evidence remains unclassified.

Therefore future Balance Sheet / P&L-shaped answers must keep value and completeness separate.

## Capability classification

### A — already present or directly exposed

| Capability | Current reading |
| --- | --- |
| Actual / transaction history | Correction-aware, occurrence-date-aware production Actual review exists. |
| Exact multi-posting movement | Practical Movement records exact signed Effects; selected balanced Movement semantics are qualified. |
| Selected balances | Production BalanceReview exists with explicit zero-origin coverage requirements. |
| Stock-Flow | Production report exists. |
| Transactions Flow | Production report exists, including net, gross, positive, negative, and contributing Event witnesses. |
| Budget Window / budget-vs-Actual shape | Production report derives entitlement, consumption, and Remaining. |
| Conditional future selected balance | Production conditional Liquidity path exists under an explicit completeness assumption. |
| Separate quantities by Measure | Core keeps exact Measure identity and refuses unproved cross-Measure addition. |

### B — existing evidence appears sufficient; projection is missing or incomplete

| Capability | Why this is B rather than C |
| --- | --- |
| Register / general-ledger-shaped view | Actual + date ordering + Locus/Measure effects already contain the relevant retained movement witnesses. |
| Period Income / Expense totals | Actual window + explicit AccountingRole classification can select role-aware quantities. |
| P&L-shaped report | Income/Expense role projection is qualified in selected scope; cash/occurrence-time presentation does not require a new physical event model. |
| Trial Balance-shaped report | Locus / role quantity aggregation is a projection problem; unresolved classification must remain visible. |
| Balance Sheet-shaped report | Asset/Liability/Equity classification is reconstructable, but stock completeness / origin coverage must be preserved explicitly. |
| Net Worth by one Measure | Asset/Liability stock projection is plausible from existing role + complete quantity evidence. |
| Periodic quantity reports | Explicit DateRange projection is already a recurring production pattern. |

“B” does not mean a UI-only change. A small shared review boundary may still need to be earned and qualified. It means no new retained accounting fact has yet been demonstrated as necessary for the selected answer.

## Balance Sheet is not just a renamed BalanceReview

Current BalanceReview answers an explicitly selected `Locus × Measure` display question from:

```text
Actual evidence
+ correction frontier
+ ZeroOriginCoverage
+ balance-view selection
```

It does not enumerate all AccountingRole coordinates and does not claim statement completeness.

Therefore a Balance Sheet-shaped projection needs to compose at least:

```text
AccountingRole
+ stock quantity evidence
+ origin / completeness evidence
+ selected Measure / as-of coordinate
```

and preserve an unresolved / unsupported frontier rather than silently omitting coordinates that cannot be justified.

## P&L is closer than Balance Sheet

For a selected occurrence-time / cash-basis-shaped period answer, the required ingredients are already conceptually present:

```text
correction-aware current Actual
+ explicit [start, end) window
+ AccountingRole
    -> Income / Expense role quantities
       + unresolved Effect frontier
```

This should not be confused with full accrual accounting. Recognition-time policy is a separate C-level pressure below.

## Multi-currency reading

LOAM should be described precisely as **multi-Measure native**, not as already having a complete production foreign-currency accounting subsystem.

`MeasureId` deliberately carries no built-in currency, commodity, valuation, or dimensional meaning. Distinct Measures can coexist and are not silently added.

Therefore LOAM can naturally retain and separately report, for example:

```text
cash-jpy / jpy
foreign-holding / usd
```

without changing neutral Event / Effect shape.

However a single base-currency answer such as:

```text
net worth expressed in JPY
```

requires independently observable valuation inputs such as effective rate coordinate, source provenance, scalar-selection authority, and exact residual / presentation policy where integral rounding is required.

Research has qualified substantial pieces of this composition, but current production does not retain a general market-rate / FX valuation authority.

## C — genuine independent semantic pressure remains

| Capability | Missing independent information / authority |
| --- | --- |
| Base-currency net worth across Measures | Temporal valuation relation, source provenance, scalar selection, exact conversion / residual policy. |
| Realised / unrealised FX gain | Occurrence / settlement / query valuation coordinates plus basis/provenance and selected valuation policy. |
| Accrual / deferred recognition | Recognition coordinate / definition is not determined by payment or occurrence time. |
| Formal Cash Flow Statement | Operating / Investing / Financing or equivalent liquid-flow classification has not received an equivalent qualified production composition. |
| Rich investment accounting | Lot / acquisition basis, disposal provenance and rich selection policy are only partly qualified and not production-complete. |
| Tax accounting | Jurisdiction / applicability / tax-basis policy is external independent authority. |
| ROI / return methodology | Time-weighting / cash-flow methodology remains a separate selected policy question. |
| Full reconciliation / filed-statement finality workflow | Historical as-known projections are researched, but publication / sign-off workflow authority remains broader than current reports. |

These are the areas where “just connect another report” would be an overclaim.

## Relation to Ledger / hledger reconstruction research

The existing Ledger / hledger reconstruction checkpoint already found substantial selected breadth without C-level pressure to enlarge neutral `Event / Effect / EffectKey` shape.

The recurring surviving architecture is:

```text
small neutral physical Core
+ independently observable typed evidence
+ explicit relations
+ policy / projection / generation
+ admission when generated material becomes retained fact
    -> mature accounting answers
```

This audit is consistent with that result.

The new practical conclusion is narrower:

> Several ordinary household/accounting reports now appear to be production projection gaps rather than ontology gaps.

## Compression hypothesis for the next step

Do **not** immediately add independent engines such as:

```text
ProfitLossReview
BalanceSheetReview
TrialBalanceReview
NetWorthReview
IncomeExpenseReview
```

until a smaller basis has been tested.

The strongest current compression hypothesis is two shared projection families:

```text
RoleFlow
  correction-aware Actual
  + explicit DateRange
  + AccountingRole
    -> role quantities
     + unresolved Effect frontier

RoleBalance
  stock quantity evidence
  + completeness / origin evidence
  + AccountingRole
  + as-of / Measure selection
    -> role balances
     + unresolved / unsupported frontier
```

Candidate conventional views would then be presentation / selection compositions over those answers:

```text
RoleFlow
  -> P&L-shaped view
  -> Income / Expense breakdown
  -> selected Trial Balance flow rows

RoleBalance
  -> Balance Sheet-shaped view
  -> Net Worth
  -> selected Trial Balance stock rows
```

This is a hypothesis, not yet a production design decision.

## Next falsification question

Before implementation, test whether the apparent family can actually be compressed:

> Do P&L, Balance Sheet, Trial Balance, and Net Worth require distinct semantic engines, or are the independently observable differences exhausted by stock-vs-flow coordinate, AccountingRole selection, completeness frontier, and presentation policy?

Alloy is a plausible first tool because the immediate question is distinguishability / information sufficiency rather than arithmetic performance or UI shape.

Useful counterexample targets include:

1. same RoleFlow answer but legitimately different P&L answer;
2. same RoleBalance answer but legitimately different Balance Sheet answer;
3. same role totals but different unresolved Effect frontier;
4. same stock quantities but different completeness / origin justification;
5. a Trial Balance answer requiring information not recoverable from the proposed two-family basis;
6. a conventional view whose selected answer changes under a policy not represented by stock-vs-flow + role + completeness.

If such a counterexample exists, add only the missing independent coordinate / evidence / authority. Do not add a named report object merely because conventional accounting has that noun.

## Stop rule

Do not add accounting features merely to make a capability table greener.

Reopen ontology pressure only when one of these occurs:

```text
real household dogfood asks a question existing evidence cannot determine
RoleFlow / RoleBalance compression produces a concrete counterexample
valuation / recognition / finality pressure cannot remain additive
provenance cannot attach safely to existing stable identities
a user-visible answer requires an authority that current evidence cannot reconstruct
```

Otherwise prefer shared projection and presentation composition.

## Checkpoint verdict

```text
major ordinary household/accounting capability basis present     YES
current production report surface complete                        NO
main deficit                                                       projection / connection
Balance Sheet / P&L semantic reconstruction in selected scope     YES
truthful completeness frontier required                            YES
multi-Measure support                                               YES
complete production FX valuation accounting                        NO
new neutral Event/Effect shape currently required                  NO EVIDENCE
next best pressure                                                  RoleFlow / RoleBalance falsification
```

The checkpoint therefore closes this audit with the working principle:

> LOAM should first expose the accounting answers already determined by its evidence, while keeping unresolved evidence and completeness visible. New retained accounting concepts should be added only where a concrete answer cannot otherwise be justified.
