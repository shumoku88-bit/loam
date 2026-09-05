# LOAM Falsification Atlas — Wave 2

Status: **catalogue expansion; F129-F200**
Seed date: 2026-09-06
Baseline after Wave 1 merge: `65b243575df9ddeb03a43b6e04c3f602279c918a`

This file is an additive shard of `LOAM_FALSIFICATION_ATLAS.md`.

Wave 1 established F001-F128. This wave deliberately adds 72 specimens from pressure families that were weak or absent in the first catalogue. The purpose remains falsification of LOAM's minimum-evidence hypothesis, not feature collection.

The same criterion applies:

```text
current LOAM canonical evidence is identical
but
a legitimate household/accounting query must return different answers
```

If such a pair exists, the tested evidence boundary is too small for that query.

All Wave 2 entries begin as `CATALOGUED`. None is promoted to `READY` merely because it looks interesting. Extraction happens only after the 200-specimen corpus is reviewed as a whole.

Runtime remains `RESEARCH_ONLY` unless real household dogfood creates an operational requirement.

---

## Q. Insurance / claim / deductible

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F129 | insured loss occurs now but insurer has not accepted the claim | Physical loss vs claim recognition | CATALOGUED | P1 | RESEARCH_ONLY |
| F130 | claim is accepted but deductible means household bears first portion | Gross loss vs household burden allocation | CATALOGUED | P1 | RESEARCH_ONLY |
| F131 | insurer pays provider directly rather than reimbursing household | Benefit realization without household cash receipt | CATALOGUED | P1 | RESEARCH_ONLY |
| F132 | claim is partially approved and partially denied | One claim with several adjudicated burden outcomes | CATALOGUED | P1 | RESEARCH_ONLY |
| F133 | insurer initially pays then later recovers from another liable party | Benefit payment vs subrogation/recovery provenance | CATALOGUED | P2 | RESEARCH_ONLY |
| F134 | household receives an advance claim payment before final loss amount is known | Provisional settlement vs final entitlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F135 | replacement-cost benefit depends on later proof of replacement purchase | Conditional entitlement over later Actual evidence | CATALOGUED | P2 | RESEARCH_ONLY |
| F136 | policy coverage changes while a long-running claim remains open | Timed policy authority vs claim lifecycle | CATALOGUED | P1 | RESEARCH_ONLY |

Pressure sought: loss occurrence, claim, adjudication, household burden, insurer payment, and later recovery need not share one time or one movement.

---

## R. Escrow / deposits / restricted reserves

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F137 | mortgage payment contains principal plus money placed into escrow | One payment with debt settlement and restricted reserve funding | CATALOGUED | P1 | RESEARCH_ONLY |
| F138 | escrow balance is positive but unavailable for ordinary household spending | Holding quantity vs permitted-use rights | CATALOGUED | P1 | RESEARCH_ONLY |
| F139 | projected escrow shortage exists before actual balance becomes negative | Forecast obligation vs current holding | CATALOGUED | P1 | RESEARCH_ONLY |
| F140 | annual escrow analysis creates a surplus refund | Restricted reserve release vs ordinary income | CATALOGUED | P1 | RESEARCH_ONLY |
| F141 | annual escrow analysis increases future monthly collection | Current reserve evidence changes future Scheduled quantities | CATALOGUED | P1 | RESEARCH_ONLY |
| F142 | tax or insurance bill paid from escrow differs from earlier estimate | Estimated backing vs later Actual obligation | CATALOGUED | P1 | RESEARCH_ONLY |
| F143 | refundable security deposit is held for months then partly retained for damage | Conditional ownership/burden across return horizon | CATALOGUED | P1 | RESEARCH_ONLY |
| F144 | deposit is transferred from old service provider to new provider without becoming spendable cash | Beneficial continuity vs physical custodian movement | CATALOGUED | P2 | RESEARCH_ONLY |

HUD mortgage-escrow material explicitly distinguishes surplus, actual shortage, and projected/accrual shortage, creating useful pressure against treating a reserve balance as the whole answer.

---

