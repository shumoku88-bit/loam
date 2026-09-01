# Observations 079–084 checkpoint — Context-relative sufficiency

## Purpose

Observations 079–084 form a coherent sub-arc, but they do not earn a new Observation 085 or a generic `Summary` framework.

The important checkpoint is that a principle already visible near the beginning of LOAM has returned at a different layer.

Observations 004, 005, and 029 studied retained household history and established a vocabulary-relative notion of sufficiency:

```text
history
  -> future operation vocabulary
  -> observable distinctions
  -> sufficient retained state
```

The recent observations apply the same pressure to formal checking, later result reuse, and privacy-safe real-data observation:

```text
world / formal run / private relation
  -> retained projection
  -> later question
  -> sufficient retained evidence
```

This audit records that recurrence without promoting it into a new Core abstraction.

## 1. The earlier law returning

### Observation 004 — sufficient memory follows the future question

Observation 004 showed that compression quality is not determined only by summary size.

A count of continuity facts could be too coarse even when it retained as much numeric information as a targeted Boolean. One targeted bit was sufficient for the one future distinction the chosen operation vocabulary could observe.

The stronger result was already:

> A useful state summary may be the smallest information that preserves the distinctions the future is allowed to observe.

Change the future vocabulary and the sufficient retained state may change with it.

### Observation 005 — vocabulary induces observational equivalence

Observation 005 enlarged the future vocabulary and observed more distinguishable history classes behind the same current placement.

The emerging shape was:

```text
history
  -> future operation vocabulary
  -> observable equivalence classes
  -> sufficient retained state
```

A retained state can therefore be viewed as a quotient of history by distinctions that the admitted future questions cannot observe.

### Observation 029 — the shape survives generalization

Observation 029 moved this from finite examples into Lean.

For vocabularies `small ⊆ large` it proves that:

- observational equivalence under `large` implies observational equivalence under `small`;
- a summary sufficient for `large` remains sufficient for `small`;
- equal encodings under a sufficient summary are invisible to every question in that vocabulary.

The important boundary is:

> New memory becomes necessary when a later vocabulary exposes a distinction that the current retained projection collapses.

There is no claim that one globally minimal summary exists independently of the questions that may later be asked.

## 2. What Observations 079–084 add

The recent sub-arc does not replace that earlier law. It gives it concrete operational pressure outside household state.

### Observation 079 — interpretation is context-relative

Retaining only a raw checker token loses what the checker said.

```text
SAT / UNSAT / SUCCESS
    !=
semantic interpretation
```

The later question matters even inside one checker vocabulary. The context sufficient to answer:

```text
What did this check say about the proposition?
```

is not the same projection as the context sufficient to answer:

```text
Why did CI qualify this check as successful?
```

So there is already no single universal check-receipt projection forced by the experiment.

### Observation 080 — epistemic strength is regime-relative

A retained claim family and workflow `SUCCESS` do not determine what was established when checking regime, finite scope, or theorem premises are forgotten.

The concrete LOAM history contains both outcomes:

- bounded Alloy support that later becomes an unbounded Lean theorem under explicit premises;
- bounded Alloy support for a generalization that later admits an infinite Lean counterexample.

Thus:

```text
bounded no-counterexample
    !=
unbounded theorem
```

and the checking contract participates in the meaning of the retained result.

### Observation 081 — applicability is later-question-relative

The same retained correction knowledge permits different reuse decisions for different later correction shapes.

```text
0 corrections   -> recorded aggregate may be used
1 correction    -> single-correction projection may be used
2+ corrections  -> fail closed
```

The retained result bundle alone does not determine applicability.

The later question is not incidental metadata. It is one of the coordinates that determines whether a retained result answers the current problem.

### Observation 082 — a safe aggregate can preserve pressure while losing provenance

The private Plan-realization observer intentionally projects explicit realization relations into a sanitized joint aggregate.

That aggregate still preserves useful structural pressure and link cardinality, but it does not reconstruct which identities participate in the realization relation.

```text
privacy-safe structural summary
    !=
realization provenance
```

This is not a defect in the observer. The lost distinction is deliberate. It becomes a defect only if a later question silently assumes that the lost provenance is still available.

### Observation 083 — separately adequate views can lose a joint question

A joint summary determines its separate marginals, but the marginals do not in general determine the joint summary.

```text
summary(A × B)
    -> summary(A) + summary(B)

summary(A) + summary(B)
    -/-> summary(A × B)
```

So two retained summaries may each be sufficient for their own one-dimensional questions while being insufficient for a later cross-dimension question.

This is correlation loss rather than provenance loss.

### Observation 084 — even the repair is query-shape dependent

Observation 084 asks whether retaining one additional joint cell repairs the correlation loss.

The answer depends on the joint shape:

```text
2 × 2:
  marginals + one joint anchor
      -> whole joint table

3 × 3:
  marginals + one joint anchor
      -/-> whole joint table
```

Lean proves the positive 2 × 2 integer law. Alloy and J expose the 3 × 3 counterexample.

The important result is not the number one. It is that the amount and arrangement of retained cross-evidence sufficient for a later question can itself depend on the shape of that question.

