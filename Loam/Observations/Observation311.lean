import Loam.Observations.Observation309
import Loam.Observations.Observation310

namespace Loam.Observation311

set_option autoImplicit false

/-!
# Observation 311 — bounded depth candidate discovery

Observation 309 proved a concrete completeness boundary for the selected
ActualReversal vocabulary:

    depth 0  — insufficient
    depth 1  — exact FutureEquivalent quotient

Observation 308 supplied the executable bounded signatures from which that
depth-one quotient can be observed.

This observation adds only the explorer-side question:

> can a finite semantic slice propose the first depth at which its behavioural
> partition stops changing?

The explorer compares the equality relation induced by depth d signatures with
the equality relation induced by depth d+1 signatures over a caller-supplied
finite list of states.

A stable finite partition is only a candidate. In general it does not prove
that deeper or unlisted states cannot reveal a distinction.

For the reversal fixture, the explorer proposes depth 1. The already-independent
Observation-309 theorem then certifies that depth 1 is globally exact for the
declared future vocabulary.
-/

universe uS uL uR

/--
Do two encodings induce the same equality partition on the supplied finite
state list?

No equality instance for State is required. The list supplies the comparison
coordinates; only the two summary types need decidable equality.
-/
def samePartitionOn
    {State : Type uS}
    {LeftSummary : Type uL}
    {RightSummary : Type uR}
    [DecidableEq LeftSummary]
    [DecidableEq RightSummary]
    (states : List State)
    (leftEncode : State → LeftSummary)
    (rightEncode : State → RightSummary) : Bool :=
  states.all
    (fun left =>
      states.all
        (fun right =>
          decide (leftEncode left = leftEncode right) ==
            decide (rightEncode left = rightEncode right)))

/--
Return the first depth in the inclusive bounded interval

    current .. current + remaining

whose predicate is true.
-/
def firstDepthWhere
    (predicate : Nat → Bool) : Nat → Nat → Option Nat
  | current, 0 =>
      if predicate current then some current else none
  | current, remaining + 1 =>
      if predicate current then
        some current
      else
        firstDepthWhere predicate (current + 1) remaining

/-! ## Reversal depth explorer -/

/-- Reuse the Observation-308 finite slice while varying only continuation depth. -/
def reversalSpaceAtDepth
    (depth : Nat) :
    Loam.Observation299.SearchSpace
      Loam.Observation304.State
      Loam.Observation304.Operation
      Loam.Observation304.Question :=
  { Loam.Observation308.reversalSynthesisSpace with depth := depth }

/-- Mechanically generated answer vector at one requested depth. -/
def reversalSignatureAtDepth
    (depth : Nat)
    (state : Loam.Observation304.State) : List Bool :=
  Loam.Observation308.boundedBehaviourSignature
    (reversalSpaceAtDepth depth)
    Loam.Observation304.answer
    Loam.Observation304.step
    Loam.Observation304.Vocabulary
    Loam.Observation308.decideReversalVocabulary
    state

/--
Has the bounded behavioural partition stopped changing between depth and
depth+1 on the three supplied witness states?
-/
def reversalPartitionStableAtDepth
    (depth : Nat) : Bool :=
  samePartitionOn
    Loam.Observation308.reversalSynthesisSpace.states
    (reversalSignatureAtDepth depth)
    (reversalSignatureAtDepth (depth + 1))

/-- Search candidate depths starting at zero. -/
def reversalFirstStableDepthUpTo
    (maxDepth : Nat) : Option Nat :=
  firstDepthWhere reversalPartitionStableAtDepth 0 maxDepth

/-! ## Executable candidate discovery -/

theorem reversal_depth_zero_class_count :
    Loam.Observation308.realizedBehaviourClassCount
        (reversalSpaceAtDepth 0)
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        Loam.Observation308.decideReversalVocabulary = 2 := by
  native_decide

theorem reversal_depth_one_class_count :
    Loam.Observation308.realizedBehaviourClassCount
        (reversalSpaceAtDepth 1)
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        Loam.Observation308.decideReversalVocabulary = 3 := by
  native_decide

theorem reversal_depth_two_class_count :
    Loam.Observation308.realizedBehaviourClassCount
        (reversalSpaceAtDepth 2)
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        Loam.Observation308.decideReversalVocabulary = 3 := by
  native_decide

/-- The partition still refines from depth zero to depth one. -/
theorem reversal_depth_zero_partition_not_stable :
    reversalPartitionStableAtDepth 0 = false := by
  native_decide

/-- No further partition refinement appears from depth one to depth two. -/
theorem reversal_depth_one_partition_stable :
    reversalPartitionStableAtDepth 1 = true := by
  native_decide

/-- The bounded explorer therefore proposes depth one as its first stable depth. -/
theorem reversal_first_stable_depth_candidate :
    reversalFirstStableDepthUpTo 2 = some 1 := by
  native_decide

/-! ## Independent semantic certification of the candidate -/

/--
At depth one the generic variable-depth signature is definitionally the same
bounded answer vector certified by Observation 309.
-/
theorem reversalSignatureAtDepth_one
    (state : Loam.Observation304.State) :
    reversalSignatureAtDepth 1 state =
      Loam.Observation309.reversalDepthOneSignature state := by
  rfl

/--
The explorer-proposed depth is not trusted merely because the finite partition
stabilized. Its generated signature is checked against the independently proved
unbounded future semantics.
-/
theorem reversal_depth_one_candidate_is_exact :
    Loam.Observation307.ExactFutureClassifier
      Loam.Observation304.answer
      Loam.Observation304.step
      Loam.Observation304.Vocabulary
      (reversalSignatureAtDepth 1) := by
  intro left right
  rw [reversalSignatureAtDepth_one left,
    reversalSignatureAtDepth_one right]
  exact
    Loam.Observation309.same_depth_one_signature_iff_futureEquivalent
      left right

/--
The executable explorer proposes depth one, and the semantic proof layer
certifies that same depth as globally exact.
-/
theorem discovered_reversal_depth_is_certified :
    reversalFirstStableDepthUpTo 2 = some 1 ∧
      Loam.Observation307.ExactFutureClassifier
        Loam.Observation304.answer
        Loam.Observation304.step
        Loam.Observation304.Vocabulary
        (reversalSignatureAtDepth 1) :=
  ⟨reversal_first_stable_depth_candidate,
    reversal_depth_one_candidate_is_exact⟩

/-!
## Finding

The reversal example now has a search/certification split for depth itself.

Explorer:

    depth 0 signatures
          |
       2 classes
          |
          v
    depth 1 signatures
          |
       3 classes
          |
          v
    depth 2 signatures
          |
       3 classes
          |
          v
    first stable candidate = 1

Certification:

    candidate depth 1
          |
          v
    Observation 309
          |
          v
    ExactFutureClassifier
          |
          v
    unbounded FutureEquivalent quotient

The finite stabilization test is intentionally not promoted to a generic proof
rule. A finite slice may stabilize too early, omit relevant states, or require a
deeper continuation outside the explored bound.

Its role is exploratory: propose a depth cheaply, then hand that candidate to a
separate semantic proof boundary.

That mirrors the earlier counterexample architecture:

    bounded explorer proposes
          +
    small trusted semantics certifies

but now the proposed object is a quotient depth rather than a counterexample.
-/

end Loam.Observation311
