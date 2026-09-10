# Canonical basis re-minimization — Phase 2: physical topology

Status: **research checkpoint; no production or loam-data migration authorized**

Baseline production main reviewed: `9d11b5413bc353d1e596aa7e839ee281cd28e613`

Tracking: #693 / draft PR #694

## 1. Important rediscovery: early LOAM already separated meaning from topology

The current audit initially started to add a new Observation 244 comparing:

```text
split files + dependency order
atomic bundled image
split files + unsafe reverse order
```

That observation was immediately removed after re-reading Observation 055.
The old experiment already asks essentially the same question and reaches the
stronger result.

Observation 054 established that, for the modeled questions, an unordered tagged
fact set and several typed fact sets carry the same semantic information when
explicit identity relations are preserved. Co-location does not itself merge
meaning. The extra danger appears only when one physical serialization order is
silently promoted into global chronology / priority / authority.

Observation 055 then established that logical canonical topology and publication
topology need not coincide:

- one atomic bundle preserves closure;
- uncoordinated independent streams can tear;
- dependency-ordered streams can preserve closure;
- fail-closed admission can preserve semantic closure over temporarily torn raw
  storage.

Its explicit conclusion is that persistence should be chosen from operational
pressure, not inferred from logical fact topology.

### Compression consequence

Do not add a new live proof merely to rediscover 054/055.

The current task is now narrower and more valuable:

> Re-apply the already-earned 054/055 distinction to the current production
> authority graph and find where later implementation topology leaked back into
> semantic/application structure.

## 2. Current design tension: Movement manifest rationale has become stronger than 054

`MovementManifestAuthority` correctly keeps six independently meaningful Movement
families distinct while selecting them through one `CURRENT` generation.

That implementation is itself strong evidence for:

```text
semantic-family count != authority-handle count != backing-file count
```

However its current design rationale says a monolithic single-file snapshot would
"conflate distinct semantic authorities".

That statement is too strong unless `single-file snapshot` specifically means a
representation that erases typed family membership, explicit identities, or adds
an unearned global cross-family order.

Observation 054 already showed that physical co-location alone does not perform
that conflation.

A typed atomic image such as:

```text
[Event]
...
[ActualValidity]
...
[EventDescription]
...
```

can still preserve independent semantic families. Whether it is operationally
better is a separate question involving write amplification, deduplication,
recovery, corruption radius, and inspectability.

Therefore the current audit should weaken this historical implication:

```text
semantic separation
    -> must remain semantically typed

NOT

semantic separation
    -> must occupy separate physical files
```

No production comment is changed in this research PR yet; the point is recorded
for later design correction if the topology comparison confirms it.

## 3. Authority grouping must be derived from update and failure laws

The useful physical unit is not `one meaning`, and not automatically `one file`.
A better candidate is an **authority group**: meanings that share a selected
publication / recovery / ownership boundary.

Working production grouping follows.

| Semantic families | Current physical shape | Current operational relation | Topology status |
| --- | --- | --- | --- |
| Event, ActualValidity, EventDescription, RelationUnit, RelationDischarge, LocusAdmission | `movement-authority/CURRENT` + immutable family objects | one selected Movement generation; atomic `CURRENT` switch | current group earned; exact object/file partition still operational, not semantic |
| Scheduled occurrence, completion, retirement, replacement | `scheduled.loam` | already one typed lifecycle image | direct counterexample to `one family = one file` |
| CapacityMovement + CapacityEffective | `capacity.loam` + `capacity.loam.effective` | one writer-ownership domain; completeness checked together; effective evidence published before movement activation | **strong bundle/descriptor candidate** |
| EventCorrection + ActualReversal | optional `corrections.loam` + required `actual-reversals.loam` | symmetric conflict checks; Correction derives Reversal sibling filename; both coordinate with Movement activation | **strong Actual-revision authority candidate** |
| ActualRouting | `actual-routing.loam` | independent append-only historical writer | keep independent unless later atomicity witness says otherwise |
| ScheduledRouting | `scheduled-routing.loam` | independent routing history; Scheduled lifecycle used for admission | keep independent unless later witness says otherwise |
| AccountingRole | `accounting-role.loam` | independent classification authority with cross-locking for first assignment | keep independent unless later witness says otherwise |
| ZeroOriginCoverage | `zero-origin-coverage.loam` | independent completeness evidence for balance answerability | semantic independence earned; physical placement still open |

This table is about selected authority groups, not total filesystem object count.
Content-addressed objects and explicit recovery generations may remain useful even
if ordinary callers see fewer physical names.

## 4. Candidate compression 1: Capacity package

Current Capacity publication already acts more like one authority than two:

```text
lock capacity authority
load CapacityMovement
load CapacityEffective
require bidirectional completeness
allocate one fresh identity across both
publish effective evidence
publish activating movement
unlock
```

The `.effective` filename is derived from the Capacity filename and is visible in
publisher, CLI, review, TUI/tests, and persistence wiring.

This suggests three representations are worth comparing while holding semantics
constant:

### A. current companion files

```text
capacity.loam
capacity.loam.effective
```

Properties:

- supports evidence-first crash protocol;
- can leave inert dangling effective evidence after a crash;
- requires explicit recovery after that partial publication;
- physical companion convention leaks upward.

### B. one typed Capacity image

```text
LOAM-CAPACITY-AUTHORITY
[MOVEMENTS]
...
[EFFECTIVE]
...
```

