# LOAM Interaction Atlas — Synthetic Interaction Scorecard

Date: 2026-09-06  
Status: **provisional structural scoring; not timed usability evidence**  
Parent: `LOAM_INTERACTION_ATLAS.md`  
Companion: `LOAM_INTERACTION_ATLAS_INTERACTION_TRACES.md`

---

## 0. Purpose

This shard turns the code-derived interaction traces into a first **synthetic scorecard**.

It does **not** attempt to produce one overall usability number yet. The goal is narrower:

> test the hypothesis that HRA felt easier partly because it imposed less presentation-only work before and after the real household action.

The user's report that HRA was the easiest household UI used so far is treated as an external experiential anchor, not as a score input.

The scorecard therefore isolates UI-created burden from:

- genuine semantic decisions,
- necessary target selection,
- actual data entry,
- safety/publication work.

Those dimensions remain recorded separately.

---

# 1. Safety gate comes before scoring

A candidate interaction path is not eligible merely because it is short.

For each operation, first check the relevant safety properties:

- fail closed on unavailable/ambiguous state,
- do not manufacture semantic evidence from UI defaults,
- preserve provenance/history,
- re-read stale-sensitive authority before publication where required,
- preserve qualified publication ordering/recovery,
- distinguish retained fact from projection.

If a candidate fails a relevant safety property, it is **ineligible**, regardless of its interaction score.

The scorecard must therefore never reward a UI for removing a confirmation or explicit distinction that is semantically necessary.

---

# 2. First experimental metric: UI Tax

The first metric intentionally measures only work introduced by presentation.

```text
UI Tax = PF + R + CD
```

where:

## PF — Presentation-focus tax

Add `1` for each required transition whose purpose is only to put the UI into the right interaction region/mode, not to select a semantic target.

Examples:

- Calendar focus -> Section focus,
- Section focus -> Surface focus,
- Accounts pane -> Transactions pane when the desired transaction is already the semantic target class.

Do **not** count:

- moving to a different day,
- moving the cursor to a different Scheduled item,
- choosing the account actually being reconciled.

Those are target selection, not presentation tax.

## R — Recall/re-entry tax

Add:

- `2` when an internal identity already visible in the UI must be typed/recalled, such as `scheduled-7`,
- `1` when a human-meaningful datum that could safely be inherited or selected from visible context must be re-entered, such as an already-visible date,
- `1` when a currently known selectable domain token must instead be typed exactly.

Do not count genuinely new information.

Examples:

- new purchase amount: `0` tax, because the system does not know it,
- changed replacement date: `0` tax, because it is the semantic change,
- typing a visible Scheduled ID to act on the selected row: `2` tax.

## CD — Context-displacement tax

After completion/cancel/recovery:

- `0`: return to the same useful human place/workspace,
- `1`: return to the same domain/list but local selection/orientation is lost,
- `2`: return to Home and the user must re-enter the domain,
- `3`: return to a top menu/command shell and the operation context must be reconstructed,
- `4`: the command/process must effectively be restarted from scratch to continue the task.

A completed object legitimately disappearing from the current-open set does not by itself count as context loss.

---

# 3. What UI Tax deliberately ignores

This metric is not a proxy for total work.

It does not count:

- `SD`: real semantic decisions,
- `TS`: target-selection movement itself,
- `DE`: genuine data entry,
- `PR`: necessary preview/admission/publication/recovery work.

That matters because h-kernel may reduce ordinary expense data entry through specialized flows, while HRA may have lower navigation tax. Likewise current LOAM may have a longer publication story because it has stronger qualified recovery semantics.

A low UI Tax therefore means only:

> the interface asks the human to do little work that exists solely because of the interface.

---

# 4. Fixed comparison stance for this pass

To keep the first scores reproducible:

- start each TUI trace at Home/calendar unless the scenario explicitly starts in a local object view,
- use keyboard paths, not mouse shortcuts,
- use the shortest documented direct path,
- assume the user is familiar with the UI,
- do not charge semantic target movement as PF,
- score current repository paths, not imagined improvements.

Reference traces:

- HRA revision: `75cc6b04c38dff47cb6373f5d2ca38038ba7c9bf`
- h-kernel revision: `722b8460b056bf2d68d1cc837de403ee59f29c0c`
- LOAM reference used by the trace shard: `7f2e117b66b076295d32d60f9347a2490cb13582`

These scores must be recomputed if the interaction paths materially change.

---

# 5. First six scenario scores

These numbers are **structural estimates from the inspected code paths**, not observed completion-time data.

## S01 — ordinary purchase today

### HRA

```text
Home(selected today) -> r -> editor -> preview -> publish -> same Home coordinate
```

- PF: 0
- R: 0
- CD: 0
- **UI Tax: 0**

### h-kernel

Using the direct Home `r` path:

- PF: 0
- R: 0
- CD: 0
- **UI Tax: 0**

### current LOAM CLI

