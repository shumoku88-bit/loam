# LOAM Interaction Atlas — Transaction Entry Catalog

Date: 2026-09-06  
Status: **research catalog; no entry flow selected**  
Parent: `LOAM_INTERACTION_ATLAS.md`

---

## 0. Question

How should a person tell LOAM that something happened?

This catalog compares entry patterns across CLI, TUI, GUI/Web, ChatGPT, and possible Mobile surfaces before selecting a flow.

The target is not “fewest fields at any cost”. The target is:

> the smallest interaction that captures the real-world distinction without inventing semantic evidence.

Entry UI must separate three concerns:

1. **draft convenience** — defaults, templates, recognition, calculation,
2. **semantic proposal** — what LOAM believes the user is asking to publish,
3. **publication** — re-read/admit/write under the appropriate authority and fail closed if state changed.

A default may be convenient without becoming evidence.

---

# 1. Entry dimensions

A generic finance form usually presents some subset of these fields. LOAM should not assume they all belong to one universal transaction object.

| Dimension | Human question | Can often default? | Risk if silently inferred |
|---|---|---:|---|
| Date/time | When did it happen? | yes, draft only | wrong temporal evidence |
| Quantity | How much moved? | sometimes from source evidence | wrong exact fact |
| Source locus | Where did it come from? | recent/default suggestion | wrong physical movement |
| Destination locus | Where did it go? | suggestion | wrong physical movement |
| Purpose/routing | What was it for? | suggestion | manufactured classification authority |
| Counterparty/payee | Who was involved? | recognition | mistaken identity |
| Description/memo | How should human remember it? | template | accidental identity authority |
| Relation | Is it a refund/replacement/match/settlement? | rarely | false durable relation |
| External evidence | What source observed it? | imported | loss of provenance |
| Schedule relation | Was it expected? | proposal | false realization/match |
| Issue relation | Does it resolve an open issue? | proposal | false lifecycle closure |
| Allocation effect | How should capacity change? | derived/action-specific | conflating reality and planning |

---

# 2. Existing entry archetypes

## E-01 Account-first register — Actual Budget

Actual starts manual entry from an account register. `Add New` creates a row in that account; Payee and Category are dropdown-backed fields. Account context removes one source-selection decision from ordinary entry. Keyboard shortcuts include Tab/Shift-Tab navigation and Ctrl-Enter to add/close a transaction.

Strengths:

- account is already known,
- dense expert workflow,
- nearby running balance and transaction history provide context,
- dropdowns support recognition over recall.

Risks for LOAM:

- makes “which account am I editing?” the dominant first question,
- purpose/category can look structurally equivalent to physical account even when semantics differ,
- difficult for chat entry where the conversation may start from the event rather than an account.

Sources:
- https://actualbudget.org/docs/tour/accounts/
- https://actualbudget.org/docs/getting-started/tips-tricks/
- https://actualbudget.org/docs/transactions/importing/

## E-02 Amount-first + transaction-type choice — YNAB 2026

Current YNAB mobile entry offers Add Transaction from Home, Plan, Spending, account registers, widgets, app icon shortcuts, and category long-press. The main flow begins with amount, then asks for transaction type: Spending, Inflow, Credit Card Payment, or Transfer. Spending/Inflow then expose payee, category, account, flag, cleared state, and schedule options. Transfer/Card Payment omit payee/category.

Strengths:

- amount is often the easiest fact to recall at point of purchase,
- human-facing transaction kinds alter which questions are needed,
- entry can begin from many contexts and prefill context-specific fields,
- shortcuts/widgets can prefill repeated information.

Risks for LOAM:

- four UI types can become an ontology even if underlying semantics are smaller/different,
- amount-first is awkward when the primary task is “move all remaining balance” or non-exact future expectation,
- silent shortcut prefills can become errors if not visibly reviewed.

Sources:
- https://support.ynab.com/en_us/how-to-add-transactions-in-ynab-HyDwA_byi
- https://support.ynab.com/en_us/adding-transactions-without-direct-import-B1kBALVaxx

## E-03 Quick entry vs detailed multi-item entry — Zaim

Zaim explicitly separates two entry routes from Home:

- `かんたん入力` for one simple spending record,
- `記録する` for detailed records including multiple purchased items.

It also supports `よく使う` templates that prefill amount/category, while allowing editing before record.

Strengths:

- progressive disclosure based on actual complexity,
- everyday entry stays cheap,
- multi-item purchases are not forced through the simple form,
- templates reduce repeated recall.

Risks for LOAM:

- two flows can drift semantically if they do not share one application action/admission path,
- “simple vs detailed” must be determined by human need, not separate retained event types,
- template reuse must not copy durable identity/relation evidence.

Sources:
- https://content.zaim.net/manuals/show/9
- https://content.zaim.net/manuals/show/24

## E-04 Calculator + category + source — Money Forward ME

Money Forward ME’s manual mobile flow begins from a pencil action, uses a calculator-style amount input, then category selection and source wallet/account selection. The app strongly complements manual entry with automatic imports.

Strengths:

- numeric entry optimized for touch,
- explicit source selection remains visible,
- category hierarchy supports recognition.

Risks for LOAM:

- category hierarchy may dominate purpose semantics,
- imported sources and manual sources have different edit restrictions,
- user can learn two different authority models depending on source.

Source:
- https://support.me.moneyforward.com/hc/ja/articles/4406429692569

## E-05 Ledger/register keyboard sequence — GnuCash

GnuCash’s primary entry path is direct in an account register. The cursor starts on Date. Tab advances through Num, Description, Transfer account, reconcile state, and amount. Description/account fields auto-complete. Enter finishes editing; Cancel clears the not-yet-recorded transaction. Existing similar descriptions can prefill transfer account.

Strengths:

- extremely efficient after learning field order,
- visible register context,
- keyboard-first recognition/autocomplete,
- explicit Cancel while draft is uncommitted.

Risks for LOAM:

- user must internalize ledger field order and account ontology,
- auto-completing transfer account from description can silently assert too much if copied to stronger semantic relations,
- GnuCash can post imbalance to Imbalance-CUR, whereas LOAM should normally reject invalid balanced movement rather than manufacture a balancing destination.

Sources:
- https://www.gnucash.org/docs/v5/C/gnucash-manual/trans-enter.html
- https://www.gnucash.org/docs/v5/C/gnucash-manual/gui-acct-reg.html

---

# 3. LOAM archaeology — current entry pressure

Current LOAM practical entry already contains several useful constraints.

## L-01 Balanced movement is collected before durable Event publication

`Loam/MovementEntry.lean` collects movement effects from known loci. The movement shape is admitted before it can become durable evidence.

## L-02 Scheduled realization uses editable defaults, not silent inheritance

`collectMovementEffectsWithDefaults` lets an interactive caller keep old Scheduled movement values, but redirected/scripted input must remain explicit. This is a strong distinction between **human convenience** and **machine-call authority**.

Repository evidence:
- `Loam/MovementEntry.lean`
- `Loam/Cli/ScheduledCli.lean`
- `Loam/Cli/ScheduledReplacementCli.lean`

## L-03 Movement draft does not infer unrelated relations

Current Movement CLI intentionally collects optional overlays separately and does not infer discharge target from endpoint, sign, label, or amount shape.

Repository evidence:
- `Loam/Cli/MovementCli.lean`

## L-04 Publication should follow current WriterOwnership discipline

A future GUI/TUI/chat adapter should prepare a human-readable draft before locking when possible, then re-read relevant state under writer ownership before admitting/publishing. A stale UI model must not overwrite newer canonical facts.

This is an architectural requirement for all surfaces, not a CLI peculiarity.

---

# 4. Entry scenario suite

The same scenarios should be synthetic-dogfooded across every candidate surface.

## S1 — Simple purchase

```text
2026-09-05
PayPay → coffee
¥138
```

Questions:

- how quickly can date/source/purpose be selected?
- can recent PayPay/coffee be suggested without silently becoming authority?
- is exact movement preview obvious?

## S2 — Purchase with multiple purposes

```text
PayPay pays ¥2,470 total
Books                  ¥1,750
Shipping                 ¥720
```

Questions:

- is one physical payment visually preserved?
- can the two purpose/burden components be edited without making two payments?
- is exact remainder visible?

