# LOAM Interaction Atlas — Home & Attention Catalog

Date: 2026-09-06  
Status: **research catalog; no Home design selected**  
Parent: `LOAM_INTERACTION_ATLAS.md`

---

## 0. Question

What should a person see when LOAM opens?

This is deliberately asked **after** collecting human goals and difficult operations, because choosing Home too early can force the whole system into one inherited mental model:

- account register,
- budget table,
- dashboard,
- transaction feed,
- calendar,
- task list,
- report book.

Existing software answers this question very differently. LOAM should not choose one by taste alone.

The primary Home question is:

> What information changes the person’s next action or decision right now?

Secondary question:

> What information is useful at a glance but does not deserve interruption?

---

# 1. Attention levels

Before choosing widgets or navigation, classify visible information by interruption cost.

| Level | Meaning | Example | Default presentation |
|---|---|---|---|
| A0 Background | useful if explicitly requested | historical report, net worth history | not on Home by default |
| A1 Glance | useful situational context | current balances, cycle position | compact summary |
| A2 Actionable | a decision/review is genuinely due | upcoming bill, unmatched evidence | visible Home item |
| A3 Urgent | delay creates likely practical harm | overdue obligation, invalid canonical state | prominent attention |
| A4 Blocking | safe action cannot proceed | fail-closed invalid frontier, stale writer conflict | contextual blocking error, not generic Home decoration |

Rule:

> Do not promote information merely because it is computable.

---

# 2. Product Home archetypes

## H-01 Budget as operational center — Actual Budget

Actual’s persistent sidebar makes Budget, Reports, Schedules, and Accounts peers, but the product tour presents Budget as the main planning work area. The Budget view is a dense category-by-month table with Budgeted / Spent / Balance and direct editing of assigned amounts.

Strengths:

- planning state is immediately actionable,
- multi-month context can stay visible,
- allocation editing happens in place.

Risks for LOAM:

- makes category/allocation ontology dominate everyday navigation,
- may over-emphasize budgeting when the person merely wants to record or inspect reality,
- table density is poor for chat/mobile surfaces.

Sources:
- https://actualbudget.org/docs/tour/user-interface/
- https://actualbudget.org/docs/tour/budget/

## H-02 Priority/progress Home — YNAB mobile

YNAB’s mobile Home is explicitly framed around personal priorities and progress. It can include pinned categories, current goal, monthly summary, future assigned money, and content recommendations.

Strengths:

- Home is personalized around what matters to the user,
- priority categories become recognition-first shortcuts,
- progress is separated from detailed transaction/account work.

Risks for LOAM:

- priority/pinning can become manual dashboard gardening,
- motivational content is not necessarily relevant to LOAM’s purpose,
- “important to me” and “requires action now” are different dimensions.

Source:
- https://support.ynab.com/spotlight-BkdHBZUokg

## H-03 Tile dashboard — Quicken Simplifi

Simplifi’s Dashboard provides a broad financial overview through tiles such as Spending Plan, Net Worth, Recent Transactions, Bills & Income, Top Spending Categories, Savings Goals, Watchlist, and monthly spending/income.

Strengths:

- broad situational overview,
- strong drill-down entry points,
- configurable summary supports different priorities.

Risks for LOAM:

- easy to turn Home into a museum of all available calculations,
- weak hierarchy between “interesting” and “requires action”,
- widgets can duplicate information from dedicated surfaces.

Sources:
- https://support.simplifi.quicken.com/en/articles/3357180-getting-to-know-your-dashboard
- https://support.simplifi.quicken.com/en/articles/4564905-getting-to-know-your-dashboard-on-the-mobile-app

## H-04 Recent money movement + contextual topics — Zaim

Zaim’s Home emphasizes current money movement. Its newer Home includes current-month balance/flow, spending distribution, comparative topics such as food spending versus last month, payday countdown, and notifications. Older/current documentation also exposes budget-versus-spending progress.

Strengths:

- understandable household language,
- temporal context such as days until payday is immediately useful,
- recent movement anchors the interface in reality rather than configuration.

