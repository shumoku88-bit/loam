# LOAM Falsification Progress

Status: **F001-F200 reviewed; F051 and F033 completed; four-item near queue remains**

Baseline corpus:

```text
LOAM_FALSIFICATION_ATLAS.md        F001-F128
LOAM_FALSIFICATION_ATLAS_WAVE2.md  F129-F200
```

Selection checkpoint:

```text
LOAM_FALSIFICATION_SELECTION_2026-09.md
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
- `READY / UNTESTED` means the reviewed specimen has been selected into the small near formal queue, but no new bounded result exists yet.
- `DONE / ABSORBED` means existing LOAM evidence already supplies the distinction required by the specimen.
- `DONE / COUNTEREXAMPLE` means formal work directly demonstrated that a tested smaller candidate was too small.
- a `COUNTEREXAMPLE` does not automatically create product work.
- `IMPLEMENTED` is used only when real practical work already required and obtained the corresponding production capability.

## Default after F051 and F033

Every F001-F200 specimen has now been cross-referenced.

Unless an ID appears in an exact `READY` or `DONE` override below:

```text
Work     = REVIEWED
Finding  = UNTESTED
Queue    = NONE
Runtime  = RESEARCH_ONLY
```

This keeps the completed review sparse: unresolved cases do not need duplicated rows.

## Queue

```text
READY      4
OBSERVING  0
```

Exact READY order:

| Order | ID | Pressure |
|---:|---|---|
| 1 | F001 | authorization hold without capture |
| 2 | F076 | refund provenance through shared burden |
| 3 | F055 | recurrence at shorter-month boundary |
| 4 | F086 | physical/external quantity assertion vs reconstructed history |

All four remain `Finding = UNTESTED` and `Runtime = RESEARCH_ONLY`.
Only one should normally advance to `OBSERVING` at a time.
Detailed scoring and WATCHLIST rationale live in `LOAM_FALSIFICATION_SELECTION_2026-09.md`.

# Exact DONE overrides

## ABSORBED

| ID | Finding | Runtime | Existing bounded evidence / interpretation |
|---|---|---|---|
| F009 | ABSORBED | RESEARCH_ONLY | Observation 065 — refund/reimbursement remains distinct from Correction; source occurrence survives. |
| F017 | ABSORBED | RESEARCH_ONLY | PR #284 / Observation 125 — provider key is not lifecycle identity; explicit continuity preserves pending→posted replacement. |
| F018 | ABSORBED | RESEARCH_ONLY | PR #281 / Observation 123 — pending and posted source evidence may drift in quantity while supporting one stable Actual. |
| F021 | ABSORBED | RESEARCH_ONLY | PR #279 / Observation 121 — multiple external feeds may support one Actual through explicit reconciliation. |
| F022 | ABSORBED | RESEARCH_ONLY | PR #279 + #283 — identical content/delivery count does not determine source-observation or household-occurrence identity. |
| F023 | ABSORBED | RESEARCH_ONLY | PR #279 — one transfer-shaped Actual may retain multiple source observations without multiplying household occurrences. |
| F024 | ABSORBED | RESEARCH_ONLY | PR #279 — reconciliation may survive source timing drift without rewriting household occurrence time. |
| F028 | ABSORBED | RESEARCH_ONLY | Observations 032-033 + 110; PRs #309-#312 — multi-Measure occurrence, valuation, authority and exact residual remain separate layers. |
| F041 | ABSORBED | RESEARCH_ONLY | PR #305 / Observation 139 — negative Remaining does not determine asset/liability funding composition. |
| F042 | ABSORBED | RESEARCH_ONLY | PR #305 / Observation 139 — equal deficit may be cash- or liability-funded without OverspendKind. |
| F046 | ABSORBED | RESEARCH_ONLY | PR #285 + PR #301 — Capacity/unused-carry continuity and Backing continuity are independent axes. |
| F047 | ABSORBED | IMPLEMENTED | Observation 111 / Practical Slice A2 — one Actual Event may route Effects to several Purposes through historical Locus routing. |
| F048 | ABSORBED | IMPLEMENTED | Observation 111 / Practical Slice A2 — current routing does not rewrite occurrence-valid historical routing. |
| F049 | ABSORBED | RESEARCH_ONLY | Observation 064 — repeated-plan content / recurrence shape does not reconstruct Series membership. |
| F057 | ABSORBED | RESEARCH_ONLY | PR #306 / Observation 140 — recognition is a policy/query-coordinate projection rather than payment/invoice/service timing alone. |
| F058 | ABSORBED | RESEARCH_ONLY | Observation 164 — invoice/bill-like open obligation and later cash settlement fit a directional relation + later discharge. |
| F059 | ABSORBED | RESEARCH_ONLY | PR #306 — service range, invoice/payment timing, and recognition authority remain separable coordinates. |
| F060 | ABSORBED | RESEARCH_ONLY | PR #306 — annual prepayment can project periodic recognition from service DateRange + recognition definition. |
| F062 | ABSORBED | RESEARCH_ONLY | PR #306 — same physical payment may support different recognition views under explicit recognition authority. |
| F064 | ABSORBED | RESEARCH_ONLY | PR #306 + PR #307 — recognition projection and as-published/restated knowledge horizon compose without mutable closed-period truth. |
| F065 | ABSORBED | RESEARCH_ONLY | Observation 164 — card-financed burden may exist before bank cash settlement; later debit discharges relation rather than creating expense again. |
| F074 | ABSORBED | RESEARCH_ONLY | Observations 163-165 — later reimbursement/receipt can discharge an already-established outside burden without changing burden allocation. |
| F075 | ABSORBED | RESEARCH_ONLY | Observation 165 — one obligation origin may be discharged across several later Events; outstanding remains derived. |
| F078 | ABSORBED | RESEARCH_ONLY | Observations 165 + 172 — one later Event may discharge multiple relation units, while opaque endpoint identity preserves per-counterparty distinctions. |
| F081 | ABSORBED | RESEARCH_ONLY | Observation 051 + PR #279 — external confirmation/matching evidence does not itself mean reconciled; reconciliation is explicit correspondence. |
| F083 | ABSORBED | RESEARCH_ONLY | PR #307 / Observation 141 — later correction need not erase an earlier as-known/as-published answer. |
| F084 | ABSORBED | RESEARCH_ONLY | PR #307 / Observation 141 — as-published and current-restated projections coexist. |
| F089 | ABSORBED | RESEARCH_ONLY | PR #309 / Observation 142 — occurrence, settlement, and query coordinates may select different retained valuation observations. |
| F090 | ABSORBED | RESEARCH_ONLY | PR #310 / Observation 143 — source provenance does not itself choose one authoritative scalar. |
| F094 | ABSORBED | RESEARCH_ONLY | PR #311/#312 / Observations 144-145 — exact residual preserves conversion equality; visible residual placement is separate authority. |
| F095 | ABSORBED | RESEARCH_ONLY | Observation 033 + temporal valuation work — reporting valuation is a Measure-to-Measure projection context, not canonical conversion baked into Event history. |
| F096 | ABSORBED | RESEARCH_ONLY | PR #309/#310 — retained temporal relation observations plus source provenance preserve historical valuation inputs without relying on later recomputation. |
| F097 | ABSORBED | RESEARCH_ONLY | Observations 066-067 — acquisition basis and acquisition-specific provenance survive aggregation and remain distinct from valuation. |
| F115 | ABSORBED | RESEARCH_ONLY | Observation 111 — Purpose routing is separate historical evidence from Event/Effect quantity, so routing may change without amount correction. |
| F116 | ABSORBED | RESEARCH_ONLY | Observation 096 + bitemporal correction work — valid/effective time and learned time remain distinct. |
| F117 | ABSORBED | RESEARCH_ONLY | PR #310 / Observation 143 — several source-distinguished candidates may coexist; provenance and scalar-selection authority are separate. |
| F120 | ABSORBED | RESEARCH_ONLY | Observations 070-071 — current policy definition does not reconstruct the historical definition governing retained attribution. |
| F124 | ABSORBED | IMPLEMENTED | Application 004 + `Loam.WriterOwnership` production use — writer ownership spans observe -> prepare -> admit -> publish. |
| F127 | ABSORBED | RESEARCH_ONLY | Observation 047/068 + replaceable query-view work — selection/query policy is replaceable authority over retained evidence. |
| F128 | ABSORBED | RESEARCH_ONLY | Application 006 — conservative fact extension can add new independent evidence without rewriting old fact meaning/projections. |
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
| F033 | COUNTEREXAMPLE | RESEARCH_ONLY | Observation 197 — equal wallet quantity and equal broad allocation eligibility can coexist with different send/withdraw permissions; quantity and coarse usability do not determine future movement rights. |
| F044 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #285 / Observation 126 — Capacity + holdings/eligibility do not determine per-Purpose Backing; explicit Backing correspondence is observable. |
| F045 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #285 / Observation 126 — Backing support and Capacity authority are not mutually determined. |
| F051 | COUNTEREXAMPLE | RESEARCH_ONLY | Observation 196 — identical exact Scheduled evidence can coexist with a known amount-unknown obligation versus no known obligation; existence knowledge and exact quantity knowledge are independently observable. |
| F053 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #278 / Observation 120 — one-to-one ScheduledCompletion is too small for split realization, and quantity-free topology is too small for apportionment. |
| F054 | COUNTEREXAMPLE | RESEARCH_ONLY | PR #278 / Observation 120 — several Scheduled claims sharing one Actual require quantity apportionment beyond endpoint topology. |
| F073 | COUNTEREXAMPLE | RESEARCH_ONLY | Observation 163 — physical payment and final net movement do not determine economic burden allocation before settlement. |
| F099 | COUNTEREXAMPLE | RESEARCH_ONLY | Observation 067 — aggregate holding, disposal quantity and even source identity set are too small; per-acquisition consumed quantity is independently observable. |

# Completed review notes

## F001-F040 — authorization, refund, external observation, transfer, restricted rights

The review now has one additional direct result:

- Observation 197 closes F033 with a counterexample: quantity plus broad allocation eligibility does not determine selected future movement rights, and quantity plus spendability does not reconstruct sendability/withdrawability.
- Observation 050 qualifies `initiated != settled` but explicitly excludes reservation/hold rights, failure, cancellation, reversal, partial settlement, multiple settlement legs, and institution-specific rails. Therefore F001-F008 are not waved away as "pending payment already solved".
- Observation 065 explicitly leaves multiple refunds, refund lifecycle, dispute/chargeback, and multi-source reimbursement open. Therefore F010-F016 remain live.
- PRs #279/#281/#283/#284 absorb many external-feed identity pressures, but pending disappearance and later institution revision remain untested in F019-F020.
- side-local transfer dates/reconciliation, fees, one-to-many settlement, net settlement, and reversal remain beyond Observation 050's scope.
- Observation 048 proves `held != allocatable`; Observation 197 now additionally proves that even equal allocation eligibility does not settle operation-specific movement rights. F034-F040 remain separate unresolved restricted-value questions.

## F041-F080 — Capacity/Backing, Scheduled, recognition, debt, shared burden

Direct results absorb several seams, but unresolved cases remain deliberately live:

- PR #305 tests cash-funded versus liability-funded negative Remaining but not arbitrary mixed funding composition, so F043 stays open.
- recurrence generation itself remains deferred; Series membership evidence does not answer shorter-month or weekend-shift generation policy.
- Observation 196 now closes F051 by finding a genuine counterexample: exact Scheduled evidence does not determine whether an amount-unknown obligation is already known to exist. F049/F050/F052 remain separate unresolved quantity/date questions.
- PR #278 closes the information question for split/merged realization by finding a real counterexample; it does not implement apportionment.
- PR #306 does not close recognition-policy amendment after service cancellation, or tax-specific recognition applicability.
- Observations 163-165 close ordinary directional obligation/discharge structure, but interest accrual, refinancing, late-fee generation, creditor migration, and forgiveness without cash remain live.
- shared-cost observations do not yet settle second-order refund redistribution, overpayment direction reversal, or obligation netting without a physical cash Event.

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

# Current counts

```text
Corpus total                        200
Cross-reference reviewed            200

