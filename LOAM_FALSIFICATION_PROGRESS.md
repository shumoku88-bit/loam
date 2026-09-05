# LOAM Falsification Progress

Status: **F001-F200 reviewed; first near queue selected**

Baseline corpus:

```text
LOAM_FALSIFICATION_ATLAS.md        F001-F128
LOAM_FALSIFICATION_ATLAS_WAVE2.md  F129-F200
```

Selection checkpoint:

```text
LOAM_FALSIFICATION_SELECTION_2026-09.md
```

The Atlas files own specimen descriptions, attacked seams, and source context.
This file alone owns current Work / Finding / Queue / Runtime state.

## State model

```text
Work
  REVIEWED | READY | OBSERVING | DONE | DEFERRED | OUTSIDE

Finding
  UNTESTED | ABSORBED | COUNTEREXAMPLE | REDUNDANT

Runtime
  RESEARCH_ONLY | DOGFOOD_REQUIRED | IMPLEMENTING | IMPLEMENTED
```

Interpretation:

- `REVIEWED / UNTESTED`: full existing-evidence cross-reference found no direct bounded answer.
- `READY / UNTESTED`: selected into the small near formal queue, but no new result exists yet.
- `DONE / ABSORBED`: existing qualified evidence already supplies the selected distinction.
- `DONE / COUNTEREXAMPLE`: formal work directly showed a tested smaller candidate was too small.
- `COUNTEREXAMPLE` does not imply production implementation.
- `IMPLEMENTED` is used only where practical dogfood already required and obtained the capability.

## Default after selection

Every F001-F200 specimen has been reviewed.

Unless an ID appears in an exact READY or DONE override below:

```text
Work     = REVIEWED
Finding  = UNTESTED
Queue    = NONE
Runtime  = RESEARCH_ONLY
```

## Current counts

```text
Corpus total                        200
Cross-reference reviewed            200

DONE                                 54
  ABSORBED                           48
  COUNTEREXAMPLE                      6

READY                                 6
OBSERVING                             0
REVIEWED / UNTESTED                 140

Runtime IMPLEMENTED                   3
  F047
  F048
  F124
```

# Exact READY overrides

All READY specimens remain `Finding = UNTESTED` and `Runtime = RESEARCH_ONLY`.
Only one should normally advance to `OBSERVING` at a time.

| Order | ID | Attack seam | Selection reason |
|---:|---|---|---|
| 1 | F051 | known obligation vs unknown quantity | Directly challenges exact quantity-bearing Scheduled evidence with a tiny two-world distinction. |
| 2 | F033 | equal quantity vs different movement rights | Household-adjacent wallet pressure; asks whether quantity/location evidence answers future transfer/withdrawal rights. |
| 3 | F001 | temporary authorization reservation vs settled movement | Observation 050 explicitly left hold/reservation rights outside its boundary. |
| 4 | F076 | refund provenance through shared burden | Extends real shared-cost pressure beyond ordinary reimbursement/discharge into second-order refund meaning. |
| 5 | F055 | recurrence generation at shorter-month boundary | Series membership and replacement do not determine generated occurrence policy. |
| 6 | F086 | physical/external quantity assertion vs reconstructed history | Small external-truth conflict against a derived balance without presupposing adjustment/reconciliation nouns. |

Detailed scoring, watchlist, and re-ranking rules live in `LOAM_FALSIFICATION_SELECTION_2026-09.md`.

# Exact DONE overrides

## ABSORBED

