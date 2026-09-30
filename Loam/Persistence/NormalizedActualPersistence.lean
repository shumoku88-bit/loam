import Loam.Core.ActualEvidence
import Loam.Core.Event
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
import Loam.Persistence.NormalizedActualAdmission
import Loam.Persistence.TokenSyntax

namespace Loam.Persistence

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-- Version-1 header for TX-only normalized Actual documents. -/
def normalizedActualHeaderV1 : String := "LOAM-NORMALIZED-ACTUAL\t1"

/-- Version-2 header adding document-level retained settlement evidence. -/
def normalizedActualHeaderV2 : String := "LOAM-NORMALIZED-ACTUAL\t2"

/-- Version-3 header adding append-only settlement commitment revision evidence. -/
def normalizedActualHeaderV3 : String := "LOAM-NORMALIZED-ACTUAL\t3"

/-- Version-4 header adding quantity-bearing non-settlement extinguishment evidence. -/
def normalizedActualHeaderV4 : String := "LOAM-NORMALIZED-ACTUAL\t4"

private inductive NormalizedActualWireVersion where
  | v1
  | v2
  | v3
  | v4
deriving Repr, DecidableEq

private def normalizedActualWireVersion? (header : String) : Option NormalizedActualWireVersion :=
  if header == normalizedActualHeaderV1 then
    some .v1
  else if header == normalizedActualHeaderV2 then
    some .v2
  else if header == normalizedActualHeaderV3 then
    some .v3
  else if header == normalizedActualHeaderV4 then
    some .v4
  else
    none

/-- Format one open relation endpoint for normalized wire representation. -/
def formatEndpoint (endpoint : RelationEndpoint) : String :=
  match endpoint with
  | .household => "household"
  | .external id => "external:" ++ id.token

/-- Parse one open relation endpoint from normalized wire representation. -/
def parseEndpoint? (s : String) : Option RelationEndpoint :=
  if s == "household" then
    some .household
  else if s.startsWith "external:" then
    let token := (s.drop 9).toString
    if validToken token then
      some (.external ⟨token⟩)
    else
      none
  else
    none

/-- Machine-readable reason for a syntax or wire-level parse failure. -/
inductive NormalizedActualParseErrorReason where
  | missingFinalNewline
  | emptyDocument
  | invalidHeader (found : String)
  | malformedTxRow (detail : String)
  | malformedRow (rowType : String) (detail : String)
  | unknownRowType (rowType : String)
  | missingEndTx (event : EventId) (txLine : Nat)
  | invalidToken (token : String)
  | invalidInteger (value : String)
  | duplicateMerchant
  | duplicateExchange
  | duplicateOriginalAmount
  | duplicateOperation
  | duplicateReplaces
  | duplicateReversalOf
deriving Repr, DecidableEq

/-- A structured parse error with a 1-indexed line number in the document. -/
structure NormalizedActualParseError where
  line : Nat
  reason : NormalizedActualParseErrorReason
deriving Repr, DecidableEq

/-- Human-readable description of a parse error. -/
def NormalizedActualParseError.message (err : NormalizedActualParseError) : String :=
  let reasonMsg := match err.reason with
    | .missingFinalNewline => "document must end with a newline"
    | .emptyDocument => "empty document"
    | .invalidHeader found => s!"invalid header: '{found}', expected '{normalizedActualHeaderV1}', '{normalizedActualHeaderV2}', '{normalizedActualHeaderV3}', or '{normalizedActualHeaderV4}'"
    | .malformedTxRow detail => s!"malformed TX row: {detail}"
    | .malformedRow rowType detail => s!"malformed {rowType} row: {detail}"
    | .unknownRowType rowType => s!"unknown row type: '{rowType}'"
    | .missingEndTx event txLine => s!"missing ENDTX for transaction '{event.token}' (opened at line {txLine})"
    | .invalidToken token => s!"invalid token: '{token}'"
    | .invalidInteger value => s!"invalid integer quantity: '{value}'"
    | .duplicateMerchant => "duplicate MERCHANT or NONMERCHANT row in transaction"
    | .duplicateExchange => "duplicate EXCHANGE row in transaction"
    | .duplicateOriginalAmount => "duplicate ORIGINAL-AMOUNT row in transaction"
    | .duplicateOperation => "duplicate OPERATION row in transaction"
    | .duplicateReplaces => "duplicate REPLACES row in transaction"
    | .duplicateReversalOf => "duplicate REVERSAL-OF row in transaction"
  s!"line {err.line}: {reasonMsg}"

instance : ToString NormalizedActualParseError where
  toString := NormalizedActualParseError.message

/-- Failure during construction of Core domain aggregate memories from parsed transactions. -/
inductive NormalizedActualConstructionError where
  | eventEffects (event : EventId)
  | eventMemory
  | validityHistory
  | descriptionMemory
  | merchantMemory
  | exchangeMemory
  | originalAmountMemory
  | movementOperationMemory
  | correctionMemory
  | reversalMemory
deriving Repr, DecidableEq

/-- Human-readable description of an aggregate construction error. -/
def NormalizedActualConstructionError.message : NormalizedActualConstructionError → String
  | .eventEffects ev => s!"failed to construct Event '{ev.token}': invalid or duplicate effect keys"
  | .eventMemory => "failed to construct EventMemory: duplicate EventId found"
  | .validityHistory => "failed to construct ActualValidityHistory: duplicate revision or invalid validity parts"
  | .descriptionMemory => "failed to construct EventDescriptionMemory: duplicate description for event"
  | .merchantMemory => "failed to construct EventMerchantEvidenceMemory: duplicate merchant disposition for event"
  | .exchangeMemory => "failed to construct ExchangeEvidenceMemory: duplicate exchange for event"
  | .originalAmountMemory => "failed to construct OriginalAmountEvidenceMemory: duplicate event or nonpositive quantity"
  | .movementOperationMemory => "failed to construct MovementOperationEvidenceMemory: duplicate operation or event mapping"
  | .correctionMemory => "failed to construct EventCorrectionMemory: duplicate replacement event"
  | .reversalMemory => "failed to construct ActualReversalMemory: reversal endpoint identity reused"

instance : ToString NormalizedActualConstructionError where
  toString := NormalizedActualConstructionError.message

