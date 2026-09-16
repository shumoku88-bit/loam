# G2-019 — Event construction obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

Primary instruments: **DRAKONview + source comparison + Core-invariant ownership + existing runtime qualification**.

## Question

Three independent production writers create new Actual Events outside ordinary `MovementAdmission.admit?`:

- Correction replacement;
- Scheduled Completion;
- Actual Reversal.

Before G2-019, each writer constructed `Event` directly and supplied its own proof of:

```text
(retainedEffectKeys effects).Nodup
```

The question is whether those publisher-local proofs represent independent semantics, or whether they duplicate the local invariant already owned by `Core.Event`.

## Core owner already exists

`Loam.Core.Event` already exposes:

```lean
def Event.ofEffects? (id : EventId) (effects : List Effect) : Option Event
```

Its only admission law is the Event-local retained-EffectKey uniqueness invariant. It is already used by ordinary Movement admission and normalized Actual decoding.

Therefore a publisher that creates an Event should not normally reconstruct the `Event` structure merely to prove the same invariant locally.

## Same-scale comparison

### Record Movement

```text
raw Movement draft
  -> sparse identity canonicalization
  -> operation-specific validation
  -> allocate record EventId
  -> Event.ofEffects?
  -> append Event / validity / description / relation evidence
```

### Correction

```text
replacement effects
  -> sparse identity canonicalization with no retained keys
  -> correction-specific currentness / relation / reversal guards
  -> allocate replacement EventId
  -> [before G2-019] direct Event constructor + local keyNodup proof
  -> append correction-specific evidence
```

### Scheduled Completion

```text
completion Movement
  -> sparse identity canonicalization with no retained keys
  -> completion-specific plain-Movement / Locus / current-open guards
  -> stable scheduled-completion EventId
  -> [before G2-019] direct Event constructor + local keyNodup proof
  -> Scheduled-first / Actual-second retry protocol
```

### Actual Reversal

```text
current target Event
  -> exact anonymous inverse Effects
  -> reversal-specific independence guards
  -> deterministic reversal EventId
  -> [before G2-019] direct Event constructor + dedicated anonymous-key theorem
  -> append reversal relation atomically with Actual generation
```

The surrounding semantics differ. The Event-local invariant does not.

## Why the existing constructor is sufficient

### Correction and Scheduled Completion

Both paths call:

```text
SparseEffectIdentity.canonicalizeEffects []
```

so no collector-local EffectKey is retained. The previous local proof established exactly that consequence and then used it to fill the `Event.keyNodup` field.

Delegating to `Event.ofEffects?` preserves the same fail-closed law without making the publishers own the proof field.

### Actual Reversal

Reversal Effects are created only with:

```text
Effect.ofAnonymousQuantity
```

The previous private theorem `retainedEffectKeys_anonymousInverse` existed solely to prove those Effects carry no retained keys. `Event.ofEffects?` already checks the Event invariant, so the publisher-specific theorem is no longer required.

## What remains local

G2-019 does **not** merge the writers.

```text
Correction replacement EventId allocation              KEEP LOCAL
Correction target-current / relation / reversal guards KEEP LOCAL
Scheduled stable completion EventId                     KEEP LOCAL
Scheduled current-open + retry/crash protocol           KEEP LOCAL
Reversal deterministic EventId                          KEEP LOCAL
Reversal exact inverse construction                     KEEP LOCAL
Reversal relation-independence guards                   KEEP LOCAL
Locus admission checks                                  KEEP WHERE EARNED
Actual publication protocol                             KEEP LOCAL
```

Only Event value admission moves back to its existing Core owner.

## Why no new Actual append abstraction

Record, Correction, Completion and Reversal also contain nearby calls such as:

```text
EventMemory.add?
ActualValidityHistory.addFact?
EventDescriptionMemory.add?
```

Those calls already delegate to the correct local memory owners. The remaining repetition is orchestration, not one newly discovered invariant.

A new `ActualAppendEngine`, `ActualEventBundle`, or generic publisher would bundle neighboring operations while obscuring operation-specific diagnostics and evidence relations. G2-019 therefore stops at Event construction.

## Production change

Replace publisher-local direct Event construction with:

```lean
match Event.ofEffects? eventId effects with
| some event => ...
| none => refuse
```

in:

- `Loam/CorrectionPublisher.lean`;
- `Loam/ScheduledTerminalPublisher.lean`;
- `Loam/ActualReversalPublisher.lean`.

Delete the Reversal-only theorem whose sole purpose was supplying `keyNodup` for the direct constructor.

No persistence format, Event representation, identity policy, authority topology, or household-visible successful result changes.

The production delta across those three files is `+12 / -40`, net `-28` lines, with no new production type or helper.

## Obligation DAG

```text
                    new Actual Event
                          |
            +-------------+-------------+
            |             |             |
            v             v             v
       Correction     Completion      Reversal
            |             |             |
 operation-specific  operation-specific operation-specific
 identity/guards      identity/guards    identity/guards
            |             |             |
            +-------------+-------------+
                          |
                          v
                  effects + EventId
                          |
                          v
                    Event.ofEffects?
                          |
                 retained keys unique?
                    /           \
                  no             yes
                  |               |
                refuse           Event
                                  |
                                  v
                         operation-specific
                         evidence publication
```

Shared owner earned:

```text
Core.Event.ofEffects?
```

Not earned:

```text
generic Actual publisher
shared EventId policy
shared correction/completion/reversal admission
shared crash protocol
new append-bundle abstraction
```

## Qualification

Production/audit head `3d6856d0918970cb88d9cc85c6a5adca644620ea` qualified the production refactor.

Triggered workflows completed successfully:

- Shared Scheduled Terminal Publisher: **SUCCESS**
  - shared publisher dependencies built;
  - Actual-backed Scheduled completion and cancellation runtime story passed.
- Production TUI: **SUCCESS**, all 62 substantive steps.
  - normalized Actual correction publication passed;
  - Correction editor/shared publication passed;
  - Actual Reversal publisher build and both reversal runtime paths passed;
  - Scheduled terminal publisher build and completion/cancellation passed;
  - downstream Actual/Scheduled composition and report/routing surfaces also passed.
- Compression Audit: **SUCCESS**.
- Selected Lean Observations: **SUCCESS**.
- Shared ActualValidity Publisher: **SUCCESS**.
- Shared Scheduled Replacement Publisher: **SUCCESS**.

The final documentation commit after this qualification changes only this audit record. Production code and tests remain identical to the qualified head above.

## Final verdict

**G2-019: SIMPLIFY QUALIFIED — Event construction delegates to `Event.ofEffects?`; Correction, Scheduled Completion and Actual Reversal semantics remain separate.**
