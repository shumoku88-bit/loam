# Future-context semantics: theory correspondence map

Date: 2026-09-23  
Status: research checkpoint after Observations 304–317  
Scope: literature correspondence only; no novelty claim

## Executive conclusion

The future-context thread in LOAM now sits inside a well-developed family of ideas from automata theory, model-based testing, active automata learning, coalgebra, and abstract interpretation.

The strongest correspondence is:

```text
LOAM FutureEquivalentUnder
    ~ Nerode / behavioural equivalence under all admitted futures

LOAM FutureCharacterizingSetUnder
    ~ characterization set / W-set / finite distinguishing experiment set

LOAM finiteContextProfile / boundedBehaviourSignature
    ~ finite observation-table row / finite behavioural signature

LOAM FiniteFutureQuotientUnder
    ~ finite index of behavioural equivalence, represented by finitely many classes

LOAM ExactFutureClassifierUnder
    ~ any encoding whose kernel is exactly the behavioural equivalence
```

The important caution is that LOAM's `FutureContextBasisUnder` is **strictly stronger** than a standard characterization set. A W-set only needs its experiments collectively to distinguish every inequivalent state pair. LOAM's basis additionally requires every admitted future observation to be uniformly identical, on every retained state, to one listed representative context.

Thus the most defensible interpretation is not "LOAM discovered a new Myhill–Nerode theorem." It is:

> LOAM has independently reconstructed and Lean-certified a vocabulary-relative behavioural quotient / finite-characterization architecture for retained-evidence semantics, while also exposing a stronger representative-context basis property that should be kept distinct from ordinary characterization sets.

The next research value is in the **combination and application boundary**, not in adding another example or inventing a generic W-set minimizer.

---

## 1. Myhill–Nerode and future equivalence

Classical Myhill–Nerode equivalence identifies two prefixes when every possible continuation gives the same acceptance result. Finite index of that equivalence is equivalent to finite-state recognizability.

A representative modern statement for timed automata also makes the same pattern explicit: recognizability is characterized by finite quotient index, and finite index yields a finite set of distinguishing extensions.

References:

- Myhill–Nerode overview and finite-index characterization:
  https://en.wikipedia.org/wiki/Myhill%E2%80%93Nerode_theorem
- Active Learning of Deterministic Timed Automata with Myhill-Nerode Style Characterization:
  https://link.springer.com/chapter/10.1007/978-3-031-37706-8_1
- Algebraic Myhill–Nerode Theorems:
  https://www.sciencedirect.com/science/article/pii/S0304397510005785

LOAM's corresponding definition is:

```text
FutureEquivalentUnder answer step operationVocabulary questionVocabulary left right
```

which requires equality after every admitted finite operation continuation and every admitted terminal question.

A useful normalization is to view one LOAM state as a Moore-style behaviour:

```text
behaviour(state)(continuation)(question)
  = answer (run step state continuation) question
```

Then:

```text
FutureEquivalentUnder left right
iff
behaviour(left) = behaviour(right)
```

up to the declared operation/question vocabularies.

### What is standard

- equivalence by agreement under all future experiments;
- quotienting state by that equivalence;
- finite index as the meaningful finite-state boundary;
- exact state encodings whose equality fibers coincide with behavioural equivalence.

### What LOAM changes in presentation

LOAM separates the future language into two declared coordinates:

```text
OperationVocabulary
    ×
QuestionVocabulary
```

rather than treating the observable as one fixed accept/reject predicate.

This is naturally interpretable as a deterministic transition system with a family of terminal observations. It is useful for LOAM, but should not currently be presented as a new automata-theoretic construction.

---

## 2. FutureCharacterizingSetUnder and the classical W-set

The closest literature match to `FutureCharacterizingSetUnder` is the **characterization set**, commonly called the **W-set**, from finite-state-machine testing.

Chow's 1978 W-method describes a characterization set as input sequences that distinguish the behaviour of every pair of states in a minimal automaton.

Reference:

- T. S. Chow, "Testing Software Design Modeled by Finite-State Machines", IEEE TSE, 1978:
  https://archiv.infsec.ethz.ch/intranet_secured/r/1/chow-testingFSMs.pdf

A recent categorical generalization states the DFA condition in essentially kernel form:

> if two states agree on the characterization set, they agree on the full language behaviour.

Reference:

- Complete Test Suites for Automata in Monoidal Closed Categories:
  https://link.springer.com/chapter/10.1007/978-3-031-90897-2_10

That is extremely close to Observation 315:

```text
EquivalentOnContexts ... contexts left right
    iff
FutureEquivalentUnder ... left right
```

