# Observation 224 — Which onboarding histories fit zero-origin coverage?

Status: **QUALIFIED ENTRY-BOUNDARY CLASSIFICATION; NO NEW PRODUCTION PRIMITIVE**

Research starting point:

- LOAM `c7c05c275bdcedeb7477197f7ed561648132b061`
- household data `cb028c76d04f16d6e604d5ce8e25e71efc006e65`

## Question

After the production retirement of QuantityBasis, LOAM now answers current household quantity from:

```text
explicit finite ZeroOriginCoverage
+
correction-aware selected Event history
```

Does that smaller boundary also make LOAM easy to enter from several common starting situations?

In particular:

1. a genuinely new zero-start household coordinate;
2. a complete Ledger-family / journal-style historical import;
3. a person adopting LOAM today while existing balances already exist;
4. a truncated historical import plus observed balances;
5. a mixed migration where different coordinates have different evidence quality.

The goal is not to design an importer yet. The goal is to classify which evidence each entry shape actually needs before a generic import or origin ontology is invented.

## Prior qualified pressure

Observation 219 showed that the former five exact-zero QuantityBasis rows carried no quantity information beyond finite zero-origin completeness evidence.

Observation 221 rejected a generic `Coverage` ontology. Zero-origin completeness remains a question-specific evidence boundary rather than permission, visibility, presentation selection, accounting classification, or representation completeness.

Observation 222 showed that an observed state and retained Event history can overlap. When a snapshot already reflects a retained occurrence, simple addition double-counts it; a correction-stable overlap relation or an explicit non-overlap reconstruction invariant is required.

Observation 223 then qualified and landed the present production cut: current household balances no longer use QuantityBasis or BasisCut, and the five household balance coordinates are admitted independently by `ZeroOriginCoverage`.

So Observation 224 asks what this result means for *entry into LOAM*, not whether the current household cut was correct.

## First distinction: starting bookkeeping is not the same as starting from zero

The phrase "start a new household ledger" hides two different situations.

### A genuinely new coordinate

Example:

```text
new-wallet / jpy
created empty today
```

There is no earlier quantity and no omitted prior history.

This can truthfully begin with:

```text
new-wallet / jpy in ZeroOriginCoverage
```

and subsequent Events determine its current quantity.

### A new LOAM user with an old household

Example:

```text
bank / jpy = 100000 today
LOAM has no earlier bank history
```

The software is new, but the bank quantity is not.

Declaring this coordinate zero-origin would assert something false about the retained history. If the next Event is `bank -3000`, zero-origin arithmetic would answer `-3000` rather than `97000`.

Therefore:

```text
new application use
!=
zero-origin evidence
```

This is common onboarding pressure, not an exotic accounting edge case.

## Evidence axes that must remain separate

The entry cases expose at least four independent questions:

```text
1. occurrence evidence
   What retained changes are represented as Events?

2. completeness evidence
   Is the selected retained history complete from zero for this coordinate?

3. observed-state evidence
   Is a nonzero quantity known at an application/import boundary?

4. overlap evidence
   Does that observed state already reflect any retained Event occurrence?
```

A fifth concern, already observed in the historical-import arc, remains orthogonal:

```text
5. import identity / provenance continuity
   Which source occurrence is the same admitted LOAM occurrence across runs or later relations?
```

A file parser can answer none of questions 2–5 merely by successfully producing Event-shaped rows.

## Case A — true zero-born coordinate

Shape:

```text
explicit zero-complete boundary
+
post-boundary Events
```

Result:

```text
ZeroOriginCoverage is sufficient
```

For a covered coordinate `c`, let `E(c)` be the correction-aware sum of selected Event effects.

Then:

```text
Q(c) = E(c)
```

No starting quantity identity, quantity column, correction graph, or overlap relation is required.

This is the cleanest use of the current production model.

## Case B — complete historical import

Suppose a Ledger-family or journal-style source is imported into selected LOAM Events and the import process can independently justify that the selected retained history is complete from zero for coordinate `c`.

Then the same shape works:

```text
imported selected Events
+
explicit zero-origin completeness evidence
```

and:

```text
Q(c) = E(c)
```

This is important because the importer does not need to manufacture a QuantityBasis row merely because the data came from another system.

But the completeness assertion must be independent of Event activity.

The following do **not** establish zero-origin coverage:

```text
source file parsed successfully
coordinate appears in an Event
coordinate appears in balance-view
current source balance happens to be zero
this is the first row seen by the importer
this is the only file handed to the importer
```

