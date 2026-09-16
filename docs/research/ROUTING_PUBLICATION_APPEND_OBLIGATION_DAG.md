# G2-018 — Routing publication append obligation DAG

Status: **Generation-2 audit evidence — SIMPLIFY QUALIFIED**

Primary instruments: **DRAKONview + source comparison + Core-invariant ownership + existing runtime qualification**.

## Question

Actual and Scheduled routing are both historical Purpose-routing writers. At a glance they contain repeated validation, append, duplicate-refusal, persistence, and writer-ownership structure.

Generation 2 asks two separate questions:

1. Which similarities are one shared routing-history mechanic?
2. Which differences are independently earned semantic boundaries that must remain local?

The goal is not a generic `RoutingPublisher` framework. It is to move only a genuinely shared invariant to the smallest owner that already represents it.

## Same-scale comparison

### Actual routing

The production shape is:

```text
validate routing path
validate Locus token
validate RoutingEffective
validate managed Purpose token
        |
        v
lock Actual-routing authority
        |
        v
load existing history or initialize empty
        |
        v
construct RoutingEntry
        |
        v
append + re-admit (Locus, effectiveOn) uniqueness
        |
        v
save complete Actual-routing history
```

Its subject is:

```text
LocusId
```

and its effective coordinate is:

```text
RoutingEffective String
  = initial
  | dated YYYY-MM-DD
```

The `initial` distinction is independently qualified and must remain Actual-specific.

### Scheduled routing

The production shape is:

```text
validate dated effective coordinate
validate ScheduledId / Locus / Purpose tokens
validate both configured paths
        |
        v
lock Scheduled-routing authority
        |
        v
re-read Scheduled lifecycle
        |
        v
require retained ScheduledId
require occurrence contains selected Locus
        |
        v
load existing Scheduled-routing history
        |
        v
construct RoutingEntry
        |
        v
append + re-admit (subject, effectiveOn) uniqueness
        |
        v
save complete Scheduled-routing history
```

Its subject is:

```text
ScheduledRoutingSubject
  = ScheduledId × LocusId
```

and its effective coordinate is an ordinary dated `String`.

These differences are semantic parameters, not duplicate routing engines.

## Why the Scheduled lifecycle check stays local

Scheduled routing names a concrete occurrence-local subject. The writer therefore must establish that:

```text
ScheduledId exists
AND
selected Locus occurs in that retained Scheduled movement
```

Actual routing has no analogous occurrence identity. Its subject is the Locus itself.

The current Scheduled publisher does not classify the subject as currently open. That is intentional: open/unresolved classification belongs to read projections such as `ScheduledCommitmentInspection`, while routing is historical evidence.

Source inspection of current Scheduled writers also matters for ownership pressure:

- Scheduled creation appends a new occurrence;
- Scheduled replacement retains the source occurrence and appends a replacement occurrence plus terminal relation;
- completion/retirement append terminal evidence;
- none of those writers rewrites the retained movement of an existing Scheduled occurrence.

Therefore the predicate used by Scheduled routing,

```text
retained ScheduledId exists
AND occurrence contains Locus
```

is stable for an already-retained occurrence across current lifecycle publication. G2-018 does not add Scheduled-lifecycle ownership merely because the lifecycle is another semantic input.

The previous publisher comment saying the lifecycle was re-read "under lock" was imprecise: the routing authority is locked; the Scheduled lifecycle is re-read during that publication interval. The comment is corrected without changing ownership semantics.

## Why current Locus admission is not made a shared routing guard

Observation 212 gives `LocusAdmissionVocabulary` a deliberately narrow meaning:

> a new **quantity-bearing** canonical write may use this LocusId.

It explicitly separates:

```text
historically referenced Loci
!=
Loci approved for new quantity publication
```

and requires old evidence using a no-longer-approved Locus to remain readable.

Actual routing is interpretation evidence, not a new quantity Effect. `ActualRoutingReview` already exposes routing subjects outside current Locus admission as `historicalOnlyRouteLoci`.

Therefore G2-018 does not add current Locus-admission gating to Actual routing merely to make it resemble quantity writers or the routing administration candidate list. Such a gate could block legitimate historical interpretation of a retired Locus.

## The duplicated mechanic

Both publishers previously implemented the same local history transition directly:

```text
RoutingHistory.ofEntries? (history.entries ++ [entry])
```

The meaning of failure is identical in both cases:

```text
new entry duplicates an existing (subject, effectiveOn) coordinate
```

This is not an Actual-specific or Scheduled-specific rule. It is exactly the local invariant already owned by generic Core:

```text
RoutingHistory Subject Time
coordinateNodup :
  (entries.map (fun e => (e.subject, e.effectiveOn))).Nodup
```

The repository already uses the same ownership pattern for other semantic memories. For example `EventMemory.add?` owns EventId append admission instead of requiring each caller to reconstruct `ofEvents? (events ++ [event])`.

