# Ledger / hledger Capability Reconstruction Map — September 2026

Status: **reviewed through Observation 210; selected semantic reconstruction, not product parity**

Evidence baseline before this documentation update:

```text
64b8c203baaa531593c669ca46e1ad74af357be7
experiment: probe Ledger lot gain composition (#461)
```

Companion checkpoint:

- `LEDGER_HLEDGER_RECONSTRUCTION_CHECKPOINT_2026-09.md`

This map asks a narrower question than “does LOAM implement Ledger/hledger?”

> For selected mature plain-text-accounting semantics, does LOAM need a larger neutral Core, or can the answer be reconstructed from stable Event / Effect / Locus / Measure / Quantity identity plus additive typed evidence, explicit relations, policy, projection, generation, and admission?

Ledger and hledger are pressure sources, not target ontologies. Reconstruction does not imply a production type, writer, UI, parser, or command.

Primary external references used by this research pass:

- hledger 1.52 manual: https://hledger.org/1.52/hledger.html
- hledger command overview: https://hledger.org/commands.html
- Ledger 3 manual / command reference: https://ledger-cli.org/doc/ledger3.html

Related LOAM research:

- `EXTERNAL_ACCOUNTING_PRESSURE_SURVEY_2026-09.md`
- `../falsification/LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md`
- `../household/HOUSEHOLD_MINIMUM_VOCABULARY.md`
- `../household/HOUSEHOLD_COMPRESSION_STATUS.md`
- `../../../experiments/207_derived_posting_assertion_boundary.md`
- `../../../experiments/208_ledger_chart_status_date_boundary.md`
- `../../../experiments/209_ledger_generation_finality_boundary.md`
- `../../../experiments/210_ledger_lot_gain_composition.md`

## Reading the map

```text
R  RECONSTRUCTABLE / QUALIFIED IN THE SELECTED SCOPE
   Direct LOAM evidence is sufficient for the narrow semantic question named.

A  ADDITIVE / CORE-PRESERVING CANDIDATE OR RESIDUAL
   Additional evidence/policy is real but does not belong automatically in Core.
   R/A means a selected question is qualified while broader variants remain.

U  UNQUALIFIED
   LOAM has not earned a sufficiently strong semantic boundary yet.

S  SURFACE / TOOLING
   Primarily parsing, query syntax, formatting, validation, generation UI, or
   interaction machinery. Its inputs may still depend on R/A/U semantics.
```

Core-pressure readings:

```text
No (selected scope)
    direct evidence qualified the selected semantics without changing neutral
    Event / Effect / EffectKey shape.

Not demonstrated
    additive handling is plausible or partial, but the broader row has not been
    attacked strongly enough.

Unknown
    a genuine semantic boundary remains unqualified.
```

The governing rule remains:

```text
looks additive != Core-shape pressure disproved
```

Only direct qualified evidence earns `No (selected scope)`.

---

# Capability map

