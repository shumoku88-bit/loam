import Loam.Core.ActualValidity

namespace Loam.Core

set_option autoImplicit false

/-!
# Append-only Actual-validity history

Observation 096 qualified temporal correction as a relation between retained
TemporalFact identities rather than mutation of the Event or deletion of the
superseded temporal fact. This module realizes only that raw retained shape for
Actual validity evidence.

`ActualValidityMemory` remains the admitted current projection consumed by
historical routing and other applications. This history is the raw provenance
from which that one-current-date-per-Event view can be derived.
-/

/-- Stable identity for one retained Actual-validity fact. -/
structure ActualValidityFactId where
  token : String
deriving Repr, DecidableEq

/-- One retained claim that an Event was valid at one coordinate. -/
structure ActualValidityFact (Time : Type) where
  id : ActualValidityFactId
  event : EventId
  validOn : Time
deriving Repr, DecidableEq

/-- Stable identity for one correction between Actual-validity facts. -/
structure ActualValidityCorrectionId where
  token : String
deriving Repr, DecidableEq

/--
One append-only claim that a replacement validity fact corrects an earlier one.
The relation itself assigns no arrival-order or last-write-wins authority.
-/
structure ActualValidityCorrection where
  id : ActualValidityCorrectionId
  target : ActualValidityFactId
  replacement : ActualValidityFactId
deriving Repr, DecidableEq

/--
Raw retained Actual-validity provenance.

Only fact identity and correction identity are unique at this boundary.
Reference closure, same-Event replacement, acyclicity, conflicts, and the
one-current-date-per-Event law belong to the Application frontier admission.
List position is representation only.
-/
structure ActualValidityHistory (Time : Type) where
  facts : List (ActualValidityFact Time)
  factIdNodup : (facts.map ActualValidityFact.id).Nodup
  corrections : List ActualValidityCorrection
  correctionIdNodup : (corrections.map ActualValidityCorrection.id).Nodup

namespace ActualValidityHistory

variable {Time : Type}

/-- Admit raw history only when retained fact and correction identities are unique. -/
def ofParts?
    (facts : List (ActualValidityFact Time))
    (corrections : List ActualValidityCorrection) : Option (ActualValidityHistory Time) :=
  if hFacts : (facts.map ActualValidityFact.id).Nodup then
    if hCorrections : (corrections.map ActualValidityCorrection.id).Nodup then
      some {
        facts := facts
        factIdNodup := hFacts
        corrections := corrections
        correctionIdNodup := hCorrections
      }
    else
      none
  else
    none

private def findFactByIdIn? :
    List (ActualValidityFact Time) → ActualValidityFactId → Option (ActualValidityFact Time)
  | [], _ => none
  | fact :: rest, id =>
      if fact.id = id then some fact else findFactByIdIn? rest id

/-- Find one retained validity fact by stable identity. -/
def findFactById?
    (history : ActualValidityHistory Time)
    (id : ActualValidityFactId) : Option (ActualValidityFact Time) :=
  findFactByIdIn? history.facts id

private def findCorrectionByIdIn? :
    List ActualValidityCorrection → ActualValidityCorrectionId → Option ActualValidityCorrection
  | [], _ => none
  | correction :: rest, id =>
      if correction.id = id then some correction else findCorrectionByIdIn? rest id

/-- Find one retained validity correction by stable identity. -/
def findCorrectionById?
    (history : ActualValidityHistory Time)
    (id : ActualValidityCorrectionId) : Option ActualValidityCorrection :=
  findCorrectionByIdIn? history.corrections id

/-- Append one raw validity fact without deriving currentness from list position. -/
def addFact?
    (history : ActualValidityHistory Time)
    (fact : ActualValidityFact Time) : Option (ActualValidityHistory Time) :=
  ofParts? (history.facts ++ [fact]) history.corrections

/-- Append one raw validity correction without deriving a winner from list position. -/
def addCorrection?
    (history : ActualValidityHistory Time)
    (correction : ActualValidityCorrection) : Option (ActualValidityHistory Time) :=
  ofParts? history.facts (history.corrections ++ [correction])

@[simp] theorem ofParts?_nil :
    ofParts? ([] : List (ActualValidityFact Time)) [] =
      some {
        facts := []
        factIdNodup := by simp
        corrections := []
        correctionIdNodup := by simp
      } := by
  simp [ofParts?]

end ActualValidityHistory

end Loam.Core
