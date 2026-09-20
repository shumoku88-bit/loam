import Loam.ActualEvidence
import Loam.ActualDate
import Loam.Core.Event
import Loam.Core.BalancedMovement
import Loam.Core.EventMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.EventMerchantEvidence
import Loam.Core.MovementOperationEvidence
import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualReversal
import Loam.Core.ActualReversalBalance
import Loam.Core.OpenRelation
import Loam.Application.CorrectionFrontier
import Loam.Application.ActualValidityFrontier
import Loam.Application.OpenRelationFrontier
import Loam.Application.RelationDischargeFrontier
import Loam.Persistence.TokenSyntax
import Std.Data.HashMap

namespace Loam.Persistence

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-- Header marker for the single-generation normalized Actual wire representation. -/
def normalizedActualHeader : String := "LOAM-NORMALIZED-ACTUAL\t1"

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

/--
One fully admitted normalized Actual image plus the two read-side projections
that production repeatedly reconstructs.

The raw retained evidence remains available for writer candidate construction.
`currentEvents` and `currentValidities` are derived views, not new authorities.
Their proof fields prevent those views from drifting from the retained evidence.
-/
structure AdmittedActualImage where
  evidence : ActualEvidence
  currentEvents : EventMemory
  currentValidities : ActualValidityMemory String
  currentEvents_admitted :
    correctionFrontierMemory? evidence.events evidence.corrections = some currentEvents
  currentValidities_admitted :
    admittedActualValidityMemory? evidence.validity = some currentValidities

private def retainedEventIndex
    (events : EventMemory) : Std.HashMap String Event :=
  events.events.foldl
    (fun index event => index.insert event.id.token event)
    {}

private def currentValidityIndex
    (validities : ActualValidityMemory String) : Std.HashMap String String :=
  validities.entries.foldl
    (fun index entry => index.insert entry.event.token entry.validOn)
    {}

/--
Construct the proof-carrying movement projection for one represented Measure.
-/
private def normalizedMovementForMeasure?
    (effects : List Effect) (measure : MeasureId) :
    Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? measure <|
    ActualReversalBalance.movementChangesForMeasure measure effects

/-- Check the exact signed total for one Measure without mixing dimensional units. -/
private def normalizedMeasureBalanced
    (effects : List Effect) (measure : MeasureId) : Bool :=
  (normalizedMovementForMeasure? effects measure).isSome

/-- Every retained quantity-bearing Effect must remain nonzero. -/
private def normalizedEventEffectsNonzero (event : Event) : Bool :=
  event.effects.all fun effect =>
    effect.quantity.quanta != 0

/--
Check that every represented Measure closes independently for one Event.

Reversal endpoints may defer this check to exact-reversal admission: the target
is admitted once there and the reversal side is then derived from the exact
inverse proof rather than admitted a second time.
-/
private def normalizedEventEffectsBalanced (event : Event) : Bool :=
  event.effects.all fun effect =>
    normalizedMeasureBalanced event.effects effect.measure

/--
Occurrence-date strings become production calendar evidence at this boundary,
so every retained base date and revision date must denote a real ISO calendar
date rather than merely fit in one text token.
-/
private def normalizedValidityDatesAdmissible
    (history : ActualValidityHistory String) : Bool :=
  history.facts.all fun fact =>
    Loam.ActualDate.validIsoDate fact.validOn

/--
Validate that an ActualEvidence aggregate satisfies referential closure and
semantic admission using existing Core and Application boundaries, while
retaining the two derived read views that are otherwise recomputed downstream.

