# Let's Kakeibo — evolution, rewrite, and interface continuity

## 1. The earliest concept predates Windows

In the 1999 and 2005 author interviews, the author says the conceptual ancestor was a personal program on a PC-8801mkIIMR.

The defining concepts were already:

- direct entry into a table;
- expense classification;
- multiple-account management.

The author explicitly describes the basic concept as unchanged when rebuilding the program for Windows.

This makes the table model older than the particular Windows controls later used to render it.

## 2. User growth created structural pressure

The 2005 author interview contains a particularly valuable software-history detail.

The early Windows program had been designed primarily for the author. Over several years, user requests were added until even small feature additions required large amounts of work.

The author compares the result to trying to expand a small single-story house into a much larger multi-story one.

This is direct evidence of **feature accretion exceeding the original internal architecture**.

## 3. Ver.3 was a near-total internal rewrite

To escape that state, the author started a separate project that rewrote almost all of the program source while intentionally keeping the visible appearance and behavior the same.

The rewrite was originally expected to take months but took more than three and a half years. It eventually became the Ver.3.xx line.

This is an unusually clear case of:

```text
interaction contract retained
implementation replaced
```

It is one of the strongest findings in this study.

## 4. Why this matters more than the old toolkit

The product's long life is therefore not simply explained by "old Windows binaries happen to keep running."

Its history already contains one deliberate implementation replacement beneath a retained interaction model.

That suggests three distinct layers were implicitly present even before they were formally named:

```text
household concept
      |
interaction habits
      |
implementation machinery
```

The first two were valuable enough to preserve while the third was replaced.

## 5. Version 5 changed the surroundings, not the center

Version 5 in 2008 changed the screen design and graph facilities and added:

- calendar pane;
- simple daily aggregation/diary pane;
- formula entry;
- stronger history/category assistance;
- per-month budgeting.

Yet the core monthly ledger remained the everyday work surface.

This is incremental evolution around a stable center rather than periodic reinvention of the home screen.

## 6. Stable user goal expressed by the author

The 2005 interview says development continuously aimed at a program that was:

- simple and readable;
- easy to operate;
- friendly to beginners;
- still high-functionality;
- satisfying to the author as an actual user.

The author also says reducing everyday entry labor remained an ongoing priority.

For LOAM research, this is useful because it describes a design constraint rather than a feature list.

## 7. Installation and upgrade were treated as interaction problems

The author says many novice users found installation and version upgrades harder than using the program itself, so substantial effort went into simplifying those paths.

This broadens the meaning of UI longevity:

```text
usable daily screen
+
survivable installation / upgrade path
```

A durable LOAM surface should treat packaging, migration, and recovery as part of interaction quality rather than as separate engineering chores.

## 8. Final-release paradox

By 2024, the author says the old source is difficult to adapt to current development tools, even though the existing binary continues to run on Windows 10/11.

So the product exhibits two opposite longevity outcomes:

### Success

- the household interaction model remained understandable;
- the binary survived multiple Windows generations;
- user data remained useful;
- outside specialists could still learn and document the program.

### Failure pressure

- development tooling aged out;
- source modernization became unattractive/difficult;
- support stopped;
- some graphics no longer fit modern high-resolution displays.

## 9. LOAM implication

A useful architectural target is therefore not "make one GUI survive forever."

It is:

```text
stable household semantics
      +
stable application actions/projections
      +
replaceable human shell
```

The Let's家計簿 history gives concrete evidence that replacing implementation while preserving interaction can be worth doing, and also that waiting too long can make the next replacement prohibitively expensive.