/--
High-level diagnostic error during normalized Actual document decoding.
Distinguishes syntax/parse failures, memory construction failures, and semantic re-admission failures.
-/
inductive NormalizedActualDecodeError where
  | parse (err : NormalizedActualParseError)
  | construction (err : NormalizedActualConstructionError)
  | admission
deriving Repr, DecidableEq

/-- Human-readable description of a decoding error. -/
def NormalizedActualDecodeError.message : NormalizedActualDecodeError → String
  | .parse err => err.message
  | .construction err => err.message
  | .admission => "semantic admission failed: aggregates violate ledger invariants or referential closure"

instance : ToString NormalizedActualDecodeError where
  toString := NormalizedActualDecodeError.message

/--
Intermediate per-transaction parsing state during normalized Actual decoding.
-/
private structure ParsedTx where
  event : EventId
  baseValidOn : String
  description : Option String
  merchant : Option MerchantDisposition
  exchange : Option ExchangeEvidence
  originalAmount : Option OriginalAmountEvidence
  movementOperation : Option MovementOperationId
  replaces : Option EventId
  reversalOf : Option EventId
  effects : List Effect
  dateRevisions : List (ActualValidityRevisionId × String × ActualValidityRef)
  relations : List RelationUnit
  discharges : List RelationDischarge

private structure TxDraft where
  txLine : Nat
  lastLine : Nat
  event : EventId
  baseValidOn : String
  description : Option String
  merchant : Option MerchantDisposition := none
  exchange : Option ExchangeEvidence := none
  originalAmount : Option OriginalAmountEvidence := none
  movementOperation : Option MovementOperationId := none
  replaces : Option EventId := none
  reversalOf : Option EventId := none
  effects : List Effect := []
  dateRevisions : List (ActualValidityRevisionId × String × ActualValidityRef) := []
  relations : List RelationUnit := []
  discharges : List RelationDischarge := []

private structure TxParserState where
  current : Option TxDraft := none
  completed : List ParsedTx := []