| # | Ledger / hledger capability family | LOAM reconstruction reading after Obs. 210 | Status | Neutral Core pressure reading |
|---|---|---|---|---|
| 1 | Journal transaction recording | `Event` + exact signed `Effect` over `Locus × Measure`; balanced Movement is a practical entrance where required | **R** | **No (selected scope)** |
| 2 | Multi-posting / balanced double-entry | balanced Movement admission; debit/credit presentation is derived rather than physical ontology | **R** | **No (selected scope)** |
| 3 | Account balances | correction-aware quantity projection over selected Locus / Measure | **R** | **No (selected scope)** |
| 4 | Register / running balance | correction-aware quantities are qualified; broader register ordering/display remains additive | **R/A** | **Not demonstrated** |
| 5 | Print / journal export | persistence/rendering surface over retained evidence | **S** | **No by itself** |
| 6 | Account names and account selection | `Locus` identity plus naming/display policy; richer naming provenance remains additive | **R/A** | **Not demonstrated** |
| 7 | Hierarchical accounts / depth-limited reports | Obs. 208: hierarchy changes subtree selection and role inheritance while remaining an additive relation over Locus | **R/A** | **No (selected scope)** |
| 8 | Account types / accounting roles | Obs. 049 separates Locus from AccountingRole; Obs. 208 qualifies inheritance and child override | **R/A** | **No (selected scope)** |
| 9 | Balance sheet | selected role classification plus quantity projection is reconstructable; complete statement/product authority remains additive | **R/A** | **No (selected scope)** |
| 10 | Income statement / P&L | role projection composes with independently qualified recognition/query-time boundaries; complete conventional policy not claimed | **R/A** | **No (selected scope)** |
| 11 | Cash-flow report | liquid/cash-role authority and richer cash-flow classification have not received an equivalent composition probe | **A/U** | **Unknown** |
| 12 | Periodic quantity reports | DateRange / temporal projection over retained Actual evidence | **R** | **No (selected scope)** |
| 13 | Filtering/query language | syntax and command language are surface policy over typed evidence | **S** | **No by itself** |
| 14 | Description / narration | practical `EventDescription` evidence exists | **R** | **No (selected scope)** |
| 15 | Payee/payer queries | likely separate Event-scoped evidence when description is insufficient | **A** | **Not demonstrated** |
| 16 | Notes / tags / arbitrary metadata | no generic metadata ontology is assumed; selected meanings must earn typed evidence separately | **U/A** | **Unknown** |
| 17 | Unmarked / pending / cleared status | Obs. 208 qualifies transaction status plus posting-specific override with report-vs-assertion selection | **R/A** | **No (selected scope)** |
| 18 | Reconciliation | occurrence is separable from reconciliation evidence; complete publication/workflow authority remains unqualified | **A/U** | **Unknown** |
| 19 | Balance assertions / physical count assertions | Obs. 201 separates assertion from reconstruction; Obs. 207 composes assertions with contribution planes and correction horizons; Obs. 209 adds prefix/order pressure | **R/A** | **No (selected scope)** |
| 20 | Discrepancy repair / balance adjustment | Obs. 206 qualifies bounded query-local repair/completeness without invented Actual; broader workflow remains additive | **R/A** | **No (selected scope)** |
| 21 | CSV / bank import | adapter plus source identity/provenance plus fail-closed admission; source syntax is not Core | **S/A** | **Not demonstrated** |
| 22 | Duplicate-import prevention / matching | source-owned identity plus explicit matching/admission policy | **A/S** | **Not demonstrated** |
| 23 | Budget report / goals | selected positive Remaining composes from Capacity + routing + Actual; debt-funded/negative variants remain separate pressure | **R/A** | **Not demonstrated** |
| 24 | Forecast transactions | Scheduled + lifecycle + routing + horizon reconstruct the selected commitment view; richer forecasting remains additive | **R/A** | **Not demonstrated** |
| 25 | Periodic / recurring rules | recurrence shape does not determine generation policy; practical generation authority remains deferred | **A/U** | **Unknown** |
| 26 | Automated postings / rewrite rules | Obs. 207 qualifies query-generated contribution as a separate policy plane affecting reports/assertions without becoming retained physical history | **R/A** | **No (selected scope)** |
| 27 | Close / open transaction generation | Obs. 209 qualifies selected close/open/retain/assign/assert generation, context-sensitive validation, ordering, and generated-vs-retained admission | **R/A/S** | **No (selected scope)** |
| 28 | Opening balance initialization | observed starting quantity is `QuantityBasis`; conventional generated opening is separate generation policy partly covered by Obs. 209 | **R/A** | **No (selected scope)** |
| 29 | Commodities / currencies | neutral `Measure` is sufficient for the selected commodity-identity distinction | **R** | **No (selected scope)** |
| 30 | Historical prices / exchange rates | Obs. 142–143 qualify valuation coordinate and rate/source-authority separation; market-data persistence/source-selection remain additive | **R/A** | **No (selected scope)** |
| 31 | Market-value conversion | temporal valuation is separate from occurrence; Obs. 210 qualifies selected cost-vs-market remaining value in the bounded specimen | **R/A** | **No (selected scope)** |
| 32 | Cost basis / lots | Obs. 066 separates basis from valuation, Obs. 067 qualifies quantity-bearing source provenance, Obs. 210 composes basis with disposal provenance; rich lot policy remains open | **R/A** | **No (selected scope)** |
| 33 | Realised / unrealised gains | Obs. 210 qualifies `basis + disposal provenance + proceeds + market valuation + report mode -> selected gain/value answers` | **R/A** | **No (selected scope)** |
| 34 | Multiple transaction/posting/effective dates | Obs. 208 qualifies transaction date plus posting-specific date override; other recognition/effective-time conventions remain additive | **R/A** | **No (selected scope)** |
| 35 | Virtual / accounting-only postings | Obs. 207 qualifies a distinct accounting-only contribution plane with consumer-specific selection law; no universal Effect flag is earned | **R/A** | **No (selected scope)** |
| 36 | ROI / investment return reports | downstream analytics still require cash-flow/time-weighting policy beyond the qualified valuation/gain pieces | **S/U** | **Unknown** |
| 37 | Account aliases / display rewrites | display aliasing is surface policy; semantic identity rewriting must remain provenance-safe | **S/A** | **Not demonstrated** |
| 38 | `check` / journal validation | command is tooling; several assertion/order/status inputs are qualified, but the complete validation rule set is not | **S/A** | **Not demonstrated** |
| 39 | `diff` between journals | comparison tooling over parsed/admitted evidence | **S** | **No by itself** |
| 40 | prior-posting transaction generation (`xact`-like) | drafting/inference surface; Obs. 209 qualifies generated-vs-retained separation, not a general inference policy | **A/S** | **Not demonstrated** |