So the terminology "future-characterizing set" is well aligned with existing usage.

### Important difference in the experiment type

A classical DFA W-set usually consists of input words.

A LOAM future context is:

```text
(List Operation, Question)
```

so an experiment means:

1. execute a finite admitted future operation sequence;
2. ask one admitted terminal question.

That is a natural generalization of a distinguishing suffix to a transition-plus-observation experiment.

Recent work on pomset recognizers explicitly defines characterization sets as **sets of contexts**, not merely strings, which reinforces that "context" is established terminology in more general automata settings.

Reference:

- Active Learning Techniques for Pomset Recognizers:
  https://link.springer.com/chapter/10.1007/978-3-032-22730-0_27

---

## 3. FutureContextBasisUnder is stronger than a W-set

Observation 315 already proved this internally, and the literature comparison confirms the distinction is worth preserving.

A standard characterization set requires:

```text
if two states agree on all selected experiments,
then they are behaviourally equivalent
```

It does **not** require every possible experiment to be semantically identical to one selected experiment.

Observation 314's `FutureContextBasisUnder` requires the stronger property:

```text
for every admitted future context c,
there exists selected context b
such that
for every retained state s,
    answer(s, b) = answer(s, c)
```

This is a uniform factorization of the entire observation family through finitely many representative columns.

Therefore:

```text
FutureContextBasisUnder
        =>
FutureCharacterizingSetUnder
```

but not conversely.

The Observation 315 x/y/xor witness is exactly the right separator:

- x and y together characterize all behaviour;
- xor is determined by the pair;
- xor is not uniformly identical to x or y individually.

### Stronger literature match: context-side equivalence / left automata equivalence

A more precise match is available than the generic phrase "stronger W-set."

Define semantic equivalence on admitted future contexts by equality of their complete
observation columns:

```text
context₁ ≈obs context₂
iff
for every retained state s,
  contextAnswer s context₁ = contextAnswer s context₂
```

Then `FutureContextBasisUnder` says exactly:

1. every listed context is admitted; and
2. every admitted context is `≈obs`-equivalent to at least one listed context.

So the "basis" is a **finite representative cover of the context-side observational
equivalence classes**. If duplicate representatives are removed, it is a complete
set of representatives, or transversal, of those classes.

This gives a clean row/column distinction:

```text
behaviour matrix
  rows    = retained states
  columns = admitted future contexts
  cells   = answers

FutureCharacterizingSetUnder:
  choose enough columns to preserve all row distinctions

FutureContextBasisUnder:
  choose representatives for all distinct column behaviours
```

This explains exactly why the basis condition is stronger than a W-set. A W-set
does not need to represent every semantically distinct experiment column; it only
needs enough columns jointly to separate every behaviourally distinct state pair.

There is also a direct classical automata specialization.

For a Boolean DFA observation with accepting-state set `F`, an input word `u`
induces the observation column

```text
q ↦ [δ(q,u) ∈ F]
```

Two words have the same column exactly when they have the same predecessor set
of final states:

```text
pre_u(F) = pre_v(F)
```

Ganty, Gutiérrez, and Valero call this the **left automata-based equivalence**.
Their Definition 11 defines

```text
u ~ᴸ_N v  iff  pre_u^N(F) = pre_v^N(F)
```

and proves that it is a finite-index left congruence for finite automata. They
also distinguish it from the language-based left Nerode equivalence and explain
the duality with right congruences.

Reference:

- Pierre Ganty, Elena Gutiérrez, Pedro Valero,
  "A Congruence-based Perspective on Automata Minimization Algorithms",
  MFCS 2019:
  https://arxiv.org/abs/1906.06194
  (especially Definitions 9 and 11)

For an accessible DFA, equality of these predecessor sets is equivalent to
equality under every possible left prefix, so this also meets the language-side
left Nerode view. For arbitrary LOAM retained states, which are not introduced
as states reachable from one distinguished initial state, the **automata-based
left equivalence** is the more faithful analogue.

LOAM generalizes the experiment carrier from one Boolean suffix to:

```text
(List Operation, Question)
```

with arbitrary Answer. Thus the safest description is:

> `FutureContextBasisUnder` is a finite representative cover of
> context-observation equivalence; in the single-question Boolean DFA case this
> specializes to representatives of the left automata-based equivalence classes.

### Research implication

Do not call `FutureContextBasisUnder` "the W-set condition."

The current evidence suggests that "basis" is LOAM terminology for a standard
kind of **complete representative set on the experiment side**, rather than a
new characterization-set concept. The exact multi-question, arbitrary-answer
generalization may not have one universally dominant name, but its mathematical
shape is now clear enough that a novelty claim about the condition itself would
be inappropriate.

