# HRA interaction atlas for LOAM

Status: research pressure, not a production UI specification.

Comparator revision:

```text
shumoku88-bit/hra
75cc6b04c38dff47cb6373f5d2ca38038ba7c9bf
```

LOAM pressure point when this atlas was written:

```text
Prototype 07
938737f548df312b17dd1b5e49bd506ec7466441
Calendar -> selected-day canonical Actual list -> detail
```

## Question

HRA was unusually pleasant and fast in real household use. LOAM should not copy its
canonical model, but it should treat the interaction that survived dogfood as strong
evidence.

The question is therefore not:

> How do we port the HRA TUI?

It is:

> Which HRA interaction decisions still earn their place when rebuilt over LOAM's
> current evidence boundaries, and which can be deleted or compressed?

Classification used below:

- **KEEP**: preserve the interaction shape unless later dogfood falsifies it.
- **REDESIGN**: preserve the household question or navigation role, but bind it to
  current LOAM semantics rather than HRA state or lifecycle vocabulary.
- **DROP**: do not carry it into the current LOAM surface set without fresh pressure.

## Evidence from HRA

### 1. Home is a temporal root, not a menu

`src/hra-household_home_interaction.ads` separates two coordinates:

```text
Known_Through  fixed visibility horizon
Selected_Day   mutable focus coordinate
```

Navigation changes only `Selected_Day`; it never changes the visibility horizon.
The pure interaction package has day/week movement, direct day selection, and a
return-to-known-through operation. Boundary movement fails closed.

This separation is important. The user can ask "what was visible through this
horizon?" and independently move the visual focus to another day, including a
future day.

### 2. Home combines calendar orientation with selected-day evidence

`src/hra-household_home_presentation.ads` presents one UI-neutral Home model with:

- monthly calendar cells;
- selected-day Actual;
- selected-day Plan;
- selected-day Issue;
- cycle position;
- attention markers for scheduled Plan, due Issue, and cycle end.

Terminal formatting is explicitly outside that presentation type. The calendar is
therefore not merely decoration around a command launcher. It is the spatial index
for household evidence.

### 3. Home opens semantic-family workspaces directly

`src/hra-household_home_tui_input.ads` / `.adb` map Home input to:

```text
record Actual
a  Actual workspace
p  Plan workspace
i  Issue workspace
e  Entitlement workspace
v  Report workspace
q  quit
```

Arrow keys and h/j/k/l move the calendar focus. `g` returns focus to the visible
horizon.

The outer Home loop in `src/hra-household_home_tui.adb` delegates to those
workspaces and redraws Home when they return.

### 4. Workspaces select objects and actions without becoming mutation authority

This is one of the strongest reusable decisions.

`src/hra-household_actual_workspace_tui.ads` says the Actual workspace selects an
Actual object and coordinates reversal, new-record, and filtering while publication
authority remains at the existing Household application boundaries.

`src/hra-household_plan_workspace_tui.ads` and
`src/hra-household_issue_workspace_tui.ads` similarly return typed action results to
Home. They do not own the mutation authority they request.

This shape is compatible with LOAM's rule that presentation must not become a
second accounting authority.

### 5. Object detail can remain local to a workspace

The HRA Actual workspace input has previous/next row movement and left/right focus
movement inside the workspace. Its outer result is only `Back_To_Home` or
`Record_New_Actual`; there is no independent top-level "Actual detail application"
returned to Home.

This pressures Prototype 07's `ActualList` / `ActualDetail` split. The detail view
may deserve to survive visually while ceasing to be a top-level application
surface. It can instead be a local mode of one Actual workspace.

This is a candidate simplification, not yet a production decision.

### 6. Report sections are local modes of one Report workspace

`src/hra-household_report_workspace_tui_input.ads` supports line/page/horizontal
scroll, previous/next section, and choose-section inside one workspace.

`src/hra-household_report_workspace_tui.ads` keeps reports observation-driven and
builds one selected report section into semantic presentation. This is useful
interaction evidence even though the actual HRA report vocabulary must not be
copied into LOAM automatically.

HRA also allowed one routing/classification mutation from the report workspace.
That coupling is *not* inherited by this atlas; it needs separate LOAM pressure.

## First classification

