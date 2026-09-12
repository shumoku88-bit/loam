import Loam.ActualEvidence
import Loam.Core.Event
import Loam.Core.EventMemory
import Loam.Core.ActualValidityHistory
import Loam.Core.EventDescription
import Loam.Core.EventCorrectionMemory
import Loam.Core.ActualReversal
import Loam.Core.OpenRelation
import Loam.Application.CorrectionFrontier
import Loam.Application.ActualValidityFrontier
import Loam.Application.OpenRelationFrontier
import Loam.Application.RelationDischargeFrontier
import Loam.Persistence.TokenSyntax

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

private def uncoveredSource (_ : EventId) (_ : EffectKey) : Bool := false

/--
Validate that an ActualEvidence aggregate satisfies referential closure and
semantic admission using existing Core and Application boundaries.

This performs no second engine semantics: it calls existing frontiers and checks
that references among the co-published fact families resolve within the generation.
-/
def admitActualEvidence? (evidence : ActualEvidence) : Option ActualEvidence := do
  -- 1. Event correction frontier: requires reference closure, acyclicity, no branching
  let _ ← correctionFrontierMemory? evidence.events evidence.corrections

  -- 2. Validity frontier: requires reference closure, single current date per Event
  let admittedDates ← admittedActualValidityMemory? evidence.validity
  -- Every retained validity fact must belong to a retained Event
  for fact in evidence.validity.facts do
    if (evidence.events.findById? fact.event).isNone then
      none
  -- Every remembered event must have a valid current occurrence date
  for event in evidence.events.events do
    if (admittedDates.findByEventId? event.id).isNone then
      none

  -- 3. Event descriptions: every described event must exist
  for entry in evidence.descriptions.entries do
    if (evidence.events.findById? entry.event).isNone then
      none

  -- 4. Reversals: target and reversal must exist, exact physical inverse, no reversal-of-reversal
  for reversal in evidence.reversals.reversals do
    let targetEvent ← evidence.events.findById? reversal.target
    let reversalEvent ← evidence.events.findById? reversal.reversal
    if reversal.target = reversal.reversal then
      none
    -- Lean publisher qualification: reversal-of-reversal chains are rejected
    if (evidence.reversals.findByReversal? reversal.target).isSome then
      none
    -- Physical effects must form an exact inverse multiset of (locus, measure, quantity)
    if !ActualReversal.exactPhysicalInverse? targetEvent.effects reversalEvent.effects then
      none

  -- 5. Relations: source Event and keyed Effect must exist, bounds and positive quantity
  for relation in evidence.relations do
    let sourceEvent ← evidence.events.findById? relation.sourceEvent
    let sourceEffect ← sourceEvent.effects.find? fun e => e.key = some relation.sourceEffect
    if relation.debtor = relation.creditor then
      none
    if relation.quantity.quanta <= 0 then
      none
    if relation.quantity.quanta > sourceEffect.quantity.quanta.natAbs then
      none
    -- Must resolve through existing relation frontier
    let state ← currentRelationState?
      evidence.events evidence.relations uncoveredSource relation.sourceEvent relation.sourceEffect
    match state with
    | .knownPositive current =>
        if !(current.any fun u => u.relation.id = relation.id) then
          none
    | _ => none

  -- Relation unit IDs must be unique
  if !(evidence.relations.map RelationUnit.id).Nodup then
    none

  -- 6. Discharges: target relation must exist, unique (event, target), total discharge <= relation quantity
  let dischargePairs := evidence.discharges.map fun d => (d.event, d.target)
  if !dischargePairs.Nodup then
    none
  for discharge in evidence.discharges do
    let _ ← evidence.events.findById? discharge.event
    if discharge.quantity.quanta <= 0 then
      none
    let rawRel ← evidence.relations.find? fun r => r.id = discharge.target
    if discharge.event = rawRel.sourceEvent then
      none

  for relation in evidence.relations do
    let _ ← admittedRelationDischargesFor?
      evidence.events evidence.relations evidence.discharges relation.id

  some evidence

