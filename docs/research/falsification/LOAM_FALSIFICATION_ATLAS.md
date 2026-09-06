# LOAM Falsification Atlas

Status: **catalogue-first falsification program**
Seed date: 2026-09-06
Baseline main when seeded: `00683648e86ef8a863cce7c4bc3ad323c2f582cf`

This document is a pressure catalogue, not a feature roadmap.

Its purpose is to try to falsify LOAM's current minimum-evidence hypothesis by collecting many externally real or structurally plausible worlds that may require distinctions not currently owned by canonical evidence.

The atlas starts from `HOUSEHOLD_COMPRESSION_STATUS.md` and `EXTERNAL_ACCOUNTING_PRESSURE_SURVEY_2026-09.md`, but deliberately widens beyond household-budget products into payment processing, bank feeds, wallets, debt, shared expenses, bookkeeping, ERP, investments, inventory, and synchronization.

## Falsification criterion

A candidate is important when we can construct two worlds such that:

```text
current LOAM canonical evidence is identical
but
a legitimate household/accounting query must return different answers
```

If such worlds exist, the current evidence boundary is too small for that query.

The response is **not** automatically to add a production type. First identify the missing independently observable information and qualify the boundary with the smallest useful formal instrument.

## Research state

```text
CATALOGUED
    collected but not yet extracted for a formal observation

READY
    high-value candidate extracted into the near queue

OBSERVING
    a bounded Alloy / Lean / TLA+ observation is active

QUALIFIED
    current evidence or a smaller information-equivalent boundary survived the selected bounded question

COUNTEREXAMPLE
    the tested evidence set was too small; a missing independent distinction was demonstrated

REDUNDANT
    subsumed by an earlier qualified observation

DEFERRED
    valid pressure, but intentionally postponed

OUTSIDE
    intentionally outside the current research horizon
```

`QUALIFIED` does not mean universally proved. It means qualified for the explicit bounded question recorded by the corresponding observation.

## Runtime state

Research and production are deliberately separate:

```text
RESEARCH_ONLY
    no production change follows from the research result

DOGFOOD_REQUIRED
    real household operation now needs the distinction

IMPLEMENTING
    production work exists because dogfood requires it

IMPLEMENTED
    the dogfood-required capability is present in production
```

Default rule:

> A counterexample may change the research model without changing production. Production implementation waits for real operational need.

This prevents the falsification corpus from turning into a feature wish list.

## Extraction order

Initial near queue, chosen for household relevance + ability to attack the current evidence boundary with a small specimen:

| Order | Atlas IDs | Pressure |
|---|---|---|
| 1 | F041-F042 | negative Remaining: cash-funded vs credit-funded |
| 2 | F001 | card authorization hold without capture |
| 3 | F017 | pending -> posted identity replacement |
| 4 | F025 | transfer sides with different dates |
| 5 | F033 | equal wallet quantity with different movement rights |
| 6 | F051 | certain obligation with unknown amount |
| 7 | F053 | partial Scheduled fulfillment |
| 8 | F057 | recognition time separate from payment |
| 9 | F083-F084 | reconciled/published past vs later correction |
| 10 | F089 | transaction/settlement/query FX rate separation |
| 11 | F113 | one-to-many correction |
| 12 | F073 | physical payer vs economic burden |

Only one small observation should normally be promoted at a time. The queue can be reordered whenever dogfood or a stronger counterexample changes the pressure.

## Catalogue

## A. Payment authorization / capture

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F001 | authorization hold exists but no capture | Occurrence vs temporary reservation | READY | P0-02 | RESEARCH_ONLY |
| F002 | authorization expires without capture | Temporary reservation vs completed movement | CATALOGUED | P1 | RESEARCH_ONLY |
| F003 | authorization amount is incremented before capture | Identity across changing authorized quantity | CATALOGUED | P1 | RESEARCH_ONLY |
| F004 | partial authorization covers only part of requested amount | Requested, authorized, and paid quantities diverge | CATALOGUED | P1 | RESEARCH_ONLY |
| F005 | one authorization is captured in several partial captures | One intent vs several realized movements | CATALOGUED | P1 | RESEARCH_ONLY |
| F006 | capture is smaller than authorization and remainder is released | Reservation release vs refund | CATALOGUED | P1 | RESEARCH_ONLY |
| F007 | tip/overcapture makes final capture exceed initial authorization | Earlier evidence does not determine final quantity | CATALOGUED | P2 | RESEARCH_ONLY |
| F008 | authorization visible as several pending entries then one posted entry | External observation identity vs economic identity | CATALOGUED | P1 | RESEARCH_ONLY |