private def stepTxParser
    (state : TxParserState)
    (item : Nat × String) : Except NormalizedActualParseError TxParserState :=
  let (lineNo, row) := item
  match state.current with
  | none =>
      let fields := row.splitOn "\t"
      match fields with
      | ["TX", eventToken, baseDate, "NODESC"] => do
          if !validToken eventToken then
            Except.error { line := lineNo, reason := .invalidToken eventToken }
          else if !validToken baseDate then
            Except.error { line := lineNo, reason := .invalidToken baseDate }
          else
            Except.ok { state with
              current := some {
                txLine := lineNo
                lastLine := lineNo
                event := ⟨eventToken⟩
                baseValidOn := baseDate
                description := none
              }
            }
      | "TX" :: eventToken :: baseDate :: "DESC" :: descFields => do
          if !validToken eventToken then
            Except.error { line := lineNo, reason := .invalidToken eventToken }
          else if !validToken baseDate then
            Except.error { line := lineNo, reason := .invalidToken baseDate }
          else
            let descText := String.intercalate "\t" descFields
            if descText.isEmpty || descText.contains '\n' || descText.contains '\r' then
              Except.error { line := lineNo, reason := .malformedTxRow "invalid description text" }
            else
              Except.ok { state with
                current := some {
                  txLine := lineNo
                  lastLine := lineNo
                  event := ⟨eventToken⟩
                  baseValidOn := baseDate
                  description := some descText
                }
              }
      | _ =>
          if fields.head? == some "TX" then
            Except.error { line := lineNo, reason := .malformedTxRow "expected TX <event> <date> [NODESC|DESC <text>]" }
          else
            Except.error { line := lineNo, reason := .unknownRowType (fields.head?.getD "") }
  | some draft =>
      if row == "ENDTX" then
        Except.ok {
          current := none
          completed := {
            event := draft.event
            baseValidOn := draft.baseValidOn
            description := draft.description
            merchant := draft.merchant
            exchange := draft.exchange
            originalAmount := draft.originalAmount
            movementOperation := draft.movementOperation
            replaces := draft.replaces
            reversalOf := draft.reversalOf
            effects := draft.effects
            dateRevisions := draft.dateRevisions
            relations := draft.relations
            discharges := draft.discharges
          } :: state.completed
        }
      else if row.startsWith "TX\t" || row == "TX" then
        Except.error { line := lineNo, reason := .missingEndTx draft.event draft.txLine }
      else
        let fields := row.splitOn "\t"
        match fields with
        | ["MERCHANT", partyToken] =>
            if draft.merchant.isSome then
              Except.error { line := lineNo, reason := .duplicateMerchant }
            else if !validToken partyToken then
              Except.error { line := lineNo, reason := .invalidToken partyToken }
            else
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  merchant := some (.merchant ⟨partyToken⟩)
                }
              }
        | ["NONMERCHANT"] =>
            if draft.merchant.isSome then
              Except.error { line := lineNo, reason := .duplicateMerchant }
            else
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  merchant := some .nonmerchant
                }
              }
        | ["EXCHANGE", sourceKey, destinationKey] =>
            if draft.exchange.isSome then
              Except.error { line := lineNo, reason := .duplicateExchange }
            else if !validToken sourceKey then
              Except.error { line := lineNo, reason := .invalidToken sourceKey }
            else if !validToken destinationKey then
              Except.error { line := lineNo, reason := .invalidToken destinationKey }
            else
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  exchange := some {
                    event := draft.event
                    source := ⟨sourceKey⟩
                    destination := ⟨destinationKey⟩
                  }
                }
              }
        | ["ORIGINAL-AMOUNT", measureToken, quantityStr] => do
            if draft.originalAmount.isSome then
              Except.error { line := lineNo, reason := .duplicateOriginalAmount }
            else if !validToken measureToken then
              Except.error { line := lineNo, reason := .invalidToken measureToken }
            else
              match quantityStr.toInt? with
              | none =>
                  Except.error { line := lineNo, reason := .invalidInteger quantityStr }
              | some quanta =>
                  Except.ok { state with
                    current := some { draft with
                      lastLine := lineNo
                      originalAmount := some {
                        event := draft.event
                        measure := ⟨measureToken⟩
                        quantity := Quantity.ofQuanta quanta
                      }
                    }
                  }
        | ["OPERATION", operationToken] =>
            if draft.movementOperation.isSome then
              Except.error { line := lineNo, reason := .duplicateOperation }
            else if !validToken operationToken then
              Except.error { line := lineNo, reason := .invalidToken operationToken }
            else
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  movementOperation := some ⟨operationToken⟩
                }
              }
        | ["REPLACES", target] =>
            if draft.replaces.isSome then
              Except.error { line := lineNo, reason := .duplicateReplaces }
            else if !validToken target then
              Except.error { line := lineNo, reason := .invalidToken target }
            else
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  replaces := some ⟨target⟩
                }
              }
        | ["REVERSAL-OF", target] =>
            if draft.reversalOf.isSome then
              Except.error { line := lineNo, reason := .duplicateReversalOf }
            else if !validToken target then
              Except.error { line := lineNo, reason := .invalidToken target }
            else
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  reversalOf := some ⟨target⟩
                }
              }
        | ["EFFECT", locus, measure, quantityStr] => do
            match quantityStr.toInt? with
            | none => Except.error { line := lineNo, reason := .invalidInteger quantityStr }
            | some quanta =>
                if !validToken locus then
                  Except.error { line := lineNo, reason := .invalidToken locus }
                else if !validToken measure then
                  Except.error { line := lineNo, reason := .invalidToken measure }
                else
                  let effect := Effect.ofAnonymousQuantity ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)
                  Except.ok { state with
                    current := some { draft with
                      lastLine := lineNo
                      effects := draft.effects ++ [effect]
                    }
                  }
        | ["KEYED-EFFECT", key, locus, measure, quantityStr] => do
            match quantityStr.toInt? with
            | none => Except.error { line := lineNo, reason := .invalidInteger quantityStr }
            | some quanta =>
                if !validToken key then
                  Except.error { line := lineNo, reason := .invalidToken key }
                else if !validToken locus then
                  Except.error { line := lineNo, reason := .invalidToken locus }
                else if !validToken measure then
                  Except.error { line := lineNo, reason := .invalidToken measure }
                else
                  let effect := Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)
                  Except.ok { state with
                    current := some { draft with
                      lastLine := lineNo
                      effects := draft.effects ++ [effect]
                    }
                  }
        | ["DATE-REV", revId, date, "REPLACES", "ROOT"] =>
            if !validToken revId then
              Except.error { line := lineNo, reason := .invalidToken revId }
            else if !validToken date then
              Except.error { line := lineNo, reason := .invalidToken date }
            else
              let item := (⟨revId⟩, date, ActualValidityRef.root draft.event)
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  dateRevisions := draft.dateRevisions ++ [item]
                }
              }
        | ["DATE-REV", revId, date, "REPLACES", "REV", prior] =>
            if !validToken revId then
              Except.error { line := lineNo, reason := .invalidToken revId }
            else if !validToken date then
              Except.error { line := lineNo, reason := .invalidToken date }
            else if !validToken prior then
              Except.error { line := lineNo, reason := .invalidToken prior }
            else
              let item := (⟨revId⟩, date, ActualValidityRef.revision ⟨prior⟩)
              Except.ok { state with
                current := some { draft with
                  lastLine := lineNo
                  dateRevisions := draft.dateRevisions ++ [item]
                }
              }
        | ["RELATION", relId, "SOURCE", key, debtorStr, creditorStr, quantityStr] => do
            match quantityStr.toInt? with
            | none => Except.error { line := lineNo, reason := .invalidInteger quantityStr }
            | some quanta =>
                if !validToken relId then
                  Except.error { line := lineNo, reason := .invalidToken relId }
                else if !validToken key then
                  Except.error { line := lineNo, reason := .invalidToken key }
                else
                  let debtor ← match parseEndpoint? debtorStr with
                    | some d => Except.ok d
                    | none => Except.error { line := lineNo, reason := .malformedRow "RELATION" s!"invalid debtor endpoint '{debtorStr}'" }
                  let creditor ← match parseEndpoint? creditorStr with
                    | some c => Except.ok c
                    | none => Except.error { line := lineNo, reason := .malformedRow "RELATION" s!"invalid creditor endpoint '{creditorStr}'" }
                  let rel : RelationUnit := {
                    id := ⟨relId⟩
                    sourceEvent := draft.event
                    sourceEffect := ⟨key⟩
                    debtor := debtor
                    creditor := creditor
                    quantity := Quantity.ofQuanta quanta
                  }
                  Except.ok { state with
                    current := some { draft with
                      lastLine := lineNo
                      relations := draft.relations ++ [rel]
                    }
                  }
        | ["DISCHARGE", relId, quantityStr] => do
            match quantityStr.toInt? with
            | none => Except.error { line := lineNo, reason := .invalidInteger quantityStr }
            | some quanta =>
                if !validToken relId then
                  Except.error { line := lineNo, reason := .invalidToken relId }
                else
                  let discharge : RelationDischarge := {
                    event := draft.event
                    target := ⟨relId⟩
                    quantity := Quantity.ofQuanta quanta
                  }
                  Except.ok { state with
                    current := some { draft with
                      lastLine := lineNo
                      discharges := draft.discharges ++ [discharge]
                    }
                  }
        | _ =>
            let head := fields.head?
            if head == some "MERCHANT" then
              Except.error { line := lineNo, reason := .malformedRow "MERCHANT" s!"expected 2 fields, got {fields.length}" }
            else if head == some "NONMERCHANT" then
              Except.error { line := lineNo, reason := .malformedRow "NONMERCHANT" s!"expected 1 field, got {fields.length}" }
            else if head == some "EXCHANGE" then
              Except.error { line := lineNo, reason := .malformedRow "EXCHANGE" s!"expected 3 fields, got {fields.length}" }
            else if head == some "ORIGINAL-AMOUNT" then
              Except.error { line := lineNo, reason := .malformedRow "ORIGINAL-AMOUNT" s!"expected 3 fields, got {fields.length}" }
            else if head == some "OPERATION" then
              Except.error { line := lineNo, reason := .malformedRow "OPERATION" s!"expected 2 fields, got {fields.length}" }
            else if head == some "REPLACES" then
              Except.error { line := lineNo, reason := .malformedRow "REPLACES" s!"expected 2 fields, got {fields.length}" }
            else if head == some "REVERSAL-OF" then
              Except.error { line := lineNo, reason := .malformedRow "REVERSAL-OF" s!"expected 2 fields, got {fields.length}" }
            else if head == some "EFFECT" then
              Except.error { line := lineNo, reason := .malformedRow "EFFECT" s!"expected 4 fields, got {fields.length}" }
            else if head == some "KEYED-EFFECT" then
              Except.error { line := lineNo, reason := .malformedRow "KEYED-EFFECT" s!"expected 5 fields, got {fields.length}" }
            else if head == some "DATE-REV" then
              Except.error { line := lineNo, reason := .malformedRow "DATE-REV" "invalid DATE-REV pattern" }
            else if head == some "RELATION" then
              Except.error { line := lineNo, reason := .malformedRow "RELATION" "expected RELATION <id> SOURCE <key> <debtor> <creditor> <quantity>" }
            else if head == some "DISCHARGE" then
              Except.error { line := lineNo, reason := .malformedRow "DISCHARGE" "expected DISCHARGE <relId> <quantity>" }
            else
              Except.error { line := lineNo, reason := .unknownRowType (head.getD "") }

