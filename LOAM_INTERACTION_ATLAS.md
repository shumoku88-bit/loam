# LOAM Interaction Atlas — Research Catalog v0.1

Date: 2026-09-06  
Status: **Research catalog, not UI specification**  
Scope: CLI / TUI / GUI-Web / ChatGPT in-chat UI / possible Mobile

Companion shards:

- `LOAM_INTERACTION_ATLAS_DIFFICULT_OPERATIONS.md` — transfer, card, points, refunds, shared costs, splits, schedules, import matching, correction, reconciliation

---

## 0. Purpose

This document catalogs the interaction design space before LOAM commits to a UI.

The goal is **not** to copy HRA, h-kernel, or an existing budgeting product. Instead:

1. catalog what humans actually try to do with household money,
2. observe how existing software exposes those goals,
3. study navigation, representation, error/recovery, and human factors,
4. map the observations onto LOAM semantics,
5. only then design surface-specific flows,
6. synthetic-dogfood the flows before committing to implementation.

A feature appearing in this atlas is **not** a request to implement it.

---

# 1. Planned LOAM Surfaces

| Surface | Primary role | Strong at | Weak at / risk |
|---|---|---|---|
| CLI | canonical minimal action surface; scripting; AI adapter | exactness, composability, automation, testing | discoverability, overview |
| TUI | daily keyboard-first household use | speed, focus, low-latency navigation, dense information | touch, rich visualization |
| GUI / Web | inspection, visualization, drill-down, mouse interaction | overview, comparison, explainability, graphs | complexity creep |
| ChatGPT in-chat UI | natural-language intent → review → action | low input burden, conversational explanation, contextual capture | write availability / platform constraints, ambiguity |
| Mobile | possible independent quick-capture surface | point-of-event entry, camera, notifications, touch | dense editing, deep investigation |

Working hypothesis: the surfaces should share **application-level semantic actions**, not independently reinvent household accounting semantics.

---

# 2. Atlas Record Schema

Each observation should eventually record:

| Field | Meaning |
|---|---|
| Human Goal | What the person is trying to accomplish |
| Trigger | What happened in the real world |
| Frequency | many/day, daily, weekly, monthly, rare |
| Existing Product | observed software |
| Entry Point | where the flow begins |
| Interaction | concrete steps |
| Representation | how facts/state are shown |
| Required Recall | what the user must remember |
| Feedback | what confirms success or failure |
| Error Prevention | constraints / preview / confirmation |
| Recovery | undo / correction / reversal / re-edit |
| Provenance Visibility | whether the origin of a value can be understood |
| Automation | automatic / suggested / approved / manual |
| Surface | desktop, mobile, TUI, CLI, chat |
| LOAM Mapping | candidate semantic concept(s) |
| Copy? | yes/no/unknown |
| Research State | observed / partial / todo |
| Implementation State | deliberately separate from research |

---

# 3. Human Goal Catalog v0.1

## A. Capture and record

| ID | Human goal |
|---|---|
| CAP-001 | Record a purchase paid from one account |
| CAP-002 | Record income received |
| CAP-003 | Record money received that is not ordinary income |
| CAP-004 | Record a transaction with multiple purposes/categories |
| CAP-005 | Record fees separately from the purchased item |
| CAP-006 | Record tax separately from base amount |
| CAP-007 | Record a receipt quickly at the point of purchase |
| CAP-008 | Record a past transaction discovered later |
| CAP-009 | Record an amount before full details are known |
| CAP-010 | Add a note / memo / evidence |
| CAP-011 | Reuse a previous transaction as a starting point |
| CAP-012 | Record several similar transactions quickly |
| CAP-013 | Record with keyboard only |
| CAP-014 | Record with touch only |
| CAP-015 | Record through natural-language conversation |

## B. Money movement

| ID | Human goal |
|---|---|
| MOV-001 | Move money between owned accounts |
| MOV-002 | Represent cash withdrawal |
| MOV-003 | Represent cash deposit |
| MOV-004 | Charge an e-money / wallet balance |
| MOV-005 | Pay a credit-card balance without double-counting expense |
| MOV-006 | Move money through an intermediate wallet/account |
| MOV-007 | Represent a transfer fee alongside a transfer |
| MOV-008 | Identify two externally imported records as one real-world movement |
| MOV-009 | Correct the destination/source of a movement |
| MOV-010 | Understand why a movement changed balances but not spending |

## C. Shared costs, reimbursements, returns

