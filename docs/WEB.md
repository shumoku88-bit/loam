# LOAM Web

Status: **first read-only second-frontend experiment**

LOAM Web tests one narrow architectural claim:

> Can a human-facing frontend other than the production TUI present useful
> household answers without owning household semantics or authority?

## Browser strategy

The first slice deliberately starts with the smallest browser baseline rather than
with a rich Web application.

```text
Level 0  semantic HTML + conservative CSS
         Dillo / NetSurf target

Level 1  progressive visual enhancement
         Safari and other modern browsers

Level 2  optional interaction enhancement
         only after the semantic and authority boundaries remain intact
```

The baseline uses no JavaScript and avoids CSS Grid, `color-mix`, rounded-corner
requirements, HTML5-only structural elements, and client-side household state.
A browser may ignore styling and the document must still preserve the same household
answers and explicit unavailability.

Dillo and NetSurf are compatibility targets for the first slice. Browser-specific
visual polish is intentionally deferred until the plain document has been exercised
locally in those browsers.

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

Open the same URL in Dillo, NetSurf, or Safari. The household meaning must not depend
on which browser renders it.

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
semantic HTML
        |
        +--> Dillo / NetSurf
        |
        +--> Safari / modern browser
```

The Python standard-library HTTP server only serves the generated file. It does
not parse household data or call LOAM semantics.

Missing or refused evidence remains visibly unavailable. The Web layer must not
turn missing authority into zero, empty, false, or NotDue.

## Progressive-enhancement rule

A later Safari-rich layer may add layout, typography, responsive cards, timelines,
or optional partial-page interaction. It must not become required to understand the
page or to recover household meaning.

The intended asymmetry is:

```text
remove rich CSS / optional JavaScript
        -> presentation becomes simpler
        -> household meaning survives
```

If a rich layer requires a second household model, duplicated calculations, or
browser-owned canonical state, it has crossed the LOAM frontend boundary.

## What this experiment does not claim

This first slice does not establish that:

- every TUI capability is presentation-neutral;
- Web writes are safe or qualified;
- the frontend is live-updating;
- the page is a general HTTP API;
- browser presentation is a new household authority;
- LOAM is ready for remote hosting;
- CI has visually qualified every lightweight browser implementation.

In particular, this experiment deliberately adds no write path.

## Success criterion

The experiment succeeds when the same useful household document works in a
lightweight browser and a modern browser while all semantic answers still come from
existing shared Review boundaries and no Web-specific retained meaning is introduced.

Only after that boundary is stable should a later experiment consider richer Safari
presentation and then one small write path through an existing presentation-neutral
HouseholdCommand/publisher boundary.