- no persistent selected day, so occurrence date is re-entered: R +1
- operation returns to command/top-menu orientation: CD +3
- PF: 0
- **UI Tax: 4**

Important counterpoint: this does not count LOAM's exact movement/admission preview, nor does it count HRA's posting-field volume.

---

## S02 — record a purchase from three days ago

### HRA

The user moves the visible day coordinate, then records from it.

- PF: 0
- R: 0
- CD: 0
- **UI Tax: 0**

Calendar movement is target selection, not UI tax.

### h-kernel

The direct calendar -> `r` path behaves similarly.

- PF: 0
- R: 0
- CD: 0
- **UI Tax: 0**

### current LOAM CLI

The exact ISO date is typed inside the entry flow and no selected-day context persists afterward.

- PF: 0
- R: 1
- CD: 3
- **UI Tax: 4**

This does not mean calendar traversal is always faster. Direct ISO entry may be excellent for an expert who already knows the date. The metric tests recall/orientation burden, not elapsed time.

---

## S03 — find and correct/reverse a mistaken Actual

### HRA

Representative inspected path is object-local:

```text
Home -> a -> select target -> local reverse action -> preview -> publish -> Actual context
```

- PF: 0
- R: 0
- CD: 0
- **UI Tax: 0**

### h-kernel

Keyboard path from Home can require:

- Calendar -> Section focus,
- Section -> Surface focus,
- Accounts -> Transactions pane focus.

Using the representative cold path:

- PF: 3
- R: 0
- CD: 0
- **UI Tax: 3**

Mouse or already-being-in-the-Actual-surface can reduce this score. That is why later dogfood should record start state explicitly.

### current LOAM CLI

Correction candidate selection is already recognition-first through a displayed numbered list, so there is no internal-ID recall charge.

The main tax is orientation after the command returns.

- PF: 0
- R: 0
- CD: 3
- **UI Tax: 3**

Separate issue not included in UI Tax: the corrected balanced movement is re-entered rather than seeded from the selected target.

---

## S04 — complete Scheduled/Plan as Actual

### HRA

Object-local Plan selection plus editable prefill:

- PF: 0
- R: 0
- CD: 0
- **UI Tax: 0**

The selected Plan can legitimately disappear after completion without counting as lost context.

### h-kernel

Representative keyboard path from Home to Plans surface:

- Calendar -> Section focus: +1
- Section -> Surface focus: +1

Then Plan selection/action is semantic target work.

- PF: 2
- R: 0
- CD: 0
- **UI Tax: 2**

### current LOAM CLI

The Scheduled workbench displays the object, then requires the internal Scheduled ID to be typed for `Record what actually happened`.

- PF: 0
- R-ID: +2
- missing persistent selected-day context can require date-context work: +1
- CD: 0, because the Scheduled workbench re-renders after the action
- **UI Tax: 3**

This is one of the clearest current opportunities for a TUI to reduce tax without changing any Scheduled completion semantics.

---

## S05 — replace/reschedule one Scheduled item

### HRA

Representative Plan lifecycle operation is initiated from the selected visible object.

- PF: 0
- R: 0
- CD: 0
- **UI Tax: 0**

### h-kernel

Representative keyboard path from Home to Plans surface:

- PF: 2
- R: 0
- CD: 0
- **UI Tax: 2**

### current LOAM CLI

The old Scheduled date and movement are already used as editable defaults, which is good. The avoidable tax is target identity recall:

- PF: 0
- visible internal Scheduled ID must be typed: R +2
- same Scheduled workbench is re-rendered: CD 0
- **UI Tax: 2**

This result is particularly encouraging: the existing LOAM replacement publisher already contains the hard semantics. A selectable list could remove almost all measured tax here.

---

## S06 — move spending Capacity/allocation

### HRA

Representative Entitlement flow begins from a stable Home/domain path and shows Current/After state.

- PF: 0
- R: 0 when endpoints are selected from visible Entitlement context
- CD: 0
- **UI Tax: 0**

### h-kernel

Representative keyboard path through the generalized section shell:

- PF: 2
- R: 0
- CD: 0
- **UI Tax: 2**

### current LOAM CLI

The Capacity command is semantically small, but known Purpose endpoints are typed as tokens rather than selected from a visible current state. For the common `unallocated -> known purpose` case:

- PF: 0
- R-token: +1
- return to top-level command/menu orientation: CD +3
- **UI Tax: 4**

A purpose-to-purpose move can incur another token-recall unit, so this case can be `5` depending on starting information.

---

# 6. First structural result

Using the fixed representative keyboard paths above:

| Scenario | HRA | h-kernel | current LOAM CLI |
|---|---:|---:|---:|
| S01 ordinary purchase | 0 | 0 | 4 |
| S02 past purchase | 0 | 0 | 4 |
| S03 correct Actual | 0 | 3 | 3 |
| S04 complete Scheduled | 0 | 2 | 3 |
| S05 replace Scheduled | 0 | 2 | 2 |
| S06 move Capacity | 0 | 2 | 4 |
| **Mean UI Tax** | **0.0** | **1.5** | **3.3** |
| **Median UI Tax** | **0** | **2** | **3.5** |