DONE                                 56
  ABSORBED                           48
  COUNTEREXAMPLE                      8

READY                                 4
OBSERVING                             0
REVIEWED / UNTESTED                 140

Runtime IMPLEMENTED                   3
  F047
  F048
  F124
```

The 140 unresolved non-READY cases are not claimed novel. They are the reviewed cases for which no direct information-equivalent bounded result was found and which were not selected into the current near queue.

# Selection frontier

F051 and F033 are complete:

```text
F051
  Work     DONE
  Finding  COUNTEREXAMPLE
  Runtime  RESEARCH_ONLY

F033
  Work     DONE
  Finding  COUNTEREXAMPLE
  Runtime  RESEARCH_ONLY
```

The next READY representative is F001:

```text
authorization hold exists
    +
no capture yet
```

Before opening it, preserve the one-observation-at-a-time rule and re-check whether Observations 196-197 change any ranking rationale. Do not open four observations in parallel.
Do not expand the corpus merely to keep numbering moving.
Do not convert a formal counterexample into production work without dogfood pressure.

# Formal-tool rule

```text
Alloy
    information independence / two-world distinguishability

Lean
    exact algebraic law / conservation / constructive sufficiency

TLA+ or SPIN
    temporal publication / interleaving / lifecycle ordering
```

A catalogue entry does not earn a formal model merely by existing.

# Production gate

```text
formal pressure
    -> research result
    -> RESEARCH_ONLY

real household operation requires the distinction
    -> DOGFOOD_REQUIRED
    -> implementation work
```

The catalogue is intentionally allowed to be much larger than the product.