## B. Refund / reversal / dispute

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F009 | full refund after settled purchase | Reverse movement vs correction of original meaning | CATALOGUED | P1 | RESEARCH_ONLY |
| F010 | several partial refunds against one purchase | One-to-many relation and remaining refundable quantity | CATALOGUED | P1 | RESEARCH_ONLY |
| F011 | refund requested but not yet received | Claim/expectation vs Actual | CATALOGUED | P1 | RESEARCH_ONLY |
| F012 | refund fails after being initiated | Lifecycle evidence vs mutable status | CATALOGUED | P1 | RESEARCH_ONLY |
| F013 | charge is disputed and funds are provisionally removed | Physical balance effect vs unresolved adjudication | CATALOGUED | P1 | RESEARCH_ONLY |
| F014 | dispute is won or lost after a long horizon | Knowledge time vs effective financial consequences | CATALOGUED | P2 | RESEARCH_ONLY |
| F015 | lost dispute later becomes a late win | Finality assumptions can be false | CATALOGUED | P1 | RESEARCH_ONLY |
| F016 | merchant credit is issued instead of cash refund | Restricted value vs ordinary money | CATALOGUED | P1 | RESEARCH_ONLY |

## C. Bank sync / external observation

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F017 | pending transaction becomes a new posted identity | Source identity replacement vs stable household identity | READY | P0-03 | RESEARCH_ONLY |
| F018 | pending amount differs from posted amount | Observation update vs correction vs separate facts | CATALOGUED | P1 | RESEARCH_ONLY |
| F019 | pending transaction disappears without posting | Observed intent-like trace vs Actual occurrence | CATALOGUED | P1 | RESEARCH_ONLY |
| F020 | posted transaction is later modified by institution | External authority can revise past observation | CATALOGUED | P1 | RESEARCH_ONLY |
| F021 | same bank account linked twice produces duplicate imports | Duplicate evidence vs duplicate occurrence | CATALOGUED | P1 | RESEARCH_ONLY |
| F022 | two source feeds report the same occurrence with different ids | Cross-source identity and provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F023 | bank supplies only posted data, never pending | Absence of evidence vs evidence of absence | CATALOGUED | P2 | RESEARCH_ONLY |
| F024 | posting date differs from actual merchant occurrence date | Multiple temporal coordinates | CATALOGUED | P1 | RESEARCH_ONLY |

## D. Transfer / settlement

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F025 | two sides of one transfer have different dates | Shared movement identity vs locus-local observation time | READY | P0-04 | RESEARCH_ONLY |
| F026 | transfer amount is shared but reconciliation state differs by side | Shared quantity vs locus-local external evidence | CATALOGUED | P1 | RESEARCH_ONLY |
| F027 | transfer includes an independent fee | Transfer topology vs consumption | CATALOGUED | P1 | RESEARCH_ONLY |
| F028 | cross-currency transfer has unequal source and destination quantities | Multi-Measure conservation and rate provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F029 | one outgoing transfer arrives as several incoming credits | One-to-many settlement relation | CATALOGUED | P1 | RESEARCH_ONLY |
| F030 | several outgoing items settle as one incoming amount | Many-to-one net settlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F031 | one side is observed now and counterpart days later | Incomplete topology under knowledge horizon | CATALOGUED | P1 | RESEARCH_ONLY |
| F032 | transfer is reversed after destination arrival | Reversal relation vs new independent movement | CATALOGUED | P2 | RESEARCH_ONLY |

