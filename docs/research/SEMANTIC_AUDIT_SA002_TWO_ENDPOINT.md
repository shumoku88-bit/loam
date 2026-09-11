# Semantic audit SA-002 — two-endpoint relation mechanics

Status: **AUDIT VERDICT COMPLETE — no production abstraction earned**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `f2d57ccc867193365bf66c2c30579ea06f2a9b80`

This record asks whether current relation-like memories with uniqueness pressure on two endpoints should share another generic Core mechanism.

The target is not to make structurally similar relations nominally identical. The target is to remove only implementation mathematics that is actually the same while preserving raw conflict evidence, domain admission, and household meaning.

## 1. Historical pressure

The September semantic census identified a repeated two-endpoint shape among the then-separate:

```text
ActualReversalMemory
ScheduledCompletionMemory
ScheduledReplacementMemory
```

Since that census, Scheduled lifecycle has already undergone a stronger semantic recompression.

Observation 244 / PR #695 re-tested the mature Scheduled semantics and qualified one target-preserving relation:

```text
Scheduled -> Actual       completion
Scheduled -> Scheduled    replacement
Scheduled -> no target    retirement
```

Production PR #696 introduced `ScheduledTerminalMemory`, and PR #706 subsequently removed the old dedicated Completion / Retirement / Replacement Core memories and standalone codecs while preserving the v1 wire format and per-kind uniqueness laws.

Therefore the old three-family shape must not be counted as three current opportunities. The current question is narrower:

```text
ActualReversalMemory
vs
endpoint-uniqueness portions of ScheduledTerminalMemory
```

## 2. Current ActualReversal shape

`ActualReversalMemory` retains one explicit relation:

```text
target EventId -> reversal EventId
```

with global uniqueness on both projections:

```text
(reversals.map target).Nodup
(reversals.map reversal).Nodup
```

This is representation-level partial-injection shape, but the household meaning is stronger than the shape:

- both Events remain physical historical facts;
- the relation answers which Actual one inverse movement reverses;
- publisher admission requires an exact inverse balanced Movement;
- reversal-of-reversal chains are not currently qualified;
- reversal is refused for several currently unsupported relation/Scheduled interactions;
- relation-first interrupted publication may temporarily retain a missing reversal endpoint.

Therefore `ActualReversal` is not a generic replacement edge and should not move into `ReplacementFrontier` merely because both endpoints are unique.

## 3. Current ScheduledTerminal shape

`ScheduledTerminalMemory` is deliberately **not** globally source-unique.

It keeps separate raw uniqueness laws for:

```text
completion source
completion Actual target
retirement source
replacement source
replacement Scheduled target
```

while deliberately retaining a same-source cross-kind conflict so Application can diagnose it as `conflictingTerminalEvidence`.

This is an important distinction between:

```text
per-kind endpoint uniqueness
and
global endpoint uniqueness
```

They are not interchangeable representations.

## 4. Structural counterexample to a universal two-endpoint memory

Consider one Scheduled source `S` and one Actual Event `A` with raw terminal evidence:

```text
completion: S -> Actual A
retirement: S -> no target
```

Each current per-kind uniqueness requirement is satisfied:

- one completion source;
- one completion Actual target;
- one retirement source;
- no replacement endpoints.

So `ScheduledTerminalMemory.ofTerminals?` may retain this raw state.

The state is intentionally **not semantically accepted** as one current lifecycle answer. `ScheduledInspection.currentOpenScheduled` observes it later as:

```text
conflictingTerminalEvidence
```

Now replace the current representation with a family-blind relation carrier requiring global source uniqueness:

```text
all retained edges have unique source
```

The same raw world becomes unrepresentable at construction time because `S` appears twice.

### Consequence

A universal source-unique / target-unique relation memory would erase a currently observable malformed-evidence state and move a semantic review refusal into an earlier generic construction failure.

That violates the audit gate:

```text
observable fail-closed distinction preserved
```

So the direct semantic merge is rejected.

