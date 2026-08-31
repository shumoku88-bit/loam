# Observation 076 — Can external identity aid be retired instead of becoming permanent infrastructure?

## Question

Observation 075 established that imported identity is continuity information, not something that can be safely recomputed from mutable content or presentation position.

It also showed that an external admission anchor can preserve continuity, but did **not** establish that a permanent sidecar should exist.

Observation 076 asks a stricter practical question:

> If LOAM ever uses an external identity aid for legacy source records, can that aid be retired, and what must replace the continuity information before retirement is safe?

The intended pressure is deliberately anti-sidecar:

```text
external identity aid
    must not silently become
permanent second authority
```

No sidecar format is proposed here.

## Why retirement matters

A permanent mapping beside the canonical source would create another durable authority surface:

```text
canonical source
+ external identity mapping
+ LOAM persistence
```

That may be justified someday, but it must not arise merely because import was convenient.

Therefore any future external identity aid should have an explicit exit story from the beginning.

## Bounded model

The Alloy model keeps one historical occurrence and two current source candidates with the same visible snapshot. It distinguishes:

- `StableSourceId`: identity retained by the canonical source;
- `ExternalAid`: a hypothetical external identity aid;
- `LoamId`: identity retained after authority has deliberately transferred to LOAM;
- `SourceAuthority`: the source remains authoritative and future source reattachment is required;
- `LoamAuthority`: an admitted occurrence is now owned by LOAM and no future source reattachment is required;
- `reconciledTo`: an explicit current-cycle reconciliation decision, not a permanent inferred key.

The model does not claim that authority transfer is desirable for the current household source. It is included only to distinguish ongoing shadow synchronization from a genuine one-time admission or migration boundary.

## Exit paths under observation

### 1. Source-owned identity

If the source begins retaining a stable occurrence identity, the external aid can disappear while automatic source reattachment remains determinate.

```text
source remains authoritative
+ stable source identity
=> external aid can retire
```

### 2. Deliberate authority transfer

If an occurrence is admitted once and LOAM explicitly becomes authoritative for that admitted occurrence, future reattachment to the mutable source is no longer part of the contract.

```text
one-time admission
+ authority transfer
=> external mapping can retire
```

This is not ongoing shadow synchronization. Treating these as the same operation would hide an authority change.

### 3. Explicit reconciliation

If the source remains authoritative, has no stable identity, and no external aid is retained, an ambiguous source change may still be handled by explicit reconciliation for that operation.

```text
ambiguity
=> stop automatic matching
=> explicit reconciliation
```

This does not create a promise that the same match can be reconstructed automatically after another arbitrary edit.

## Expected boundary

A retired external aid is **not** by itself enough to preserve automatic ongoing synchronization against a mutable identity-free source.

If the source remains canonical and automatic reattachment must continue, one of the following must carry the distinction:

- stable source-owned identity; or
- an explicit reconciliation decision at the ambiguous boundary.

A different exit is possible only by changing the authority contract so that future source reattachment is no longer required.

Therefore the intended law is not:

```text
no permanent sidecar
=> source identity is mandatory
```

because explicit reconciliation and deliberate authority transfer are also possible.

The stronger practical rule is:

```text
external aid may retire only when
continuity responsibility has moved somewhere explicit
or automatic reattachment has stopped
```

## Practical Core impact

None.

- no new identity type;
- no sidecar;
- no Persistence change;
- no CLI change;
- no change to `shadow-audit`;
- no private canonical values copied into the repository or CI.

This observation constrains a future admission protocol. It does not implement one.

## Next pressure

If the bounded results confirm this separation, the next useful question is operational:

> For a source that remains canonical and identity-free, what is the smallest fail-closed reconciliation entrance that can resolve one ambiguous admission without creating a permanent mapping store?

That question should be asked before writing any sidecar or migration database.
