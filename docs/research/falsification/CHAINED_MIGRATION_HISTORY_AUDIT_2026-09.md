# Chained migration history audit — 2026-09-20

Status: **historical pressure audit / no production change**

Related executable observation:

- `Loam/Observations/Observation285.lean`

## Question

Observation 285 shows that this migration check is too weak:

```text
current report before migration
    =
current report after migration
```

A representation may preserve today's report while discarding a distinction
needed by a later legitimate query.

The stronger audit question is:

> Across LOAM's actual sequence of household-data representation changes, what
> independently observable distinctions were preserved, translated, or
> explicitly retired?

This document applies that question to the real migration history rather than a
synthetic candidate.

## Result in one sentence

LOAM's historical migrations generally used a substantially stronger contract
than report parity.

The important qualification is that several migrations intentionally retired
representation identities. Those retirements are acceptable only because the
affected identities were either explicitly judged duplicate / no longer
meaningful, or later qualified as unearned representation witnesses rather than
household facts.

## 1. Canonical Locus unification — loam-data PR #90

The first bounded Locus migration unified three old source-shaped coordinates
with the newer household vocabulary.

This was explicitly classified as an **identity migration**, not a display
rename.

The temporary generator refused publication unless it preserved:

- Event identities;
- Effect keys;
- Measures;
- exact signed Quantities;
- Event and Effect counts;
- exact per-Event / per-Measure quantity totals;
- AccountingRole;
- Purpose routing meaning;
- unrelated Scheduled / routing / zero-origin / query configuration.

It also refused source/target co-occurrence inside one Event.

### Observation 285 classification

**Qualified semantic compression, not mere report parity.**

The old Locus identity itself was intentionally retired from current authority.

That means a future question of the form:

```text
Was this Effect historically stored under the old source-shaped Locus token?
```

is not promised by current canonical data.

Git history can answer provenance questions about the migration, but the old
token is not retained as a second live household identity.

This is acceptable only because the migration explicitly decided that the two
tokens denoted one current household coordinate.

The important point is that the migration did not infer this merely from:

- equal AccountingRole;
- equal Purpose;
- similar spelling;
- equal report totals.

The candidate pairs were qualified separately before the cutover.

## 2. Remaining mixed-era Locus cutover — loam-data PRs #91 / #92

This was the stronger household example.

PR #91 first froze an Event-level review without changing household facts.
PR #92 then rewrote exactly the reviewed Effects.

The migration preserved:

- EventId;
- EffectKey;
- Measure;
- exact signed Quantity;
- Event / Effect cardinality;
- per-Event / per-Measure physical totals;
- unrelated evidence families byte-for-byte where they were outside the cut.

The migration also preserved uncertainty instead of manufacturing stronger
classification.

Examples of the policy shape:

```text
exact old service identity but no longer useful for entry
    -> historical-only retained identity

old evidence too lossy for stronger classification
    -> historical-unclassified
    -> no invented AccountingRole
```

### Observation 285 classification

**Strong pass.**

This migration did not merely preserve existing report output. It carried
forward independently retained identity, physical quantity, routing and role
meaning while explicitly representing places where stronger historical meaning
was unavailable.

This is close to the long-horizon contract suggested by Observation 285:

```text
preserve
or translate
or explicitly retire / leave unresolved
```

rather than silently collapse.

## 3. Actual authority normalization — loam-data commit 736489a

This was a large physical topology change.

Before the cutover, the selected Movement authority was split across
content-addressed families such as:

- Event;
- ActualValidity;
- EventDescription;
- RelationUnit;
- RelationDischarge;
- LocusAdmission;

with reversal evidence in its own sidecar.

After the cutover, current Actual evidence moved to one normalized
`actual.loam` authority while LocusAdmission became an independent direct
policy file.

### Direct old-generation versus new-file comparison

A machine comparison of the exact selected pre-cutover generation against the
first normalized `actual.loam` found:

```text
EventId set                         exact match
occurrence-valid date per Event     exact match
EventDescription per Event          exact match
(Event,Locus,Measure,Quantity)
  physical Effect multiset          exact match
```

Cardinality at cutover:

```text
Events        593 -> 593
Effects      1241 -> 1241
validities    593 -> 593
descriptions  593 -> 593
```

The selected RelationUnit, RelationDischarge and Reversal authorities were empty
at that cutover, so no retained relation / discharge / reversal row was silently
dropped.

### The non-byte-preserving change: Effect keys

The old Event representation carried collector / migration-era keys on Effects.
The normalized generation retained no `KEYED-EFFECT` rows because no retained
relation evidence required an exact Effect endpoint in that generation.

At first glance this looks like a violation of long-horizon preservation.

Later sparse-identity qualification explains the intended semantics more
precisely:

```text
collector-local Effect key
    !=
durable household evidence

independent retained evidence needs exact Effect reference
    -> EffectKey is earned and retained
```

Current `Loam.SparseEffectIdentity` and Observation 255 make the boundary
explicit.

Erasing an unearned EffectKey preserves:

- Event identity;
- Effect list multiplicity;
- Locus;
- Measure;
- exact Quantity;
- Event-level quantity projections.

It removes only the claim that one Effect is durably addressable by that key.

### Observation 285 classification

**Pass, with an important explicit limitation.**

The normalized migration intentionally retired unearned Effect addressability.

Therefore a later query must not pretend that a historically anonymous Effect
always carried a durable identity.

