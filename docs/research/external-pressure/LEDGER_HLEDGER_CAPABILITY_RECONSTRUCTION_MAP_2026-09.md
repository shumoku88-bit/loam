# Ledger / hledger Capability Reconstruction Map — September 2026

Status: **research map after adversarial review; capability-reconstruction hypothesis, not parity claim**

Baseline LOAM main for this reviewed version:

```text
efe74c24522fa1c238a645dc12a6cbab1c46369d
```

This document asks a deliberately narrower question than “does LOAM have all Ledger/hledger features?”

> For mature plain-text accounting capabilities, does LOAM need a larger neutral Core, or can the capability be reconstructed from the current small semantic families plus projections, policies, adapters, or separately typed additive evidence?

The point is not to imitate Ledger or hledger’s vocabulary. Their mature feature sets are used as pressure against LOAM’s current compression discipline.

Primary external references reviewed for this pass:

- hledger 1.52 manual: https://hledger.org/1.52/hledger.html
- hledger command overview: https://hledger.org/commands.html
- Ledger 3 manual / command reference: https://ledger-cli.org/doc/ledger3.html

Related LOAM checkpoints now live under the repository research tree:

- `../household/HOUSEHOLD_MINIMUM_VOCABULARY.md`
- `../household/HOUSEHOLD_COMPRESSION_STATUS.md`
- `EXTERNAL_ACCOUNTING_PRESSURE_SURVEY_2026-09.md`
- `../falsification/LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md`

## Reading the map

```text
R  RECONSTRUCTABLE / QUALIFIED IN THE SELECTED SCOPE
   Current LOAM evidence or already-qualified projections are sufficient for the
   narrow semantic question named in the row. This is not product parity.

A  ADDITIVE / CORE-PRESERVING CANDIDATE
   Some independently observable evidence or policy appears necessary, and a
   narrow additive representation is plausible. This has NOT qualified that
   Core expansion is unnecessary.

U  UNQUALIFIED
   LOAM has not yet earned a semantic claim strong enough to say how the feature
   should be reconstructed or whether an additive representation is sufficient.

S  SURFACE / TOOLING
   Primarily query, formatting, parsing, validation, generation, or interaction
   machinery. A particular implementation can still pull in A/U semantics.
```

The last column deliberately distinguishes three claims:

```text
No (selected scope)
    the already-qualified semantic question does not require a new neutral Core
    primitive.

Not demonstrated
    no Core-shape failure has been shown, but neither has its absence been proved.

Unknown
    the capability remains capable of exposing genuine Core-shape pressure.
```

This avoids the invalid inference:

```text
additive candidate looks plausible
    -> therefore Core expansion is impossible
```

---

# Capability map

