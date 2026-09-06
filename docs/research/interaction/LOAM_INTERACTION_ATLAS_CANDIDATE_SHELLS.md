# LOAM Interaction Atlas — Candidate Shell Scorecard

Date: 2026-09-06  
Status: **paper/state-machine comparison only; no TUI selected**  
Parent: `LOAM_INTERACTION_ATLAS.md`  
Companions:

- `LOAM_INTERACTION_ATLAS_INTERACTION_TRACES.md`
- `LOAM_INTERACTION_ATLAS_SCORECARD.md`

---

## 0. Question

Given the first structural finding that HRA's interaction graph was unusually flat, what shell topology should LOAM test before implementing a production TUI?

This comparison holds the **semantic publisher constant** in imagination:

```text
surface draft
  -> LOAM semantic proposal/admission
  -> WriterOwnership / fresh re-read where required
  -> existing qualified publication protocol
  -> fresh observation
```

The candidates therefore differ only in how a human reaches the same semantic action.

---

# 1. Candidate A — HRA-derived flat shell

Core idea:

- one always-visible selected day,
- direct mnemonic actions for a small stable daily vocabulary,
- selectable objects,
- object-local actions,
- no mandatory section-focus mode.

Paper topology:

```text
Home(selected day)
  r  Record
  a  Actual
  s  Scheduled
  c  Capacity
  v  Views
  /  Search / command palette fallback
```

Mouse/touch can activate the same objects/actions without creating separate semantics.

Important: direct mnemonic actions are an acceleration layer, not hidden commands. The footer/help exposes them continuously.

## Six scenario traces

### A-S01 ordinary purchase

```text
Home(today) -> r -> draft seeded with today -> preview -> publish -> Home(today)
```

UI Tax estimate: **0**

### A-S02 past purchase

```text
Home -> move/select past day -> r -> draft seeded with selected day -> publish -> same day
```

UI Tax estimate: **0**

### A-S03 correct Actual

```text
Home -> a -> select Actual -> c Correct -> seeded correction draft -> publish -> Actual view
```

UI Tax estimate: **0**

### A-S04 complete Scheduled

```text
Home -> s -> select Scheduled -> r Record actual -> editable defaults -> publish -> Scheduled list
```

UI Tax estimate: **0**

### A-S05 replace Scheduled

```text
Home -> s -> select Scheduled -> e Edit/reschedule -> editable defaults -> publish -> replacement selected
```

UI Tax estimate: **0**

### A-S06 move Capacity

```text
Home -> c -> select From/To from visible capacity state -> amount -> Current/After preview -> publish -> Capacity
```

UI Tax estimate: **0**

### Candidate A risk

A zero paper UI Tax is not a proof of superiority. The cost may move into:

- learning mnemonic letters,
- overcrowded Home help,
- object-local action discovery,
- too-general data-entry forms.

The dogfood must measure those separately.

---

# 2. Candidate B — h-kernel-derived generalized focus shell

Core idea:

```text
Calendar region
  <-> Section region
  <-> Surface region
```

Within complex surfaces there may also be local pane focus.

Strengths:

- explicit scalable navigation model,
- mouse/pointer fits naturally,
- active region is visually honest,
- sections can grow without adding more global mnemonic keys,
- rich workspaces are easy to host.

## Six scenario UI Tax estimate

Use the already-observed h-kernel structural baseline:

| Scenario | Tax |
|---|---:|
| ordinary purchase via Home `r` | 0 |
| past purchase via calendar + `r` | 0 |
| correct Actual from Home | 3 |
| complete Scheduled | 2 |
| replace Scheduled | 2 |
| move Capacity | 2 |
| **mean** | **1.5** |

### Candidate B risk

The generalized focus layer creates work unrelated to household semantics, especially for repeated keyboard use.

### Candidate B counter-hypothesis

The extra focus layer may still win if:

- pointer use is common,
- the number of domains grows,
- users frequently browse rather than execute known actions,
- continuous visible focus reduces mistakes enough to offset navigation cost.

---

# 3. Candidate C — intent / command-palette shell

Core idea:

A universal palette is reachable from anywhere:

```text
/
  Record movement
  Complete scheduled item
  Replace scheduled item
  Correct actual
  Move capacity
  Compare balance
  Search history
  ...
```

After choosing intent, the UI asks only for missing target/context.

The palette can fuzzy-search human words and expose shortcuts once learned.

This is particularly relevant to:

- CLI users,
- infrequent operations,
- a ChatGPT/intent adapter,
- avoiding a deep permanent section hierarchy.

## Assumption for fair comparison

Candidate C still has an always-visible selected day on Home. The palette replaces domain-navigation mnemonics, not temporal orientation.

Opening the palette counts as one presentation transition (`PF +1`). Choosing the desired semantic action is not counted again as presentation tax because that is the action choice itself.

## Six scenario traces

### C-S01 ordinary purchase

```text
Home(today) -> / -> Record movement -> draft(today) -> publish -> Home(today)
```

UI Tax estimate: **1**

A dedicated learned shortcut could later reduce this to 0, but the palette baseline remains 1.

### C-S02 past purchase

```text
select past day -> / -> Record movement -> draft(selected day) -> publish -> same day
```

UI Tax estimate: **1**

### C-S03 correct Actual

Two useful paths:

```text
select Actual -> / -> Correct selected Actual
```

or

```text
/ -> Correct Actual -> recognition-first target picker
```

UI Tax estimate: **1**

### C-S04 complete Scheduled

```text
/ -> Complete scheduled -> selectable open Scheduled list -> publish -> same domain context
```

UI Tax estimate: **1**

No internal Scheduled ID recall.

### C-S05 replace Scheduled

```text
/ -> Replace scheduled -> select visible target -> editable defaults -> publish
```

UI Tax estimate: **1**

### C-S06 move Capacity

```text
/ -> Move capacity -> visible endpoint picker -> Current/After preview -> publish
```

UI Tax estimate: **1**

### Candidate C structural result

| Scenario | Tax |
|---|---:|
| S01 | 1 |
| S02 | 1 |
| S03 | 1 |
| S04 | 1 |
| S05 | 1 |
| S06 | 1 |
| **mean** | **1.0** |

### Candidate C risk

The palette can become a junk drawer if it exposes implementation nouns instead of human goals.

It must say things such as:

- `Record what happened`
- `Change a scheduled payment`
- `Move spending capacity`

rather than forcing recall of internal Core type names.

---

# 4. Candidate D — hybrid flat shell + palette

This candidate emerges naturally from A and C.

Core idea:

- HRA-style stable selected day,
- direct shortcuts only for genuinely frequent operations,
- command palette for everything else,
- object-local actions when an object is already selected,
- no mandatory Section/Surface focus cycle.

Paper Home:

```text
┌───────────────────────────────────────────────────────────┐
│ September 2026                    observed through Sep 6  │
│                                                           │
│ Mo Tu We Th Fr Sa Su                                      │
│     1  2  3  4  5 [6]                                    │
│  7  8  9 10$ 11 12 13                                    │
│                                                           │
│ Sep 6                                                     │
│ Actual                                                     │
│   coffee       PayPay -> coffee        138 JPY            │
│ Upcoming                                                   │
│   Sep 10       bank -> rent         50,000 JPY            │
│ Attention                                                  │
│   none                                                      │
│                                                           │
│ r Record   s Scheduled   / More actions   q Quit           │
└───────────────────────────────────────────────────────────┘
```

Only `r` and perhaps `s` earn permanent Home keys initially. Less frequent actions live behind `/` or local object actions.

This avoids spending a global mnemonic on every domain.

---

# 5. Candidate D expected traces

## Frequent direct path

Ordinary/past purchase:

- PF 0,
- recall 0,
- context displacement 0.

Expected UI Tax: **0**.

## Object-local path

When an Actual or Scheduled object is already selected:

- correction/completion/replacement use local actions,
- no internal identity recall,
- no palette required for the common action displayed beside the selected object.

Expected UI Tax: **0** for the common local operations.

## Infrequent action

Capacity/reconcile/settings/report actions can begin with `/`:

Expected UI Tax: **1** unless promoted by actual frequency data.

