# Future-context retention checker — research checkpoint

Status: **LEAN-CHECKED RESEARCH CHECKPOINT**

Date: **2026-09-23**

Baseline:

```text
2446b633e8ebe25cc53ef29c337fe775d57c3c55
experiment: measure distinct-collision search across real semantics (#1168)
```

This note records the current state of the future-context semantic-compression
thread after Observations 192 and 297–303 and the bounded-search work merged
through PR #1168.

It is not a paper draft and does not claim mathematical novelty. Its purpose is
to freeze the present result before further exploration changes the shape of the
work.

## 1. Current research question

The present question is:

> When a candidate summary identifies two retained semantic states, can a bounded
> set of allowed future contexts expose a distinction that the summary discarded,
> while keeping only a small semantic checker inside the trusted proof boundary?

The practical version is:

> If we throw this information away because two states look the same now, can an
> allowed future operation make the discarded distinction observable later?

This is narrower than event sourcing in general, provenance in general, or
state minimization in general.

## 2. Core semantic vocabulary

The generic ingredients are:

```text
State      S
Operation  O
Question   Q
Answer     A
Summary    M

answer : S -> Q -> A
step   : S -> O -> S
encode : S -> M
V      : Q -> Prop
```

Observation 192 supplies the central future-context notions.

### FutureEquivalent

Two states are future-equivalent when no selected question can distinguish them
after any common finite continuation of allowed operations.

Informally:

```text
left ~F right
iff
for every continuation c and selected question q,
answer (run left c) q = answer (run right c) q
```

### FutureSufficient

A summary is future-sufficient when equality of summaries never collapses states
that the selected future contexts can distinguish.

The useful necessary condition is:

```text
encode left = encode right
        +
left and right are not FutureEquivalent
        =>
encode is not FutureSufficient
```

That implication is the semantic target of the executable counterexample path.

## 3. What is already generic and Lean-checked

The current generic foundation includes:

1. vocabulary-relative current observational equivalence;
2. future-context equivalence;
3. future equivalence refining current equivalence;
4. step stability of future equivalence;
5. the greatest sound step-stable relation characterization;
6. the necessary condition that a future-sufficient summary may collapse only
   future-equivalent states;
7. a positive maintained-certificate route through Observation 297 / 298;
8. a negative concrete-counterexample route through Observation 298;
9. sound bounded search through Observation 299.

The negative path is currently the more developed executable side.

## 4. Trusted checker boundary

Observation 298 separates exploration from semantic trust.

A candidate counterexample contains:

```text
left state
right state
common continuation
terminal question
```

The checker verifies the semantic obligations needed for a real witness,
including:

```text
same candidate summary now
        +
selected terminal question
        +
different answers after the same continuation
```

A returned payload does not become a theorem merely because the explorer found
it. It must pass the checker.

The architecture is therefore:

```text
possibly heuristic / bounded / incomplete explorer
                    |
                    v
           candidate payload
                    |
                    v
        small Lean semantic checker
                    |
              +-----+-----+
              |           |
           reject       accept
                          |
                          v
             ValidCounterexample
                          |
                          v
                 not FutureSufficient
```

This division is important because future explorers may become more complicated
without enlarging the semantic trust boundary.

## 5. Current explorer pipeline

The present executable pipeline has accumulated in small steps:

```text
semantic seeds
      |
      v
domain-specific world realization
      |
      v
finite SearchSpace
      |
      v
candidate summary
      |
      v
distinct state pairs whose summaries collide
      |
      v
bounded common future continuations
      |
      v
candidate payload
      |
      v
Observation-298 checker
      |
      v
certified counterexample
```

### 5.1 Finite semantic slices

`SearchSpace` does not require whole-domain `Fintype` instances.

Real LOAM states contain open-ended identities, strings, quantities, and other
unbounded values. The experiment instead chooses a finite semantically relevant
slice:

```text
states
operations
questions
maximum continuation depth
```

### 5.2 Semantic seeds

`SearchSpace.fromSeeds` separates compact domain-specific choices from the full
worlds they generate.

Examples already used include:

- target quantities for Correction worlds;
- source identities for document-provenance worlds;
- endpoint-consumption choices for Actual reversal worlds.

The seed-to-state realization remains domain-specific.

### 5.3 Summary-collision filtering

The explorer first removes state pairs that the candidate summary already
distinguishes.

This is an optimization outside the trusted boundary.

### 5.4 Distinct unordered collisions

The current narrowest explorer removes:

- self-pairs;
- symmetric duplicates such as both `(A,B)` and `(B,A)`.

It enumerates each distinct pair once by finite-list position, so it does not
need `DecidableEq State`.

The semantic checker remains unchanged.

## 6. Executable case studies

The same search/check path now runs over three intentionally different relation
meanings.

### 6.1 EventCorrection

Meaning:

```text
target -> replacement
supersession / effective-frontier selection
```

Candidate summary:

```text
current correction-effective quantity
```

Two generated worlds currently summarize to the same quantity, but the same
future Correction exposes a different later quantity.

Result:

```text
not FutureSufficient
```

### 6.2 DocumentDerivation

Meaning:

```text
source -> derived
provenance without supersession
```

Candidate summary:

```text
current selected two-step provenance answer
```

Two worlds currently answer the selected provenance question equally, but one
common future derivation edge makes the answer diverge.

Result:

```text
not FutureSufficient
```

This example is intentionally independent of EventCorrection.

### 6.3 ActualReversalMemory