## S. Buy Now, Pay Later / installments

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F145 | one purchase immediately creates four future installment obligations | One consumption occurrence vs generated debt schedule | CATALOGUED | P1 | RESEARCH_ONLY |
| F146 | first installment is paid at checkout while later installments remain claims | Partial immediate settlement vs remaining obligation | CATALOGUED | P1 | RESEARCH_ONLY |
| F147 | merchandise is returned after some installments have already been paid | Return/refund provenance across partially settled debt | CATALOGUED | P1 | RESEARCH_ONLY |
| F148 | merchant refund is approved but BNPL lender still shows installments due | Merchant adjudication vs lender obligation authority | CATALOGUED | P1 | RESEARCH_ONLY |
| F149 | missed installment creates a late fee without changing original purchase quantity | New obligation from lifecycle condition | CATALOGUED | P1 | RESEARCH_ONLY |
| F150 | autopay fails and bank separately charges overdraft or NSF fee | One failed settlement causing independent downstream cost | CATALOGUED | P1 | RESEARCH_ONLY |
| F151 | lender freezes future purchasing capacity after delinquency | Debt state vs future credit rights | CATALOGUED | P2 | RESEARCH_ONLY |
| F152 | unpaid BNPL debt is transferred to collection while original merchant purchase remains unchanged | Claim ownership/counterparty migration | CATALOGUED | P1 | RESEARCH_ONLY |

CFPB describes BNPL as installment credit, commonly four or fewer payments, with refund/dispute and late-fee pressures that are distinct from the merchant purchase itself.

---

## T. Subscription / recurring billing / proration

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F153 | subscription plan changes halfway through a prepaid billing period | Service entitlement vs payment period transformation | CATALOGUED | P1 | RESEARCH_ONLY |
| F154 | downgrade creates credit for unused service time | Negative future charge vs cash refund | CATALOGUED | P1 | RESEARCH_ONLY |
| F155 | unpaid old invoice exists when a plan change generates a proration credit | Credit entitlement may assume settlement that did not occur | CATALOGUED | P1 | RESEARCH_ONLY |
| F156 | billing-cycle anchor is reset and an immediate invoice is generated | Series identity vs billing-period coordinate replacement | CATALOGUED | P1 | RESEARCH_ONLY |
| F157 | trial adds service entitlement before any cash payment | Entitlement/consumption without payment evidence | CATALOGUED | P1 | RESEARCH_ONLY |
| F158 | cancellation stops renewal but service remains available until period end | Cancellation intent vs current entitlement termination | CATALOGUED | P1 | RESEARCH_ONLY |
| F159 | usage is accumulated during period and price becomes known only at true-up | Certain service occurrence with later quantity/price authority | CATALOGUED | P1 | RESEARCH_ONLY |
| F160 | same subscription history gives different credits under two billing algorithms | Historical evidence vs replaceable calculation policy | CATALOGUED | P2 | RESEARCH_ONLY |

Stripe documents proration against service periods, billing-cycle-anchor resets, and the awkward case where unpaid invoices can still lead to credits for unused time.

---

## U. Marketplace / platform payout / multi-party settlement

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F161 | one customer charge is later split among several sellers/providers | One incoming movement vs multi-party economic allocation | CATALOGUED | P1 | RESEARCH_ONLY |
| F162 | platform retains a fee while transferring remainder to seller | Gross customer payment vs platform revenue vs seller entitlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F163 | customer refund does not automatically reverse seller transfer | Refund relation vs independent downstream settlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F164 | seller transfer is partially reversed after a partial refund | Partial recovery relation over prior settlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F165 | asynchronous customer payment fails after seller transfer was already created | Upstream settlement failure after downstream movement | CATALOGUED | P1 | RESEARCH_ONLY |
| F166 | payout timing differs from customer charge and seller transfer timing | Charge, allocation, transfer, and bank payout use separate clocks | CATALOGUED | P1 | RESEARCH_ONLY |
| F167 | dispute consumes platform funds while seller already received payout | Liability/burden migrates across parties after settlement | CATALOGUED | P1 | RESEARCH_ONLY |
| F168 | allocated funds exist for a payment but are not yet platform-available or seller-paid | Restricted intermediate holding state | CATALOGUED | P1 | RESEARCH_ONLY |

Stripe Connect explicitly decouples customer charges from transfers and notes that refunds do not automatically reverse associated transfers.

---

