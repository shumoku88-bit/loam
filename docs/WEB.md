# LOAM Web

Status: **first read-only second-frontend experiment**

LOAM Web tests one narrow architectural claim:

> Can a human-facing frontend other than the production TUI present useful
> household answers without owning household semantics or authority?

## Run

From the repository root:

```sh
./tools/loam web [LOAM_DATA_DIR]
```

The command:

1. builds the `loamWeb` Lean executable;
2. loads shared Review answers from the selected household root;
3. renders one static HTML snapshot to `.lake/loam-web/index.html`;
4. serves that file on `http://127.0.0.1:8765`.

The server binds only to localhost.

The first slice is intentionally snapshot-on-start. Restart the command to refresh
canonical evidence.

## Current surface

The page shows four read-only sections:

- recent Actual;
- current-open Scheduled;
- open Attention;
- all-retained Capacity.

The Web frontend does not reconstruct those meanings. It consumes:

```text
ActualReview
ScheduledReview
AttentionReview
CapacityReview
```

and performs presentation only.

## Authority boundary

The Web frontend has no publisher, writer, canonical storage, recurrence model,
account model, or independent household state.

```text
canonical household evidence
        |
        v
shared Review boundaries
        |
        v
Loam.Web.Snapshot
        |
        v
HTML
        |
        v
localhost browser
```

The Python standard-library HTTP server only serves the generated file. It does
not parse household data or call LOAM semantics.

Missing or refused evidence remains visibly unavailable. The Web layer must not
turn missing authority into zero, empty, false, or NotDue.

## What this experiment does not claim

This first slice does not establish that:

- every TUI capability is presentation-neutral;
- Web writes are safe or qualified;
- the frontend is live-updating;
- the page is a general HTTP API;
- browser presentation is a new household authority;
- LOAM is ready for remote hosting.

In particular, this experiment deliberately adds no write path.

## Success criterion

The experiment succeeds when the browser can present useful household state while
all semantic answers still come from existing shared Review boundaries and no
Web-specific retained meaning is introduced.

Only after that boundary is stable should a later experiment consider one small
write path through an existing presentation-neutral HouseholdCommand/publisher
boundary.
