# Observation 081 — Can a retained formal result be reused without the later question context?

## Question

Observations 079 and 080 established two information-loss boundaries:

```text
raw result != semantic interpretation

claim family + workflow SUCCESS != what was established
```

Those observations concerned the meaning of a formal result itself.

A different pressure appears when an old result is used later to make a new implementation decision:

> If the retained formal results are known, but the shape of the later question is forgotten, is applicability still recoverable?

## Concrete reuse pressure

PR #139, `feat(cli): expose single-correction effective quantities`, deliberately reused earlier LOAM work instead of opening another structural Alloy experiment.

The current code retains a narrow practical boundary:

```text
0 corrections
  -> show recorded aggregate

1 correction
  -> use the earned single-correction quantity projection

2+ corrections
  -> fail closed; a frontier projection is still required
```

This boundary is not an arbitrary UI policy.

`Loam.Core.CorrectionQuantity.quantityAtEffective?` explicitly states that it is a single-correction projection. It does not fold a correction chain, choose among sibling corrections, apply a conflict-resolution rule, or infer chronology from storage order.

`Loam.Core.EventCorrection.UnresolvedCorrection` also retains the older sibling-conflict boundary: several distinct correction branches may remain simultaneously possible, and representation order cannot choose a winner.

So the same body of retained LOAM knowledge is relevant to several later effective-quantity questions, but it does not authorize the same action in every later context.

## Experiment

The Alloy model does not encode a universal proof database or a generic applicability calculus.

It models only the current practical boundary as three later question shapes:

```text
ZeroCorrections
SingleCorrection
MultipleCorrections
```

and three already-retained result roles:

```text
RecordedAggregateLaw
SingleCorrectionQuantityLaw
SiblingConflictLaw
```

The retained knowledge bundle is identical for every later question.

The model asks whether forgetting the later correction shape forces one context-free reuse decision.

### Expected witness

A current practical witness should exist in which:

```text
ZeroCorrections      -> reusable
SingleCorrection     -> reusable
MultipleCorrections  -> not reusable
```

### Expected counterexample

The assertion

```text
same retained knowledge
    ->
same reuse decision
```

should have a counterexample.

### Narrow control

Within this deliberately small model, retaining both:

```text
retained knowledge + later correction shape
```

should determine the modeled reuse decision.

This control is not a claim that `CorrectionShape` is a universal field for future formal-result receipts.

## Expected boundary

If the model behaves as expected, Observation 081 earns only this negative result:

> Applicability is not a property of a retained formal result alone. It is a relation between retained result context and the later question to which someone wants to apply it.

That would extend the preceding observations:

```text
079: result token alone loses interpretation
080: claim/result without checking regime loses epistemic strength
081: retained result without later-use context loses applicability
```

A future human/AI work surface therefore cannot safely turn "proved before" or "observed before" into a context-free permission to reuse a conclusion.

## Non-goals

This observation does not earn:

- a generic `Applicability` type;
- a `ProofDatabase`;
- a `CheckReceipt` or `ReuseReceipt`;
- one universal set of later-context fields;
- a rule that every practical implementation requires a new formal check;
- a claim that the three correction shapes exhaust future correction semantics;
- a semantic-OS kernel primitive.

The current question is only whether PR #139's already-existing reuse boundary survives if the later question shape is projected away.

## Practical Core impact

None.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no correction-law change;
- no new cross-tool schema.
