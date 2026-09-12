import Loam.Core.EventMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualReversal
import Loam.Core.OpenRelation

namespace Loam

open Loam.Core

set_option autoImplicit false

/--
Persistence-neutral aggregate of admitted Actual evidence.

This is not a new semantic family or a second semantic engine. It is an acquired
view of existing production evidence types that can be produced either from the
legacy multi-stream Movement files or directly from a single normalized `actual.loam`
representation.
-/
structure ActualEvidence where
  events : EventMemory
  validity : ActualValidityHistory String
  descriptions : EventDescriptionMemory
  corrections : EventCorrectionMemory
  reversals : ActualReversalMemory
  relations : List RelationUnit
  discharges : List RelationDischarge

end Loam