---

## 4. BoundedBehaviourSignature and active automata learning

Observation 308's bounded behavioural signatures are structurally close to the rows of an L* observation table.

Angluin's L* algorithm uses:

- prefixes as candidate states;
- suffixes as distinguishing experiments;
- a finite row of answers to those suffixes as the current state signature.

Reference:

- Dana Angluin, "Learning Regular Sets from Queries and Counterexamples", Information and Computation 75(2), 1987.
- A recent summary with the same observation-table structure:
  https://dl.acm.org/doi/10.1145/3793654.3793755

A recent automata-learning description states explicitly that columns are suffixes applied in the reached state and serve as differentiators.

LOAM:

```text
bounded contexts
    ->
boundedBehaviourSignature state
    ->
candidate equality partition
```

is therefore very close to an observation-table row semantics.

### Important LOAM difference

LOAM currently does **not** implement L*.

It does not assume:

- a minimally adequate teacher;
- membership queries;
- equivalence queries;
- closed / consistent observation tables;
- automatic convergence to a minimal automaton.

Instead the architecture is:

```text
bounded finite exploration proposes
            +
independent Lean theorem certifies
            =
trusted unbounded semantic statement
```

This synthesis/certification split is worth retaining as a system-design contribution even though the ingredients are established.

---

## 5. Observation 317 and finite index

Observation 317 proves two directions.

### Forward direction

A finite list of representatives covers every `FutureEquivalentUnder` class:

```text
∀ state,
  ∃ representative in representatives,
    FutureEquivalentUnder state representative
```

Then choose one distinguishing admitted context for each inequivalent representative pair.

Because there are finitely many representative pairs, this yields a finite future-characterizing set.

This is the familiar finite-index -> finite-distinguishing-experiments argument.

The timed-automata Myhill–Nerode paper gives an especially close published formulation: finite recognizable quotient yields a finite set of distinguishing extensions.

Reference:

https://link.springer.com/chapter/10.1007/978-3-031-37706-8_1

### Reverse direction

If a finite future-characterizing set exists and the answer space is explicitly covered by a finite list, then only finitely many answer profiles can occur. Choosing one retained representative per realized profile yields a finite cover of all behavioural classes.

This is again classical finite-signature reasoning.

### What is useful in LOAM

The raw `State` type is not assumed finite.

The finite object is the **behavioural quotient**:

```text
possibly unbounded retained state
            |
            v
FutureEquivalentUnder
            |
            v
finite representative cover
```

This is conceptually important for retained histories, but generalized Myhill–Nerode and coalgebraic theory already make clear that a large or infinite carrier may admit a finite behavioural quotient.

Therefore this should be framed as a clean Lean instantiation / specialization, not a new finite-index theorem.

---

## 6. ExactFutureClassifierUnder and quotient representations

`ExactFutureClassifierUnder` says:

```text
encode left = encode right
iff
FutureEquivalentUnder left right
```

This is best understood as:

> `encode` has exactly the same kernel relation as the full behavioural semantics.

Observation 314's theorem that any two exact classifiers have the same fibers is then immediate quotient uniqueness at the level of state-pair equality.

This is closely related to:

- minimal automaton state equivalence;
- quotienting by Nerode equivalence;
- minimal coalgebras / logical equivalence in coalgebra learning.

Reference:

- Coalgebra Learning via Duality:
  https://link.springer.com/chapter/10.1007/978-3-030-17127-8_4

For expressive logics, that work explicitly identifies logical and behavioural equivalence and discusses minimality with respect to behavioural equivalence.

Again, the safest claim is correspondence rather than novelty.

---

## 7. Coalgebraic behavioural equivalence

Coalgebra supplies a broader home for the idea that system states are identified by observable future behaviour.

Relevant literature explicitly treats behavioural equivalence for automata, transition systems, Moore machines, and related state-based systems.

References:

- Coalgebraic Methods in Computer Science 2024:
  https://link.springer.com/book/10.1007/978-3-031-66438-0
- Survey of modal logics characterising behavioural equivalences:
  https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/abs/survey-of-modal-logics-characterising-behavioural-equivalences-for-nondeterministic-and-stochastic-systems/BDC8F160A764092B2790EB879664A556
- Behavioural Equivalence via Modalities for Algebraic Effects:
  https://link.springer.com/chapter/10.1007/978-3-319-89884-1_11

This suggests the following mapping:

```text
LOAM step
  ~ transition / coalgebra structure

LOAM terminal questions
  ~ chosen observation family / logic

FutureEquivalentUnder
  ~ observational / behavioural equivalence

ExactFutureClassifierUnder
  ~ behavioural quotient representation
```