This remains a re-admission boundary rather than a second semantic engine:
it reuses the existing balanced-movement algebra and calendar-date admission,
then calls the existing frontiers and checks that references among the
co-published fact families resolve within the generation.
-/
def admitActualImage? (evidence : ActualEvidence) : Option AdmittedActualImage := do
  -- Nonzero physical evidence remains a direct persistence obligation for every Event.
  if !evidence.events.events.all normalizedEventEffectsNonzero then
    none
  -- Ordinary Events retain direct per-Measure balance admission. Reversal endpoints
  -- are deferred to the relation loop below so one target admission can prove both sides.
  if !evidence.events.events.all (fun event =>
      if evidence.reversals.mentionsEvent event.id then
        true
      else
        normalizedEventEffectsBalanced event) then
    none
  if !normalizedValidityDatesAdmissible evidence.validity then
    none
  match hFrontier : correctionFrontierMemory? evidence.events evidence.corrections with
  | none => none
  | some currentEvents =>
      match hValidity : admittedActualValidityMemory? evidence.validity with
      | none => none
      | some admittedDates => do
          -- Derived acceleration indexes only. Core memories remain the proof-carrying authority.
          let retainedEvents := retainedEventIndex evidence.events
          let currentValidities := currentValidityIndex admittedDates

          -- Every retained validity fact must belong to a retained Event.
          for fact in evidence.validity.facts do
            if !retainedEvents.contains fact.event.token then
              none
          -- Every remembered Event must have a valid current occurrence date.
          for event in evidence.events.events do
            if !currentValidities.contains event.id.token then
              none

          -- Event descriptions: every described Event must exist.
          for entry in evidence.descriptions.entries do
            if !retainedEvents.contains entry.event.token then
              none

          -- Merchant dispositions: every classified Event must exist.
          if !EventMerchantEvidenceMemory.referencesOnlyKnownEvents
              evidence.events evidence.merchants then
            none

          -- Movement operation evidence: every mapped Event must exist.
          if !MovementOperationEvidenceMemory.referencesOnlyKnownEvents
              evidence.events evidence.movementOperations then
            none

          -- Reversals: Core memory already proves global endpoint uniqueness.
          -- Persistence admits target balance once, proves exact physical inversion,
          -- and derives reversal balance from those proofs without a second runtime check.
          for reversal in evidence.reversals.reversals do
            let targetEvent ← retainedEvents[reversal.target.token]?
            let reversalEvent ← retainedEvents[reversal.reversal.token]?
            if hExact :
                ActualReversal.exactPhysicalInverse?
                    targetEvent.effects reversalEvent.effects = true then
              for effect in targetEvent.effects do
                let some targetMovement :=
                    normalizedMovementForMeasure? targetEvent.effects effect.measure
                  | none => none
                let _derivedReversal : BalancedMovement LocusId := {
                  measure := effect.measure
                  changes :=
                    ActualReversalBalance.movementChangesForMeasure
                      effect.measure reversalEvent.effects
                  balanced :=
                    ActualReversalBalance.reversalMeasureZero_of_targetMeasureZero_exactPhysicalInverse
                      targetEvent.effects
                      reversalEvent.effects
                      effect.measure
                      targetMovement.balanced
                      hExact
                }
                pure ()
            else
              none

          -- Relations: whole-family frontier owns source resolution, shape,
          -- quantity bounds, aggregate coverage, and stable identity uniqueness.
          let _ ← admittedRelationFrontier? evidence.events evidence.relations

          -- Discharges: persistence owns same-generation reference closure.
          for discharge in evidence.discharges do
            let _ ← retainedEvents[discharge.event.token]?
            let _ ← evidence.relations.find? fun r => r.id = discharge.target

          for relation in evidence.relations do
            let _ ← admittedRelationDischargesFor?
              evidence.events evidence.relations evidence.discharges relation.id

          some {
            evidence := evidence
            currentEvents := currentEvents
            currentValidities := admittedDates
            currentEvents_admitted := hFrontier
            currentValidities_admitted := hValidity
          }

/--
Compatibility entrance returning only retained ActualEvidence.
Writers that mutate a candidate continue to use this raw aggregate and therefore
must requalify the changed candidate before publication.
-/
def admitActualEvidence? (evidence : ActualEvidence) : Option ActualEvidence := do
  let image ← admitActualImage? evidence
  some image.evidence

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
    | .invalidHeader found => s!"invalid header: '{found}', expected '{normalizedActualHeader}'"
    | .malformedTxRow detail => s!"malformed TX row: {detail}"
    | .malformedRow rowType detail => s!"malformed {rowType} row: {detail}"
    | .unknownRowType rowType => s!"unknown row type: '{rowType}'"
    | .missingEndTx event txLine => s!"missing ENDTX for transaction '{event.token}' (opened at line {txLine})"
    | .invalidToken token => s!"invalid token: '{token}'"
    | .invalidInteger value => s!"invalid integer quantity: '{value}'"
    | .duplicateMerchant => "duplicate MERCHANT or NONMERCHANT row in transaction"
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
  movementOperation : Option MovementOperationId
  replaces : Option EventId
  reversalOf : Option EventId
  effects : List Effect
  dateRevisions : List (ActualValidityRevisionId × String × ActualValidityRef)
  relations : List RelationUnit
  discharges : List RelationDischarge