## E. Restricted wallets / points / vouchers

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F033 | same numeric PayPay balance has Money vs Money Lite rights | Quantity equality vs future-movement rights | READY | P0-05 | RESEARCH_ONLY |
| F034 | PayPay Points can pay but cannot be sent to another user | Spendability vs transferability | CATALOGUED | P1 | RESEARCH_ONLY |
| F035 | payment consumes several balance classes by priority | Policy-selected source decomposition | CATALOGUED | P1 | RESEARCH_ONLY |
| F036 | receiver gets a different balance class due to identity-verification rules | Source kind does not fully determine destination kind | CATALOGUED | P1 | RESEARCH_ONLY |
| F037 | limited-time points expire | Temporal rights and destructive expiry | CATALOGUED | P1 | RESEARCH_ONLY |
| F038 | gift card can be spent only at selected merchants | Purpose restriction vs Locus/Measure identity | CATALOGUED | P1 | RESEARCH_ONLY |
| F039 | store credit cannot be withdrawn as cash | Economic value vs convertibility | CATALOGUED | P1 | RESEARCH_ONLY |
| F040 | voucher requires minimum purchase or excludes items | Context-dependent eligibility policy | CATALOGUED | P2 | RESEARCH_ONLY |

## F. Capacity / budget / backing

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F041 | negative Remaining from cash-funded overspend | Positive carry law under negative values | READY | P0-01 | RESEARCH_ONLY |
| F042 | same negative Remaining from credit-funded overspend | Funding provenance vs numeric Remaining | READY | P0-01 | RESEARCH_ONLY |
| F043 | mixed cash and credit fund one overspend | Composition provenance behind one projection | CATALOGUED | P1 | RESEARCH_ONLY |
| F044 | Capacity exists without sufficient Backing | Entitlement vs funding topology | CATALOGUED | P1 | RESEARCH_ONLY |
| F045 | Backing exists but no Capacity is granted | Holdings/funding vs permission to consume | CATALOGUED | P1 | RESEARCH_ONLY |
| F046 | unused Capacity carries but funding source changes | Capacity continuity vs Backing continuity | CATALOGUED | P1 | RESEARCH_ONLY |
| F047 | one Actual is routed across several purposes | Purpose attribution granularity | CATALOGUED | P1 | RESEARCH_ONLY |
| F048 | purpose routing changes after occurrence but old report must not change | Historical routing authority | QUALIFIED | DONE | RESEARCH_ONLY |

## G. Scheduled / recurrence / uncertainty

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F049 | scheduled date known but amount approximate | Intent with interval/tolerance rather than exact quantity | CATALOGUED | P1 | RESEARCH_ONLY |
| F050 | scheduled amount is a range | Non-point quantity expectation | CATALOGUED | P1 | RESEARCH_ONLY |
| F051 | obligation is certain but amount unknown | Existence evidence without quantity evidence | READY | P0-06 | RESEARCH_ONLY |
| F052 | amount known but due date unknown | Quantity evidence without temporal placement | CATALOGUED | P1 | RESEARCH_ONLY |
| F053 | one Scheduled is fulfilled by several Actuals | Partial fulfillment relation | READY | P0-07 | RESEARCH_ONLY |
| F054 | several Scheduled claims are paid by one Actual | Many-to-one fulfillment matching | CATALOGUED | P1 | RESEARCH_ONLY |
| F055 | monthly day 31 recurrence meets a shorter month | Generation policy at calendar boundary | CATALOGUED | P1 | RESEARCH_ONLY |
| F056 | recurrence moves around weekends/holidays without rewriting series | Series rule vs generated occurrence provenance | CATALOGUED | P1 | RESEARCH_ONLY |

