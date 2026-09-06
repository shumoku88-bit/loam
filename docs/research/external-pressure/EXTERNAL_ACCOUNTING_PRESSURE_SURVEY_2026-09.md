# External Accounting Pressure Survey — September 2026

Status: **external pressure inventory after household recording / Scheduled / Capacity checkpoint**

Survey date: 2026-09-04

This document asks a deliberately different question from a feature comparison:

> Where do mature personal-finance, plain-text accounting, bookkeeping, and ERP systems need special state, helper ledgers, exception workflows, paired records, lock rules, booking stages, or manual repair — and which of those pressures has LOAM not yet tested strongly enough?

The aim is not to copy the nouns of existing products. Mature software is used as pressure against LOAM's current evidence model.

The previous checkpoint is `HOUSEHOLD_RESEARCH_CHECKPOINT_2026-09.md`.

## Method

The sample intentionally spans several styles:

- household envelope budgeting: YNAB, Actual Budget;
- plain-text accounting: Beancount, hledger;
- personal-finance / multi-currency: Firefly III;
- small-business accounting: QuickBooks, Xero;
- ERP accounting: Odoo, ERPNext.

The survey prefers product documentation and maintainer design notes over feature-comparison articles.

Each pressure is classified as:

```text
MOSTLY QUALIFIED
    LOAM has already tested the important information boundary.

PARTIAL
    LOAM has the underlying separation, but an operational or temporal boundary remains.

CLEAR GAP
    the external pressure asks a household/accounting question LOAM has not yet directly qualified.
```

No new Practical Core type is proposed by this survey.

---

# Executive ranking

For the next formal observation, the strongest current candidates are:

| Rank | External pressure | LOAM status | Why it matters |
| --- | --- | --- | --- |
| 1 | negative Remaining / cash vs credit overspending | **CLEAR GAP** | directly household-relevant; Observation 137 tested positive unused Remaining but not deficit / debt-funded consumption |
| 2 | accounting recognition time separate from invoice, payment, delivery, or service use | **CLEAR GAP** | mature accounting systems create deferred schedules and multiple accounting entries because occurrence and recognition are different questions |
| 3 | historical finality: reconciled / filed / locked period versus later corrections | **CLEAR GAP / PARTIAL** | LOAM has append-oriented correction and knowledge horizons, but has not qualified statement-finality / period-publication semantics |
| 4 | temporal FX valuation and realised / unrealised exchange difference | **PARTIAL** | LOAM already separated Measure and Rate overlays, but not rate applicability, settlement-time gain/loss, conflicting rate authority, or rounding provenance |
| 5 | inventory / COGS recognition across physical stock and accounting views | **CLEAR GAP but lower household priority** | ERP systems maintain Stock Ledger + General Ledger because physical movement and accounting recognition/valuation differ |
| 6 | operational investment booking: crossing long↔short, self-reduction, stock splits, average cost, fees | **PARTIAL** | LOAM 066–071 already qualified acquisition/disposal provenance abstractly; operational booking laws remain untested |
| 7 | tax/localisation rule applicability | **CLEAR GAP but very broad** | mature ERPs grow ordered jurisdiction/context rules; likely policy pressure, but not yet a good next household observation |
| 8 | multi-company consolidation / elimination | **OUTSIDE CURRENT HOUSEHOLD HORIZON** | real difficulty, but weak immediate pressure for LOAM as a household system |

The top four are the useful frontier. The rest should not enlarge LOAM merely because accounting products have features for them.

---

# 1. Negative Remaining and debt-funded consumption

## External pressure

YNAB distinguishes **cash overspending** from **credit overspending**.

With funded credit-card spending, cash is moved from the spending category into a special Credit Card Payment category. With unfunded credit spending, the card liability grows but the corresponding cash is not reserved. YNAB therefore needs different visible states and different month-boundary behaviour for cash and credit deficits.

At month rollover:

- positive category Available amounts persist;
- cash overspending reduces next month's Ready to Assign;
- credit overspending becomes debt / underfunding pressure in the card payment category;
- the overspent spending category itself resets to zero rather than retaining the negative number.

This is not merely a colour choice. The same negative budget number has different consequences depending on **how the Actual was funded**.

Primary sources:

- https://support.ynab.com/en_us/credit-card-overspending-an-overview-HkMGpSbJs
- https://support.ynab.com/en_us/overspending-in-ynab-a-guide-ryWoxEyi
- https://support.ynab.com/en_us/when-the-month-rolls-over-a-guide-rkyyd6qC9

## LOAM coverage

Observation 137 qualified:

```text
previous Remaining
    = previous Capacity projection
    - previous Actual consumption
```

and showed that **positive unused Remaining carry** is distinct from Capacity-adjustment carry, Holdings, and Backing.

It did not test negative Remaining.

The checkpoint explicitly left this seam open.

## Missing question

The naive extension would be:

```text
carryUnused[purpose]
    applies equally to positive and negative Remaining
```

YNAB is pressure against assuming that law.

A negative `Remaining` may represent several physically different worlds:

```text
cash-funded overspend
    physical cash already left

credit-funded overspend
    liability increased
    cash may still be held

mixed cash + credit overspend
```

Those worlds can share the same Purpose, Capacity, and numeric Remaining while differing in debt / Backing / future cash pressure.

## Candidate Observation A

> Does negative Remaining cross a Capacity boundary under the same policy information as positive unused Remaining, or is funding provenance / liability evidence independently observable?

Small bounded specimen:

```text
same Purpose
same Capacity
same Actual consumption quantity
same Remaining = -2
same next DateRange

World Cash:
  consumption reduced a cash Holding

World Credit:
  consumption increased a liability / unsettled obligation
```

Questions:

- Can the same boundary rule produce the correct next Capacity and cash-availability answers in both worlds?
- Is `negative Remaining` itself sufficient?
- Does Backing or physical funding provenance recover the difference without a `CreditCardBudget` object?
- Can debt pressure remain a projection from existing occurrence + accounting-role / funding evidence?

**Recommended tool:** Alloy first.

**Do not introduce yet:** `DebtEnvelope`, `CreditCardPaymentCategory`, `OverspendKind`, or a new budget-cycle object.

This is the strongest next household observation.

---

# 2. Recognition time is not payment time

## External pressure

ERPNext's deferred accounting documentation says explicitly that invoice timing and recognition timing are different questions. A qualifying invoice amount is initially posted to a balance-sheet deferred account and then moved into income or expense over a service period.

ERPNext distinguishes:

```text
invoice date
payment / due date
service start/end
recognition posting date
```

and notes that credit terms change when cash is due while deferred accounting changes when income or expense is recognized.

Odoo similarly handles deferred expenses and deferred revenues by spreading recognition across multiple periodic entries rather than treating payment or invoice creation as the whole accounting meaning.

Primary sources:

- https://docs.frappe.io/erpnext/deferred-accounting
- https://docs.frappe.io/erpnext/deferred-expense
- https://docs.frappe.io/erpnext/process-deferred-accounting
- https://www.odoo.com/documentation/18.0/applications/finance/accounting/vendor_bills/deferred_expenses.html
- https://www.odoo.com/documentation/17.0/applications/finance/accounting/customer_invoices/deferred_revenues.html

## LOAM coverage

LOAM already has several adjacent separations:

```text
Scheduled != Actual
initiated != settled                 Observation 050
physical Locus != AccountingRole     Observation 049
physical movement -> double-entry view can be derived   Observation 110
```

But Observation 049 explicitly left **period recognition rules** outside its boundary, and Observation 050 explicitly left **accounting recognition timing** outside its boundary.

Current-main search also exposes no concrete deferred/accrual/receivable/payable recognition model.

## Missing question

A payment Event does not by itself tell us when an expense was consumed or revenue earned.

The dangerous shortcut is:

```text
physical Event effective time
    -> accounting recognition time
```

or:

```text
invoice / Scheduled time
    -> recognition time
```

Mature accounting systems repeatedly add schedules, deferred accounts, generated journal entries, posting dates, and review processes because those times can diverge.

## Candidate Observation B

> Can recognition over a DateRange be represented as an independent accounting overlay over existing physical / claim evidence without creating canonical Invoice, DeferredRevenue, DeferredExpense, or Accrual objects?

Bounded specimen:

```text
one annual service purchase
payment on day 0
service range [0,12)

World Immediate:
  all expense recognized at day 0

World Spread:
  1/12 recognized in each period

same physical payment evidence
same service range
```

Ask whether physical payment + DateRange determines accounting expense by period. It should not if recognition authority differs.

Then test the smaller candidate:

```text
physical / obligation evidence
+ service DateRange
+ recognition policy definition
+ query DateRange
    -> recognised accounting view
```

**Recommended tool:** Alloy first for information independence. TLA+ only later if recognition publication, cancellation, amendment, or concurrent period-close ordering becomes the question.

**Do not introduce yet:** `Invoice`, `DeferredExpense`, `Accrual`, `RecognitionSchedule` as canonical household nouns.

---

# 3. Reconciled / filed past versus later correction

## External pressure

QuickBooks treats each reconciliation's ending balance as the next reconciliation's beginning checkpoint. Its current documentation lists a recurrent failure mode: editing, deleting, voiding, moving, or unreconciling an already-reconciled transaction changes the prior ending balance and therefore breaks the next beginning balance. The repair workflow uses discrepancy reports, audit history, transaction recreation, special reconciliation, or re-reconciliation.

QuickBooks Desktop also documents undoing prior reconciliation or creating an offsetting adjustment in a special `Reconciliation Discrepancies` account.

Xero attacks the same class of problem with **lock dates**: transactions dated on or before the lock date cannot be added or edited by the affected users. Xero says lock dates are normally used for year-end or tax periods. Its product documentation also exposes awkward interactions between locked periods and later credit-note allocation because those allocations need accounting journals and can alter filed reports.

Primary sources:

- https://quickbooks.intuit.com/learn-support/en-us/help-article/statement-reconciliation/fix-issues-accounts-reconciled-past-quickbooks/L8lx6PQQ5_US_en_US
- https://quickbooks.intuit.com/learn-support/en-us/help-article/bank-feeds/fix-beginning-balance-issues-quickbooks-desktop/L04fjomHI_US_en_US
- https://central.xero.com/s/article/Set-up-and-work-with-lock-dates
- https://productideas.xero.com/forums/967139-purchase-orders-bills-inventory/suggestions/44960803-lock-dates-allocate-credit-notes-to-invoices-bil

## LOAM coverage

LOAM already has stronger append-oriented instincts than mutable-ledger repair workflows:

- Correction is explicit evidence rather than rewriting history;
- temporal / knowledge-horizon observations distinguish what was knowable when;
- reconciliation evidence has been studied separately from the underlying occurrence;
- historical-policy observations reject using a current definition to rewrite past meaning.

But those pieces do not yet answer a narrower publication question:

```text
A statement was reconciled / filed / published at horizon H.
Later evidence corrects an older occurrence.

What should a query for the old published statement return?
What should a current restated view return?
```

## Missing question

Two useful answers may need to coexist:

```text
as-published / as-reconciled answer
restated-current answer
```

A mutable ledger often solves this by freezing old rows or repairing the checkpoint. LOAM may be able to keep both answers without a `ClosedPeriod` object.

## Candidate Observation C

> Can a reconciliation/publication receipt bind a DateRange + knowledge horizon + selected evidence sufficiently to preserve an old statement while later corrections create a distinct restated projection?

Possible shape:

```text
published statement S
  range [0,30)
  knownThrough K1
  external statement evidence E

later Correction learned at K2 > K1
  effective inside [0,30)
```

Ask whether:

- `view(range, K1)` preserves the historical reconciled answer;
- `view(range, K2)` gives the corrected current answer;
- a lock flag is unnecessary for truth preservation;
- some explicit publication/reconciliation provenance is still required if the user asks “what did I sign off then?”.

**Recommended tool:** Alloy for static distinguishability first. TLA+ if the hard question becomes racing publication with a concurrent correction.

**Do not introduce yet:** canonical `ClosedPeriod`, mutable lock state, or discrepancy account.

---

# 4. Temporal foreign-exchange valuation and realised / unrealised gain

## External pressure

Xero has three dedicated system accounts around foreign-currency movement:

```text
Bank Revaluation
Realised Currency Gains
Unrealised Currency Gains
```