private def parseTxRows
    (txLine : Nat)
    (lastLine : Nat)
    (event : EventId)
    (baseValidOn : String)
    (description : Option String)
    (merchant : Option MerchantDisposition)
    (movementOperation : Option MovementOperationId)
    (replaces : Option EventId)
    (reversalOf : Option EventId)
    (effects : List Effect)
    (dateRevisions : List (ActualValidityRevisionId × String × ActualValidityRef))
    (relations : List RelationUnit)
    (discharges : List RelationDischarge) :
    List (Nat × String) → Except NormalizedActualParseError (ParsedTx × List (Nat × String))
  | [] =>
      Except.error { line := lastLine, reason := .missingEndTx event txLine }
  | (lineNo, row) :: rest => do
      if row == "ENDTX" then
        Except.ok ({
          event := event
          baseValidOn := baseValidOn
          description := description
          merchant := merchant
          movementOperation := movementOperation
          replaces := replaces
          reversalOf := reversalOf
          effects := effects
          dateRevisions := dateRevisions
          relations := relations
          discharges := discharges
        }, rest)
      else if row.startsWith "TX\t" || row == "TX" then
        Except.error { line := lineNo, reason := .missingEndTx event txLine }
      else
        let fields := row.splitOn "\t"
        match fields with
        | ["MERCHANT", partyToken] =>
            if merchant.isSome then
              Except.error { line := lineNo, reason := .duplicateMerchant }
            else if !validToken partyToken then
              Except.error { line := lineNo, reason := .invalidToken partyToken }
            else
              parseTxRows txLine lineNo event baseValidOn description (some (.merchant ⟨partyToken⟩))
                movementOperation replaces reversalOf effects dateRevisions relations discharges rest
        | ["NONMERCHANT"] =>
            if merchant.isSome then
              Except.error { line := lineNo, reason := .duplicateMerchant }
            else
              parseTxRows txLine lineNo event baseValidOn description (some .nonmerchant)
                movementOperation replaces reversalOf effects dateRevisions relations discharges rest
        | ["OPERATION", operationToken] =>
            if movementOperation.isSome then
              Except.error { line := lineNo, reason := .duplicateOperation }
            else if !validToken operationToken then
              Except.error { line := lineNo, reason := .invalidToken operationToken }
            else
              parseTxRows txLine lineNo event baseValidOn description merchant
                (some ⟨operationToken⟩) replaces reversalOf
                effects dateRevisions relations discharges rest
        | ["REPLACES", target] =>
            if replaces.isSome then
              Except.error { line := lineNo, reason := .duplicateReplaces }
            else if !validToken target then
              Except.error { line := lineNo, reason := .invalidToken target }
            else
              parseTxRows txLine lineNo event baseValidOn description merchant movementOperation (some ⟨target⟩) reversalOf
                effects dateRevisions relations discharges rest
        | ["REVERSAL-OF", target] =>
            if reversalOf.isSome then
              Except.error { line := lineNo, reason := .duplicateReversalOf }
            else if !validToken target then
              Except.error { line := lineNo, reason := .invalidToken target }
            else
              parseTxRows txLine lineNo event baseValidOn description merchant movementOperation replaces (some ⟨target⟩)
                effects dateRevisions relations discharges rest
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
                  parseTxRows txLine lineNo event baseValidOn description merchant movementOperation replaces reversalOf
                    (effects ++ [effect]) dateRevisions relations discharges rest
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
                  parseTxRows txLine lineNo event baseValidOn description merchant movementOperation replaces reversalOf
                    (effects ++ [effect]) dateRevisions relations discharges rest
        | ["DATE-REV", revId, date, "REPLACES", "ROOT"] =>
            if !validToken revId then
              Except.error { line := lineNo, reason := .invalidToken revId }
            else if !validToken date then
              Except.error { line := lineNo, reason := .invalidToken date }
            else
              let item := (⟨revId⟩, date, ActualValidityRef.root event)
              parseTxRows txLine lineNo event baseValidOn description merchant movementOperation replaces reversalOf
                effects (dateRevisions ++ [item]) relations discharges rest
        | ["DATE-REV", revId, date, "REPLACES", "REV", prior] =>
            if !validToken revId then
              Except.error { line := lineNo, reason := .invalidToken revId }
            else if !validToken date then
              Except.error { line := lineNo, reason := .invalidToken date }
            else if !validToken prior then
              Except.error { line := lineNo, reason := .invalidToken prior }
            else
              let item := (⟨revId⟩, date, ActualValidityRef.revision ⟨prior⟩)
              parseTxRows txLine lineNo event baseValidOn description merchant movementOperation replaces reversalOf
                effects (dateRevisions ++ [item]) relations discharges rest
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
                    sourceEvent := event
                    sourceEffect := ⟨key⟩
                    debtor := debtor
                    creditor := creditor
                    quantity := Quantity.ofQuanta quanta
                  }
                  parseTxRows txLine lineNo event baseValidOn description merchant movementOperation replaces reversalOf
                    effects dateRevisions (relations ++ [rel]) discharges rest
        | ["DISCHARGE", relId, quantityStr] => do
            match quantityStr.toInt? with
            | none => Except.error { line := lineNo, reason := .invalidInteger quantityStr }
            | some quanta =>
                if !validToken relId then
                  Except.error { line := lineNo, reason := .invalidToken relId }
                else
                  let discharge : RelationDischarge := {
                    event := event
                    target := ⟨relId⟩
                    quantity := Quantity.ofQuanta quanta
                  }
                  parseTxRows txLine lineNo event baseValidOn description merchant movementOperation replaces reversalOf
                    effects dateRevisions relations (discharges ++ [discharge]) rest
        | _ =>
            let head := fields.head?
            if head == some "MERCHANT" then
              Except.error { line := lineNo, reason := .malformedRow "MERCHANT" s!"expected 2 fields, got {fields.length}" }
            else if head == some "NONMERCHANT" then
              Except.error { line := lineNo, reason := .malformedRow "NONMERCHANT" s!"expected 1 field, got {fields.length}" }
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