/--
Intermediate per-transaction parsing state during normalized Actual decoding.
-/
private structure ParsedTx where
  event : EventId
  baseValidOn : String
  description : Option String
  replaces : Option EventId
  reversalOf : Option EventId
  effects : List Effect
  dateRevisions : List (ActualValidityRevisionId × String × ActualValidityRef)
  relations : List RelationUnit
  discharges : List RelationDischarge

private def parseTxRows
    (event : EventId)
    (baseValidOn : String)
    (description : Option String)
    (replaces : Option EventId)
    (reversalOf : Option EventId)
    (effects : List Effect)
    (dateRevisions : List (ActualValidityRevisionId × String × ActualValidityRef))
    (relations : List RelationUnit)
    (discharges : List RelationDischarge) :
    List String → Option (ParsedTx × List String)
  | [] => none
  | row :: rest => do
      if row == "ENDTX" then
        some ({
          event := event
          baseValidOn := baseValidOn
          description := description
          replaces := replaces
          reversalOf := reversalOf
          effects := effects
          dateRevisions := dateRevisions
          relations := relations
          discharges := discharges
        }, rest)
      else
        let fields := row.splitOn "\t"
        match fields with
        | ["REPLACES", target] =>
            if replaces.isSome || !validToken target then none
            else
              parseTxRows event baseValidOn description (some ⟨target⟩) reversalOf
                effects dateRevisions relations discharges rest
        | ["REVERSAL-OF", target] =>
            if reversalOf.isSome || !validToken target then none
            else
              parseTxRows event baseValidOn description replaces (some ⟨target⟩)
                effects dateRevisions relations discharges rest
        | ["EFFECT", locus, measure, quantityStr] => do
            let quanta ← quantityStr.toInt?
            if !validToken locus || !validToken measure then none
            else
              let effect := Effect.ofAnonymousQuantity ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)
              parseTxRows event baseValidOn description replaces reversalOf
                (effects ++ [effect]) dateRevisions relations discharges rest
        | ["KEYED-EFFECT", key, locus, measure, quantityStr] => do
            let quanta ← quantityStr.toInt?
            if !validToken key || !validToken locus || !validToken measure then none
            else
              let effect := Effect.ofQuantity ⟨key⟩ ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)
              parseTxRows event baseValidOn description replaces reversalOf
                (effects ++ [effect]) dateRevisions relations discharges rest
        | ["DATE-REV", revId, date, "REPLACES", "ROOT"] =>
            if !validToken revId || !validToken date then none
            else
              let item := (⟨revId⟩, date, ActualValidityRef.root event)
              parseTxRows event baseValidOn description replaces reversalOf
                effects (dateRevisions ++ [item]) relations discharges rest
        | ["DATE-REV", revId, date, "REPLACES", "REV", prior] =>
            if !validToken revId || !validToken date || !validToken prior then none
            else
              let item := (⟨revId⟩, date, ActualValidityRef.revision ⟨prior⟩)
              parseTxRows event baseValidOn description replaces reversalOf
                effects (dateRevisions ++ [item]) relations discharges rest
        | ["RELATION", relId, "SOURCE", key, debtorStr, creditorStr, quantityStr] => do
            let quanta ← quantityStr.toInt?
            if quanta <= 0 || !validToken relId || !validToken key then none
            else
              let debtor ← parseEndpoint? debtorStr
              let creditor ← parseEndpoint? creditorStr
              if debtor == creditor then none
              else
                let rel : RelationUnit := {
                  id := ⟨relId⟩
                  sourceEvent := event
                  sourceEffect := ⟨key⟩
                  debtor := debtor
                  creditor := creditor
                  quantity := Quantity.ofQuanta quanta
                }
                parseTxRows event baseValidOn description replaces reversalOf
                  effects dateRevisions (relations ++ [rel]) discharges rest
        | ["DISCHARGE", relId, quantityStr] => do
            let quanta ← quantityStr.toInt?
            if quanta <= 0 || !validToken relId then none
            else
              let discharge : RelationDischarge := {
                event := event
                target := ⟨relId⟩
                quantity := Quantity.ofQuanta quanta
              }
              parseTxRows event baseValidOn description replaces reversalOf
                effects dateRevisions relations (discharges ++ [discharge]) rest
        | _ => none