## S3 — Wallet charge

```text
SMBC → PayPay
¥3,000
```

Questions:

- does user need to know the word `transfer`?
- does UI clearly say this does not create spending/income?
- if imported evidence later arrives, can it be related without duplicate economic movement?

## S4 — Shared transport cost

```text
You pay fare
Friend later sends half to PayPay
```

Questions:

- can physical payment and household burden remain distinct?
- can UI refrain from offering a fake “income” classification for reimbursement?
- if claim/settlement semantics are not yet earned, does UI avoid pretending to support them?

## S5 — Refund

```text
Merchant returns part of previous purchase
```

Questions:

- can original purchase be selected by recognition rather than ID?
- does refund remain different from correction?
- can destination account differ from original source?

## S6 — Scheduled realization

```text
Scheduled electricity ¥4,800
Actual payment ¥5,100
```

Questions:

- are old expected values useful editable defaults?
- is difference visible before write?
- does Actual remain independent evidence rather than rewriting Scheduled?

## S7 — Reschedule

```text
Rent expected 9/10
Move occurrence to 9/12
```

Questions:

- can the user say “reschedule” while LOAM publishes replacement evidence?
- is fresh Scheduled identity hidden from routine interaction but available in provenance?
- is routing independence visible when it matters?

## S8 — Correction after publication

```text
Recorded ¥638
Reality was ¥500 tobacco + ¥138 coffee
```

Questions:

- does “fix” clearly differ from deleting history?
- can semantic before/after be previewed?
- can provenance be opened on demand?

## S9 — Manual then imported evidence

```text
Manual: PayPay ¥2,470 books
Later import: PAYPAY ¥2,470 one day later
```

Questions:

- does UI suggest relation with rationale?
- can ambiguity be rejected?
- does imported date/source evidence overwrite or relate?

## S10 — Reconcile mismatch

```text
External bank balance differs by ¥1,000
```

Questions:

- does entry UI first help inspect difference?
- is “create adjustment” clearly evidence creation rather than discovered reality?

---

# 5. Surface flow candidates

These are experiment scripts, not selected designs.

## CLI candidate

### Explicit command mode

```text
loam record actual \
  --date 2026-09-05 \
  --from paypay \
  --to coffee \
  --amount 138 \
  --commodity JPY
```

Strength:
- scriptable and auditable.

Risk:
- long for daily human use.

### Interactive intent mode

```text
$ loam record
What happened?
> Paid / received / moved / scheduled / other

Amount: 138
From:   PayPay
For:    coffee
Date:   today (2026-09-06)

PayPay -138 JPY
coffee +138 JPY

[record / edit / cancel]
```

Research questions:

- should CLI expose application verb `record` or lower-level `movement`?
- how many defaults are safe?
- can expert flags and novice prompts enter the same draft/admission function?

## TUI candidate

```text
┌ Record Actual ─────────────────────────────┐
│ Date        2026-09-06                     │
│ From        PayPay                    ▼    │
│ Amount      138                            │
│ Purpose     coffee                    ▼    │
│ Memo                                        │
├─────────────────────────────────────────────┤
│ Preview                                     │
│ PayPay             -138 JPY                 │
│ coffee             +138 JPY                 │
│                                             │
│ Enter Record   Esc Cancel   Tab Next        │
└─────────────────────────────────────────────┘
```

Candidate qualities:

- picker lists, not ID recall,
- visible focus,
- keyboard-only completion,
- mouse optional,
- live preview,
- advanced detail hidden until requested.

Risk:
- a universal form could become an accidental domain model.

## GUI/Web candidate

Two possible modes:

### Quick sheet

```text
Amount      ¥138
Paid from   PayPay
For         coffee
Date        Today

[More details]          [Record]
```

### Relationship/detail inspector

Use only when needed for split/refund/matching/correction:

```text
Physical movement
  PayPay → merchant / purpose ...

Purpose routing
  ...

Related evidence
  ...

Publication preview
  ...
```

Principle:

> progressive disclosure should hide complexity, not hide meaning.

## ChatGPT candidate

Conversation may already contain fields the user naturally supplied.

User:

```text
今日PayPayで138円の缶コーヒー買った
```