## H. Recognition / obligation / service time

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F057 | annual insurance paid now but recognized over twelve months | Payment time vs recognition time | READY | P0-08 | RESEARCH_ONLY |
| F058 | invoice exists now but payment is due later | Claim/obligation vs cash movement | CATALOGUED | P1 | RESEARCH_ONLY |
| F059 | service is delivered before invoice is issued | Occurrence/service time vs billing time | CATALOGUED | P1 | RESEARCH_ONLY |
| F060 | same payment has different cash-basis and accrual views | Projection policy authority | CATALOGUED | P1 | RESEARCH_ONLY |
| F061 | service stops early and recognition schedule must change | Policy amendment without rewriting prior recognition | CATALOGUED | P1 | RESEARCH_ONLY |
| F062 | advance payment is allocated later to one or more invoices | Unallocated claim settlement vs allocation relation | CATALOGUED | P1 | RESEARCH_ONLY |
| F063 | deposit is refundable and not yet earned | Held resource vs revenue/expense meaning | CATALOGUED | P1 | RESEARCH_ONLY |
| F064 | escrow money is held physically but economically restricted | Control/ownership/availability distinctions | CATALOGUED | P2 | RESEARCH_ONLY |

## I. Debt / credit / interest

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F065 | one loan payment contains principal, interest, and fee | One cash movement with several economic burdens | CATALOGUED | P1 | RESEARCH_ONLY |
| F066 | interest rate changes over time | Timed policy applicability | CATALOGUED | P1 | RESEARCH_ONLY |
| F067 | interest accrues daily but is paid monthly | Accrual occurrence vs settlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F068 | early principal repayment changes future interest schedule | Future plan derived from current debt state/policy | CATALOGUED | P1 | RESEARCH_ONLY |
| F069 | late fee appears after missed due date | Temporal condition creates new obligation | CATALOGUED | P1 | RESEARCH_ONLY |
| F070 | purchase is converted to installments after original settlement | Later financing relation over historical Actual | CATALOGUED | P1 | RESEARCH_ONLY |
| F071 | debt is forgiven without cash movement | Liability change without physical money movement | CATALOGUED | P1 | RESEARCH_ONLY |
| F072 | credit limit changes independently of debt balance | Capacity-like credit availability vs liability quantity | CATALOGUED | P2 | RESEARCH_ONLY |

## J. Shared expense / claim / reimbursement

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F073 | one person pays 2000 but burden is 1000 each | Physical payer vs economic burden | READY | P0-12 | RESEARCH_ONLY |
| F074 | reimbursement arrives later | Burden settlement vs original payment | CATALOGUED | P1 | RESEARCH_ONLY |
| F075 | only part of reimbursement is received | Partial claim settlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F076 | group expense is later fully refunded | Refund provenance through shared burden graph | CATALOGUED | P1 | RESEARCH_ONLY |
| F077 | refund must be redistributed to participants | Second-order settlement and entitlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F078 | several bilateral debts are netted into one payment | Net settlement vs underlying claims | CATALOGUED | P1 | RESEARCH_ONLY |
| F079 | one participant disputes their share after payment | Burden policy amendment vs physical history | CATALOGUED | P2 | RESEARCH_ONLY |
| F080 | gift and reimbursement have same money flow but different burden meaning | Meaning not derivable from movement alone | CATALOGUED | P1 | RESEARCH_ONLY |

## K. Reconciliation / finality / assertions

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F081 | transaction is cleared but not reconciled | External confirmation stages | CATALOGUED | P1 | RESEARCH_ONLY |
| F082 | statement is reconciled at knowledge horizon K1 | Publication/reconciliation receipt | CATALOGUED | P1 | RESEARCH_ONLY |
| F083 | later correction changes an older reconciled period | Historical finality vs truth correction | READY | P0-09 | RESEARCH_ONLY |
| F084 | query asks both as-published and currently-restated statement | Two valid historical views | READY | P0-09 | RESEARCH_ONLY |
| F085 | external bank statement itself is corrected later | Authority revision provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F086 | physical cash count conflicts with derived balance | Assertion vs reconstructed history | CATALOGUED | P1 | RESEARCH_ONLY |
| F087 | broker holding assertion conflicts with transaction reconstruction | Quantity assertion across incomplete evidence | CATALOGUED | P1 | RESEARCH_ONLY |
| F088 | missing history can be padded or left unknown | Repair policy vs epistemic uncertainty | CATALOGUED | P1 | RESEARCH_ONLY |