This is **not an overall usability ranking**.

It says something narrower and useful:

> Under a metric intentionally designed to expose presentation-only navigation, recall, and context loss, the inspected HRA paths are consistently flatter.

That is compatible with the user's lived report that HRA felt easiest, so the hypothesis survives this first structural check.

It is not yet confirmed, because the metric was chosen after the HRA preference was known and because no timed/error-rate dogfood has been run.

---

# 7. Why this does not prove HRA should be copied

The scorecard deliberately omits several areas where h-kernel or current LOAM may be better.

## h-kernel advantages not captured by UI Tax

- specialized Expense / Income / General entry modes,
- mouse selection,
- responsive narrow/wide layout,
- richer account/transaction workspaces,
- integrated external-balance comparison,
- temporal range observation.

## current LOAM advantages not captured by UI Tax

- WriterOwnership,
- fresh re-read before stale-sensitive publication,
- fail-closed Scheduled frontiers,
- relation-first replacement/correction recovery,
- Event-last authority publication where qualified,
- explicit provenance boundaries,
- stronger refusal to infer routing/continuation/settlement semantics.

## HRA costs not captured by UI Tax

- a general posting editor may require more field-level work for ordinary purchases than a specialized expense form,
- mnemonic shortcuts are efficient after learning but may be less discoverable to a cold user,
- some HRA semantic vocabulary should not be imported into LOAM merely because its UI was pleasant.

Therefore the likely direction is not `copy HRA`.

It is:

> preserve HRA's low orientation tax while borrowing better interaction primitives and keeping LOAM's current semantic/publication machinery.

---

# 8. Second metric set for actual synthetic dogfood

The next run should record raw observations, not just UI Tax.

For every scenario/candidate:

## Time / action

- total key/click count,
- time to first correct semantic preview,
- time from preview to fresh post-write observation.

## Presentation burden

- PF transitions,
- surface changes,
- focus-mode errors,
- help lookups.

## Recall burden

- internal IDs typed,
- dates typed from memory,
- exact domain tokens typed rather than selected,
- already-known values re-entered.

## Error / recovery

- wrong-target attempts,
- wrong-date attempts,
- cancel distance,
- recovery distance after discovering a mistake,
- whether interrupted publication has a clear next action.

## Continuity

- selected day retained,
- selected object retained where meaningful,
- scroll/list position retained,
- fresh canonical reload shown in the same place.

## Subjective report

After each scenario, record a tiny subjective response separately:

- `effort`: 1–5,
- `confidence`: 1–5,
- `orientation`: 1–5 (`I always knew where I was`),
- optional one-sentence note.

Do not combine subjective values into the structural score automatically.

---

# 9. Candidate shells for the next scorecard

The next synthetic comparison should include four shells:

1. **Current LOAM CLI** — real baseline.
2. **HRA-derived flat TUI** — stable selected day + direct mnemonic/object-local actions.
3. **h-kernel-derived focus TUI** — calendar/section/surface shell.
4. **Intent/command-palette shell** — type/select an action first, then target/context.

For candidates 2–4, use paper/state-machine traces first. Do not implement them merely to obtain scores.

Candidate surfaces should call the same LOAM semantic publishers in the model, so safety differences do not contaminate the navigation experiment.

---

# 10. Falsification conditions

The HRA-orientation hypothesis should be weakened or rejected if repeated synthetic/household dogfood shows any of the following:

1. lower UI Tax does not correlate with lower effort, faster completion, fewer errors, or stronger orientation;
2. the user repeatedly prefers h-kernel-style focus or command-palette paths despite higher UI Tax;
3. HRA-style direct mnemonics cause enough shortcut recall/error burden to outweigh their shallow topology;
4. field-level burden from HRA-style general editors dominates the navigation advantage;
5. persistent selected-day context causes wrong-date errors because inherited context is overlooked;
6. object-local actions make advanced operations harder to discover or understand;
7. a richer shell materially improves safety comprehension even when the underlying publisher is identical.

The goal is not to preserve the HRA hypothesis. The goal is to find the smallest interaction model that survives actual use.

---

# 11. First conclusion

The first structural scorecard supports one concrete experiment strongly:

> A LOAM TUI should first test **stable selected-day orientation + selectable objects + local actions**, while leaving existing LOAM publishers untouched.

The highest-confidence low-risk reductions are:

1. stop asking for a Scheduled ID that is already represented by the selected visible row;
2. let a visible selected day seed date drafts without turning the default into hidden authority;
3. return after fresh reload to the same useful date/domain context;
4. show current/after projections for Capacity moves while retaining only existing Capacity evidence;
5. keep presentation-focus modes out of the first prototype unless dogfood demonstrates a real need for them.

This is enough to design a synthetic state-machine prototype. It is **not yet enough to implement a production TUI**.
