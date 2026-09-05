# Application 031 — Production-typed BudgetWindow manifest parity

## Question

Application 030 qualified one complete retained read-only product answer (`loamJournalExport`) through generation-manifest authority. Application 028 identified exactly two retained read-only executable roots in the steady-state authority-consumer frontier.

This application asks:

> Can the remaining read-only executable root, `loamBudgetWindow`, consume one captured manifest generation through the existing production typed decoders and reproduce the current sidecar-derived answer byte-for-byte?

A successful result would close the retained read-only executable frontier at 2/2 without changing production source.

## Freshness and stack

This observation is stacked on Application 030 / PR #410 head `dc177ab681a5a3092958c0a7233d3cf28f1f4aec`.

At observation start actual `main` is `f9428b09bea3ee61d61ed8a6fa0512ec7a2701a9` (`experiment: separate choice commitment and funding posture (#408)`), unrelated to the publication stack.

Application 030 is open and mergeable, and its exact-head Application 030 pull-request workflow is successful.

## Current BudgetWindow meaning

The production `BudgetWindowCli` requires these physical families:

```text
Capacity
CapacityEffective
Event
ActualValidity
ActualRouting
```

`EventCorrection` is optional and physical absence means empty correction evidence for this caller.

The query then:

1. resolves ActualValidity correction history to one current occurrence date per Event;
2. derives Capacity entitlement over `[start, end)`;
3. derives routed Actual consumption over the same coordinate window;
4. derives Remaining as exact Entitlement minus Consumption;
5. optionally enumerates every Purpose represented by retained Capacity evidence for `--all`.

No BudgetPeriod, Remaining, or second accounting authority is introduced.

## Scratch manifest path

Application 031 adds only an experiment executable source. It does not modify `BudgetWindowCli` or production persistence.

The scratch path is:

```text
capture CURRENT once
  -> resolve six family-presence entries
  -> verify requested content-addressed object SHA-256
  -> existing production decoders
       decodeCapacityMemory?
       decodeCapacityEffectiveMemory?
       decodeEventMemory?
       decodeEventCorrectionMemory?
       decodeActualValidityHistory?
       decodeActualRoutingHistory?
  -> existing ActualValidityFrontier / CapacityWindowInspection semantics
  -> current BudgetWindow rendering rules
  -> derived answer
```

Five families remain required. EventCorrection keeps its caller-specific absent-as-empty policy.

## Practical fixture

The workflow reuses the existing practical BudgetWindow dogfood shape:

```text
Capacity
  food     100 JPY effective 2026-08-17
  general   50 JPY effective 2026-08-17

Actual
  2026-08-16 expenses:food 20 JPY  (outside window)
  2026-08-18 expenses:food 30 JPY  (inside window)

Routing
  expenses:food -> food
```

The real production executables create all sidecars:

- `loamCapacity`
- `loamMovement`
- `loamActualRouting`

The real `loamBudgetWindow` then produces two baseline answers:

```text
food
--all
```

The scratch publisher captures those exact sidecar family bytes into one manifest generation. A separate Lean process then reports the same two queries from the manifest-selected generation.

Both output files must match the real production `loamBudgetWindow` output with exact `cmp` byte equality.

Expected core answers remain:

```text
food:    entitlement 100, consumption 30, remaining 70 JPY
general: entitlement  50, consumption  0, remaining 50 JPY
```

## Qualified result

The exact practical probe succeeded on the initial Application 031 head and reported:

```text
Application 031 BudgetWindow byte parity PASS
read_only_executable_frontier_qualified=2/2
parity_cases=2
byte_equal_cases=2
production_typed_family_boundaries=6
required_absence_fail_closed=1
```

The selected generation recorded `EventCorrection` as `ABSENT`; the manifest-backed query preserved the current BudgetWindow empty-correction policy.

Both the single-purpose `food` answer and the `--all` answer were byte-for-byte equal to the real production `loamBudgetWindow` output. The observed answers remained:

```text
food:    entitlement 100, consumption 30, remaining 70 JPY
general: entitlement  50, consumption  0, remaining 50 JPY
```

Each manifest-backed query captured `CURRENT` once and crossed six production typed family boundaries.

## Required-absence pressure

The workflow then edited only scratch `CURRENT` so `ActualRouting` was explicitly `ABSENT` while the old content-addressed routing object still physically existed.

The manifest-backed BudgetWindow refused with `ActualRouting is absent from selected generation`.

This distinguishes:

```text
object exists somewhere
```

from:

```text
selected generation contains required ActualRouting evidence
```

and confirms that explicit family presence is an authority property rather than directory discovery.

## Finding

Applications 030 and 031 together now qualify both retained steady-state read-only executable roots:

```text
loamJournalExport  qualified through manifest authority
loamBudgetWindow   qualified through manifest authority

read-only executable frontier = 2/2
```

For both product paths, changing the physical authority topology did not require changing the production typed decoders or household projection semantics.

This does not authorize production migration by itself. The remaining steady-state authority-consumer pressure is writer-capable execution. The scratch parity executable also copies private BudgetWindow rendering shape solely to compare externally visible bytes; no renderer API refactor is claimed.

## Boundary

No production source, canonical path, persistence format, typed decoder, CLI behavior, writer path, household data, migration contract, or deployment mechanism changes. This remains a scratch executable parity observation.
