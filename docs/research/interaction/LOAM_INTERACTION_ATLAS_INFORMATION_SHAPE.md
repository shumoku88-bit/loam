# LOAM Interaction Atlas — Information Shape, Learning, and Long-Term Familiarity

Date: 2026-09-06  
Status: **cross-domain HCI research; not a UI selection**  
Parent: `LOAM_INTERACTION_ATLAS.md`

---

## 0. Question

A household system is not used only to complete isolated commands. It becomes a place the person returns to repeatedly.

This shard asks:

> How should information be arranged so that the interface becomes easier to inhabit over time without hiding important meaning or forcing the person to memorize the software?

The focus is broader than household finance:

- visual hierarchy,
- spatial memory,
- navigation vs search,
- tables vs charts,
- empty states,
- errors,
- defaults,
- customization and personalization,
- interface change and learning,
- autonomy and avoidance.

The goal is to derive evaluation criteria, not visual styling rules.

---

# 1. Visual hierarchy is an attention policy

Visual hierarchy is not decoration. It determines what the eye encounters first and what recedes.

Common mechanisms include:

- scale,
- contrast,
- spacing,
- placement,
- proximity,
- common regions.

A dense screen can still be usable if importance is obvious. A sparse screen can still be confusing if everything has equal visual weight.

### LOAM consequence

Visual prominence should reflect **decision importance**, not merely data size or implementation hierarchy.

Candidate ordering on a Home surface:

1. blocking or safety-critical state,
2. action that actually needs attention,
3. current orientation / selected time,
4. ordinary current facts,
5. explanatory metadata,
6. implementation identity / provenance details.

Do not make every canonical fact equally loud merely because all are semantically precise.

### Candidate law IS-01 — prominence must be earned

> Visual weight is a scarce resource. Give it to what changes the next human decision.

This strengthens the existing "attention is scarce" principle.

Sources:
- Nielsen Norman Group, Visual Hierarchy / visual design principles.
- Apple Human Interface Guidelines, hierarchy.

---

# 2. Spatial memory makes stable layouts faster over time

Repeated users develop rough memory of where controls and content live.

Important observations from spatial-memory research:

- visual search is effortful,
- stable placement allows repeated users to locate things faster,
- broad/shallow hierarchies often support spatial memory better than narrow/deep hierarchies,
- spatial memory is imprecise and still benefits from textual/visual landmarks,
- overviews can help people maintain a sense of the larger information space.

### LOAM consequence

A UI that continuously reorders itself to be "smart" may destroy learned orientation.

Examples of risky adaptation:

- moving actions based on recent use,
- reordering Home sections daily,
- hiding sections that currently have no data,
- moving a warning into a different region when severity changes,
- changing shortcut letters as the feature set grows.

### Candidate law IS-02 — stable place before adaptive cleverness

> Prefer stable landmarks over automatic rearrangement unless adaptation has a demonstrated benefit large enough to repay the spatial-memory cost.

### HRA connection

The user's preference for HRA may partly reflect this property:

- stable calendar location,
- stable selected-day context,
- stable mnemonic paths,
- stable return location.

That is a different hypothesis from "HRA had fewer keystrokes".

### Synthetic metric

Record after one week of simulated repeated use:

- number of visual-search pauses,
- number of wrong-region moves,
- help lookups,
- time to locate a rarely used action,
- whether the user can point to the approximate region before reading labels.

Source:
- Nielsen Norman Group, Spatial Memory: Why It Matters for UX Design.

---

# 3. Navigation and search solve different problems

Navigation is recognition-oriented:

> "I see a place that looks like where this belongs."

Search/palette is intent-oriented:

> "I know roughly what I want to do; find the command for me."

Information-scent research emphasizes that people choose paths based on labels, surrounding context, and prior experience.

### LOAM consequence

Do not force one mechanism to serve everything.

A strong candidate remains:

- stable visible Home/calendar for orientation,
- selectable visible objects for local actions,
- direct shortcuts for very frequent actions,
- command palette/search for long-tail actions,
- explicit CLI for precise/scriptable use.

### Candidate law IS-03 — recognition for place, search for intent

> Let people navigate when they know where something is and search when they know what they want.

### Naming consequence

A palette label such as `Replace Scheduled` may be semantically exact but human-poor.

Search aliases may need human wording such as:

- change a future payment,
- move a scheduled payment,
- reschedule,
- change date,
- replace scheduled item.

