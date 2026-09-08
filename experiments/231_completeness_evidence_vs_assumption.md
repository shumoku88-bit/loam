# Observation 231 — Can an explicit completeness assumption substitute for Scheduled completeness evidence?

Status: **IN PROGRESS — typed evidence-vs-assumption boundary**

Research baseline: LOAM `406b892a240928a3a9b417967e2c499b32c907ed`

## Pressure

Observation 229 narrowed the future-path calculation itself to something small:

```text
current selected quantity
+ dated selected daily net effects
-> prefix sum
-> day-boundary path / day-boundary minimum
```

The remaining future-evidence pressure is not mainly arithmetic.

Observation 211 already showed that finite Scheduled is open-world and that a bounded completeness claim can justify negative absence inside its scope without recurrence. Observation 221 then showed that completeness is a family-specific information gate rather than a generic Coverage ontology.

A practical Report Lab question remains:

> If production does not yet retain Scheduled completeness evidence, may a user ask for a useful path by explicitly saying “assume the Scheduled set is complete through H”?

Two candidate inputs can therefore share the same date while having different meanings:

```text
A. retained completeness evidence
   "Scheduled is complete through H"

B. query-local assumption
   "for this calculation, assume Scheduled is complete through H"
```

The question is whether B can safely substitute for A, or whether it must remain visibly conditional even when both produce the same numbers.

## Prior boundaries held fixed

This observation reuses rather than reopens:

- Observation 185: canonical evidence + explicitly typed hypothetical intervention may produce a derived comparison without mutating authority;
- Observation 211: bounded completeness can strengthen absence from Unknown to NotDue inside scope;
- Observation 221: completeness is domain-specific evidence and justified completeness refines information;
- Observation 229: once the future input is qualified, a day-boundary selected balance path is prefix accumulation; selection, intraday ordering, and overdue future timing remain separate evidence boundaries.

The current production TUI therefore remains correct to show `UNKNOWN` when no qualified complete-future input exists.

## Candidate typed answer

Observation 231 deliberately keeps three result states distinct:

```text
Unknown

Qualified(evidence, path)
  retained completeness evidence covers the query

Conditional(assumption, path)
  no covering retained evidence
  but the caller explicitly supplied a covering assumption
```

The numerical `path` may be identical in the last two cases.

That does **not** make the answers semantically identical.

```text
same payload
    !=
same epistemic status
    !=
same provenance
```

This is the key boundary under test.

## Lean probe

The experiment uses one tiny two-day path input:

```text
current   10
D1 flow   -3
D2 flow   +5
```

so the ordinary prefix path is:

```text
D1  7
D2 12
```

It defines separate experiment-local types:

```text
CompletenessEvidence
CompletenessAssumption
PathAnswer = Unknown | Qualified ... | Conditional ...
```

The review rule is:

```text
covering retained evidence
    -> Qualified

otherwise covering explicit assumption
    -> Conditional

otherwise
    -> Unknown
```

Retained evidence has priority if both are supplied.

## Selected probes

The Lean file checks:

1. the two-day prefix path is `[7, 12]`;
2. completeness evidence through day 2 yields `Qualified ... [7, 12]`;
3. only an assumption through day 2 yields `Conditional ... [7, 12]`;
4. the two answers have equal numerical payload;
5. the two answers themselves are unequal;
6. an assumption-only answer is never marked qualified;
7. no evidence and no assumption remains `Unknown`;
8. an assumption shorter than the requested horizon remains `Unknown`;
9. short evidence plus a covering assumption yields `Conditional`, not `Qualified`;
10. covering evidence wins over a broader assumption;
11. the read-only review preserves its canonical input exactly.

## Architectural hypothesis

If the selected typed boundary survives, the two product directions are not rivals. They answer different questions.

### A. Retained completeness evidence

Potential meaning:

> LOAM has retained a current claim that the Scheduled authority is complete through H for the relevant query scope.

This could support an unconditional **qualified** path inside H, subject to the other Observation 229 boundaries.

But it creates real authority-maintenance pressure:

- how is the claim earned?
- is it global, subject-scoped, or selection-scoped?
- is it historical evidence or replaceable current planning authority?
- how is it revised if an omitted obligation is later discovered?
- must it be atomically coupled to one Scheduled authority image?
- may the horizon retreat as well as advance?

Observation 211 already noted that the whole-file Scheduled publication shape could mechanically carry such a claim in the same authority, but did not qualify that as production design.

### B. Explicit query assumption

Potential meaning:

> Show the derived path **if** the currently retained Scheduled set is treated as complete through H for this query only.

This can remain disposable query provenance:

```text
canonical Scheduled unchanged
+ explicit completeness assumption
-> Conditional path
```

It requires no canonical completeness fact merely to perform the calculation.

The cost is that the answer must remain visibly conditional. It must not be silently relabeled as Known, Qualified, safe-to-spend, or a guaranteed forecast.

## Practical Report Lab consequence

If the result is qualified, the smallest useful dogfood path may be:

```text
production baseline
  Future path: UNKNOWN

optional explicit query
  Assume Scheduled complete through 2026-10-15
        ↓
  Conditional selected-balance path
  Conditional day-boundary low-water
```

The baseline refusal remains intact. The conditional view is an overlay, not replacement evidence.

A human-facing surface should therefore say something closer to:

```text
CONDITIONAL OUTLOOK
Assumption: no additional Scheduled items through 2026-10-15

...

This path is conditional on that assumption.
```

rather than simply `Forecast` or `Known low-water`.

This follows the same no-write provenance boundary already qualified for typed hypotheticals in Observation 185.

## Why this may be preferable before persistence

The assumption route can buy practical observational power without first adding:

- a new canonical fact family;
- a Scheduled persistence version;
- a writer;
- completeness revision rules;
- a generic scenario engine;
- a canonical LiquidityRole.

It therefore makes a good dogfood probe.

If repeated use shows that users constantly supply the same assumption and expect the result to be treated as ordinary retained knowledge, that practical pressure would be evidence in favor of a real maintained completeness claim later.

## What this observation does not earn

Observation 231 does not authorize:

- treating an assumption as evidence;
- converting Conditional into Qualified because the numbers match;
- a production Scheduled completeness authority;
- a final persistence wire format;
- a generic Coverage concept;
- recurrence, Series, Cadence, or generation policy;
- a canonical LiquidityRole;
- an automatic overdue re-date rule;
- intraday low-water without order evidence;
- a claim that Scheduled equals later Actual;
- safe-to-spend authority;
- canonical scenario persistence;
- automatic TUI writes.

## Expected decision boundary

The likely small result is:

```text
EVIDENCE
  may refine Unknown -> Qualified

ASSUMPTION
  may refine Unknown -> Conditional

same numerical path
  does not collapse those two statuses
```

If the Lean probe passes, the next practical move should be to dogfood **B first** as an explicit, read-only conditional report surface. Only if that becomes repeatedly useful should LOAM pressure the maintenance semantics required for **A**.