| ID | Human goal |
|---|---|
| SHR-001 | Pay a shared expense initially |
| SHR-002 | Record another person's reimbursement |
| SHR-003 | Split burden without pretending physical payments were separate |
| SHR-004 | Record a merchant refund |
| SHR-005 | Record partial refund |
| SHR-006 | Track money expected back |
| SHR-007 | Close an expected reimbursement when received |
| SHR-008 | Distinguish reimbursement from income |

## D. Scheduling and future obligations

| ID | Human goal |
|---|---|
| SCH-001 | Record a known future payment |
| SCH-002 | Record known future income |
| SCH-003 | Record a repeating obligation |
| SCH-004 | Record a one-time future obligation |
| SCH-005 | View what is due soon |
| SCH-006 | View future obligations on a calendar |
| SCH-007 | Change only the next occurrence |
| SCH-008 | Change all future occurrences |
| SCH-009 | Postpone an occurrence |
| SCH-010 | Advance an occurrence |
| SCH-011 | Change expected amount |
| SCH-012 | Cancel one occurrence |
| SCH-013 | End a repeating series |
| SCH-014 | Realize a scheduled item as an Actual |
| SCH-015 | Match an Actual/imported transaction to a schedule |
| SCH-016 | Skip a scheduled date without destroying the schedule |
| SCH-017 | Mark expected amount as approximate or ranged |
| SCH-018 | Distinguish an obligation with a date from flexible planned spending |
| SCH-019 | See why an item is considered upcoming |
| SCH-020 | Recover safely from interrupted schedule editing |

## E. Budgeting / capacity / allocation

| ID | Human goal |
|---|---|
| BUD-001 | Decide how much is available to spend |
| BUD-002 | Assign available resources to a purpose |
| BUD-003 | Move allocation between purposes |
| BUD-004 | Return unused allocation |
| BUD-005 | Preserve unused allocation into a future period |
| BUD-006 | Save gradually for an irregular future expense |
| BUD-007 | Cover overspending from another purpose |
| BUD-008 | Compare budget/target with actual spending |
| BUD-009 | Separate fixed commitments from flexible spending |
| BUD-010 | Separate dated commitments from undated spending intentions |
| BUD-011 | Understand money already committed by future obligations |
| BUD-012 | Ask whether spending now threatens known future obligations |
| BUD-013 | View an exact residual / remainder when dividing capacity over days |
| BUD-014 | Change a plan because circumstances changed |
| BUD-015 | Understand what is reserved versus merely projected |

## F. Verification and reconciliation

| ID | Human goal |
|---|---|
| VER-001 | Compare LOAM account balance with an external account |
| VER-002 | Mark a transaction as externally observed/cleared |
| VER-003 | Identify records not yet externally confirmed |
| VER-004 | Reconcile to a statement/date |
| VER-005 | Find the cause of a balance mismatch |
| VER-006 | Detect duplicate records |
| VER-007 | Match manual and imported records |
| VER-008 | See which evidence came from which source |
| VER-009 | Validate the household state before writing |
| VER-010 | Know whether a view is complete, partial, stale, or unknown |

## G. Correction and recovery

| ID | Human goal |
|---|---|
| COR-001 | Fix a typo discovered immediately |
| COR-002 | Correct a past transaction without silently rewriting history |
| COR-003 | Reverse an erroneous economic event |
| COR-004 | Replace a future scheduled event |
| COR-005 | Cancel an unfinished input flow |
| COR-006 | Preview consequences before committing a consequential change |
| COR-007 | Understand exactly what “undo” would affect |
| COR-008 | Recover after process interruption between publications |
| COR-009 | Resolve an invalid or ambiguous state |
| COR-010 | Retry an operation idempotently |
| COR-011 | See the difference between correction and deletion |
| COR-012 | Explain why direct destructive edit is unavailable |

## H. Inquiry, explanation, and reports

| ID | Human goal |
|---|---|
| QRY-001 | What is my balance now? |
| QRY-002 | Where did this balance come from? |
| QRY-003 | What did I spend today / this week / this cycle? |
| QRY-004 | What changed since the previous observation? |
| QRY-005 | What is due next? |
| QRY-006 | How much is committed already? |
| QRY-007 | How much can I safely use? |
| QRY-008 | What is unusual or needs attention? |
| QRY-009 | Search for a past transaction |
| QRY-010 | Filter by account / purpose / date / amount / status |
| QRY-011 | Inspect a single event and all related provenance |
| QRY-012 | Compare periods |
| QRY-013 | See a daily calendar |
| QRY-014 | See monthly / cycle movement |
| QRY-015 | See account-level statements |
| QRY-016 | Explain why a projection has a particular number |
| QRY-017 | Distinguish zero, unknown, absent, not-yet-observed, and not-applicable |
| QRY-018 | Share a screenshot without exposing real amounts |
| QRY-019 | Export a human-readable report |
| QRY-020 | Export machine-readable data |