This is a concrete bounded counterexample. A new Alloy artifact is unnecessary because the mature Scheduled recompression research already qualified preservation of cross-kind conflict observability; this audit only applies that retained law to the proposed generic two-endpoint carrier.

## 5. Could only the Nodup mechanic be shared?

A narrower helper is theoretically possible, for example a representation-level predicate or constructor parameterized by two endpoint projections:

```text
leftOf  : Item -> Left
rightOf : Item -> Right

Nodup (items.map leftOf)
Nodup (items.map rightOf)
```

or a variant using `filterMap` for tagged subrelations.

However current production pressure is too small:

- ActualReversal is the only current family that directly uses global two-projection uniqueness over its whole list;
- ScheduledTerminal needs several **kind-filtered** projections rather than one global pair;
- the semantic census's former Scheduled Completion/Replacement memories have already been deleted by stronger recompression;
- `ReplacementFrontier` already owns finite partial-injective graph mechanics where source/successor uniqueness is actually part of a shared Application law.

A new Core `PartialInjection`, `BiMap`, `RelationMemory`, or `TwoEndpointMemory` would therefore add a named abstraction mostly to hide a handful of explicit `Nodup` checks.

That does not reduce the number of independent implementation principles enough to justify its fixed cost.

Decision: **keep the current explicit endpoint uniqueness fields**.

## 6. Why ReplacementFrontier is not the missing abstraction

`ReplacementFrontier` owns:

```text
source/successor uniqueness
reference closure
acyclicity
frontier = carrier outside source domain
```

ActualReversal has no superseded frontier meaning: both target and reversal Events remain physically accumulated historical facts.

Scheduled replacement uses the replacement subset of terminal evidence, but completion and retirement are not successor edges in the same graph and cross-kind conflicts must remain raw-visible.

Therefore promoting ActualReversal or all Scheduled terminal meanings into `ReplacementFrontier` would conflate graph mechanics with relation meaning.

## 7. Lookup mechanics are a separate, smaller question

ActualReversal exposes forward and reverse lookup by its globally unique endpoints. ScheduledTerminal exposes completion/replacement lookups through kind-specific scans.

These are small finite-list lookup mechanics, not evidence for a generic two-endpoint ontology.

If lookup duplication later becomes material, reuse or extend the already-small `FiniteKeyed` representation mechanic rather than introducing a new public relation carrier.

## 8. Formal-method verdict

The right formal result for this audit is negative:

```text
global bi-unique carrier
  cannot preserve
kind-local uniqueness + raw cross-kind conflict observability
```

No new temporal model is needed. This is a finite structural distinction, and the concrete Scheduled witness plus the previously qualified Observation-244 behavior is sufficient.

A future extraction should be reopened only if at least one of these pressures appears:

1. a third live semantic family independently repeats the exact same two-projection `Nodup` mechanics;
2. proof duplication around two-endpoint lookup/permutation becomes substantial;
3. a small helper shows a measured net source/proof reduction without changing raw-state admission;
4. the helper can stay representation-level rather than becoming a household relation ontology.

At that point Lean should prove wrapper/representation equivalence and preservation of each family's admission behavior.

## 9. SA-002 verdict

### Keep explicit

```text
ActualReversalMemory
ScheduledTerminalMemory
```

Their semantic meanings and raw admission surfaces are independently justified.

### Already compressed correctly

Scheduled Completion / Retirement / Replacement no longer own separate runtime memory mechanisms; `ScheduledTerminalMemory` is the stronger current compression result.

### Already shared where appropriate

`ReplacementFrontier` owns partial-injective supersession graph mechanics in Application where those graph laws genuinely coincide.

### Not earned

```text
NO generic BiMap / PartialInjection Core type
NO universal TwoEndpointMemory
NO generic household RelationMemory
NO promotion of ActualReversal into replacement-frontier semantics
NO globally source-unique Scheduled terminal carrier
```

### Implementation state

No production change is recommended from SA-002 at this checkpoint.

This is a useful negative audit result: the apparent two-endpoint duplication is now too small and semantically non-uniform to justify another abstraction.

Next ledger step: SA-003 temporal / effective evidence family.