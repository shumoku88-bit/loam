# LOAM TUI

`loamTui` is the production terminal frontend for LOAM.

The TUI is presentation and interaction state, not a second household authority.
It consumes the same admitted read and write boundaries used by other LOAM
frontends.

Current production direction:

```text
Loam/Tui/Kernel     small Widget / Screen meaning and reconstruction laws
Loam/Tui/Runtime    compiled sparse-row redraw representation
Loam/Tui/Terminal   raw terminal mechanics only
Loam/Tui/Calendar   presentation-only Gregorian month projection
Loam/Tui/Main       Home / Actual / Scheduled interaction state
Loam/Tui/Cli        canonical snapshot loading and executable loop
```

One selected day drives Home evidence, Actual review, Scheduled review, and the
future Record date seed. Actual and Scheduled remain separate semantic families.
Missing explicit Scheduled evidence remains `Unknown`; the UI must not strengthen
it into `NotDue` without completeness evidence.

## Production rule

Historical `Loam/Prototype/*` code and numbered prototype executables are research
provenance. Production TUI code must not import them. Useful mechanics are promoted
into `Loam/Tui/*` only when they have earned a stable production role.

The production executable is:

```sh
lake build loamTui
./.lake/build/bin/loamTui
```

`LOAM_DATA_DIR` may select the household data directory; otherwise the executable
uses `../loam-data`. Movement reads use selected manifest authority and fail closed.

## Write boundary

Record editing is not considered complete until an already-collected typed
`MovementAdmission.Draft` can be published through the same writer-ownership,
current-world re-read, admission, and manifest publication path used by the line
Movement entrance. The TUI must not duplicate that publisher or create its own
canonical write path.


## Record publication

Home `r` opens the production Record editor on the selected day. Tab and
Shift-Tab move through date, description, FROM/TO locus and integer JPY amount
fields, and Add FROM / Add TO / Drop last row / Preview / Cancel actions.
Right accepts a prefix candidate into the active locus field. Backspace edits;
Escape cancels. The current 80×24 editor supports six effect rows; dropping the
last row retains at least one row on each side. Preview shows every effect and
allows Publish, Edit, or Cancel. No transaction kind is retained.

`Loam.MovementPublisher` is the non-CLI publication entrance for collected
`MovementAdmission.Draft` values. Both line CLI and TUI use it. It acquires the
existing WriterOwnership lock, rereads the current selected manifest world,
runs production `MovementAdmission.admit?`, then publishes that world. It does
not read human input or print terminal output. The sidecar fixture path retains
its existing support-before-Event ordering inside the same shared module.

Draft balance, positive totals, JPY measure, valid effect tokens and occurrence
date are validated at the shared admission entrance. These are practical
Movement conditions, not new restrictions on neutral Core Events. Locus
suggestions remain read evidence; the current production vocabulary decides
publication, including when it changes after preview.

Successful publication discards the editor and cached Actual cursor, reloads
canonical review evidence and returns Home on the same selected date. A failure
after a successful publication, including reload failure, exits rather than
presenting the same Publish intent again. Exceptions also unwind the terminal
boundary. A normal admission refusal retains the editable form.

Qualification: `Loam/Tests/TuiRecord.lean` exercises invalid drafts, cancellation,
candidate isolation, Edit preservation, stale Locus policy refusal without
CURRENT mutation, canonical publication and fresh shared Actual review. The
retained Screen and sparse-row reconstruction laws apply to Record widgets too.
Terminal glyph width, ANSI, OS locking and IO remain outside those Lean proofs.
Real household migration to an explicit Locus vocabulary is a separate step;
these regression fixtures do not authorize or mutate household data.
