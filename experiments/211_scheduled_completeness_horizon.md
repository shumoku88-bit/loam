# Observation 211 — Can a completeness horizon make absent Scheduled evidence safe for AI advice?

Status: **COMPLETE — bounded completeness survives / RESEARCH_ONLY**

## Household pressure

A concrete household consultation exposed a dangerous ambiguity.

Suppose the retained future schedule visibly contains rent in September and November but no rent in October. From those finite Scheduled occurrences alone, an AI cannot know whether:

```text
A
  October rent is genuinely not due

B
  October rent is due
  but that occurrence has not been materialized yet
```

Silently assuming monthly recurrence can therefore invent a payment and produce a false balance warning. Silently assuming bimonthly recurrence is equally unjustified.

The immediate question is not whether LOAM should add `Recurrence`.

It is narrower:

> What is the smallest information needed for an AI or projection to distinguish positive Scheduled evidence, safe negative evidence, and an unknown future gap?

## Prior boundaries

This observation reuses rather than reopens earlier results.

Observation 064 established:

```text
Plan content
    !=
recurrence kind
    !=
Series membership
```

Observation 122 established that next-occurrence continuation provenance is independent from replacement and does not itself earn recurrence generation.

Observation 200 established:

```text
Series membership + recurrence shape
    !=
generation policy
```

so even an eventual recurrence representation must not be assumed to determine every generated calendar occurrence.

LOAM also already uses a `known-through` horizon in historical/shadow Scheduled queries. That horizon means which evidence is visible through an observation time. It does **not** mean that all household obligations up to that date have been entered. Observation 211 deliberately does not reuse that name or meaning.

## Candidate under test

The candidate is a single global Scheduled completeness boundary:

```text
explicit Scheduled occurrences
+
complete-through date
```

with the meaning:

> For the covered interval, every household obligation that should be represented as Scheduled has been explicitly materialized.

This is deliberately stronger than ordinary finite Scheduled memory, but much smaller than a recurrence engine.

For AI/query purposes it supports a three-valued reading:

```text
explicit occurrence exists
    -> Due

no explicit occurrence
+ query is inside complete-through horizon
    -> NotDue

no explicit occurrence
+ query is outside complete-through horizon
    -> Unknown
```

`Unknown` is an important result, not an error. It lets LOAM refuse to invent monthly/bimonthly semantics when canonical evidence is silent.

## Alloy vocabulary

The bounded model uses two household subjects and four abstract months:

```text
Subject = Rent | Subscription
Month   = Sep | Oct | Nov | Dec
```

Each observation-local world has:

```text
actualDue       : Subject -> Month
explicit        : Subject -> Month
completeThrough : lone Month
```

`actualDue` is only model ground truth for checking sufficiency. It is not proposed production state.

Every explicit Scheduled occurrence must be actually due.

If `completeThrough = h`, the model additionally requires exact equality between actual-due and explicit occurrences for **all subjects** inside the prefix ending at `h`.

The candidate is therefore a global completeness assertion over the Scheduled authority, not one new recurrence record per bill/Series.

## Selected probes

The observation asks for:

1. a representative September/November rent schedule with October safely absent under completeness through November;
2. two worlds with identical explicit Scheduled evidence but different October-rent truth when no completeness claim exists;
3. two worlds that agree on explicit Scheduled and completeness through October but disagree beyond the horizon;
4. a check that explicit positive Scheduled evidence is sound;
5. a counterexample to closed-world `absent -> NotDue` over finite Scheduled alone;
6. a check that covered absence safely implies NotDue;
7. a check that equal explicit evidence + equal completeness fixes truth inside the covered horizon;
8. a counterexample to treating completeness as recurrence or unlimited future knowledge.

## Executed result

Alloy 6.2.0 + Sat4j produced exactly the selected matrix on model head:

```text
850b0cf842e4d8cab6cff43821772f9626182412
```

Dedicated workflow run `34040959113`, job `101507509697`, completed **SUCCESS**, including the expected-result checker.

```text
representativeCoveredBimonthlyLikeRent              SAT
sameExplicitNoCoverageDifferentOctoberRent          SAT
sameExplicitAndCoverageDifferentBeyond              SAT
ExplicitScheduledDeterminesPositiveDue              UNSAT counterexample
ExplicitAbsenceDeterminesNotDue                      SAT counterexample
CoveredAbsenceDeterminesNotDue                       UNSAT counterexample
SameExplicitAndCoverageDetermineCoveredTruth         UNSAT counterexample
CoverageDeterminesAllFutureTruth                     SAT counterexample
```

