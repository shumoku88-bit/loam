import Loam.Observations.Observation298

namespace Loam.Observation299

set_option autoImplicit false

/-!
# Observation 299 — bounded counterexample search

Observation 298 separated search from semantic checking:

- a search mechanism proposes a `CounterexamplePayload`;
- the Lean checker validates the payload against `FutureSufficient` semantics.

This observation adds the smallest executable bounded searcher on top of that
protocol.

The search space is explicitly finite and caller-supplied:

- candidate retained states;
- allowed operations;
- selected terminal questions;
- a maximum continuation depth.

No completeness claim is made beyond the supplied finite search space and depth.
The only semantic theorem is soundness: every payload returned by the searcher
is a valid counterexample and therefore refutes the proposed compression.
-/

universe uSeed uS uO uQ uA uM

/-- All operation words of exactly the requested length. -/
def continuationsExact
    {Operation : Type uO}
    (operations : List Operation) : Nat → List (List Operation)
  | 0 => [[]]
  | depth + 1 =>
      (continuationsExact operations depth).flatMap
        (fun path =>
          operations.map
            (fun operation => path ++ [operation]))

/-- All operation words whose length is at most `depth`. -/
def continuationsUpTo
    {Operation : Type uO}
    (operations : List Operation) : Nat → List (List Operation)
  | 0 => [[]]
  | depth + 1 =>
      continuationsUpTo operations depth ++
        continuationsExact operations (depth + 1)

/--
Enumerate every candidate payload in the supplied finite rectangle.

State pairs are ordered, which is harmless for soundness and keeps the
enumerator simple.
-/
def candidatePayloads
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    (states : List State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat) :
    List (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  states.flatMap
    (fun left =>
      states.flatMap
        (fun right =>
          (continuationsUpTo operations depth).flatMap
            (fun continuation =>
              questions.map
                (fun question =>
                  { left := left
                    right := right
                    continuation := continuation
                    question := question }))))


/--
Enumerate only ordered state pairs that collide under the candidate summary.

This is an explorer optimization, not a trusted semantic judgment. The later
Observation-298 checker still rechecks summary equality together with the future
answer distinction before any theorem is derived.
-/
def summaryCollidingStatePairs
    {State : Type uS}
    {Summary : Type uM}
    [DecidableEq Summary]
    (encode : State → Summary)
    (states : List State) : List (State × State) :=
  states.flatMap
    (fun left =>
      states.filterMap
        (fun right =>
          if encode left = encode right then
            some (left, right)
          else
            none))


/--
Enumerate each distinct unordered state pair exactly once, by list position.

No `DecidableEq State` is required: distinctness is structural in the finite
candidate list. This removes self-pairs and symmetric duplicates from explorer
work without asserting any semantic equality on the state type.
-/
def unorderedDistinctStatePairs
    {State : Type uS} : List State → List (State × State)
  | [] => []
  | left :: rest =>
      rest.map (fun right => (left, right)) ++
        unorderedDistinctStatePairs rest

/--
Keep only distinct unordered pairs that the candidate summary currently
identifies.
-/
def distinctSummaryCollidingStatePairs
    {State : Type uS}
    {Summary : Type uM}
    [DecidableEq Summary]
    (encode : State → Summary)
    (states : List State) : List (State × State) :=
  (unorderedDistinctStatePairs states).filter
    (fun pair => decide (encode pair.1 = encode pair.2))

/-- Enumerate future payloads from distinct unordered summary collisions only. -/
def candidatePayloadsFromDistinctSummaryCollisions
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Summary : Type uM}
    [DecidableEq Summary]
    (encode : State → Summary)
    (states : List State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat) :
    List (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  (distinctSummaryCollidingStatePairs encode states).flatMap
    (fun pair =>
      (continuationsUpTo operations depth).flatMap
        (fun continuation =>
          questions.map
            (fun question =>
              { left := pair.1
                right := pair.2
                continuation := continuation
                question := question })))

/-- Enumerate future-context payloads only from current-summary collisions. -/
def candidatePayloadsFromSummaryCollisions
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Summary : Type uM}
    [DecidableEq Summary]
    (encode : State → Summary)
    (states : List State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat) :
    List (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  (summaryCollidingStatePairs encode states).flatMap
    (fun pair =>
      (continuationsUpTo operations depth).flatMap
        (fun continuation =>
          questions.map
            (fun question =>
              { left := pair.1
                right := pair.2
                continuation := continuation
                question := question })))

/--
A first-class finite slice of an otherwise potentially infinite semantic model.

This deliberately does not require `Fintype State`, `Fintype Operation`, or
`Fintype Question`. Real LOAM states contain open-ended identities and values;
the bounded experiment chooses only the semantically relevant finite candidates.
-/
structure SearchSpace
    (State : Type uS)
    (Operation : Type uO)
    (Question : Type uQ) where
  states : List State
  operations : List Operation
  questions : List Question
  depth : Nat

/--
Build one bounded semantic slice from a smaller list of domain-specific seeds.

The seed type is intentionally unconstrained. A caller may use quantities,
identities, relation endpoints, or another compact description that generates
the retained states worth comparing. This is not whole-type enumeration.
-/
def SearchSpace.fromSeeds
    {Seed : Type uSeed}
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    (seeds : List Seed)
    (realize : Seed → State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat) :
    SearchSpace State Operation Question :=
  { states := seeds.map realize
    operations := operations
    questions := questions
    depth := depth }

@[simp] theorem SearchSpace.fromSeeds_state_count
    {Seed : Type uSeed}
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    (seeds : List Seed)
    (realize : Seed → State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat) :
    (SearchSpace.fromSeeds seeds realize operations questions depth).states.length =
      seeds.length := by
  simp [SearchSpace.fromSeeds]

def SearchSpace.payloads
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    (space : SearchSpace State Operation Question) :
    List (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  candidatePayloads
    space.states space.operations space.questions space.depth

/-- Exact number of candidate payloads enumerated by this bounded slice. -/
def SearchSpace.candidateCount
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    (space : SearchSpace State Operation Question) : Nat :=
  space.payloads.length


/-- Candidate payloads after discarding state pairs with different current summaries. -/
def SearchSpace.summaryCollisionPayloads
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Summary]
    (encode : State → Summary) :
    List (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  candidatePayloadsFromSummaryCollisions
    encode space.states space.operations space.questions space.depth

/-- Exact bounded candidate count after current-summary collision filtering. -/
def SearchSpace.summaryCollisionCandidateCount
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Summary]
    (encode : State → Summary) : Nat :=
  (space.summaryCollisionPayloads encode).length


/-- Payloads from distinct unordered state pairs that collide under the summary. -/
def SearchSpace.distinctSummaryCollisionPayloads
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Summary]
    (encode : State → Summary) :
    List (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  candidatePayloadsFromDistinctSummaryCollisions
    encode space.states space.operations space.questions space.depth

/-- Exact candidate count after distinct unordered summary-collision filtering. -/
def SearchSpace.distinctSummaryCollisionCandidateCount
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Summary]
    (encode : State → Summary) : Nat :=
  (space.distinctSummaryCollisionPayloads encode).length