The executed action can still be one exact LOAM application action.

Source:
- Nielsen Norman Group, Information Scent.

---

# 4. Tables and charts answer different questions

Charts are strong when the task is to:

- see trends,
- compare magnitudes,
- spot outliers/clusters,
- understand change over time,
- communicate a small number of important relationships.

Tables/lists are strong when the task is to:

- inspect exact values,
- search,
- sort,
- select objects,
- compare multiple attributes precisely,
- act on individual records.

Apple's chart guidance explicitly notes that not every dataset should be charted; if the goal is simply to provide or manipulate data, a searchable/sortable list or table may be better.

### LOAM consequence

Do not turn reports into graphs merely because GUI permits graphs.

Candidate pairing:

```text
Trend / pattern question
    -> chart

Exact / provenance / action question
    -> table/list

Need both
    -> chart as overview + linked exact table/detail
```

### Example

For cycle spending:

- chart: shape of spending through the cycle,
- table: exact movements by day/purpose,
- detail: provenance explaining a selected value.

### Candidate law IS-04 — chart for shape, table for exactness

> Use graphical compression for patterns and row/column structure for exact inspection and action.

### Accessibility consequence

A chart must never be the only representation of important financial state.

Sources:
- Apple HIG, Charting data / Charts.
- Apple HIG, Lists and tables.

---

# 5. Empty is a state, not an absence of design

Empty screens are often temporary states with real meaning.

Examples in LOAM:

- no open Scheduled items,
- no Actual on selected day,
- no attention requiring action,
- no search results,
- no Capacity assigned to a purpose,
- data unavailable beyond observation horizon.

These are not equivalent.

### Candidate empty-state vocabulary

| State | Example wording direction |
|---|---|
| genuinely none | `No open scheduled items.` |
| none for selected coordinate | `No Actual recorded for Sep 6.` |
| not yet observed | `Actual after Sep 6 is not yet observable.` |
| failed/unavailable | `Could not determine open Scheduled state.` |
| filtered to none | `No results match this filter.` |
| not configured | `No external account observation has been added.` |

### Candidate law IS-05 — empty must preserve epistemic meaning

> Never let blank space collapse none, unknown, unavailable, filtered-out, and not-yet-observed into the same experience.

Where an empty state implies a natural next action, present it. Where "nothing to do" is healthy, let the state remain quiet.

Source:
- Apple HIG writing guidance on empty states.

---

# 6. Error messages are part of recovery, not diagnostics for developers

Strong error guidance converges on several points:

- prevent errors where possible,
- keep previously entered information,
- identify the specific problem,
- explain how to fix it,
- put the explanation near the relevant place,
- avoid generic messages,
- avoid blame and unnecessary jargon.

### LOAM consequence

Bad:

```text
Admission failed: invalid frontier
```

Better human layer:

```text
This scheduled payment changed while you were editing it.
Nothing was recorded.

Current item:
Sep 12  bank -> rent  ¥50,000

[Review current item]
```

The detailed technical reason can remain reachable:

```text
Details: stale completion draft; source no longer open
```

### Candidate law IS-06 — errors need two layers

> First explain the human situation and next safe action; keep exact technical/provenance detail available without forcing it into the primary message.

### Fail-closed consequence

Fail-closed behavior should be visible as a **recoverable state**, not a terminal wall of technical text.

Sources:
- GOV.UK Design System error-message guidance.
- GOV.UK validation recovery guidance.
- Nielsen Norman Group usability heuristic 9.

---

# 7. Defaults are powerful because people often keep them

Defaults reduce setup and repetitive entry, but their influence means they must be chosen carefully.

Strong general guidance:

- provide defaults that work for most people,
- do not require configuration before useful work,
- avoid a giant settings surface,
- keep task-specific controls near the task,
- respect broader system preferences when possible.

### LOAM consequence

A useful distinction:

## Safe convenience default

Example:

```text
Actual date [selected Home day]
```

The value is visible, editable, and becomes evidence only when the user submits the draft.

## Dangerous semantic default

Example:

```text
Replacement routing [copied silently from old Scheduled]
```

That manufactures a relation the user did not state.

### Candidate law IS-07 — default presentation, never default authority

> Defaults may reduce typing, but a default must not silently create semantic evidence that is not already justified.

This sharpens an existing LOAM principle.

Sources:
- Apple HIG, Settings.
- Apple HIG, Onboarding.

---

# 8. Personalization and customization are not the same as adaptive rearrangement