LOAM has not yet formalized a coalgebraic abstraction, and there is no need to introduce category theory merely to rename already-working definitions. Coalgebra is most useful here as comparison literature and as a warning against overclaiming novelty.

---

## 8. Abstract interpretation and observational completeness

The phrase "observational completeness" is nearby but should be used carefully.

Amato and Scozzari define an abstract domain to be observationally complete for an observable when abstract computations retain all concrete precision relevant to that observable.

Reference:

- Observational Completeness on Abstract Interpretation:
  https://journals.sagepub.com/doi/10.3233/FI-2011-381

Related completeness work studies complete shells and the least refinements/restrictions needed to preserve semantic computations.

References:

- Making Abstract Interpretations Complete:
  https://www.research.unipd.it/handle/11577/1365861
- Completeness in Abstract Interpretation: A Domain Perspective:
  https://www.research.unipd.it/handle/11577/182291

The conceptual overlap with LOAM is:

```text
smaller retained representation
    should lose no information
    relevant to selected observations
    after selected computations
```

But the formal structures differ.

LOAM currently works primarily with:

- state equivalence;
- future experiment equality;
- exact classifier fibers;
- finite distinguishing contexts.

Abstract interpretation works with:

- concrete and abstract domains;
- abstraction/concretization relationships;
- semantic transformers;
- completeness of abstract computations.

### Conclusion

Observational completeness is a useful neighboring theory for `FutureSufficientUnder` and retention abstractions, but it is **not** the direct source model for `FutureCharacterizingSetUnder`.

---

## 9. Minimal characterizing sets are already a hard classical problem

Observation 316 proves small concrete minimality results:

- ActualReversal least semantic characterizing depth = 1;
- ActualReversal minimum characterizing context count = 2;
- selected provenance least exact generated depth = 1.

This is worthwhile as instance-level certification.

However, building a generic optimizer for minimum W-sets is not a promising novelty direction.

Türker, Hierons, and Jourdan proved for deterministic FSMs that:

- deciding whether a characterization set with at most K sequences exists is PSPACE-complete;
- deciding whether one exists with total input length at most K is NP-complete.

Reference:

- Minimizing Characterizing Sets, Science of Computer Programming 208 (2021):
  https://www.sciencedirect.com/science/article/pii/S0167642321000381
- Author repository copy:
  https://eprints.whiterose.ac.uk/id/eprint/173162/

### Implication for LOAM

Keep:

- small theorem-proved minimality results;
- bounded heuristics as candidate generators;
- independent certification.

Avoid, for now:

- claiming a general efficient minimizer;
- treating first partition stabilization as proof of minimality;
- spending research effort reproducing generic W-set optimization.

---

## 10. Observation-by-observation map

| LOAM observation / concept | Closest established idea | Current interpretation |
|---|---|---|
| FutureEquivalent / FutureEquivalentUnder | Nerode-style / behavioural equivalence | Established mathematical shape |
| FutureSufficient / FutureSufficientUnder | sufficient abstraction preserving future observations | Related to abstraction completeness |
| ExactFutureClassifierUnder | quotient encoding with kernel = behavioural equivalence | Established quotient/minimization shape |
| boundedBehaviourSignature | finite observation-table row | Strong L*/testing analogy |
| bounded partition explorer | heuristic experiment refinement | exploratory, not proof |
| FutureContextBasisUnder | stronger uniform representative-context factorization | not ordinary W-set; keep separate |
| FutureCharacterizingSetUnder | W-set / characterization set | very close correspondence |
| least distinguishing depth | k-equivalence / bounded distinguishing depth | established family; LOAM proves concrete instances |
| minimum context count | minimum W-set size | established optimization problem |
| FiniteFutureQuotientUnder | finite behavioural index / finite representative cover | established finite-index shape |
| finite quotient -> finite characterization | finite classes -> choose pair distinguishers | classical argument |
| finite characterization + finite answers -> finite quotient | finitely many finite observation profiles | classical finite-signature argument |

---

## 11. What looks specifically valuable in LOAM

The literature search does **not** currently support a claim that the core mathematics is new.

What still looks worth preserving and possibly writing about is the way the pieces are assembled for retained evidence.

### A. Vocabulary-relative future semantics

Claims are always explicitly scoped by:

```text
selected future operations
    ×
selected terminal questions
```

This prevents "sufficient for everything" claims and makes semantic scope an explicit object.

### B. Raw history versus behavioural quotient

The retained state can remain structurally rich, historical, and potentially unbounded while future-relevant behaviour admits a small quotient.

