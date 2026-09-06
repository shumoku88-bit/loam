# LOAM Interaction Atlas — HRA Interaction Archaeology

Date: 2026-09-06  
Status: **observed usability specimen; not a LOAM UI selection**  
Parent: `LOAM_INTERACTION_ATLAS.md`

---

## 0. Why HRA is a high-weight specimen

The user reports that HRA has been the easiest household system they have used so far.

That is not proof that HRA's navigation should be copied into LOAM, but it is stronger evidence than a purely hypothetical wireframe. HRA was used against the user's own household workflow, so this shard treats it as a **high-weight experiential benchmark**.

The research question is therefore:

> Which concrete interaction properties of HRA may have produced that usability, and which of those properties survive when mapped onto LOAM's smaller semantic vocabulary?

Reference HRA revision inspected here:

`75cc6b04c38dff47cb6373f5d2ca38038ba7c9bf`

The analysis below deliberately separates:

1. direct code observation,
2. plausible usability hypotheses,
3. candidate LOAM experiments.

---

# 1. Interaction topology

HRA's household TUI is not a set of unrelated command screens. It has a persistent **Home coordinate** consisting of:

- `Known_Through`
- `Selected_Day`

The selected day can move without changing what is currently known. Home navigation uses:

- `h` / Left: previous day
- `l` / Right: next day
- `k` / Up: previous week
- `j` / Down: next week
- `g`: return focus to `Known_Through`

From that stable coordinate, a single mnemonic key opens each main action surface:

- `r`: record Actual directly for the selected day
- `a`: Actual workspace
- `p`: Plan workspace
- `i`: Issue workspace
- `e`: Entitlement workspace
- `v`: Reports workspace
- `q`: quit

Source trail:

- `src/hra-household_home_interaction.adb`
- `src/hra-household_home_tui_input.adb`
- `src/hra-household_home_tui_help.adb`

### Usability hypothesis HRA-U01 — stable temporal place

The user rarely needs to answer “what date am I acting on?” inside every operation. Home already carries the selected day.

This may reduce repeated date entry while keeping the date visually explicit.

### LOAM experiment candidate

Compare:

A. command-first TUI that asks for date inside every action

against

B. a persistent time navigator where actions inherit an explicit selected coordinate.

Measure:

- date re-entry count,
- wrong-date corrections,
- context loss after returning from a workspace,
- time-to-record for past and future events.

---

# 2. Home is a time navigator, not merely a dashboard

HRA Home renders a monthly calendar plus structured details for the selected day.

The UI-neutral Home presentation contains:

- calendar grid,
- Actual details,
- Plan details,
- Issue details,
- Cycle role,
- separate `Known_Through` and `Selected_Day`,
- future-focus state.

Calendar cells can expose independent attention facts:

- Plan scheduled,
- Issue due,
- Cycle end,
- multiple simultaneous facts.

The selected day then expands into concrete sections:

- Actual Transactions,
- Planned Payments,
- Due Issues,
- Cycle.

Importantly, unavailable states are not rendered as empty success. For example:

- Actual beyond the known horizon is shown as not yet visible,
- Issue closure timing can be shown as unavailable,
- Cycle resolution failure is shown explicitly.

Source trail:

- `src/hra-household_home_presentation.ads`
- `src/hra-household_home_text.adb`
- `src/hra-household_home_tui_render.adb`

### Usability hypothesis HRA-U02 — temporal recognition beats menu recall

A date on a calendar is a strong recognition cue. The user can remember “around that Tuesday” rather than recall a transaction identifier or menu path.

### Usability hypothesis HRA-U03 — one Home coordinate joins unlike domains without flattening them

Actual, Plan, Issue, and Cycle remain different semantic domains, but the same date can reveal them together.

The calendar is therefore a **coordinate system**, not a universal event ontology.

### Candidate LOAM principle

> Let time align distinct facts without forcing them into one stored type.

---

# 3. Direct recording from Home

Pressing `r` on Home starts an Actual editor already anchored to the selected day.

The editor is a general balanced-posting form:

1. Description
2. Posting 1 account
3. Posting 1 amount
4. Posting 2 account
5. Posting 2 amount
6. optional additional posting rows

Keyboard behavior:

- Tab: next field
- Shift-Tab: previous field
- Ctrl-N: add posting row
- Ctrl-D: drop final posting row
- Esc: cancel
- Enter: preview

On account fields, matching account candidates are shown immediately. Up/Down changes the candidate selection and Enter accepts the account and advances.

Preview displays the typed transaction shape and then offers:

- Enter: record
- `e`: edit
- `q`: cancel

The editor itself returns a typed transaction. Durable identity and publication remain outside the editor.

Source trail:

- `src/hra-household_actual_record_tui.ads`
- `src/hra-household_actual_record_tui.adb`
- `src/hra-household_actual_record_interaction.adb`

### Usability hypothesis HRA-U04 — form movement is spatially predictable

The field cycle is fixed:

`description -> account -> amount -> account -> amount ...`

The user does not navigate a tree of transaction types just to enter ordinary data.

### Usability hypothesis HRA-U05 — candidate visibility removes identifier recall

Account names are recognized from live candidates rather than memorized or repeatedly typed in full.

### Usability hypothesis HRA-U06 — preview is a mode boundary

HRA does not mix “editing” and “published”. Enter first moves from editing into an explicit preview. A second Enter publishes.

This gives a short daily path without losing a strong semantic checkpoint.

### Candidate LOAM experiment

Synthetic-dogfood the same purchase using:

- wizard prompts,
- HRA-style inline form,
- command palette,
- chat proposal.

Compare not just keystrokes but:

- eye travel,
- account recall,
- number of mode changes,
- accidental publication,
- recovery distance.

---

# 4. One editor is reused through typed seeds

A particularly important HRA pattern is that the Actual editor can start from:

- an empty draft,
- an already typed transaction seed,
- a typed seed plus a presentation-only context line.

Seed values are editable, but they still pass through the same build and preview law.

This is used by Plan completion.

### Usability hypothesis HRA-U07 — reuse through prefilled meaning, not copy-paste

The user gets the convenience of “use what I already planned” without a separate second editor or implicit publication.

### Candidate LOAM principle

> Reuse an already-earned typed shape as an editable draft, but never let prefill become silent retained evidence.

This closely matches LOAM's current Scheduled completion/replacement behavior where interactive defaults may be retained by pressing Enter while scripted callers remain explicit.

---

# 5. Actual workspace: inspect first, mutate from the selected object

Home `a` enters the Actual workspace.

The workspace coordinates account selection, transaction selection, filtering, and actions. Its action keys include:

- `f`: cycle temporal filter
- `x`: reverse selected Actual
- `p`: create Plan from selected Actual
- `a`: add Account
- `n`: record new Actual
- `q`: return Home

The visible footer summarizes these actions instead of requiring hidden command recall.

A reversal is not “delete”. HRA prepares an exact inverse and shows a dedicated preview containing:

- target ID/date/description,
- original postings,
- reversal candidate identity/date/description,
- exact inverted postings,
- explicit statement that target source is preserved.

Then Enter publishes or `q` cancels.

Source trail:

- `src/hra-household_actual_workspace_tui.ads`
- `src/hra-household_actual_workspace_tui.adb`
- `src/hra-household_actual_workspace_tui_input.adb`

### Usability hypothesis HRA-U08 — actions are object-local

The user selects an Actual and then chooses what to do with *that Actual*.

This is cognitively different from opening a global “Correction” screen and then identifying the target again.

### Candidate LOAM principle

> Prefer object-local actions after recognition-based selection when the target identity already exists on screen.

---

# 6. Plan workspace: lifecycle verbs stay adjacent to the selected Plan

Home `p` opens a list of open Plans visible through the current horizon.

The selected Plan shows:

- scheduled date,
- description,
- Plan identity,
- posting summary.

Actions:

- `j/k`: select
- Enter / `c`: complete
- `n`: add Plan
- `x`: cancel
- `s`: supersede
- `q`: Home

Source trail:

- `src/hra-household_plan_workspace_tui.adb`
- `src/hra-household_plan_workspace_tui_input.adb`

### Usability hypothesis HRA-U09 — lifecycle operations are visible together

Create, complete, cancel, and supersede are not scattered across unrelated menus.

The selected object's legal next operations sit directly under the object.

This gives the user a small local state machine without needing to know the implementation's lifecycle relation types.

---