Customization gives the person explicit control.

Adaptive interfaces change themselves based on inferred behavior.

Both can help, but adaptation can also make an interface unpredictable.

### Candidate safe customization

- choose compact vs roomy density,
- choose which secondary Home blocks are visible,
- customize shortcut bindings,
- choose chart/table preference for a report,
- choose whether optional attention classes appear on Home.

### Candidate risky adaptation

- automatically moving sections,
- hiding commands because they are rarely used,
- silently changing defaults from inferred habits,
- changing which action Enter performs based on prediction.

### Candidate law IS-08 — personalize parameters, not meaning

> Let people customize presentation and acceleration; do not let personalization alter accounting meaning or make action locations unpredictable without explicit benefit.

Source:
- Microsoft Research on adaptive graphical interfaces.
- Apple HIG settings guidance.

---

# 9. Interface change has a transition cost

Research on interface change shows that even an objectively better interface can cause an immediate performance drop. Some users abandon a new interface before learning enough to benefit from it.

### LOAM consequence

A future TUI replacing HRA-like habits should not be judged only after expert familiarity, nor only on first use.

We need a learning curve.

### Candidate measurement schedule

For each candidate shell:

- first encounter,
- fifth repetition,
- twentieth repetition,
- after one-week gap,
- after a feature relocation/change.

Record:

- completion time,
- errors,
- help lookups,
- subjective effort,
- confidence,
- desire to revert,
- whether performance is still improving.

### Candidate law IS-09 — measure the curve, not one point

> A good recurring-use interface may legitimately cost a little more on day one if it becomes much easier by day twenty, but the initial cost must not exceed the user's tolerance to continue.

Source:
- Microsoft Research, On User Behaviour Adaptation Under Interface Change.

---

# 10. Expertise should reveal accelerators without creating a second semantic system

Novices benefit from visible controls and descriptive labels.

Experienced users benefit from:

- keyboard shortcuts,
- command palette,
- type-to-search,
- stable spatial locations,
- prefilled repeated structures.

### LOAM consequence

The expert path should be a faster entrance to the same application action.

Bad architecture:

```text
GUI Replace -> semantics A
CLI replace -> semantics B
keyboard shortcut -> special fast path C
```

Preferred:

```text
visible action
shortcut
palette
CLI
ChatGPT proposal
    -> same application action/admission boundary
```

### Candidate law IS-10 — expertise changes access cost, not meaning

This extends LH-08.

Source:
- Nielsen Norman Group heuristic 7 / flexibility and efficiency of use.

---

# 11. Autonomy matters for sustainable use

Interfaces can be efficient and still feel coercive.

Autonomy-oriented design allows people to work in ways aligned with their own priorities rather than forcing one narrow sequence.

### LOAM consequence

Potentially healthy flexibility:

- select date first, then record,
- choose Record first, then date,
- use mouse, keyboard, CLI, or chat,
- inspect exact provenance only when wanted,
- postpone a nonblocking cleanup decision,
- dismiss an AI suggestion without punishment.

The semantic result must remain exact across paths.

### Candidate law IS-11 — multiple routes, one meaning

> Permit different human routes when they converge on the same explicit semantic proposal.

This is particularly relevant to the multi-surface LOAM architecture.

Sources:
- Nielsen Norman Group, Three Methods to Increase User Autonomy.
- Apple 2026 design principles: Agency, Responsibility, Familiarity, Flexibility, Simplicity.

---

# 12. Avoidance is a stronger failure signal than slow completion

For recurring household software, a feature can technically work while still failing in practice because the person avoids it.

Examples:

- "I will fix that transaction later."
- "I don't want to open Capacity because it is confusing."
- "I stopped recording small purchases because entry feels tedious."
- "I ignore the attention panel because it always has something red."

### Candidate long-term metrics

Add these to synthetic/real dogfood:

- `AvoidanceIntent`: did the user want to postpone the task despite having time?
- `RepeatWillingness`: would they willingly use this flow again tomorrow?
- `FeatureDormancy`: is a useful capability repeatedly avoided?
- `CleanupDebt`: how many small unresolved tasks accumulate because correction is annoying?
- `AlertDismissalHabit`: are warnings dismissed without inspection?

### Candidate law IS-12 — measure what people stop doing

> A recurring-use feature that is correct but consistently avoided is not a successful interaction design.

This is directly relevant to household bookkeeping because missing entries degrade the value of every downstream report.

