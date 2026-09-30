# Let's Kakeibo -> LOAM translation notes

> For the concluded classification, see [LESSONS_FOR_LOAM_DESK.md](LESSONS_FOR_LOAM_DESK.md). For the minimal implementation hypothesis, see [DESK_TUI_V0_HYPOTHESIS.md](DESK_TUI_V0_HYPOTHESIS.md).

Status: **superseded as the exploratory mapping by the research conclusion; retained for traceability**

## 1. Do not clone the data model

Let's家計簿 and LOAM do not have the same semantics.

The study should copy interaction ideas only where LOAM can preserve its own:

- Movement model;
- Actual authority/evidence;
- Scheduled semantics;
- correction/admission rules;
- Measure handling;
- provenance.

## 2. Candidate correspondences

| Let's家計簿 observation | Possible LOAM concept | Caution |
| --- | --- | --- |
| monthly household table | Actual chronological desk | Do not make display rows the authority. |
| account field + running balance | Locus + derived balance | Derived values must remain explainable. |
| recurring automatic entry | Scheduled | Do not silently turn plan into Actual. |
| credit settlement -> purchases | settlement / provenance | LOAM can model traceability more explicitly. |
| category colors | Purpose/Locus presentation metadata | Color is presentation only. |
| calendar -> ledger row | date navigation over Actual | Strong TUI candidate. |
| report -> source detail | observation -> evidence | Strong LOAM fit. |
| balance correction | correction/reconciliation workflow | Preserve LOAM evidence semantics; do not overwrite history. |
| formula/calculator in amount cell | entry convenience | Keep parser behavior explicit and testable. |
| history reuse | entry proposal/default | Never silently infer final semantics. |
| sample household | deterministic demo fixture | Must not mix with real authority. |

## 3. Candidate LOAM Desk shape

A research sketch:

```text
+------------------+----------------------------------------------+
| calendar         | Actual chronological table                   |
|                  |                                              |
| month/day        | date | from -> to | amount | context         |
| navigation       |                                              |
+------------------+----------------------------------------------+
| daily/cycle info | selected row / evidence / balance / trend    |
+------------------+----------------------------------------------+
| key help / state / refusal explanation                          |
+-----------------------------------------------------------------+
```

The most important choice is that the table remains the center.

## 4. Potentially valuable ideas to test first

### A. Date navigation without mode switching

Calendar selection changes the visible/focused Actual interval.

### B. Row-centered context

Selecting a movement changes only the context pane:

- detail;
- balance effect;
- related Scheduled item;
- provenance/correction state;
- small trend.

### C. Aggregate-to-evidence navigation

From any number that matters, provide a route to the rows that created it.

### D. Reusable entry suggestions

Reuse recent compatible values as proposals, not as hidden automatic truth.

### E. Persistent command hints

The original product used status/help cues to make a dense surface learnable. A terminal desk can do the same very cheaply.

## 5. Ideas to treat skeptically

- duplicating every old setup tab;
- replicating credit-card accounting rules that LOAM models differently;
- many chart types without a household question;
- hidden behavior that changes by cell without visible state;
- automatic balance adjustments that bypass explicit evidence;
- recreating old Windows aesthetics for nostalgia rather than function.

## 6. Relationship to the current TUI

The desk experiment should be a separate front end during research.

It should not initially replace:

- the current production TUI;
- named CLI commands;
- existing application entrances.

If it proves useful, the two surfaces can later share more presentation/application components.

## 7. Suggested experimental sequence

```text
read-only calendar + Actual table
        ->
selection + context pane
        ->
date/month navigation
        ->
detail/evidence drill-down
        ->
small aggregate drill-down
        ->
only then consider write/correction actions
```

The purpose is to test the interaction topology before paying the cost of a second complete editing surface.
