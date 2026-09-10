import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-!
# Zero-origin quantity coverage

This is the narrow evidence earned by the reconstructed household path: one
explicit finite set of neutral quantity coordinates whose retained selected
Event history is known to begin at exact zero.

It is not an Account registry, balance-view policy, accounting role, visibility
window, writer permission, or generic coverage framework. Row order carries no
priority, presentation, temporal, or accounting meaning.

## Design Rationale

- **Current semantics**: An explicit finite set of `EffectCoordinate` (Locus × Measure)
  whose selected retained Event history is affirmatively known to begin at exact zero.
  Balance queries (`inspectZeroOriginQuantity`) are answerable if and only if the queried
  coordinate is an admitted member of this set.

- **Why this design**: Distinguishes "retained history begins at exact zero" from
  "unknown/unrecorded historical starting balance". Factoring out the known-zero premise
  from historical `QuantityBasis` eliminates redundant pointwise-zero storage while preserving
  the fail-closed boundary: missing coverage means unavailable, never implicit zero.

- **Prohibited simplifications**:
  1. *Why not default zero?*: Missing history is unknown, not zero. If an untracked wallet
     or pre-adoption account is queried, assuming 0 fabricates purchasing power or hides
     missing history, corrupting financial decisions. Uncovered coordinates must fail closed
     as `.coverageMissing`.
  2. *Why not derive coverage from Event activity?*: An account with 10 recorded transactions
     does not prove its starting balance was 0; it could have started at 100,000 JPY.
     Event presence proves activity, not origin completeness.
  3. *Why not derive coverage from balance-view or Locus admission?*: `balance-view.tsv`
     selects presentation questions only; `LocusAdmissionVocabulary` guards new write spelling.
     Neither constitutes a factual assertion that historical origin was zero.
  4. *Why not a universal Coverage ontology?*: World completeness, scheduled horizon completeness,
     and quantity origin completeness share only an abstract information order; collapsing them
     into a single generic type conflates unrelated semantic authorities.

- **Permanent evidence references**:
  - `Loam.Application.ZeroOriginQuantity.inspectZeroOriginQuantity_missing`: Proves that an empty
    coverage set yields `.coverageMissing` regardless of Event or EventCorrection contents.
  - Observations 090, 219, 221, 223, 224: Document the elimination of pointwise-zero QuantityBasis
    and the rejection of implicit-zero defaults and importer-fabricated opening events.
-/

/-- Explicit finite evidence that selected retained history is complete from zero. -/
structure ZeroOriginCoverage where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup

namespace ZeroOriginCoverage

/-- Admit one finite zero-origin set only when coordinates are unique. -/
def ofCoordinates? (coordinates : List EffectCoordinate) : Option ZeroOriginCoverage :=
  if h : coordinates.Nodup then
    some { coordinates := coordinates, nodup := h }
  else
    none

/-- The empty evidence set proves no coordinate complete from zero. -/
def empty : ZeroOriginCoverage :=
  { coordinates := [], nodup := by simp }

/-- Whether one neutral quantity coordinate has explicit zero-origin evidence. -/
def covers (coverage : ZeroOriginCoverage) (coordinate : EffectCoordinate) : Bool :=
  decide (coordinate ∈ coverage.coordinates)

end ZeroOriginCoverage

end Loam.Core