Its realised gain compares invoice/bill/credit-note creation with payment; unrealised gain values unpaid items using the current exchange rate. Its FX report also records which rate was used and whether it came from an external source or a user.

Firefly III's exchange-rate subsystem exposes a different set of practical compromises:

- the feature is relatively new and disabled by default;
- conversions target only one primary/base currency;
- changing the primary currency requires recalculation of converted amounts;
- missing/not-yet-calculated rates fall back to 1;
- historical rates are not downloaded;
- a transaction's explicit foreign amount may override calculated conversion.

These are strong signs that “a number relating two currencies” is not enough. Source, effective time, query time, settlement time, override authority, and rounding matter.

Primary sources:

- https://central.xero.com/s/article/Foreign-currency-accounts-in-the-chart-of-accounts
- https://central.xero.com/0/article/Foreign-Currency-Gains-and-Losses-report
- https://docs.firefly-iii.org/explanation/financial-concepts/exchange-rates/

## LOAM coverage

This is not a blank area.

Observation 032 earned neutral `Measure` rather than a built-in Currency primitive.

Observation 033 showed that a Measure-to-Measure relation can remain an overlay over the physical Event core. It explicitly did **not** establish:

- source / timestamp / validity interval of rates;
- one authoritative relation;
- historical versus present valuation choice;
- conflict resolution;
- safe arithmetic conversion semantics.

Observations 066–071 further separated historical valuation, acquisition basis, disposal provenance, and policy provenance.

So LOAM has already solved the *static ontology separation*. It has not solved temporal rate applicability.

## Candidate Observation D

> Given multiple Rate observations for the same Measure pair, what information determines the rate used for occurrence-time valuation, settlement-time realised gain, and current unrealised valuation?

Specimen:

```text
invoice / claim at day 0
payment / settlement at day 2
query at day 3

Rate R0 effective day 0
Rate R2 effective day 2
Rate R3 effective day 3
```

Potential projections:

```text
historical booked value
realised exchange difference
current unrealised exposure
```

Ask whether those are derivable from existing Event/settlement + timed Rate observations, or whether another independent valuation-policy definition is needed.

A second, separate observation may be needed for exact-quantity rounding / residual allocation. Do not mix that arithmetic problem into the first semantic observation.

**Recommended tool:** Alloy for applicability/authority. Lean later for exact rounding and conservation laws.

**Do not introduce yet:** stored `FXGainLoss` facts or currency-specific Core Events merely because Xero has special accounts.

---

# 5. Inventory and COGS: one physical stock event, several accounting consequences

## External pressure

ERPNext's sales flow separates several documents and ledgers:

```text
Sales Order        commitment
Delivery Note      stock movement
Sales Invoice      receivable + revenue + tax
Payment            clears receivable
```

A Sales Invoice can optionally also update Stock, in which case one document affects both Stock Ledger and General Ledger. ERPNext warns not to use that option if a Delivery Note already recorded the movement.

Its Delivery Note documentation also points to an immutable stock ledger that changes cancellation/backdating rules.

Primary sources:

- https://docs.frappe.io/erpnext/sales-invoice
- https://docs.frappe.io/erpnext/delivery-note

## LOAM coverage

LOAM can already represent exact quantities over `Locus × Measure`, has stable Effect identity, and has explored acquisition/disposal provenance plus accounting-role overlays.

But the current household project has not directly asked:

```text
physical stock leaves
    !=
expense/COGS recognition
    !=
revenue recognition
    !=
customer receivable
```

## Candidate pressure

This likely decomposes into already-ranked observations:

- recognition timing (Candidate B);
- acquisition/disposal provenance (066–071);
- temporal valuation (Candidate D).

Therefore inventory should **not** be the next observation. First test those smaller boundaries. Only reopen inventory if a concrete stock workflow still has an unanswered question after composition.

---

# 6. Investment booking: mature software still has sharp edges

## External pressure

Beancount's Vnext design document explicitly describes current booking problems:

- augmenting and reducing legs need different syntax;
- crossing from long to short currently requires disabling booking or splitting the transaction in the importer, and the document says neither solution is good;
- average-cost booking needs careful precision handling;
- trade matching needs retained “crumbs” from booking that connect reductions to augmenting postings;
- self-reductions are unintuitive and were not trivial to define, with transaction splitting as the workaround;
- stock splits were still an open design problem in that document.