## Minimal production factorization

G2-018 introduces only:

```lean
def RoutingHistory.add?
    (history : RoutingHistory Subject Time)
    (entry : RoutingEntry Subject Time) :
    Option (RoutingHistory Subject Time) :=
  ofEntries? (history.entries ++ [entry])
```

and replaces the two publisher-local reconstructions with:

```text
history.add? entry
```

This is definitionally the same transition the publishers already performed. No new representation, sorting rule, effective-time rule, authority, or persistence format is introduced.

## What remains deliberately separate

```text
Actual subject type                         KEEP LOCAL
Scheduled subject type                      KEEP LOCAL
Actual initial | dated coordinate           KEEP LOCAL
Scheduled ordinary dated coordinate         KEEP LOCAL
Scheduled occurrence/Locus validation       KEEP LOCAL
Actual missing-storage -> empty policy       KEEP LOCAL
Scheduled missing-storage -> refusal policy  KEEP LOCAL
publisher diagnostics                        KEEP LOCAL
routing authority files                      KEEP SEPARATE
```

In particular, the different missing-storage contracts are observable and must not be hidden by a generic publisher helper.

## Why no generic RoutingPublisher

A larger shared publication layer would immediately need parameters/adapters for:

- different subject types;
- different time types;
- different date validation;
- Scheduled occurrence membership validation;
- Actual absent-as-empty versus Scheduled missing-as-error;
- different persistence functions;
- different diagnostics and CLI/TUI entrances.

That would share orchestration while obscuring the reasons those paths differ.

The one mechanic below those differences is the append invariant, and Core already has the correct generic owner for it.

## Qualification result

Production/audit head `a76c3b0a6e7f9246b35e314b0efbdf9b62714dea` qualified the factorization across both routing specializations and the broader dependent surface.

Successful runs:

```text
Practical Actual Routing Writer       SUCCESS
Practical Scheduled Routing           SUCCESS
Practical Actual Routing Persistence  SUCCESS
Compression Audit                     SUCCESS
Practical Slice A2                    SUCCESS
Practical Slice B                     SUCCESS
Stateless Shadow Quantity             SUCCESS
Cycle Funding Inspection              SUCCESS
Observation 078                       SUCCESS
Production TUI                        SUCCESS, all 62 substantive steps
Selected Lean Observations            SUCCESS on rerun
```

The first Selected Lean attempt failed before any Lean build because the runner could not resolve `release.lean-lang.org` while installing Elan. The failed job was rerun unchanged and completed successfully. This was infrastructure failure, not a source/proof failure.

The routing-specific runtime stories preserved all distinguishing behavior.

### Actual

`Practical Actual Routing Writer` passed:

```text
initial managed append
initial unmanaged append
dated append
duplicate coordinate refusal
invalid date refusal
persistence reload / latest-visible behavior
```

### Scheduled

`Practical Scheduled Routing` passed the existing publisher story, including:

```text
managed + unmanaged append
unknown ScheduledId refusal
absent-Locus refusal
missing / malformed authority refusal
duplicate coordinate refusal
later route selection
earlier route preservation
CLI publication
re-read of updated Scheduled lifecycle
```

Production TUI also passed the Actual Purpose routing administration steps, Scheduled Routing TUI interaction, Scheduled continuation routing inheritance, and every downstream report/workspace check.

## Obligation DAG

```text
                         routing publication
                                |
              +-----------------+-----------------+
              |                                   |
              v                                   v
       semantic entrance                    history mutation
              |                                   |
      +-------+--------+                          v
      |                |                 construct RoutingEntry
      v                v                          |
   Actual           Scheduled                     v
      |                |                  RoutingHistory.add?
 Locus subject     Scheduled×Locus                 |
 initial|dated      dated only                     v
 absent->empty     existing authority      coordinate unique?
      |            occurrence check           /       \
      |                |                     no       yes
      +-------+--------+                     |         |
              |                              v         v
              v                           refuse     persist
       KEEP semantic split

Shared node earned:
  RoutingHistory.add?

Not earned:
  generic RoutingPublisher
  shared authority
  shared subject/time wrapper
  extra Scheduled lifecycle lock
  LocusAdmission gate for all routing
```

## Final verdict

```text
Actual / Scheduled routing semantics       KEEP SEPARATE
RoutingHistory append invariant            SHARE IN CORE
publisher-local append reconstruction      REMOVE
Scheduled occurrence check                 KEEP LOCAL
Scheduled lifecycle extra ownership        DO NOT ADD
Actual current-Locus admission gate        DO NOT ADD
Generic RoutingPublisher                    DO NOT ADD
```

**G2-018: SIMPLIFY QUALIFIED — `RoutingHistory` owns append uniqueness; Actual and Scheduled routing publication boundaries remain semantically separate.**
