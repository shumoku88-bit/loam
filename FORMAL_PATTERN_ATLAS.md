# Formal Pattern Atlas

Status: experimental reverse index for LOAM exploration.

This atlas is not a new source of semantic authority and it is not a catalogue of mathematics that LOAM claims to instantiate. It is a navigation aid for moving from a concrete design pressure to candidate mathematics, qualification questions, and the smallest formal instrument that can answer the next question.

The governing order remains:

```text
concrete pressure
    -> smallest discriminating question
    -> witness or counterexample
    -> candidate structure
    -> qualification
    -> retained law only if earned
```

A familiar mathematical name is a hypothesis until its defining laws have been checked. A successful bounded model is evidence, not a general theorem. A useful projection is not automatically canonical state.

## How to use this atlas

Start from the symptom, not from the mathematical theory you hope to find.

1. Find the closest symptom in the quick index.
2. Read the qualification questions before naming the structure.
3. Choose the smallest formal tool that gives a distinct answer.
4. Build the smallest witness that could refute the claim.
5. Retain the mathematical name only to the level actually earned.
6. Record any production consequence separately from the abstract result.

The atlas should grow only when a repeated exploration pressure appears. It should not become a second ontology for LOAM.

## Quick reverse index

| Symptom | Candidate mathematics | First instrument |
| --- | --- | --- |
| Two states differ internally but all selected answers agree | equivalence relation, quotient, factorization | Alloy or Lean |
| A transformation changes representation but should preserve selected answers | invariant, preserver, stabilizer-like structure | Lean |
| More observations allow fewer transformations, and vice versa | polarity, closure operator, Galois connection | Lean |
| Different finite presentations have the same coordinate totals | commutative additive structure, free Abelian projection | J then Lean |
| A question may legitimately refuse to return a value | partial function, `Option` or `Except`, information order | Lean, Alloy for witnesses |
| States look equal now but a shared future operation separates them | contextual equivalence, Nerode-style equivalence, bisimulation candidate | Lean or TLA+ |
| A safety claim concerns all reachable operation sequences | transition system, invariant, reachability | TLA+ / TLC |
| The pressure is specifically process scheduling or interleaving | traces, protocol states, concurrency semantics | SPIN / Promela or TLA+ |
| Information or capability only grows or shrinks in one direction | partial order, monotone map, refinement | Lean |
| Repeated application appears to converge to a stable answer | fixed point, closure, least or greatest fixed point candidate | Lean or TLA+ |
| The useful question runs naturally backwards from answer to causes | relation, inverse image, relational search | miniKanren only if needed |

The entries below explain what must be checked before those names are earned.

---

## Pattern 01: Observational quotient

### Symptom

Two retained states are physically different, but every answer in a selected vocabulary is equal.

### Candidate mathematics

- equivalence relation
- quotient
- factorization through equivalence classes
- universal property of a quotient

### Qualification questions

Ask:

- Is the proposed indistinguishability reflexive?
- Is it symmetric?
- Is it transitive?
- Is the target answer constant on each indistinguishability class?
- Does the claim quantify over exactly the observations that matter, rather than every imaginable question?

Do not call the relation a quotient boundary before the equivalence laws are established.

### Smallest first instrument

Use Alloy when the main question is whether a small counterexample exists. Use Lean when the relation is already clear enough that the general equivalence and factorization laws are the actual result.

### Witness strategy

Construct two states that differ only in information intentionally hidden from the selected vocabulary. Then add one candidate observation at a time and see whether the states remain indistinguishable.

### Earned conclusion

If a target observation is constant on every equivalence class, it can be treated as depending only on the quotient for that observational purpose.

### Do not conclude

Quotient-equality does not imply that retained provenance, event identity, or historical evidence may be deleted. A projection may forget distinctions that another legitimate question still observes.

### LOAM trail

- Observation 159 gives a concrete coordinate-vector equivalence.
- Observation 191 defines generic observational indistinguishability and proves the factorization boundary.
- `experiments/191_observational_quotient_factorization.md`

---

## Pattern 02: Preservation and invariants

### Symptom

A transformation changes a representation, but selected observations are expected to remain unchanged.

### Candidate mathematics

- invariant
- preserving transformation
- stabilizer-like family of transformations
- homomorphism, when an algebraic operation is also preserved

### Qualification questions

Ask:

- Which exact observations must remain unchanged?
- Does the transformation preserve them for every input or only for a witness?
- Are transformations closed under composition?
- Is there an identity transformation?
- Are inverses actually available? If not, do not promote a monoid-like family to a group.

