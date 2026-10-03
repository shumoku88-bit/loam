# LOAM GUI Desk v0 hypothesis

Date: 2026-10-01  
Status: **completed experiment; implementation retired 2026-10-03**

## 1. Why a GUI experiment now

The separate Desk TUI answered an important question.

A calendar + chronological Actual table + selected-detail area can be built cleanly in the terminal, but in real use it did not feel sufficiently different from LOAM's production TUI to justify a second terminal shell.

The remaining Let's家計簿-inspired ideas depend more strongly on direct manipulation:

- click a date and immediately reposition the ledger;
- click/select a row without entering a navigation mode;
- resize the relative space given to calendar, ledger, and context;
- use a real table with stable columns;
- select graph regions and drill back to contributing evidence;
- expose contextual actions next to the object they affect.

The next experiment therefore changes **interaction medium**, not household semantics.

## 2. Semantic boundary used by the experiment

At the time of this experiment, the GUI prototype used a broad surface-neutral
aggregate named `Loam.Presentation.HouseholdSnapshot`. It composed existing
Review answers so the GUI shell did not read or reinterpret canonical household
files directly.

That aggregate was experiment scaffolding, not a production authority or a
required architecture boundary. After the conventional GUI implementation was
retired on 2026-10-03, the unused aggregate and its Home projection were later
distilled from the live product surface. The surviving rule is narrower: a
renderer consumes existing typed Review answers, plus only the small
Presentation helpers that have a current production caller.

## 3. Shell choice

For the first LOAM GUI experiment, **Tauri is a replaceable shell candidate**, not a semantic commitment.

Target shape:

```text
LOAM Lean
  Core / Authority / Application / Review / Presentation
                         |
                         v
              tiny read-only adapter
                         |
                         v
                  Tauri shell
                 Rust kept thin
                         |
                         v
                 HTML / CSS / TS
```

Rust/TypeScript may own:

- window lifecycle;
- pointer events;
- local selection state;
- pane geometry;
- table rendering;
- graph rendering;
- presentation-only formatting.

They must not own:

- accounting arithmetic;
- Movement meaning;
- correction rules;
- Scheduled authority;
- balance derivation;
- provenance relations;
- write admission.

If another GUI toolkit later proves better, the shell should be replaceable without changing household meaning.

## 4. First transport boundary

Do not create a broad GUI API in advance.

The first implementation should expose only the read data needed for one screen.

Candidate first payload:

```text
observed_at
visible_month
Actual rows:
  event identity
  current date
  description
  effects:
    locus
    measure
    exact quanta
replacement/current status where needed
```

The adapter should be a serialization of existing Review / Presentation answers, not a second query implementation.

JSON is a practical candidate for a Tauri shell, but the transport format is disposable. The durable boundary is the existing typed LOAM read answer.

## 5. v0 screen

The first GUI should deliberately be smaller than either LOAM's full TUI or Let's家計簿.

```text
+-------------------------------------------------------------+
| October 2026                                                |
+------------------+------------------------------------------+
| Calendar         | Actual                                   |
|                  |                                          |
|  Mo Tu We ...    | date | movement/effects | description   |
|                  |                                          |
|  click date      | click row                                |
+------------------+------------------------------------------+
| Selected                                                     |
| identity / effects / evidence                               |
+-------------------------------------------------------------+
```

Required interaction:

1. click a calendar date;
2. ledger follows that date/month;
3. click an Actual row;
4. selected detail updates immediately;
5. resize the window without losing the table;
6. navigate month backward/forward;
7. expose one explicit route from selected row to evidence/provenance detail.

Keyboard navigation may remain as a parallel path, but it is not the experiment's point.

## 6. Explicit non-goals

v0 does not include:

- recording;
- correction;
- Scheduled editing;
- budget editing;
- generic dashboard cards;
- a large component framework;
- every current LOAM report;
- old Windows visual imitation;
- a stable public API;
- synchronization/cloud features.

The goal is to test whether a GUI creates a **materially better household desk**, not to build a second full LOAM client immediately.

## 7. Acceptance test

Keep the GUI experiment only if it produces a clearly different experience from the production TUI.

The v0 should make these actions feel spatial and direct:

- "show me this day";
- "show me this row";
- "what created this movement/effect?";
- "move through the month without losing where I am";
- "give the ledger more/less room by resizing the window."

A successful result should not need the explanation "it is basically the TUI, but in a window."

## 8. Kill criteria

Stop or radically simplify if:

- the GUI requires duplicated accounting/business logic;
- it reads canonical files directly;
- Rust/TypeScript starts recreating Review calculations;
- the transport grows into a second household schema before the first screen proves useful;
- the GUI needs a large framework before basic calendar/table selection feels better than the TUI;
- maintenance cost appears before a distinct interaction benefit.

## 9. Relationship to the retired Desk TUI

The retired implementation remains useful as a completed experiment in Git history.

What survives from it:

- Actual-centered topology;
- read-only first step;
- calendar/date coupling;
- selected-row context;
- explicit evidence route;
- separate-shell architecture.

What does not survive:

- a second terminal executable;
- terminal-specific pane/layout code;
- terminal key grammar as the primary interaction model.

The next experiment should reuse the **question**, not the old renderer.


## 10. Experiment outcome

The conventional read-only Tauri workbench was implemented and qualified, but it
remained too close to an ordinary household desktop application to justify a
second daily surface beside the production TUI.

Its code and dedicated CI were therefore retired on 2026-10-03. The experiment
survives in this document and Git history.

What survives into the next GUI direction:

- read-only presentation over surface-neutral LOAM answers;
- no accounting or household authority in the renderer;
- direct navigation from aggregate observation to contributing evidence;
- a replaceable shell.

What does not survive:

- calendar + ledger + inspector as the primary GUI topology;
- duplicating ordinary TUI workflows in a window;
- a GUI whose main advantage is conventional pointer interaction.

The next experiment is [LOAM Observatory v0](../LOAM_OBSERVATORY_V0_HYPOTHESIS.md):
a GPU-first spatial instrument whose first surface is the pension-cycle Orbit and
whose second surface is evidence X-Ray.