For example, if future investment semantics need to say exactly which of two
otherwise indistinguishable historical acquisition Effects supplied a disposal,
LOAM may have to answer:

```text
insufficient retained identity evidence
```

rather than retroactively minting sameness.

This is not data loss relative to the selected sparse-identity semantics. It is
a refusal to upgrade an old representation witness into a household fact.

That distinction should remain visible because acquisition / lot pressure
(Observations 067 and related work) is exactly the kind of future query that can
cross this boundary.

## 4. Later point-accounting changes are not mere schema migration

Later household changes such as the point-accounting correction used explicit
Correction replacement evidence rather than rewriting the old Event as though
the earlier observation had never existed.

That is important for this audit because not every data-shape change should be
classified as migration.

```text
representation changed, household fact unchanged
    -> migration / re-key / normalization

household interpretation changed or was corrected
    -> correction / new evidence
```

Conflating these would let a migration silently rewrite history.

## 5. Capacity normalization — loam-data PR #110

Capacity moved from:

```text
capacity.loam
capacity.loam.effective
```

to one normalized:

```text
capacity.loam
```

The migration required a one-to-one identity match between every retained
CapacityMovement and every independently retained effective-date row.

At cutover there were 25 movement identities and 25 effective identities, with
an exact one-to-one correspondence.

The retained semantic distinction remained explicit in the normalized image:

```text
CapacityMovement
    !=
CapacityEffective
```

The migration did not derive effective dates from movement content.

It intentionally preserved:

- movement identity;
- exact quantity;
- Purpose;
- effective date;
- one-to-one movement/effective correspondence.

### Observation 285 classification

**Strong pass.**

This is a physical normalization that preserves both independent semantic
families rather than treating co-location in one file as ontology merging.

It is a useful example of:

```text
share persistence
    !=
merge meaning
```

## 6. Generation-2 cleanup

Later Generation-2 work retired:

- stale request bridges;
- old manifest/object-store assumptions;
- duplicated hard-coded LOAM revisions;
- completed migration scaffolding;
- old compatibility paths whose protected property had moved elsewhere.

This is not primarily a household-fact migration.

The important preservation rule was instead:

> deleting a migration mechanism must not delete the semantic result or safety
> property that mechanism had established.

Git history remains archive; current production keeps the surviving law in the
current Core / Application / persistence boundary.

### Observation 285 classification

**Compatible with the chained-migration rule.**

Long-term safety does not require every historical schema reader and every
one-shot migrator to remain executable forever.

It requires the *meaning needed by current authority* to survive after the
temporary bridge is retired.

## 7. Measure presentation activation

The current household presentation configuration includes fixed-point scales for
selected Measures.

The activation did not reinterpret existing non-JPY household history because
the newly configured foreign Measures had no retained Actual quantities at the
time of activation, while JPY kept its existing scale.

The standing rule is now:

```text
unused Measure
    -> scale may be selected

Measure with retained household quantities
    -> scale change is migration
```

This is another example where a future representation edit becomes semantic
once retained data depends on it.

## 8. What the real history says about Observation 285

The real migration chain supports the observation, but sharpens it.

The preservation contract is **not**:

```text
preserve every old byte
preserve every old token
preserve every possible future query
```

That would make migration and semantic compression nearly impossible.

The stronger useful rule is:

```text
for every destructive change:

1. inventory independently retained meanings / references;
2. preserve or exactly translate each meaning that remains live;
3. name any distinction intentionally retired;
4. do not infer stronger replacement meaning from report parity;
5. keep unresolved / unknown state unresolved when evidence is insufficient;
6. qualify the new complete authority before retiring the migration bridge.
```

A later query that depends on an explicitly retired or never-earned distinction
must receive an unavailable / insufficient-evidence answer rather than a
reconstructed fiction.

## 9. Main positive finding

LOAM's actual history does not show a pattern of:

```text
old report == new report
    -> assume migration safe
```

Instead, the larger migrations repeatedly protected lower-level semantic
coordinates and independent evidence families.

The strongest examples are:

- Event / Effect physical parity across Locus cutovers;
- explicit preservation of unresolved historical classification;
- exact Event/date/description/physical-Effect parity across Actual
  normalization;
- independent CapacityMovement / CapacityEffective preservation inside one
  normalized file.

That is stronger evidence for long-term migration safety than the synthetic
Observation 285 alone.

## 10. Remaining pressure

The most important long-horizon edge is not an already-known broken migration.

It is this:

> A distinction may be correctly classified as unearned today and become useful
> only after a genuinely new household question appears years later.

Sparse historical Effect identity is the clearest example.

LOAM cannot guarantee answers to every future ontology without retaining every
possible distinction forever.

Its defensible contract is instead:

```text
never claim a distinction that was not retained
never erase an earned distinction accidentally
make intentional semantic retirement explicit
preserve enough migration provenance to explain the transition
```

This is compatible with LOAM's existing epistemic rule:

```text
unknown != zero
missing != false
insufficient evidence -> refusal is an answer
```

## Verdict

The historical chain is **consistent with the stronger migration discipline**
suggested by Observation 285.

No current evidence from this audit requires:

- a generic migration framework;
- permanent readers for all historical schemas;
- a universal migration manifest;
- restoring mandatory Effect identity;
- retaining every obsolete token in current household authority.

The most useful permanent artifact is the review question itself:

> Which independently observable distinctions does this migration preserve,
> translate, intentionally retire, or leave unresolved?
