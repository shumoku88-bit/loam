import Loam.Core.EventMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.EventMerchantEvidence
import Loam.Core.ExchangeEvidence
import Loam.Core.OriginalAmountEvidence
import Loam.Core.MovementOperationEvidence
import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualReversal
import Loam.Core.OpenRelation

namespace Loam

open Loam.Core

set_option autoImplicit false

/--
Persistence-neutral aggregate of retained Actual evidence.

This aggregate is intentionally not itself a proof that every cross-family
semantic law has been admitted. Some members, notably Relation and Discharge,
remain raw retained provenance until an Application or persistence admission
boundary qualifies the question being asked.

This is not a new semantic family or a second semantic engine. It is an acquired
view of existing production evidence types that can be produced either from the
legacy multi-stream Movement files or directly from a single normalized `actual.loam`
representation.
-/
structure ActualEvidence where
  events : EventMemory
  validity : ActualValidityHistory String
  descriptions : EventDescriptionMemory
  merchants : EventMerchantEvidenceMemory
  exchanges : ExchangeEvidenceMemory := .empty
  originalAmounts : OriginalAmountEvidenceMemory := .empty
  movementOperations : MovementOperationEvidenceMemory := .empty
  corrections : EventCorrectionMemory
  reversals : ActualReversalMemory
  relations : List RelationUnit
  discharges : List RelationDischarge

/--
Whether retained Relation or Discharge provenance names one Event directly.

This is a raw membership query over already-retained evidence. It does not decide
whether an operation may change that Event; publishers and canonical admission
remain the owners of those operation-specific rules.
-/
def ActualEvidence.relationEvidenceMentionsEvent
    (evidence : ActualEvidence) (event : EventId) : Bool :=
  evidence.relations.any (fun relation => decide (relation.sourceEvent = event)) ||
    evidence.discharges.any (fun discharge => decide (discharge.event = event))

/-- The empty Actual evidence aggregate. -/
def ActualEvidence.empty : ActualEvidence := {
  events := { events := [], idNodup := by simp }
  validity := {
    facts := []
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp
  }
  descriptions := EventDescriptionMemory.empty
  merchants := EventMerchantEvidenceMemory.empty
  exchanges := ExchangeEvidenceMemory.empty
  originalAmounts := OriginalAmountEvidenceMemory.empty
  movementOperations := MovementOperationEvidenceMemory.empty
  corrections := { corrections := [], idNodup := by simp }
  reversals := ActualReversalMemory.empty
  relations := []
  discharges := []
}

end Loam
