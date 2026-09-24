# D3 Measure scale stability audit — 2026-09-24

Status: **STRUCTURAL + TEMPORAL QUALIFICATION COMPLETE / PRODUCTION IMPLEMENTATION OPEN**

Audit source: post-Generation-2 development delta finding D3.

## Root semantic question

LOAM already states that once a Measure has retained household quantities, its
fixed-point scale is stable and changing that scale requires an explicit
migration.

What still has to be shown before D3 can be closed?

## Blueprint reading

The relevant long-horizon commitments are:

- **B1 — One operational household authority:** operational meaning must not be
  silently rewritten.
- **B4 — Current answers are projections over retained provenance:** current
  presentation must not erase the provenance needed to interpret retained
  quantities.
- **B6 — Projection does not acquire authority by becoming convenient:** a
  presentation helper must not silently redefine household facts.
- **B8 — Formal methods and AI are evidence-producing instruments:** use the
  smallest instrument that answers the residual question.

The existing multi-currency boundary already makes the intended policy explicit:

```text
unused Measure
    -> scale may be selected

Measure with retained household quantity
    -> scale is stable
    -> changing it requires an explicit migration
```

Therefore this audit is not inventing a new scale policy.

## Structural observation

Current topology is projected in:

`docs/d2/measure_scale_stability_audit.d2`

The important seam is:

```text
measure-presentation.tsv
        |
        v
MeasurePresentation
        |
        +--> Record parsing
        +--> Correction / Scheduled-completion editable text
        +--> PTA export
        +--> Beancount/Fava export

retained Actual / Scheduled / Capacity quanta
        |
        v
Measure + exact integer Quantity

NO retained edge:
used Measure --------> historical scale / migration history
```

The config is therefore more than cosmetic after use: it participates in the
human interpretation of already-retained exact quanta.

## Obligation DAG

```text
D3: used Measure must not be silently reinterpreted
 |
 +-- D1  exact quanta remain integer and Measure-scoped
 |       -> Core Quantity / Measure / BalancedMovement
 |
 +-- P1  parse / format are exact and scale-bounded
 |       -> qualified MeasurePresentation boundary
 |
 +-- P2  current TUI and exporters share the convention
 |       -> Record / Correction / Scheduled completion / PTA / Beancount
 |
 +-- P3  policy already says scale is stable after retained use
 |       -> OPERATIONAL_MULTICURRENCY_BOUNDARY + ADDING_CURRENCY
 |
 +-- D2  no production writer/publisher enforces scale immutability
 |       -> config is directly editable; loadMetadata reads current file only
 |
 +-- R1  can current quanta + current config determine historical convention?
 |       -> bounded distinguishability question
 |
 `-- R2  if not, what is the smallest operational evidence / migration
         boundary that preserves the distinction?
```

## D — deterministic obligations

### D1 — exact retained representation

Closed.

Core Quantity is integer quanta. Measure identity is explicit and orthogonal to
the quantity. Changing presentation scale does not rewrite those bytes, which is
exactly why reinterpretation can occur without a persistence-format change.

### D2 — current enforcement inventory

Closed.

There is no Measure-presentation publisher or retained convention history in the
current code path. `loadMetadata` reads the current
`config/measure-presentation.tsv` and missing metadata defaults to scale 0.

The documented currency-addition procedure instructs the household to edit that
file directly.

Therefore runtime can currently observe only the present configuration, not a
qualified history of scale choices.

## P — previously earned obligations

### P1 — exact fixed-point conversion

Reused from `Loam.MeasurePresentation`.

No floating-point value or rounding is introduced. Excess fractional precision
is refused.

### P2 — shared practical consumers

Reused from the qualified multi-currency work.

The same convention is consumed by current Record parsing, correction and
Scheduled-completion editing, and PTA / Beancount presentation.

### P3 — retained-meaning policy

Reused from:

- `docs/research/OPERATIONAL_MULTICURRENCY_BOUNDARY_2026-09.md`
- `docs/ADDING_CURRENCY.md`
- `docs/research/falsification/CHAINED_MIGRATION_HISTORY_AUDIT_2026-09.md`

The policy is already explicit. D3 is an enforcement/evidence gap, not an
unresolved product-policy question.

## R — residual obligations

### R1 — proof / bounded structural distinguishability

**Closed by Observation 328.**

GitHub Actions run `35945061540`, Alloy 6.2.0 / Sat4j, qualified:

```text
ambiguousCurrentSnapshot                        SAT
silentScaleRewriteExists                        SAT
stableUseExists                                 SAT
CurrentSnapshotDeterminesHistoricalConvention   SAT counterexample
QualifiedSnapshotDeterminesHistoricalConvention UNSAT counterexample
```

Two worlds can therefore share the same current retained quantity and current
configuration while differing in the historical scale that gave the quantity
its human meaning.

Current-snapshot inspection alone is insufficient to enforce the documented
used-Measure scale-stability rule.

### R2 — policy-to-production correspondence

**Closed at protocol-selection level by Observation 329.**

Repository inspection identified four current retained-quantity authority
families:

```text
Actual
Scheduled
Capacity
CurrentQuantityAnchor
```

A naive `check unused -> later update scale` protocol is racy because first-use
quantity publication can occur between the check and update.

GitHub Actions run `35945792069`, TLA+ tools 1.7.4 / TLC, qualified:

```text
NaiveSpec + MeaningStable
    -> invariant violation, reachable first-use race

LockedSpec + MeaningStable
    -> PASS, 513 distinct states / complete explored state space

LockedSpec + NeverScale2
    -> invariant violation, proving pre-use scale change remains reachable

LockedSpec + NeverUsed
    -> invariant violation, proving quantity publication remains reachable
```

The selected production direction is therefore deliberately operational rather
than ontological:

```text
scale administration
    -> acquire retained-quantity authorities in compatible fixed order
    -> re-read them under ownership
    -> used Measure: refuse ordinary scale change
    -> unused Measure: atomically publish new presentation config
```

This does not require retaining scale on every Quantity, inventing a Currency
type, or adding a new lock to every quantity writer.

Explicit migration remains a separate future operation if a used Measure ever
really needs a scale change.

## Current stop point

This branch changes no production semantics.

D3 now has:

1. an existing retained-meaning policy;
2. a D2 ownership/consumer map;
3. an Alloy counterexample proving current-snapshot insufficiency;
4. a TLA+ counterexample for naive mutation ordering;
5. a TLA+ qualified candidate protocol that preserves both scale change before
   use and ordinary quantity publication.

The next step is a small production implementation of that administration
boundary, followed by source-correspondence and integration qualification.

Lean is not yet required. The remaining work is correspondence between the
qualified protocol and concrete WriterOwnership / persistence code, not a new
mathematical law.
