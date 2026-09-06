# Ledger / hledger Capability Reconstruction Map — September 2026

Status: **reviewed reconstruction map through Observation 210; semantic-reconstruction checkpoint, not parity claim**

Evidence baseline before this documentation update:

```text
64b8c203baaa531593c669ca46e1ad74af357be7
experiment: probe Ledger lot gain composition (#461)
```

Companion checkpoint:

- `LEDGER_HLEDGER_RECONSTRUCTION_CHECKPOINT_2026-09.md`

This document asks a deliberately narrower question than “does LOAM have all Ledger/hledger features?”

> For selected mature plain-text-accounting semantics, does LOAM need a larger neutral Core, or can the answer be reconstructed from the current Event / Effect / Locus / Measure / Quantity identity plus additive typed evidence, explicit relations, policy, projection, generation, and admission?

Ledger and hledger are pressure sources, not target ontologies. A row marked reconstructed does not imply production implementation, syntax compatibility, or option-for-option parity.

Primary external references used by this research pass:

- hledger 1.52 manual: https://hledger.org/1.52/hledger.html
- hledger command overview: https://hledger.org/commands.html
- Ledger 3 manual / command reference: https://ledger-cli.org/doc/ledger3.html

Related LOAM research:

- `EXTERNAL_ACCOUNTING_PRESSURE_SURVEY_2026-09.md`
- `../falsification/LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md`
- `../../household/HOUSEHOLD_MINIMUM_VOCABULARY.md`
- `../../household/HOUSEHOLD_COMPRESSION_STATUS.md`
- `../../../experiments/207_derived_posting_assertion_boundary.md`
- `../../../experiments/208_ledger_chart_status_date_boundary.md`
- `../../../experiments/209_ledger_generation_finality_boundary.md`
- `../../../experiments/210_ledger_lot_gain_composition.md`

## Reading the map

```text
R  RECONSTRUCTABLE / QUALIFIED IN THE SELECTED SCOPE
   Direct LOAM evidence is sufficient for the narrow semantic question named in
   the row. This is not product parity.

A  ADDITIVE / CORE-PRESERVING CANDIDATE OR RESIDUAL
   Independently observable evidence or policy remains outside the neutral Core.
   In an R/A row, a selected core question is qualified but broader variants remain.

U  UNQUALIFIED
   LOAM has not yet earned a semantic claim strong enough to choose the boundary.

S  SURFACE / TOOLING
   Primarily query, formatting, parsing, validation, generation UI, or interaction
   machinery. Its inputs may still depend on R/A/U semantics.
```

The last column distinguishes:

```text
No (selected scope)
    a direct observation has qualified the named selected semantics without a
    new neutral Core primitive or a changed Event / Effect / EffectKey shape.

Not demonstrated
    an additive design is plausible or partly supported, but the row itself has
    not received enough direct pressure for the broader claim.

Unknown
    a genuine semantic boundary remains unqualified.
```

The important logical rule remains:

```text
looks additive
    !=
Core-shape pressure disproved
```

Only direct qualified evidence earns `No (selected scope)`.

---

# Capability map