## I. Issues and attention

| ID | Human goal |
|---|---|
| ISS-001 | Remember a financial issue that is not yet a transaction |
| ISS-002 | Give an issue a due date |
| ISS-003 | Explicitly record that due date is unknown |
| ISS-004 | Track reimbursement / subscription / budget problems |
| ISS-005 | See overdue and near-due items |
| ISS-006 | Close an issue without inventing a financial event |
| ISS-007 | Attach a decision memo |
| ISS-008 | Surface only actionable attention on Home |

## J. Automation and imports

| ID | Human goal |
|---|---|
| AUT-001 | Import transactions from an external source |
| AUT-002 | Let the system suggest a recurring pattern |
| AUT-003 | Approve or reject an inferred schedule |
| AUT-004 | Apply a routing/categorization rule |
| AUT-005 | Review what an automation changed |
| AUT-006 | Prevent automation from silently changing semantic meaning |
| AUT-007 | Resolve duplicate imported evidence |
| AUT-008 | Run the same action through CLI or an AI adapter |
| AUT-009 | Require approval before consequential writes |
| AUT-010 | Know when external sync was last successful |

---

# 4. Existing Product / System Atlas — First Pass

## Actual Budget

Observed patterns:

- Persistent left sidebar: Budget / Reports / Schedules / Accounts, with lower-frequency functions under More.
- Account register is a major action surface.
- Cleared and uncleared balances can be exposed from account header.
- Reconciliation visually distinguishes external confirmation state.
- Schedules can be one-time or recurring, automatic or approval-based.
- Schedule expected amount can be exact, approximate, or a range.
- A future-dated transaction can be converted to a schedule rather than posted as an Actual.
- Upcoming visibility horizon is a presentation setting, separate from stored/calculated meaning.
- Import attempts duplicate matching against manually entered records.
- Split transactions require child totals to equal parent total.
- Numeric scrambling exists for privacy during screenshots/support.

LOAM questions raised:

- Can LOAM represent “expected amount uncertainty” without flattening it into a fake exact amount?
- Should upcoming horizon be pure presentation policy?
- Should external-observation state be separate from economic-event identity?
- Could privacy-scramble be a surface concern over exact canonical facts?

Sources:
- https://actualbudget.org/docs/tour/user-interface/
- https://actualbudget.org/docs/tour/accounts/
- https://actualbudget.org/docs/accounts/reconciliation/
- https://actualbudget.org/docs/schedules/
- https://actualbudget.org/docs/transactions/importing/
- https://actualbudget.org/docs/transactions/split-transactions/

## YNAB

Observed patterns:

- Scheduled transactions live close to account-register transaction entry.
- Mobile flow has a prominent Transaction action.
- Imported transactions can match earlier manual records.
- Repeating scheduled edits distinguish current occurrence vs future occurrences.
- Targets are category-level planning mechanisms, distinct from scheduled transactions.
- “Move Money” is a first-class budget reallocation flow.
- Expert and beginner flows coexist through visible actions plus shortcuts/swipes.

LOAM questions:

- How should Scheduled replacement and continuation be made visually distinct?
- Does LOAM need a first-class “move capacity/allocation” human action even if the underlying retained semantics are smaller?
- Should manual-first then import-match become an explicit provenance relation?

Sources:
- https://support.ynab.com/scheduled-transactions-a-guide-BygrAIFA9
- https://support.ynab.com/en_us/editing-and-deleting-scheduled-transactions-a-guide-Skru9yNJo
- https://support.ynab.com/how-to-use-targets-rk5kkI9ks
- https://support.ynab.com/moving-money-in-your-plan-ryyCKbBJi
- https://support.ynab.com/en_us/approving-and-matching-transactions-a-guide-ByYNZaQ1i

## Quicken Simplifi

Observed patterns:

- Flexible Planned Expenses and dated Recurring Expenses are distinct.
- Spending Plan separates Income, Bills, Planned Spend, Other Spend, Goals, and Left This Month.
- Dated recurring items reduce available spending before payment.
- Linked recurring reminders are excluded from Planned Spend to avoid double-counting.
- Mobile and desktop preserve the same conceptual sections but use surface-specific entry flows.
- Future projection can be disabled, custom, or based on historical averages.

LOAM questions:

- LOAM already has evidence that “dated commitment” and “undated allocation intention” should not be flattened. This product is a useful UI comparison.
- Projection source/assumption should be visible if LOAM ever adds forecasting.

Sources:
- https://support.simplifi.quicken.com/en/articles/5142441-planned-expenses-versus-recurring-expense-transactions
- https://support.simplifi.quicken.com/en/articles/4212702-understanding-your-spending-plan
- https://support.simplifi.quicken.com/en/articles/14982841-how-to-set-up-a-spending-plan-on-the-mobile-app

## Monarch Money

Observed patterns:

- Recurring items can be shown as both calendar and list.
- Recurring calendar uses state cues for upcoming vs paid-as-expected vs amount-different.
- Flex budgeting separates Fixed, Non-Monthly, and Flex spending.
- Recurring schedule view is explicitly described as timing/detail while budget buckets are categorization/planning.
- “Hide transaction” preserves record visibility while excluding it from some calculations.
- Manual transactions in synced accounts have nuanced balance behavior.

LOAM questions:

- Calendar status can communicate observation mismatch without forcing a semantic rewrite.
- “Hidden from projection” needs caution: LOAM should prefer explicit projection policy, not invisible exclusion flags.

Sources:
- https://help.monarch.com/hc/en-us/articles/4890751141908-Tracking-Recurring-Expenses-and-Bills
- https://help.monarch.com/hc/en-us/articles/32125337244052-Understanding-Flex-Budgeting
- https://help.monarchmoney.com/hc/en-us/articles/4405041904916-Hide-Transactions

## Money Forward ME

Observed patterns:

- Mobile bottom navigation emphasizes Home, inflow/outflow history, household-book analysis, and a direct input action.
- Inflow/outflow history has list and calendar views.
- “Transfer” is used for movement that should change balances without counting as spending/income.
- Transfer is also used to prevent double-counting between external sources.
- Some future-date editing differs between mobile and web.
- Imported records can have restrictions on direct modification.

LOAM questions:

- This is a rich catalog of where “transfer” becomes overloaded: physical movement, de-duplication, credit-card settlement, e-money charging.
- LOAM should test whether one human-facing shortcut can map to several explicit semantic relations without hiding which one occurred.
- Surface parity is not automatically desirable: mobile may intentionally expose fewer deep-editing flows.

Sources:
- https://support.me.moneyforward.com/hc/ja/articles/4406430145049
- https://support.me.moneyforward.com/hc/ja/articles/4410966033689
- https://support.me.moneyforward.com/hc/ja/articles/900003465946
- https://support.me.moneyforward.com/hc/ja/articles/900004380163
- https://support.me.moneyforward.com/hc/ja/articles/900004413723

## Zaim

Observed patterns:

- Calendar is both an inspection surface and an entry point.
- Budget can be total-only or category-detailed.
- Budget progress is a dedicated analysis view.
- Transfers are explicitly described as neither expense nor income and change balances.
- Calendar can layer money history with daily notes and other life context.
- Receipt capture is a prominent mobile capture mechanism.

LOAM questions:

- Calendar may be more useful as a temporal navigation surface than as a report.
- The ability to start an event from a selected date is a strong low-recall pattern.
- Household financial UI may benefit from showing “life context” without making the context canonical accounting meaning.

Sources:
- https://zaim.net/
- https://content.zaim.net/manuals/show/20
- https://content.zaim.net/manuals/show/21
- https://content.zaim.net/manuals/show/46
- https://content.zaim.net/manuals/show/74

## GnuCash

Observed patterns:

- The account register is the dominant work surface.
- Transfer, split, schedule, reconcile, duplicate, delete, and jump-to-other-account are register actions.
- Reconciliation distinguishes new, cleared, and reconciled state.
- Scheduled transactions can be built from an existing ledger transaction or from a dedicated editor.
- Scheduled transaction window combines list + upcoming calendar.
- Scheduled entries can be auto-created or review-driven.
- GnuCash explicitly supports reversing transactions as an accounting-style alternative to deletion/editing.

LOAM questions:

- Register-centric design is excellent for experts but may expose internal accounting structure too early.
- Reversal UX is directly relevant to LOAM’s append/history-preserving correction design.
- “Jump to other account” is a useful example of navigating an economic relation rather than a menu hierarchy.

Sources:
- https://www.gnucash.org/docs/v5/C/gnucash-manual/gui-acct-reg.html
- https://www.gnucash.org/docs/v5/C/gnucash-manual/acct-reconcile.html
- https://www.gnucash.org/docs/v5/C/gnucash-manual/trans-sched.html
- https://www.gnucash.org/docs/v5/C/gnucash-guide/chapter_txns.html

