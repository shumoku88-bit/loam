# Semantic audit SA-006 — Persistence semantic echo

Status: **AUDIT VERDICT COMPLETE — implementation intentionally deferred**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `f924a5ad962dedf4b00c459d0d87fe4da7b64cff`

This record asks whether the current `Loam/Persistence` surface represents too many independent concepts, or whether the file count mainly reflects explicit ownership of distinct wire meanings.

The target is not minimum file count. The target is the fewest independent persistence principles that preserve every semantic admission, authority, compatibility, and recovery distinction.

## 1. Physical inventory

Current `Loam/Persistence` contains 21 Lean modules.

Three are already deliberately shared mechanics:

```text
TokenSyntax
VersionedRows
SiblingStage
```

The remaining eighteen are semantic codecs or persistence boundaries:

```text
AccountingRolePersistence
ActualReversalPersistence
ActualRoutingPersistence
ActualValidityPersistence
AmountPersistence
AttentionPersistence
CapacityEffectivePersistence
CapacityPersistence
EventCorrectionPersistence
EventDescriptionPersistence
EventPersistence
LocusAdmissionPersistence
OpenRelationPersistence
RelationDischargePersistence
ScheduledLifecyclePersistence
ScheduledPersistence
ScheduledRoutingPersistence
ZeroOriginCoveragePersistence
```

A 21-file count is therefore not a 21-concept count.

## 2. Prior audit evidence

`COMPRESSION_AUDIT_PHASE3.md` already reached four decisions directly relevant here:

```text
M2 SHARE    exact versioned line-image framing only
M3 SHARE    sibling stage/write/rename primitive only
M4 SEPARATE missing-storage meaning per authority
M9 SEPARATE multi-family authority protocols beyond M2/M3
```

Current production contains the concrete results of M2 and M3 as `VersionedRows` and `SiblingStage`.

This SA-006 audit therefore treats Phase 3 as a prior hypothesis to revalidate against current main, not as a request to invent another serializer framework.

## 3. Audit dimensions

Each persistence module was classified along four independent dimensions.

1. **wire shape**
   - scalar/single object
   - flat versioned rows
   - block/chunk records
   - compound sectioned image

2. **decode admission**
   - syntax only; raw semantic conflict deliberately retained
   - local structural admission such as uniqueness/balance
   - compatibility/publication policy beyond row decoding

3. **publication protocol**
   - direct write
   - shared sibling stage + rename
   - stage + stronger verification/guard
   - inner codec only, no independent writer

4. **authority role**
   - current semantic authority/provenance stream
   - inner codec inside another authority
   - explicitly low-level plumbing artifact

These dimensions are more informative than file count because two files can have identical outer framing while owning different admission laws.

## 4. Current classification

| Module | Wire shape | Admission / special law | Publication / role | Audit decision |
| --- | --- | --- | --- | --- |
| `TokenSyntax` | token predicate | representation only | shared mechanic | `KEEP` |
| `VersionedRows` | flat frame | exact header + trailing newline | shared mechanic | `KEEP`, formalize contract candidate |
| `SiblingStage` | text candidate | no semantic admission | shared physical replace | `KEEP` |
| `AccountingRolePersistence` | flat rows | typed role + duplicate-Locus refusal | sibling stage; semantic authority | `KEEP_BOUNDARY` |
| `ActualReversalPersistence` | flat rows | self-edge refusal + endpoint uniqueness | sibling stage; provenance authority | `KEEP_BOUNDARY` |
| `ActualRoutingPersistence` | flat rows | routing-coordinate uniqueness | sibling stage; routing authority | `KEEP_BOUNDARY` |
| `ActualValidityPersistence` | fact/correction rows | V2-only decode + existing-storage admission | guarded stage/rename | `KEEP_POLICY`, `SHARE_MECHANICS` candidate |
| `AmountPersistence` | scalar row | typed measure/quanta syntax | direct-write low-level file | `TOPOLOGY_REVIEW` |
| `AttentionPersistence` | tagged flat rows | item/closure uniqueness; referential closure later | sibling stage; complete image | `KEEP_BOUNDARY` |
| `CapacityEffectivePersistence` | flat rows | movement-id uniqueness + date syntax | sibling stage; effective evidence | `KEEP_BOUNDARY` |
| `CapacityPersistence` | block/chunk | re-proves balanced movement + movement identity | sibling stage; Capacity authority | `KEEP_EXPLICIT` |
| `EventCorrectionPersistence` | flat rows | correction-id uniqueness; endpoint presence deliberately later | sibling stage; raw relation authority | `KEEP_BOUNDARY` |
| `EventDescriptionPersistence` | flat rows | escaped text; publication rejects U+FFFD while decode permits repair | sibling stage; description authority | `KEEP_BOUNDARY` |
| `EventPersistence` | single Event + EventMemory blocks | Effect/Event identity admission | direct low-level Event + staged EventMemory | `KEEP`, mixed plumbing/authority roles |
| `LocusAdmissionPersistence` | flat set rows | duplicate Locus refusal | sibling stage; explicit policy evidence | `KEEP_BOUNDARY` |
| `OpenRelationPersistence` | flat rows | **syntax only**; duplicate/quantity/source conflicts deliberately retained | sibling stage; raw provenance | `KEEP_BOUNDARY` |
| `RelationDischargePersistence` | flat rows | **syntax only**; duplicate pairs and semantic bounds deliberately retained | sibling stage; raw provenance | `KEEP_BOUNDARY` |
| `ScheduledLifecyclePersistence` | compound sections | legacy physical sections mapped to current terminal semantics | stage + read-back verification; lifecycle authority | `KEEP_PROTOCOL` |
| `ScheduledPersistence` | block/chunk | date + balance + occurrence identity | **inner codec only**, no standalone authority | `KEEP_CODEC` |
| `ScheduledRoutingPersistence` | flat rows | routing-coordinate uniqueness | sibling stage; routing authority | `KEEP_BOUNDARY` |
| `ZeroOriginCoveragePersistence` | flat set rows | duplicate coordinate refusal | sibling stage; explicit completeness evidence | `KEEP_BOUNDARY` |