## V. Payroll / withholding / benefits

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F169 | gross wage, take-home cash, and tax withholding differ on one pay event | Economic earning vs received cash vs third-party remittance | CATALOGUED | P1 | RESEARCH_ONLY |
| F170 | employer benefit is earned without appearing as cash take-home | Compensation entitlement vs cash movement | CATALOGUED | P2 | RESEARCH_ONLY |
| F171 | payroll deduction funds retirement or savings account owned by employee | Withheld from cash yet remains household asset acquisition | CATALOGUED | P1 | RESEARCH_ONLY |
| F172 | reimbursement for work expense is paid on same paycheck as wages | Same bank deposit with different burden/recognition provenance | CATALOGUED | P1 | RESEARCH_ONLY |
| F173 | bonus is earned in one period and paid in another | Earning/recognition time vs payment time | CATALOGUED | P1 | RESEARCH_ONLY |
| F174 | employer later issues corrected W-2/W-2c for prior-year wages or withholding | External authoritative correction of historical tax evidence | CATALOGUED | P1 | RESEARCH_ONLY |
| F175 | garnishment redirects part of earned pay to a creditor | Household earning vs legally directed settlement | CATALOGUED | P2 | RESEARCH_ONLY |
| F176 | payroll overpayment is later recovered through future paychecks | Correction/claim against future compensation | CATALOGUED | P1 | RESEARCH_ONLY |

IRS W-2c procedures provide direct real-world pressure for authoritative correction of previously reported wage and withholding evidence.

---

## W. Tax filing / withholding / credit carryforward

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F177 | tax is withheld throughout year but final liability is determined later | Prepayment/withholding vs final obligation | CATALOGUED | P1 | RESEARCH_ONLY |
| F178 | estimated tax payment is made before annual liability is known | Payment toward unresolved future obligation | CATALOGUED | P1 | RESEARCH_ONLY |
| F179 | prior-year overpayment is elected as next-year estimated-tax credit instead of cash refund | Entitlement transformed across tax periods without cash movement | CATALOGUED | P1 | RESEARCH_ONLY |
| F180 | one overpayment is split between cash refund and next-year credit | One entitlement with multiple realization routes | CATALOGUED | P1 | RESEARCH_ONLY |
| F181 | amended return changes previously published income, deduction, credit, or liability | Filed historical finality vs later authoritative restatement | CATALOGUED | P1 | RESEARCH_ONLY |
| F182 | government corrects a simple return error without taxpayer amendment | External authority correction vs household-authored correction | CATALOGUED | P2 | RESEARCH_ONLY |
| F183 | tax credit is earned in one year but limited and carried to another | Entitlement existence vs period applicability | CATALOGUED | P2 | RESEARCH_ONLY |
| F184 | refund is intercepted or offset against another government debt | Tax refund entitlement vs actual settlement destination | CATALOGUED | P2 | RESEARCH_ONLY |

IRS Publication 505 documents withholding, estimated payments, and election of prior-year overpayments into a later tax period; IRS amended-return guidance exposes later correction of filed historical facts.

---

## X. Interest / accrual / compounding

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F185 | interest accrues daily but is credited monthly | Earned quantity vs posted Actual | CATALOGUED | P1 | RESEARCH_ONLY |
| F186 | interest compounds after prior credited interest becomes principal | Derived basis changes future accrual | CATALOGUED | P1 | RESEARCH_ONLY |
| F187 | variable rate changes between two accrual days | Timed rate authority | CATALOGUED | P1 | RESEARCH_ONLY |
| F188 | account closes after interest accrued but before normal credit date | Accrued entitlement vs institution forfeiture policy | CATALOGUED | P2 | RESEARCH_ONLY |
| F189 | minimum-balance rule changes whether interest is earned | Eligibility predicate over balance history | CATALOGUED | P2 | RESEARCH_ONLY |
| F190 | average-daily-balance and daily-balance policies produce different interest from same movements | Calculation-policy dependence over identical Actual evidence | CATALOGUED | P2 | RESEARCH_ONLY |
| F191 | interest rate is stated annually but accrual/credit frequency differs | Rate representation vs temporal application mechanics | CATALOGUED | P2 | RESEARCH_ONLY |
| F192 | negative interest or account fee reduces balance without a purchase/transfer | Policy-driven quantity change without consumption semantics | CATALOGUED | P2 | RESEARCH_ONLY |

FDIC Regulation DD material distinguishes interest accrual, compounding, crediting frequency, variable rates, balance computation methods, and possible forfeiture before crediting.

---

## Y. Securities trade / settlement / entitlement timing

