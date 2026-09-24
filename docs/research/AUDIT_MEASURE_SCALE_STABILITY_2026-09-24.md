# D3 Measure scale stability audit — 2026-09-24

Status: **STRUCTURAL + TEMPORAL QUALIFICATION COMPLETE / PRODUCTION CANDIDATE UNDER CI**

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

### Production source correspondence candidate

The production implementation is deliberately one narrow administration
boundary: `Loam.MeasurePresentationAuthority.setScale`.

It acquires existing ownership scopes in this fixed order:

```text
scheduled.loam
    -> actual.loam
    -> current-quantity-anchor.loam
    -> capacity.loam
```

This corresponds to current production topology rather than introducing a new
generic lock graph:

- Scheduled multi-authority writers already use
  `ScheduledActualOwnership`: Scheduled -> Actual.
- CurrentQuantityAnchor publication already uses Actual -> Anchor.
- Capacity publication owns Capacity alone.
- Repository inspection found no current production
  Capacity -> Actual/Scheduled/Anchor reverse acquisition path.

Only after all four scopes are held does the administration boundary re-read the
current admitted images and the current Measure-presentation configuration.

The retained-use observation is structural and intentionally small:

```text
Actual                -> every retained Event Effect.measure
Scheduled             -> every ScheduledOccurrence.measure
Capacity              -> every CapacityMovement.measure
CurrentQuantityAnchor -> every Assertion.coordinate.measure
```

Actual correction and reversal evidence refers to retained Event identities; it
does not carry an independent quantity payload, so scanning every retained
Event Effect covers the Actual quantity-bearing family without inventing
frontier semantics.

The candidate behavior is:

```text
same effective scale
    -> safe no-op

different scale + used Measure
    -> refuse, explicit migration required

different scale + unused Measure
    -> encode
    -> sibling stage
    -> byte re-read
    -> typed re-decode
    -> atomic rename
```

Missing Measure-presentation configuration still means scale 0. Missing optional
CurrentQuantityAnchor and Capacity authorities mean empty use for those families;
malformed configured evidence fails closed. Scheduled lifecycle and Actual remain
required authority for this household administration path.

The surface-neutral entrance is
`HouseholdCommand.setMeasureScale`; the scriptable production surface is:

```text
loam measure-scale DATA_ROOT MEASURE SCALE
```

No Currency type, Quantity field, MeasureId field, retained migration marker,
generic migration framework, new Lean theorem, or second TLA+ model is added.

Integration qualification is intentionally about the implementation/model
correspondence:

```text
unused Measure scale change     -> allowed
used Actual Measure change      -> refused
used Scheduled Measure change   -> refused
used Capacity Measure change    -> refused
used Anchor Measure change      -> refused
same used scale                 -> byte-preserving no-op
malformed config                -> refused / byte preserving
missing config + scale 0        -> compatibility-preserving no-op
concurrent first-use publisher  -> serialized, then scale change refused
```

The concurrent case uses the real cross-process `WriterOwnership` boundary:
a first-use Actual writer acquires Actual before scale administration, publishes
while the administration process is blocked, then the administration process
acquires Actual and re-reads the newly-used Measure before deciding.

## Current stop point

The production candidate now exists and keeps the selected protocol narrow.
D3 closure waits only for the dedicated integration workflow to compile the
production boundary and qualify the retained-family and real first-use
concurrency cases above.

No additional formal-method instrument is currently indicated. Observation 328
already answered the historical distinguishability question, and Observation 329
already answered the temporal race question. The remaining evidence is concrete
source correspondence and production execution.