## L. FX / multi-Measure valuation

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F089 | transaction, settlement, and query dates use different FX rates | Temporal rate applicability | READY | P0-10 | RESEARCH_ONLY |
| F090 | provider rate and user override conflict | Rate authority provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F091 | unpaid foreign claim has unrealised gain/loss | Current valuation without settlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F092 | settlement creates realised FX difference | Settlement-time valuation relation | CATALOGUED | P1 | RESEARCH_ONLY |
| F093 | refund uses a different rate from original purchase | Reverse movement does not cancel base-currency value | CATALOGUED | P1 | RESEARCH_ONLY |
| F094 | rounding leaves residual units | Exact conservation under quantization | CATALOGUED | P1 | RESEARCH_ONLY |
| F095 | same commodity is valued in several reporting currencies | Projection context rather than canonical conversion | CATALOGUED | P2 | RESEARCH_ONLY |
| F096 | historical rate source is unavailable later | Provenance preservation vs recomputation | CATALOGUED | P1 | RESEARCH_ONLY |

## M. Investments / lots / corporate actions

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F097 | same security acquired in several lots at different bases | Acquisition provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F098 | FIFO and average-cost policies give different gain | Policy-dependent projection over same evidence | CATALOGUED | P1 | RESEARCH_ONLY |
| F099 | one sale consumes parts of several lots | Many-source disposal provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F100 | stock split changes units without economic cash flow | Measure/unit transformation | CATALOGUED | P1 | RESEARCH_ONLY |
| F101 | return of capital reduces basis without changing shares | Valuation/basis change without quantity change | CATALOGUED | P1 | RESEARCH_ONLY |
| F102 | reinvested dividend is income plus acquisition | One external action vs multiple semantic effects | CATALOGUED | P1 | RESEARCH_ONLY |
| F103 | spin-off allocates basis across two securities | Historical basis transformation and policy | CATALOGUED | P2 | RESEARCH_ONLY |
| F104 | fractional share from merger is settled in cash | Corporate action plus disposal/settlement | CATALOGUED | P2 | RESEARCH_ONLY |

## N. Inventory / physical assets

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F105 | sales order commits but does not move stock or recognize revenue | Commitment vs physical/accounting occurrence | CATALOGUED | P2 | RESEARCH_ONLY |
| F106 | delivery moves stock before customer is invoiced | Physical movement vs receivable/revenue recognition | CATALOGUED | P1 | RESEARCH_ONLY |
| F107 | invoice recognizes revenue but stock was moved earlier | Independent document/evidence planes | CATALOGUED | P1 | RESEARCH_ONLY |
| F108 | customer returns goods before refund arrives | Reverse stock movement vs cash claim | CATALOGUED | P1 | RESEARCH_ONLY |
| F109 | partial return covers only some delivered units | Partial reversal relation | CATALOGUED | P1 | RESEARCH_ONLY |
| F110 | inventory valuation differs from selling price | Physical quantity vs valuation basis | CATALOGUED | P1 | RESEARCH_ONLY |
| F111 | asset depreciates without physical movement | Time/policy-driven value change | CATALOGUED | P2 | RESEARCH_ONLY |
| F112 | asset is impaired or revalued | Observation/policy-driven valuation without movement | CATALOGUED | P2 | RESEARCH_ONLY |

## O. Identity / correction / provenance

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F113 | one historical Event is corrected into two replacement Events | One-to-many correction provenance | READY | P0-11 | RESEARCH_ONLY |
| F114 | two duplicate Events are merged into one occurrence | Many-to-one correction provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F115 | amount is correct but Purpose routing was wrong | Correction plane separation | CATALOGUED | P1 | RESEARCH_ONLY |
| F116 | effective date is old but correction is learned today | Effective time vs knowledge time | CATALOGUED | P1 | RESEARCH_ONLY |
| F117 | two authoritative sources disagree on one amount | Conflicting provenance and authority | CATALOGUED | P1 | RESEARCH_ONLY |
| F118 | source withdraws previously supplied evidence | Retraction vs correction | CATALOGUED | P1 | RESEARCH_ONLY |
| F119 | same imported record is edited locally and refreshed remotely | Local annotation vs external authority | CATALOGUED | P1 | RESEARCH_ONLY |
| F120 | historical policy definition changes but old interpretation must remain | Policy provenance over time | QUALIFIED | DONE | RESEARCH_ONLY |