| HRA interaction | Decision | LOAM interpretation |
| --- | --- | --- |
| Home as persistent root | KEEP | One stable place to regain orientation. |
| Monthly calendar as Home's spatial index | KEEP | Time is selected spatially rather than repeatedly typed. |
| Visibility horizon separate from focus day | KEEP | Preserve the distinction; exact LOAM naming may differ. |
| Selected-day evidence directly under calendar | KEEP | Home should answer "what is here?" before opening a workspace. |
| Attention markers on calendar | REDESIGN | Keep as projections only; providers must be LOAM Actual/Scheduled/Issue/Cycle evidence. |
| Direct entry from Home to semantic-family workspace | KEEP | Prefer shallow navigation over a generic router. |
| Workspace returns typed object/action intent | KEEP | UI selects; application boundary admits or rejects. |
| Actual workspace list + detail/focus | KEEP | Keep one Actual workspace; detail is a local mode candidate. |
| HRA Plan workspace | REDESIGN | Rebind to current LOAM Scheduled semantics. Do not import HRA Plan lifecycle by analogy. |
| HRA Issue workspace | REDESIGN | Rebind only to Issue semantics already qualified in LOAM. |
| Report workspace with local section navigation | KEEP | One report workspace can contain many projection sections. |
| HRA report contents | REDESIGN | Every section must earn itself from LOAM evidence and dogfood. |
| Mutation from inside a report | DROP for now | A report is a projection; do not add writer authority without new evidence. |
| Entitlement workspace | DROP for now | No current LOAM interaction goal in this study requires a dedicated entitlement surface. |
| Separate top-level Actual Detail surface | DROP candidate | Retain detail visually, test it as a local Actual workspace mode. |
| Generic command palette / router | DROP candidate | HRA already reaches the active families directly; do not add an extra navigation surface without pressure. |
| Generic scrolling framework | DROP for now | Add scrolling mechanics only when a real workspace needs them. |

## Candidate LOAM interaction skeleton

The smallest HRA-derived skeleton currently worth pressure-testing is:

```text
Home / Calendar
  |
  +-- Actual workspace
  |     browse <-> detail/local focus
  |     record/reversal requests -> LOAM application boundary
  |
  +-- Scheduled workspace
  |     browse <-> local actions
  |
  +-- Issue workspace
  |     browse <-> local actions
  |
  +-- Report workspace
        section <-> section
        scroll within section
```

Home itself owns only presentation orientation:

```text
visibility horizon
focus day
last local workspace orientation, when useful
```

None of those presentation coordinates become canonical household evidence.

## Formal pressure

`Loam/Prototype/Interaction08/Minimality.als` asks a deliberately narrow structural
question. The required goals in the bounded model are:

```text
select a day
review Actual
inspect Actual detail
record Actual
review Scheduled
review Issues
view Reports
```

Two Actual shapes are compared:

```text
A. one Actual workspace containing browse + detail as local modes
B. separate Actual list and Actual detail top-level surfaces
```

The model also includes two additive surfaces with no required goal in this study:

```text
Palette
Entitlement
```

Expected bounded result:

- the one-workspace Actual shape satisfies all current goals with five top-level
  surfaces total: Home, Actual, Scheduled, Issue, Report;
- the split Actual shape also satisfies the goals, but needs six surfaces;
- no sufficient configuration with four or fewer surfaces exists under the stated
  goal mapping;
- any sufficient five-surface configuration is exactly the one-workspace core, so
  Palette and Entitlement cannot enter the minimal set without displacing a surface
  that provides a required goal.

This does **not** prove that five screens are globally optimal, that the named
semantic families are permanent, or that fewer key presses always feel better. It
only answers the bounded structural question encoded above.

## Tool boundary

Use Alloy here because the question is structural sufficiency and removable graph
nodes.

Do not duplicate Prototype 07's orientation laws in Alloy. Lean already has the
better job there: bounded selected row, day preservation across Enter/Back, exact
cursor preservation, and semantic-screen equality for the sparse renderer.

The desired division is:

```text
Alloy  -> can this interaction graph be smaller without losing current goals?
Lean   -> once a shape survives, which orientation/rendering laws deserve permanence?
human  -> is the resulting tool actually pleasant to use?
```

## Next experiment if this atlas survives review

Do not implement Scheduled, Issue, and Reports all at once.

First reshape Prototype 07 into one HRA-style Actual workspace where browse/detail
are local modes under a Home calendar root. Human-dogfood that shape. If it remains
clearer and equally responsive, then add one second semantic-family workspace
(Scheduled is the strongest next candidate) and see whether the same Home/workspace
composition survives without a generic router.

Only after multiple real workspaces require the same mechanism should that
mechanism be promoted into the verified TUI kernel.