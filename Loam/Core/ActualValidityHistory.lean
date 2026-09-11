import Loam.Core.ActualValidity
import Loam.Core.FiniteKeyed

namespace Loam.Core

set_option autoImplicit false

/-!
# Append-only Actual-validity history

Observation 096 qualified temporal correction as a relation between retained
temporal revisions rather than mutation of the Event or deletion of superseded
evidence. Observation 147 then qualified the narrower identity law used here:

- one Event-rooted base occurrence date has no separately allocated identity;
- later temporal revisions receive identity only when a correction occurs.

`ActualValidityMemory` remains the admitted current projection consumed by
historical routing and other applications. This history is the raw provenance
from which that one-current-date-per-Event view can be derived.
-/

/-- Stable identity allocated only for a later Actual-validity revision. -/
structure ActualValidityRevisionId where
  token : String
deriving Repr, DecidableEq

/-- Reference to either an Event-rooted base date or an identified later revision. -/
inductive ActualValidityRef where
  | root (event : EventId)
  | revision (id : ActualValidityRevisionId)
deriving Repr, DecidableEq

/--
One retained occurrence-date claim.

A base claim is identified by its Event. Only a later temporal revision carries
an independently allocated revision identity.
-/
inductive ActualValidityFact (Time : Type) where
  | base (event : EventId) (validOn : Time)
  | revision (id : ActualValidityRevisionId) (event : EventId) (validOn : Time)
deriving Repr, DecidableEq

namespace ActualValidityFact

variable {Time : Type}

/-- Structural reference used by correction provenance. -/
def ref : ActualValidityFact Time → ActualValidityRef
  | .base event _ => .root event
  | .revision id _ _ => .revision id

/-- Event whose occurrence date this retained fact describes. -/
def event : ActualValidityFact Time → EventId
  | .base event _ => event
  | .revision _ event _ => event

/-- Retained occurrence date coordinate. -/
def validOn : ActualValidityFact Time → Time
  | .base _ validOn => validOn
  | .revision _ _ validOn => validOn

end ActualValidityFact

/-- Stable identity for one correction between Actual-validity facts. -/
structure ActualValidityCorrectionId where
  token : String
deriving Repr, DecidableEq

/--
One append-only claim that an identified revision corrects an earlier base or
revision. The relation itself assigns no arrival-order or last-write-wins authority.
-/
structure ActualValidityCorrection where
  id : ActualValidityCorrectionId
  target : ActualValidityRef
  replacement : ActualValidityRevisionId
deriving Repr, DecidableEq

/--
Raw retained Actual-validity provenance.

Only fact references and correction identities are unique at this boundary.
Reference closure, same-Event replacement, acyclicity, conflicts, and the
one-current-date-per-Event law belong to the Application frontier admission.
List position is representation only.
-/
structure ActualValidityHistory (Time : Type) where
  facts : List (ActualValidityFact Time)
  factRefNodup : (facts.map ActualValidityFact.ref).Nodup
  corrections : List ActualValidityCorrection
  correctionIdNodup : (corrections.map ActualValidityCorrection.id).Nodup

namespace ActualValidityHistory

variable {Time : Type}

/-- Admit raw history only when retained fact references and correction identities are unique. -/
def ofParts?
    (facts : List (ActualValidityFact Time))
    (corrections : List ActualValidityCorrection) : Option (ActualValidityHistory Time) :=
  if hFacts : (facts.map ActualValidityFact.ref).Nodup then
    if hCorrections : (corrections.map ActualValidityCorrection.id).Nodup then
      some {
        facts := facts
        factRefNodup := hFacts
        corrections := corrections
        correctionIdNodup := hCorrections
      }
    else
      none
  else
    none

/-- Find one retained validity fact by structural base/revision reference. -/
def findFactByRef?
    (history : ActualValidityHistory Time)
    (ref : ActualValidityRef) : Option (ActualValidityFact Time) :=
  FiniteKeyed.findBy? ActualValidityFact.ref history.facts ref

/-- Find one retained validity correction by stable identity. -/
def findCorrectionById?
    (history : ActualValidityHistory Time)
    (id : ActualValidityCorrectionId) : Option ActualValidityCorrection :=
  FiniteKeyed.findBy? ActualValidityCorrection.id history.corrections id

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
        factRefNodup := by simp
        corrections := []
        correctionIdNodup := by simp
      } := by
  simp [ofParts?]

end ActualValidityHistory

end Loam.Core