## P. Policy / tax / concurrency / system edges

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F121 | tax rule changes mid-period | Timed rule applicability | CATALOGUED | P2 | RESEARCH_ONLY |
| F122 | same transaction has different tax treatment by jurisdiction | Context-dependent policy | CATALOGUED | P2 | RESEARCH_ONLY |
| F123 | rounding is performed per line vs on document total | Policy-dependent exact arithmetic | CATALOGUED | P2 | RESEARCH_ONLY |
| F124 | two writers append related evidence concurrently | Writer ownership and ordering | CATALOGUED | P1 | RESEARCH_ONLY |
| F125 | offline device records facts then syncs after newer facts exist | Causal/knowledge ordering under merge | CATALOGUED | P1 | RESEARCH_ONLY |
| F126 | same external event is imported concurrently by two writers | Deduplication under concurrent provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F127 | query policy changes without changing historical facts | Replaceable current policy vs canonical evidence | CATALOGUED | P1 | RESEARCH_ONLY |
| F128 | a report requires information not present at original recording time | Forward-compatible conservative fact extension | CATALOGUED | P1 | RESEARCH_ONLY |

## Seed evidence and source families

The catalogue is intentionally broader than the exact claims already qualified in LOAM. Primary documentation used to seed concrete pressure families includes:

- Stripe payment documentation: authorization/capture, incremental authorization, partial authorization, multicapture, disputes and late wins.
- Plaid Transactions documentation: pending vs posted identity replacement, removals/modifications, duplicate feeds.
- Actual Budget documentation: transfer fields that are shared vs side-local, different transfer dates, approximate/range schedules, recurrence rules.
- PayPay help: PayPay Money / Money Lite / Points have different withdrawal/transfer capabilities and payment/transfer priority rules.
- ERPNext documentation: deferred accounting; Sales Order / Delivery Note / Sales Invoice / Payment Entry separations; stock ledger and COGS.
- GnuCash documentation: cleared vs reconciled states, lots, return of capital, loans, stock operations.
- Existing LOAM external pressure survey: negative Remaining, recognition timing, historical finality, temporal FX, inventory/COGS, investment booking, tax applicability, consolidation.

These sources justify the existence of pressure specimens. They do not make the corresponding LOAM conclusion in advance.

## Maintenance rules

1. Collect broadly before narrowing.
2. Prefer a two-world information test over copying a product noun.
3. Keep a candidate `CATALOGUED` until it is intentionally extracted.
4. Promote only a small number to `READY`.
5. When an observation finishes, update the atlas state and link the Observation/PR.
6. Do not delete failed ideas merely because LOAM survived them; a `QUALIFIED` specimen is evidence.
7. Mark genuine duplicates `REDUNDANT` rather than silently removing them.
8. Keep runtime state `RESEARCH_ONLY` unless real dogfood requires production behavior.
9. A discovered `COUNTEREXAMPLE` earns missing information, not automatically a new canonical object.
10. Periodically expand the corpus from new domains rather than only deepening familiar accounting cases.

## Next catalogue expansion

The first 128 specimens are deliberately not exhaustive. Good next source domains include:

- payroll withholding and employer benefits;
- insurance claims and deductibles;
- security deposits and escrow release;
- merchant gift cards and promotional credits;
- securities settlement failures and cash-in-lieu;
- taxes with carryforwards and credits;
- subscriptions with usage-based true-up;
- installment services / BNPL;
- chargeback representment and network fees;
- multi-party marketplace payouts;
- estates, trusts, and beneficial ownership;
- offline-first and multi-device household editing;
- statement import formats with lossy identity;
- account migration / institution merger;
- data deletion, redaction, and retained audit evidence.

The target is a living corpus, not a fixed count.