| # | Ledger / hledger capability family | LOAM reconstruction candidate / pressure | Status | Neutral Core pressure reading |
|---|---|---|---|---|
| 1 | Journal transaction recording | `Event` + exact signed `Effect` over `Locus × Measure`; balanced Movement is a practical entrance where required | **R** | **No (selected scope)** |
| 2 | Multi-posting / balanced double-entry transaction | Balanced Movement admission; debit/credit presentation derived by Observation 110 | **R** | **No (selected scope)** |
| 3 | Account balances | quantity projection over selected Locus/Measure and correction frontier | **R** | **No (selected scope)** |
| 4 | Register / running balance | correction-aware quantity projection is qualified; ordering/tie-break semantics can be presentation policy unless independently observed | **R/A** | **Not demonstrated** |
| 5 | Print / journal export | persistence/rendering surface over retained evidence | **S** | **No by itself** |
| 6 | Account names and account selection | `Locus` identity plus naming/display policy; richer naming provenance remains optional pressure | **R/A** | **Not demonstrated** |
| 7 | Hierarchical accounts / depth-limited reports | hierarchy is more than typography when type inheritance, parent totals, or assertions depend on it; current LOAM has not qualified a general hierarchy law | **U/A** | **Unknown** |
| 8 | Account types such as asset/liability/equity/revenue/expense/cash | accounting-role overlay is plausible and Observation 110 separates accounting explanation from physical occurrence | **A** | **Not demonstrated** |
| 9 | Balance sheet | amount projection is easy once accounting roles are fixed, but the role authority itself is not yet a qualified production boundary | **A** | **Not demonstrated** |
| 10 | Income statement / profit and loss | accounting-role plus DateRange projection is plausible; recognition time can differ from payment/occurrence time and remains a known gap | **A/U** | **Unknown** |
| 11 | Cash-flow report | simple liquid-holding movement view is plausible, but “cash” role authority and valuation variants remain additive/unqualified | **A/U** | **Unknown** |
| 12 | Periodic daily/weekly/monthly/yearly quantity reports | DateRange / temporal query mechanics over Actual evidence | **R** | **No (selected scope)** |
| 13 | Filtering/query language | query surface over typed evidence; syntax is not canonical semantics | **S** | **No by itself** |
| 14 | Description / narration | practical `EventDescription` evidence already exists | **R** | **No (selected scope)** |
| 15 | Payee/payer-specific queries | likely separate Event-scoped evidence when free description is insufficient | **A** | **Not demonstrated** |
| 16 | Notes / tags / arbitrary metadata | generic metadata is deliberately not assumed; individual selected meanings may need typed evidence | **U/A** | **Unknown** |
| 17 | Unmarked / pending / cleared status | hledger/Ledger permit independent transaction/posting marks with user-defined meaning; this is not safely reducible to Scheduled lifecycle or reconciliation by name alone | **A/U** | **Unknown** |
| 18 | Reconciliation | occurrence is separable from reconciliation evidence, but publication/finality under later correction is still a documented gap | **U/A** | **Unknown** |
| 19 | Balance assertions / physical count assertions | Observation 201 / F086 proves external assertion is independent of reconstructed history | **A** | **Not demonstrated** |
| 20 | Discrepancy repair / balance adjustment | Observation 206 / F088 shows a bounded query-local repair/completeness representation can avoid invented Actual; broader repair workflows remain unqualified | **A** | **Not demonstrated** |
| 21 | CSV / bank import | adapter plus external identity/provenance plus fail-closed admission; source syntax is not Core | **S/A** | **Not demonstrated** |
| 22 | Duplicate-import prevention / matching | source-owned/imported identity and matching policy | **A/S** | **Not demonstrated** |
| 23 | Budget report / budget goals | current positive Remaining view composes from Capacity + routing + Actual; negative/debt-funded overspending remains a clear external-pressure gap | **R/A** | **Not demonstrated** |
| 24 | Forecast transactions | Scheduled + lifecycle + query horizon covers the selected commitment view; mature forecast/generation details remain additive | **R/A** | **Not demonstrated** |
| 25 | Periodic / recurring transaction rules | F055 proves recurrence shape does not determine generation policy; practical generation remains deferred | **A/U** | **Unknown** |
| 26 | Automated postings / rewrite rules | hledger/Ledger can generate report-time postings that change balances and interact with assertions; a safe LOAM policy/view boundary is not yet qualified generally | **U** | **Unknown** |
| 27 | Closing / opening transaction generation | mature `close` behavior generates zeroing/restoring postings and assertions and interacts with status, virtual/auto postings, dates, and costs; `QuantityBasis` answers a different starting-observation question | **U/A/S** | **Unknown** |
| 28 | Opening balance initialization | observed starting quantity is naturally `QuantityBasis`; parity with conventional generated opening-equity transactions is not claimed | **R/A** | **Not demonstrated** |
| 29 | Commodities / currencies | neutral `Measure` is already sufficient for the selected commodity-identity distinction | **R** | **No (selected scope)** |
| 30 | Historical prices / exchange rates | Measure-to-Measure Rate overlay remains outside physical Event; temporal authority/applicability is not complete | **A** | **Not demonstrated** |
| 31 | Market-value conversion | timed Rate evidence plus valuation policy is plausible, but rate applicability/source authority/rounding remain open | **U/A** | **Unknown** |
| 32 | Cost basis / lots | acquisition/disposal/source provenance has abstract separation; operational lot booking, splits, fees, average cost, and crossing long/short are not qualified | **U/A** | **Unknown** |
| 33 | Realised / unrealised gains | requires temporal valuation, cost basis, settlement/disposal provenance, authority, and exact arithmetic; external-pressure survey explicitly leaves operational laws open | **U** | **Unknown** |
| 34 | Multiple transaction/posting/effective dates | LOAM already resists one universal Event date, but exact mature-ledger auxiliary-date semantics and recognition-time interactions are not qualified | **A/U** | **Unknown** |
| 35 | Virtual postings / non-real accounting-only postings | Ledger/hledger distinguish postings that affect some reports while being removable from “real” views; current LOAM has no general qualified representation | **U** | **Unknown** |
| 36 | ROI / investment return reports | downstream calculation only after cash-flow, valuation, lot, and gain semantics are settled | **S/U** | **Unknown** |
| 37 | Account aliases / display rewrites | display aliases are surface policy; historical semantic rewriting must remain provenance-safe | **S/A** | **Not demonstrated** |
| 38 | `check` / journal validation | command is tooling, but individual checks can depend on assertions, balancing, chronology, types, and other semantic rules | **S/A** | **Not demonstrated** |
| 39 | `diff` between journals | comparison tooling over parsed/admitted evidence | **S** | **No by itself** |
| 40 | transaction generation from prior postings (`xact`-like) | drafting/generation surface; inference policy and admission provenance remain separate questions | **A/S** | **Not demonstrated** |

---

# Adversarial review findings

The first version of this map was too optimistic in several places. The review changed the interpretation in four important ways.

## 1. An additive candidate is not a proof that the Core will stay unchanged

The strongest correction is logical rather than accounting-specific.

```text
A-level candidate survived casual inspection
    !=
C-level pressure disproved
```

Only rows backed by an already-qualified selected semantic question get `No (selected scope)` in the Core-pressure column. Most `A` rows now say `Not demonstrated`, and `U` rows say `Unknown`.

This keeps the map consistent with the concept-pressure rule used after Observations 202–206.

## 2. High-level accounting reports inherit the uncertainty of account-role and recognition authority

