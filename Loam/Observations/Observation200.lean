import Loam.Core.Event

namespace Loam.Observation200

open Loam.Core

set_option autoImplicit false

/-!
# Observation 200 — quantity-preserving Effect split / merge invariance

Structural falsification item S003 asks a deliberately query-relative question.

One Event representation carries one Effect of quantity `left + right` at one
`Locus × Measure` coordinate. Another carries two distinct Effects of quantities
`left` and `right` at the same coordinate.

The claim under test is not that the Event representations are identical. Effect
identity and decomposition remain available to later provenance-sensitive
questions. The selected claim is only that the existing quantity projection
cannot observe this quantity-preserving decomposition.
-/

private def mergedEvent
    (id : EventId) (key : EffectKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) : Event :=
  { id := id
    effects := [Effect.ofQuantity key locus measure (left + right)]
    keyNodup := by simp }

private def splitEvent
    (id : EventId) (leftKey rightKey : EffectKey)
    (hDifferent : leftKey ≠ rightKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) : Event :=
  { id := id
    effects :=
      [ Effect.ofQuantity leftKey locus measure left
      , Effect.ofQuantity rightKey locus measure right
      ]
    keyNodup := by simp [hDifferent] }

/--
For arbitrary exact signed quantities, replacing one Effect carrying
`left + right` by two distinct Effects carrying `left` and `right` at the same
coordinate leaves the selected `Event.quantityAt` answer unchanged.
-/
theorem quantityAt_split_merge
    (id : EventId)
    (mergedKey leftKey rightKey : EffectKey)
    (hDifferent : leftKey ≠ rightKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    Event.quantityAt
        (mergedEvent id mergedKey locus measure left right)
        locus measure =
      Event.quantityAt
        (splitEvent id leftKey rightKey hDifferent locus measure left right)
        locus measure := by
  simp [mergedEvent, splitEvent, Event.quantityAt, Quantity.add, Int.add_assoc]

/--
The representation itself is still observably different: one side retains one
Effect and the other retains two. S003 therefore earns only a quantity-query
invariance law, not global Event equivalence or permission to erase Effect
identity/provenance.
-/
theorem split_merge_representation_remains_distinct
    (id : EventId)
    (mergedKey leftKey rightKey : EffectKey)
    (hDifferent : leftKey ≠ rightKey)
    (locus : LocusId) (measure : MeasureId)
    (left right : Quantity) :
    (mergedEvent id mergedKey locus measure left right).effects ≠
      (splitEvent id leftKey rightKey hDifferent locus measure left right).effects := by
  simp [mergedEvent, splitEvent]

/-!
## Candidate finding

If the theorem above qualifies on the exact observation head, S003 has a narrow
positive answer:

```text
quantity-preserving Effect split / merge
  -> invisible to Event.quantityAt at the decomposed coordinate
```

while the negative boundary remains explicit:

```text
Effect decomposition / identity
  -> still present in retained Event evidence
```

No generic quotient type, Event normalization, Effect deletion, persistence
change, or production rewrite follows from this observation.
-/

end Loam.Observation200