---

# Cross-feature falsification completed after the adversarial review

The earlier map correctly moved several familiar features back to `A/U` or `U`: plausibility was not evidence. Observations 207–210 then attacked the strongest clustered uncertainties directly.

## Observation 207: derived/accounting-only contribution + assertion + correction horizon

One flat selected-balance scalar failed to determine assertion outcome or provenance. Explicit physical, accounting-only, and generated planes plus policy/assertion/horizon inputs determined the selected answers in the bounded model.

```text
classification: B / conservative additive composition
```

Selected virtual/auto/assertion pressure therefore no longer sits at `Unknown`.

## Observation 208: hierarchy + role + status + posting date

Hierarchy, inherited/overridden role, posting-specific status, and posting-specific date all changed legitimate selected answers. Explicit relations over existing Event / Effect / Locus identities determined report/assertion selection.

```text
classification: B / conservative additive composition
C-level Core-shape pressure: not demonstrated
```

## Observation 209: generation + assignment + selection context + assertion order

The probe established:

```text
generated values -/-> generation meaning
generation       -/-> retained history
final balance     -/-> prefix assertion result
```

Explicit mode, target, selection context, order policy, and admission inputs determined the selected outputs.

```text
classification: B / conservative additive composition
```

`QuantityBasis` still does not *mean* conventional close/open. Close/open is instead a separate reconstructable generation layer.

## Observation 210: acquisition basis + disposal provenance + gain/value

Earlier observations had already separated basis, valuation, disposal provenance, attribution, and historical policy. Obs. 210 composed:

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

Compressed candidates lost information; fixing the explicit inputs fixed the selected answers.

```text
classification: B / conservative additive composition
C-level Event/Effect/EffectKey pressure found: no
```

---

# Architectural reading at the checkpoint

Across selected mature Ledger/hledger semantics tested through Observation 210, the recurring architecture is:

```text
small neutral physical Core
+ independently observable evidence
+ explicit relations
+ policy / projection / generation
+ explicit admission when generated material becomes retained fact
    -> mature accounting answers
```

The research repeatedly found information that cannot be erased. It has not yet found that this information must be baked into neutral Event/Effect shape.

```text
small Core != few semantics
small Core  = stable identities onto which explicit semantic planes can attach
```

That is stronger evidence than the original statement that feature breadth merely *might* be reconstructable. The selected four cross-feature gates survived direct C-seeking attacks.

It is still not a proof about every future accounting capability.

---

# Residual frontier

```text
SOURCE / RECONCILIATION AUTHORITY
  import identity and matching
  reconciliation publication/finality workflow
  arbitrary metadata meanings

RULE ENGINES
  practical recurring-generation authority
  general rewrite/expression semantics
  xact-like inference policy

RICH INVESTMENT POLICY
  FIFO / LIFO / average-cost / specific-identification
  tax basis and fees
  splits, mergers, spin-offs, and other corporate actions
  short positions
  ROI / return methodology

SURFACE PARITY
  Ledger/hledger parser and file syntax
  query/expression language
  command-option compatibility
  exact formatting/workflow behavior
```

Version distinctions remain important. hledger 1.52 preserves cost/lot annotations and valuation distinctions but has more limited automated lot/gain machinery than Ledger 3. Ledger 3 has richer cost/lot/gain reporting, but that should not be inflated into an assumed automatic FIFO/LIFO engine.

---

# Non-claims

This map does not claim:

- option-for-option Ledger or hledger parity;
- parser, syntax, query-language, or command compatibility;
- identical accounting conventions;
- tax-accounting correctness;
- production `Account`, `Lot`, `CostBasis`, `VirtualPosting`, or status types;
- automatic FIFO/LIFO/average-cost/specific-identification;
- corporate-action or short-position completeness;
- production market-price persistence;
- full ROI/investment analytics;
- that every remaining `A/U` family will stay additive;
- that the whole LOAM application must remain small in lines of code.

The qualified claim concerns the **semantic-kernel boundary**.

---

# Stop / reopen rule

Do not add Ledger/hledger observations merely to make the table greener. This reconstruction line is checkpointed through Observation 210.

Reopen only when real dogfood, product work, or a concrete counterexample supplies a new hinge. Then ask:

```text
1. What exact user answer is independently observable?
2. Does retained LOAM evidence already determine it?
3. If not, what narrow additional evidence, relation, or policy is required?
4. Does it preserve provenance when composed with neighboring semantics?
5. Can generated answers remain distinct from admitted retained fact?
6. Only if explicit additive composition fails, which existing Core identity or
   semantic shape is actually insufficient?
```

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