/-- Return the first element accepted by a Boolean checker. -/
def firstAccepted
    {α : Type uS}
    (checker : α → Bool) : List α → Option α
  | [] => none
  | candidate :: rest =>
      match checker candidate with
      | true => some candidate
      | false => firstAccepted checker rest

/-- Anything returned by `firstAccepted` is accepted by its checker. -/
theorem firstAccepted_some_implies_true
    {α : Type uS}
    (checker : α → Bool)
    (candidates : List α)
    (candidate : α)
    (hFound : firstAccepted checker candidates = some candidate) :
    checker candidate = true := by
  induction candidates with
  | nil =>
      simp [firstAccepted] at hFound
  | cons head tail ih =>
      cases hCheck : checker head with
      | false =>
          simp [firstAccepted, hCheck] at hFound
          exact ih hFound
      | true =>
          simp [firstAccepted, hCheck] at hFound
          cases hFound
          exact hCheck

/--
Search the supplied finite model for one distinguishing payload.

`decideVocabulary` is explicit, matching Observation 298: the search procedure
must state which terminal questions count as selected.
-/
def boundedCounterexampleSearch
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (states : List State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat) :
    Option (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  firstAccepted
    (Loam.Observation298.checkCounterexample
      answer step vocabulary decideVocabulary encode)
    (candidatePayloads states operations questions depth)

/-- Run the bounded search using one explicit finite semantic slice. -/
def SearchSpace.search
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary) :
    Option (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  boundedCounterexampleSearch
    answer step vocabulary decideVocabulary encode
    space.states space.operations space.questions space.depth


/--
Search only state pairs that already collide under the candidate summary.

The trusted boundary remains unchanged: every returned payload is still passed
through the same Observation-298 checker.
-/
def SearchSpace.searchSummaryCollisions
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary) :
    Option (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  firstAccepted
    (Loam.Observation298.checkCounterexample
      answer step vocabulary decideVocabulary encode)
    (space.summaryCollisionPayloads encode)


/--
Search distinct unordered state pairs that collide under the current summary.

This is a narrower explorer than `searchSummaryCollisions`; the semantic checker
and its trust boundary remain unchanged.
-/
def SearchSpace.searchDistinctSummaryCollisions
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary) :
    Option (Loam.Observation298.CounterexamplePayload State Operation Question) :=
  firstAccepted
    (Loam.Observation298.checkCounterexample
      answer step vocabulary decideVocabulary encode)
    (space.distinctSummaryCollisionPayloads encode)