## 5. Main architectural result

The current Persistence surface does **not** support a universal serializer, generic persistence repository, or common semantic admission policy.

The files cluster around a small number of physical shapes, but their semantic acceptance laws differ materially.

The correct compression boundary remains:

```text
share framing / token / physical replacement mechanics
keep row meaning / semantic admission / authority / compatibility explicit
```

This is consistent with the existing Phase 3 decision and with the desired Git-like plumbing/porcelain architecture.

## 6. Bounded formal check — one duplicate policy cannot preserve both semantics

The strongest counterexample is between admitted complete images and raw provenance streams.

Representative admitted families reject structural duplication while decoding or typed re-admission. Representative raw provenance families such as OpenRelation and RelationDischarge deliberately retain duplicate/conflicting rows so Application can later fail closed with the complete raw evidence.

We exhaustively checked every family-blind Boolean acceptance policy that can depend only on whether duplicate keys are present.

There are exactly four such policies:

```text
accept(nonduplicate), accept(duplicate)
false, false
false, true
true,  false
true,  true
```

Required current semantics are:

```text
                 nonduplicate   duplicate
admitted image       accept       reject
raw provenance       accept       accept
```

None of the four family-blind policies matches both rows of this table.

**Formal consequence:** duplicate/admission semantics cannot move into one family-blind generic decoder without changing at least one current authority's behavior.

A shared decoder may therefore own syntax/framing, or may accept an explicitly family-owned admission function, but it must not silently choose one universal duplicate policy.

This is a bounded exhaustive result, not an Alloy artifact retained in the repository. A permanent Alloy model is unnecessary unless a future refactor proposes to move semantic admission into a shared codec.

## 7. Bounded formal check — VersionedRows has an implicit newline-free contract

`encodeVersionedRows` accepts arbitrary `String` rows, while its intended callers provide already-encoded single-line rows.

A bounded round-trip check used the row alphabet:

```text
""
"a"
"b"
"a\nb"
"\n"
```

and all row lists of length 0 through 2.

Results:

```text
31 total row-list cases
18 round-trip failures
13 newline-free cases
0 failures among newline-free cases
```

Every observed failure was caused by an embedded newline becoming a new physical row boundary.

This does not indicate a current production bug: current row encoders either reject newline-bearing tokens or escape text before framing.

It does expose a useful proof obligation for the shared mechanic. A future Lean theorem should be shaped approximately as:

```text
header contains no newline
all encoded rows contain no newline
-----------------------------------
decodeVersionedRows? header (encodeVersionedRows header rows) = some rows
```

This is a stronger audit outcome than adding another serializer abstraction because it makes the existing small helper's real contract explicit.

## 8. Strong residual compression candidate — ActualValidity sibling staging

`ActualValidityPersistence` currently defines its own:

```text
path ++ ".loam-stage"
writeFile stage text
rename stage path
```

`SiblingStage.replaceTextViaSiblingStage` owns the same physical primitive and the same reserved suffix.

ActualValidity's important stronger law is separate:

```text
existing target, if present, must decode under the current canonical V2 format
before a normal practical write may replace it
```

That guard can remain entirely in `ActualValidityPersistence` while the final physical replacement delegates to `SiblingStage`.