## Firefly III

Observed patterns:

- Strong separation of transactions, budgets, recurring transactions/bills, rules, tags, piggy banks.
- Budget period and automation are configurable, with some period limitations.
- REST API covers most of the system and makes automation/integration first-class.
- Rules can automate transaction handling.

LOAM questions:

- Useful comparison for API-first / automation-heavy architecture.
- Important negative case: rich feature taxonomies can become a large ontology; LOAM should test whether fewer semantic primitives can generate equivalent views.

Sources:
- https://docs.firefly-iii.org/how-to/firefly-iii/finances/budgets/
- https://github.com/firefly-iii/firefly-iii

---

# 5. HRA / h-kernel Archaeology — First Pass

## h-kernel TUI

Observed current section taxonomy includes:

- Actual
- Plans
- Entitlement
- Accounts
- Issues
- Reports
- Settings

The TUI also has independently named focusable surfaces such as Home, CalendarDay, Accounts, Issues, Reports, Settings, and section tabs.

Research value:

- It already explored a multi-section household workspace.
- It is useful as a record of what became too concept-heavy or too hidden.
- It should **not** automatically determine LOAM navigation.

## HRA Home

HRA’s current home-presentation layer explicitly transforms semantic home observations into **UI-neutral structured view models**, including:

- monthly calendar grid with attention facts,
- selected-day Actual details,
- selected-day Plan details,
- selected-day Issue details,
- selected-day Cycle details.

Calendar attention includes distinct markers for:

- cycle end,
- plan due,
- issue due,
- multiple simultaneous attention facts.

Research value:

- semantic observation → presentation model → surface rendering is a strong pattern worth retaining as an architectural candidate;
- the exact HRA concepts and navigation are not presumed to be correct for LOAM.

---

# 6. Interaction Pattern Catalog v0.1

| Pattern ID | Pattern | Example | Strength | Risk / LOAM question |
|---|---|---|---|---|
| PAT-001 | Account register as home | GnuCash, Actual | dense, expert-efficient | accounting structure dominates mental model |
| PAT-002 | Dashboard as home | Simplifi | quick situational awareness | can become decorative and non-actionable |
| PAT-003 | Calendar as temporal navigator | Zaim, Monarch, HRA | low recall; time context | calendar can overcrowd meaning |
| PAT-004 | Sidebar object navigation | Actual | predictable | nouns may mirror software internals |
| PAT-005 | Bottom-tab mobile navigation | Money Forward | thumb-friendly | limited top-level slots |
| PAT-006 | Central quick-add action | Money Forward, YNAB | frequent capture is cheap | over-centralizing “record” can hide other goals |
| PAT-007 | Existing transaction as template | GnuCash, Actual | recognition over recall | copy can accidentally copy semantic identity |
| PAT-008 | Manual-first then import-match | Actual, YNAB | fast capture + later evidence | identity/matching must be explicit |
| PAT-009 | List + calendar dual view | Monarch, GnuCash | detail + temporal overview | duplicated controls/state |
| PAT-010 | Upcoming horizon | Actual | focus relevant future | must remain presentation policy |
| PAT-011 | Approve-vs-auto schedule realization | Actual, GnuCash | user control | auto-write semantics must be auditable |
| PAT-012 | Exact/approximate/range expectation | Actual | honest uncertainty | needs proper LOAM semantic representation |
| PAT-013 | Current occurrence vs future series edit | YNAB | matches user intent | must not conflate replacement and continuation |
| PAT-014 | Flexible plan vs dated obligation | Simplifi | strong semantic clarity | UI taxonomy may become too broad |
| PAT-015 | Budget bucket vs schedule | Monarch | separates amount planning/timing | possible duplication if semantic boundary unclear |
| PAT-016 | Move allocation direct manipulation | YNAB | natural recovery from overspending | retained state must preserve history |
| PAT-017 | Reconcile workspace | GnuCash, Actual | focused verification | household users may not understand term “reconcile” |
| PAT-018 | Hidden/excluded transaction | Monarch, MF | handles reporting exceptions | dangerous if projection policy is invisible |
| PAT-019 | Reversing transaction | GnuCash | non-destructive history | must present in everyday language |
| PAT-020 | Split transaction editor | Actual, GnuCash | captures composite purchase | physical payment vs burden/purpose must stay distinct |
| PAT-021 | Calendar-to-new-entry | Zaim | date preselection lowers input | chosen date must remain visible |
| PAT-022 | Suggested recurring pattern | Actual, Monarch | automation reduces entry | suggestion should never become silent authority |
| PAT-023 | Rule-based routing | Actual, Firefly III | removes repetition | automation provenance must remain visible |
| PAT-024 | Privacy scramble | Actual | support/share safely | derived presentation only |
| PAT-025 | Section-specific attention | HRA | actionable Home | danger of alert overload |
| PAT-026 | Pure/UI-neutral presentation model | HRA | multi-surface reuse | avoid premature generic view framework |
| PAT-027 | Abstract key actions → configurable bindings | Brick | expert efficiency | key vocabulary should follow application actions |
| PAT-028 | Model / Msg / update / view | Bubble Tea / LeanTEA | clean state transition model | IO/write boundaries need careful separation |
| PAT-029 | Preview before consequential action | HCI pattern | error prevention | preview must show semantic effect, not raw diff |
| PAT-030 | Chat intent → structured confirmation card | Apps SDK opportunity | low input load + review | model ambiguity and write availability |

