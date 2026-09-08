# Observation 231 — Can an explicit completeness assumption substitute for Scheduled completeness evidence?

Status: **QUALIFIED TYPED BOUNDARY — equal payload does not collapse evidence and assumption**

Research baseline: LOAM `406b892a240928a3a9b417967e2c499b32c907ed`

Qualified Lean head: `315cf6210ad38434f25b66ac3309d7bed5a60dce`

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

The practical Report Lab question is:

> If production does not yet retain Scheduled completeness evidence, may a user ask for a useful path by explicitly saying “assume the Scheduled set is complete through H”?

Two candidate inputs can share the same date while having different meanings:

```text
A. retained completeness evidence
   "Scheduled is complete through H"

B. query-local assumption
   "for this calculation, assume Scheduled is complete through H"
```

Observation 231 tests whether B may substitute for A, or whether it must remain visibly conditional even when both produce the same numbers.

## Prior boundaries held fixed

This observation reuses rather than reopens:

- Observation 185: canonical evidence + explicitly typed hypothetical intervention may produce a derived comparison without mutating authority;
- Observation 211: bounded completeness can strengthen absence from Unknown to NotDue inside scope;
- Observation 221: completeness is domain-specific evidence and justified completeness refines information;
- Observation 229: once the future input is qualified, a day-boundary selected balance path is prefix accumulation; selection, intraday ordering, and overdue future timing remain separate evidence boundaries.

The current production TUI therefore remains correct to show `UNKNOWN` when no qualified complete-future input exists.

## Typed answer under test

Observation 231 keeps three result states distinct:

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

## Executed result

The dedicated Observation 231 workflow run `34187272140`, job `101938023203`, completed **SUCCESS** on exact Lean head `315cf6210ad38434f25b66ac3309d7bed5a60dce`.

The Lean probe mechanically checks all selected witnesses:

```text
prefix path                                  [7, 12]
covering evidence                            Qualified [7, 12]
covering assumption only                     Conditional [7, 12]
evidence payload = assumption payload        true
evidence answer != assumption answer         true
assumption-only isQualified                  false
assumption-only isConditional                true
no evidence + no assumption                  Unknown
short assumption                             Unknown
short evidence + covering assumption         Conditional
covering evidence + broader assumption       Qualified
canonical input preserved                    theorem
```

The selected boundary therefore survives.

## Finding

An explicit completeness assumption **cannot substitute for retained completeness evidence as knowledge**.

It can substitute only as a premise for a conditional calculation.

```text
EVIDENCE
  may refine Unknown -> Qualified

ASSUMPTION
  may refine Unknown -> Conditional

same numerical path
  does not collapse those two statuses
```

This is not merely presentation wording. The distinction is typed in the observation and survives equal numerical payload.

## Architectural consequence

The two product directions are not rivals. They answer different questions.

### A. Retained completeness evidence

Potential meaning:

> LOAM has retained a current claim that the Scheduled authority is complete through H for the relevant query scope.

This may support an unconditional **qualified** path inside H, subject to the other Observation 229 boundaries.

But it creates real authority-maintenance pressure:

- how is the claim earned?
- is it global, subject-scoped, or selection-scoped?
- is it historical evidence or replaceable current planning authority?
- how is it revised if an omitted obligation is later discovered?
- must it be atomically coupled to one Scheduled authority image?
- may the horizon retreat as well as advance?

Observation 211 already noted that the whole-file Scheduled publication shape could mechanically carry such a claim in the same authority, but did not qualify that as production design.

### B. Explicit query assumption

Meaning:

> Show the derived path **if** the currently retained Scheduled set is treated as complete through H for this query only.

This can remain disposable query provenance:

```text
canonical Scheduled unchanged
+ explicit completeness assumption
-> Conditional path
```

It requires no canonical completeness fact merely to perform the calculation.

The answer must remain visibly conditional. It must not be silently relabeled as Known, Qualified, safe-to-spend, or a guaranteed forecast.

## Practical Report Lab consequence

The smallest useful dogfood path is now clearer:

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

A human-facing surface should say something closer to:

```text
CONDITIONAL OUTLOOK
Assumption: no additional Scheduled items through 2026-10-15

...

This path is conditional on that assumption.
```

rather than simply `Forecast` or `Known low-water`.

This follows the no-write provenance boundary already qualified for typed hypotheticals in Observation 185.

## Why B is the smaller next dogfood move

The assumption route buys practical observational power without first adding:

- a new canonical fact family;
- a Scheduled persistence version;
- a writer;
- completeness revision rules;
- a generic scenario engine;
- a canonical LiquidityRole.

It therefore earns a practical probe before persistence.

If repeated use shows that the same completeness assumption is constantly re-entered and users expect the result to count as ordinary retained knowledge, that practical pressure would be evidence in favor of a real maintained completeness claim later.

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

## Result

The evidence-vs-assumption fork is resolved narrowly:

```text
A. retained completeness evidence
   -> candidate source for Qualified future-path knowledge
   -> maintenance semantics still unqualified

B. explicit query-local assumption
   -> qualified as a source for Conditional future-path calculation
   -> no persistence or authority required
```

The preferred next practical move is therefore **B first**: dogfood an explicitly labeled, read-only conditional selected-balance path. Only if that surface proves repeatedly useful should LOAM pressure the authority-maintenance semantics required for A.