hledger’s balance-sheet, income-statement, and cash-flow commands use account types such as Asset, Liability, Equity, Revenue, Expense, and Cash. Account type can be explicitly declared, inherited from a parent, or inferred by hledger.

Therefore:

```text
quantity projection exists
    !=
high-level accounting statement semantics qualified
```

LOAM Observation 110 shows that double-entry presentation can be derived from balanced Movement, but it deliberately does not make accounting explanation or period-recognition policy part of the neutral physical Event.

So BS/P&L/CF rows are additive or unqualified until accounting-role and, where relevant, recognition-time authority are earned.

## 3. Several “features” interact and cannot be reviewed as isolated rows

Mature plain-text accounting has cross-feature interference.

Examples from hledger/Ledger:

```text
status marks can exist at transaction/posting scope
balance assertions see statuses regardless of status filters
virtual postings can affect assertions while `--real` hides them from reports
auto postings can change balances and therefore change assertion outcomes
close generates assertions and can be disrupted by status/real/auto/date choices
```

This means a reconstruction map must attack compositions, not merely one row at a time.

The strongest future pressure is therefore not “does LOAM have virtual postings?” in isolation, but questions such as:

```text
Can one retained physical history support both
  real-only quantity truth
and
  accounting-only derived postings
while assertions remain provenance-correct?
```

That could expose a genuine semantic-plane boundary.

## 4. `QuantityBasis` does not automatically reconstruct conventional close/open semantics

LOAM’s `QuantityBasis` is strong evidence for the question:

> What quantity was observed at the application-origin cut without inventing earlier movement?

hledger `close`, however, can generate closing and opening transactions, restore balances, preserve costs, and emit balance assertions.

Those are not the same semantic question.

So opening initialization remains partly reconstructable, while full close/open generation is moved back to the unqualified frontier.

---

# What remains genuinely strong

The conservative review does not destroy the small-kernel hypothesis.

The strongest already-qualified reconstruction cases remain:

```text
neutral quantity-bearing occurrence       Event / Effect
balanced household Movement               balanced admission over Effects
debit / credit presentation               derived accounting view
raw balances                              quantity projection
period quantity reports                   temporal projection
description                               EventDescription
selected positive budget Remaining        Capacity + routing + Actual
selected forecast / Commitment             Scheduled + lifecycle + routing
starting observed quantity                QuantityBasis
commodity identity                        Measure
correction-aware quantities               Correction frontier
```

These are substantial capabilities built from relatively few semantic families.

The key hypothesis still survives in a weaker and more defensible form:

> Mature accounting surface breadth does not, by itself, imply proportional neutral-Core breadth.

What has *not* survived is the stronger shortcut:

> Every familiar Ledger/hledger feature already looks safely additive.

That is not supported.

---

# Current frontier clusters

The uncertain rows cluster into a few deeper problems rather than forty unrelated nouns.

```text
ACCOUNTING AUTHORITY
  account hierarchy
  accounting roles
  recognition time
  statement finality / reconciliation

DERIVED-POSTING SEMANTICS
  virtual postings
  automated postings
  close/open generation
  generated/inferred transactions

VALUATION
  temporal Rate authority
  market valuation
  lots / cost basis
  realised / unrealised gain

EPISTEMIC / SOURCE EVIDENCE
  status marks
  assertions
  import identity
  reconciliation
  arbitrary metadata meanings
```

This clustering itself supports compression pressure: several product features may share one deeper information boundary. But each cluster still needs direct falsification before production vocabulary is earned.

---

# What this does **not** establish

This map does not claim:

- option-for-option Ledger parity;
- option-for-option hledger parity;
- identical accounting conventions;
- identical query language or file syntax;
- investment/tax/ERP completeness;
- that every `A` row will survive a direct counterexample attack;
- that every `U` row can be handled additively;
- that LOAM as a whole will contain fewer lines of code;
- that UI, importers, parsers, report formatting, and operational tooling are small.

The narrower hypothesis is about **semantic-kernel size**.

A system can have a small semantic kernel and still have a large, capable shell.

---

# Next falsification rule

Do not open new observations merely to fill this table.

When dogfood blocks on one of the `A/U` clusters, ask:

```text
1. What exact user answer is independently observable?
2. Does current evidence already determine it?
3. If not, can one narrow additive typed family or query policy determine it?
4. Does that representation preserve provenance when combined with neighboring features?
5. Only if additive composition also fails, which existing Core family’s semantic shape is actually wrong?
```

Step 4 is the main addition from this adversarial review. Cross-feature composition is where Ledger/hledger pressure becomes strongest.

## Current reviewed conclusion

```text
broad accounting surface with small semantic kernel   PLAUSIBLE
feature breadth alone forces larger Event/Effect       NOT SUPPORTED
several important capabilities already reconstruct     YES
many mature features still additive/unqualified        YES
proven need for wholesale Core expansion                NONE
proven absence of future Core-shape pressure             NO
Ledger/hledger feature parity                            NOT CLAIMED
```

The useful next evidence should come from real dogfood or one concrete cross-feature failure, not from making the table greener.