# LOAM Falsification Progress

Status: **F001-F200 cross-reference review complete**

Baseline corpus:

```text
LOAM_FALSIFICATION_ATLAS.md        F001-F128
LOAM_FALSIFICATION_ATLAS_WAVE2.md  F129-F200
```

The atlas files own specimen descriptions, attacked seams, and source context.
This file alone owns current progress state after the 200-specimen checkpoint.

The status columns embedded in the atlas files are historical seed metadata.

## State model

Progress has three independent axes:

```text
Work
  REVIEWED | READY | OBSERVING | DONE | DEFERRED | OUTSIDE

Finding
  UNTESTED | ABSORBED | COUNTEREXAMPLE | REDUNDANT

Runtime
  RESEARCH_ONLY | DOGFOOD_REQUIRED | IMPLEMENTING | IMPLEMENTED
```

Interpretation:

- `REVIEWED / UNTESTED` means the specimen was cross-referenced against existing LOAM evidence and no direct information-equivalent bounded result was found.
- `DONE / ABSORBED` means existing LOAM evidence already supplies the distinction required by the specimen.
- `DONE / COUNTEREXAMPLE` means formal work directly demonstrated that a tested smaller candidate was too small.
- a `COUNTEREXAMPLE` does not automatically create product work.
- `IMPLEMENTED` is used only when real practical work already required and obtained the corresponding production capability.

## Default after full review

Every F001-F200 specimen has now been cross-referenced.

Unless an ID appears in an exact `DONE` override below:

```text
Work     = REVIEWED
Finding  = UNTESTED
Queue    = NONE
Runtime  = RESEARCH_ONLY
```

This makes the completed review sparse: unresolved cases no longer need 146 duplicated rows.

## Queue

```text
READY      0
OBSERVING  0
```

The old Wave 1 seed queue remains retired.
No new formal observation is selected until the reviewed unresolved corpus is ranked as a whole.

# Exact DONE overrides

## ABSORBED

