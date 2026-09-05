# Observation 171: relation qualification / publication factor

## Question

Observation 170 found that relation completeness is a finite writer-closure problem:

```text
for every operation that can establish current covered Actual validity:
  relation-complete
  or
  fail closed / impossible in that region
```

The tempting next implementation is one common `ActualAdmission` publisher used by every operation.

Before doing that, ask a narrower structural question:

> Is the earned commonality a shared relation-completeness qualification law, or a shared physical publication protocol?

## Current-main pressure

Current main already distinguishes several publication shapes.

Practical Movement, Scheduled completion, and movement-correction replacement eventually publish a new Event as the authority commit. Date correction can establish or move current Actual validity without publishing a new Event. Historical publication is separate one-time approved-byte cutover machinery.

Earlier Application observations already established two useful constraints:

- writer ownership spans `observe -> prepare -> admit -> publish` for the operation being performed;
- a later fact family can remain an independently typed stream, with cross-family coordination added only when an actual invariant requires it.

So forcing every covered-validity operation through one Event-last publisher could over-generalize the physical mechanism even if all operations need the same relation-completeness decision.

## Model

The bounded Alloy model separates:

- operation kind;
- physical publication protocol;
- relation meaning;
- covered-validity participation;
- relation qualification;
- retained positive relation evidence.

Observation-local publication protocols are:

```text
Movement / ScheduledCompletion / CorrectionReplacement
  -> EventLast

DateCorrection
  -> ValidityOnly

HistoricalPublish
  -> BulkApprovedBytes
```

These names describe current operational shapes only. They are not proposed production types.

The candidate shared law is intentionally protocol-neutral:

```text
covered + qualified
  -> positive evidence iff meaning is HasEdge
```

The publication protocol remains outside that law.

## Probes

The model asks whether:

1. all five operation kinds can obey one qualification law;
2. the same qualification law can coexist with three distinct publication protocols;
3. operation kind fails to determine relation meaning, so adapters still have to supply/recover the meaning rather than the common capability inferring it;
4. a correction replacement can legitimately have a different relation meaning from its target, so target meaning is not a theorem of replacement meaning;
5. historical legacy publication can remain outside shared qualification while it stays outside the covered region;
6. an unqualified covered operation can still break known-none projection;
7. qualified covered absence determines no edge;
8. closing qualification over the covered frontier makes known-none sound;
9. covered qualification does not imply Event-last publication;
10. neither operation kind nor correction target determines relation meaning.

## Candidate factor

The smallest common capability suggested by the model is not a generic publisher:

```text
operation-specific preparation
        |
        v
relation meaning decision / evidence
        |
        v
shared covered-validity qualification
        |
        +--> allow covered transition
        |
        `--> refuse / remain outside covered region

then:
  operation-specific publication protocol
```

In other words, the common seam is closer to an authorization/qualification predicate than to a transaction framework.

Movement, Scheduled completion, correction replacement, date correction, and any covered historical admission may reuse that law while keeping their existing publication sequencing and ownership scopes.

## Stop conditions

This observation does **not** earn:

- one universal `ActualAdmission` transaction object;
- one physical publisher for all canonical streams;
- changing date correction into an Event replacement merely to fit an abstraction;
- making HistoricalPublisher permanent infrastructure;
- inferring relation meaning from CLI operation kind;
- automatically copying target relation meaning to a correction replacement;
- a universal `Fact` or `Relation` framework;
- a concrete production relation stream yet.

If the common qualification law is later implemented, each adapter may still have operation-specific work before qualification. For example, a correction replacement may carry, translate, re-ask, or explicitly revise relation meaning; the shared gate merely refuses covered admission until that meaning is sufficiently qualified.

## Current checkpoint

The likely production direction is therefore:

```text
shared law
  small, semantic, source-neutral

publication protocols
  remain local until stronger pressure earns consolidation
```

This preserves the conservative-fact-extension result while giving Observation 170 one auditable place to state relation-completeness admission.

Observation 171 is based directly on current main `3348c59206c124293130bb8bd8a37fc8210e768f`; open Observations 163–170 are semantic antecedents, not code dependencies.
