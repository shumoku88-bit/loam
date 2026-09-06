# LOAM Interaction Atlas — Cross-System Interaction Traces

Date: 2026-09-06  
Status: **code-derived structural comparison; not timed usability evidence**  
Parent: `LOAM_INTERACTION_ATLAS.md`  
Companions:

- `LOAM_INTERACTION_ATLAS_HRA_ARCHAEOLOGY.md`
- `LOAM_INTERACTION_ATLAS_HKERNEL_ARCHAEOLOGY.md`
- `LOAM_INTERACTION_ATLAS_TRANSACTION_ENTRY.md`

---

## 0. Purpose

The user reports that HRA has been the easiest household system they have used so far.

This document compares the **human-visible interaction traces** for the same household goals across:

1. HRA TUI,
2. h-kernel Brick TUI,
3. current LOAM practical CLI.

The purpose is not to crown a winner from source code. These are **structural traces**, derived from implementation paths and visible prompts, not measured completion times from controlled user tests.

The main question is:

> Which complexity belongs to the household meaning itself, and which complexity is introduced only by the presentation/navigation layer?

Reference revisions used for this pass:

- HRA: `75cc6b04c38dff47cb6373f5d2ca38038ba7c9bf`
- h-kernel: `722b8460b056bf2d68d1cc837de403ee59f29c0c`
- LOAM main observed: `7f2e117b66b076295d32d60f9347a2490cb13582`

---

# 1. Complexity dimensions

A trace records five distinct kinds of work.

| Code | Dimension | Meaning |
|---|---|---|
| SD | Semantic decision | a real-world distinction the user genuinely must decide |
| TS | Target selection | work needed to identify the day/object/account being acted on |
| PF | Presentation focus | UI-only navigation/focus/mode transitions |
| DE | Data entry | fields, free text, amount, endpoint, date, etc. |
| PR | Publication/recovery | preview, confirmation, fresh re-read, cancel/retry boundaries |

Additional flags:

| Flag | Meaning |
|---|---|
| R-ID | internal identifier must be recalled/typed |
| R-DATE | date must be re-entered rather than inherited from visible context |
| KEEP-DAY | selected day survives the operation/return |
| KEEP-OBJ | selected object survives local actions/return |
| FAIL-VISIBLE | unavailable/ambiguous state is shown rather than flattened to empty/zero |
| PREVIEW | a human-visible pre-publication boundary exists |

The comparison should prefer eliminating PF/TS work where doing so does not hide required SD work.

---

# 2. Trace 01 — record an ordinary purchase today

Scenario:

```text
Today
PayPay -> coffee
138 JPY
```

The real semantic content is small:

- occurrence date,
- movement source,
- movement destination/purpose coordinate,
- amount,
- optional description/routing depending on model.

## HRA

Starting point: Home focused on current `Known_Through` / selected day.

Structural trace:

```text
Home on today
  -> r
  -> Actual editor already seeded with selected date
  -> description
  -> source account candidate
  -> amount
  -> destination/use account candidate
  -> amount
  -> Enter preview
  -> Enter publish
  -> reload canonical Household
  -> return to familiar Home coordinate
```

Observed interaction properties:

- date context is inherited from Home,
- account candidates are visible inline,
- one general editor handles two-or-more posting shape,
- Tab order is predictable,
- preview separates draft from publication,
- the user does not type an internal Event ID.

Flags:

- R-ID: no
- R-DATE: no when Home day is correct
- KEEP-DAY: yes
- PREVIEW: yes
- FAIL-VISIBLE: yes for editor/admission failures

### Structural reading

HRA spends little PF work. The user moves from a visible date directly into the operation.

## h-kernel

Starting point: Home/calendar.

Shortest direct path supported by Home:

```text
Home on today
  -> r
  -> Daily/Actual entry flow
  -> household-oriented fields
  -> preview/write outcome flow
  -> fresh workspace reload
  -> return preserving selected day
```

Alternative from Actual surface may pass through:

```text
Calendar
  -> Section focus
  -> Actual
  -> Surface focus
  -> e Expense / i Income / g General
  -> entry flow
```

Observed advantages:

- `r` keeps the frequent Home-to-record path short,
- specialized Expense/Income flows can reduce posting-level input,
- selected-day return remains strong.

Observed added complexity:

- if not entering through Home `r`, shell and pane focus become part of the path,
- several entry modes require choosing which UI path matches the intent.

Flags for Home `r` path:

- R-ID: no
- R-DATE: generally no when selected day is used
- KEEP-DAY: yes
- PREVIEW: yes
- FAIL-VISIBLE: yes

### Structural reading

For this single high-frequency task, h-kernel can be nearly as flat as HRA because it retained direct Home `r`.

This is important: **the HRA advantage cannot be inferred from simple entry alone.**

## current LOAM CLI

Starting point: practical top-level menu.

```text
./tools/loam
  -> 1 Record movement
  -> preflight authority
  -> occurrence date
  -> optional description
  -> FROM locus
  -> FROM amount
  -> blank when FROM done
  -> TO locus
  -> TO amount
  -> blank when TO done
  -> optional relation decision/input
  -> optional discharge decision/input
  -> acquire ownership
  -> fresh re-read/admit
  -> Admission preview
  -> publish supporting evidence
  -> Event last
  -> return to top-level invocation/menu
```

Current strengths:

- strong draft progress feedback,
- balanced movement invariant is explicit,
- provenance/relations/discharges are not inferred from shape,
- fresh identity is chosen at admission, not human input,
- WriterOwnership and fail-closed publication are strong,
- admission preview says exactly which boundaries were crossed.

Current friction:

- occurrence date is asked inside every ordinary movement entry,
- FROM/TO locus loops are semantically precise but verbose for common one-to-one purchases,
- relation/discharge decisions can appear even when ordinary users may rarely need them,
- no persistent selected-day orientation exists,
- user returns to a command/menu shell rather than a date/object context.

Flags:

- R-ID: no
- R-DATE: yes
- KEEP-DAY: no persistent day exists
- PREVIEW: yes, very strong
- FAIL-VISIBLE: yes

### Trace 01 preliminary conclusion

The current LOAM CLI is not missing semantic safety. It is missing **orientation compression**.

A TUI could preserve the exact LOAM admission/publication machinery while borrowing HRA's selected-day context and recognition-first locus selection.

---

# 3. Trace 02 — record a purchase from three days ago

Scenario:

```text
The user notices a forgotten purchase from three days earlier.
```

## HRA

```text
Home
  -> h/h/h or calendar movement to target day
  -> r
  -> record using selected day
  -> preview
  -> publish
  -> return to same selected day
```

The date is chosen spatially before the form opens.

Usability property:

> date selection is navigation, not repeated form data.

## h-kernel

```text
Home calendar
  -> move selected day three days back
  -> r
  -> record
  -> return preserving selected day
```

This is also strong.

## LOAM CLI

```text
Record movement
  -> occurrence date prompt
  -> type YYYY-MM-DD
  -> rest of movement flow
```

This is fewer navigation keystrokes if the date is known exactly, but it requires exact textual recall.

### Trace 02 design tension

Two good modes solve different memory situations:

- **calendar selection** is recognition-first,
- **ISO date entry** is expert/direct.

Candidate LOAM TUI principle:

> Keep a selected day, but allow direct date jump instead of forcing calendar traversal.

The TUI does not need to choose between recognition and explicit entry.

---

# 4. Trace 03 — find and correct a mistaken Actual

Scenario:

```text
A previously recorded movement has the wrong amount or endpoints.
```

This task combines target selection with historical recovery semantics.

## HRA

Typical path:

```text
Home
  -> a Actual workspace
  -> select account/transaction
  -> x reverse selected Actual
  -> exact reversal preview
  -> publish reversal
```

HRA's known reversal path is object-local. The selected transaction is already visible when the action is requested.

The preview shows:

- target identity/date/description,
- original postings,
- inverse candidate,
- exact inverted postings,
- target source preserved.

For correction-oriented entry, HRA also has a general Actual editor capable of fresh replacement-like economic evidence, but reversal is the clearest direct recovery affordance.

Flags:

- R-ID: no
- TS: visual selection
- PF: direct `a`, then local workspace
- PREVIEW: strong
- KEEP-OBJ: selected target is local context

## h-kernel

Representative reversal path:

```text
Home / Workspace
  -> reach Actual surface
  -> Accounts pane
  -> Transactions pane
  -> select transaction
  -> Enter / reverse flow
  -> preview/write outcome
  -> reload
  -> return to Actual workspace with day context
```

Possible focus path from Home:

```text
Calendar focus
  -> Section focus
  -> Actual section
  -> Surface focus
  -> Accounts/Transactions focus
  -> selected transaction
  -> reverse
```

Strengths:

- rich account/transaction inspection,
- selected object remains local,
- typed reversal flow,
- mouse can eliminate some keyboard focus traversal.

Cost:

- more PF states before the semantic action.

## LOAM CLI

Current correction path:

```text
More actions
  -> correct
  -> load Event / Correction / Validity evidence
  -> print numbered correctable records
  -> Select number
  -> enter corrected movement FROM/TO
  -> relation-first correction publication
  -> replacement date evidence when applicable
  -> replacement Event last
  -> report target -> replacement identity
```

Strengths:

- target is selected by displayed number, not by typing Event ID,
- original remains retained,
- dangling relation-first publication can be resumed,
- ambiguous multiple sibling correction relations fail closed,
- effective projection is explicitly distinguished from recorded raw quantities.

Friction:

- candidate display is a global correction list rather than contextual historical navigation,
- for a record found during review, correction is not necessarily an immediate object-local action in the same surface,
- corrected balanced movement is re-entered explicitly rather than seeded from the selected target.

### Trace 03 strongest finding

LOAM's **semantic recovery mechanism is stronger than HRA's simpler UI vocabulary**, but HRA/h-kernel are stronger at **object-local initiation**.

Candidate experiment:

```text
Review / calendar / account view
  -> select Actual
  -> c Correct
  -> editor seeded from selected movement
  -> semantic correction preview
  -> existing LOAM relation-first publisher
```

This would reuse LOAM safety without requiring a global correction entrance.

---

# 5. Trace 04 — complete a planned/scheduled payment as Actual

Scenario:

```text
An expected payment is now known to have happened.
The actual amount/endpoints may differ.
```

## HRA

```text
Home
  -> p
  -> open Plan list
  -> select Plan
  -> Enter/c complete
  -> confirm selected Plan
  -> Actual date defaulted from Home selected day
  -> general Actual editor prefilled from Plan
  -> edit only differences
  -> preview Actual
  -> choose complete-only or complete+next Plan
  -> if next: date + seeded next-Plan editor
  -> publish requested world
  -> reload and return
```

Strong interaction properties:

- Plan is selected visually,
- date context comes from Home,
- expected transaction is an editable draft seed,
- Actual remains independent evidence,
- continuation is asked after Actual meaning is established.

Important semantic warning for LOAM:

HRA's convenient complete-and-next flow must not imply that replacement and continuation are the same relation.

## h-kernel

```text
Home/calendar
  -> section shell or Plans surface
  -> select Plan
  -> Enter/c Complete & Advance
  -> typed completion flow
  -> write outcome
  -> fresh reload
  -> return preserving context
```

h-kernel preserves object-local Plan lifecycle operations and more explicit typed sub-flow state.

## LOAM CLI

Current practical Scheduled workbench:

```text
More actions
  -> scheduled
  -> render open Scheduled movements ordered by date
  -> r Record what actually happened
  -> prompt: Scheduled id
  -> preflight terminal evidence
  -> prepare completion draft outside writer lock
  -> Actual detail collection, with Scheduled movement as editable defaults on interactive TTY
  -> acquire Scheduled ownership
  -> re-read terminal evidence
  -> acquire EventMemory ownership in fixed order
  -> activate completion
  -> re-render open Scheduled set
```

Strengths:

- interactive defaults already implement “press Enter to keep expected values”,
- scripted callers remain explicit,
- stale completion draft cannot beat a concurrent cancellation,
- completion relation is separate evidence,
- no automatic next occurrence/Series inference,
- re-rendered open set makes terminal state visible.

Friction:

- the UI already displays Scheduled IDs in the list but then asks the user to type the Scheduled ID,
- no cursor selection connects visible object to action,
- no persistent selected-day context supplies Actual date,
- routing of replacement/new identity is deliberately independent and may need an explicit later action.

### Trace 04 strongest finding

This is the clearest place where HRA's usability can be recovered with **almost no semantic compromise**:

> replace “type Scheduled ID” with “select visible Scheduled object”, then reuse current LOAM completion draft/publisher unchanged.

---

# 6. Trace 05 — reschedule / replace one future item

Scenario:

```text
An open future payment changes date and possibly amount.
```

## HRA