private def parseTxs (rows : List (Nat × String)) :
    Except NormalizedActualParseError (List ParsedTx) := do
  let finalState ← rows.foldlM stepTxParser {}
  match finalState.current with
  | some draft =>
      Except.error { line := draft.lastLine, reason := .missingEndTx draft.event draft.txLine }
  | none =>
      Except.ok finalState.completed.reverse


private structure SettlementParseState where
  commitments : List SettlementCommitment := []
  commitmentRevisions : List SettlementCommitmentRevision := []
  extinguishments : List SettlementCommitmentExtinguishment := []
  extinguishmentRevisions : List SettlementExtinguishmentRevision := []
  correspondences : List SettlementEffectCorrespondence := []
  correspondenceRevisions : List SettlementCorrespondenceRevision := []
  nettingContexts : List SettlementNettingContext := []
  nettingMembers : List SettlementNettingMember := []
  nettingMemberRevisions : List SettlementNettingMemberRevision := []

private def isSettlementRowType (rowType : String) : Bool :=
  rowType == "SETTLEMENT-COMMITMENT" ||
  rowType == "SETTLEMENT-COMMITMENT-REVISION" ||
  rowType == "SETTLEMENT-EXTINGUISHMENT" ||
  rowType == "SETTLEMENT-EXTINGUISHMENT-REVISION" ||
  rowType == "SETTLEMENT-CORRESPONDENCE" ||
  rowType == "SETTLEMENT-CORRESPONDENCE-REVISION" ||
  rowType == "SETTLEMENT-NETTING" ||
  rowType == "SETTLEMENT-MEMBER" ||
  rowType == "SETTLEMENT-MEMBER-REVISION"

private def stepSettlementParser
    (state : SettlementParseState)
    (item : Nat × String) : Except NormalizedActualParseError SettlementParseState := do
  let (lineNo, row) := item
  let fields := row.splitOn "\t"
  match fields with
  | ["SETTLEMENT-COMMITMENT", id, "SOURCE", sourceEvent, sourceEffect,
      debtorText, creditorText, measure, quantityText] => do
      for token in [id, sourceEvent, sourceEffect, measure] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      let debtor ← match parseEndpoint? debtorText with
        | some endpoint => pure endpoint
        | none =>
            throw {
              line := lineNo
              reason := .malformedRow "SETTLEMENT-COMMITMENT"
                s!"invalid debtor endpoint '{debtorText}'"
            }
      let creditor ← match parseEndpoint? creditorText with
        | some endpoint => pure endpoint
        | none =>
            throw {
              line := lineNo
              reason := .malformedRow "SETTLEMENT-COMMITMENT"
                s!"invalid creditor endpoint '{creditorText}'"
            }
      let quanta ← match quantityText.toInt? with
        | some value => pure value
        | none => throw { line := lineNo, reason := .invalidInteger quantityText }
      pure {
        state with
        commitments := {
          id := ⟨id⟩
          sourceEvent := ⟨sourceEvent⟩
          sourceEffect := ⟨sourceEffect⟩
          debtor := debtor
          creditor := creditor
          measure := ⟨measure⟩
          quantity := Quantity.ofQuanta quanta
        } :: state.commitments
      }
  | ["SETTLEMENT-COMMITMENT-REVISION", target, "REPLACEMENT", replacement] => do
      for token in [target, replacement] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      pure {
        state with
        commitmentRevisions := {
          target := ⟨target⟩
          replacement := some ⟨replacement⟩
        } :: state.commitmentRevisions
      }
  | ["SETTLEMENT-COMMITMENT-REVISION", target, "RETRACT"] => do
      if !validToken target then
        throw { line := lineNo, reason := .invalidToken target }
      pure {
        state with
        commitmentRevisions := {
          target := ⟨target⟩
          replacement := none
        } :: state.commitmentRevisions
      }
  | ["SETTLEMENT-EXTINGUISHMENT", id, "TARGET", target, quantityText, "UNKNOWN"] => do
      for token in [id, target] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      let quanta ← match quantityText.toInt? with
        | some value => pure value
        | none => throw { line := lineNo, reason := .invalidInteger quantityText }
      pure {
        state with
        extinguishments := {
          id := ⟨id⟩
          target := ⟨target⟩
          quantity := Quantity.ofQuanta quanta
          effectiveOn := none
        } :: state.extinguishments
      }
  | ["SETTLEMENT-EXTINGUISHMENT", id, "TARGET", target, quantityText,
      "EFFECTIVE", effectiveOn] => do
      for token in [id, target, effectiveOn] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      let quanta ← match quantityText.toInt? with
        | some value => pure value
        | none => throw { line := lineNo, reason := .invalidInteger quantityText }
      pure {
        state with
        extinguishments := {
          id := ⟨id⟩
          target := ⟨target⟩
          quantity := Quantity.ofQuanta quanta
          effectiveOn := some effectiveOn
        } :: state.extinguishments
      }
  | ["SETTLEMENT-EXTINGUISHMENT-REVISION", target, "REPLACEMENT", replacement] => do
      for token in [target, replacement] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      pure {
        state with
        extinguishmentRevisions := {
          target := ⟨target⟩
          replacement := some ⟨replacement⟩
        } :: state.extinguishmentRevisions
      }
  | ["SETTLEMENT-EXTINGUISHMENT-REVISION", target, "RETRACT"] => do
      if !validToken target then
        throw { line := lineNo, reason := .invalidToken target }
      pure {
        state with
        extinguishmentRevisions := {
          target := ⟨target⟩
          replacement := none
        } :: state.extinguishmentRevisions
      }
  | ["SETTLEMENT-CORRESPONDENCE", id, "TARGET", target, "PHYSICAL",
      event, effect, quantityText] => do
      for token in [id, target, event, effect] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      let quanta ← match quantityText.toInt? with
        | some value => pure value
        | none => throw { line := lineNo, reason := .invalidInteger quantityText }
      pure {
        state with
        correspondences := {
          id := ⟨id⟩
          target := ⟨target⟩
          event := ⟨event⟩
          effect := ⟨effect⟩
          quantity := Quantity.ofQuanta quanta
        } :: state.correspondences
      }
  | ["SETTLEMENT-CORRESPONDENCE-REVISION", target, "REPLACEMENT", replacement] => do
      for token in [target, replacement] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      pure {
        state with
        correspondenceRevisions := {
          target := ⟨target⟩
          replacement := ⟨replacement⟩
        } :: state.correspondenceRevisions
      }
  | ["SETTLEMENT-NETTING", id, measure, "ZERO"] => do
      for token in [id, measure] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      pure {
        state with
        nettingContexts := {
          id := ⟨id⟩
          measure := ⟨measure⟩
          outcome := .zero
        } :: state.nettingContexts
      }
  | ["SETTLEMENT-NETTING", id, measure, "PHYSICAL", event, effect] => do
      for token in [id, measure, event, effect] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      pure {
        state with
        nettingContexts := {
          id := ⟨id⟩
          measure := ⟨measure⟩
          outcome := .physical ⟨event⟩ ⟨effect⟩
        } :: state.nettingContexts
      }
  | ["SETTLEMENT-MEMBER", id, "CONTEXT", context, "TARGET", target, quantityText] => do
      for token in [id, context, target] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      let quanta ← match quantityText.toInt? with
        | some value => pure value
        | none => throw { line := lineNo, reason := .invalidInteger quantityText }
      pure {
        state with
        nettingMembers := {
          id := ⟨id⟩
          context := ⟨context⟩
          target := ⟨target⟩
          quantity := Quantity.ofQuanta quanta
        } :: state.nettingMembers
      }
  | ["SETTLEMENT-MEMBER-REVISION", target, "REPLACEMENT", replacement] => do
      for token in [target, replacement] do
        if !validToken token then
          throw { line := lineNo, reason := .invalidToken token }
      pure {
        state with
        nettingMemberRevisions := {
          target := ⟨target⟩
          replacement := ⟨replacement⟩
        } :: state.nettingMemberRevisions
      }
  | _ =>
      let rowType := fields.head?.getD ""
      if isSettlementRowType rowType then
        throw {
          line := lineNo
          reason := .malformedRow rowType "invalid settlement row shape"
        }
      else
        throw { line := lineNo, reason := .unknownRowType rowType }

