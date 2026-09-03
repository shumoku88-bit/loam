# Observation 116: May an open Scheduled view determine which terminal actions the UI should offer?

## Question

The first practical Upcoming-style view now derives open Scheduled occurrences from retained LOAM evidence.

A tempting UI rule is:

```text
open Scheduled row
    -> show Complete
    -> show Cancel
```

But the existing publication protocol already contains a sharper distinction.

A completion relation may be retained before its Actual Event is published. Readers deliberately treat that raw relation as inert, so the Scheduled occurrence remains visible as open. The completion writer can retry that interrupted publication, while the cancellation writer conservatively refuses to compete with the retained completion relation.

The question is therefore:

> Is the `open` projection itself sufficient to determine which terminal actions a truthful UI may enable?

## Concrete states

The bounded Alloy model keeps only the evidence needed to expose the distinction.

```text
FreshOpen
  no terminal evidence

InterruptedCompletion
  completion relation retained
  Actual Event absent

Completed
  completion relation retained
  Actual Event present

Retired
  retirement evidence retained
```

Derived reader meaning:

```text
open
  = no retirement
  + no effective completion

completion is effective
  = completion relation
  + referenced Actual Event
```

Practical writer meaning in this observation:

```text
Complete / retry admitted
  when not retired
  and not already effectively completed

Cancel admitted
  when not retired
  and no completion relation is retained
```

This matches the current practical Scheduled lifecycle boundary rather than inventing a generic UI theory.

## Competing presentation rules

### Naive open-driven UI

```text
if row is open:
  enable Complete
  enable Cancel
```

### Admission-aware UI

```text
for each action:
  enable it only when that action is admitted by the current evidence
```

## Expected counterexample

`InterruptedCompletion` is the important witness:

```text
completion relation = yes
Actual Event         = no
retirement           = no

open row             = yes
Complete / retry     = admitted
Cancel               = blocked
```

So:

```text
open Scheduled
    -/->
Cancel admitted
```

A UI that derives buttons only from the open/closed projection can therefore present an action that the writer must reject.

## Commands

The model requires these results:

```text
interruptedOpenButCancelBlocked     SAT
naiveOffersBlockedAction            SAT
AdmissionAwareOnlyOffersAdmitted    UNSAT
FreshOpenOffersBoth                 UNSAT
ClosedOffersNoTerminalActions       UNSAT
OpenImpliesCancelAdmitted           SAT
```

For `check` commands, SAT means Alloy found a counterexample to the assertion.

## Interpretation

If the expected results hold, the first earned UI rule is deliberately narrow:

```text
projection answers what is visible
admission answers what is operable
```

The UI should not infer enabled actions merely from a displayed status or row membership when the underlying evidence carries a finer operational distinction.

For LOAM this suggests a useful presentation seam:

```text
World / retained evidence
        |                 |
        v                 v
   projection          admission
   "show this"        "allow this"
        \                 /
         \               /
          human interface
```

The same row may therefore remain visible while one action is disabled and another remains available.

## What this does not establish

This observation does not introduce:

- a generic UI framework;
- a generic `Action` type in Practical Core;
- a stored UI state;
- a universal disabled-reason taxonomy;
- a requirement that every blocked action be shown disabled rather than hidden;
- colors, layout, keyboard bindings, mouse behavior, panels, tabs, or widgets;
- a claim that every future LOAM operation follows the Scheduled lifecycle shape.

A later observation may ask whether a blocked visible action should carry explicit reason evidence such as `completion publication in progress`. That should be earned separately rather than bundled into this first UI law.