| ID | Runtime | Existing bounded evidence |
|---|---|---|
| F009 | RESEARCH_ONLY | Observation 065 — refund/reimbursement is distinct from Correction; source occurrence survives. |
| F017 | RESEARCH_ONLY | PR #284 / Observation 125 — provider key is not lifecycle identity. |
| F018 | RESEARCH_ONLY | PR #281 / Observation 123 — pending/posted source quantity may drift while supporting one Actual. |
| F021 | RESEARCH_ONLY | PR #279 / Observation 121 — multiple feeds may support one Actual through reconciliation. |
| F022 | RESEARCH_ONLY | PR #279 + #283 — equal content does not determine source or occurrence identity. |
| F023 | RESEARCH_ONLY | PR #279 — one transfer-shaped Actual may retain multiple external observations. |
| F024 | RESEARCH_ONLY | PR #279 — source timing drift need not rewrite household occurrence time. |
| F028 | RESEARCH_ONLY | Observations 032-033 + 110; PRs #309-#312 — multi-Measure occurrence, valuation, authority and residual remain separate. |
| F041 | RESEARCH_ONLY | PR #305 / Observation 139 — negative Remaining does not determine funding composition. |
| F042 | RESEARCH_ONLY | PR #305 / Observation 139 — equal deficit may be cash- or liability-funded. |
| F046 | RESEARCH_ONLY | PR #285 + #301 — Capacity/unused carry and Backing continuity are independent. |
| F047 | IMPLEMENTED | Observation 111 / Practical Slice A2 — one Actual may route Effects to several Purposes. |
| F048 | IMPLEMENTED | Observation 111 / Practical Slice A2 — current routing does not rewrite historical routing. |
| F049 | RESEARCH_ONLY | Observation 064 — recurring content does not reconstruct Series membership. |
| F057 | RESEARCH_ONLY | PR #306 / Observation 140 — recognition is a policy/query-coordinate projection. |
| F058 | RESEARCH_ONLY | Observation 164 — open obligation plus later discharge covers payable-like structure. |
| F059 | RESEARCH_ONLY | PR #306 — service, invoice/payment timing and recognition authority are separable. |
| F060 | RESEARCH_ONLY | PR #306 — annual prepayment can project periodic recognition. |
| F062 | RESEARCH_ONLY | PR #306 — same payment can support different recognition views under authority. |
| F064 | RESEARCH_ONLY | PR #306 + #307 — recognition and as-published/restated horizons compose without closed-period truth. |
| F065 | RESEARCH_ONLY | Observation 164 — financed burden may precede bank cash settlement. |
| F074 | RESEARCH_ONLY | Observations 163-165 — later reimbursement can discharge established outside burden. |
| F075 | RESEARCH_ONLY | Observation 165 — one obligation may be discharged across several Events. |
| F078 | RESEARCH_ONLY | Observations 165 + 172 — one Event may discharge several relation units with endpoint identity preserved. |
| F081 | RESEARCH_ONLY | Observation 051 + PR #279 — confirmation/matching is not reconciliation. |
| F083 | RESEARCH_ONLY | PR #307 / Observation 141 — later correction need not erase earlier as-known answer. |
| F084 | RESEARCH_ONLY | PR #307 / Observation 141 — as-published and restated views coexist. |
| F089 | RESEARCH_ONLY | PR #309 / Observation 142 — occurrence, settlement and query coordinates may select different valuation inputs. |
| F090 | RESEARCH_ONLY | PR #310 / Observation 143 — provenance does not choose one scalar authority. |
| F094 | RESEARCH_ONLY | PR #311/#312 — residual preserves exact conversion; placement is separate authority. |
| F095 | RESEARCH_ONLY | Observation 033 + temporal valuation — reporting valuation remains projection context. |
| F096 | RESEARCH_ONLY | PR #309/#310 — retained temporal relation provenance preserves historical inputs. |
| F097 | RESEARCH_ONLY | Observations 066-067 — acquisition basis/provenance survives aggregation and differs from valuation. |
| F115 | RESEARCH_ONLY | Observation 111 — Purpose routing is separate evidence from Event quantity. |
| F116 | RESEARCH_ONLY | Observation 096 + bitemporal correction — effective and learned time differ. |
| F117 | RESEARCH_ONLY | PR #310 / Observation 143 — source candidates and scalar-selection authority are separate. |
| F120 | RESEARCH_ONLY | Observations 070-071 — current policy does not reconstruct historical policy definition. |
| F124 | IMPLEMENTED | Application 004 + WriterOwnership — exclusive ownership spans observe→prepare→admit→publish. |
| F127 | RESEARCH_ONLY | Observation 047/068 + replaceable query views — query policy is replaceable authority over evidence. |
| F128 | RESEARCH_ONLY | Application 006 — conservative fact extension adds evidence without rewriting old meaning. |
| F138 | RESEARCH_ONLY | Observation 048 — positive holding does not imply allocation/spending eligibility. |
| F146 | RESEARCH_ONLY | Observation 178 + discharge frontier — exact partial discharge and outstanding are representable. |
| F161 | RESEARCH_ONLY | Observations 172-173 + OpenRelation — one Effect may carry several quantity-bearing external relations. |
| F173 | RESEARCH_ONLY | PR #306 / Observation 140 — earning/recognition may differ from payment time. |
| F181 | RESEARCH_ONLY | PR #307 / Observation 141 — amendment may restate current view while preserving old publication. |
| F193 | RESEARCH_ONLY | Observation 050 — execution/initiation and later settlement are distinct. |
| F199 | RESEARCH_ONLY | Observations 070-071 — later convention change does not rewrite historical policy. |
| F200 | RESEARCH_ONLY | Observations 048 + 050 — equal quantity does not collapse settlement status or usable rights. |

## COUNTEREXAMPLE

| ID | Runtime | Direct falsification result |
|---|---|---|
| F044 | RESEARCH_ONLY | PR #285 / Observation 126 — Capacity + holdings do not determine per-Purpose Backing. |
| F045 | RESEARCH_ONLY | PR #285 / Observation 126 — Backing support and Capacity authority are not mutually determined. |
| F053 | RESEARCH_ONLY | PR #278 / Observation 120 — one-to-one ScheduledCompletion and quantity-free topology are too small. |
| F054 | RESEARCH_ONLY | PR #278 / Observation 120 — shared Actual realization requires quantity apportionment. |
| F073 | RESEARCH_ONLY | Observation 163 — physical payment does not determine economic burden allocation. |
| F099 | RESEARCH_ONLY | Observation 067 — aggregate holding/source set is too small; per-acquisition consumed quantity is observable. |

# Selection frontier

The corpus review is complete. The first near queue is now selected.

The preferred next mode is:

```text
F051 READY
  -> one deliberately small formal observation
  -> record ABSORBED or COUNTEREXAMPLE
  -> re-rank remaining READY/WATCHLIST
```

Do not open six observations in parallel.
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

# Production gate

```text
formal pressure
  -> research result
  -> RESEARCH_ONLY

real household operation requires the distinction
  -> DOGFOOD_REQUIRED
  -> implementation work
```