private structure SettlementDocumentParserState where
  tx : TxParserState := {}
  settlementStarted : Bool := false
  settlement : SettlementParseState := {}

private def stepSettlementDocumentParser
    (allowCommitmentRevisions : Bool)
    (allowExtinguishments : Bool)
    (state : SettlementDocumentParserState)
    (item : Nat × String) :
    Except NormalizedActualParseError SettlementDocumentParserState := do
  let (lineNo, row) := item
  let rowType := (row.splitOn "\t").head?.getD ""
  if rowType == "SETTLEMENT-COMMITMENT-REVISION" && !allowCommitmentRevisions then
    throw {
      line := lineNo
      reason := .malformedRow rowType
        "settlement commitment revisions require normalized Actual v3"
    }
  if (rowType == "SETTLEMENT-EXTINGUISHMENT" ||
      rowType == "SETTLEMENT-EXTINGUISHMENT-REVISION") &&
      !allowExtinguishments then
    throw {
      line := lineNo
      reason := .malformedRow rowType
        "settlement extinguishment evidence requires normalized Actual v4"
    }
  if state.settlementStarted then
    if !isSettlementRowType rowType then
      throw {
        line := lineNo
        reason := .malformedRow rowType
          "transaction rows may not follow the document-level settlement region"
      }
    let settlement ← stepSettlementParser state.settlement item
    pure { state with settlement := settlement }
  else
    match state.tx.current with
    | some draft =>
        if isSettlementRowType rowType then
          throw {
            line := lineNo
            reason := .malformedRow rowType
              s!"document-level settlement row appears inside transaction '{draft.event.token}'"
          }
        let tx ← stepTxParser state.tx item
        pure { state with tx := tx }
    | none =>
        if isSettlementRowType rowType then
          let settlement ← stepSettlementParser state.settlement item
          pure {
            state with
            settlementStarted := true
            settlement := settlement
          }
        else
          let tx ← stepTxParser state.tx item
          pure { state with tx := tx }

private def parseSettlementRows
    (allowCommitmentRevisions : Bool)
    (allowExtinguishments : Bool)
    (rows : List (Nat × String)) :
    Except NormalizedActualParseError (List ParsedTx × SettlementEvidence) := do
  let finalState ← rows.foldlM
    (stepSettlementDocumentParser allowCommitmentRevisions allowExtinguishments) {}
  match finalState.tx.current with
  | some draft =>
      throw { line := draft.lastLine, reason := .missingEndTx draft.event draft.txLine }
  | none =>
      pure (
        finalState.tx.completed.reverse,
        {
          commitments := finalState.settlement.commitments.reverse
          commitmentRevisions := finalState.settlement.commitmentRevisions.reverse
          extinguishments := finalState.settlement.extinguishments.reverse
          extinguishmentRevisions := finalState.settlement.extinguishmentRevisions.reverse
          correspondences := finalState.settlement.correspondences.reverse
          correspondenceRevisions := finalState.settlement.correspondenceRevisions.reverse
          nettingContexts := finalState.settlement.nettingContexts.reverse
          nettingMembers := finalState.settlement.nettingMembers.reverse
          nettingMemberRevisions := finalState.settlement.nettingMemberRevisions.reverse
        }
      )

private def parseV2Rows
    (rows : List (Nat × String)) :
    Except NormalizedActualParseError (List ParsedTx × SettlementEvidence) :=
  parseSettlementRows false false rows