## 3. One common structure

Across the early and recent observations, the same structure now appears twice.

### First appearance — household history

```text
history
  -> retained state
  -> future operation
  -> answer
```

A state representation is sufficient only relative to the distinctions the future operation vocabulary can observe.

### Second appearance — formal and observational evidence

```text
formal run / private relation / source world
  -> retained result or projection
  -> later interpretation or query
  -> answer
```

A retained result or summary is sufficient only relative to the distinctions the later question can observe.

This suggests a common design discipline:

```text
later question / vocabulary
    -> distinctions that must survive
    -> retained evidence sufficient for those distinctions
```

rather than:

```text
invent one canonical summary
    -> reuse it everywhere
    -> assume forgotten distinctions never matter
```

The audit deliberately calls this **context-relative sufficiency** only as a description of the recurring pattern. It does not introduce `ContextRelativeSufficiency`, `Summary`, `Question`, or `Evidence` as Practical Core concepts.

## 4. What is genuinely new in 079–084

If the abstract law was already visible in 004/005/029, why retain 079–084 separately?

Because the newer observations exercise different operational boundaries that the early household-history experiments did not cover.

They show that the same law matters for:

1. **formal-result interpretation** — raw tool outcomes need their checking contract;
2. **epistemic strength** — bounded search, theorem checking, scope, and premises cannot be collapsed into one `SUCCESS` fact;
3. **implementation reuse** — an old result does not grant context-free permission for a later operation;
4. **privacy-safe observation** — a deliberately lossy aggregate can remain useful without becoming canonical semantic state;
5. **cross-dimension queries** — composing or marginalizing safe summaries can erase association needed later;
6. **query shape** — the evidence that repairs one collapsed distinction need not repair a larger shape.

The sub-arc therefore validates the old vocabulary-relative sufficiency principle in the exact surfaces where a human and AI collaborator may later be tempted to over-reuse compact retained results.

## 5. Private realization dogfood

Observation 084 has now been applied through the existing private Plan-realization shadow boundary.

The public tool chain remains layered:

```text
private canonical source
    -> private-plan-realization-shadow
    -> sanitized joint aggregate
    -> private-plan-realization-summary-sufficiency.py
    -> structural sufficiency result only
```

The outer checker does not parse private canonical meaning itself. It consumes only the already-sanitized joint matrix and the inner shadow's privacy/read-only confirmations.

For the current private snapshot, the retained separate marginals do not uniquely determine the observed joint aggregate, and no single observed joint-cell anchor is sufficient to make that aggregate unique.

That is snapshot-specific reality pressure, not a universal minimal-summary theorem.

The dedicated public synthetic qualification also contains an effective 2 × 2 case in which a single-cell anchor *is* sufficient. This prevents the dogfood checker from degenerating into a hard-coded `insufficient` answer and keeps the 084 shape distinction executable.

No private identities, dates, descriptions, quantities, Locus/Measure values, source metadata, or raw source text are required in public CI or this audit.

## 6. Practical Core audit

Observations 079–084 and their private dogfood add no domain primitive.

```text
Practical Core additions:             0
Persistence additions:                0
CLI additions:                        0
wire-format additions:                0
generic receipt/summary abstractions: 0
```

The diagnostic sufficiency checker added after Observation 084 is tooling around a sanitized observer boundary. It is not canonical household state and does not widen Practical Core semantics.

## 7. Deliberately unearned abstractions

This checkpoint does not earn:

- `Summary` as a universal domain type;
- `Context` as a universal semantic container;
- `CheckReceipt`;
- `ReuseReceipt`;
- `Applicability`;
- `ProofDatabase`;
- `Evidence` as one cross-domain object;
- `Anchor` or `Correlation` primitives;
- a universal observer algebra;
- one fixed minimal-summary formula;
- a general privacy framework;
- a Plan or realization store;
- a semantic-OS proof/evidence kernel.

The repeated result is almost the opposite: a field or representation is justified only by the later distinction that observes it.

## 8. Checkpoint

The current sub-arc closes as:

```text
004 / 005
  question vocabulary shapes sufficient memory
        ↓
029
  vocabulary-relative sufficiency survives generalization
        ↓
079 / 080
  checker meaning and epistemic strength require retained contract
        ↓
081
  reuse requires later-question context
        ↓
082 / 083
  privacy projection loses provenance, then correlation
        ↓
084
  sufficient repair is itself query-shape dependent
        ↓
private dogfood
  the 084 boundary survives current real structural pressure
```

No Observation 085 is needed merely to name this pattern.

## 9. Next pressure

A future Observation should open only when a concrete later operation or query exposes a distinction that current retained evidence collapses.

In particular, do not immediately generalize the 2 × 2 / 3 × 3 arithmetic into a universal contingency-table framework merely because such a theorem is mathematically available. Observation 029 already supplies the broader vocabulary-relative sufficiency law that matters architecturally.

Useful future pressure may come from an actual human/AI reuse decision, a new private shadow query, or a practical operation whose answer cannot be justified from the currently retained evidence. Until then, the current checkpoint is sufficient.