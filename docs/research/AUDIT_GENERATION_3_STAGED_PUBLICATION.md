# Audit Generation 3 candidate: staged publication verification

Status: **ACTIVE OBSERVATION, NO GENERIC PERSISTENCE ABSTRACTION AUTHORIZED**

Baseline:

```text
6fdb058eda787414078cffa4597bb4583e93d62c
docs: add AI workbench entrance (#1213)
```

## Root question

Several current writers publish one complete text image through a sibling
`.loam-stage` path. Earlier compression audits already decided that
`SiblingStage` should own only the ordinary write+rename primitive and that
stronger authority protocols remain explicit.

The current question is therefore narrower:

> Do the stronger staged-publication protocols still differ for an independent
> reason, and in particular is Scheduled lifecycle intentionally weaker than the
> newer Actual / Capacity / Scheduled Coverage verification sequence?

## Tool choice

This is primarily an execution-order and refusal-path question.

```text
DRAKON    selected: stage / readback / verification / rename order
D2        not primary: ownership topology is already known
Lean      only if a new general round-trip law is needed
Alloy     no unresolved bounded structural world question yet
TLA+/SPIN only if a crash/interleaving residual appears after the flow comparison
```

## Prior evidence reused

Previously earned decisions remain in force:

- `SiblingStage` is the shared ordinary sibling write+rename mechanism.
- missing-storage semantics remain family-specific.
- writer ownership and semantic admission remain authority-specific.
- a generic Publisher/Authority/transaction framework remains rejected.

This audit does not reopen those conclusions without new evidence.

## Current four-path comparison

### Actual authority

```text
encode normalized Actual
-> ensure parent
-> write stage
-> read stage
-> require exact byte equality
-> decode staged bytes through production typed decoder
-> rename stage to authority
```

### Capacity authority

Same verification shape as Actual, with the normalized Capacity codec.

### Scheduled coverage configuration

Same verification shape at a non-authoritative configuration boundary: encode,
stage, readback, byte equality, decode staged bytes, rename.

### Scheduled lifecycle authority

```text
encode lifecycle image
-> write stage
-> read stage
-> require exact byte equality
-> rename stage to authority
```

The lifecycle codec has a direct encode/decode regression over representative
terminal meanings, but the publication function itself does not re-run
`decodeScheduledLifecycleImage?` on the staged bytes before authority switch.

## Obligation scaffold

```text
Should Scheduled lifecycle add typed staged re-decode?
|
+-- D1 stage bytes are read back before rename
|      -> YES
|
+-- D2 intended bytes must equal staged bytes
|      -> YES
|
+-- D3 encoder output is exercised by encode/decode regression
|      -> YES, representative specimen + malformed controls
|
+-- P1 ordinary sibling write+rename mechanic
|      -> already owned by SiblingStage; do not broaden it automatically
|
+-- D4 newer complete-image/config writers re-decode staged bytes
|      -> Actual YES, Capacity YES, Scheduled Coverage YES
|
+-- R1 safety
|      -> Is a staged lifecycle image allowed to become authority when the
|         production lifecycle decoder rejects those exact bytes?
|
+-- R2 architecture
       -> If R1 says NO, is one local decoder check sufficient, or has a
          reusable verified-stage protocol finally earned a shared helper?
```

R1 must be answered before R2. Do not create a callback-heavy staging framework
to solve a one-line missing check.

## Initial hypothesis

A local staged re-decode in `saveScheduledLifecycleImage?` appears to be a
strict fail-closed strengthening:

- ordinary encoder/decoder-compatible images remain unchanged;
- a future encoder/decoder drift cannot publish unreadable lifecycle authority;
- no semantic authority or file format changes;
- no missing-storage policy changes;
- no cross-file transaction claim.

This hypothesis should be tested as a narrow production experiment before any
mechanic extraction.

## Stop conditions

Reject broader abstraction if the local check is sufficient and the four paths
still need distinct return/error policy, directory creation policy, codec owner,
or authority semantics.

Do not promote a new generic persistence framework merely because four diagrams
share boxes.


## Experiment result

Classification: **LOCAL SAFETY STRENGTHENING QUALIFIED; NO NEW GENERIC HELPER**

The DRAKON comparison made the procedural asymmetry explicit. At the baseline,
Actual, Capacity, and Scheduled Coverage all followed:

```text
write stage
-> read stage
-> exact byte equality
-> production typed decode of staged bytes
-> rename
```

Scheduled lifecycle stopped after byte equality and renamed immediately.

The branch added only this local gate to
`saveScheduledLifecycleImage?`:

```text
match decodeScheduledLifecycleImage? staged with
| none   => return false
| some _ => continue to rename
```

No wire bytes, codec, authority topology, missing-storage meaning, publisher
entrance, or lifecycle interpretation changed.

### Qualification

At head `2eaa5320b3fac00d56039c5a128234633ea33734`, every triggered
qualification completed successfully:

- Scheduled Lifecycle Persistence;
- Shared Scheduled Creation Publisher;
- Shared Scheduled Terminal Publisher;
- Shared Scheduled Replacement Publisher;
- Practical Scheduled Routing;
- Practical Slice B;
- Selected Lean Observations;
- Compression Audit;
- temporary staged-publication DRAKON build / inspection.

The focused persistence workflow built 15 jobs successfully. Its executable
regression still reports that the v1 Completion / Retirement / Replacement wire
meaning, endpoint uniqueness, explicit empty state, and fail-closed authority
behavior are preserved.

### DRAKON result

The generated audit map contains three diagrams:

1. four staged publication paths at one procedural scale;
2. the Scheduled lifecycle verification residual;
3. the sharing stop point.

The map and SQLite metadata passed integrity checks and were inspected through
the repository's own `inspect_map.py` interface.

### Why Lean was not added

A repository search found the general newline-framing round-trip theorem for
`VersionedRows`, but no corresponding general theorem for the complete
Scheduled lifecycle codec.

Proving the entire compound lifecycle encode/decode law would require new proof
surface across the Scheduled block codec and terminal-section codec. That proof
may be useful later, but it is larger than the current safety question.

The local production-decoder gate directly enforces the needed boundary:
unreadable staged lifecycle bytes never become authority.

### Sharing verdict

The experiment does **not** earn a generic
`replaceVerifiedTextViaSiblingStage` framework.

The visible shared boxes remain surrounded by independently meaningful
differences:

- family-specific typed codecs;
- `Bool` versus `Except String Unit` result surfaces;
- different diagnostic wording;
- different parent-directory preparation;
- authority versus replaceable configuration meaning;
- different semantic admission before the persistence call.

The smallest current design is therefore:

```text
SiblingStage
  KEEP ordinary write+rename primitive

Actual / Capacity / Scheduled Coverage / Scheduled lifecycle
  KEEP stronger protocol explicit at each owning boundary

Scheduled lifecycle
  ADD local staged typed re-decode
```

## Stop point

This audit closes the observed staged-verification asymmetry without opening a
new persistence framework.

Reopen only if two or more stronger protocols later accumulate the same
verification/error/recovery contract strongly enough that a shared helper
reduces responsibility rather than merely line count.