---

# 7. Human-Factors Baseline

External baseline:

1. Visibility of system status
2. Match system language to the human world
3. User control and freedom
4. Consistency and standards
5. Error prevention
6. Recognition rather than recall
7. Flexibility and efficiency for novice and expert users
8. Minimal visual/semantic clutter
9. Diagnose and recover from errors
10. Contextual help

LOAM-specific extension candidates:

### LH-01 Semantic honesty
Never display a derived assumption as if it were retained fact.

### LH-02 Provenance reachability
A visible number should have a discoverable path to “why”.

### LH-03 Unknown is not zero
Unknown / unavailable / not observed / not applicable / zero require distinct presentation.

### LH-04 Failure must remain visible
Fail-closed states must not collapse to an empty list or 0.

### LH-05 Predictable correction
A correction/replacement/reversal UI must describe what current meaning will change.

### LH-06 No hidden double-count policy
If two observations represent the same real-world event or one should be excluded from a projection, the relationship/policy must be inspectable.

### LH-07 Recognition-first identity
Humans should select “the 9/10 rent payment” rather than remember `scheduled-17`.

### LH-08 Expert acceleration without semantic fork
Keyboard shortcuts, CLI, TUI, chat, and GUI should accelerate the same application action, not introduce alternate semantics.

### LH-09 Attention is scarce
Home should show facts requiring a decision, not everything that can be computed.

### LH-10 Surface-appropriate disclosure
Mobile/chat can be concise while allowing drill-down to exact provenance elsewhere.

---

# 8. Accessibility / Input Baseline

Research baseline to carry into later wireframes:

- Keyboard focus must remain visibly identifiable.
- Consequential financial/data changes deserve strong error prevention.
- Detected input errors must be described, not merely colored.
- Pointer targets need adequate size/spacing.
- Drag interactions need non-drag alternatives.
- Status messages must be perceivable without hijacking focus.
- Avoid redundant input when the system can safely derive or prefill it.
- Multiple input methods should coexist where appropriate.
- Color must not be the sole carrier of status.

Primary references:
- https://www.w3.org/WAI/WCAG22/Understanding/
- https://developer.apple.com/design/human-interface-guidelines/entering-data
- https://developer.apple.com/design/human-interface-guidelines/undo-and-redo
- https://www.nngroup.com/articles/ten-usability-heuristics/

---

# 9. TUI Framework Research

## Brick

Strong observations:

- state → draw function,
- event + state → state transition,
- declarative layout,
- lists, tables, editors, forms, dialogs, viewports,
- mouse as enhancement rather than required capability,
- customizable keybindings can map concrete keys onto abstract application events.

This is important for a possible “Lean Brick” study: the useful core may be smaller than a giant widget library.

Source:
- https://github.com/jtdaugherty/brick/blob/master/docs/guide.rst

## Bubble Tea

Strong observations:

- The Elm Architecture:
  - Model
  - Init
  - Update
  - View
- production-proven terminal rendering,
- keyboard, mouse, clipboard,
- common component library separate from core.

Source:
- https://github.com/charmbracelet/bubbletea

## Ratatui

Strong observations:

- explicit event loop,
- separate application state/logic and UI rendering is a common template,
- modular crate architecture and large widget ecosystem.

Source:
- https://ratatui.rs/

## LeanTEA

**High-priority research target. Very young, not an adoption decision.**

Current project describes itself as a Lean 4 full-stack Web + TUI framework based on The Elm Architecture:

- Model / Msg / update / view,
- Pure Lean HTTP server and WebSocket client,
- SQLite integration,
- typed RPC,
- an MCP endpoint in example applications,
- Web and TUI runtime under one Lean project.