private def parseV3Rows
    (rows : List (Nat × String)) :
    Except NormalizedActualParseError (List ParsedTx × SettlementEvidence) :=
  parseSettlementRows true false rows

private def parseV4Rows
    (rows : List (Nat × String)) :
    Except NormalizedActualParseError (List ParsedTx × SettlementEvidence) :=
  parseSettlementRows true true rows

/--
Detailed decoding of a normalized Actual wire representation into an admitted image with structured diagnostics.
Returns machine-readable and human-formattable error on syntax, construction, or semantic failure.
-/
def decodeNormalizedActualImageDetailed (input : String) : Except NormalizedActualDecodeError AdmittedActualImage := do
  if input.isEmpty then
    throw (NormalizedActualDecodeError.parse { line := 1, reason := .emptyDocument })
  if !input.endsWith "\n" then
    let lineCount := (input.splitOn "\n").length
    throw (NormalizedActualDecodeError.parse { line := lineCount, reason := .missingFinalNewline })
  let lines := (input.dropEnd 1).toString.splitOn "\n"
  match lines with
  | [] =>
      throw (NormalizedActualDecodeError.parse { line := 1, reason := .emptyDocument })
  | header :: rowLines =>
      let version ← match normalizedActualWireVersion? header with
        | some version => pure version
        | none =>
            throw (NormalizedActualDecodeError.parse { line := 1, reason := .invalidHeader header })
      let indexedRows : List (Nat × String) :=
        rowLines.mapIdx fun idx row => (idx + 2, row)
      let (txs, settlements) ← match version with
        | .v1 =>
            let txs ← match parseTxs indexedRows with
              | .ok txs => pure txs
              | .error parseErr => throw (NormalizedActualDecodeError.parse parseErr)
            pure (txs, SettlementEvidence.empty)
        | .v2 =>
            match parseV2Rows indexedRows with
            | .ok parsed => pure parsed
            | .error parseErr => throw (NormalizedActualDecodeError.parse parseErr)
        | .v3 =>
            match parseV3Rows indexedRows with
            | .ok parsed => pure parsed
            | .error parseErr => throw (NormalizedActualDecodeError.parse parseErr)
        | .v4 =>
            match parseV4Rows indexedRows with
            | .ok parsed => pure parsed
            | .error parseErr => throw (NormalizedActualDecodeError.parse parseErr)

      -- Construct Core Event instances
      let mut events : List Event := []
      let mut facts : List (ActualValidityFact String) := []
      let mut valCorrections : List ActualValidityCorrection := []
      let mut descriptions : List EventDescription := []
      let mut merchants : List EventMerchantEvidence := []
      let mut exchanges : List ExchangeEvidence := []
      let mut originalAmounts : List OriginalAmountEvidence := []
      let mut movementOperations : List MovementOperationEvidence := []
      let mut corrections : List EventCorrection := []
      let mut reversals : List ActualReversal := []
      let mut relations : List RelationUnit := []
      let mut discharges : List RelationDischarge := []

      -- Accumulate in reverse so decoding remains linear in retained row count.
      -- The final reversals below restore the canonical persistence representation order.
      for tx in txs do
        let event ← match Event.ofEffects? tx.event tx.effects with
          | some ev => pure ev
          | none => throw (NormalizedActualDecodeError.construction (.eventEffects tx.event))
        events := event :: events
        facts := .base tx.event tx.baseValidOn :: facts

        if let some descText := tx.description then
          descriptions := { event := tx.event, text := descText } :: descriptions

        if let some disposition := tx.merchant then
          merchants := { event := tx.event, disposition := disposition } :: merchants

        if let some exchange := tx.exchange then
          exchanges := exchange :: exchanges

        if let some originalAmount := tx.originalAmount then
          originalAmounts := originalAmount :: originalAmounts

        if let some operation := tx.movementOperation then
          movementOperations :=
            { operation := operation, event := tx.event } :: movementOperations

        if let some target := tx.replaces then
          corrections := { target := target, replacement := tx.event } :: corrections

        if let some target := tx.reversalOf then
          reversals := { target := target, reversal := tx.event } :: reversals

        for (revId, date, targetRef) in tx.dateRevisions do
          facts := .revision revId tx.event date :: facts
          valCorrections := { target := targetRef, replacement := revId } :: valCorrections

        relations := tx.relations.foldl (fun acc relation => relation :: acc) relations
        discharges := tx.discharges.foldl (fun acc discharge => discharge :: acc) discharges

      let orderedEvents := events.reverse
      let orderedFacts := facts.reverse
      let orderedValCorrections := valCorrections.reverse
      let orderedDescriptions := descriptions.reverse
      let orderedMerchants := merchants.reverse
      let orderedExchanges := exchanges.reverse
      let orderedOriginalAmounts := originalAmounts.reverse
      let orderedMovementOperations := movementOperations.reverse
      let orderedCorrections := corrections.reverse
      let orderedReversals := reversals.reverse
      let orderedRelations := relations.reverse
      let orderedDischarges := discharges.reverse

      let eventMemory ← match EventMemory.ofEvents? orderedEvents with
        | some m => pure m
        | none => throw (NormalizedActualDecodeError.construction .eventMemory)
      let validityHistory ← match ActualValidityHistory.ofParts? orderedFacts orderedValCorrections with
        | some v => pure v
        | none => throw (NormalizedActualDecodeError.construction .validityHistory)
      let descMemory ← match EventDescriptionMemory.ofEntries? orderedDescriptions with
        | some d => pure d
        | none => throw (NormalizedActualDecodeError.construction .descriptionMemory)
      let merchantMemory ← match EventMerchantEvidenceMemory.ofEntries? orderedMerchants with
        | some m => pure m
        | none => throw (NormalizedActualDecodeError.construction .merchantMemory)
      let exchangeMemory ← match ExchangeEvidenceMemory.ofEntries? orderedExchanges with
        | some m => pure m
        | none => throw (NormalizedActualDecodeError.construction .exchangeMemory)
      let originalAmountMemory ← match OriginalAmountEvidenceMemory.ofEntries? orderedOriginalAmounts with
        | some m => pure m
        | none => throw (NormalizedActualDecodeError.construction .originalAmountMemory)
      let movementOperationMemory ←
        match MovementOperationEvidenceMemory.ofEntries? orderedMovementOperations with
        | some m => pure m
        | none => throw (NormalizedActualDecodeError.construction .movementOperationMemory)
      let corrMemory ← match EventCorrectionMemory.ofCorrections? orderedCorrections with
        | some c => pure c
        | none => throw (NormalizedActualDecodeError.construction .correctionMemory)
      let revMemory ← match ActualReversalMemory.ofReversals? orderedReversals with
        | some r => pure r
        | none => throw (NormalizedActualDecodeError.construction .reversalMemory)

      let rawEvidence : ActualEvidence := {
        events := eventMemory
        validity := validityHistory
        descriptions := descMemory
        merchants := merchantMemory
        exchanges := exchangeMemory
        originalAmounts := originalAmountMemory
        movementOperations := movementOperationMemory
        corrections := corrMemory
        reversals := revMemory
        relations := orderedRelations
        discharges := orderedDischarges
        settlements := settlements
      }

      match admitActualImage? rawEvidence with
      | some image => pure image
      | none => throw NormalizedActualDecodeError.admission