HRA's Plan workspace exposes lifecycle actions next to the selected Plan, including supersede/edit-style operations depending on revision path.

Representative human graph:

```text
Home
  -> p
  -> select Plan
  -> lifecycle action
  -> edit/confirm replacement
  -> publish
  -> return to Plan list/Home
```

The UI is object-local even though the historical semantics may differ from current LOAM Scheduled replacement law.

## h-kernel

Plans surface exposes:

- Add
- Edit
- Cancel
- Replace
- Complete & Advance

Representative trace:

```text
reach Plans surface
  -> select visible Plan
  -> r Replace
  -> typed lifecycle flow
  -> write outcome
  -> reload Plans surface
```

## LOAM CLI

```text
Scheduled menu
  -> visible open Scheduled list
  -> e Edit / reschedule
  -> prompt: Scheduled id
  -> show selected Scheduled expectation
  -> replacement date [old date]
  -> replacement movement using old movement as interactive editable defaults
  -> acquire Scheduled ownership
  -> re-read completion/retirement/replacement/Event evidence
  -> ensure source currently open
  -> generate or reuse replacement identity
  -> validate frontier
  -> publish replacement relation FIRST
  -> publish replacement Scheduled occurrence
  -> report new identity
  -> remind that routing is independent
  -> re-render open set
```

This is semantically excellent:

- no EditKind/Postpone/Advance retained,
- replacement is not continuation,
- relation-first interruption fails closed,
- retry reuses the retained replacement identity,
- replacement Purpose routing is not silently inherited.

Interaction friction is concentrated almost entirely in **target selection and presentation**:

- the visible source must be retyped by ID,
- replacement routing follow-up is not integrated into the same local object context,
- list is not selectable.

### Trace 05 strongest finding

Current LOAM already has the hard part.

A TUI should probably not reinvent replacement semantics at all. It can wrap the existing sequence with:

```text
select row
  -> e
  -> date field prefilled
  -> movement fields prefilled
  -> semantic preview
  -> publish
  -> keep replacement row selected if possible
  -> visibly mark routing status
```

---

# 7. Trace 06 — move spending capacity/allocation

Scenario:

```text
Move 2,000 JPY from unallocated capacity to books,
or move capacity between two purposes.
```

## HRA

Closest predecessor is Entitlement workspace:

```text
Home
  -> e
  -> inspect unallocated + envelope balances
  -> t/m move
  -> From endpoint
  -> To endpoint
  -> Date [Home focus day]
  -> Amount
  -> Commodity default
  -> semantic Current/After preview
  -> show exact retained evidence
  -> Enter publish
  -> reload
```

Notable usability property:

HRA increases explanation density here because allocation-right semantics are less familiar than ordinary spending.

## h-kernel

Entitlement/Envelope section retains richer maintenance and transfer flows, with section shell/pointer advantages and typed publication paths.

The outer path is typically deeper than HRA because of shell focus, but inner object visibility can be richer.

## LOAM CLI

```text
More actions
  -> capacity
  -> effective date [today]
  -> Capacity from (unallocated or purpose)
  -> Capacity to (unallocated or purpose)
  -> Amount
  -> verify sufficient current entitlement
  -> publish effective evidence
  -> publish Capacity authority
  -> success line
```

Strengths:

- simple small semantic vocabulary,
- effective date remains separate evidence,
- insufficient source entitlement fails closed,
- half-open window inspection exists separately.

Current interaction gap:

- no current/after preview before publication,
- existing purpose balances are not necessarily shown during endpoint selection,
- endpoints are typed tokens rather than selected from recognized current purposes,
- direct command flow is concise but gives less decision support than HRA Entitlement.

### Trace 06 strongest finding

HRA may supply a better **risk-adjusted explanation pattern**:

> show current rights and projected after-state for allocation movement, while keeping ordinary purchase entry lighter.

This is a concrete pattern worth testing in LOAM Capacity UI.

---

# 8. Trace 07 — investigate an external balance mismatch

Scenario:

```text
Bank says 12,345 JPY.
LOAM-derived balance differs.
```

## HRA

HRA has Account/Report surfaces and household report observations, but its easiest daily shell did not make a single universal reconciliation workflow the center of Home.

Likely structural path:

```text
Home
  -> Actual/Reports
  -> inspect account/history
  -> determine discrepancy
```