Risks for LOAM:

- comparative topics can become algorithmic noise,
- colors such as green/yellow/red can oversimplify whether spending is actually safe,
- “days until payday” only matters if that boundary really owns the household cycle.

Sources:
- https://content.zaim.net/manuals/show/90
- https://content.zaim.net/manuals/show/17

## H-05 Assets + current flow + notifications — Money Forward ME

Money Forward ME’s Home exposes total assets/current flow and a notification area. Its Inflow/Outflow surface separately provides list and calendar views and can show future-dated expenses without including them in current calendar income/expense totals.

Strengths:

- aggregate financial state is immediately visible,
- notifications can surface imported evidence and changes,
- history/calendar remains nearby but not identical to Home.

Risks for LOAM:

- asset total can dominate attention even when no decision follows,
- sync notifications and household semantic attention are not the same thing,
- imported-source events can create large notification volume.

Sources:
- https://support.me.moneyforward.com/hc/ja/articles/24226189541401
- https://support.me.moneyforward.com/hc/ja/articles/24478005732889

## H-06 Custom dashboard + review queue — Monarch

Monarch describes its dashboard as a customizable home base. Widgets can include net worth, transactions, investment performance, and other views. It also makes transaction review a fast first-class workflow and has a recurring-calendar surface with state such as upcoming/completed/late.

Strengths:

- customizable surface ordering,
- review queue turns Home into an action surface,
- web/mobile dashboards can be configured differently.

Risks for LOAM:

- customization can hide important semantic failures,
- summary widgets can show only a subset without making truncation obvious,
- recurring auto-detection can create attention noise.

Sources:
- https://www.monarch.com/features/tracking
- https://www.monarch.com/customizable-dashboard-manual-transactions
- https://www.monarch.com/quicker-and-easier-transaction-review-and-more
- https://www.monarch.com/track-recurring-bills-and-subscriptions

## H-07 Home as temporal attention map — HRA

HRA’s Home presentation transforms semantic observation into a UI-neutral monthly calendar plus selected-day details. Calendar attention can distinguish cycle end, Plan due, Issue due, and multiple simultaneous facts.

Strengths:

- time is a navigation axis, not just a report dimension,
- Actual / Plan / Issue / Cycle can meet on one date without becoming one retained type,
- presentation model is separate from terminal rendering.

Risks for LOAM:

- calendar cells have limited information capacity,
- many semantic layers can create symbol soup,
- attention markers can become an accidental ontology of everything “important”.

Repository evidence:
- `shumoku88-bit/hra/src/hra-household_home_presentation.ads`
- `shumoku88-bit/hra/src/hra-household_home_text.adb`

---

# 3. What existing Homes optimize for

| Product/system | Primary Home answer | Main human question |
|---|---|---|
| Actual | budget work surface / object navigation | “How is money allocated?” |
| YNAB mobile | priorities and progress | “Am I funding what matters?” |
| Simplifi | broad dashboard | “What is my overall financial picture?” |
| Monarch | customizable overview + review | “What do I care about / need to review?” |
| Money Forward ME | assets, flow, notifications | “What changed and where do I stand?” |
| Zaim | recent movement + current-month context | “How is this month going?” |
| GnuCash | account register/tree | “What is in the books/accounts?” |
| HRA | calendar/attention + selected day | “What is happening around this date?” |
| h-kernel TUI | multi-section workspace | “Which household domain surface do I want?” |

No single answer is obviously correct for LOAM.

---

# 4. Candidate LOAM Home facts

This is a catalog, not a selection.

## A. Reality / recent evidence

| ID | Candidate fact | Attention level | Why it might matter |
|---|---|---:|---|
| HOME-R01 | latest Actual events | A1 | confidence that recording succeeded; quick recall |
| HOME-R02 | newly imported/unreviewed evidence | A2 | needs identity/routing review |
| HOME-R03 | account balances | A1 | situational context |
| HOME-R04 | balance changed unexpectedly | A2 | may require inspection |
| HOME-R05 | external sync stale/failed | A1/A2 | evidence horizon may be stale |
| HOME-R06 | reconciliation mismatch | A2/A3 | current balance may be unreliable |