hledger's current lot specification is similarly a pipeline of classification and inference rules. It explicitly distinguishes transacted cost from cost basis, carries acquisition basis across transfers, supports selectors/FIFO, handles split/consolidating transfers, and now auto-splits some transfer-with-fee shapes into explicit transfer + disposal portions.

Primary sources:

- https://beancount.github.io/docs/beancount_v3/
- https://hledger.org/SPEC-lots.html

## LOAM coverage

LOAM has already invested substantially here:

Observations 066–071 separated:

```text
historical valuation != acquisition basis
aggregate holding != quantity-bearing disposal provenance
policy-selected attribution != independently retained attribution
current policy != historical attribution
retained attribution != historical policy provenance
```

The practical audit deliberately earned **no** `Lot` or `CostBasis` type. Stable `EffectKey` was sufficient as an endpoint for the bounded provenance question.

Therefore the general statement “lot accounting is hard” is **not a new LOAM gap**.

## Remaining operational gaps

Concrete transaction laws still untested include:

- crossing long ↔ short in one occurrence;
- self-reduction / acquire-and-reduce in one occurrence;
- stock split / reverse split;
- average-cost precision;
- fee-in-kind causing partial disposal;
- corporate actions;
- jurisdiction-specific tax basis.

The 066–071 audit already says this area should reopen only when a practical acquisition/disposal workflow needs one of those answers.

**Decision:** watch, do not choose as next observation.

---

# 7. Transfer pairing and import reconciliation are painful outside, but LOAM already covered much of the boundary

## External pressure

Actual Budget models a transfer as two account transactions whose fields obey special synchronization rules:

Always synchronized:

```text
payee
amount
notes
schedule
```

Independent:

```text
cleared / reconciled state
category
usually date
```

Actual explicitly supports different dates on the two halves because the money may take days to arrive.

Its reconciliation tool separately tracks cleared and reconciled state against an external statement.

Primary sources:

- https://actualbudget.org/docs/transactions/transfers/
- https://actualbudget.org/docs/accounts/reconciliation/

## LOAM coverage

This external design is useful confirmation rather than a new frontier.

LOAM already has:

- one Event with multiple Effects rather than requiring a semantic pair of separately authoritative transaction rows;
- Observation 050: initiated != settled, including pending movement with unchanged physical holdings;
- reconciliation evidence separated from recorded claims;
- external observation / delivery / provider-continuity observations 121–125.

The remaining 050 exclusions include failure, cancellation, reversal, partial settlement, multiple settlement legs, fees, and legal finality. Those are real future pressures, but simple transfer pairing and bank-import identity do not currently justify another generic transaction object.

**Decision:** mostly qualified; revisit only with a concrete failure/partial-settlement/legal-finality case.

---

# 8. Tax and localisation: rule/context explosion

## External pressure

Odoo fiscal positions map default taxes and accounts to different taxes/accounts based on customer/vendor geography and business context. Multiple matching rules are resolved by sequence. Localisation packages ship country-specific fiscal positions.

Odoo's developer documentation represents localisation as country-specific data modules.

Primary sources:

- https://www.odoo.com/documentation/18.0/applications/finance/accounting/taxes/fiscal_positions.html
- https://www.odoo.com/documentation/18.0/developer/howtos/accounting_localization.html

This is classic rule-system pressure:

```text
same commercial occurrence
+ different jurisdiction / counterparty / date / tax status
    -> different accounting / tax treatment
```

## LOAM coverage

LOAM's policy-history observations are relevant but deliberately generic. It has not qualified tax jurisdiction, legal applicability, filing basis, tax-inclusive/exclusive pricing, thresholds, exemptions, or rule-priority semantics.

## Decision

This is a genuine gap, but too broad for the next household observation. Tax law can manufacture endless domain vocabulary if approached noun-first.

Only reopen from one concrete household tax question, then ask whether the selected answer requires new evidence or merely a time/context-sensitive policy overlay.

---

# 9. Consolidation and intercompany accounting

Mature business systems need company scopes, account mappings, elimination entries, intercompany synchronization, and consolidation adjustments.