A source may have older archives, omitted includes, an intentionally truncated export, or opening state represented outside the imported slice.

Therefore the safe pipeline is conceptually:

```text
source records
    -> Event admission

source/import scope evidence
    -> ZeroOriginCoverage, only where justified
```

The two arrows must not be collapsed.

### Import identity remains a separate problem

Even a quantity-complete import may still lack stable source-owned occurrence identity.

The earlier import observations already established that run-local identity can support only identity-renaming-invariant read-only questions, while continuity-sensitive publication requires a separate admission/provenance story.

Therefore:

```text
zero-origin completeness
!=
import identity continuity
```

Observation 224 does not reopen or solve that identity problem.

## Case C — adopt LOAM today with existing balances and no history

Shape:

```text
observed bank = 100000
no retained pre-adoption Events
later Events only
```

ZeroOriginCoverage is not sufficient because the omitted pre-adoption history contributed real quantity.

The natural arithmetic shape is instead:

```text
Q(c) = O(c) + E(c)
```

where `O(c)` is an observed origin quantity and selected `E(c)` contains only non-overlapping retained Events after that origin boundary.

This is precisely the pressure for a possible future narrow form such as:

```text
OriginSnapshot : EffectCoordinate ->? Quantity
```

but Observation 224 does **not** add that type to production.

The paper classification only establishes that ordinary onboarding can produce nonzero-origin pressure. A concrete writer, persistence shape, boundary semantics, correction policy, and historical-backfill policy still need qualification before such a primitive is earned.

## Case D — truncated history plus an observed boundary balance

Example:

```text
source contains only 2026 history
bank balance at start of retained slice = 100000
retained later Events sum = -30000
current quantity = 70000
```

Treating the truncated slice as zero-origin would give `-30000`, which is wrong.

A non-overlapping observed origin would give:

```text
100000 + (-30000) = 70000
```

So a truncated import and a complete import must not share one silent "import succeeded" admission rule.

### Opening reconstruction remains deliberately unresolved

Another possible representation is an explicit reconstructed opening Event that introduces the starting quantity before the retained slice.

That may allow a cut-free zero-origin normal form in some import policies, but the equivalence is not qualified here.

In particular, an importer must not silently fabricate an opening occurrence merely to force every source into the current Event + ZeroOriginCoverage shape. A source-authored or explicitly reconstructed opening fact and an importer-invented balancing Event are not assumed equivalent by Observation 224.

This remains future pressure.

## Case E — snapshot plus overlapping retained history

Shape:

```text
observed state O
+
retained Event occurrence already reflected in O
```

Naive addition double-counts the occurrence.

At one coordinate, the explanatory shape becomes:

```text
Q(c) = O(c) + E(c) - reflectedOverlap(c)
```

but Observation 222 already showed why `reflectedOverlap` cannot in general be replaced by one static arithmetic adjustment if the overlapping Event is later corrected.

Therefore a future snapshot-capable importer must choose an explicit policy:

```text
A. enforce non-overlap by reconstruction/rebase
or
B. retain correction-stable overlap evidence
```

It must not quietly install a snapshot over an arbitrary retained Event world.

## Case F — mixed migration is coordinate-scoped

A realistic migration may look like:

```text
bank / jpy
  complete imported history
  -> zero-origin coverage justified

cash / jpy
  only current observed balance
  -> nonzero origin pressure

old-card / jpy
  partial activity, no trustworthy opening state
  -> unknown
```

This is a useful negative result.

One global household mode such as:

```text
ImportMode.complete
ImportMode.snapshot
```

is too coarse.

The evidence quality is naturally scoped at least to `EffectCoordinate`.

That does **not** yet earn a generic `EntryEvidence` sum type in Core. It only constrains any future importer or onboarding surface not to flatten heterogeneous coordinates into one global claim.

## Case G — incomplete history with no trustworthy origin

If LOAM has:

```text
some Events for c
no zero-origin completeness evidence
no trustworthy observed origin
```

then the correct answer is still:

```text
unknown / refuse current quantity
```

Event activity is not a substitute for historical completeness.

This preserves the production rule:

```text
missing != zero
```

through the import boundary as well.

## Same quantity does not mean same evidence

Two entry worlds can have the same current numerical answer while supporting different future operations.

Example:

```text
World A: complete history
  +100
   -30
  current = 70

World B: observed origin
  origin = 100
  later Event = -30
  current = 70
```