| ID | Finding | Runtime | Existing bounded evidence / interpretation |
|---|---|---|---|
| F009 | ABSORBED | RESEARCH_ONLY | Observation 065 — refund/reimbursement remains distinct from Correction; source occurrence survives. |
| F017 | ABSORBED | RESEARCH_ONLY | PR #284 / Observation 125 — provider key is not lifecycle identity; explicit continuity preserves pending→posted replacement. |
| F018 | ABSORBED | RESEARCH_ONLY | PR #281 / Observation 123 — pending and posted source evidence may drift in quantity while supporting one stable Actual. |
| F021 | ABSORBED | RESEARCH_ONLY | PR #279 / Observation 121 — multiple external feeds may support one Actual through explicit reconciliation. |
| F022 | ABSORBED | RESEARCH_ONLY | PR #279 + #283 — identical content/delivery count does not determine source-observation or household-occurrence identity. |
| F023 | ABSORBED | RESEARCH_ONLY | PR #279 — one transfer-shaped Actual may retain multiple external observations without multiplying Actual occurrences. |
| F024 | ABSORBED | RESEARCH_ONLY | PR #279 — reconciliation may survive source timing drift without rewriting household occurrence time. |
| F028 | ABSORBED | RESEARCH_ONLY | Observations 032-033 + 110; PRs #309-#312 — multi-Measure occurrence, valuation, authority and exact residual remain separate layers. |
| F041 | ABSORBED | RESEARCH_ONLY | PR #305 / Observation 139 — negative Remaining does not determine asset/liability funding composition. |
| F042 | ABSORBED | RESEARCH_ONLY | PR #305 / Observation 139 — equal deficit may be cash- or liability-funded without OverspendKind. |
| F046 | ABSORBED | RESEARCH_ONLY | PR #285 + #301 — Capacity/unused carry and Backing continuity are independent. |
| F047 | ABSORBED | IMPLEMENTED | Observation 111 / Practical Slice A2 — one Actual Event may route Effects to several Purposes through historical Locus routing. |
| F048 | ABSORBED | IMPLEMENTED | Observation 111 / Practical Slice A2 — current routing does not rewrite occurrence-valid historical routing. |
| F049 | ABSORBED | RESEARCH_ONLY | Observation 064 — recurring content does not reconstruct Series membership. |
| F057 | ABSORBED | RESEARCH_ONLY | PR #306 / Observation 140 — recognised amount is a policy/query-coordinate projection, not payment/invoice/service timing alone. |
| F058 | ABSORBED | RESEARCH_ONLY | Observation 164 — open obligation plus later discharge covers invoice/bill-like payable structure without canonical Invoice state. |
| F059 | ABSORBED | RESEARCH_ONLY | PR #306 — service range, invoice/payment timing and recognition authority remain separable. |
| F060 | ABSORBED | RESEARCH_ONLY | PR #306 — annual prepayment can project periodic recognition from service range plus recognition definition. |
| F062 | ABSORBED | RESEARCH_ONLY | PR #306 — same payment evidence can support different recognition views under explicit authority. |
| F064 | ABSORBED | RESEARCH_ONLY | PR #306 + #307 — recognition projection and historical as-published/restated knowledge horizons compose without mutable closed-period truth. |
| F065 | ABSORBED | RESEARCH_ONLY | Observation 164 — card-financed burden may precede bank cash settlement; later debit discharges rather than recreates expense. |
| F074 | ABSORBED | RESEARCH_ONLY | Observations 163-165 — later reimbursement can discharge an established outside burden without changing burden allocation. |
| F075 | ABSORBED | RESEARCH_ONLY | Observation 165 — one obligation origin may be discharged across several later Events; outstanding remains derived. |
| F078 | ABSORBED | RESEARCH_ONLY | Observations 165 + 172 — one later Event may discharge several relation units; endpoint identity preserves per-counterparty questions when needed. |
| F081 | ABSORBED | RESEARCH_ONLY | Observation 051 + PR #279 — external confirmation/matching evidence does not itself mean reconciled; reconciliation is explicit correspondence. |
| F083 | ABSORBED | RESEARCH_ONLY | PR #307 / Observation 141 — later correction need not erase an earlier as-known/as-published answer. |
| F084 | ABSORBED | RESEARCH_ONLY | PR #307 / Observation 141 — as-published and current-restated views can coexist. |
| F089 | ABSORBED | RESEARCH_ONLY | PR #309 / Observation 142 — occurrence, settlement and query coordinates may select different retained valuation observations. |
| F090 | ABSORBED | RESEARCH_ONLY | PR #310 / Observation 143 — source provenance does not itself choose one authoritative scalar. |
| F094 | ABSORBED | RESEARCH_ONLY | PR #311/#312 / Observations 144-145 — residual preserves exact conversion; residual placement is separate authority. |
| F095 | ABSORBED | RESEARCH_ONLY | Observation 033 + temporal valuation work — reporting valuation is a Measure-to-Measure projection context, not canonical conversion baked into Event history. |
| F096 | ABSORBED | RESEARCH_ONLY | PR #309/#310 — retained temporal relation observations plus source provenance preserve historical valuation inputs without relying on later recomputation. |
| F097 | ABSORBED | RESEARCH_ONLY | Observations 066-067 — acquisition basis and acquisition-specific provenance survive aggregation and remain distinct from valuation. |
| F115 | ABSORBED | RESEARCH_ONLY | Observation 111 — Purpose routing is separate historical evidence from Event/Effect quantity, so routing may change without amount correction. |
| F116 | ABSORBED | RESEARCH_ONLY | Observation 096 + bitemporal correction work — valid/effective time and learned time remain distinct. |
| F117 | ABSORBED | RESEARCH_ONLY | PR #310 / Observation 143 — several source-distinguished candidates may coexist; provenance and scalar-selection authority are separate. |
| F120 | ABSORBED | RESEARCH_ONLY | Observations 070-071 — current policy definition does not reconstruct the historical definition governing retained attribution. |
| F124 | ABSORBED | IMPLEMENTED | Application 004 + WriterOwnership production use — exclusive ownership spans observe→prepare→admit→publish. |
| F127 | ABSORBED | RESEARCH_ONLY | Observation 047/068 + replaceable query-view work — selection/query policy is replaceable authority over retained evidence, not canonical historical fact. |
| F128 | ABSORBED | RESEARCH_ONLY | Application 006 — conservative fact extension can add new independent evidence without rewriting old meaning/projections. |
| F138 | ABSORBED | RESEARCH_ONLY | Observation 048 — positive physical holding does not imply allocation/spending eligibility. |
| F146 | ABSORBED | RESEARCH_ONLY | Observation 178 + relation-discharge frontier — exact partial discharge and remaining outstanding are independently representable. |
| F161 | ABSORBED | RESEARCH_ONLY | Observations 172-173 + OpenRelation — one source Effect may carry several exact quantity-bearing relation units to distinct external endpoints. |
| F173 | ABSORBED | RESEARCH_ONLY | PR #306 / Observation 140 — earning/recognition period can differ from later payment time. |
| F181 | ABSORBED | RESEARCH_ONLY | PR #307 / Observation 141 — a later amendment can produce a current restatement while preserving the earlier as-published view. |
| F193 | ABSORBED | RESEARCH_ONLY | Observation 050 — execution/initiation and later physical settlement are distinct temporal states. |
| F199 | ABSORBED | RESEARCH_ONLY | Observations 070-071 — later policy/convention changes do not recover or rewrite the historical policy definition. |
| F200 | ABSORBED | RESEARCH_ONLY | Observations 048 + 050 — equal quantities do not collapse settlement state or immediately usable/allocation-eligible rights. |