This is genuine accounting complexity, but current LOAM is a household system and has no practical multi-entity requirement.

**Decision:** record as distant pressure, not a research priority.

---

# Cross-system pattern

The systems sampled do not reveal one missing grand accounting object. They reveal several recurring reasons software becomes ad-hoc:

## Pattern A — one numeric value hides different authority

Examples:

```text
negative budget balance
    cash deficit vs new debt

exchange rate
    occurrence valuation vs settlement valuation vs current valuation

lot quantity
    aggregate holding vs source-specific disposal basis
```

LOAM is already strong at asking whether identical numeric projections can hide different future-visible evidence.

## Pattern B — one date hides several temporal meanings

Examples:

```text
transaction date
settlement date
invoice date
due date
service date
recognition date
reconciliation statement date
filing / lock date
rate effective date
```

LOAM has temporal-coordinate machinery, but the external survey shows that **recognition**, **statement finality**, and **valuation applicability** are still distinct untested uses of time.

## Pattern C — mutable current state damages historical answers

Examples:

- QuickBooks past reconciliation changes;
- mutable current FX rates and recalculation;
- mutable booking / basis policy;
- tax/localisation rule changes.

LOAM already rejects several current-state reconstruction shortcuts, but reconciled/issued statement preservation is not yet a first-class tested question.

## Pattern D — mature systems grow helper ledgers when physical and semantic views diverge

Examples:

```text
Stock Ledger + General Ledger
Deferred accounts + recognition entries
FX revaluation / realised / unrealised accounts
Credit Card Payment category
reconciliation checkpoint + discrepancy report
```

The LOAM question should not be “which helper ledger should we copy?”.

It should be:

> What independent evidence makes the helper ledger necessary, and can its visible answers instead be projected from a smaller set of facts plus explicit authority?

---

# What the survey removes from the candidate list

The following should **not** be rediscovered as new observations merely because existing products look complicated there:

```text
generic transfer pairing
    -> LOAM multi-Effect Event + async settlement already pressure this

bank-import duplicate / provider identity
    -> Observations 121–125 already qualify the information boundary

generic envelope rollover / cycle / names
    -> Observations 131–138 already qualify the boundary

static valuation independence
    -> Observation 033

generic lot / cost-basis provenance
    -> Observations 066–071

double-entry presentation as canonical physical truth
    -> Observation 110 already rejects that collapse
```

External complexity confirms these observations were worthwhile, but confirmation alone is not a reason to add more concepts.

---

# Recommended next sequence

Do **not** implement a new accounting subsystem from this survey.

Use the ranked frontier:

```text
A. negative Remaining / funding provenance
        ↓
B. recognition time / service-period authority
        ↓
C. historical statement finality under later correction
        ↓
D. temporal Rate applicability / realised-unrealised FX
```

After each observation, stop if the current LOAM evidence already answers the question.

The goal is not to complete all four. The goal is to discover the first external pressure that actually forces information LOAM does not already have.

## Suggested first move

Observation A is the best next experiment because it is:

- directly relevant to household budgeting;
- a deliberate exclusion from Observation 137;
- visible in a mature envelope-budget product as special cash/credit behaviour;
- small enough for a bounded Alloy specimen;
- likely to test whether debt/funding provenance can remain outside the Capacity ontology.

A candidate question is:

> Two worlds have equal Purpose, Capacity, Actual consumption, and negative Remaining. One consumed cash; the other created credit-card debt. Can LOAM derive the next-period budget and available-cash answers without a new budget object, and what existing evidence must differ?

That is narrow enough to observe without inventing a `CreditCardBudget` concept.

---

# Survey conclusion

The household recording / Scheduled / envelope-budget chapter did not merely postpone mature-accounting complexity. It already eliminated several places where other systems need special transaction pairing, mutable budget containers, lot identities, or current-state reconstruction.

The most interesting remaining pressure is now concentrated around **orthogonal meanings of time and funding**:

```text
Capacity time
recognition time
settlement time
valuation time
publication / reconciliation horizon

physical cash funding
credit / liability funding
```

That is a much smaller frontier than “implement accounting software”.

Proceed by asking one bounded question at a time and continue to resist promoting familiar accounting nouns into canonical LOAM state until a future-visible answer actually requires them.
