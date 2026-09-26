import Loam.Application.ActualValidityFrontier

namespace Loam.Observation337

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Observation 337 — raw evidence extension is not a global information order

R6 asks whether LOAM can safely read ordinary evidence growth as a monotone
information order:

```text
less evidence <= more evidence
```

This observation gives one concrete counterexample at the existing
ActualValidityHistory / ActualValidityFrontier boundary.

Start with one admitted correction path:

```text
root -> revision-1
```

Then append one fresh revision fact and one fresh correction edge:

```text
root -> revision-1
     \
      -> revision-2
```

The extended raw history still satisfies its own storage invariants:

- fact references remain unique;
- exact correction edges remain unique.

But semantic frontier admission rejects the sibling correction topology rather
than inventing one current date from representation order.

So raw evidence extension can move a derived answer from defined to fail-closed.
That is enough to reject a single global lattice reading in which ordinary raw
history inclusion is automatically "more informative".
-/

private def event : EventId := ⟨"o337-event"⟩
private def revision1 : ActualValidityRevisionId := ⟨"o337-r1"⟩
private def revision2 : ActualValidityRevisionId := ⟨"o337-r2"⟩

private def baseFacts : List (ActualValidityFact Nat) :=
  [
    .base event 1,
    .revision revision1 event 2
  ]

private def baseCorrections : List ActualValidityCorrection :=
  [
    { target := .root event, replacement := revision1 }
  ]

private def extendedFacts : List (ActualValidityFact Nat) :=
  baseFacts ++
    [
      .revision revision2 event 3
    ]

private def extendedCorrections : List ActualValidityCorrection :=
  baseCorrections ++
    [
      { target := .root event, replacement := revision2 }
    ]

private def baseHistory : ActualValidityHistory Nat :=
  {
    facts := baseFacts
    factRefNodup := by native_decide
    corrections := baseCorrections
    correctionIdNodup := by native_decide
  }

private def extendedHistory : ActualValidityHistory Nat :=
  {
    facts := extendedFacts
    factRefNodup := by native_decide
    corrections := extendedCorrections
    correctionIdNodup := by native_decide
  }

/--
A deliberately narrow notion of "more raw evidence": the right history keeps
the complete represented prefixes of facts and corrections and only appends new
items.

This relation is research-only. It does not claim to be LOAM's semantic
information order.
-/
def RawExtends
    (left right : ActualValidityHistory Nat) : Prop :=
  ∃ addedFacts addedCorrections,
    right.facts = left.facts ++ addedFacts ∧
      right.corrections = left.corrections ++ addedCorrections

theorem base_to_extended_is_raw_extension :
    RawExtends baseHistory extendedHistory := by
  refine ⟨[.revision revision2 event 3],
    [{ target := .root event, replacement := revision2 }], ?_, ?_⟩
  · rfl
  · rfl

/--
Both lists are admitted by the ordinary raw-history constructor. The
counterexample therefore does not depend on violating raw identity invariants.
-/
theorem base_raw_storage_admitted :
    (ActualValidityHistory.ofParts? baseFacts baseCorrections).isSome = true := by
  native_decide

theorem extended_raw_storage_admitted :
    (ActualValidityHistory.ofParts? extendedFacts extendedCorrections).isSome = true := by
  native_decide

/--
The original linear correction history has one admitted current validity
projection.
-/
theorem base_semantic_frontier_defined :
    (admittedActualValidityMemory? baseHistory).isSome = true := by
  native_decide

/--
After adding fresh retained evidence, the sibling topology is intentionally
ambiguous and semantic admission fails closed.
-/
theorem extended_semantic_frontier_refused :
    (admittedActualValidityMemory? extendedHistory).isSome = false := by
  native_decide

/--
The failure occurs at semantic frontier admission, not raw storage admission.
-/
theorem extended_frontier_is_not_admissible :
    actualValidityFrontierAdmissible extendedHistory = false := by
  native_decide

private def semanticDefined
    (history : ActualValidityHistory Nat) : Bool :=
  (admittedActualValidityMemory? history).isSome

/--
Naive definedness is not monotone under ordinary raw append-extension.

This single witness is sufficient for the R6 stop condition. It does not rule
out narrower domain-specific orders whose relation already encodes admissible
refinement.
-/
theorem semantic_definedness_not_monotone_under_raw_extension :
    ¬ ∀ left right : ActualValidityHistory Nat,
        RawExtends left right →
        semanticDefined left = true →
        semanticDefined right = true := by
  intro hMonotone
  have hExtended :=
    hMonotone
      baseHistory
      extendedHistory
      base_to_extended_is_raw_extension
      (by
        simpa [semanticDefined] using base_semantic_frontier_defined)
  have hRefused :
      semanticDefined extendedHistory = false := by
    simpa [semanticDefined] using extended_semantic_frontier_refused
  rw [hRefused] at hExtended
  cases hExtended

/-!
## Finding

The counterexample separates two different notions that a generic knowledge
lattice would otherwise blur:

```text
more retained raw provenance
    !=
more semantically admitted information
```

The added revision and edge are both fresh and structurally retainable. The
semantic layer nevertheless becomes less defined because the evidence now
supports two incompatible current successors.

Therefore LOAM should not introduce a repository-wide partial order, lattice,
or fixed-point vocabulary merely by ordering raw evidence through inclusion or
append-extension.

Narrow domain-specific orders remain possible, but they must build semantic
admissibility into the relation instead of assuming evidence quantity alone is
monotone.
-/

end Loam.Observation337