HRA is less important here as a polished reference than for entry/navigation.

## h-kernel

h-kernel adds integrated account comparison/reconciliation from Actual workspace:

```text
reach Actual surface
  -> select Account
  -> c compare/reconcile
  -> enter external observation
  -> ReconcileFlow
  -> inspect difference
```

This is one area where h-kernel clearly adds a useful household intent-specific path beyond HRA.

## LOAM CLI

Current practical CLI has strong balance/effective/integrity inspections, but no single retained “reconcile” action should be assumed from the currently inspected paths.

Relevant commands include:

- balance views,
- effective views,
- integrity checks,
- correction paths.

The absence of one polished reconcile workflow should be recorded as a **capability/UI gap**, not filled by inventing semantics in this trace.

### Trace 07 conclusion

A future LOAM TUI can borrow h-kernel's **compare external observation** interaction while deciding separately whether any new retained reconciliation evidence is actually needed.

Do not equate “useful reconcile UI” with “must add reconciliation state to Core”.

---

# 9. Trace 08 — inspect an overdue nonfinancial attention item

Scenario:

```text
There is a household financial concern requiring action,
but no money movement has happened yet.
```

Examples:

- reimbursement still expected,
- subscription decision pending,
- unknown-due bill needs investigation,
- refund not yet received.

## HRA

```text
Home calendar marker
  -> selected-day Due Issues
  -> i Issue workspace
  -> select Issue
  -> local action: close / realize / continue
```

Due state can be:

- date,
- no due date,
- undetermined.

This is a strong human affordance because it refuses to invent a transaction merely to remember an unresolved concern.

## h-kernel

h-kernel retains Issues as a dedicated section and exposes open Issue count/status in shell. It also preserves Issue realization and maintenance flows.

The information is richer, but access passes through the generalized section shell unless mouse/selection shortcuts reduce it.

## LOAM CLI

No equivalent first-class practical Issue/Attention capability should be assumed from current LOAM semantics.

This is an explicit **research gap**.

The correct next question is:

> Does LOAM need a retained Issue-like concept, or can existing relation/Scheduled/observation mechanisms plus a presentation-only attention layer cover the actual household needs?

Do not port HRA Issue solely because the UI was useful.

---

# 10. Cross-trace structural matrix

Qualitative scale:

- low = little UI-only overhead
- medium = noticeable but bounded
- high = frequent extra presentation navigation
- N/A = capability/path not established in inspected system

| Task | HRA PF | h-kernel PF | LOAM CLI PF | Strongest observed advantage |
|---|---|---|---|---|
| ordinary purchase | low | low via Home `r`, medium via shell | low shell, but repeated field context | HRA/h-kernel selected-day orientation; LOAM admission safety |
| past purchase | low | low | low navigation, higher date recall | calendar recognition vs explicit date speed |
| correct Actual | low-medium | medium-high | low PF, medium target-context loss | HRA/h-kernel object-local target; LOAM relation-first correction |
| complete Scheduled | low | medium | low PF, but R-ID target re-entry | HRA prefill/local selection; LOAM concurrency safety |
| replace Scheduled | low | medium | low PF, but R-ID target re-entry | LOAM strongest semantics; predecessors better object-local UX |
| move allocation | low | medium | low | HRA current/after preview; LOAM smaller vocabulary |
| external mismatch | medium | medium | fragmented | h-kernel intent-specific reconcile path |
| unresolved Issue | low | medium | N/A | HRA direct attention model |

This table deliberately does not score “overall usability”.

---

# 11. Identifier-recall matrix

| Operation | HRA | h-kernel | current LOAM CLI |
|---|---|---|---|
| ordinary Actual | visible account candidates | visible lists/forms | locus prompts with known-loci support |
| select historical Actual | list selection | list selection | numbered correction candidate selection |
| select Scheduled/Plan | list selection | list selection | open list shown, then Scheduled ID typed |
| replace Scheduled/Plan | selected object local action | selected object local action | Scheduled ID typed, then source shown |
| Capacity endpoints | visible Entitlement state | visible section/workspace | purpose token typed |

### Finding TR-ID01

Current LOAM is already better than a raw-ID CLI in several places:

- correction uses numbered candidate selection,
- movement entry can use known loci as prompt hints.

But Scheduled workbench still has a particularly avoidable mismatch:

> the object is visible, yet the user must retype its internal identity to act on it.