## COUNTEREXAMPLE

| ID | Finding | Runtime | Direct falsification result |
|---|---|---|---|
| F044 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #285 / Observation 126 — Capacity + holdings/eligibility do not determine per-Purpose Backing; explicit Backing correspondence is observable. |
| F045 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #285 / Observation 126 — Backing support and Capacity authority are not mutually determined. |
| F053 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #278 / Observation 120 — one-to-one ScheduledCompletion is too small for split realization; topology alone is too small for apportionment. |
| F054 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #278 / Observation 120 — several Scheduled claims sharing one Actual require quantity apportionment beyond endpoint topology. |
| F073 | COUNTEREXAMPLE | RESEARCH_ONLY | Observation 163 — physical payment/final net movement do not determine economic burden allocation before settlement. |
| F099 | COUNTEREXAMPLE | RESEARCH_ONLY | Observation 067 — aggregate holding, disposal quantity and even source identity set are too small; per-acquisition consumed quantity is independently observable. |

# Completed review notes

## F001-F040 — authorization, refund, external observation, transfer, restricted rights

The review preserves the earlier stop conditions:

- Observation 050 qualifies `initiated != settled` but explicitly excludes reservation/hold rights, failure, cancellation, reversal, partial settlement, multiple settlement legs, and institution-specific rails.
- Observation 065 leaves multiple refunds, refund lifecycle, disputes/chargebacks, and multi-source reimbursement open.
- PRs #279/#281/#283/#284 absorb much external-feed identity/reconciliation pressure but do not settle pending disappearance or later institution revision.
- Observation 048 proves `held != allocatable` but does not by itself settle liquidity, convertibility, ownership, transfer rights, expiry, or legal restrictions.

## F041-F080 — Capacity/Backing, Scheduled, recognition, debt, shared burden

Direct results absorb several seams, but unresolved cases remain deliberately live:

- arbitrary mixed funding composition remains beyond PR #305;
- recurrence generation rules remain outside Series-membership results;
- unknown Scheduled amount/due semantics remain untested;
- recognition amendment/cancellation remains beyond PR #306;
- interest accrual, refinancing, late-fee generation, creditor migration, forgiveness, second-order refund redistribution, and cashless netting remain untested.

## F081-F120 — finality, FX, investments, inventory, correction/provenance

Review result:

- reconciliation remains explicit evidence rather than a synonym for confirmation;
- temporal valuation, source authority, exact residual, acquisition basis and disposal provenance absorb several Atlas pressures;
- operational realised/unrealised FX calculations remain untested;
- policy-specific FIFO/average-cost gain calculation remains untested even though policy-selected attribution is already separated from physical provenance;
- stock split, return-of-capital, reinvestment and other corporate-action mechanics remain untested;
- **F105-F112 inventory / physical-asset cases remain REVIEWED / UNTESTED as a family**. Existing work separates physical movement, valuation and recognition, but has not directly qualified ERP-style stock/COGS/document sequencing;
- one-to-many and many-to-one Event correction topology remain untested;
- routing correction, bitemporal correction and source-selection authority are already separated where the exact questions match.

## F121-F160 — policy, concurrency, insurance, escrow, BNPL, subscriptions

Review result:

- tax/jurisdiction applicability and per-line-vs-document rounding policy remain untested;
- WriterOwnership solves local stale-writer publication but does not claim offline merge, distributed consensus, or concurrent semantic deduplication;
- replaceable query policy is already separated from canonical historical evidence;
- insurance adjudication, deductible/subrogation, provisional claim settlement and long-running coverage-policy interaction remain untested;
- ordinary escrow non-spendability is absorbed by `held != allocatable`, but escrow-analysis forecasting, deposit ownership and custodian migration remain untested;
- exact partial obligation discharge is already available, but BNPL schedule generation, lender/merchant authority divergence, late-fee creation and collection migration remain untested;
- subscription proration, service entitlement, cancellation horizon, metered true-up and billing-anchor generation remain untested.

## F161-F200 — marketplace, payroll, tax filing, interest, securities settlement

Review result:

- OpenRelation endpoint identity plus plane-local exact relation quantities absorb the basic one-source-to-several-external-entitlements split;
- marketplace fee recognition, refund/transfer reversal coupling, settlement failure and burden migration remain untested;
- payroll earning/payment separation is partly absorbed by recognition work, but withholding, benefits, garnishment and payroll-overpayment workflows remain untested except where an exact Atlas seam is already listed above;
- amended-return historical finality is absorbed by as-published/current-restated evidence, while tax-credit carryforward, withholding/final-liability and refund interception remain untested;
- interest accrual/compounding/balance-method policy remains untested;
- securities execution versus later settlement is absorbed by Observation 050, but settlement failure, exposure/ownership before settlement, dividend entitlement and corporate-action cash-in-lieu remain untested;
- historical settlement-convention policy and settlement-status rights are already separated by existing temporal-policy / settlement / eligibility results.

# Review completion counts

```text
Corpus total                        200
Cross-reference reviewed            200

DONE                                 54
  ABSORBED                           48
  COUNTEREXAMPLE                      6

REVIEWED / UNTESTED                 146

READY                                 0
OBSERVING                             0

Runtime IMPLEMENTED                   3
  F047
  F048
  F124
```

The 146 unresolved cases are not claimed novel. They are the cases for which this review found no direct information-equivalent bounded result strong enough to mark `DONE`.

# Next gate

The next task is no longer corpus review.

It is **ranking the 146 REVIEWED / UNTESTED specimens**.

Selection should prefer:

1. real household relevance;
2. a small two-world distinguishability test;
3. direct pressure against current minimum retained evidence;
4. a question not already answerable by composition of qualified evidence;
5. one formal observation at a time.

Do not expand the corpus or implement product behavior merely to keep the sequence moving.

# Formal-tool rule

```text
Alloy
  information independence / two-world distinguishability

Lean
  exact algebraic law / conservation / constructive sufficiency

TLA+ or SPIN
  temporal publication / interleaving / lifecycle ordering
```

# Production gate

```text
formal pressure
  -> research result
  -> RESEARCH_ONLY

real household operation requires the distinction
  -> DOGFOOD_REQUIRED
  -> implementation work
```

The catalogue is intentionally allowed to remain much larger than the product.