Provisional decision:

```text
semantic V2 overwrite guard     KEEP LOCAL
stage/write/rename mechanic     SHARE existing SiblingStage
wire bytes                      unchanged
missing-storage semantics       unchanged
migration policy                unchanged
```

This is the clearest current SA-006 subtraction candidate, but it is **not implemented by this audit**.

Before promotion to `IMPLEMENTATION_READY`, verify the exact relevant tests/CI and that no stage-path-specific stronger behavior is hidden outside this module.

## 9. Why ScheduledLifecycle must remain separate

`ScheduledLifecyclePersistence` also uses `.loam-stage`, but it performs a stronger sequence:

```text
write staged image
read staged image back
compare staged bytes to intended bytes
rename only after equality
```

Replacing this with the simple `SiblingStage` primitive would erase a current verification step.

Decision: `KEEP_PROTOCOL`.

A more configurable generic staging framework is not justified by two variants; it would turn a visible stronger protocol into callback/configuration machinery.

## 10. Block codecs — Capacity and Scheduled

Capacity and Scheduled occurrence codecs both reconstruct `BalancedMovement` from block-like change rows.

This similarity is real, but a useful generic codec would need parameters for at least:

- block marker and outer header;
- identity metadata;
- Capacity-vs-Scheduled metadata (`measure` versus `scheduled day + measure`);
- coordinate encoding/decoding;
- movement/container constructors;
- memory constructor and identity admission;
- standalone writer ownership, since Scheduled is inner-codec-only while Capacity is an authority.

With only two current BalancedMovement block users, such a callback-heavy abstraction would hide more structure than it removes.

Decision: `KEEP_EXPLICIT` for now.

Reopen only if a third production family earns the same block grammar or a concrete proof/mechanics duplication becomes large enough to outweigh the adapter surface.

## 11. Low-level Amount / Event plumbing

`Loam/Cli.lean` explicitly separates practical dogfood commands from `help low-level` commands.

Low-level commands include:

```text
amount show
single Event create / quantity
EventMemory get / review / quantity / add
```

Therefore standalone Amount and Event files should not be classified as accidental canonical authorities merely because the normal household path does not use them.

They are closer to Git plumbing: small inspectable/interchangeable objects used below the primary product entrance.

Current nuance:

- standalone Event codec participates in compositional low-level Event -> EventMemory workflows;
- Amount persistence is much more isolated and currently deserves a later product-topology usefulness review;
- neither should be removed from a semantic persistence audit solely on executable-canonical reachability.

Decision: move the Amount question to a later low-level-product-surface audit rather than treating it as SA-006 semantic duplication.

## 12. Historical deletion is not eternal prohibition

Earlier compression work retired `AccountingRolePersistence` when it had no live production owner. Current main has re-earned it through current review, publisher, and TUI administration paths.

This establishes an important ledger rule:

> `DELETE` means that a distinction or surface has no independently earned current role at that checkpoint. It does not prohibit a later feature from re-earning the same semantic boundary.

The audit must always re-check current reachability and independent meaning rather than treating an old deletion decision as ontology.

## 13. SA-006 verdict

### Keep

- semantic wire owners;
- authority-specific decode admission;
- missing-storage semantics;
- ScheduledLifecycle stronger staged verification;
- raw provenance retention for OpenRelation / RelationDischarge;
- explicit Capacity/Scheduled block codecs for now;
- low-level plumbing distinction from canonical household authority.

### Already correctly shared

- `TokenSyntax`;
- `VersionedRows` outer frame;
- `SiblingStage` ordinary stage/write/rename;
- Core/Application mechanics such as `FiniteKeyed`, `ReplacementFrontier`, and `RoutingHistory` that persistence adapters reuse indirectly.

### Residual candidate

1. make ActualValidity use the already-earned `SiblingStage` physical primitive while retaining its V2 overwrite guard;
2. later prove the newline-free `VersionedRows` encode/decode round-trip in Lean rather than enlarging the persistence abstraction;
3. review isolated Amount low-level plumbing under product topology, not semantic codec compression.

### Rejected

```text
NO universal serializer/schema layer
NO generic Persistence<T> repository
NO universal duplicate/admission policy
NO generic missing-storage policy
NO generic stage protocol parameterized by callbacks
NO authority unification merely because wire framing is similar
```

## 14. Promotion state

SA-006 is now **audit-complete** at this checkpoint.

No production change is authorized by this file alone.

The ActualValidity staging candidate may be promoted only after the parent ledger's implementation gate is satisfied. The remaining repository-wide audit should proceed to SA-007 Application projection fanout before a batch of compression implementations begins.
