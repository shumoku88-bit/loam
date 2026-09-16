# G2-033 — Scheduled terminal admission asymmetry obligation DAG

Status: **Generation-2 targeted frontier — KEEP / NO NEW STRUCTURAL PRESSURE**

Baseline main:

```text
415e35d99608a4549de649232d5349741ccd6c0b
docs(audit): close G2-032 Attention delivery gap (#976)
```

Primary instruments: **DRAKONview + production obligation DAG + Alloy/SPIN cross-check + runtime regression + history**.

## Question

The Generation-2 coverage checkpoint left only a few targeted holes. Role Flow, Capacity, and Relation publication turned out to have already received same-scale pressure in earlier Generation-2 work. One remaining surface that still looked thinner was the cancellation half of `ScheduledTerminalPublisher`.

Completion and cancellation live in one publisher and one retained terminal relation, but their admission branches are visibly asymmetric. Generation 2 therefore asks:

> Is the cancellation-specific completion-claim refusal a duplicated lifecycle check that should collapse into the shared current-open projection, or does it preserve independent crash/recovery meaning?

The answer is **KEEP the asymmetry**.

## Existing shared structure

First-generation compression already removed the physical duplication that was safe to remove.

PR #696 recompressed Scheduled completion, retirement, and replacement meaning into one runtime terminal relation. PR #706 then retired the legacy dedicated lifecycle adapters while preserving the selected wire format. PR #848 shared the Scheduled-to-Actual lock order across production writers.

The current terminal publisher therefore already shares the mechanics that genuinely have one reason to change:

```text
ScheduledTerminalPublisher
        |
        +-> ScheduledActualOwnership
        |
        +-> load Scheduled lifecycle image
        |
        +-> load current Actual evidence
        |
        +-> currentOpen? / findOpen?
                 |
                 v
          Application.currentOpenScheduled
```

The remaining question is above that shared base: which operation-specific obligations must be discharged before publication?

## Completion obligations

Completion turns one Scheduled occurrence into a normalized Actual Event.

Its production path owns obligations that cancellation does not have:

```text
current-open Scheduled target
        |
current Locus admission
        |
plain Actual Movement draft admitted
        |
deterministic completion EventId
        |
retained completion endpoint ownership
        |
append Actual Event + occurrence date + optional description
        |
publish Scheduled completion claim FIRST
        |
publish normalized Actual generation SECOND
```

The relation-first order deliberately admits an interrupted state:

```text
completion relation retained
Actual Event absent
```

That state is not a completed occurrence yet. It is recovery evidence. A later completion retry must reuse the retained canonical Actual endpoint and finish publication.

## Cancellation obligations

Cancellation writes no Actual Event. It appends a retirement terminal with no target.

However it cannot decide admission from `currentOpen?` alone.

Before `findOpen?`, the writer asks whether any completion relation is already retained for the Scheduled identity:

```text
completion claim retained?
        |
        +-- yes + Actual exists
        |       -> refuse: already completed
        |
        +-- yes + Actual absent
        |       -> refuse: interrupted completion; retry completion
        |
        +-- no
                -> require current-open
                -> append retirement
```

This extra branch is the apparent asymmetry under audit.

## Why current-open is insufficient

The read projection and the mutation admission question are intentionally different.

An interrupted completion is represented by:

```text
completion relation = present
Actual Event         = absent
retirement           = absent
```

Scheduled readers treat the raw completion relation as inert until the referenced Actual Event exists. Therefore the occurrence remains current-open for read purposes.

But cancellation must not compete with that already-retained completion claim. If it appended retirement, the authority would retain conflicting terminal claims for one source.

So this implication is false:

```text
current-open Scheduled
        ->
Cancel admitted
```

The counterexample is the interrupted completion state.

## Existing Alloy evidence

Observation 116 modeled exactly this distinction.

It separates:

```text
projection  = what remains visible
admission   = which operation is currently allowed
```

The bounded model found the intended witness:

```text
InterruptedCompletion
  open row         = yes
  Complete / retry = admitted
  Cancel           = blocked
```

The model therefore rejects a UI law that enables cancellation merely because the row projects as open.

This is direct evidence that the writer asymmetry is not an accidental duplicate branch.

## Existing SPIN evidence

Observation 118 tested the temporal version of the same obligation.

A UI may render Complete and Cancel from a fresh state and then become stale before activation. The safe protocol is:

```text
render snapshot
        |
world may change
        |
user activates action
        |
acquire terminal ownership
        |
re-read current evidence
        |
re-admit requested operation
        |
publish or refuse
```

SPIN found no safety violation for activation-time re-admission. Deliberately unsafe stale-Cancel and stale-Complete models both reached the conflicting-terminal assertion.

`ScheduledTerminalPublisher` already follows the safe shape by re-reading under `ScheduledActualOwnership` rather than trusting cached TUI state.

## Runtime regression

`Loam/Tests/ScheduledTerminalPublisher.lean` pins the production consequences:

- ordinary completion removes the occurrence from fresh Scheduled review;
- ordinary cancellation removes the occurrence from fresh Scheduled review;
- a stale completion after cancellation is refused;
- an interrupted completion can be resumed using the retained canonical endpoint;
- cancellation is refused when an interrupted completion claim already exists;
- completion re-checks current Locus admission before publication.

The test therefore covers both sides of the asymmetric terminal protocol, not only successful happy paths.

## Why not add a generic terminal admission helper?

A helper such as:

```text
admitTerminalAction(currentOpen, action)
```

would be too weak because current-open intentionally erases the distinction between fresh-open and interrupted-completion states.

A richer helper would have to reintroduce the raw completion claim, effective Actual existence, retirement state, and operation kind. That would merely repackage the existing branch structure while obscuring why completion recovery and cancellation exclusion differ.

No duplicated semantic decision is removed by doing so.

The existing shared layer is already at the correct seam:

- common lifecycle projection and target lookup are shared;
- common ownership order is shared;
- completion-specific recovery and Actual construction stay local;
- cancellation-specific exclusion of any retained completion claim stays local.

## Obligation DAG

```text
                  current retained world
                           |
              ScheduledActualOwnership
                           |
          +----------------+----------------+
          |                                 |
          v                                 v
     COMPLETION                         CANCELLATION
          |                                 |
     find current-open                 completion claim?
          |                          /                  \
     completion claim?             yes                  no
     /             \                |                    |
 existing          fresh      Actual exists?         find current-open
    |                |          /       \               |
reuse endpoint   allocate      yes       no          append retirement
    |                |          |         |
    +-------+--------+       refuse    refuse retry
            |
      admit Actual draft
            |
   publish completion claim
            |
    publish Actual generation
```

The branches converge on shared retained lifecycle meaning, but they do not carry the same operational obligations.

## Verdict

```text
one Scheduled terminal runtime relation             KEEP
shared Scheduled/Actual ownership order              KEEP
shared currentOpen? / findOpen? projection           KEEP
completion Actual construction and recovery          KEEP LOCAL
cancellation raw completion-claim exclusion          KEEP LOCAL
interrupted-completion asymmetry                     KEEP
new generic terminal-admission abstraction           DO NOT ADD
production code change                               NONE
```

**G2-033: KEEP / NO NEW STRUCTURAL PRESSURE.**

This is the second targeted KEEP / no-new-pressure result after the G2-031 coverage checkpoint, following G2-032 Attention closure. It therefore strengthens the checkpoint's closure signal. Generation 2 should perform one final broad falsification / coverage pass before declaring the campaign complete rather than reopening already-earned terminal distinctions.