This should be one of the first TUI dogfood targets.

---

# 12. Date-context matrix

| Operation | HRA | h-kernel | current LOAM CLI |
|---|---|---|---|
| ordinary Actual | selected Home day | selected Home day | prompt inside command |
| past Actual | navigate/select day | navigate/select day | type ISO date |
| Plan/Scheduled completion | Home selected day can seed Actual | selected-day context preserved | completion flow asks/derives through CLI draft path |
| allocation movement | Home focus day defaults date | context-dependent | today default, editable prompt |
| Scheduled replacement | Plan/object context | object context | replacement date defaults old Scheduled date |

### Finding TR-DATE01

HRA's strongest date affordance is not “calendar looks nice”.

It is that **selected time becomes reusable interaction context across domains**.

This lowers R-DATE without turning date into hidden authority because the chosen day stays visible on Home.

---

# 13. Preview-density matrix

| Operation | HRA | h-kernel | current LOAM |
|---|---|---|---|
| ordinary Actual | compact transaction preview | typed flow/write preview | detailed admission preview |
| reversal/correction | detailed target + inverse | dedicated flow | semantic relation + replacement result |
| Plan/Scheduled completion | staged Plan then Actual preview | staged typed flow | completion draft + terminal re-admission |
| allocation movement | rich Current/After + canonical evidence | typed maintenance flow | success/failure, no equivalent rich pre-publish Current/After in CapacityCli |
| Scheduled replacement | lifecycle editor | lifecycle flow | semantically rich relation-first mechanism, interaction preview mostly through prompts/result |

### Finding TR-PREV01

The systems suggest three different preview budgets:

1. **ordinary frequent action**: compact confirmation,
2. **historical correction/lifecycle action**: explicit target/replacement explanation,
3. **rights/allocation action**: before/after state explanation.

LOAM should not use one generic “Are you sure?” dialog everywhere.

---

# 14. Safety vs interaction location

A crucial synthesis is that LOAM's current CLI safety mechanisms are mostly **below** the interaction shell:

- WriterOwnership,
- fresh re-read under ownership,
- relation-first publication where required,
- Event-last authority commit where required,
- exact balanced movement admission,
- fail-closed replacement graph readers,
- explicit independent routing,
- correction chain admission.

Therefore a flatter HRA-like TUI does **not** require weakening those guarantees.

Candidate architecture:

```text
HRA-like orientation and selection
        |
        v
surface-specific editable draft
        |
        v
LOAM semantic proposal/admission
        |
        v
existing WriterOwnership + fresh re-read
        |
        v
existing qualified publication protocol
        |
        v
fresh observation returned to same human place
```

The UI can become simpler while the publisher remains strict.

---

# 15. Candidate TUI topology A — HRA-derived flat shell

This is only a synthetic candidate.

```text
┌──────────────────────────────────────────────────────────────┐
│ September 2026                         Known through: Sep 6   │
│                                                              │
│ Mo Tu We Th Fr Sa Su                                         │
│     1  2  3  4  5 [6]                                       │
│  7  8  9 10$ 11 12 13                                       │
│ ...                                                          │
├──────────────────────────────────────────────────────────────┤
│ Sep 6                                                       │
│ Recent actual                                                │
│   coffee                 PayPay -> coffee       138 JPY      │
│                                                              │
│ Upcoming                                                     │
│   Sep 10  rent           bank -> rent        50,000 JPY      │
│                                                              │
│ Attention                                                    │
│   none                                                       │
├──────────────────────────────────────────────────────────────┤
│ r record   a actual   s scheduled   c capacity   v views     │
└──────────────────────────────────────────────────────────────┘
```

Key experiment properties:

- selected day is always visible,
- no mandatory section-focus mode,
- frequent domains have direct mnemonic actions,
- deeper views can still open list/workspace surfaces,
- mouse can make calendar/object rows clickable without changing keyboard topology.

Do not treat the letters above as final vocabulary.

---

# 16. Candidate object-local Scheduled trace

Current CLI:

```text
show list
 -> choose `e`
 -> type `scheduled-7`
 -> replacement flow
```

Candidate TUI:

```text
Scheduled list
  > Sep 10 [scheduled-7] bank -> rent 50000
    Sep 15 [scheduled-9] bank -> phone 3000

  e

Replacement
  Date   [2026-09-10]
  From   [bank]
  Amount [50000]
  To     [rent]

  Preview:
    current source: scheduled-7
    new Scheduled identity: chosen only at admission
    replacement does not imply continuation
    routing for replacement is independent

  Enter publish / Esc cancel
```

The internal ID remains visible for provenance, but it is **not a field the human must remember**.

This distinction should become standard:

> visible identity is useful; recalled identity is often unnecessary.

---

# 17. Candidate correction trace

Current CLI already gives a numbered list. A TUI can go further by initiating correction from where the user discovers the mistake.

```text
Actual history
  > Sep 5  coffee   PayPay -> coffee  138

  c

Correct selected Actual
  Original
    Sep 5  PayPay -> coffee 138

  Replacement draft
    Date   [Sep 5]
    From   [PayPay]
    To     [coffee]
    Amount [138]

  semantic note:
    original is retained
    correction changes effective projection

  Enter preview/publish
```

This is an interaction wrapper around existing LOAM correction semantics, not a destructive edit.

---

# 18. Candidate capacity trace

HRA-inspired decision support:

```text
Capacity
  unallocated   12,000 JPY
  food          10,000 JPY
  books          2,000 JPY

Move capacity
  From    [unallocated]
  To      [books]
  Amount  [2000]
  Date    [Sep 6]

Before                 After
unallocated  12,000    10,000
books         2,000     4,000

Enter publish / Esc cancel
```

LOAM would still retain only the already-qualified Capacity movement/effective evidence.

The before/after view is projection, not new authority.

---

# 19. What the HRA preference now tells us

The user's preference is more informative after the structural comparison.

It does **not** currently imply:

- Curses is better than Brick,
- HRA domain model is better than LOAM,
- every HRA screen should return,
- one general posting editor is always superior,
- Issues/Entitlement should be copied as concepts.

It does provide meaningful evidence for these hypotheses:

1. stable selected-day orientation is valuable,
2. direct mnemonic paths can beat generalized focus shells for repeated keyboard use,
3. object-local actions reduce target re-identification,
4. ambient local help reduces shortcut recall,
5. preview should be proportional to semantic risk,
6. prefilled drafts reduce re-entry without weakening provenance,
7. preserving place after fresh reload matters,
8. human-visible state graph depth is an important usability metric.

---

# 20. First candidate metric set for synthetic dogfood

For every scenario, record:

### Navigation

- `N_pf`: number of presentation-focus transitions
- `N_surface`: number of surface changes
- `N_target`: target-selection operations

### Recall

- `N_id`: internal IDs typed from memory
- `N_date`: dates typed from memory
- `N_token`: domain tokens typed rather than selected

### Semantic work

- `N_semantic`: genuine user decisions
- `N_inference`: system inferences requiring review

### Publication

- `N_preview`: explicit draft/preview boundaries
- `D_cancel`: interaction distance from current point to safe cancel
- `D_correct`: interaction distance from discovering a mistake to correction draft

### Continuity

- selected day retained? yes/no
- selected object retained? yes/no
- previous scroll/list location retained? yes/no
- fresh canonical reload after write? yes/no

### Honesty

- unknown distinct from zero? yes/no
- failure distinct from empty? yes/no
- retained fact distinct from projection? yes/no
- internal identity visible when useful? yes/no
- internal identity required from memory? yes/no

No aggregate “usability score” should be invented until repeated dogfood shows how these dimensions should be weighted.

---

# 21. Research outcome of this pass

The comparison changes the design question.

Before:

> Should LOAM copy HRA, h-kernel, or another finance UI?

After:

> Can LOAM keep its current strict semantic/publication machinery while minimizing presentation-state navigation, using a stable time/object context similar to the parts of HRA that were actually pleasant to use?

That is a much smaller and more testable question.

---

# 22. Next experiment

The next useful artifact should be a **synthetic trace scorecard**, not production TUI code.

Run at least these four candidate shells on the same scenario corpus:

1. current LOAM CLI,
2. HRA-derived flat TUI topology,
3. h-kernel-derived section/focus topology,
4. command-palette/intent-first topology.

The first target scenario set should be:

- ordinary purchase today,
- purchase three days ago,
- correct discovered Actual,
- complete Scheduled as Actual,
- replace Scheduled,
- move Capacity.

Only after these traces show a repeated winner should LOAM earn a TUI shell implementation.