### Illustrative six-scenario estimate

| Scenario | Hybrid tax |
|---|---:|
| ordinary purchase | 0 |
| past purchase | 0 |
| correct selected Actual | 0 |
| complete selected Scheduled | 0 |
| replace selected Scheduled | 0 |
| move Capacity via palette | 1 |
| **mean** | **0.17** |

This is a **paper prediction**, not evidence.

---

# 6. Cross-candidate structural table

For the six initial scenarios:

| Shell | Mean paper/observed UI Tax | Evidence kind |
|---|---:|---|
| HRA observed predecessor | 0.0 | code-derived historical structure |
| current LOAM CLI | 3.3 | code-derived current structure |
| h-kernel focus shell | 1.5 | code-derived historical structure |
| command palette candidate | 1.0 | synthetic paper trace |
| flat + palette hybrid | 0.17 | synthetic paper trace |

Do **not** rank these as usability scores. Synthetic candidates have not earned equality with used systems.

The table exists to decide what to test, not what to ship.

---

# 7. What the comparison suggests

The strongest candidate is not a literal restoration of HRA.

It is a **hybrid interaction law**:

1. keep time orientation persistent,
2. make visible objects selectable,
3. put actions next to the selected object,
4. give only very frequent actions direct shortcuts,
5. use a searchable palette for the long tail,
6. keep advanced explanation inside the action flow rather than the outer shell,
7. return fresh canonical observation to the same human place.

This combines:

- HRA's low orientation tax,
- h-kernel's richer widgets/mouse/responsive lessons,
- command palette discoverability,
- current LOAM's strict publishers.

---

# 8. Human-factors prediction

## Why the hybrid may work

It supports both recognition and expert acceleration.

Cold/rare operation:

```text
/ -> type `refund` / `replace` / `compare` -> choose action
```

Learned daily operation:

```text
r
```

Object already visible:

```text
select row -> e
```

No user has to memorize the complete command vocabulary before the system becomes useful.

## Why it may fail

- `/` may be undiscoverable without a visible `More actions` label,
- local action letters may conflict between surfaces,
- a calendar Home may be too large on narrow terminals,
- selected-day defaults may cause unnoticed wrong-date actions,
- a flat shell may become crowded as capabilities grow.

Each failure mode is directly dogfoodable.

---

# 9. Mobile / GUI / ChatGPT implication

The hybrid topology should not be copied visually to other surfaces.

Instead preserve the interaction laws:

## Mobile

- selected/current date visible,
- large quick-record action,
- tap visible object -> local actions,
- searchable `More` sheet for rare operations.

## GUI/Web

- calendar/timeline can remain an orientation surface,
- direct object-local menus/actions,
- command palette optional for keyboard experts.

## ChatGPT

The conversation itself functions like the intent palette:

```text
user language
  -> candidate application action
  -> structured object/target picker if ambiguous
  -> semantic preview
  -> explicit approval
  -> same LOAM publisher
```

This means a good Application Action vocabulary can benefit every surface without forcing one visual navigation system everywhere.

---

# 10. First prototype boundary

If later dogfood earns an implementation experiment, the first TUI prototype should be deliberately tiny:

- calendar / selected day,
- current-day detail pane,
- `r` Record movement,
- selectable Scheduled list,
- local `r/e/x` Scheduled actions,
- `/` action palette,
- fresh-return-to-place after publication.

Do not initially add:

- a seven-section focus rail,
- full Reports workspace,
- settings framework,
- generic plugin/action architecture,
- persisted UI state,
- universal widget abstraction,
- new accounting semantics.

The point of the prototype would be to falsify the **interaction topology**, not to build the final TUI.

---

# 11. Decision status

No shell is selected.

Current research status:

- HRA flatness hypothesis: **SURVIVED structural check**
- h-kernel generalized focus shell: **valuable comparison, not rejected**
- command palette: **paper candidate**
- flat + palette hybrid: **highest-priority synthetic dogfood candidate**
- production TUI implementation: **NOT YET EARNED**

Next evidence should come from scenario dogfood and user preference, not more architectural speculation alone.