private partial def parseTxs : List String → Option (List ParsedTx)
  | [] => some []
  | line :: rest =>
      let fields := line.splitOn "\t"
      match fields with
      | ["TX", eventToken, baseDate, "NODESC"] => do
          if !validToken eventToken || !validToken baseDate then none
          match parseTxRows ⟨eventToken⟩ baseDate none none none [] [] [] [] rest with
          | some (tx, remaining) =>
              let tail ← parseTxs remaining
              some (tx :: tail)
          | none => none
      | "TX" :: eventToken :: baseDate :: "DESC" :: descFields => do
          if !validToken eventToken || !validToken baseDate then none
          let descText := String.intercalate "\t" descFields
          if descText.isEmpty || descText.contains '\n' || descText.contains '\r' then none
          match parseTxRows ⟨eventToken⟩ baseDate (some descText) none none [] [] [] [] rest with
          | some (tx, remaining) =>
              let tail ← parseTxs remaining
              some (tx :: tail)
          | none => none
      | _ => none

/--
Decode a complete normalized Actual document into persistence-neutral ActualEvidence.
Fails closed (`none`) on any syntax error, unknown row, missing header, or semantic violation.
-/
def decodeNormalizedActual? (input : String) : Option ActualEvidence := do
  if !input.endsWith "\n" then none
  let lines := (input.dropEnd 1).toString.splitOn "\n"
  match lines with
  | [] => none
  | header :: rowLines =>
      if header != normalizedActualHeader then none
      else
        let txs ← parseTxs rowLines
        -- Construct Core Event instances
        let mut events : List Event := []
        let mut facts : List (ActualValidityFact String) := []
        let mut valCorrections : List ActualValidityCorrection := []
        let mut descriptions : List EventDescription := []
        let mut corrections : List EventCorrection := []
        let mut reversals : List ActualReversal := []
        let mut relations : List RelationUnit := []
        let mut discharges : List RelationDischarge := []

        for tx in txs do
          let event ← Event.ofEffects? tx.event tx.effects
          events := events ++ [event]
          facts := facts ++ [.base tx.event tx.baseValidOn]

          if let some descText := tx.description then
            descriptions := descriptions ++ [{ event := tx.event, text := descText }]

          if let some target := tx.replaces then
            corrections := corrections ++ [{ target := target, replacement := tx.event }]

          if let some target := tx.reversalOf then
            reversals := reversals ++ [{ target := target, reversal := tx.event }]

          for (revId, date, targetRef) in tx.dateRevisions do
            facts := facts ++ [.revision revId tx.event date]
            valCorrections := valCorrections ++ [{ target := targetRef, replacement := revId }]

          relations := relations ++ tx.relations
          discharges := discharges ++ tx.discharges

        let eventMemory ← EventMemory.ofEvents? events
        let validityHistory ← ActualValidityHistory.ofParts? facts valCorrections
        let descMemory ← EventDescriptionMemory.ofEntries? descriptions
        let corrMemory ← EventCorrectionMemory.ofCorrections? corrections
        let revMemory ← ActualReversalMemory.ofReversals? reversals

        let rawEvidence : ActualEvidence := {
          events := eventMemory
          validity := validityHistory
          descriptions := descMemory
          corrections := corrMemory
          reversals := revMemory
          relations := relations
          discharges := discharges
        }

        admitActualEvidence? rawEvidence

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