| # | Ledger / hledger capability family | LOAM reconstruction reading after Obs. 210 | Status | Neutral Core pressure reading |
|---|---|---|---|---|
| 1 | Journal transaction recording | `Event` + exact signed `Effect` over `Locus × Measure`; balanced Movement is a practical entrance where required | **R** | **No (selected scope)** |
| 2 | Multi-posting / balanced double-entry transaction | balanced Movement admission; debit/credit presentation derived rather than stored as physical ontology | **R** | **No (selected scope)** |
| 3 | Account balances | correction-aware quantity projection over selected Locus / Measure | **R** | **No (selected scope)** |
| 4 | Register / running balance | correction-aware quantities are qualified; broader register ordering/display policy remains additive | **R/A** | **Not demonstrated** |
| 5 | Print / journal export | persistence/rendering surface over retained evidence | **S** | **No by itself** |
| 6 | Account names and account selection | `Locus` identity plus naming/display policy; richer naming provenance remains additive | **R/A** | **Not demonstrated** |
| 7 | Hierarchical accounts / depth-limited reports | Obs. 208 proves hierarchy can change subtree selection and role inheritance while remaining an additive relation over Locus identity | **R/A** | **No (selected scope)** |
| 8 | Account types such as asset/liability/equity/revenue/expense/cash | Obs. 049 separates physical Locus from AccountingRole; Obs. 208 qualifies parent inheritance and child override for the selected role query | **R/A** | **No (selected scope)** |
| 9 | Balance sheet | selected accounting-role classification plus quantity projection is reconstructable; complete statement policy and production role authority remain outside Core | **R/A** | **No (selected scope)** |
| 10 | Income statement / profit and loss | role projection composes with the independently qualified recognition/query-time boundary; full conventional statement policy is not claimed | **R/A** | **No (selected scope)** |
| 11 | Cash-flow report | liquid/cash-role authority and richer cash-flow classification have not received an equivalent direct composition probe | **A/U** | **Unknown** |
| 12 | Periodic daily/weekly/monthly/yearly quantity reports | DateRange / temporal query mechanics over retained Actual evidence | **R** | **No (selected scope)** |
| 13 | Filtering/query language | syntax and command language are surface policy over typed evidence | **S** | **No by itself** |
| 14 | Description / narration | practical `EventDescription` evidence already exists | **R** | **No (selected scope)** |
| 15 | Payee/payer-specific queries | likely separate Event-scoped evidence when description is insufficient | **A** | **Not demonstrated** |
| 16 | Notes / tags / arbitrary metadata | no generic metadata ontology is assumed; selected meanings must earn typed evidence separately | **U/A** | **Unknown** |
| 17 | Unmarked / pending / cleared status | Obs. 208 qualifies transaction status plus posting-specific override as additive evidence with report-vs-assertion selection | **R/A** | **No (selected scope)** |
| 18 | Reconciliation | occurrence remains separable from reconciliation evidence; complete reconciliation publication/workflow authority is still unqualified | **A/U** | **Unknown** |
| 19 | Balance assertions / physical count assertions | Obs. 201 separates external assertion from reconstruction; Obs. 207 composes assertions with real/accounting/generated planes and correction horizons; Obs. 209 adds prefix/order pressure | **R/A** | **No (selected scope)** |
| 20 | Discrepancy repair / balance adjustment | Obs. 206 shows bounded query-local repair/completeness can avoid invented Actual; broader repair workflow remains additive | **R/A** | **No (selected scope)** |
| 21 | CSV / bank import | adapter plus source identity/provenance plus fail-closed admission; source syntax is not Core | **S/A** | **Not demonstrated** |
| 22 | Duplicate-import prevention / matching | source-owned identity plus explicit matching/admission policy | **A/S** | **Not demonstrated** |
| 23 | Budget report / budget goals | selected positive Remaining composes from Capacity + routing + Actual; debt-funded/negative variants remain separate pressure | **R/A** | **Not demonstrated** |
| 24 | Forecast transactions | Scheduled + lifecycle + routing + query horizon reconstruct the selected commitment view; richer forecasting remains additive | **R/A** | **Not demonstrated** |
| 25 | Periodic / recurring transaction rules | recurrence shape does not determine generation policy; practical rule/generation authority remains deferred | **A/U** | **Unknown** |
| 26 | Automated postings / rewrite rules | Obs. 207 qualifies query-generated contribution as a separate policy plane that can affect reports/assertions without becoming retained physical history; rule-language parity remains outside scope | **R/A** | **No (selected scope)** |
| 27 | Closing / opening transaction generation | Obs. 209 qualifies selected close/open/retain/assign/assert generation, context-sensitive validation, ordering, and generated-vs-retained admission; full command behavior/cost handling remains additive | **R/A/S** | **No (selected scope)** |
| 28 | Opening balance initialization | observed starting quantity is `QuantityBasis`; conventional generated opening transactions are a separate generation policy now partly covered by Obs. 209 | **R/A** | **No (selected scope)** |
| 29 | Commodities / currencies | neutral `Measure` is sufficient for the selected commodity-identity distinction | **R** | **No (selected scope)** |
| 30 | Historical prices / exchange rates | Obs. 142–143 qualify valuation coordinate and rate/source-authority separation; concrete market-data persistence and source-selection policy remain additive | **R/A** | **No (selected scope)** |
| 31 | Market-value conversion | temporal valuation evidence/policy is separated from physical occurrence; Obs. 210 additionally qualifies cost-vs-market selected remaining value in the bounded lot/gain specimen | **R/A** | **No (selected scope)** |
| 32 | Cost basis / lots | Obs. 066 separates basis from valuation, Obs. 067 qualifies quantity-bearing acquisition-source provenance, and Obs. 210 composes acquisition-specific basis with disposal provenance; rich lot-booking policy remains unqualified | **R/A** | **No (selected scope)** |
| 33 | Realised / unrealised gains | Obs. 210 qualifies the bounded composition `basis + disposal provenance + proceeds + market valuation + report mode -> gain/value answers`; tax and rich investment policy remain outside scope | **R/A** | **No (selected scope)** |
| 34 | Multiple transaction/posting/effective dates | Obs. 208 qualifies transaction date plus posting-specific date override for selected report/assertion queries; other recognition/effective-time conventions remain additive | **R/A** | **No (selected scope)** |
| 35 | Virtual postings / non-real accounting-only postings | Obs. 207 qualifies a distinct accounting-only contribution plane with consumer-specific selection law; this does not earn a universal flag on Effect | **R/A** | **No (selected scope)** |
| 36 | ROI / investment return reports | downstream analytics still depend on additional cash-flow/time-weighting policy beyond the qualified valuation/gain pieces | **S/U** | **Unknown** |
| 37 | Account aliases / display rewrites | display aliasing is surface policy; semantic identity rewriting must remain provenance-safe | **S/A** | **Not demonstrated** |
| 38 | `check` / journal validation | validation command is tooling; several assertion/order/status inputs are now qualified, but the complete command rule set is not | **S/A** | **Not demonstrated** |
| 39 | `diff` between journals | comparison tooling over parsed/admitted evidence | **S** | **No by itself** |
| 40 | transaction generation from prior postings (`xact`-like) | drafting/inference surface; Obs. 209 qualifies generated-vs-retained separation but not a general prior-posting inference policy | **A/S** | **Not demonstrated** |