/--
Soundness of the bounded searcher.

Search enumeration itself is untrusted from the semantic point of view. If the
searcher returns a payload, the existing Observation-298 checker is the bridge
to the actual preservation proposition.
-/
theorem boundedCounterexampleSearch_some_is_valid
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (states : List State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      boundedCounterexampleSearch
        answer step vocabulary decideVocabulary encode
        states operations questions depth = some payload) :
    Loam.Observation298.ValidCounterexample
      answer step vocabulary encode payload := by
  have hAccepted :
      Loam.Observation298.checkCounterexample
          answer step vocabulary decideVocabulary encode payload = true :=
    firstAccepted_some_implies_true
      (Loam.Observation298.checkCounterexample
        answer step vocabulary decideVocabulary encode)
      (candidatePayloads states operations questions depth)
      payload hFound
  exact
    (Loam.Observation298.checkCounterexample_eq_true_iff
      answer step vocabulary decideVocabulary encode payload).1
      hAccepted

/-- Any found payload immediately refutes future sufficiency. -/
theorem boundedCounterexampleSearch_some_refutes_futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (states : List State)
    (operations : List Operation)
    (questions : List Question)
    (depth : Nat)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      boundedCounterexampleSearch
        answer step vocabulary decideVocabulary encode
        states operations questions depth = some payload) :
    ¬ Loam.Observation192.FutureSufficient
      answer step vocabulary encode := by
  exact
    Loam.Observation298.validCounterexample_refutes_futureSufficient
      answer step vocabulary encode payload
      (boundedCounterexampleSearch_some_is_valid
        answer step vocabulary decideVocabulary encode
        states operations questions depth payload hFound)

/-- A payload returned from an explicit search space is semantically valid. -/
theorem SearchSpace.search_some_is_valid
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      space.search answer step vocabulary decideVocabulary encode = some payload) :
    Loam.Observation298.ValidCounterexample
      answer step vocabulary encode payload := by
  exact
    boundedCounterexampleSearch_some_is_valid
      answer step vocabulary decideVocabulary encode
      space.states space.operations space.questions space.depth payload hFound

/-- A summary-collision search result is still checked into a semantic witness. -/
theorem SearchSpace.searchSummaryCollisions_some_is_valid
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      space.searchSummaryCollisions
        answer step vocabulary decideVocabulary encode = some payload) :
    Loam.Observation298.ValidCounterexample
      answer step vocabulary encode payload := by
  have hAccepted :
      Loam.Observation298.checkCounterexample
          answer step vocabulary decideVocabulary encode payload = true :=
    firstAccepted_some_implies_true
      (Loam.Observation298.checkCounterexample
        answer step vocabulary decideVocabulary encode)
      (space.summaryCollisionPayloads encode)
      payload hFound
  exact
    (Loam.Observation298.checkCounterexample_eq_true_iff
      answer step vocabulary decideVocabulary encode payload).1 hAccepted

/-- A distinct-summary-collision search result remains a checked semantic witness. -/
theorem SearchSpace.searchDistinctSummaryCollisions_some_is_valid
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      space.searchDistinctSummaryCollisions
        answer step vocabulary decideVocabulary encode = some payload) :
    Loam.Observation298.ValidCounterexample
      answer step vocabulary encode payload := by
  have hAccepted :
      Loam.Observation298.checkCounterexample
          answer step vocabulary decideVocabulary encode payload = true :=
    firstAccepted_some_implies_true
      (Loam.Observation298.checkCounterexample
        answer step vocabulary decideVocabulary encode)
      (space.distinctSummaryCollisionPayloads encode)
      payload hFound
  exact
    (Loam.Observation298.checkCounterexample_eq_true_iff
      answer step vocabulary decideVocabulary encode payload).1 hAccepted

