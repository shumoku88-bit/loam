# Compression audit Phase 3 — mechanics multiplication

Status: **IN PROGRESS — M1–M4 DECIDED**

Phase 2 closed with this current audit basis:

```text
18 retained fact/policy families
~9 physical authority instances
134 executable-reachable practical Lean files
21,226 executable-reachable practical lines
```

Phase 3 asks why the implementation surface is much larger than the retained information basis.

This phase does **not** assume that repeated code is accidental. Different semantic authorities may legitimately need separate codecs, publication protocols, recovery behavior, or failure boundaries. Conversely, giving every fact family a narrowly named helper does not prove those mechanisms are distinct.

## Audit families

The first mechanics pass groups pressure into these questions.

### M1 — collection / identity admission

How many semantic families independently implement:

- unique stable identity;
- `List`-backed memory;
- `of... ?` admission;
- append with duplicate rejection;
- lookup by identity;
- permutation-independence laws?

Repeated proof text may be harmless local explicitness, or it may indicate a reusable finite-map/set boundary already earned by several real domains.

### M2 — text codec admission

How many persistence modules repeat:

- version header;
- token validation;
- row encode/decode;
- trailing-empty handling;
- full collection re-admission;
- malformed => `none` fail-closed behavior?

Wire syntax may need to remain domain-specific even if mechanical parsing/publication support is shared.

### M3 — stage + rename publication

How many executable-reachable persistence/authority modules create a sibling `.loam-stage`, write the complete candidate, then `IO.FS.rename` it into authority?

The law is valuable. Repetition is not automatically valuable.

### M4 — missing-storage semantics

Audit every `pathExists` / `OrEmpty?` boundary. Missing storage sometimes means:

- unavailable evidence;
- empty evidence;
- malformed/missing authority and therefore refusal.

These are semantic distinctions. A generic loader must not erase them.

### M5 — writer ownership and current-world re-read

Audit publishers for repeated implementation of:

- acquire one ownership anchor;
- re-read current authority inside ownership;
- validate a stale frontend intent against current evidence;
- prepare candidate state;
- publish relation/policy evidence in an observed order;
- commit authority;
- return a small receipt.

The sequence may admit a shared transaction-shaped skeleton while publication order and semantic admission remain domain-specific.

### M6 — fresh identity allocation

Several practical writers generate `record-N`, `replacement-N`, `correction-N`, `validity-N`, relation ids, and other identities by scanning all relevant retained namespaces.

The audit must distinguish:

- genuinely different collision domains;
- one shared opaque-id allocation mechanic specialized to different namespaces;
- compatibility-era identity logic that current manifest authority may have displaced.

### M7 — replacement / correction frontier mechanics

Event correction, Actual-validity correction, Scheduled replacement, and other revision-like domains may share directed-edge mechanics while preserving different semantic endpoints and authority.

`ReplacementFrontier` already exists for part of this pressure. Phase 3 must determine where reuse stops and domain-specific logic starts, instead of creating a larger generic history framework by reflex.

### M8 — historical routing mechanics

Actual and Scheduled routing already share `RoutingHistory` while retaining separate subject types and authorities. This is a positive control for the audit: a demonstrated example of mechanical factoring without semantic collapse.

### M9 — complete-image / multi-family authority

Movement manifest, Scheduled lifecycle, and Attention show different ways to package several meanings into one physical authority image. The audit must ask whether these differences are driven by required atomicity and recovery behavior or simply by implementation chronology.

## Mechanical smoke scan

`tools/audit-mechanics-patterns` scans only executable-reachable practical Lean modules for textual pressure indicators such as:

- `.loam-stage`;
- `IO.FS.rename`;
- `pathExists`;
- `WriterOwnership`;
- Movement selected-world load/prepare/commit calls;
- `OrEmpty?` loaders;
- `fresh...` identity helpers;
- `ReplacementFrontier`;
- `RoutingHistory`;
- `Nodup` collection laws;
- executable-reachable `*Publisher.lean` modules.

These counts are smoke alarms only. A textual match is not a duplication finding, and absence of a match is not proof of factoring.

## M1 decision — `SHARE` narrowly, not as a generic Memory ontology

Detailed inspection found two different things that should not be conflated.

### Mechanically identical pressure

Several current runtime families use the same representation-level recipe:

```text
List item
+ a projection item -> stable key
+ Nodup over projected keys
+ runtime admission from a raw List
+ lookup by key
+ sometimes append-by-re-admission
```

`EventMemory` and `EventCorrectionMemory` go further and independently carry almost the same recursive lookup plus a substantial proof that lookup is invariant under a permutation when projected keys are unique. `ActualValidityMemory` and capability-only `EventResolutionMemory` repeat the same proof shape as further evidence that the mechanic is representation-level rather than Event-specific.

The narrow reusable boundary already earned by at least two current production domains is therefore:

```text
find an item in a List by an explicit key projection
prove that result invariant under List permutation when projected keys are Nodup
```

A future compression change may factor that helper/theorem while each semantic module retains its own named lookup wrapper.

### Semantic constraints that must stay local

The audit rejects a universal `Memory α` or generic finite-map ontology at this point.

Examples that are *not* the same invariant:

- `ScheduledCompletionMemory` requires uniqueness of both Scheduled and Actual endpoints;
- `ScheduledReplacementMemory` requires uniqueness of both source and replacement endpoints;
- `ScheduledRetirementMemory` is unique by its Scheduled source despite having no independent retirement identity;
- `ActualValidityHistory` owns two independent identity spaces, facts and corrections;
- `RoutingHistory` is unique by a composite `(subject, effective coordinate)` coordinate;
- `LocusAdmissionVocabulary` and `ZeroOriginCoverage` are set-like evidence, not identity-bearing memories.

Those laws answer domain questions. Hiding them inside one generic collection type would make the abstraction larger than the duplicated mechanism it replaces.

Likewise, the local `of...?` and `add?` functions are currently short and make the exact domain uniqueness law visible. M1 does not yet justify replacing them with a framework merely to reduce repeated syntax.

### M1 result

**`SHARE`**, with a deliberately small scope:

- share only unique-key list lookup and its permutation-independence mechanics;
- preserve every domain-specific memory structure and its explicit uniqueness fields;
- preserve domain-specific admission and append names unless later measurements show a second clearly identical substantial mechanic;
- do not introduce a generic `Memory`, repository, registry, entity store, or finite-map semantic layer.

This is the first Phase 3 example of subtractive design: remove duplicated proof/mechanical text without adding a new household concept.

## M2 decision — `SHARE` the exact line-image frame, keep codecs semantic

The codec audit found a repeated outer grammar across many current production streams:

```text
<header>\n
<row>\n
<row>\n
...
```

with the same mechanical obligations:

1. require exactly the expected version header;
2. require a trailing newline rather than accepting a partial final row;
3. expose the body as ordered row strings;
4. fail closed on malformed outer framing;
5. let the domain decoder parse each row and re-admit the resulting typed collection.

This shape appears in current routing, Capacity-effective, Event-description, Relation-discharge, open-relation, Attention, zero-origin, and other row-oriented persistence families. Several modules independently spell `input.splitOn "\n"`, `rows.reverse`, the trailing empty-row check, `mapM` decoding, and final semantic admission.

### What can be shared

A future compression may introduce a *small persistence-level helper* equivalent to:

```text
encodeVersionedRows(header, rows)
decodeVersionedRows?(expectedHeader, input) -> Option (List String)
```

The helper would know only the exact line-image framing law. It must not know Event, Scheduled, routing, Attention, Capacity, identity, or collection semantics.

`validToken` is already an example of this appropriately small persistence-level sharing: opaque-token syntax is mechanical and reused without turning all persisted meanings into one family.

### What must remain local

The audit rejects a generic serializer/codec ontology.

Domain code must continue to own:

- row tags and field counts;
- typed token interpretation;
- date validation;
- endpoint encoding;
- EventDescription escaping and U+FFFD publication policy;
- ActualValidity V2 root/revision normalization;
- final `of...?` semantic admission;
- block/chunk structure for EventMemory, CapacityMemory, and other non-row images;
- the Scheduled lifecycle outer multi-section format.

Those are observable compatibility and fail-closed rules, not boilerplate to erase.

In particular, EventDescription decoding has an independent escaping contract, while ActualValidity persistence performs canonical identity normalization before encoding. Treating those as one generic row codec would hide rather than remove complexity.

### M2 result

**`SHARE`**, again with a deliberately narrow boundary:

- share exact versioned line-image framing and trailing-newline admission;
- keep every domain row encoder/decoder and typed re-admission local;
- do not generalize block-oriented formats merely to use the helper;
- do not create a serializer typeclass, persistence registry, schema DSL, or generic migration framework.

The intended subtraction is repeated framing syntax, not semantic wire-format ownership.

## M3 decision — `SHARE` the sibling replacement primitive, preserve stronger protocols

The smoke scan found `.loam-stage` in 15 executable-reachable files and filesystem rename in the same broad persistence surface. Detailed inspection confirms a large identical core:

```text
stage := sibling(target, ".loam-stage")
write complete candidate text to stage
rename stage -> target
```

For ordinary single-image persistence streams this operation has the same obligation regardless of the fact family: never expose a target that was truncated while the new image was still being written.

### What can be shared

A small IO helper can own only the common physical primitive:

```text
replaceTextViaSiblingStage(target, text)
```

or equivalent. It may construct the reserved sibling path, write the complete text, and rename it over the target.

The helper must make no claim about cross-stream transactions, concurrent writers, fsync/power-loss durability, semantic admission, or authority selection. Those remain caller responsibilities exactly as current persistence comments already state.

### What must remain local

Not every stage operation has the same protocol strength.

- Scheduled lifecycle publication reads the staged complete image back before rename and checks byte equality.
- Movement manifest `CURRENT` publication decodes the staged manifest and compares typed references before the authority switch.
- content-addressed Movement object preparation verifies existing or staged object bytes and digest identity.
- ActualValidity additionally refuses to overwrite existing storage that does not decode under the current canonical format.

Those checks are not accidental variants of `write + rename`; they protect different authority and migration laws. A shared primitive must sit below them, not replace them.

The audit therefore rejects callback-heavy transaction frameworks merely to force every stronger publication path through one function.

### M3 result

**`SHARE`**, at the physical sibling-replacement primitive only:

- factor the repeated stage-path/write/rename operation used by ordinary complete-image streams;
- keep staged verification, digest checks, migration refusal, and manifest authority switching explicit in their stronger callers;
- do not claim the helper is a transaction, lock, recovery log, or durability abstraction.

This is a high-confidence subtraction candidate because the shared behavior is physical IO, not household semantics.

## M4 decision — `SEPARATE`: missing storage has domain meaning

The `pathExists` / `OrEmpty?` scan initially looks like ordinary repetition, but detailed examples show materially different contracts.

Current production has at least these meanings:

```text
missing -> explicit empty evidence
missing -> evidence source unavailable
missing -> malformed/missing authority and refuse
```

Examples:

- Actual-validity history and Capacity-effective evidence have explicit `OrEmpty?` entrances where absence means no retained evidence yet.
- Attention review distinguishes an absent configured file as `unavailable`, not an empty Attention stream.
- Movement manifest authority treats missing `CURRENT` as an authority error and fails closed.
- Scheduled lifecycle documentation requires configured authority to exist; absence is not a synthetic empty lifecycle.

These distinctions affect household answers and writer safety. They cannot be normalized to one default without changing semantics.

### M4 result

**`SEPARATE`**.

Do not introduce a generic `loadOrEmpty`, `loadOptional`, or `MissingPolicy` abstraction solely to shrink `pathExists` branches. Each authority/review boundary should keep a named entrance whose return type and error behavior state what absence means there.

Very small filesystem helpers remain mechanically possible, but they would not remove the important branch and therefore are not a meaningful Phase 3 compression target.

No production refactor is performed yet. Phase 3 first classifies M1–M9 so proposed abstractions can be compared against the whole mechanics landscape before code is changed.

## Decision labels

Every mechanics family that survives detailed inspection will receive exactly one label:

- `SHARE` — same mechanism can be factored while semantic authority stays explicit;
- `SEPARATE` — repetition is justified by different semantic/atomicity/recovery requirements;
- `RETIRE` — implementation mechanism belongs to obsolete or unreachable production surface;
- `OPEN` — evidence is insufficient; one focused observation/test may be warranted.

Do not add a generic abstraction merely to reduce line count. `SHARE` requires at least two current production domains with genuinely identical mechanical obligations.

## Exit rule

Phase 3 completes only when each mechanics family M1–M9 has a concrete `SHARE / SEPARATE / RETIRE / OPEN` result and any proposed sharing boundary is smaller than the mechanisms it replaces without weakening fail-closed behavior, provenance, or authority separation.
