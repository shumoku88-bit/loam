# Let's Kakeibo — longevity study

## 1. Timeline

High-confidence public timeline:

- The author describes the original concept as dating back to a PC-8801 household program.
- A Windows version emerged in the Windows 95/98 era.
- A 1999 Vector review documents version 1.79 with the core direct-entry table already established.
- A 2005 review shows the same basic table plus mature recurring, budget, graph, account, and card behavior.
- Version 5 appeared in 2008 with a redesigned screen, refreshed graphs, calendar pane, simple daily/diary pane, formula entry, and stronger input assistance.
- The final public version is v5.93 from 2013.
- On 2024-07-06 the author ended shareware sales/support and made the program free to use.
- The author states that the code has been unmaintained for more than a decade and is difficult to bring forward to current development tools.
- The official site nevertheless reports that the existing program still runs on Windows 10/11 with possible minor issues; a 2024 窓の杜 report independently says Windows 11 operation was confirmed.

## 2. What appears to have lasted

The durable part was not modern visual styling.

The following interaction ideas survive across the available snapshots:

- one chronological monthly household workspace;
- direct entry into the table;
- multiple accounts visible through the same ledger;
- running balance near the transaction;
- repeated-entry assistance;
- recurring items;
- dedicated but nearby budget/report surfaces;
- fast return from summaries to details;
- guidance that helps a dense program remain learnable.

## 3. The technology did not age as well as the interaction model

The author's 2024 notice is a useful warning.

The program can still execute, but the old source is difficult to adapt to current development tools.

This yields a distinction:

```text
interaction model longevity != toolkit longevity
```

For LOAM, long life should therefore come from keeping:

- household facts;
- semantics;
- application actions;
- export/import boundaries;
- presentation projections;

more durable than any one GUI toolkit.

## 4. Continuity over perfect bookkeeping

The author's 2008 remarks prioritize continuing the household record over forcing perfect reconstruction of every discrepancy.

Whether or not LOAM adopts the same policy, this is an important sustained-use observation:

```text
a household system that blocks continuation after imperfect memory
may be less durable than one that records uncertainty explicitly
```

LOAM should answer this in its own evidence model rather than by copying a generic "unknown expense" mechanism.

## 5. Sample data as longevity infrastructure

The later walkthrough highlights an 18-month sample household that makes long-range graphs and reports meaningful immediately.

This is a subtle but strong teaching mechanism:

- users can inspect a populated system before committing their own data;
- report behavior can be learned without waiting months;
- demonstrations and regression examples share similar shapes.

A LOAM Desk prototype may benefit from deterministic demonstration data, but it should remain separate from canonical household authority.

## 6. Long-lived UI hypothesis

The evidence suggests that durable household software benefits from:

1. a stable central object users recognize every day;
2. low-friction repetitive input;
3. nearby explanation and recovery;
4. strong temporal navigation;
5. ability to reach source evidence from summaries;
6. export/backup escape routes;
7. implementation technology that can be replaced without redefining household meaning.

Only the first six are directly observable in Let's家計簿. The seventh is the LOAM architectural inference drawn from its eventual toolchain aging.
