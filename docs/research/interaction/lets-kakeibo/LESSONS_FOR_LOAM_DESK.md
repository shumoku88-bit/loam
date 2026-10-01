# Lessons from Let's Kakeibo for LOAM Desk

Date: 2026-10-01  
Status: **research conclusion; Desk TUI tested and retired; GUI experiment is the next shell hypothesis**

This note closes the first Let's家計簿 research cycle by separating durable interaction lessons from historical product details.

The question is not "How do we reproduce Let's家計簿?"

The question is:

> Which interaction ideas remain useful when the household semantics are LOAM's?

## 1. Adopt directly as interaction hypotheses

These ideas map cleanly onto LOAM without weakening its model.

### A. Keep the chronological household table at the center

The strongest lesson is structural:

```text
calendar / local summary
          |
          v
chronological household table
          |
          +--> detail
          +--> balance
          +--> future
          +--> trend
          +--> evidence
```

A desk should begin from Actual evidence, not from a dashboard of disconnected cards.

The table is the place the user returns to after inspection.

### B. Date navigation should not require changing screens

Calendar/date movement should change the visible/focused Actual interval.

Useful terminal equivalents include:

- previous/next day;
- previous/next month;
- jump to date;
- first/last row in period.

The exact Let's家計簿 shortcuts do not need to be copied, but date navigation should be cheap enough to become muscle memory.

### C. Repeated entry should inherit obvious local context

Let's家計簿 reduces repeated receipt entry by reusing date/shop/account context.

LOAM can test the same human goal:

```text
record first movement with full context
        ->
record next compatible item
        ->
reuse only explicit safe defaults
```

The inherited values must remain visible proposals, never hidden semantic inference.

### D. Persistent command/help context

A dense desk becomes learnable when the currently valid actions are always visible.

A terminal has an advantage here: one bottom line can continuously expose:

- selected state;
- available actions;
- refusal/explanation;
- current period;
- active filter.

### E. Aggregate -> contributing evidence

This is one of the strongest LOAM fits.

Any important aggregate should have a route back to what created it:

```text
Trend / Flow / Balance / Scheduled pressure
            ->
contributing rows
            ->
Actual evidence / provenance
```

LOAM can make this stronger than Let's家計簿 because provenance is already a first-class concern.

### F. Future obligations as one household question

Let's家計簿 combines different future sources in one future view.

LOAM should preserve the semantic distinctions internally, while letting the user ask one practical question:

> What is going to hit the household next?

A future pane may combine:

- Scheduled;
- settlement consequences;
- manually planned/future items where LOAM semantics permit;
- source/type markers.

### G. Query -> inspect subset -> act

Search becomes more useful when the result set remains connected to the original ledger and can support qualified actions.

Initial LOAM Desk work should prioritize:

```text
query -> inspect -> jump back to evidence
```

Batch mutation can wait until the read/navigation model is proven.

## 2. Adopt only after translating into LOAM semantics

These ideas are useful at the human-interaction level but their historical storage/accounting behavior should not be copied.

### A. Transfer assistant

Useful idea:

> one interaction for one real-world movement.

Do not copy:

> encode transfer as compensating income/expense rows excluded from reports.

LOAM already has the stronger Movement model.

### B. Balance reconciliation

Useful idea:

> imperfect memory must not permanently block continued bookkeeping.

Translate using LOAM-native:

- explicit observation;
- explicit discrepancy;
- correction/reconciliation evidence;
- later reclassification without rewriting history invisibly.

Do not create a magical balancing row merely to make numbers agree.

### C. Credit purchase -> settlement traceability

Useful idea:

> origin and later settlement should be navigable in both directions.

LOAM should use its own settlement/provenance representation, not reproduce installment/revolving machinery merely because Let's家計簿 had it.

### D. Recurring rule editing

Useful idea:

> show future consequences and make retrospective effects explicit.

Do not silently rebuild past Actual evidence when a Scheduled rule changes.

### E. Multiple currencies

Useful idea:

> currency/measure belongs near the account/movement and should remain visible when non-default.

LOAM's Measure/exchange semantics remain authoritative. Do not collapse different measures merely to reproduce historical account totals.

### F. Tags

Useful idea:

> cross-cutting annotations should not be confused with accounting classification.

Before adding a generic tag system, test whether existing LOAM concepts such as Attention, events, Purpose, or explicit presentation metadata already cover the real need.

## 3. Reference only, not an implementation target

These are useful historical observations but should not drive the first desk experiment.

- many graph types;
- many setup tabs;
- exact Windows toolbar/menu organization;
- receipt cosmetics;
- old credit-card financial calculators;
- password-on-start behavior;
- every legacy import format;
- reminder utility;
- per-book toolbar colors;
- historical holiday-rule detail;
- old floating calendar variants.

They may inspire later work if a current LOAM need appears.

## 4. Do not copy

### A. Historical transfer storage semantics

LOAM must not regress from first-class Movement to paired pseudo-income/pseudo-expense rows.

### B. Hidden cell magic

Let's家計簿 gains speed from context-sensitive cells, but the final help also reveals substantial hidden behavior.

LOAM Desk should prefer visible state and explicit actions over a cell whose meaning silently changes by context.

### C. Automatic mutation during preview/cancel

Later hands-on import analysis found paths where cancellation could leave configuration changes behind.

LOAM should preserve:

```text
preview is non-mutating
commit is one qualified boundary
cancel means cancel
```

### D. Direct editing of derived state

Balances should remain derived.

A desk may show or reconcile a balance, but it should never make a derived balance cell itself the authority.

### E. Recreate old Windows aesthetics

The useful inheritance is information topology and workflow, not nostalgia.

## 5. The four durable principles

The research can be compressed into four principles.

### 1. Evidence first

The central object is the chronological household record.

### 2. Navigation over mode switching

Move through day/month/row/context before opening a new screen.

### 3. Observation must lead back to evidence

Every useful summary should answer "what made this number?"

### 4. Preserve semantics beneath replaceable shells

Let's家計簿 survived multiple Delphi generations and one major internal rewrite. LOAM should make the terminal/GUI replaceable while household meaning remains stable.

## 6. Desk TUI experiment outcome

A separate read-only Desk TUI was implemented and used.

It preserved the intended semantic boundary: the shell owned only layout/focus/selection and consumed existing read projections. However, in actual use it did not feel materially different from the production TUI.

This is informative rather than a reason to widen the terminal experiment. The missing distinction is primarily interaction-medium capability:

- pointer-directed selection;
- genuinely resizable spatial panes;
- richer table affordances;
- graph/region selection;
- hover/context surfaces where useful;
- direct manipulation without rebuilding GUI mechanics inside a terminal.

Therefore the separate Desk TUI implementation is retired rather than grown into a second production TUI.

The next shell experiment should be a small GUI over the existing presentation/read boundary, with the same semantic rule:

```text
Core / Authority / Application / Review / Presentation
                         |
                         v
              surface-neutral read answers
                         |
                         v
               replaceable GUI shell
```

The GUI must not become a second accounting engine.

## 7. Stop rule for this research cycle

The Let's家計簿 study is sufficiently complete to start a LOAM Desk interaction experiment.

Further archaeology should be demand-driven.

Return to the source material only when a concrete Desk question needs evidence, such as:

- exact receipt-entry behavior;
- a specific report drill-down;
- search-result mutation;
- a backup/recovery interaction.

Do not continue researching merely to make the historical inventory exhaustive.
