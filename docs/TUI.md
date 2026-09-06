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
