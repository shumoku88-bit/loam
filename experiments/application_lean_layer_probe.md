# Lean application-layer probe

## Purpose

Application 001 and Application 002 were first made executable in Dafny to ask whether a verification-aware host could turn LOAM's application distinctions into small verified operations.

This probe asks the inverse question before Dafny becomes a permanent dependency:

> Can the existing Lean 4 world itself serve as the application layer, using the actual Practical Core values directly rather than rebuilding their evidence as a second host-language model?

This is a comparison experiment. It does not yet promote a permanent `Loam.Application` package and it does not remove the Dafny probes.

## Existing Lean pressure

LOAM already uses Lean for more than theorem storage.

The current practical boundary includes executable CLI and IO code, and `spendJpy` already performs a human-facing path of roughly:

```text
prompt
    -> construct Event
    -> EventMemory.add?
    -> Persistence.saveEventMemory?
```

So the question is not whether Lean can execute an application. The question is whether application meaning can stay clearer when the law, Core types, executable decision, and local proofs remain in one type universe.

## Application 001 in Lean

The Dafny probe receives a compact host-language summary:

```text
correction count
recorded quantity candidate
optional effective quantity candidate
    -> typed answer
```

The Lean probe instead receives the actual Core values:

```text
EventMemory
EventCorrectionMemory
LocusId
MeasureId
    -> QuantityInspectionAnswer
```

and calls the existing Core operations directly:

- `EventMemory.quantityAtRecorded`;
- `EventCorrection.quantityAtEffective?`.

The application result remains the same four-way boundary:

```text
0 Corrections
    -> RecordedQuantity

1 Correction + available effective projection
    -> SingleCorrectionEffectiveQuantity

1 Correction + unavailable endpoint
    -> MissingCorrectionEndpoint

2+ Corrections
    -> FrontierRequired
```

The important difference is ownership. Lean does not need a second representation of `recordedQuantity`, `effectiveQuantity`, or correction count as separately trusted semantic inputs. The application branch inspects the retained Core memory directly.

## Application 002 in Lean

The Dafny writer probe receives a Boolean summary saying whether candidate Event identity is already present.

The Lean probe instead calls the real Core admission operation:

```text
EventMemory.add? memory candidate
```

The result is therefore stronger than a publication permission flag:

```text
stale snapshot
    -> RefuseStaleSnapshot

current snapshot + Core admission failure
    -> RefuseDuplicateEventIdentity

current snapshot + Core admission success
    -> PublishCandidate(updated EventMemory)
```

`PublishCandidate` carries the exact admitted `EventMemory` returned by Core. Application code does not have to reproduce the duplicate-identity law or reconstruct the updated memory after authorization.

The experiment-local `PublicationSnapshot` remains only equality evidence for preparation freshness. It is not Event identity, semantic time, authority, provenance, or an earned persistence revision format.

## Proof surface

The probe retains eight local theorems:

- no-correction query is exactly the Core recorded projection;
- one successful correction is exactly the Core effective projection;
- one unavailable correction endpoint refuses explicitly;
- two-or-more corrections require a frontier;
- stale preparation refuses publication;
- current Core admission failure refuses duplicate identity;
- current Core admission success carries the exact admitted memory;
- stale preparation cannot escape refusal by changing the candidate.

These proofs stayed small because most obligations reduce through the existing Core definitions with `simp`.

This matters for the comparison. Lean did not require a parallel specification function plus a separate executable method for these two probes. The executable definitions themselves are ordinary Lean functions, and the theorems state the laws directly over those functions and Core values.

## Executable witnesses

Synthetic execution covers the same Application 001 modes exercised by Dafny:

```text
RecordedQuantity
SingleCorrectionEffectiveQuantity
MissingCorrectionEndpoint
FrontierRequired
```

and the three distinct writer decisions:

```text
PublishCandidate
RefuseDuplicateEventIdentity
RefuseStaleSnapshot
```

No household data is used.

## Qualification result

The first CI run succeeded without a corrective proof patch.

The repository's existing pinned toolchain is:

```text
Lean 4.33.1
```

The dedicated probe builds the existing `Loam.Core`, checks all theorem declarations, executes the synthetic witnesses, and confirms their result vocabulary.

Unlike the Dafny probes, this adds no new compiler or runtime family. It reuses the repository's existing `lean-toolchain`, Lake project, and `leanprover/lean-action` setup.

The CI log also makes the maintenance contrast concrete:

```text
Lean probe
    existing Elan / Lean / Lake path
    existing Lake cache
    no added .NET / Node toolchain family

Dafny probes
    Dafny itself was small and natural
    official setup path also brought .NET and Node machinery
    repeated action/runtime deprecation pressure
```

This does not mean Lean is universally better than Dafny. Dafny still demonstrated useful SMT-oriented verification ergonomics. The finding is narrower:

> For these two LOAM application operations, Lean can express the executable boundary directly over the real Core with low proof friction and no new toolchain dependency.

## Comparison checkpoint

```text
                         Dafny probe                  Lean probe

Core values              summarized at boundary      used directly

quantity semantics       supplied as candidates      calls existing Core projection

duplicate identity       supplied as Boolean         calls EventMemory.add?

successful writer result permission                  admitted EventMemory

proof style               SMT / ensures               theorem over executable def

new toolchain family      yes                          no

observed proof friction   low                          low
```

The strongest Lean result is not fewer lines. It is fewer semantic translations.

```text
Alloy distinction
    -> Lean Core law/value
    -> Lean application operation
    -> Lean theorem
    -> existing Lean IO boundary
```

can remain one connected type world.

## What this does not settle

This probe does not prove that all future application work belongs in Lean.

In particular it does not solve:

- concurrent writer interleavings;
- the check-then-replace race after application authorization;
- filesystem compare-and-swap or locking;
- cross-stream atomic publication;
- a future interactive UI architecture;
- canonical household write authority.

Those questions may still earn TLA+, SPIN, Ada/SPARK, PureScript/Erlang, Dafny, or another instrument when their specific vocabulary appears.

The result instead raises the bar for adding another permanent application language:

> A new host should provide a capability that the existing Lean application path cannot express cleanly enough to justify another maintained toolchain.

## Scope

- one Lean application-layer experiment;
- Application 001 and 002 only;
- actual Practical Core types reused;
- eight local theorems;
- synthetic execution only;
- one dedicated workflow;
- no Practical Core changes;
- no Persistence changes;
- no production CLI changes;
- no canonical data reads or writes;
- no Dafny removal;
- no permanent Application package;
- no Observation 085.
