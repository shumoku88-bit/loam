# Application 026 — What is the smallest safe sidecar -> manifest cutover and rollback boundary?

## Question

Application 025 closed the typed-decoder gap for one complete practical Movement path:

```text
production sidecars
  -> existing typed decoders
  -> content-addressed family objects
  -> CURRENT
  -> restart
  -> existing typed decoders
  -> same household projection
```

That still left a deployment question outside the scratch manifest root:

> How can existing canonical sidecar authority move to manifest authority without creating two readable authorities, and when is rollback still a real rollback rather than silent data loss?

This application holds the five Movement-relevant semantic families fixed:

- EventMemory;
- ActualValidity;
- EventDescription;
- RelationUnit;
- RelationDischarge.

It changes no production path or persistence format.

## Prior pressure already earned

Observation 145 already qualified a stronger destructive historical authority cut. Its important reusable lessons are:

- hold the existing `WriterOwnership` for the complete cutover;
- a crash may make a current answer unavailable, but must not expose a plausible mixed-generation false answer;
- completion and cleanup are later than the semantic authority commit;
- unknown/mixed physical states fail closed rather than guessing a generation.

Application 026 does not re-prove the old Historical Actual cutover or replace that publisher. The new question is narrower: the old practical sidecars are intentionally retained read-only for a bounded rollback window while a new physical selector chooses which topology is authoritative.

## Why `CURRENT exists -> use manifest, otherwise use sidecars` is rejected

The tempting migration rule is:

```text
if manifest/CURRENT is readable
  use manifest
else
  use legacy sidecars
```

That is not a rollback protocol. Once manifest authority has been selected, corruption or a missing selected object would silently revive stale sidecars.

Application 026 therefore models an explicit physical authority selector:

```text
AUTHORITY = SIDECAR
```

or

```text
AUTHORITY = MANIFEST
```

When `AUTHORITY = MANIFEST`, a missing/malformed manifest or digest mismatch means **unavailable**. It never means `try the old sidecars`.

The preserved sidecars are rollback material, not a fallback reader branch.

## Candidate migration shape

The smallest safe shape observed here is:

```text
0. hold existing WriterOwnership

1. read the current canonical sidecars
   and admit them through existing production decoders

2. encode those same typed values with existing production encoders
   into immutable content-addressed family objects

3. prepare and verify CURRENT off authority

4. require exact generation equivalence
   selected manifest family bytes/fingerprints == preserved sidecar generation

5. atomically replace only the top-level authority selector
   SIDECAR -> MANIFEST

6. keep the legacy sidecars frozen and read-only
   while the rollback window remains open

7. release WriterOwnership
```

The selector is the authority transition. `CURRENT` continues to select one generation *inside* manifest topology; it does not by itself decide whether legacy sidecars or manifest topology owns production authority.

## Practical specimen

The CI fixture creates a real two-Movement world through the existing `loamMovement` executable:

```text
record-1
  paypay -> travel 100 JPY
  RelationUnit relation-1 = 100 JPY

record-2
  friend-in -> paypay 40 JPY
  RelationDischarge relation-1 = 40 JPY
```

Application 025 then prepares a manifest generation from the five production sidecars.

Before cutover, the fixture verifies all five selected object images are byte-for-byte identical to the canonical sidecar images. The explicit selector is switched:

```text
SIDECAR -> MANIFEST -> SIDECAR -> MANIFEST
```

while those fingerprints remain equal. The pre-divergence rollback is therefore a true authority reversal: both selections name the same generation.

## The rollback window has a hard edge

The fixture then freezes the preserved legacy sidecars and creates a third Movement on an exact copy using the ordinary production Movement writer:

```text
record-3
  paypay -> coffee 10 JPY
```

Those newly produced production family images are stored as the next manifest generation while the preserved rollback sidecars remain unchanged.

Now:

```text
selected manifest Event image  contains record-3
preserved legacy Event sidecar does not
```

The exact fingerprint rollback guard fails.

This earns the central result:

```text
selector-only rollback is safe
iff
preserved sidecar generation == selected manifest generation
```

After the first manifest-only mutation, simply flipping `AUTHORITY` back to `SIDECAR` is not rollback. It is loss of newer retained household evidence.

The Lean model records the same boundary with generation fingerprints:

- cutover between equal generations preserves the read answer;
- rollback between equal generations preserves the read answer;
- one manifest-native write closes the preserved-sidecar selector rollback;
- a blind post-divergence rollback changes the readable generation;
- broken manifest authority returns unavailable and never falls back.

## What rollback would require after divergence

There are only two honest broad shapes after manifest authority has advanced:

1. **Forward conversion back to legacy topology**
   - materialize the current manifest generation into a newly qualified sidecar generation;
   - verify exact semantic/fingerprint parity;
   - perform another authority cutover.

2. **Restore a legacy generation that already contains every manifest-era fact**
   - which means it must have been kept current by some explicit publication mechanism.

The second option is effectively dual-write / dual-publication machinery. Application 026 does not earn that permanent complexity merely to keep a cheap rollback switch alive.

The first option is a new migration in the opposite direction, not a free selector flip. Because legacy sidecars are several independently replaced files, it can reintroduce the multi-stream publication protocol that the manifest topology was meant to compress.

Therefore the smallest current policy is:

```text
preserve old sidecars for a short verified rollback window
close that window at the first manifest-only authority mutation
never keep silent legacy fallback afterward
```

## Fail-closed corruption specimen

The practical fixture also corrupts the Event object referenced by a valid selected manifest while `AUTHORITY = MANIFEST`.

The selector reader returns failure. It records no sidecar read source.

So the migration rule is explicitly:

```text
selected MANIFEST + broken selected generation
  -> unavailable
```

not:

```text
selected MANIFEST + broken selected generation
  -> stale SIDECAR
```

This mirrors Observation 145's existing policy that unknown/mixed authority states are refusal states, not invitations to guess an older generation.

## Relationship to retirement / GC

Application 024 already found that immediate online object GC is not safe merely because an object is absent from the newest `CURRENT`; stale readers may still hold an older manifest.

Application 026 adds a different retention obligation: the legacy sidecars may be retained during the verified rollback window. Once the first manifest-only write closes that window, keeping those sidecars no longer provides a selector rollback and should not be mistaken for active authority.

Their eventual archival/deletion policy remains a separate retirement decision. This application does not authorize deletion of any canonical production file.

## Qualified boundary

This application does **not** add:

- a production `AUTHORITY` file;
- production manifest readers or writers;
- dual writes;
- permanent sidecar fallback;
- a generic transaction layer;
- sidecar retirement;
- object GC;
- household-data migration;
- a production rollback command.

It qualifies the migration shape only.

## Result

The useful cutover picture is now:

```text
legacy sidecars G0
      |
      | prepare manifest G0 off authority
      | verify exact equivalence
      v
AUTHORITY: SIDECAR
      |
      | one atomic selector replacement
      v
AUTHORITY: MANIFEST -> CURRENT -> manifest G0
      |
      | rollback is still cheap while sidecars == selected manifest
      |
      +---- selector rollback to sidecars G0 is safe
      |
      | first manifest-only mutation
      v
manifest G1
      |
      +---- old sidecars G0 are now stale rollback material
             selector-only rollback is forbidden
```

The manifest proposal therefore does not require permanent dual authority. It requires one explicit cutover selector and a deliberately finite rollback window.

Production migration is still not authorized by this application. The next deployment pressure is whether old and new binaries/readers can coexist safely across the cutover epoch, or whether the switch must require a quiescent single-version deployment boundary.