The current quantity agrees, but the evidence is not interchangeable.

A later historical backfill or correction can distinguish them.

Therefore:

```text
current quantity equality
-/->
origin-evidence equivalence
```

This is the same broader LOAM pattern seen elsewhere: a projection may collapse distinctions that a later operation can still observe.

## Negative-control matrix

| Candidate shortcut | Result |
| --- | --- |
| Event activity implies zero-origin completeness | **REJECT** |
| balance-view selection implies completeness | **REJECT** |
| parser success implies complete history | **REJECT** |
| first imported row defines historical origin | **REJECT** |
| current balance equals zero, therefore zero-origin | **REJECT** |
| new LOAM user, therefore zero-origin | **REJECT** |
| truncated history can be admitted as zero-origin | **REJECT** |
| snapshot + arbitrary retained history can be simply added | **REJECT** |
| one global import mode classifies every coordinate | **REJECT** |
| complete history + independent completeness evidence can use ZeroOriginCoverage | **ADMIT** |
| genuinely zero-born coordinate can use ZeroOriginCoverage | **ADMIT** |
| unknown origin remains unknown | **ADMIT** |

## Import boundary suggested by the observation

A future importer should probably be decomposed by evidence job rather than by source product noun:

```text
source occurrence conversion
    -> selected Event candidates

historical completeness qualification
    -> ZeroOriginCoverage candidates

source/destination continuity qualification
    -> import identity / provenance evidence

observed nonzero boundary state
    -> future OriginSnapshot pressure, if earned

overlap between observed state and retained occurrences
    -> reconstruction/rebase or explicit overlap evidence
```

This decomposition lets a Ledger-family source, a hand-entered fresh household, and another external source share the same LOAM semantic boundaries without pretending their evidence is identical.

## What this says about accessibility

The ZeroOriginCoverage cut improves entry ergonomics in two important cases:

```text
true zero start
complete reconstructed/imported history
```

because neither needs artificial zero-valued QuantityBasis identities.

But it is **not** a universal onboarding mechanism.

A very common user who begins using LOAM today with pre-existing balances but without full history produces genuine nonzero-origin pressure.

So the accessibility gain is better stated as:

> LOAM can now accept zero-complete histories with a very small explicit concept, while leaving nonzero observed-state entry visibly unresolved instead of hiding it inside the same primitive.

That separation is preferable to making `ZeroOriginCoverage` lie about a user's history.

## Candidate future experiments

Before adding any production `OriginSnapshot`, qualify at least these synthetic or source-backed cases:

```text
A. truly empty new coordinate -> ZeroOriginCoverage
B. complete Ledger-family history -> Events + independent ZeroOriginCoverage
C. new LOAM adoption with nonzero current balance and no history
D. truncated history + observed opening balance
E. snapshot + overlapping retained Event followed by Event correction
F. mixed coordinates: zero-complete + snapshot-pressure + unknown
```

A source-backed experiment should also test that completeness is not inferred from file shape alone.

If cases C/D/F repeatedly require the same narrow observed-state semantics, that would be concrete pressure for an application-level `OriginSnapshot`. If reconstruction into explicit non-overlapping Events removes that need cleanly, the snapshot primitive may remain unnecessary.

## Finding

```text
ZeroOriginCoverage for true zero starts
    SUFFICIENT

ZeroOriginCoverage for independently qualified complete imports
    SUFFICIENT for quantity origin completeness

Event activity as import completeness evidence
    UNSOUND

new application user with pre-existing balances
    NOT zero-origin

truncated history + observed balance
    CREATES nonzero-origin pressure

snapshot + overlapping retained history
    CREATES overlap/reconstruction pressure

mixed migration
    NATURALLY coordinate-scoped

generic ImportOrigin / EntryEvidence Core ontology
    NOT EARNED

production OriginSnapshot today
    NOT YET EARNED
```

## Decision

Keep `ZeroOriginCoverage` narrow.

Do not infer it from Event activity, parser success, source file position, balance-view selection, or the fact that a user is new to LOAM.

Record nonzero observed-state onboarding as a real and likely common future pressure, but do not restore QuantityBasis or preemptively publish a new OriginSnapshot primitive.

The next implementation-level observation should use concrete import/onboarding fixtures to decide whether nonzero entry is best represented by:

```text
explicit OriginSnapshot
```

or by a qualified explicit reconstruction into a non-overlapping Event world.

Until then, the smaller production model remains correct for the current household while the entry boundary is now documented rather than accidental.