---

# 13. Visual delight is not irrelevant, but it must support purpose

Aesthetic quality can affect how approachable and satisfying an interface feels.

But visual polish cannot compensate for:

- ambiguous meaning,
- poor recovery,
- unstable navigation,
- missing context,
- bad defaults.

### LOAM consequence

The visual goal should not be "enterprise finance dashboard" or "cute budgeting app" by default.

A better target:

> calm, legible, exact, responsive, and pleasant enough that returning to it does not feel like clerical punishment.

This may matter especially for a tool used every day.

Source:
- Apple 2026 design principles, including Craft and Delight.

---

# 14. Revised evaluation profile

A candidate LOAM surface should now be profiled across at least these dimensions.

## Correctness / meaning

1. task effectiveness
2. semantic clarity
3. safety eligibility
4. provenance reachability

## Immediate interaction

5. UI Tax
6. genuine data-entry burden
7. visual-search burden
8. discoverability
9. response/feedback quality

## Orientation / learning

10. spatial stability
11. information scent
12. learning curve
13. cold-start recovery for rare tasks

## Recovery / time

14. correction distance
15. resumption friction
16. context preservation

## Attention / sustainability

17. attention friction
18. avoidance intent
19. repeat willingness
20. feature dormancy

## Human control

21. autonomy
22. customization without semantic fork
23. automation trust calibration

Do not collapse these into a single number yet.

---

# 15. New synthetic experiments

## EXP-IS01 — stable vs adaptive Home

Compare:

A. fixed Home blocks
B. Home automatically reordered by current attention/recent use

Measure after repeated runs:

- locate time,
- visual-search pauses,
- wrong-region actions,
- preference,
- ability to resume after a week.

Hypothesis:

> stable landmarks outperform adaptive order for repeated household use unless the adaptation benefit is very large.

---

## EXP-IS02 — chart vs table vs linked pair

Task set:

- identify exact largest expense,
- identify spending trend,
- compare two cycle totals,
- inspect why one value exists,
- find a specific movement.

Compare:

A. chart only
B. table only
C. chart overview + linked table/detail

Hypothesis:

> linked overview/detail wins mixed analytical tasks without requiring every report to become graphical.

---

## EXP-IS03 — human-layer vs technical-layer failure

Create a stale Scheduled completion attempt.

Compare:

A. technical failure only
B. human explanation only
C. human explanation + expandable exact detail

Measure:

- successful recovery,
- confidence,
- ability to explain what happened,
- debugging usefulness.

Hypothesis:

> layered error explanation preserves both household usability and LOAM inspectability.

---

## EXP-IS04 — visible commands vs palette vs both

Use rare tasks after a simulated long gap:

- correction,
- external balance comparison,
- replacement routing inspection,
- integrity explanation.

Compare:

A. visible navigation only
B. palette only
C. visible common actions + palette long tail

Measure:

- discovery success,
- search term mismatch,
- time,
- help lookup.

---

## EXP-IS05 — default date visibility

Compare:

A. selected Home date visibly prefilled
B. silently inherited date
C. no default; always type date

Measure:

- wrong-date errors,
- time,
- confidence,
- correction count.

Hypothesis:

> visible editable default dominates both silent inheritance and mandatory re-entry.

---

## EXP-IS06 — interface evolution

After the user becomes familiar with a paper TUI, relocate or rename one action.

Measure:

- performance drop,
- frustration,
- recovery via palette/search,
- preference for old vs new location.

This tests migration cost before LOAM accumulates real UI history.

---

# 16. Current synthesis

The broad research now suggests that a good LOAM UI should not optimize for a single static concept of simplicity.

It should aim for:

```text
semantic exactness
+ stable orientation
+ low avoidable interaction tax
+ strong information hierarchy
+ recognition-first local action
+ searchable long-tail action
+ task-appropriate exact/visual representation
+ visible recoverable errors
+ safe visible defaults
+ gradual expertise
+ autonomy across surfaces
+ sustained willingness to return
```

The most important new shift is:

> **Familiarity itself is an asset that the UI can either accumulate or destroy.**

A household system is not merely a sequence of forms. Over months, it becomes a learned spatial and semantic environment.

LOAM should therefore be evaluated not only on whether the first interaction is understandable, but on whether repeated interaction becomes calm, fast, and almost location-like without making hidden assumptions.

---

## Working rule

> Keep meaning stable, let familiarity compound, and make the long tail discoverable.
