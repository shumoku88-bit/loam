# Observation 321 — interpretation subject sufficiency

Status: **QUALIFIED BOUNDED ALLOY OBSERVATION — DO NOT PROMOTE TO PRODUCTION YET**

Baseline: `e3a715bd64bca91fea57bffab17c538018175ec0`

## Trigger

Observation 320 qualified a small structural possibility:

- Facts can remain fixed;
- later Reflections can accumulate without erasing earlier ones;
- recording time and an attributed earlier time can remain distinct;
- timestamp order alone need not select one current interpretation.

That does not show that LOAM needs a production `Reflection` object.

Before adding vocabulary, compare the desired household answer with evidence LOAM
already has.

Two especially relevant existing surfaces are:

1. `EventDescription`, which retains opaque Event-scoped human-recognition text;
2. the example-layer `PersonalSemanticMemory`, which composes zero-effect Events,
   descriptions, and explicit corrections to remember text without promoting a
   generic memory ontology into Core.

Production Attention also retains opaque human `context`, but its meaning is a
matter currently requiring attention and its lifecycle is resolved/dropped.

The narrower question is:

> If the same interpretive sentence is already retained as text, is the
> information "this later interpretation is about *that* household Fact"
> reconstructible, or is the subject association independent evidence?

## Why this is not yet a Reflection-type experiment

The candidate in this model is only:

```text
Note -> Fact
```

The Note can be read as an already-retainable text note, for example a
zero-effect Event + EventDescription in the PersonalSemanticMemory experiment.

No dedicated Reflection identity, confidence score, stance type, causal edge,
psychology field, or persistence format is assumed.

## Model boundary

Each bounded World contains:

```text
Fact descriptions
Note text
Attention context
candidate Note -> Fact subject relation
```

There are exactly two household Facts with distinct retained descriptions. This
prevents the counterexample from depending on anonymous/interchangeable Facts.

The two Worlds are forced to agree on all modeled existing evidence:

```text
factDescription
noteText
attentionContext
```

The same Note text is also copied into the ordinary Attention context in both
Worlds.

Only the candidate `subject` relation may differ.

## Household query

The observation asks one concrete query:

> Which later notes / interpretations are about this retained Fact?

Formally:

```text
notesFor(world, fact)
```

If two Worlds have identical currently retained evidence but this answer differs,
then subject attribution is not reconstructible from those surfaces.

## Qualified matrix

GitHub Actions run `35889060574`, Alloy 6.2.0 / Sat4j:

```text
sameExistingEvidenceDifferentSubjectAnswer   SAT
attentionCopyStillCannotSelectSubject         SAT

ExistingEvidenceDeterminesSubject             SAT counterexample
ExplicitSubjectDeterminesPerFactQuery         UNSAT counterexample
```

Interpretation:

- SAT for the first two runs means identical descriptions, note text, and
  Attention context can coexist with different subject answers.
- SAT for `ExistingEvidenceDeterminesSubject` means Alloy found a
  counterexample to the claim that the current text-bearing surfaces determine
  the subject relation.
- UNSAT for `ExplicitSubjectDeterminesPerFactQuery` means no bounded
  counterexample was found once that one relation is fixed.

## Existing LOAM relation boundary

This probe deliberately does **not** reuse production `RelationUnit`.

`RelationUnit` is quantity-bearing provenance rooted in a source Event +
Effect and participates in discharge semantics. A zero-effect interpretive note
does not naturally satisfy that meaning.

Likewise, `EventCorrection` means explicit replacement/correction. Observation
320 already showed that incompatible interpretations may legitimately coexist;
they are not necessarily corrections of one another.

Historical Attention provenance experiments also do not by themselves earn a
production relation vocabulary. Current Core intentionally retains Attention
item + due meaning + closure evidence, with opaque context.

## What this qualified result earns

Only this information-boundary claim:

> If LOAM wants to answer "what later interpretations have I attached to this
> particular Fact?", some explicit subject association must be retained or
> otherwise supplied by evidence that is equivalent to it.

It does **not** yet earn:

- a production `Reflection` type;
- a new canonical file;
- a generic knowledge graph;
- arbitrary Event-to-Event relations;
- automatic AI inference of the subject;
- mandatory note entry;
- a rule that every note has exactly one subject in production.

The surprising small candidate is not "Reflection". It is just **subject
attribution**.

## Next pressure

If the subject association survives, the next independent question should be
temporal:

> Does the recording time of an interpretation carry household meaning that
> cannot be reconstructed from the subject Fact's own occurrence/validity time?

That should be tested separately rather than bundled into this observation.