## B. Future obligations

| ID | Candidate fact | Attention level | Why it might matter |
|---|---|---:|---|
| HOME-F01 | next Scheduled items | A1 | near-future context |
| HOME-F02 | Scheduled due today | A2 | likely action/confirmation |
| HOME-F03 | overdue Scheduled occurrence | A2/A3 | needs review; may be missing Actual/cancel evidence |
| HOME-F04 | known obligation with unknown amount | A2 | user may need estimate/evidence |
| HOME-F05 | replacement frontier invalid | A4 | practical readers must fail closed |
| HOME-F06 | replacement occurrence unrouted | A2 | downstream projection may be incomplete |
| HOME-F07 | upcoming recurring series | A1 | useful context, not necessarily action |

## C. Capacity / budget / allocation

| ID | Candidate fact | Attention level | Why it might matter |
|---|---|---:|---|
| HOME-C01 | current safe/spendable capacity | A1 | direct everyday decision support |
| HOME-C02 | known commitments | A1 | explains why capacity is lower than holdings |
| HOME-C03 | negative / insufficient capacity | A2/A3 | requires allocation or spending decision |
| HOME-C04 | remainder / days left in cycle | A1 | pacing context |
| HOME-C05 | allocation changed since previous observation | A1/A2 | useful if unexpected |
| HOME-C06 | unallocated capacity | A1 | possible planning action |

## D. Issues / open questions

| ID | Candidate fact | Attention level | Why it might matter |
|---|---|---:|---|
| HOME-I01 | overdue Issue | A2/A3 | explicit unresolved task |
| HOME-I02 | Issue due soon | A2 | near-term action |
| HOME-I03 | due date unknown | A1/A2 | uncertainty itself may need resolution |
| HOME-I04 | reimbursement expected | A1/A2 | outstanding claim |
| HOME-I05 | subscription/renewal question | A1/A2 | action depends on context |
| HOME-I06 | data/semantic review issue | A2 | system trust depends on resolution |

## E. System integrity / provenance

| ID | Candidate fact | Attention level | Why it might matter |
|---|---|---:|---|
| HOME-S01 | fail-closed projection | A3/A4 | hiding it would be dishonest |
| HOME-S02 | canonical source missing/unreadable | A4 | cannot safely operate |
| HOME-S03 | writer recovery required | A3/A4 | interrupted publication needs explicit continuation |
| HOME-S04 | stale UI snapshot rejected | contextual A2 | user action must retry against fresh state |
| HOME-S05 | unknown relation endpoint | A3/A4 | semantics incomplete |
| HOME-S06 | exact parity mismatch | A4 | canonical projection safety failure |

## F. Reflection / analytics

| ID | Candidate fact | Attention level | Why it might matter |
|---|---|---:|---|
| HOME-A01 | month/cycle spending summary | A1 | glance reflection |
| HOME-A02 | previous-cycle comparison | A0/A1 | useful periodically |
| HOME-A03 | category/purpose trend | A0/A1 | reflection, not daily action |
| HOME-A04 | net worth | A0/A1 | broad financial context |
| HOME-A05 | historical graph | A0 | dedicated report likely better |
| HOME-A06 | achievements/streaks | A0 | low relevance unless deliberately desired |

Early hypothesis: Home should heavily favor A1/A2 facts and route A0 analytics to dedicated report/reflect surfaces.

---

# 5. Attention is not notification

Three different mechanisms must stay conceptually separate.

| Mechanism | Purpose | Example |
|---|---|---|
| Home attention | visible when user enters LOAM | upcoming bill, unresolved matching |
| In-context warning | relevant only during an action | correction affects reconciled evidence |
| OS/push notification | interrupts user outside LOAM | genuinely time-sensitive due event |

Do not automatically turn every Home attention item into a notification.

Apple’s current feedback guidance explicitly warns that alerts lose impact when used too often or for unimportant information. Live Activity guidance similarly says to alert only for essential updates requiring attention.