---

# What changed after the adversarial review

The earlier reviewed map intentionally moved several apparently additive features back to `A/U` or `U`. That was correct at the time: plausibility was not evidence.

Observations 207–210 then attacked the four strongest cross-feature clusters directly.

## 1. Derived/accounting-only planes can coexist with assertions and correction history

Observation 207 attacked:

```text
retained physical history
+ accounting-only contribution
+ query-generated contribution
+ balance assertion
+ correction-aware historical horizon
```

The flat candidates failed: one selected report scalar did not determine assertion outcome or provenance. The explicit layered candidate remained deterministic in the bounded model.

Result:

```text
B / conservative additive composition
```

This upgrades the selected pressure behind virtual postings, automated postings, and assertions. It does not create production `VirtualPosting` or `AutoPosting` types.

## 2. Hierarchy, role, status, and posting date are real information without becoming Event fields

Observation 208 showed that:

```text
hierarchy
role declaration + inheritance/override
transaction/posting status
transaction/posting date
report-vs-assertion selection policy
```

all affect legitimate selected answers. Flattening them loses information. Keeping them as explicit relations over existing Event / Effect / Locus identities fixes the selected answers.

Result:

```text
B / conservative additive composition
C / Core-shape pressure not demonstrated
```

This replaces the old `Unknown` reading for the selected hierarchy/status/date seam.

## 3. Generated output is not retained history, and final balance is not enough for prefix-sensitive validation

Observation 209 attacked close/open/retain/assign/assert generation together with selection context and Ledger-vs-hledger ordering pressure.

It established, in the bounded selected scope:

```text
generated values  -/-> generation meaning
generation        -/-> retention
final balance      -/-> prefix assertion result
```

while explicit generation mode, target/context/order/admission inputs determined the selected outputs.

Result:

```text
B / conservative additive composition
```

So `QuantityBasis` still does not *mean* conventional close/open. Instead, conventional generation can itself be reconstructed as a separate layer without rewriting physical Event history.

## 4. Basis, disposal provenance, market value, and gain compose without a new Lot-shaped Core

Observations 066–071 had already separated acquisition basis, disposal provenance, attribution, and policy history. Observation 210 composed the selected Ledger-style gain question:

```text
acquisition-specific basis
+ disposal provenance
+ sale proceeds
+ remaining market valuation
+ cost/market report mode
    -> realised gain
     + unrealised gain
     + selected remaining value
```