Assistant/app proposal:

```text
記帳案

日付       2026-09-06
支払元     PayPay
用途       coffee
金額       ¥138

PayPay  -¥138
coffee  +¥138

[記帳] [編集] [詳しく見る]
```

Rules:

- natural language is an **intent source**, not canonical evidence by itself,
- materially ambiguous source/destination/amount must not be guessed into a write,
- established contextual defaults may be offered as visible suggestions,
- approval card should expose exactly what will be published at human semantic level,
- adapter must call the same application admission/write path as other surfaces.

## Mobile candidate

Potential order:

```text
1. amount keypad
2. source / purpose recent choices
3. date visible as Today
4. Save
```

Long press / recent template may prefill common combinations.

For complex operations, mobile should route into a structured editor rather than attempting a one-screen universal form.

---

# 6. First-question experiments

The first question strongly shapes mental model. Test at least these.

## FQ-A — What happened?

```text
Paid
Received
Moved money
Future payment
Correct something
```

Pros:
- human language,
- flow can ask only relevant fields.

Cons:
- UI verbs may become pseudo-domain types,
- shared/refund/card cases may fit multiple choices.

## FQ-B — Amount first

```text
¥ ______
```

Pros:
- excellent point-of-purchase touch flow,
- demonstrated by YNAB/Money Forward.

Cons:
- weak for corrections, reconciliation, unknown future amounts, non-monetary relations.

## FQ-C — Source account/locus first

```text
PayPay
SMBC
Cash
...
```

Pros:
- narrows candidates and gives balance context,
- proven by register-centric tools.

Cons:
- user may think in purchase rather than account,
- chat flow rarely starts this way.

## FQ-D — Purpose first

```text
coffee
food
books
...
```

Pros:
- strong when entering from budget/priority context.

Cons:
- purpose does not determine physical movement,
- encourages category-first accounting ontology.

## FQ-E — Free-form intent first

```text
> 今日PayPayで本を2470円買った。送料720円。
```

Pros:
- natural and information-dense,
- ideal ChatGPT surface.

Cons:
- requires structured review,
- ambiguous language cannot be direct write authority.

Likely conclusion: **different surfaces may begin differently while converging on the same semantic proposal**.

---

# 7. Defaulting policy candidates

Defaults reduce input but are a common source of silent error.

| Field | Candidate default | Required presentation |
|---|---|---|
| Date | today/local date | always visible before publish |
| Commodity | household default JPY | visible if multiple commodities possible |
| Source locus | recent/frequent suggestion | never silently chosen for script/API |
| Purpose | recent matching suggestion | visibly suggested, not inferred authority |
| Description | prior text/template | editable, never identity evidence |
| Scheduled values | previous expectation | interactive-only editable defaults |
| Split remainder | calculated | exact preview, cannot publish nonzero remainder |
| Counterparty | recent match | suggestion only |
| Relation target | candidate match | must be explicitly approved when durable |

### DP-01 Scripted callers are stricter than interactive humans

A CLI script, ChatGPT tool call, or external adapter must not depend on hidden “press Enter to keep old value” conventions unless the structured call explicitly carries that intent.

Current LOAM Scheduled input already provides useful precedent: interactive defaults exist while redirected input remains explicit.

### DP-02 Remembered convenience is not remembered semantics

The UI may remember that PayPay was most recently used. It must not remember “coffee always comes from PayPay” as a semantic rule unless an explicit automation/routing rule exists.

---

# 8. Validation and feedback

## Before publication

Surface should expose the relevant invariant rather than merely disable a button mysteriously.

Examples:

```text
Movement balanced ✓
Split remainder   ¥0 ✓
Referenced locus  known ✓
Replacement graph valid ✓
```

For failure:

```text
Cannot record yet
Split items total ¥2,400, but payment is ¥2,470.
Remaining: ¥70

[Add remainder] [Edit amount]
```

## After publication

Success feedback should answer:

1. what was recorded,
2. what changed visibly,
3. where to inspect provenance/correct it.

Example:

```text
Recorded
PayPay -¥138 · coffee

Current PayPay balance: ¥8,224
[View event] [Correct]
```

Do not require users to interpret a commit/persistence ID as the primary success signal.