Sources:
- https://developer.apple.com/design/human-interface-guidelines/feedback
- https://developer.apple.com/design/human-interface-guidelines/live-activities

---

# 6. Attention design anti-patterns

## AP-01 Everything dashboard

Symptoms:

- balance,
- net worth,
- charts,
- transactions,
- budget,
- goals,
- schedules,
- tips,
- sync,
- news,
- achievements,

all compete for first-screen space.

Risk: semantic/action priority disappears beneath information abundance.

## AP-02 Red means everything

Red can mean:

- negative balance,
- overdue,
- overspent,
- invalid,
- sync failure,
- destructive action.

LOAM should not rely on color alone or reuse one alarm signal for unrelated meanings.

## AP-03 Persistent badge debt

An item remains “needs review” after the user already resolved the underlying task, or the same attention appears in multiple places.

Risk: users learn to ignore the badge.

## AP-04 Algorithmic nagging

Auto-detected recurrence, “insight”, or category suggestion repeatedly asks for review despite low relevance.

Rule: automation suggestions should be suppressible and should never outrank explicit known obligations by default.

## AP-05 Silent truncation

Dashboard says “8 items need review” but displays only an unlabeled subset.

Better: show `5 of 8` or route directly to the complete queue.

## AP-06 Empty means good

If a projection fails closed, Home must not render an empty list that looks like “nothing due”.

Unknown/failure is a state.

## AP-07 Decorative precision

Showing a highly precise derived number without an easy “why?” path creates false confidence.

LOAM Home numbers should support provenance drill-down.

---

# 7. Calendar as attention/navigation surface

Calendar has appeared repeatedly across Zaim, Money Forward, Monarch, Simplifi, GnuCash scheduled transactions, and HRA.

Possible calendar roles:

| Role | Example |
|---|---|
| History navigator | choose date → Actual/events |
| Future navigator | choose date → Scheduled/reminders |
| Attention map | due/overdue/issues/cycle boundaries |
| Input origin | choose date → add event with date prefilled |
| Comparison context | current cycle vs previous cycle day |

Calendar should **not** necessarily own:

- accounting period truth,
- category ontology,
- schedule recurrence semantics,
- issue semantics.

It can be a coordinate system over heterogeneous facts.

Money Forward’s calendar is a useful precedent for showing future expenses while excluding them from current income/expense totals. That makes the distinction between **visible future context** and **current aggregate** explicit.

Source:
- https://support.me.moneyforward.com/hc/ja/articles/24478005732889

Simplifi’s Bills & Income surface combines Past Due, upcoming Reminders, summary, and monthly calendar. This demonstrates that calendar and actionable list can coexist rather than forcing one representation.

Source:
- https://support.simplifi.quicken.com/en/articles/4775646-using-the-bills-income-section-on-the-mobile-app

---

# 8. Frequency as navigation evidence

A function’s semantic importance does not determine its navigation prominence.

Candidate frequency classes:

| Frequency | Examples | UI implication |
|---|---|---|
| many/day | quick Actual capture | one action away / shortcut |
| daily | recent activity, capacity glance | Home / primary surface |
| weekly | reconcile, review queue | visible secondary attention |
| monthly/cycle | allocation, report comparison | dedicated surface |
| rare | account creation, import setup | settings/maintenance |
| exceptional | recovery, destructive privacy action | contextual flow only |

This argues against copying h-kernel’s domain-section taxonomy directly into top-level LOAM navigation.

---

# 9. Proposed Home evaluation metrics

Before selecting a Home, synthetic dogfood should measure:

| Metric | Question |
|---|---|
| Action latency | how many inputs from launch to common task? |
| Decision latency | how quickly can user answer “what needs me?” |
| Recall burden | what IDs/terms must be remembered? |
| Attention precision | what percentage of highlighted items actually need action? |
| Attention recall | are important items hidden? |
| False urgency | how many nonurgent facts look urgent? |
| Explanation depth | can every important number/state answer “why?” |
| Recovery discoverability | can interrupted/failed operations be resumed? |
| Surface consistency | same action semantics across CLI/TUI/GUI/chat/mobile? |
| Scan cost | how much content must be visually parsed each launch? |
| Keyboard cost | key count for TUI/CLI daily paths |
| Touch cost | tap/reach burden for mobile |