# 7. Plan completion: confirm identity, then prefill Actual

Completing a Plan is deliberately staged.

1. Confirm the selected Plan with ID, planned date, description, and postings.
2. Explicitly state that continuing opens a prefilled Actual editor and publishes nothing yet.
3. Choose Actual date, defaulting to Home's selected day.
4. Open the same general Actual editor seeded from the Plan transaction.
5. Preview the resulting Actual.
6. Choose whether to:
   - complete only, or
   - complete and create a next Plan.
7. If a next Plan is requested, require its date and open another seeded editor.
8. Publish only after the requested draft world is complete.

Source trail:

- `src/hra-household_plan_completion_tui.ads`
- `src/hra-household_plan_completion_tui.adb`

### Usability hypothesis HRA-U10 — staged confirmation mirrors the human question order

The flow asks:

1. “Is this the Plan?”
2. “What actually happened?”
3. “Does there need to be a next one?”

This may be easier than exposing completion, replacement, continuation, recurrence, and identity relations simultaneously.

### LOAM warning

HRA's convenient “also create next Plan” UI must not cause LOAM to conflate replacement with continuation. LOAM has already earned that these are separate meanings.

The interaction pattern may still be reusable while the semantics remain separate.

---

# 8. Issues: an explicit attention workspace

Home `i` opens visible Issues.

Each list item exposes:

- identity,
- status,
- due state/date,
- title.

The selected Issue can also display relation history such as:

- realized-as Actual,
- continued-as another Issue,
- continued-from another Issue.

Actions:

- `j/k`: select
- `c`: close
- `r`: realize as Actual
- `f`: continue
- `n`: new
- `q`: Home

Source trail:

- `src/hra-household_issue_workspace_tui.adb`
- `src/hra-household_issue_workspace_tui_input.adb`

Issue creation also distinguishes due states rather than forcing a fake date:

- specific due date,
- no due date,
- due undetermined.

It supports Enter-to-keep defaults, explicit empty values, selected-day shortcuts, validation messages, and review before publication.

### Usability hypothesis HRA-U11 — nonfinancial attention is not forced into transactions

A household task can exist before money moves.

This likely prevents the TUI from forcing every concern through the ledger just because the ledger is easy to display.

### Candidate LOAM question

Does LOAM need a first-class Attention/Issue capability, or can a smaller already-earned concept provide the same human affordance?

Do not copy the HRA domain type until this is re-earned.

---

# 9. Entitlement workspace: complexity earns more explanation

Home `e` opens the Entitlement workspace.

The first screen is observational:

- unallocated balance,
- current Envelope balances,
- retired balances that can only be sources,
- stock origins.

A movement is initiated with `t` (or `m`). The flow then asks:

1. From endpoint
2. To endpoint
3. Date, defaulting to Home's focus day
4. positive quantity
5. Commodity, with a safe default when available

The typed movement kind is derived from the chosen endpoints:

- unallocated -> Envelope: grant
- Envelope -> unallocated: return
- Envelope -> Envelope: transfer

Before publication, HRA shows a semantic preview with:

- From / To
- Date
- Amount
- current source balance
- current target balance
- after source balance
- after target balance
- exact canonical evidence that will be retained

Then Enter publishes or `q` cancels.

Source trail:

- `src/hra-household_entitlement_workspace_tui.adb`
- `src/hra-household_entitlement_workspace_tui_input.adb`

### Usability hypothesis HRA-U12 — explanation density scales with semantic risk

Ordinary Actual recording is a compact inline form.

Entitlement movement, which changes allocation rights and has less familiar semantics, receives a richer before/after preview.

This suggests a useful rule:

> Do not make every operation equally verbose. Spend explanation budget where the user's mental model is most likely to diverge from the retained meaning.

---

# 10. Reports: remain a separate inspection surface

Home `v` enters Reports rather than filling Home with every report.

The report workspace contains 11 semantic sections and supports:

- line scrolling,
- page scrolling,
- horizontal scrolling,
- previous/next section,
- chooser mode,
- Home return.

The current section number and title stay visible.

Special action is contextual: Envelope Budget can expose classification of unrouted Expense activity, while unrelated sections do not show that action.

Source trail:

- `src/hra-household_report_workspace_tui.adb`
- `src/hra-household_report_workspace_tui_input.adb`

