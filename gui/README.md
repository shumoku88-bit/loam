# LOAM GUI v0

Status: read-only interaction experiment.

This is deliberately a very small Tauri 2 shell around LOAM's existing read boundary.
It does not read `actual.loam` itself and does not contain accounting or correction logic.

## Shape

```text
actual.loam
   |
ActualAuthority / ActualReview
   |
loam explain actual --machine --month YYYY-MM
   |
thin Tauri command
   |
calendar + monthly Actual workbench + selected evidence
```

The Rust side only starts the normal `loam` binary and validates/parses the bounded
`ACTUAL1` transport. The web side owns pointer selection, presentation filtering,
pane geometry, and rendering.

## Run on macOS

Install Rust/Tauri prerequisites once, then from the repository:

```sh
cargo install tauri-cli --version "^2.0.0" --locked   # first time only
./gui/dev
```

`gui/dev` builds the ordinary LOAM binary first, then starts Tauri.

The GUI uses the same default household root as LOAM. A different path is available
behind the `Data` disclosure and is remembered locally by the GUI.

Optional development overrides:

```text
LOAM_GUI_REPO_ROOT=/path/to/loam
LOAM_GUI_LOAM_BIN=/path/to/loam
```

## Current read-only interaction

- click a calendar date and keep temporal orientation;
- click a monthly Actual row and inspect exact Effects;
- switch between the whole month and the selected day;
- presentation-only search across description, identities, loci, measures, and quanta;
- drag the vertical separator to resize calendar vs ledger;
- move month backward/forward;
- resize the native window;
- remember the calendar width, data path, and month/day view preference locally.

Search and scope switches never change household evidence. They only filter the
already-loaded monthly read answer in the webview.

No write action exists yet.

## Boundary

Do not add accounting arithmetic to Rust or JavaScript.

If a new GUI observation is needed, first ask whether an existing Review /
Presentation answer already owns it. Any machine transport remains replaceable
presentation plumbing, not a second household schema.