This is unusually close to the long-term LOAM surface problem:
Lean semantic core + TUI + Web/GUI + MCP/chat boundary.

Risks:

- extremely young ecosystem,
- small user base,
- fast-moving API,
- LOAM should not inherit its persistence or web semantics merely because it is Lean-native.

Source:
- https://reservoir.lean-lang.org/%40Verilean/lean-tea

---

# 10. ChatGPT Surface Research

Current platform observations as of 2026-09-06:

- OpenAI Apps SDK can define both app logic and in-chat interactive UI.
- Apps SDK is built on MCP.
- ChatGPT apps can surface interactive cards/experiences in conversation.
- Custom write/modify MCP support is currently plan/workspace-dependent and still beta.
- A local-only MCP server is not directly connected; supported remote/tunnel deployment considerations matter.

Therefore:

**Do not make ChatGPT write access a prerequisite for the rest of LOAM UI architecture.**

Instead design an adapter boundary now:

```text
natural language
    ↓
intent extraction
    ↓
LOAM application action proposal
    ↓
structured preview
    ↓ explicit approval
LOAM write
    ↓
structured result + provenance link
```

Candidate future in-chat card:

```text
Record purchase

Mathematics books          ¥1,750
Shipping                     ¥720
Paid from                  PayPay
-------------------------------
Total                       ¥2,470

[Review details] [Record]
```

The card is only presentation. The action underneath should be the same semantic application action available through CLI/TUI/GUI.

Primary references:
- https://help.openai.com/en/articles/12515353-build-with-the-apps-sdk
- https://help.openai.com/en/articles/12584461
- https://help.openai.com/en/articles/11487775

---

# 11. Preliminary Surface Matrix

Legend:
- P = primary
- S = strong secondary
- R = rare/admin
- ? = needs research

| Goal | CLI | TUI | GUI/Web | ChatGPT | Mobile |
|---|---:|---:|---:|---:|---:|
| quick Actual entry | S | P | S | P | P |
| complex split entry | S | P | P | S | S |
| transfer / movement | P | P | P | P | P |
| scheduled creation | P | P | P | S | S |
| scheduled edit/replacement | P | P | P | S | S |
| calendar inspection | weak | P | P | S | P |
| capacity / budget overview | S | P | P | S | P |
| detailed provenance | P | P | P | S | weak |
| reconciliation | P | P | P | S | S |
| correction/reversal | P | P | P | S | S |
| reports/comparison | S | P | P | S | S |
| bulk editing | P | P | P | weak | weak |
| automation scripting | P | R | R | S | weak |
| explain “why this number?” | S | P | P | P | S |
| privacy-safe sharing | S | S | P | P | P |

This table is provisional and should be revised after more observation.

---

# 12. Tentative Application Action Vocabulary

**Not an API design yet.**

The research is starting to suggest that surfaces might share actions in families such as:

### Observe
- list current/open items
- inspect event
- inspect account
- explain derived value
- search
- compare

### Record
- record actual movement/event
- record future scheduled movement
- record issue / nonfinancial attention

### Relate
- route purpose
- match evidence
- settle shared cost
- relate replacement
- reconcile external observation

### Change current meaning without destroying history
- correct
- replace scheduled
- retire/cancel
- reverse

### Allocate / capacity
- grant/allocate
- transfer allocation
- return allocation
- inspect capacity

Important: this vocabulary must be derived from existing LOAM semantics rather than forcing LOAM to implement the words above.

---

# 13. Important Early Findings

## Finding A — “Home” is not settled

Existing products choose radically different centers:

- account register,
- budget,
- dashboard,
- calendar,
- transaction feed.

LOAM should not choose its Home until the frequency/attention catalog is complete.

## Finding B — Calendar is stronger than a report

Across consumer apps and HRA, calendar acts as:

- navigation,
- attention,
- due-date display,
- historical recall,
- entry point.

Candidate hypothesis: LOAM calendar may be a **time navigator**, not a “calendar report”.

## Finding C — Movement/transfer is a major UX danger zone

Existing personal-finance software frequently uses “transfer” for several user problems:

- genuine account-to-account movement,
- credit-card settlement,
- wallet/e-money charging,
- duplicate suppression between data sources.

LOAM’s movement semantics may allow a cleaner UI, but only if the UI does not collapse distinct relations into one magical “transfer” flag.

## Finding D — Schedule and budget repeatedly separate in mature products

Several products distinguish:

- **when/what payment is expected**
from
- **how much money is allocated/available**

This independently supports LOAM’s existing refusal to flatten future-event identity and capacity/allocation into one concept.