### Usability hypothesis HRA-U13 — Home is not forced to become analytics

Daily orientation and deep reporting are adjacent but separate.

This reduces Home density while keeping reports one key away.

---

# 11. Mutation return path and stale-state handling

After mutation attempts, HRA generally reloads the canonical Household before continuing.

Examples include:

- recording an Actual,
- completing/cancelling Plans,
- Entitlement publication.

Some failure paths deliberately return to Home rather than reuse cached choices when policy/source premises may have become stale.

### Usability hypothesis HRA-U14 — the UI's mental continuity is stronger because stale application state is not silently reused

The user returns to a familiar place, but the displayed state has been re-admitted from canonical sources.

This is both a safety property and an interaction property.

### Candidate LOAM principle

> Preserve navigation context where safe; refresh semantic state after writes.

---

# 12. Why HRA may have felt easier than its concept count suggests

HRA has many domain concepts, yet the TUI often presents a small local vocabulary.

The likely pattern is:

```text
Home time coordinate
   |
   +-- r -> record one Actual
   +-- a -> inspect/select Actual -> local actions
   +-- p -> inspect/select Plan   -> local lifecycle actions
   +-- i -> inspect/select Issue  -> local lifecycle actions
   +-- e -> inspect allocations   -> move with rich preview
   +-- v -> inspect reports
```

The user does not start by navigating the domain model. They start from either:

- **a day**, or
- **a visible object**.

Only then do legal actions appear.

This is a strong candidate explanation for usability.

---

# 13. Candidate HRA-derived interaction laws for LOAM

These are **research hypotheses**, not accepted LOAM laws.

### HRAL-01 Keep a stable orientation surface

After a sub-flow, return to a recognizable coordinate rather than dropping the user into an unrelated root menu.

### HRAL-02 Time can be navigation without being ontology

Use selected day as context across facts without requiring a universal event type.

### HRAL-03 Recognition before identifier recall

Select visible objects; do not ask humans for internal IDs when the object is already on screen.

### HRAL-04 Object-local actions

Once an object is selected, expose only actions meaningful for that object/state.

### HRAL-05 Frequent path short, consequential path explanatory

Do not impose a giant confirmation ceremony on ordinary entry, but provide semantic before/after previews for unfamiliar or high-impact actions.

### HRAL-06 Prefill is draft convenience, never authority

A Plan/Scheduled value can seed editing, but the new Actual remains independent evidence.

### HRAL-07 Preview separates editing from publication

A preview boundary should make it obvious when nothing has been retained yet.

### HRAL-08 Failure is content

Unavailable/ambiguous/error states should occupy visible UI space rather than masquerading as empty results.

### HRAL-09 Preserve place, refresh truth

Keep navigation context where possible while re-reading canonical state after mutation.

### HRAL-10 Help should be ambient and local

HRA continuously displays compact key help at the bottom and adapts it to terminal width. This reduces reliance on memorized global shortcuts.

---

# 14. What should not be copied blindly

The user preference for HRA should not turn into “port HRA to Lean”.

Potential baggage that must be re-earned:

- HRA's exact section taxonomy,
- Entitlement terminology,
- Issue as a retained LOAM concept,
- 11-section report book,
- exact key bindings,
- Plan continuation UX,
- account/posting vocabulary at the first layer,
- any HRA-specific persistence shape.

LOAM should copy **interaction properties only after comparison**, not inherited nouns.

---

# 15. Highest-value next comparison

The next useful experiment is not another product survey. It is a controlled comparison between:

1. HRA's actual interaction topology,
2. h-kernel's TUI topology,
3. current LOAM CLI,
4. a minimal HRA-inspired LOAM TUI sketch.

Use the same synthetic household scenarios from `LOAM_INTERACTION_ATLAS_TRANSACTION_ENTRY.md`.

For each surface measure:

- steps to reach the action,
- decisions required,
- identifiers recalled,
- explicit defaults accepted,
- context switches,
- preview quality,
- recovery distance,
- whether selected date/object survives return,
- whether failure is distinguishable from empty state.

The key question is:

> Was HRA easy because of its visual layout, because of its navigation topology, because of its prefill/default policy, because it kept semantic operations local, or because of some combination of these?

That question should be answered before LOAM adopts an HRA-like shell.
