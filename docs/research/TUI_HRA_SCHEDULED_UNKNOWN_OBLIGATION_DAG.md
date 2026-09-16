# G2-029 — HRA Scheduled Unknown preservation obligation DAG

Status: **Generation-2 audit evidence — FIX IDENTIFIED**

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
            -> HraScheduled.scopeRecordsResult
                 -> ScheduledReview.dayEvidence focusDate
```

The production path therefore consumes the shared day-evidence answer directly.
No separate semantic engine is needed in the TUI.

## Observed collapse

Current `HraScheduled.scopeRecordsResult` contains:

```text
ScheduledReview.dayEvidence = .due first rest
  -> .ok (first :: rest)

ScheduledReview.dayEvidence = .unknown
  -> .ok []
```

The view later sees an empty successful result and renders:

```text
(none due on this day)
```

The resulting DAG is therefore:

```text
ScheduledReview .unknown
        |
        v
      .ok []
        |
        v
"none due on this day"
```

This collapses an independently meaningful open-world result into the same
mechanical list used when no explicit rows are available.

## Why this is a semantic bug

`ScheduledReview.dayEvidence` deliberately preserves `.unknown`. The repository's
architecture law says missing/incomplete/unknown evidence must not silently become
empty or false. The current production Scheduled workspace violates that boundary
only in presentation adaptation; the shared review answer itself remains correct.

The older Main Scheduled workspace explicitly rendered `Scheduled / Unknown` and
`Unknown is not NotDue`, which is why its legacy regression still catches this
meaning even though Home `p` now enters HRA Scheduled instead.

## Target DAG

Retain an explicit presentation result:

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
   -> "Unknown; no completeness horizon claimed"
```

A list projection may still map Unknown to `[]` for cursor/locus mechanics, but
that projection must not be the answer used to label evidence completeness.

## KEEP boundaries

G2-029 must preserve:

- `ScheduledReview.dayEvidence` unchanged;
- HRA Scheduled Focus Day and All Current scopes;
- current-open occurrence browsing, locus filtering, selection, and commands;
- startup/invalid evidence refusals;
- write delegation and post-write canonical reload behavior;
- `Unknown` as distinct from startup unavailability;
- the older Main workspace until the production HRA surface independently carries
  the Unknown guarantee.

## Qualification obligations

The implementation must show that:

- Focus Day `.unknown` survives the HRA Scheduled adapter as an explicit result;
- the rendered production workspace says Unknown rather than `none due on this day`;
- an actual `.due` day still renders its explicit records;
- HRA Scheduled mechanics and startup-unavailability tests remain green;
- Scheduled browse/detail/open-world tests remain green while the legacy surface is
  still retained;
- Production TUI, Compression Audit, and Selected Lean Observations remain green.

## Generation-2 verdict

**FIX IDENTIFIED.**

The shared Scheduled semantics are correct; the production HRA Scheduled adapter
currently spends information by mapping Unknown to the same successful empty list
used by ordinary mechanics. Preserve Unknown at the adapter boundary before
retiring any legacy Scheduled presentation path.