---

# 10. Candidate Home experiments — not designs

These are synthetic-dogfood candidates only.

## Experiment A — Attention-first Home

```text
LOAM

Needs attention
  Rent due tomorrow             ¥50,000
  1 imported movement unmatched
  Reimbursement still open      ¥1,240

Today
  Spendable / capacity           ¥3,420
  2 Actual events

Recent
  Coffee                          ¥138
  Books                         ¥2,470
```

Hypothesis:

- excellent for next-action clarity,
- risks underrepresenting broad financial state.

## Experiment B — Time-first Home

```text
September 2026

 Mo Tu We Th Fr Sa Su
        1  2  3  4  5  6
        ·  $  ·  !  +  [6]
 ...

Selected 6 Sep
  Actual      2
  Scheduled   1
  Issue       0
  Cycle       day 12 / 61
```

Hypothesis:

- strong temporal navigation,
- risks overloading calendar markers.

## Experiment C — Capacity-first Home

```text
Available now                 ¥xx,xxx
Known commitments             ¥xx,xxx
Unallocated                   ¥x,xxx
Cycle remaining               49 days

Due next
  ...

Recent changes
  ...
```

Hypothesis:

- useful for “can I spend?” decisions,
- risks making a derived projection feel more authoritative than its evidence.

## Experiment D — Command/intent Home

```text
What do you want to do?

  Record something
  Move money
  Review what changed
  See what is due
  Check what I can use

Needs attention: 2
```

Hypothesis:

- excellent recognition-first navigation,
- may feel slower to experts unless keyboard shortcuts bypass it.

## Experiment E — Hybrid minimal Home

```text
Attention  2       Capacity ¥x,xxx

Today
  2 Actual   1 Scheduled

[Record] [Review] [Calendar] [Accounts]
```

Hypothesis:

- perhaps best multi-surface seed,
- may be too generic to express LOAM’s strongest semantics.

No experiment is selected.

---

# 11. Surface differences

The Home concept does not need identical composition across surfaces.

## CLI

Opening `loam` could show a compact status summary plus command discovery.

Best at:

- exact diagnostics,
- scripted status,
- direct commands.

Avoid:

- pretending ASCII dashboard density is inherently useful.

## TUI

Likely strongest candidate for persistent Home/Calendar/Attention workspace.

Best at:

- keyboard navigation,
- split panes,
- selected-item detail,
- dense review queues,
- low-latency switching.

## GUI/Web

Best at:

- drill-down,
- charts/comparison,
- provenance graph/detail,
- flexible responsive layout.

Home can be richer than TUI but should preserve the same attention semantics.

## ChatGPT

Conversation itself is already a contextual Home.

A separate in-chat LOAM card should probably surface only:

- the requested action,
- relevant attention triggered by that action,
- confirmation/result,
- direct links/drill-down.

Chat should not dump the full dashboard into every interaction.

## Mobile

Best candidates:

- quick capture,
- due/overdue attention,
- recent activity,
- capacity glance,
- calendar,
- notifications.

Detailed provenance and bulk maintenance can remain secondary.

---

# 12. HCI baseline for Home

Current Apple design principles emphasize:

- purpose: focus on what matters most,
- agency: keep people informed and make recovery easy,
- responsibility: safety/privacy/transparency,
- familiarity: build on known concepts,
- clear feedback.

Source:
- https://developer.apple.com/design/human-interface-guidelines/design-principles

For LOAM this suggests:

1. Home should have a **purpose**, not just widgets.
2. attention states should explain what action is possible,
3. semantic failure should be transparent,
4. recovery should be available from the failure context,
5. unfamiliar LOAM concepts should be introduced only when they help a real goal.

Modal interactions should remain narrow and dismissible because stacking modal context increases cognitive load.

Source:
- https://developer.apple.com/design/human-interface-guidelines/modality