This is theoretically familiar but highly relevant to event-sourced / retained-evidence systems.

### C. Search is not trusted as proof

LOAM repeatedly uses:

```text
bounded exploration
    -> candidate
    -> independent unbounded Lean theorem
```

Finite stabilization is never silently promoted into an unbounded theorem.

### D. Strong basis versus weak characterization

The mechanized distinction:

```text
FutureContextBasisUnder
    strictly stronger than
FutureCharacterizingSetUnder
```

prevents a useful strong certificate from being mistaken for the minimal semantic requirement.

### E. Explicit representative evidence

Observation 317 represents finite quotient index by an actual finite list of retained-state representatives and a coverage proof, rather than requiring the raw state type itself to be finite.

This is a good engineering/formalization choice even though the theorem pattern is classical.

---

## 12. Claims to avoid

Do not currently claim:

- LOAM invented future-context equivalence;
- LOAM invented finite characterization;
- finite quotient iff finite distinguishing experiments is new;
- the current work is a new Myhill–Nerode theorem;
- bounded partition stabilization proves global completeness;
- minimum characterizing sets are easy or efficiently computable;
- FutureContextBasisUnder is simply another name for a W-set;
- abstract-interpretation observational completeness is identical to LOAM's characterizing-set condition;
- raw history must be finite for finite behavioural characterization.

---

## 13. Defensible research framing

A modest framing, if this thread eventually becomes a paper or technical report, is:

> A Lean-certified study of vocabulary-relative future-context retention for long-lived retained-evidence systems, connecting bounded behavioural synthesis to independently certified behavioural quotients and finite characterization.

Potential contribution categories would be:

1. **formalization/application** of established behavioural-equivalence ideas to retained evidence;
2. **proof architecture** separating bounded candidate discovery from unbounded semantic certification;
3. **semantic scoping** by operation and question vocabularies;
4. **engineering interpretation** of which historical distinctions must remain retained for future observable behaviour;
5. possibly the stronger **representative-context basis** as a useful domain-specific certificate, after a deeper literature search for an existing equivalent notion.

This is much safer than presenting a new automata theorem.

---

## 14. Recommended next research questions

### Priority 1 — formalize the context-side quotient if it adds clarity

The terminology search substantially resolved the earlier ambiguity.

The useful next formal object would be an explicit relation such as:

```text
ContextObservationEquivalent answer step c₁ c₂ :=
  ∀ state,
    contextAnswer answer step state c₁ =
      contextAnswer answer step state c₂
```

Then prove that `FutureContextBasisUnder` is precisely a finite admitted
representative cover of this relation.

For the single-question Boolean DFA specialization, record the correspondence
with the left automata-based equivalence `pre_u(F) = pre_v(F)`.

This would make the state/context duality explicit:

```text
state-side quotient:
  FutureEquivalentUnder

context-side quotient:
  ContextObservationEquivalent
```

Only add this Observation if the explicit duality clarifies later reasoning;
the underlying mathematics is established.

### Priority 2 — formalize the Moore-machine normalization only if useful

Show, on paper first, that:

```text
output(state) : Question -> Answer
transition(state, operation)
```

turns the selected deterministic LOAM semantics into a Moore-style machine.

Then determine whether `FutureEquivalentUnder` is literally standard Moore behavioural equivalence after restricting the input alphabet and observable output coordinates.

If yes, record that and avoid introducing duplicate theory.

### Priority 3 — compare with event sourcing / provenance research

The automata correspondence explains the mathematics, but not why retained historical evidence matters.

The potentially more domain-specific question is:

> when may an event-sourced or provenance-preserving system discard historical distinctions while preserving all declared future decisions and observations?

That may be where LOAM contributes a useful application story.

### Priority 4 — constructive versus classical finite characterization

Observation 317's forward proof chooses one distinguishing context for each inequivalent representative pair using classical choice.

A genuinely different engineering question is:

> under which decidable/enumerable future languages can the characterizing contexts be extracted constructively?

This connects the theorem to an executable synthesizer without pretending general minimization is easy.

---

## Checkpoint conclusion

Observations 304–317 have reached a coherent theoretical stopping point.

The thread is no longer "an unusual accounting-specific trick." It is recognizably an instance of established behavioural-equivalence and finite-characterization theory.

That is good news rather than a disappointment: it means LOAM's definitions have converged onto durable mathematical structure.

The best next move is not another relation example. It is to investigate the two remaining interfaces where the current literature match is less direct:

1. the stronger `FutureContextBasisUnder` property;
2. retained-evidence / event-sourcing semantics as the application domain.

Until those are researched, additional generic theorem-building risks rediscovering established automata theory under LOAM names.