### Smallest first instrument

Lean is usually the first choice once the transformation and observation are explicit. J can be useful first when the pressure is finite shape or projection behavior.

### Witness strategy

Use a representation-changing transform that obviously alters presentation shape while preserving the claimed semantic projection. Then try an observation that should not be preserved.

### Earned conclusion

The transformation belongs to the preserver family for the selected observations.

### Do not conclude

A transformation preserving one projection does not preserve the full retained evidence or semantic identity.

### LOAM trail

- Observation 179 studies normalization, preservation, and the polarity between observations and preserving transformations.
- `experiments/179_preservation_galois_polarity.md`

---

## Pattern 03: Closure and Galois polarity

### Symptom

Adding observations makes the set of admissible preserving transformations smaller. Adding transformations makes the set of invariant observations smaller.

### Candidate mathematics

- order reversal
- polarity
- closure operator
- Galois connection
- lattice-theoretic structure, if meet and join structure is actually established

### Qualification questions

Ask:

- What are the two ordered collections?
- What is the order on each side, usually inclusion?
- Does the preserver operation reverse inclusion?
- Does the invariant operation reverse inclusion?
- Does double application give an extensive, monotone, idempotent closure?
- Are arbitrary meets or joins really needed and available before saying complete lattice?

### Smallest first instrument

Lean is well suited because the result is a law about sets, order, and closure rather than a bounded witness.

### Witness strategy

Begin with a small observation basis. Add a derived observation and test whether the closure changes. Then add a genuinely distinguishing observation and check that the preserver family shrinks.

### Earned conclusion

A double-polarity closure can identify observations derivable from a retained observational basis under the chosen universe of transformations.

### Do not conclude

A Galois polarity is not automatically a classical Galois group. A closure operator is not automatically a complete lattice theorem.

### LOAM trail

- Observation 179 establishes the preservation polarity.
- Observation 180 establishes observational closure and a minimal additive basis.
- Observation 191 connects closure to quotient factorization under all evidence endomaps.

---

## Pattern 04: Additive projection

### Symptom

Different finite presentations produce the same signed total at every coordinate.

### Candidate mathematics

- commutative monoid
- Abelian group
- finitely supported integer-valued functions
- free Abelian group or free module style representation
- linear or additive projection

### Qualification questions

Ask:

- What is the carrier being added?
- Is addition associative?
- Is there an identity?
- Is addition commutative?
- Are additive inverses really present?
- Is the representation free on named coordinates, or are extra relations imposed?
- Is the projection a homomorphism with respect to the retained operation?

### Smallest first instrument

J is useful for finite vector shape and aggregation experiments. Lean is appropriate when the additive law and equivalence are worth retaining generally.

### Witness strategy

Compare a compact movement presentation with a split presentation that has the same coordinate totals but a different number of retained entries.

### Earned conclusion

The additive image may have free-Abelian character even when the retained event presentation contains more identity and provenance than the image.

### Do not conclude

Equal additive image does not authorize collapsing event identity, provenance, or presentation-sensitive observations.

### LOAM trail

- Observation 159 defines `VectorEquivalent` by equality of every coordinate aggregate.
- `experiments/159_free_abelian_projection_boundary.md`
- Observation 191 later identifies this concrete relation as one observational quotient instance.

---

## Pattern 05: Partial semantic result

### Symptom

A semantic question may legitimately refuse to produce a domain value because the retained evidence is inadmissible, inconsistent, or insufficient.

### Candidate mathematics

- partial function
- lifted codomain such as `Option A`
- error-aware codomain such as `Except E A`
- information order between exact result and derived availability

### Qualification questions

Ask:

- Is refusal itself observable?
- Are distinct refusal reasons observably different?
- Is `none` merely absence of an answer, or is the domain mistakenly treating it as a numerical value?
- Can a coarser availability observation be derived from the exact result?
- Can the exact result be reconstructed from availability alone?

### Smallest first instrument

Lean is usually sufficient once the result type is explicit. Alloy can help find a small state where one branch is defined and another is not.

### Witness strategy

Build two states with the same current visible quantity, then apply the same future evidence so that one remains admissible and the other fails closed.

### Earned conclusion

Definedness can be part of the semantic observation space without creating a new accounting quantity or a special quotient machinery.

### Do not conclude

Do not invent a rich refusal taxonomy until a real observation distinguishes refusal reasons.

### LOAM trail

- Observation 194 demonstrates future definedness as an observable distinction.
- Observation 195 proves that availability factors through the exact `Option` result and is strictly coarser.
- `experiments/195_semantic_result_observation.md`