private partial def parseTxs :
    List (Nat × String) → Except NormalizedActualParseError (List ParsedTx)
  | [] => Except.ok []
  | (lineNo, line) :: rest =>
      let fields := line.splitOn "\t"
      match fields with
      | ["TX", eventToken, baseDate, "NODESC"] => do
          if !validToken eventToken then
            Except.error { line := lineNo, reason := .invalidToken eventToken }
          else if !validToken baseDate then
            Except.error { line := lineNo, reason := .invalidToken baseDate }
          else
            let (tx, remaining) ← parseTxRows lineNo lineNo ⟨eventToken⟩ baseDate none none none none none [] [] [] [] rest
            let tail ← parseTxs remaining
            Except.ok (tx :: tail)
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
              let (tx, remaining) ← parseTxRows lineNo lineNo ⟨eventToken⟩ baseDate (some descText) none none none none [] [] [] [] rest
              let tail ← parseTxs remaining
              Except.ok (tx :: tail)
      | _ =>
          if fields.head? == some "TX" then
            Except.error { line := lineNo, reason := .malformedTxRow "expected TX <event> <date> [NODESC|DESC <text>]" }
          else
            Except.error { line := lineNo, reason := .unknownRowType (fields.head?.getD "") }

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
      if header != normalizedActualHeader then
        throw (NormalizedActualDecodeError.parse { line := 1, reason := .invalidHeader header })
      else
        let indexedRows : List (Nat × String) :=
          rowLines.mapIdx fun idx row => (idx + 2, row)
        let txs ← match parseTxs indexedRows with
          | .ok txs => pure txs
          | .error parseErr => throw (NormalizedActualDecodeError.parse parseErr)

        -- Construct Core Event instances
        let mut events : List Event := []
        let mut facts : List (ActualValidityFact String) := []
        let mut valCorrections : List ActualValidityCorrection := []
        let mut descriptions : List EventDescription := []
        let mut merchants : List EventMerchantEvidence := []
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
          movementOperations := movementOperationMemory
          corrections := corrMemory
          reversals := revMemory
          relations := orderedRelations
          discharges := orderedDischarges
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

/--
Encode persistence-neutral ActualEvidence into normalized Actual wire representation.
Fails closed (`none`) if any Event lacks an occurrence date or contains invalid characters.
-/
def encodeNormalizedActual? (evidence : ActualEvidence) : Option String := do
  let _ ← admitActualEvidence? evidence
  let mut rows : List String := [normalizedActualHeader]

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

  some (String.intercalate "\n" rows ++ "\n")

end Loam.Persistence
