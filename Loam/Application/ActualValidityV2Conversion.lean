import Loam.ActualValidityV2Identity
import Loam.Application.ActualValidityFrontier

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

variable {Time : Type}

private def isReplacementId
    (history : ActualValidityHistory Time)
    (id : ActualValidityFactId) : Bool :=
  history.corrections.any fun correction => decide (correction.replacement = id)

private def compressedIdForFact
    (history : ActualValidityHistory Time)
    (fact : ActualValidityFact Time) : ActualValidityFactId :=
  if isReplacementId history fact.id then
    fact.id
  else
    Loam.ActualValidityV2.rootFactId fact.event

private def compressedIdForExisting?
    (history : ActualValidityHistory Time)
    (id : ActualValidityFactId) : Option ActualValidityFactId := do
  let fact ← history.findFactById? id
  pure (compressedIdForFact history fact)

private def compressCorrection?
    (history : ActualValidityHistory Time)
    (correction : ActualValidityCorrection) : Option ActualValidityCorrection := do
  let target ← compressedIdForExisting? history correction.target
  let replacement ← compressedIdForExisting? history correction.replacement
  pure {
    id := correction.id
    target := target
    replacement := replacement
  }

/--
Compress an already-admitted V1 history into the compatibility shape used by
V2 persistence.

Every source fact loses its independent stored identity and instead receives a
derived adapter id from EventId. Facts that are replacement endpoints retain
their identities because they are actual temporal revisions. Correction ids are
unchanged. The conversion refuses any V1 history that the existing production
frontier would not admit.
-/
def compressActualValidityV1ToV2?
    (history : ActualValidityHistory Time) : Option (ActualValidityHistory Time) := do
  if !actualValidityFrontierAdmissible history then
    none
  else
    let facts := history.facts.map fun fact =>
      { fact with id := compressedIdForFact history fact }
    let corrections ← history.corrections.mapM (compressCorrection? history)
    let compressed ← ActualValidityHistory.ofParts? facts corrections
    let oldCurrent ← admittedActualValidityMemory? history
    let newCurrent ← admittedActualValidityMemory? compressed
    if oldCurrent.entries = newCurrent.entries then
      pure compressed
    else
      none

/--
A V2-compatible history has exactly one Event-derived source identity for every
correction path; later replacement facts retain independent revision identity.
This predicate is representation validation only and assigns no winner by order.
-/
def actualValidityV2Compatible
    (history : ActualValidityHistory Time) : Bool :=
  history.facts.all fun fact =>
    if isReplacementId history fact.id then
      !Loam.ActualValidityV2.isRootFact fact
    else
      Loam.ActualValidityV2.isRootFact fact

end Loam.Application