---

## Pattern 06: Future-context equivalence

### Symptom

Two states answer every current selected question the same way, but applying the same future operation sequence may make their answers differ.

### Candidate mathematics

- contextual equivalence
- Nerode-style equivalence
- behavioral equivalence
- bisimulation candidate
- coalgebraic structure candidate

### Qualification questions

Ask:

- Is equivalence quantified over every allowed continuation or only one witness?
- Is it stable under one common next step?
- Does current observational equivalence follow from future equivalence?
- Is the relation the greatest step-stable observationally sound relation?
- Is there an actual coalgebra, functor, or bisimulation definition before using those stronger names?

### Smallest first instrument

Use Lean when the continuation semantics are simple and a general contextual law is the goal. Use TLA+ when reachability, operation order, or temporal behavior is the main pressure.

### Witness strategy

Find two states that are currently equal under the selected question. Apply exactly the same continuation to both and require different terminal answers.

### Earned conclusion

Current sufficiency may be weaker than future sufficiency. A state summary adequate for today's answer may fail to preserve future behavior.

### Do not conclude

A Nerode-style theorem does not by itself establish a finite minimal automaton. A behavioral analogy does not by itself establish a coalgebraic model.

### LOAM trail

- Observation 192 defines `FutureEquivalent` and connects it to contextual observational indistinguishability.
- Observation 193 supplies a Correction witness where current equality hides future value divergence.
- Observation 194 supplies a fail-closed witness where future definedness diverges.
- `experiments/192_future_context_equivalence.md`

---

## Pattern 07: Transition safety and reachability

### Symptom

The claim is not about one state or one function application. It is about every state reachable through allowed operation sequences.

### Candidate mathematics

- transition system
- inductive invariant
- reachability
- safety property
- refinement, when one transition system is intended to simulate another

### Qualification questions

Ask:

- What is the initial-state predicate?
- What exactly is the next-state relation?
- Is the property state-local or temporal?
- Is it preserved by every enabled transition?
- Does the model need fairness or liveness, or only safety?
- Is a proposed abstraction a real refinement mapping or merely a similar presentation?

### Smallest first instrument

TLA+ / TLC is the default LOAM instrument for temporal behavior, operation order, reachable histories, and state-transition questions. Lean is appropriate when an inductive invariant deserves a general proof after the transition model is stable.

### Witness strategy

Search for the shortest trace from an allowed initial state to a state violating the candidate invariant.

### Earned conclusion

A safety property is meaningful only relative to the modeled initial states and transitions.

### Do not conclude

No bounded counterexample does not prove an unbounded transition theorem. A safety proof does not imply liveness.

---

## Pattern 08: Interleaving and protocol order

### Symptom

The failure appears only when independent actors, writers, readers, or protocol steps interleave in a particular order.

### Candidate mathematics

- traces
- labeled transition systems
- partial orders of events
- concurrency semantics
- commutation or non-commutation of operations

### Qualification questions

Ask:

- Is scheduling itself the pressure point?
- Which operations are independent?
- Which pairs commute?
- What state must be observed atomically?
- Is the problem actually concurrency, or can a simpler sequential transition model expose it?

### Smallest first instrument

Use SPIN / Promela when concrete process interleavings and scheduling are the distinct question. Use TLA+ when the broader state-transition and temporal specification is the useful artifact.

### Witness strategy

Reduce to two actors and the shortest operation sequence that could expose a stale read, duplicate publication, lost update, or authority race.

### Earned conclusion

A concurrency claim should identify the exact interleaving or commutation law that matters.

### Do not conclude

Do not add a concurrency tool merely because the implementation uses files, locks, or multiple processes. The scheduling distinction must be real.

---

## Pattern 09: Order, monotonicity, and refinement

### Symptom

Evidence, knowledge, capability, or constraints appear to move only in one direction, and operations should respect that order.

### Candidate mathematics

- preorder or partial order
- monotone map
- order embedding
- refinement order
- lattice, only if meets and joins are earned

### Qualification questions

Ask:

- What does `x <= y` mean operationally?
- Is the relation reflexive and transitive?
- Is antisymmetry actually true, or is a preorder sufficient?
- Does the operation preserve the order?
- Do least upper bounds or greatest lower bounds exist when needed?

### Smallest first instrument

Lean is usually the smallest tool for general order laws. TLA+ can expose refinement pressure when the order concerns whole transition systems.

### Witness strategy

Create the smallest pair of ordered states, apply the same operation, and try to reverse the intended order.

