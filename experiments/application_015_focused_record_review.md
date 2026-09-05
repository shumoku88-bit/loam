# Application 015: Focused record review

## Household pressure

The practical `review` entrance prints every remembered Event and Effect. Daily
recording therefore makes ordinary checking progressively harder. The observed
questions are:

- are there mistakes among the recent records?
- did I already record the thing I remember?

The h-kernel / HRA calendar interfaces supply useful pressure: dates are a human
navigation aid, not a reason to import their Home model or TUI infrastructure.

## Smallest practical shape

Use a line-oriented, read-only review with one bounded result list:

- a seven-day occurrence-date strip with current-record counts;
- a short list for that week or a selected date;
- literal, case-insensitive search over retained descriptions, locus tokens,
  measure tokens, exact quantity spellings, dates, and EventIds;
- explicit undated selection and a visible undated count;
- a selected record's full detail, with explicit correction links;
- ten results at a time, with match / displayed counts rather than silent truncation.

The date strip selects the question; it is not a stored calendar. The default
window ends on the host-local day, not the last file row or the largest EventId.
Dates mean occurrence dates, never recording timestamps. Search spans all dates,
including undated records. No match means only no match in the displayed scope,
not proof of non-recording.

No new Core fact, persistence, index, UI dependency, or writer is required.
Session selection and pagination are transient. The read-only session is loaded
on entry and explicitly reloadable; it does not promise a live or atomic
cross-file observation. Redirected input produces one bounded answer without
consuming the calling menu's next action.

## Presentation replacement boundary

Record/query selection, literal search, date movement, and their tests can be
reused by a later calendar widget or TUI. The ten-row limit belongs to rendering,
not to the query result. The current query and loading code still lives beside
the terminal adapter in `Loam/Cli/ReviewCli.lean`; this is not a finished shared
UI framework or a stable external API.

When another presentation actually earns its place, extract the required query
and evidence-loading boundary rather than parsing CLI output or duplicating
correction admission. Replace the line renderer and input loop freely. A monthly
grid, focus model, or widget toolkit has not been introduced speculatively, and
an obsolete line interface need not be retained alongside its replacement.

## Nearby semantic seams

### Movement correction

Raw EventMemory includes both original and replacement. Daily date lists and
date counts must use `correctionFrontierMemory?`, never invent a newest-wins
rule. Invalid, dangling, branching, merging, or cyclic correction evidence must
refuse the ordinary review rather than appear empty or silently fall back to raw.

Descriptions belong to EventIds. A replacement need not have its original's
description. Searching only terminal Events would make the original recognition
text disappear. Search therefore explicitly covers **all recorded Events**, with
superseded matches marked and linked to their replacement. It does not inherit a
description or claim that an original and replacement are two current movements.
The low-level raw review remains an explicitly separate inspection path.

### Date correction and missing evidence

Use the admitted Actual-validity frontier before selecting, sorting, or counting
records. A corrected date moves an Event between date windows. Missing dates are
not guessed and are always discoverable through the undated count / selection.
Equal-date order is an EventId display tie-break, not chronology or priority.

### Selection, rendering, and recovery

An on-screen number selects an EventId from that displayed snapshot, never a
freshly reordered list. Detail is read-only; no writer gains authority from a
search hit or a displayed number. Existing correction writer admission remains
unchanged. Full detail and raw inspection remain available when summaries elide
long text or additional Effects. Terminal control characters must not execute as
presentation instructions.

## Qualification

Use focused executable Lean / synthetic CLI and terminal tests for projection,
query, rendering, and composition with the existing writers. No extra formal
instrument is needed: this change introduces neither a new structural hypothesis
nor a new publication protocol. The executable expectations cover growing data,
search scope, correction and date frontiers, missing evidence, stable selection,
calendar boundaries, bounded output, and absence of persistence mutation.

Executed locally:

```text
lake build loam loamMovement loamCapacity loamDailyQuantity loamOpenScheduled
lake env lean --run Loam/Tests/RecordReview.lean
python3 tests/test_record_review.py -v
```

The pure review/calendar checks and eight synthetic CLI/PTY cases passed. Adding
300 Events still produced only ten summary rows. Writer composition included an
interrupted relation-first movement correction, refusal during the interruption,
retry, and a subsequent occurrence-date correction. Review did not mutate the
fixture streams. Long/multi-Effect summaries remained searchable in full.

Fifteen existing CI specimens for menu sessions, correction/recovery, starting
balances, basis cuts, scheduled display/completion, raw date review, and grouped
wrapper rebuilds also passed in a disposable source/build copy. This deliberately
avoided executing CI cleanup against the real sibling `loam-data` directory.
No private household data was read or changed for qualification.