/-- A distinct-summary-collision witness refutes future sufficiency. -/
theorem SearchSpace.searchDistinctSummaryCollisions_some_refutes_futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      space.searchDistinctSummaryCollisions
        answer step vocabulary decideVocabulary encode = some payload) :
    ¬ Loam.Observation192.FutureSufficient
      answer step vocabulary encode := by
  exact
    Loam.Observation298.validCounterexample_refutes_futureSufficient
      answer step vocabulary encode payload
      (space.searchDistinctSummaryCollisions_some_is_valid
        answer step vocabulary decideVocabulary encode payload hFound)

/-- A found summary-collision witness refutes future sufficiency. -/
theorem SearchSpace.searchSummaryCollisions_some_refutes_futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      space.searchSummaryCollisions
        answer step vocabulary decideVocabulary encode = some payload) :
    ¬ Loam.Observation192.FutureSufficient
      answer step vocabulary encode := by
  exact
    Loam.Observation298.validCounterexample_refutes_futureSufficient
      answer step vocabulary encode payload
      (space.searchSummaryCollisions_some_is_valid
        answer step vocabulary decideVocabulary encode payload hFound)

/-- A found payload from the finite slice refutes the candidate compression. -/
theorem SearchSpace.search_some_refutes_futureSufficient
    {State : Type uS}
    {Operation : Type uO}
    {Question : Type uQ}
    {Answer : Type uA}
    {Summary : Type uM}
    (space : SearchSpace State Operation Question)
    [DecidableEq Answer]
    [DecidableEq Summary]
    (answer : State → Question → Answer)
    (step : State → Operation → State)
    (vocabulary : Loam.Observation029.Vocabulary Question)
    (decideVocabulary : ∀ question, Decidable (vocabulary question))
    (encode : State → Summary)
    (payload : Loam.Observation298.CounterexamplePayload State Operation Question)
    (hFound :
      space.search answer step vocabulary decideVocabulary encode = some payload) :
    ¬ Loam.Observation192.FutureSufficient
      answer step vocabulary encode := by
  exact
    boundedCounterexampleSearch_some_refutes_futureSufficient
      answer step vocabulary decideVocabulary encode
      space.states space.operations space.questions space.depth payload hFound

/-! ## Executable reveal witness -/

private def revealHiddenFalse : Loam.Observation192.RevealState :=
  { visible := false, hidden := false }

private def revealHiddenTrue : Loam.Observation192.RevealState :=
  { visible := false, hidden := true }

private def revealStates : List Loam.Observation192.RevealState :=
  [revealHiddenFalse, revealHiddenTrue]

private def revealOperations : List Loam.Observation192.RevealOperation :=
  [.reveal]

private def revealQuestions : List Loam.Observation192.RevealQuestion :=
  [.visible]

/-- With no future operation allowed, the hidden distinction is not observable. -/
theorem reveal_depth_zero_finds_no_counterexample :
    (boundedCounterexampleSearch
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      Loam.Observation298.decideVisibleVocabulary
      Loam.Observation192.encodeVisible
      revealStates revealOperations revealQuestions 0).isNone = true := by
  native_decide

/-- At depth one, the same finite model discovers the `reveal` witness. -/
theorem reveal_depth_one_finds_counterexample :
    (boundedCounterexampleSearch
      Loam.Observation192.revealAnswer
      Loam.Observation192.revealStep
      Loam.Observation192.VisibleVocabulary
      Loam.Observation298.decideVisibleVocabulary
      Loam.Observation192.encodeVisible
      revealStates revealOperations revealQuestions 1).isSome = true := by
  native_decide

/-!
## Finding

The first bounded searcher can stay deliberately small:

    finite states
    finite operations
    finite selected questions
    maximum continuation depth
             |
             v
      enumerate payloads
             |
             v
      Observation-298 checker
             |
       +-----+-----+
       |           |
    rejected     accepted
                   |
                   v
          valid counterexample
                   |
                   v
          not FutureSufficient

The executable reveal example demonstrates the intended distinction between
`depth = 0` and `depth = 1`.

This observation does not claim:

- search completeness outside the supplied finite lists;
- minimality of the returned continuation;
- practical scalability;
- automatic discovery of positive preservation certificates.

Those are separate questions. The semantic trust boundary remains the small
checker from Observation 298.
-/

end Loam.Observation299
