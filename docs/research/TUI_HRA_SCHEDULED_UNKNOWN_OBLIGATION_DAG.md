# G2-029 — HRA Scheduled Unknown preservation obligation DAG

Status: **Generation-2 audit evidence — FIX QUALIFIED**

Primary instruments: **DRAKONview + semantic result DAG + production reachability**.

## Question

Does the production HRA Scheduled workspace preserve the shared open-world
`ScheduledReview.dayEvidence` distinction between:

- explicit current-open Scheduled occurrences on one day;
- absence that is justified as complete; and
- absence for which completeness is not known?

LOAM Architecture Law 6 requires unknown and incomplete evidence to remain
explicit rather than silently becoming empty, false, zero, or irrelevant.

## Production path

```text
Home `p`
  -> Cli.hraScheduledLoop
       -> HraScheduled.view
            -> HraScheduled.scopeEvidence
                 -> ScheduledReview.dayEvidence focusDate
```

The production path consumes the shared day-evidence answer directly. No separate
semantic engine is needed in the TUI.

## Observed pre-fix collapse

Before G2-029, `HraScheduled.scopeRecordsResult` contained:

```text
ScheduledReview.dayEvidence = .due first rest
  -> .ok (first :: rest)

ScheduledReview.dayEvidence = .unknown
  -> .ok []
```

The view later saw an empty successful result and rendered:

```text
(none due on this day)
```

The pre-fix DAG was therefore:

```text
ScheduledReview .unknown
        |
        v
      .ok []
        |
        v
"none due on this day"
```

This collapsed an independently meaningful open-world result into the same
mechanical list used when no explicit rows were available.

## Why this was a semantic bug

`ScheduledReview.dayEvidence` deliberately preserves `.unknown`. The repository's
architecture law says missing/incomplete/unknown evidence must not silently become
empty or false. The defect was confined to presentation adaptation; the shared
review answer itself remained correct.

The older Main Scheduled workspace already rendered `Scheduled / Unknown` and
`Unknown is not NotDue`. G2-029 moves that guarantee into the production HRA
Scheduled surface before any later compatibility retirement.

## Qualified result DAG

The production adapter now retains an explicit presentation result:

```text
ScheduledReview.dayEvidence
   |
   +-- .due records ------> ScopeEvidence.records records
   |
   +-- .unknown ----------> ScopeEvidence.unknown
   |
   `-- invalid/refusal ---> Except.error

ScopeEvidence.records []
   -> no explicit current-open rows

ScopeEvidence.unknown
   -> "Scheduled [Unknown]"
   -> "Unknown; no completeness horizon claimed"
```

`recordsForScope` still projects `ScopeEvidence.unknown` to `[]` for cursor/locus
mechanics. Presentation completeness does not read that list projection; headers,
empty-row text, and detail text inspect `scopeEvidence` instead.

`ScopeEvidence` intentionally derives no `Repr` or equality instance. Its retained
records do not need those capabilities for this boundary. The first Production TUI
attempt exposed that requesting unused derived instances would impose unrelated
instances on `ScheduledOccurrence`; removing those derives changed no semantics.

## Focused regression

`TuiHraScheduled` probes a day with no completeness horizon and requires:

```text
scopeEvidence = .ok .unknown
render contains "Scheduled [Unknown]"
render contains "Unknown; no completeness horizon claimed"
render does not contain "none due on this day"
```

The existing due-day, browsing, filtering, command, and startup-unavailability
checks remain in the same test surface.

## KEEP boundaries

G2-029 preserves:

- `ScheduledReview.dayEvidence` unchanged;
- HRA Scheduled Focus Day and All Current scopes;
- current-open occurrence browsing, locus filtering, selection, and commands;
- startup/invalid evidence refusals;
- write delegation and post-write canonical reload behavior;
- `Unknown` as distinct from startup unavailability;
- the older Main workspace until a separate audit retires that compatibility path.

## Qualification result

The corrected code head was
`d631e255eba434490aa84f827c1467f89c6cd2fa`.

Qualification on that head:

- Compression Audit #924: **SUCCESS**.
- Selected Lean Observations #1165: **SUCCESS**.
- Production TUI #786: **SUCCESS, all 62 verification steps passed**.
- Production executable build: **SUCCESS**.
- Legacy Scheduled browse/detail/open-world Unknown step 22: **SUCCESS**.
- HRA Scheduled workspace mechanics step 23, including the new focused Unknown
  regression: **SUCCESS**.
- Scheduled creation, terminal, selected-day composition, Reports, Capacity,
  routing, footer geometry, and PTY gates all completed without regression.

The first Production TUI attempt had failed only because `ScopeEvidence` requested
unused `Repr` and `DecidableEq` instances that its record payload did not provide.
Those derives were removed; the semantic result shape stayed unchanged. The
corrected head then passed the entire production qualification suite.

## Generation-2 verdict

**FIX QUALIFIED.**

The shared Scheduled semantics were already correct. G2-029 repaired the production
HRA Scheduled adapter so that open-world Unknown survives presentation adaptation
instead of being mislabeled as an empty day. Local list mechanics remain compact,
while evidence completeness stays explicit at the boundary where users see it.