### Earned conclusion

Monotonicity is a precise claim about one chosen order. It often gives a better design constraint than an informal statement that a system "only accumulates" or "only becomes safer".

### Do not conclude

A partial order does not imply a lattice. A refinement intuition does not imply a simulation theorem.

---

## Pattern 10: Fixed point and convergence

### Symptom

Repeated application of a normalization, closure, propagation, or reconstruction step appears to stop changing the result.

### Candidate mathematics

- idempotence
- fixed point
- least or greatest fixed point
- closure operator
- Knaster-Tarski style reasoning, if a complete lattice and monotonicity are actually present

### Qualification questions

Ask:

- Is one application already idempotent?
- If not, does iteration terminate?
- Is the function monotone under a stated order?
- Does the required lattice structure exist?
- Is the desired fixed point least, greatest, or merely some stable point?

### Smallest first instrument

Lean is appropriate for idempotence, monotonicity, and general fixed-point laws. TLA+ can be useful when convergence is about repeated transitions rather than a pure function.

### Witness strategy

Try to find a state where two applications differ from one. If none exists and idempotence is provable, do not introduce heavier fixed-point machinery.

### Earned conclusion

Use the weakest structure that explains the behavior. Idempotence may be the whole story.

### Do not conclude

Do not invoke complete-lattice fixed-point theorems before the order and completeness assumptions are independently earned.

---

## Pattern 11: Relational and backwards search

### Symptom

The natural question is not only "what result follows from this input?" but also "which inputs, histories, or structures could produce this result?"

### Candidate mathematics

- relation rather than function
- inverse image
- relational composition
- logic programming search

### Qualification questions

Ask:

- Is backwards search genuinely clearer than enumerating forward candidates?
- Does the relation have multiple valid predecessors?
- Is the search itself the result, or only a way to find a witness?
- Can Alloy, Lean, or ordinary finite enumeration already answer the question clearly enough?

### Smallest first instrument

Use miniKanren only when genuinely relational or backwards search gives a distinct result that the active core cannot express clearly enough.

### Witness strategy

Choose a small desired output and ask for all structurally distinct predecessors. Compare that with the forward formulation.

### Earned conclusion

A relational formulation is useful when bidirectional search is part of the question, not merely because relations are mathematically elegant.

### Do not conclude

A successful relational experiment does not create a production runtime dependency.

### LOAM trail

- Observations 006 and 007 are historical miniKanren examples.
- Observation 187 provides a later concrete backwards-search pressure.

---

## Tool selection by question shape

This table is subordinate to the repository's `README.md` Method section and `AGENTS.md` policy. It is only a reverse lookup.

| Question shape | Prefer | Distinct answer |
| --- | --- | --- |
| Can a small structure or counterexample exist? | Alloy | bounded structural witness or refutation |
| What information is lost by a finite projection or representation? | J | array shape, projection, quotient geometry |
| Does this law hold generally? | Lean 4 | machine-checked theorem |
| Can some reachable operation history violate this property? | TLA+ / TLC | temporal or transition counterexample |
| Can a symbolic transition checker add something TLC does not? | Apalache | symbolic checking or inductive-invariant pressure |
| Does a concrete scheduler interleaving expose the bug? | SPIN / Promela | process-level interleaving trace |
| Is backwards or relational search itself the useful question? | miniKanren | relational predecessor or solution search |

If two tools answer the same question in the same way, use the smaller combination.

## Qualification vocabulary

Use these labels explicitly when they help prevent overclaiming:

- **candidate**: a mathematical structure suggested by a witness or shape;
- **bounded evidence**: checked only within a finite scope;
- **proved law**: established generally under stated assumptions;
- **specialization**: a generic law instantiated by a concrete LOAM case;
- **analogy only**: terminology is suggestive but defining structure has not been established;
- **production consequence**: a change in retained evidence, authority, persistence, or operation justified separately from the mathematics.

A useful rhythm is:

```text
symptom
    -> candidate
    -> falsification attempt
    -> exact assumptions
    -> proof or bounded result
    -> production consequence, if any
```

## When to extend the atlas

Add or split an entry only when at least one of these happens:

- a recurring LOAM pressure does not fit an existing pattern;
- the same symptom repeatedly sends exploration toward the wrong mathematics;
- a tool repeatedly earns a distinct role not represented here;
- a qualification question prevents a real overclaim;
- a concrete observation establishes a stronger structure than an existing candidate label.

Do not expand the atlas just to make it comprehensive. Its value is navigational compression.