| ID | Falsification specimen | Attacked seam | Research | Queue | Runtime |
|---|---|---|---|---|---|
| F193 | stock trade executes on Monday but standard settlement occurs Tuesday | Trade occurrence vs cash/security settlement time | CATALOGUED | P1 | RESEARCH_ONLY |
| F194 | trade executes successfully but settlement later fails | Execution evidence does not imply completed transfer | CATALOGUED | P1 | RESEARCH_ONLY |
| F195 | securities are sold but cash is not yet settled/withdrawable | Economic disposition vs available-cash rights | CATALOGUED | P1 | RESEARCH_ONLY |
| F196 | purchase creates position exposure before cash settlement completes | Ownership/exposure query vs settlement query | CATALOGUED | P1 | RESEARCH_ONLY |
| F197 | dividend entitlement depends on record/ex-date timing rather than payment date | Ownership history vs later cash receipt | CATALOGUED | P2 | RESEARCH_ONLY |
| F198 | corporate action produces fractional entitlement that later becomes cash-in-lieu | Non-cash entitlement vs later settlement | CATALOGUED | P2 | RESEARCH_ONLY |
| F199 | brokerage changes settlement convention while historical trades keep old timing | Timed settlement policy provenance | CATALOGUED | P2 | RESEARCH_ONLY |
| F200 | identical trade and settlement quantities differ in immediately usable rights because one is unsettled | Quantity equality vs settlement-status rights | CATALOGUED | P1 | RESEARCH_ONLY |

The SEC's T+1 transition makes trade date and standard settlement date explicitly distinct and acknowledges settlement-fail pressure during transition.

---

## Wave 2 primary source families

The specimens above are seeded from a mix of authoritative product/regulatory documentation and deliberately bounded structural variants.

- CFPB BNPL overview and refund/dispute materials:
  - https://www.consumerfinance.gov/ask-cfpb/what-is-a-buy-now-pay-later-bnpl-loan-en-2119/
  - https://www.consumerfinance.gov/archive/newsroom/cfpb-takes-action-to-ensure-consumers-can-dispute-charges-and-obtain-refunds-on-buy-now-pay-later-loans/
  - https://www.consumerfinance.gov/ask-cfpb/do-buy-now-pay-later-bnpl-loans-have-fees-en-2118/
- Stripe Billing subscription proration and billing-cycle documentation:
  - https://docs.stripe.com/billing/subscriptions/prorations
  - https://docs.stripe.com/billing/subscriptions/billing-cycle
- Stripe Connect separate charges/transfers and allocated-funds documentation:
  - https://docs.stripe.com/connect/separate-charges-and-transfers
  - https://docs.stripe.com/connect/funds-segregation
- IRS 2026 withholding/estimated-tax and amended-return material:
  - https://www.irs.gov/publications/p505
  - https://www.irs.gov/newsroom/when-and-how-to-amend-a-tax-return
  - https://www.irs.gov/forms-pubs/about-form-w-2-c
- FDIC Truth in Savings / compound-interest material:
  - https://www.fdic.gov/consumer-compliance-examination-manual/vi-3-truth-savings
  - https://www.fdic.gov/consumer-resource-center/chapter-5-compound-interest
- HUD mortgage escrow material:
  - https://www.hud.gov/sites/documents/43301c2hsgh.pdf
- SEC T+1 settlement material:
  - https://www.sec.gov/newsroom/press-releases/2024-62

Source documentation establishes that the pressure exists in real systems. It does not establish what LOAM's answer should be.

## Corpus checkpoint after Wave 2

```text
Wave 1: F001-F128   128 specimens
Wave 2: F129-F200    72 specimens
                     ---
Total                200 specimens
```

Research-state policy after reaching 200:

1. Do not begin formal observation immediately.
2. Cross-reference F001-F200 against existing LOAM Observations.
3. Mark already-qualified cases `QUALIFIED` and genuine overlaps `REDUNDANT`.
4. Keep domain-valid but distant cases `DEFERRED` or `OUTSIDE` rather than deleting them.
5. Re-rank the remaining `CATALOGUED` cases by household relevance and falsification sharpness.
6. Promote only a small near queue to `READY`.
7. Run one bounded observation at a time.
8. Keep production `RESEARCH_ONLY` until dogfood makes an operational distinction necessary.

The next task is therefore **corpus review**, not implementation.