/--
Decode a complete normalized Actual document into an admitted image.
Compatibility wrapper delegating to detailed decoding.
-/
def decodeNormalizedActualImage? (input : String) : Option AdmittedActualImage :=
  match decodeNormalizedActualImageDetailed input with
  | .ok image => some image
  | .error _ => none

/--
Detailed decoding of normalized Actual wire representation into retained ActualEvidence.
-/
def decodeNormalizedActualDetailed
    (input : String) :
    Except NormalizedActualDecodeError ActualEvidence := do
  let image ← decodeNormalizedActualImageDetailed input
  pure image.evidence

/--
Decode only the retained ActualEvidence compatibility view.
Read-side authority consumers should prefer the richer admitted image.
-/
def decodeNormalizedActual? (input : String) : Option ActualEvidence :=
  match decodeNormalizedActualDetailed input with
  | .ok evidence => some evidence
  | .error _ => none

private def settlementEvidenceIsEmpty (settlement : SettlementEvidence) : Bool :=
  settlement.commitments.isEmpty &&
  settlement.commitmentRevisions.isEmpty &&
  settlement.extinguishments.isEmpty &&
  settlement.extinguishmentRevisions.isEmpty &&
  settlement.correspondences.isEmpty &&
  settlement.correspondenceRevisions.isEmpty &&
  settlement.nettingContexts.isEmpty &&
  settlement.nettingMembers.isEmpty &&
  settlement.nettingMemberRevisions.isEmpty

private def endpointTokenAdmissible : RelationEndpoint → Bool
  | .household => true
  | .external id => validToken id.token