The central counterexample keeps the finite explicit Scheduled evidence equal while changing only the hidden October-rent truth. Without completeness evidence, the same visible September/November schedule therefore supports both `NotDue` and `due but not materialized` worlds.

The positive covered checks close the selected bounded gap: once an explicit completeness horizon covers the queried month, absence of a Scheduled occurrence safely determines `NotDue` in the model. Equal explicit occurrences plus the same completeness horizon also determine the selected due/not-due truth inside that covered prefix.

The final counterexample deliberately requires a real, equal, nonempty completeness horizon on both worlds. The worlds can still disagree beyond it. Therefore:

```text
complete-through
    !=
recurrence
    !=
unbounded future knowledge
```

## Finding

For the selected AI-advice query, finite Scheduled should be read as **open-world** evidence:

```text
present  -> Due
absent   -> Unknown
```

That rule alone is enough to prevent the specific failure mode where an AI silently invents a monthly or bimonthly obligation from missing future rows. It requires no new canonical fact.

If LOAM also wants a safe negative answer such as "there is no rent due next month", the bounded observation shows that one completeness boundary is information-sufficient inside its covered planning window:

```text
present                         -> Due
absent + covered by completeness -> NotDue
absent + not covered             -> Unknown
```

Recurrence is therefore **not earned by this AI false-warning problem alone**.

It may still be needed later for a stronger question, such as projecting unmaterialized occurrences beyond the explicit complete window. Observation 064/122/200 already show that such a path must keep Series identity, continuation, recurrence shape, and generation policy distinctions honest rather than collapsing them into one magic rule.

## Product levels after the result

```text
Level 0
  explicit Scheduled only
  -> safe positive answers
  -> absence remains Unknown

Level 1
  explicit Scheduled + completeness horizon
  -> safe positive and negative answers inside a bounded planning window
  -> still no recurrence generation

Level 2
  recurrence / Series / generation policy
  -> only needed if LOAM must project unmaterialized occurrences beyond the explicit complete window
```

This ordering directly pressures whether the household AI-consultation problem can be solved without multiplying canonical fact families.

## Persistence topology note

No persistence change is made by this observation.

Current `ScheduledPersistence` uses one whole-file, versioned stream:

```text
LOAM-SCHEDULED-MEMORY\t1
SCHEDULED ...
CHANGE ...
...
```

and publishes the complete file through sibling staging plus rename.

Therefore, **if** a completeness boundary is later earned by practical dogfood, a separate canonical file is not mechanically required. One plausible storage experiment would be a versioned successor such as:

```text
LOAM-SCHEDULED-MEMORY\t2
SCHEDULED-COMPLETE-THROUGH\t2027-03-31
SCHEDULED ...
CHANGE ...
...
```

This is only a topology observation, not a proposed final wire format.

Keeping the completeness claim in the same Scheduled authority has one potentially useful property: occurrence-set publication and the claim that the set is complete can be staged and renamed together rather than coordinated across two files.

But same-file storage is not automatically correct. Before implementation LOAM would still need to pressure:

- whether completeness is global or needs subject/Series scope;
- whether one newly discovered omitted obligation invalidates or revises an earlier completeness claim;
- how replacement/retirement/completion projections compose with the claim;
- whether the writer can advance the horizon fail-closed;
- whether a current-snapshot completeness marker is historical evidence or replaceable planning authority.

Do not create a separate `ScheduledCompleteness` file merely because the information is independent. Logical independence does not imply physical file independence.

## Deliberate boundaries

Observation 211 does not establish:

- a production completeness field;
- a production `Recurrence`, `Cadence`, or `Series` type;
- a recurrence generator;
- a fixed materialization horizon such as three or six months;
- that a global completeness horizon is maintainable in real household use;
- that amount or date generation policies are fixed;
- that absence beyond the horizon means NotDue;
- that LOAM should rewrite canonical data now;
- a final persistence version or TUI design.

The bounded result establishes only that finite Scheduled alone is too small for safe negative inference, while one explicit completeness boundary is sufficient for the selected covered-window query.
