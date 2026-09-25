# LOAM Web

Status: **local household frontend with explicit Record confirmation**

LOAM Web tests one architectural claim:

> Can a human-facing frontend other than the production TUI present useful
> household answers without owning household semantics or authority?

## Browser strategy

The first slice deliberately starts with the smallest browser baseline rather than
with a rich Web application.

```text
Level 0  semantic HTML + conservative CSS
         Dillo target

Level 1  progressive visual enhancement
         Safari and other modern browsers

Level 2  optional interaction enhancement
         only after the semantic and authority boundaries remain intact
```

The baseline uses no JavaScript and avoids CSS Grid, `color-mix`, rounded-corner
requirements, HTML5-only structural elements, and client-side household state.
A browser may ignore styling and the document must still preserve the same household
answers and explicit unavailability.

Dillo is the first lightweight-browser compatibility target. Browser-specific visual
polish is intentionally deferred until the plain document remains useful by itself.

## Run

From the repository root:

```sh
./tools/loam web [LOAM_DATA_DIR]
```

The command:

1. builds the `loamWeb` Lean executable;
2. starts a localhost-only standard-library HTTP server on `127.0.0.1:8765`;
3. on every GET, invokes `loamWeb` against the selected household root;
4. re-reads the shared Review boundaries and renders a fresh semantic HTML document.

The server does not retain household answers between requests. It also exposes a
small Record form at `/record`. Review performs a read-only Lean admission
preview. Only the separate explicit Confirm action can publish household data.

Open the same URL in Dillo or Safari:

```text
http://127.0.0.1:8765
```

Reloading the page re-reads canonical evidence. No JavaScript is required for this
freshness boundary.

## Request-on-read

The Web frontend deliberately treats freshness as a server/read-boundary concern:

```text
browser GET / reload
        |
        v
localhost transport
        |
        v
loamWeb
        |
        v
shared Review boundaries
        |
        v
fresh semantic HTML
```

The Python server owns HTTP transport only. It does not parse household persistence,
recompute Budget, classify accounting roles, or hold canonical state.

The Lean renderer can also write the current HTML document directly to stdout by
using `-` as the output path. This keeps the server from needing to understand the
document format beyond serving the bytes returned by LOAM.

Responses are marked non-cacheable so a browser reload reaches the current read
boundary rather than silently reusing an old document.

## Current surface

The Home document currently exposes:

- Home orientation with `[Record]` nearby;
- recent Actual;
- current-open Scheduled;
- Current Budget;
- open Attention;
- Raw Capacity (all retained);
- Reports.

The separate `/record` document is the first interactive Web surface. Its v0
form collects Date, Description, Measure, From, To, and exact amounts. Admitted
Locus choices come from the existing Locus catalog boundary.

Submitting `Review` follows:

```text
HTML form
    -> localhost transport
    -> Loam.Web.Record.Request
    -> Loam.Presentation.Record.Input
    -> MovementAdmission preview
    -> human Review
```

The preview reserves no Event identity and performs no canonical publication.
A separate `Record` confirmation resubmits the original human input plus an
opaque logical operation identity. Lean rebuilds the shared draft rather than
trusting preview output, then delegates to `HouseholdCommand.recordIdempotent`.

The publisher owns writer exclusion, authoritative Actual and Locus-policy
re-read, Movement admission, identity allocation, and atomic publication. A
repeated browser Confirm with the same logical operation identity returns the
already-published Event instead of appending a duplicate. After success, the
Web command re-reads the household snapshot before rendering the result.

Current Budget consumes the same `CycleBudgetReview` boundary as the production TUI.
The Web layer does not recompute budget arithmetic. It presents the shared answers,
including:

```text
Cap
Spent
Now
Known future
After-known
```

together with shared Funding and unresolved-pressure answers.

Raw Capacity remains separately visible because it answers a different question:
all-retained Capacity entitlement. It is explicitly labelled so it cannot be mistaken
for current-cycle Budget.

The read surfaces consume shared Review boundaries such as ActualReview,
ScheduledReview, CycleBudgetReview, AttentionReview, CapacityReview, and
PurposeCatalog presentation metadata. The Record write surface does not create
a Web-specific writer; it delegates the confirmed shared draft to
`HouseholdCommand.recordIdempotent`.

## Reports

Web is a useful home for reports because long tables, multiple lenses, links,
printing, and side-by-side reading fit a document interface well. That does not mean
LOAM should add every conventional accounting report.

A report earns a place when it answers a distinct practical question from an existing
shared semantic projection. The Web renderer should present that answer rather than
creating a Web-only arithmetic or classification path.

The intended next read-only report pressure is:

```text
Stock-Flow
    -> why did the current stock become what it is?

Transactions Flow
    -> where did value come from and where did it go?

Scheduled Coverage
    -> how far are expected future occurrences explicitly covered?
```

Additional reports should remain projections over retained evidence rather than new
canonical household state.

## Authority boundary

The Web frontend owns no publisher, canonical storage, recurrence model, account
model, or independent household state. Reads and writes enter existing shared
boundaries:

```text
canonical household evidence
        |
        +--> shared Review boundaries --> Loam.Web.Snapshot --> semantic HTML
        |
        +<-- HouseholdCommand.recordIdempotent
                 ^
                 |
          explicit Confirm
```

The localhost Python process owns transport and an opaque per-form operation
token only. Tokens are high-entropy and only tokens issued by the current
localhost server are accepted for Preview or Confirm, so a cross-origin page
cannot invent a valid write request. The server retains only a bounded recent
token set; this is transport capability state, not household state. It does not
decide accounting semantics or write household files.

Missing or refused evidence remains visibly unavailable. The Web layer must not
turn missing authority into zero, empty, false, or NotDue.

Direct HTML file output is kept outside the selected household data root. Existing
filesystem aliases that resolve back into that root are refused as well, so a
presentation command cannot replace canonical or configured household evidence.

## Progressive-enhancement rule

A later Safari-rich layer may add layout, typography, responsive tables, timelines,
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

## Planned order

The second frontend is being expanded in semantic-pressure order rather than by
copying every TUI screen mechanically:

```text
request-on-read freshness
        |
        v
read-only Reports
        |
        v
shared Record input boundary
        |
        v
Web Record form + read-only Review
        |
        v
explicit Confirm + existing HouseholdCommand.recordIdempotent
        |
        v
optional Safari progressive enhancement
```

## What this experiment does not claim

This slice does not establish that:

- every TUI capability is presentation-neutral;
- every future Web write path is safe or qualified;
- the browser receives pushed updates without a request;
- the page is a general remote HTTP API;
- browser presentation is a new household authority;
- LOAM is ready for remote hosting.

Request-on-read means a reload gets a fresh answer. It is deliberately different from
browser-side polling, Server-Sent Events, or a pushed live dashboard.

## Success criterion

The experiment succeeds when lightweight and modern browsers can request the same
fresh household answers while all semantics still come from existing shared Review
boundaries and no Web-specific retained meaning is introduced.

The first existing write path is now Record. Further write surfaces should be
added only when they preserve the same explicit confirmation, shared-command,
authoritative re-read, and visible-result rules.