/--
Encode persistence-neutral ActualEvidence into normalized Actual wire representation.
Version 1 is preserved while settlement evidence is empty.
Version 2 retains the original settlement row family when no commitment revisions exist.
Version 3 is selected when append-only commitment revision evidence is present.
Version 4 is selected when non-settlement extinguishment evidence is present.
Fails closed (`none`) on invalid wire tokens or inadmissible semantic evidence.
-/
def encodeNormalizedActual? (evidence : ActualEvidence) : Option String := do
  let _ ← admitActualEvidence? evidence
  let settlementEmpty := settlementEvidenceIsEmpty evidence.settlements
  let hasCommitmentRevisions := !evidence.settlements.commitmentRevisions.isEmpty
  let hasExtinguishments :=
    !evidence.settlements.extinguishments.isEmpty ||
      !evidence.settlements.extinguishmentRevisions.isEmpty
  let header :=
    if settlementEmpty then
      normalizedActualHeaderV1
    else if hasExtinguishments then
      normalizedActualHeaderV4
    else if hasCommitmentRevisions then
      normalizedActualHeaderV3
    else
      normalizedActualHeaderV2
  let mut rows : List String := [header]

  for event in evidence.events.events do
    -- Find base occurrence date for this event
    let baseFact ← evidence.validity.facts.find? fun f =>
      match f with
      | .base ev _ => decide (ev = event.id)
      | _ => false
    let baseDate := baseFact.validOn

    match evidence.descriptions.findText? event.id with
    | none =>
        rows := rows ++ [s!"TX\t{event.id.token}\t{baseDate}\tNODESC"]
    | some text =>
        if text.isEmpty || text.contains '\n' || text.contains '\r' then none
        rows := rows ++ [s!"TX\t{event.id.token}\t{baseDate}\tDESC\t{text}"]

    match evidence.merchants.findDisposition? event.id with
    | none => pure ()
    | some .nonmerchant =>
        rows := rows ++ ["NONMERCHANT"]
    | some (.merchant party) =>
        if !validToken party.token then none
        rows := rows ++ [s!"MERCHANT\t{party.token}"]

    match evidence.exchanges.findByEvent? event.id with
    | none => pure ()
    | some exchange =>
        if !validToken exchange.source.token || !validToken exchange.destination.token then none
        rows := rows ++ [
          s!"EXCHANGE\t{exchange.source.token}\t{exchange.destination.token}"
        ]

    match evidence.originalAmounts.findByEvent? event.id with
    | none => pure ()
    | some original =>
        if !validToken original.measure.token then none
        rows := rows ++ [
          s!"ORIGINAL-AMOUNT\t{original.measure.token}\t{original.quantity.quanta}"
        ]

    match evidence.movementOperations.findOperation? event.id with
    | none => pure ()
    | some operation =>
        if !validToken operation.token then none
        rows := rows ++ [s!"OPERATION\t{operation.token}"]

    if let some corr := evidence.corrections.corrections.find? fun c => decide (c.replacement = event.id) then
      rows := rows ++ [s!"REPLACES\t{corr.target.token}"]

    if let some rev := evidence.reversals.reversals.find? fun r => decide (r.reversal = event.id) then
      rows := rows ++ [s!"REVERSAL-OF\t{rev.target.token}"]

    for effect in event.effects do
      match effect.key with
      | none =>
          rows := rows ++ [s!"EFFECT\t{effect.locus.token}\t{effect.measure.token}\t{effect.quantity.quanta}"]
      | some key =>
          rows := rows ++ [s!"KEYED-EFFECT\t{key.token}\t{effect.locus.token}\t{effect.measure.token}\t{effect.quantity.quanta}"]

    -- Date revisions for this event
    for fact in evidence.validity.facts do
      match fact with
      | .revision revId ev date =>
          if ev = event.id then
            let corr ← evidence.validity.corrections.find? fun c => decide (c.replacement = revId)
            match corr.target with
            | .root _ =>
                rows := rows ++ [s!"DATE-REV\t{revId.token}\t{date}\tREPLACES\tROOT"]
            | .revision prior =>
                rows := rows ++ [s!"DATE-REV\t{revId.token}\t{date}\tREPLACES\tREV\t{prior.token}"]
      | .base _ _ => pure ()

    for rel in evidence.relations do
      if rel.sourceEvent = event.id then
        rows := rows ++ [
          s!"RELATION\t{rel.id.token}\tSOURCE\t{rel.sourceEffect.token}\t" ++
          s!"{formatEndpoint rel.debtor}\t{formatEndpoint rel.creditor}\t{rel.quantity.quanta}"
        ]

    for discharge in evidence.discharges do
      if discharge.event = event.id then
        rows := rows ++ [s!"DISCHARGE\t{discharge.target.token}\t{discharge.quantity.quanta}"]

    rows := rows ++ ["ENDTX"]

  if !settlementEmpty then
    for commitment in evidence.settlements.commitments do
      if !validToken commitment.id.token ||
          !validToken commitment.sourceEvent.token ||
          !validToken commitment.sourceEffect.token ||
          !endpointTokenAdmissible commitment.debtor ||
          !endpointTokenAdmissible commitment.creditor ||
          !validToken commitment.measure.token then
        none
      rows := rows ++ [
        s!"SETTLEMENT-COMMITMENT\t{commitment.id.token}\tSOURCE\t" ++
        s!"{commitment.sourceEvent.token}\t{commitment.sourceEffect.token}\t" ++
        s!"{formatEndpoint commitment.debtor}\t{formatEndpoint commitment.creditor}\t" ++
        s!"{commitment.measure.token}\t{commitment.quantity.quanta}"
      ]

    for revision in evidence.settlements.commitmentRevisions do
      if !validToken revision.target.token then
        none
      match revision.replacement with
      | none =>
          rows := rows ++ [
            s!"SETTLEMENT-COMMITMENT-REVISION\t{revision.target.token}\tRETRACT"
          ]
      | some replacement =>
          if !validToken replacement.token then
            none
          rows := rows ++ [
            s!"SETTLEMENT-COMMITMENT-REVISION\t{revision.target.token}\t" ++
            s!"REPLACEMENT\t{replacement.token}"
          ]

    for extinguishment in evidence.settlements.extinguishments do
      if !validToken extinguishment.id.token ||
          !validToken extinguishment.target.token then
        none
      match extinguishment.effectiveOn with
      | none =>
          rows := rows ++ [
            s!"SETTLEMENT-EXTINGUISHMENT\t{extinguishment.id.token}\tTARGET\t" ++
            s!"{extinguishment.target.token}\t{extinguishment.quantity.quanta}\tUNKNOWN"
          ]
      | some effectiveOn =>
          if !validToken effectiveOn then
            none
          rows := rows ++ [
            s!"SETTLEMENT-EXTINGUISHMENT\t{extinguishment.id.token}\tTARGET\t" ++
            s!"{extinguishment.target.token}\t{extinguishment.quantity.quanta}\t" ++
            s!"EFFECTIVE\t{effectiveOn}"
          ]

    for revision in evidence.settlements.extinguishmentRevisions do
      if !validToken revision.target.token then
        none
      match revision.replacement with
      | none =>
          rows := rows ++ [
            s!"SETTLEMENT-EXTINGUISHMENT-REVISION\t{revision.target.token}\tRETRACT"
          ]
      | some replacement =>
          if !validToken replacement.token then
            none
          rows := rows ++ [
            s!"SETTLEMENT-EXTINGUISHMENT-REVISION\t{revision.target.token}\t" ++
            s!"REPLACEMENT\t{replacement.token}"
          ]

    for correspondence in evidence.settlements.correspondences do
      if !validToken correspondence.id.token ||
          !validToken correspondence.target.token ||
          !validToken correspondence.event.token ||
          !validToken correspondence.effect.token then
        none
      rows := rows ++ [
        s!"SETTLEMENT-CORRESPONDENCE\t{correspondence.id.token}\tTARGET\t" ++
        s!"{correspondence.target.token}\tPHYSICAL\t{correspondence.event.token}\t" ++
        s!"{correspondence.effect.token}\t{correspondence.quantity.quanta}"
      ]

    for revision in evidence.settlements.correspondenceRevisions do
      if !validToken revision.target.token || !validToken revision.replacement.token then
        none
      rows := rows ++ [
        s!"SETTLEMENT-CORRESPONDENCE-REVISION\t{revision.target.token}\t" ++
        s!"REPLACEMENT\t{revision.replacement.token}"
      ]

    for context in evidence.settlements.nettingContexts do
      if !validToken context.id.token || !validToken context.measure.token then
        none
      match context.outcome with
      | .zero =>
          rows := rows ++ [
            s!"SETTLEMENT-NETTING\t{context.id.token}\t{context.measure.token}\tZERO"
          ]
      | .physical event effect =>
          if !validToken event.token || !validToken effect.token then
            none
          rows := rows ++ [
            s!"SETTLEMENT-NETTING\t{context.id.token}\t{context.measure.token}\t" ++
            s!"PHYSICAL\t{event.token}\t{effect.token}"
          ]

    for member in evidence.settlements.nettingMembers do
      if !validToken member.id.token ||
          !validToken member.context.token ||
          !validToken member.target.token then
        none
      rows := rows ++ [
        s!"SETTLEMENT-MEMBER\t{member.id.token}\tCONTEXT\t{member.context.token}\t" ++
        s!"TARGET\t{member.target.token}\t{member.quantity.quanta}"
      ]

    for revision in evidence.settlements.nettingMemberRevisions do
      if !validToken revision.target.token || !validToken revision.replacement.token then
        none
      rows := rows ++ [
        s!"SETTLEMENT-MEMBER-REVISION\t{revision.target.token}\t" ++
        s!"REPLACEMENT\t{revision.replacement.token}"
      ]

  some (String.intercalate "\n" rows ++ "\n")

end Loam.Persistence