The compressed candidates failed, but the explicit-input candidate was deterministic.

Result:

```text
B / conservative additive composition
```

No C-level need to change `Event`, `Effect`, or `EffectKey` was found.

---

# Current architectural reading

Across the selected mature Ledger/hledger semantics tested through Observation 210, the recurring shape is now:

```text
small neutral physical Core
+ independently observable evidence
+ explicit relations
+ policy / projection / generation
+ explicit admission when generated material becomes retained fact
    -> mature accounting answers
```

The research has repeatedly found **missing information**, but has not yet found that the missing information belongs inside neutral Event/Effect shape.

That distinction matters:

```text
small Core
    !=
few semantics

small Core
    =
stable physical identities onto which multiple explicit semantic planes can attach
```

The evidence is now stronger than the earlier statement “feature breadth alone does not imply Core breadth”. For the selected attacked clusters, additive composition has survived direct C-seeking counterexample work.

It is still not a proof that every future accounting capability will do so.

---

# Residual frontier

The remaining uncertainty is narrower and less like “all of Ledger”. Important residuals include:

```text
SOURCE / RECONCILIATION AUTHORITY
  import identity and matching
  reconciliation publication/finality workflow
  arbitrary metadata meanings

RULE ENGINES
  practical recurring-generation authority
  general automated/rewrite expression semantics
  xact-like inference policy

RICH INVESTMENT POLICY
  FIFO / LIFO / average-cost / specific-identification policy
  tax basis
  fees
  stock splits, mergers, spin-offs, and other corporate actions
  short-position semantics
  ROI / return methodology

SURFACE PARITY
  Ledger/hledger parser and file syntax
  query/expression language
  command-option compatibility
  exact formatting and workflow behavior
```

These are not hidden claims of Core insufficiency. They are simply not qualified by the current observations.

A useful external-version distinction also remains:

- hledger 1.52 preserves cost/lot annotations and valuation semantics but does not provide the same automated lot/gain machinery as Ledger 3;
- Ledger 3 has richer cost/lot/gain reporting, but its documented behavior should not be inflated into an assumed automatic FIFO/LIFO engine.

Therefore the map should continue to name the selected semantic pressure instead of pretending “lot support” is one universal feature.

---

# What this does **not** establish

This map does not claim:

- option-for-option Ledger parity;
- option-for-option hledger parity;
- parser, journal-syntax, query-language, or command compatibility;
- identical accounting conventions;
- tax-accounting correctness;
- a production `Account`, `Lot`, `CostBasis`, `VirtualPosting`, or status object;
- automatic FIFO/LIFO/average-cost/specific-identification;
- corporate-action or short-position completeness;
- production market-price persistence;
- full investment/ROI analytics;
- that every remaining `A/U` family will stay additive;
- that LOAM as a whole must remain small in lines of code.

The qualified claim is about the **semantic-kernel boundary**.

A small semantic kernel can support a large and capable shell.

---

# Stop / reopen rule

Do not open more Ledger/hledger observations merely to make this table greener.

The reconstruction program is now considered **checkpointed through Observation 210**. Reopen it only when real dogfood, product work, or a concrete counterexample supplies a new hinge.

When that happens, ask:

```text
1. What exact user answer is independently observable?
2. Does retained LOAM evidence already determine it?
3. If not, what narrow additional evidence, relation, or policy is required?
4. Does it preserve provenance when composed with neighboring qualified semantics?
5. Can generated answers remain distinct from admitted retained fact?
6. Only if that explicit additive composition fails, which existing Core identity or
   semantic shape is actually insufficient?
```

C-level pressure should require an actual failure of step 6, not unfamiliar accounting vocabulary.

## Current reviewed conclusion

```text
selected broad accounting surface reconstructs over small Core     YES
Obs. 207 derived-posting/assertion composition                     B
Obs. 208 hierarchy/status/date composition                         B
Obs. 209 generation/finality/order composition                     B
Obs. 210 lot/gain/value composition                                B
C-level Event/Effect/EffectKey shape pressure found                NO
proven absence of all future Core-shape pressure                   NO
production implementation of all qualified semantics              NO
Ledger/hledger feature parity                                      NOT CLAIMED
next evidence should come from dogfood or concrete failure         YES
```