---

# 9. Draft, cancel, correction

Entry lifecycle should distinguish:

| State | Meaning | Durable? |
|---|---|---:|
| Form/draft | user is still composing | no |
| Proposal | validated semantic preview | normally no |
| Publication | canonical evidence admitted/written | yes |
| Correction | later evidence that prior publication was wrong | yes |
| Economic reversal/refund | reality changed after valid event | yes |

Consequences:

- `Esc`/Cancel before publication should simply abandon draft.
- “Undo” after publication cannot be assumed equivalent to draft cancel.
- navigation away from an unfinished form may need discard confirmation only when real work would be lost.
- crash recovery should follow publication semantics rather than autosaving every keystroke into canonical state.

---

# 10. Entry ergonomics baseline

## Keyboard

- Tab / Shift-Tab predictable focus movement.
- Enter must have one contextually predictable meaning.
- Esc cancels/closes transient interaction where safe.
- shortcuts should target application actions, not field internals only.
- focus must remain visible.
- dropdown/pickers should filter incrementally.

Actual and GnuCash both demonstrate highly efficient keyboard paths, but also show why key semantics need careful consistency: GnuCash Tab and Enter have materially different transaction-commit behavior.

Sources:
- https://actualbudget.org/docs/getting-started/tips-tricks/
- https://www.gnucash.org/docs/v5/C/gnucash-manual/trans-enter.html

## Touch

- numeric amount should use suitable keypad,
- recent/frequent choices reduce deep picker navigation,
- touch targets must not be tiny,
- swipe/long-press can accelerate but must have visible alternatives,
- date/category/source defaults should remain visible.

## Mouse

- direct row/form editing is efficient,
- hover-only essential actions should be avoided,
- drag-only allocation should have keyboard/button alternative.

## Chat

- use conversation context to reduce repetition,
- show structured proposal when a write is consequential,
- ask only for ambiguity that changes semantics,
- do not expose internal IDs unless requested or needed for disambiguation.

---

# 11. Entry efficiency measurement

Synthetic dogfood should record measurements rather than rely on aesthetic preference.

| Metric | Definition |
|---|---|
| Inputs | keys/taps/clicks required |
| Decisions | choices the human must consciously make |
| Recall items | facts/IDs the human must remember rather than recognize |
| Focus travel | fields/panes crossed |
| Corrections before publish | backtracks caused by form order/defaults |
| Time-to-preview | interaction until semantic consequence is visible |
| Time-to-publish | interaction until admitted write completes |
| Error visibility | whether invalid state is explained |
| Recovery distance | interactions required to correct a just-published mistake |
| Ambiguity exposure | whether unresolved inference is visible |
| Provenance reach | interactions from success to underlying evidence |

Do not optimize only `Inputs`. A three-tap flow that guesses the wrong account is worse than a four-tap truthful flow.

---

# 12. Synthetic dogfood matrix

Every surface prototype should run the same scenario suite.

| Scenario | CLI | TUI | GUI | Chat | Mobile |
|---|---|---|---|---|---|
| S1 simple purchase | measure | measure | measure | measure | measure |
| S2 multi-purpose purchase | measure | measure | measure | measure | measure |
| S3 wallet charge | measure | measure | measure | measure | measure |
| S4 shared cost | semantics first | semantics first | semantics first | semantics first | semantics first |
| S5 refund | measure | measure | measure | measure | measure |
| S6 schedule realization | measure | measure | measure | measure | measure |
| S7 reschedule | measure | measure | measure | measure | measure |
| S8 correction | measure | measure | measure | measure | measure |
| S9 import match | batch | queue | compare | explain | review |
| S10 reconcile | expert | strong | strong | guide | secondary |

If LOAM lacks earned semantics for a scenario, the result should be **unsupported / research needed**, not a fake UI completion.

---

# 13. Candidate cross-surface architecture

Research hypothesis only:

```text
surface input
    │
    ▼
Draft / Intent
    │
    ▼
Application-specific preparation
    │
    ▼
Semantic Preview
    │
    ├── cancel/edit
    │
    ▼
WriterOwnership / fresh re-read
    │
    ▼
Admission
    │
    ▼
Publication
    │
    ▼
Structured Result
```

