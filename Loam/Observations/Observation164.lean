import Loam.Observations.Observation159
import Loam.Observations.Observation163
import Loam.Observations.Observation164Contract

namespace Loam.Observation164

open Loam.Core
open Loam.Observation159
open Loam.Observation164Contract

set_option autoImplicit false

/-!
# Observation 164 — independent statement surface

Observation 163 demonstrated that a reviewed proposition and implementation can
remain aligned while a definition shared by both drifts. This observation tests
the smallest countermeasure: put the reviewed semantic surface in a module that
does not import the implementation vocabulary, then bridge implementation
observables onto it.

This is not Comparator yet. It asks whether separating the statement surface is
already enough to make the Observation 163 drift visible.
-/

/-- Read one implementation coordinate as plain integer quanta. -/
def observedQuanta
    (presentation : List (MovementChange Coordinate))
    (coordinate : Coordinate) : Int :=
  (aggregateAt presentation coordinate).quanta

/-- Observation 159's intended witness satisfies the independent reviewed surface. -/
theorem observation159_inhabits_independent_surface :
    ExpectedVectorClaim
      (observedQuanta compactPresentation Coordinate.wallet)
      (observedQuanta compactPresentation Coordinate.food)
      (observedQuanta splitPresentation Coordinate.wallet)
      (observedQuanta splitPresentation Coordinate.food) := by
  simp [ExpectedVectorClaim, observedQuanta, aggregateAt,
    compactPresentation, splitPresentation]

/--
The coupled-drift witness from Observation 163 is rejected without mentioning
`VectorEquivalent` or `DriftedMeaning` in the reviewed contract.
-/
theorem observation163_drift_is_rejected_by_independent_surface :
    ¬ ExpectedVectorClaim
      (observedQuanta Loam.Observation163.driftLeft Coordinate.wallet)
      (observedQuanta Loam.Observation163.driftLeft Coordinate.food)
      (observedQuanta Loam.Observation163.driftRight Coordinate.wallet)
      (observedQuanta Loam.Observation163.driftRight Coordinate.food) := by
  simp [ExpectedVectorClaim, observedQuanta, aggregateAt,
    Loam.Observation163.driftLeft, Loam.Observation163.driftRight]

/-!
The result is deliberately narrow. The contract file itself is still reviewed
by humans and can itself be edited. This observation only removes the accidental
coupling where the reviewed claim imports the very implementation definition it
is supposed to constrain. A future Comparator trial can test stronger structural
and dependency alignment between independently exported environments.
-/

end Loam.Observation164