Properties to test:

- one atomic replacement could remove the intermediate incomplete state;
- semantic families remain separately typed;
- no companion path leaks above persistence;
- each write rewrites both sections unless another representation is used.

### C. explicit Capacity authority descriptor

One public authority handle resolves two typed backing images without callers
constructing `.effective` themselves.

Properties to test:

- preserves current evidence-first protocol and separate physical data;
- removes filename derivation from application/TUI layers;
- may be the smallest change if write amplification argues against B.

At this point B and C are both plausible. File count alone cannot choose.

## 5. Candidate compression 2: Actual revision authority

Correction and Reversal are semantically distinct:

```text
Correction
  replaces the current interpretation frontier

Reversal
  records a real inverse occurrence and retains both physical occurrences
```

They must **not** be merged into one semantic relation kind.

But current physical topology creates a different question.

Correction publication reads Reversal state to reject targets participating in
Reversal evidence. Reversal publication reads Correction state to ensure the
selected target is still current. The dependencies are symmetric while the
physical initialization policies are asymmetric:

```text
missing corrections storage -> often interpreted as explicit empty
missing reversal storage     -> unavailable / refuse
```

The Correction publisher additionally discovers Reversal authority using the
sibling filename `actual-reversals.loam`.

This makes a typed package worth testing:

```text
LOAM-ACTUAL-REVISION-AUTHORITY
[CORRECTIONS]
...
[REVERSALS]
...
```

The package state would distinguish:

```text
whole authority unavailable
whole authority available
  corrections = known set, possibly empty
  reversals   = known set, possibly empty
```

That representation could remove the accidental equation:

```text
Reversal semantic authority
=
sibling filesystem entry named actual-reversals.loam
```

while preserving Correction/Reversal as different types and different operations.

### Important migration observation

The current household has an explicit empty `actual-reversals.loam` while no
`corrections.loam` is present. Production Correction readers intentionally map the
missing Correction file to empty correction memory.

A package migration could therefore materialize exactly the already-observed
semantic state:

```text
Corrections = known empty
Reversals   = known empty
```

without treating absence itself as historical household meaning.

This remains a candidate until all current operations, Doctor/recovery behavior,
and crash prefixes are checked.

## 6. Missing-storage semantics must not define Q

The current codebase contains several storage policies:

```text
missing -> empty
missing -> unavailable
missing -> error/refusal
```

Sometimes the policy even differs by operation over the same family.

These are representation/loading policies unless an admitted household operation
can distinguish the underlying authority states independently of physical layout.

Therefore Q must preserve topology-neutral results such as:

```text
known empty correction evidence
reversal evidence unavailable
scheduled lifecycle unavailable
capacity effective evidence incomplete
```

but must not freeze current implementation facts such as:

```text
file `corrections.loam` does not exist
file `actual-reversals.loam` does not exist
```

Otherwise the current filesystem layout becomes an axiom and no topology audit is
possible.

## 7. Candidate authority count after semantic regrouping

This is **not a file-count conclusion**. It is a working selected-authority graph
that follows current update/failure boundaries more closely than one-file-per-
family thinking.

A plausible current candidate is approximately:

```text
1 Movement generation authority
2 Scheduled lifecycle authority
3 Capacity authority package
4 Actual revision authority package
5 Actual routing authority
6 Scheduled routing authority
7 AccountingRole authority
8 ZeroOriginCoverage authority
```

So roughly eighteen retained semantic families may plausibly project onto about
eight selected authority handles, while Movement and recovery may still use many
immutable backing files internally.

The number eight is not yet a target. It is a falsifiable intermediate model.

## 8. Next checks before production refactoring

### Capacity

Compare current two-file publication with an atomic typed image and an explicit
opaque descriptor. Preserve:

- all read answers;
- incomplete-evidence refusal;
- crash closure;
- stale-writer behavior;
- recovery behavior.

Measure:

- path assumptions visible above persistence;
- write amplification;
- recovery states;
- corruption blast radius.

### Actual revision

Trace every current Correction/Reversal read and write and verify whether any
operation genuinely requires independent physical availability of the two
families. In particular test whether the current `missing corrections = empty`
policy has any topology-neutral observable consequence distinct from an explicit
empty corrections section.

### Movement

Do **not** replace the manifest merely because a one-file typed image is
semantically allowed. Re-test why the current content-addressed object partition
is operationally useful:

- generation deduplication;
- write amplification;
- recovery candidates;
- corruption localization;
- human recovery.

If those benefits dominate, keep the backing topology but continue hiding it
behind the existing authority root.

## 9. Current conclusion

The audit has crossed the threshold requested in #693:

> Physical file topology is demonstrably not determined by the retained semantic
> basis, and some current physical conventions have leaked upward into
> application/runtime wiring.

The strongest evidence is not a theoretical preference for fewer files. It is
the combination of:

1. early Observation 054 proving semantic equivalence across unified/split typed
   representations;
2. early Observation 055 proving publication safety does not force one topology;
3. current Scheduled already packing four semantic families into one image;
4. current Movement exposing six semantic families through one selected authority
   handle while using many backing objects;
5. current Capacity treating two physical files as one writer-owned publication
   unit;
6. current Correction discovering another semantic dependency from a sibling
   filename.

The next production move, if the remaining checks pass, should therefore be to
**reduce physical-topology knowledge above persistence**, not to optimize raw
file count by itself.