---

# 13. Early LOAM-specific Home laws

These are design candidates, not proved semantic laws.

### HA-01 Actionability before analytics

A genuinely due/reviewable item outranks an interesting chart.

### HA-02 Failure before emptiness

A failed projection cannot appear as “nothing here”.

### HA-03 Unknown before zero

Home must preserve semantic uncertainty.

### HA-04 Provenance is one step away

Any consequential visible number or warning should support “why?”.

### HA-05 No duplicated attention debt

Resolving an item in one surface should resolve its derived attention everywhere that consumes the same state.

### HA-06 Attention is derived

Home attention should normally be a projection over facts, not a second canonical task database.

### HA-07 User priority and system safety are separate

Pinned/favorite items may be customizable. Fail-closed/system-integrity attention may not be hideable in a way that implies safe state.

### HA-08 Time is a coordinate, not an ontology

Calendar can align Actual, Scheduled, Issue, Cycle, and other facts without flattening them.

### HA-09 Surface layout may differ; semantic attention must not

CLI/TUI/GUI/chat/mobile can render differently while agreeing on what is due, unknown, invalid, or resolved.

### HA-10 Quiet is a feature

If nothing requires action, Home should be allowed to be calm.

---

# 14. Research queue

Next work for this shard:

1. excavate exact HRA Home navigation and input transitions,
2. excavate h-kernel Home/TUI navigation and mouse/keyboard paths,
3. catalog “Needs review” / inbox patterns across finance software,
4. study interruption/resumption research for partially completed input,
5. study accessibility for dense calendar/status displays,
6. test 4–5 candidate Home experiments with the same synthetic household scenario,
7. count actions/keystrokes/taps rather than choosing by screenshot aesthetics.

The next sibling shard should be `LOAM_INTERACTION_ATLAS_TRANSACTION_ENTRY.md`.

---

# 15. Source index

- Actual UI: https://actualbudget.org/docs/tour/user-interface/
- Actual Budget view: https://actualbudget.org/docs/tour/budget/
- Actual Schedules: https://actualbudget.org/docs/schedules/
- YNAB Home: https://support.ynab.com/spotlight-BkdHBZUokg
- Simplifi Dashboard: https://support.simplifi.quicken.com/en/articles/3357180-getting-to-know-your-dashboard
- Simplifi mobile Dashboard: https://support.simplifi.quicken.com/en/articles/4564905-getting-to-know-your-dashboard-on-the-mobile-app
- Simplifi Spending Plan: https://support.simplifi.quicken.com/en/articles/14982841-how-to-set-up-a-spending-plan-on-the-mobile-app
- Simplifi Bills & Income: https://support.simplifi.quicken.com/en/articles/4775646-using-the-bills-income-section-on-the-mobile-app
- Money Forward Home: https://support.me.moneyforward.com/hc/ja/articles/24226189541401
- Money Forward Inflow/Outflow: https://support.me.moneyforward.com/hc/ja/articles/24478005732889
- Zaim Home: https://content.zaim.net/manuals/show/90
- Zaim earlier/current Home description: https://content.zaim.net/manuals/show/17
- Monarch tracking/dashboard: https://www.monarch.com/features/tracking
- Monarch customizable dashboard: https://www.monarch.com/customizable-dashboard-manual-transactions
- Monarch transaction review: https://www.monarch.com/quicker-and-easier-transaction-review-and-more
- Monarch recurring calendar: https://www.monarch.com/track-recurring-bills-and-subscriptions
- Apple design principles: https://developer.apple.com/design/human-interface-guidelines/design-principles
- Apple feedback: https://developer.apple.com/design/human-interface-guidelines/feedback
- Apple modality: https://developer.apple.com/design/human-interface-guidelines/modality
- Apple Live Activities attention guidance: https://developer.apple.com/design/human-interface-guidelines/live-activities

Repository archaeology:

- `shumoku88-bit/hra`
- `shumoku88-bit/h-kernel`

---

> Home is not where everything is shown. Home is where the next useful distinction becomes visible.