Meaning:

```text
target -> explicit inverse Event
both endpoints remain historical facts
endpoint identities may participate only once
```

Candidate summary:

```text
current selected reversal-provenance answer
```

One world has already consumed an endpoint identity and the other has not. Both
currently give the same selected answer. The same future reversal publication is
rejected in one world and admitted in the other.

Result:

```text
not FutureSufficient
```

This probe is deliberately limited to retained Core reversal-memory semantics.
It does not model the complete production reversal publisher.

## 7. Search reduction measured so far

Observation 303 demonstrates the explorer reductions on the synthetic reveal
fixture:

```text
all ordered state pairs                    18 payloads
current-summary-colliding ordered pairs    10 payloads
distinct unordered summary collisions       2 payloads
```

PR #1168 then checks the narrowest explorer against the three semantic case
studies above.

For each two-world, one-operation, one-question, depth-one fixture:

```text
original ordered search                     8 payloads
distinct unordered summary-collision search 2 payloads
```

In all three cases the narrower explorer still finds a checker-certified
counterexample.

These are exact counts for the selected bounded fixtures, not scalability
benchmarks.

## 8. What the current result supports

The current evidence supports the following restrained statement:

> A candidate summary can be tested against a caller-selected finite semantic
> slice by looking specifically for distinct states that the summary collapses,
> exploring bounded common future continuations, and checking any discovered
> distinguishing payload with a small Lean-verified semantic checker.

It also supports a design lesson:

> Equality of today's selected answers is not, by itself, evidence that retained
> distinctions may safely be discarded when future operations can expose them.

The reusable artifact beginning to emerge is therefore not an accounting
feature. It is a small **future-context semantic retention checker**.

## 9. What is not established

The current work does **not** establish:

1. that `FutureEquivalent` is new mathematics;
2. that bounded search is complete outside the supplied finite slice and depth;
3. that the explorer scales to large real histories;
4. that semantic seeds can be generated automatically in general;
5. that the returned continuation is globally minimal;
6. that a lack of bounded counterexample proves `FutureSufficient`;
7. that the positive maintained-certificate route can be synthesized
   automatically;
8. that the three current relation families establish domain-independent
   universality;
9. that LOAM has found a globally minimal retained state;
10. that this work is ready for a strong paper claim without a deeper literature
    comparison.

## 10. Negative and positive sides must remain separate

The current negative side is:

```text
find one valid future distinction
        =>
summary is not FutureSufficient
```

This is naturally search-friendly.

The positive side is stronger:

```text
prove every allowed future context preserves the required observations
        =>
summary is FutureSufficient
```

Observation 298 already has a maintained-certificate boundary, but automatic
certificate discovery is not the same problem as counterexample search.

Do not treat bounded failure to find a counterexample as a positive certificate.

## 11. Relationship to the older publication map

`FUTURE_CONTEXT_SEMANTIC_COMPRESSION_PUBLICATION_MAP_2026-09.md` records the
broader mathematical and literature-facing argument through the earlier
future-context work.

This checkpoint adds the later executable layer:

```text
FutureEquivalent / FutureSufficient
              |
              v
      counterexample protocol
              |
              v
        bounded SearchSpace
              |
              v
        semantic seeds
              |
              v
     summary-collision filtering
              |
              v
 distinct collision-pair exploration
              |
              v
 three semantic case studies
```

The two notes should not be collapsed yet:

- the publication map asks what claim might eventually be defensible;
- this checkpoint records what the current executable artifact actually does.

## 12. Next research gates

### Gate 1 — larger bounded slices

Before adding a more elaborate explorer, test more than two semantic worlds and
more than one possible operation.

Questions:

- Does collision filtering still reduce the candidate set materially?
- How does the count grow with summary-class size and continuation depth?
- Does the first witness remain easy to find?

This would turn the present exact toy-sized counts into the beginning of an
evaluation.

### Gate 2 — constraint-directed seed generation

Today the human still chooses semantically meaningful seeds.

A next step may be to specify conditions such as:

```text
same current summary
AND
different retained evidence
```

and generate bounded seed candidates satisfying those conditions.

This should remain domain-directed rather than introducing a generic world DSL
without pressure.

### Gate 3 — positive certificates

Explore one real case where a non-injective summary is actually
`FutureSufficient` for a declared operation/question vocabulary.

A positive case would prevent the research thread from becoming only a
counterexample generator.

### Gate 4 — literature comparison

Compare the exact executable shape against work on:

- Myhill-Nerode / right congruences;
- behavioural equivalence and bisimulation;
- database view complements and update independence;
- abstract interpretation;
- model checking and counterexample generation;
- event-sourced log/state compaction;
- provenance under updates.

The relevant question is not whether these fields exist. It is whether one of
them already gives essentially the same retained-summary criterion and
search/check architecture.

### Gate 5 — extraction pressure

Do not split this work into a standalone library merely because it now looks
generic.

Extraction is earned when another project or a substantially different LOAM
domain needs the same machinery without importing household-specific research
surface.

## 13. Recommended stop condition

This is a good checkpoint.

Do not immediately add another relation example merely to increase the count.
The current three already separate:

```text
supersession
unrestricted provenance
endpoint-unique inverse provenance
```

The next useful evidence should answer a new question rather than repeat the
same one.

The current shape to preserve is:

```text
few assumptions
small semantic vocabulary
explicit bounded explorer
small trusted checker
clear negative claim
no universality claim
```

That is the strongest current form of the work.