## Finding E — “Undo” deserves its own LOAM research track

Conventional UI expects undo. LOAM preserves history.

The likely design problem is not “whether LOAM supports undo”, but:

> How can Correction / Replacement / Reversal / Retirement present themselves as predictable human recovery actions without pretending history was erased?

## Finding F — Chat can be an interaction surface, not merely a parser

The ideal ChatGPT integration is not:

`free text → hidden write`

but:

`conversation → structured semantic proposal → visible preview → approval → same LOAM action → result/provenance`.

## Finding G — Lean-native multi-surface work is no longer hypothetical

LeanTEA is too new to trust blindly, but demonstrates that Lean-native TUI + Web + MCP is technically plausible enough to study seriously before writing a custom “Brick for Lean”.

---

# 14. Research Queue

## Product archaeology

| Target | State | Next investigation |
|---|---|---|
| HRA | partial | concrete Home/TUI input flows; issues; Plan; correction |
| h-kernel | partial | keyboard/mouse navigation; actual entry; Plans; Issues; reports |
| Actual | partial | budget editing; rules; mobile; undo/import edge cases |
| YNAB | partial | mobile entry, reconciliation, overspend recovery, targets |
| Simplifi | partial | mobile navigation, projected cash flow, transfer UX |
| Monarch | partial | transaction review, rules, goals, mobile editing |
| Money Forward ME | partial | input forms, planned expenses, difficult transfer cases |
| Zaim | partial | receipt flow, auto linkage, correction, search |
| GnuCash | partial | reconciliation workflow, reversing transaction UX, splits |
| Firefly III | partial | recurring + rules + API workflows |
| HomeBank | todo | scheduled/budget/statistics model |
| Moneydance | todo | register/reminders/reconcile |
| hledger | todo | CLI/TUI/web surface relationships |
| Beancount/Fava | todo | plaintext source + web inspection/edit |
| Ledger | todo | command/query mental model |
| Buckets | todo | envelope UX |
| KMyMoney | todo | desktop personal-finance workflow |
| Quicken Classic | todo | mature register/schedule/reconcile patterns |

## HCI tracks

| Track | State |
|---|---|
| Nielsen heuristics | started |
| recognition vs recall | started |
| error prevention/recovery | started |
| financial/data error prevention | started |
| accessibility WCAG 2.2 | started |
| keyboard-first design | started |
| mobile touch ergonomics | started |
| progressive disclosure | todo deeper |
| information scent / wayfinding | todo |
| interruption and resumption | todo |
| cognitive load / working memory | todo |
| notification/attention design | todo |
| trust in automation / AI confirmation | todo |
| privacy in financial UI | todo |
| explainable derived state | LOAM-specific research track |

## Surface technology

| Target | State |
|---|---|
| Brick | started |
| Bubble Tea | started |
| Ratatui | started |
| Textual | todo deeper |
| LeanTEA | high-priority started |
| Lean terminal primitives | todo |
| Web UI from Lean | todo |
| OpenAI Apps SDK | started |
| MCP write/action availability | started |
| Mobile native vs Web/PWA | todo |

---

# 15. Research Status Definitions

- **TODO** — identified, not investigated.
- **COLLECTING** — evidence being accumulated.
- **OBSERVED** — enough evidence to describe the pattern.
- **COMPARE** — ready for cross-product comparison.
- **LOAM-MAP** — mapped against existing LOAM semantics.
- **SELECTED** — candidate for LOAM interaction design.
- **REJECTED** — intentionally not adopted, reason retained.
- **DOGFOOD** — synthetic or household usage underway.
- **EARNED** — practical need demonstrated; implementation may be justified.

This keeps research state separate from implementation state.

---

# 16. Next Research Batch

Recommended next batch:

1. Fully excavate HRA and h-kernel daily interaction flows.
2. Continue `LOAM_INTERACTION_ATLAS_DIFFICULT_OPERATIONS.md`:
   - loans / interest,
   - authorization holds,
   - subscriptions / trials,
   - foreign currency,
   - joint accounts,
   - gift cards / store credit.
3. Build a **Home / Attention Atlas** across all products.
4. Build a **Transaction Entry Atlas** across CLI/TUI/desktop/mobile/chat.
5. Deep-review LeanTEA architecture specifically for:
   - TUI primitive reuse,
   - Web view reuse,
   - MCP boundary,
   - what LOAM should *not* inherit.
6. Only after those are mature, sketch LOAM navigation.

---

## Working rule

> Observe broadly. Map narrowly. Implement only what LOAM earns.