Important caution:

Do **not** prematurely create a universal `ActionProposal` framework just because every surface needs some notion of preview. Existing LOAM should first reveal which preparation/admission mechanics are genuinely shared.

The architecture target is shared semantics, not maximum abstraction.

---

# 14. Early design candidates

### TE-01 Fast path + expandable detail

Ordinary entry should expose only the fields earned by the selected human action. Complex relations appear only when relevant.

### TE-02 Recognition-first locus/purpose selection

List/filter known human labels. Durable IDs remain inspectable metadata.

### TE-03 Live semantic preview

Show movement/effect while editing, especially for splits, movement, correction, and replacement.

### TE-04 Draft defaults are visually distinguishable

A value filled by context/recent history should still be visible and editable before publish.

### TE-05 Script/API mode is explicit

Automation should not inherit interactive ambiguity-resolution shortcuts.

### TE-06 One publication path per semantic action

CLI, TUI, GUI, ChatGPT, and mobile adapters should not each reimplement validation/writer mechanics.

### TE-07 No universal “transaction type” until earned

UI verbs may guide entry, but retained LOAM meaning should remain based on the smallest qualified semantics.

### TE-08 Correction is an entry flow too

Recovery should be as discoverable as creation, not buried in maintenance menus.

### TE-09 Provenance after success, not before every simple write

Routine capture can stay compact while `Why? / View evidence` remains one step away.

### TE-10 Fast does not mean silent

A one-tap template or chat proposal is acceptable only when the resulting semantic proposal is predictable.

---

# 15. What to prototype later

After the catalog and semantic mapping mature, create **non-canonical** prototypes for:

1. simple purchase,
2. move money,
3. split purchase,
4. Scheduled realization,
5. Scheduled replacement,
6. correction,
7. imported-evidence match.

For each, implement only enough surface to measure the matrix above. Do not publish to household canonical data until the interaction is understood.

---

# 16. Next research queue

1. Deep-excavate HRA Actual/Plan entry key flows.
2. Deep-excavate h-kernel Brick TUI field/focus/event flows.
3. Study receipt/camera/OCR workflows for possible mobile capture, without assuming OCR belongs in LOAM core.
4. Study autocomplete and command-palette research for keyboard/TUI use.
5. Study form error recovery and interruption/resumption.
6. Study voice/chat correction behavior when intent extraction is wrong.
7. Build a first quantitative synthetic-dogfood worksheet from S1–S10.
8. Then compare candidate navigation with the Home & Attention catalog.

---

# 17. Source index

- Actual account register: https://actualbudget.org/docs/tour/accounts/
- Actual importing/manual add: https://actualbudget.org/docs/transactions/importing/
- Actual shortcuts: https://actualbudget.org/docs/getting-started/tips-tricks/
- YNAB Add Transactions (2026): https://support.ynab.com/en_us/how-to-add-transactions-in-ynab-HyDwA_byi
- YNAB without Direct Import: https://support.ynab.com/en_us/adding-transactions-without-direct-import-B1kBALVaxx
- Zaim basic entry: https://content.zaim.net/manuals/show/9
- Zaim frequent templates: https://content.zaim.net/manuals/show/24
- Money Forward ME manual entry: https://support.me.moneyforward.com/hc/ja/articles/4406429692569
- GnuCash direct register entry: https://www.gnucash.org/docs/v5/C/gnucash-manual/trans-enter.html
- GnuCash account register: https://www.gnucash.org/docs/v5/C/gnucash-manual/gui-acct-reg.html

Repository archaeology:

- `shumoku88-bit/loam/Loam/MovementEntry.lean`
- `shumoku88-bit/loam/Loam/Cli/MovementCli.lean`
- `shumoku88-bit/loam/Loam/Cli/ScheduledCli.lean`
- `shumoku88-bit/loam/Loam/Cli/ScheduledReplacementCli.lean`
- `shumoku88-bit/h-kernel/editor-src/HKernel/Editor/ActualAppend.hs`
- `shumoku88-bit/hra`

---

> The fastest entry is not the form with the fewest fields. It is the flow that reaches the correct, reviewable semantic proposal with the least unnecessary thought.
