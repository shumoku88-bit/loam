# Observation 117: Does an admitted action label determine what the UI must ask next?

## Question

Observation 116 established a first UI boundary:

```text
projection answers what is visible
admission answers what is operable
```

That prevents a UI from deriving terminal actions from `open Scheduled` alone.

A second pressure appears inside one admitted action. The existing practical Scheduled completion writer can be entered from several retained evidence stages:

```text
fresh Scheduled
completion relation retained
completion relation + Actual date retained
```

All three may still admit the completion operation. But the next evidence the human must supply is not identical.

The narrower question is:

> If the UI knows only the admitted action and its label, can it determine what input obligations remain before that action can complete?

## Concrete practical pressure

Current LOAM publication order for Scheduled completion is:

```text
completion relation
  -> Actual date evidence
  -> Actual Event
```

The Event is last, so earlier retained stages remain semantically open to readers.

The practical writer deliberately resumes these stages rather than inventing a second lifecycle object.

Representative states are therefore:

```text
FreshOpen
  evidence: none
  admitted: Complete, Cancel
  Complete still needs:
    Actual date
    Actual movement

InterruptedBeforeDate
  evidence: completion relation
  admitted: Complete / retry
  Complete still needs:
    Actual date
    Actual movement

InterruptedAfterDate
  evidence: completion relation + Actual date
  admitted: Complete / retry
  Complete still needs:
    Actual movement

Completed
  evidence: completion relation + Actual date + Actual Event

Retired
  evidence: retirement
```

The names are synthetic. No private household values are involved.

## Candidate UI surfaces

### Action-only

A minimal admission-aware UI could expose only the admitted actions:

```text
[Complete]
[Cancel]
```

or, after an interrupted completion claim:

```text
[Complete]
```

Observation 116 already showed this is safer than `open => Complete + Cancel`.

But two interrupted stages have the same admitted action set:

```text
InterruptedBeforeDate  -> { Complete }
InterruptedAfterDate   -> { Complete }
```

while the remaining inputs differ.

### Relabeled action

The UI could improve the wording when a completion relation already exists:

```text
[Resume completion]
```

This distinguishes a fresh completion from an interrupted completion.

It still does not distinguish:

```text
completion relation only
```

from:

```text
completion relation + retained Actual date
```

Both can correctly render `Resume completion`, but the first still needs a date and the second does not.

### Obligation-aware action

A richer candidate surface exposes the admitted action together with the evidence still required from the user:

```text
Resume completion
  ? Actual date
  ? Actual movement
```

or:

```text
Resume completion
  ✓ Actual date retained
  ? Actual movement
```

This is intentionally close to a Lean-style hole / goal presentation, but Observation 117 does not introduce a UI framework or a generic proof-state abstraction.

## Alloy model

The bounded model carries only:

- four evidence atoms: completion relation, Actual date, Actual Event, retirement;
- two actions: Complete and Cancel;
- two possible input obligations: Actual date and Actual movement;
- three labels: Complete, Resume, Cancel;
- five representative worlds corresponding to actual practical publication states.

`requiredInputs` follows the current practical writer:

- an admitted completion always needs independently entered Actual movement;
- it needs an Actual date only when retained date evidence is absent;
- Cancel has no modeled input obligation here.

The model compares three retained UI summaries:

```text
admitted action set
labeled admitted action set
admitted action + remaining input obligations
```

## Expected distinction

The two interrupted worlds should provide a counterexample to:

```text
same admitted actions
  -> same remaining input obligations
```

They should also provide a counterexample to:

```text
same action labels
  -> same remaining input obligations
```

because both can be labeled `Resume completion`.

By contrast, if the UI explicitly retains the remaining input obligations for each admitted action, two worlds with the same such surface must agree on those obligations by construction.

## Interpretation boundary

A positive result does **not** mean every disabled action needs an explanatory reason.

In fact, current valid Scheduled states do not yet force a general blocked-reason taxonomy. Observation 116's admitted action set already distinguishes Fresh Open from an interrupted completion claim.

Observation 117 instead asks for a narrower user-facing distinction:

```text
what operation may I perform?
    !=
what evidence must I still provide to finish it?
```

If the bounded counterexample is found, the candidate UI law becomes:

```text
projection  -> what is visible
admission   -> what is operable
obligations -> what is still needed
```

This would support a future Lean-shaped interaction surface without storing UI state or treating prompts as canonical household facts.

## Tool choice

Alloy is sufficient for this observation because the question is structural distinguishability between retained states and UI summaries.

SPIN is deliberately not used here. It becomes more appropriate for the next temporal question, for example:

> after the UI renders an admitted operation, can the world change before activation so that the displayed affordance becomes stale?

That is an interleaving / re-admission problem rather than the static information-sufficiency question studied here.

## Deliberate non-results

Observation 117 does not add:

- a Core `Action` type;
- a Core `Obligation` or `Goal` type;
- a generic disabled-reason taxonomy;
- prompt state persistence;
- a UI framework;
- a TUI widget system;
- layout, color, keyboard, or mouse rules;
- a claim that every application operation has Lean-like holes;
- a claim that input obligations are canonical household facts.

The model only tests whether action identity / wording is sufficient for one real practical completion workflow.
