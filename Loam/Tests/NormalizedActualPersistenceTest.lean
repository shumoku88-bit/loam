import Loam.Persistence.NormalizedActualPersistence
import Loam.Application.CorrectionFrontier
import Loam.Application.ActualValidityFrontier
import Loam.Application.OpenRelationFrontier
import Loam.Application.RelationDischargeFrontier

open Loam
open Loam.Core
open Loam.Application
open Loam.Persistence

def expect (condition : Bool) (message : String) : IO Unit := do
  if !condition then
    throw <| IO.userError message

def requireSome {α : Type} (option : Option α) (message : String) : IO α :=
  match option with
  | some value => pure value
  | none => throw <| IO.userError message

def requireNone {α : Type} (option : Option α) (message : String) : IO Unit :=
  match option with
  | some _ => throw <| IO.userError message
  | none => pure ()

def validFixtureWire : String :=
  "LOAM-NORMALIZED-ACTUAL\t1\n" ++
  "TX\tev-root\t2026-09-01\tDESC\tRoot transaction with mixed effects\n" ++
  "MERCHANT\tmerchant-grocery\n" ++
  "OPERATION\tproposal-root\n" ++
  "EFFECT\twallet\tjpy\t-1000\n" ++
  "EFFECT\twallet\tjpy\t-500\n" ++
  "KEYED-EFFECT\tk-source\tbank\tjpy\t1500\n" ++
  "DATE-REV\trev-1\t2026-09-02\tREPLACES\tROOT\n" ++
  "DATE-REV\trev-2\t2026-09-03\tREPLACES\tREV\trev-1\n" ++
  "RELATION\trel-loan\tSOURCE\tk-source\texternal:friend\thousehold\t1000\n" ++
  "ENDTX\n" ++
  "TX\tev-reversal\t2026-09-04\tNODESC\n" ++
  "REVERSAL-OF\tev-root\n" ++
  "EFFECT\twallet\tjpy\t1000\n" ++
  "EFFECT\twallet\tjpy\t500\n" ++
  "EFFECT\tbank\tjpy\t-1500\n" ++
  "ENDTX\n" ++
  "TX\tev-discharge\t2026-09-05\tDESC\tPartial repayment\n" ++
  "NONMERCHANT\n" ++
  "EFFECT\twallet\tjpy\t400\n" ++
  "EFFECT\tbank\tjpy\t-400\n" ++
  "DISCHARGE\trel-loan\t400\n" ++
  "ENDTX\n" ++
  "TX\tev-corr-target\t2026-09-06\tNODESC\n" ++
  "ORIGINAL-AMOUNT\tusd\t3000\n" ++
  "EFFECT\twallet\tjpy\t-100\n" ++
  "EFFECT\tbank\tjpy\t100\n" ++
  "ENDTX\n" ++
  "TX\tev-corr-r1\t2026-09-07\tDESC\tCorrection 1\n" ++
  "REPLACES\tev-corr-target\n" ++
  "EFFECT\twallet\tjpy\t-120\n" ++
  "EFFECT\tbank\tjpy\t120\n" ++
  "ENDTX\n" ++
  "TX\tev-corr-r2\t2026-09-08\tDESC\tCorrection 2\n" ++
  "REPLACES\tev-corr-r1\n" ++
  "EFFECT\twallet\tjpy\t-150\n" ++
  "EFFECT\tbank\tjpy\t150\n" ++
  "ENDTX\n"

def main : IO Unit := do
  -- 1. Decode valid fixture
  let evidence1 ← requireSome (decodeNormalizedActual? validFixtureWire)
    "valid normalized actual fixture failed to decode"
  let image1 ← requireSome (decodeNormalizedActualImage? validFixtureWire)
    "valid normalized actual image failed to decode"
  expect ((image1.currentEvents.findById? ⟨"ev-corr-r2"⟩).isSome)
    "admitted Actual image lost current terminal correction Event"
  expect ((image1.currentEvents.findById? ⟨"ev-corr-target"⟩).isNone)
    "admitted Actual image retained superseded correction target"
  let imageRootDate ← requireSome
    (image1.currentValidities.findByEventId? ⟨"ev-root"⟩)
    "admitted Actual image lost current root occurrence date"
  expect (imageRootDate == "2026-09-03")
    "admitted Actual image did not carry revised current occurrence date"

  let eventOrder := evidence1.events.events.map (·.id.token)
  expect (eventOrder == ["ev-root", "ev-reversal", "ev-discharge", "ev-corr-target", "ev-corr-r1", "ev-corr-r2"])
    "normalized Actual decoding did not preserve transaction wire order"

  -- 1a. Merchant evidence preserves the unresolved / merchant / nonmerchant distinction.
  match evidence1.merchants.findDisposition? ⟨"ev-root"⟩ with
  | some (.merchant party) =>
      expect (party.token == "merchant-grocery") "merchant identity decoded incorrectly"
  | _ => throw <| IO.userError "merchant disposition missing for ev-root"
  match evidence1.merchants.findDisposition? ⟨"ev-discharge"⟩ with
  | some .nonmerchant => pure ()
  | _ => throw <| IO.userError "explicit nonmerchant disposition missing"
  expect ((evidence1.merchants.findDisposition? ⟨"ev-reversal"⟩).isNone)
    "missing Merchant row did not remain unresolved"

  -- 1aa. Movement operation evidence preserves the idempotency key -> Event mapping.
  expect (evidence1.movementOperations.findEvent? ⟨"proposal-root"⟩ ==
      some ⟨"ev-root"⟩)
    "Movement operation identity did not resolve to ev-root"
  expect (evidence1.movementOperations.findOperation? ⟨"ev-root"⟩ ==
      some ⟨"proposal-root"⟩)
    "ev-root did not resolve back to its Movement operation identity"

  -- 1ab. Original amount is retained at the stable correction root and projects
  -- to the current terminal Event without rewriting the stored subject.
  let originalAtRoot ← requireSome
    (evidence1.originalAmounts.findByEvent? ⟨"ev-corr-target"⟩)
    "original amount missing from stable correction root"
  expect (originalAtRoot.measure.token == "usd" &&
      originalAtRoot.quantity.quanta == 3000)
    "original amount decoded incorrectly"
  let currentOriginals ← requireSome
    (currentOriginalAmounts?
      evidence1.events evidence1.corrections evidence1.originalAmounts)
    "current original amount projection failed"
  match currentOriginals with
  | [entry] =>
      expect (entry.event == ⟨"ev-corr-r2"⟩ &&
          entry.measure.token == "usd" &&
          entry.quantity.quanta == 3000)
        "original amount did not follow correction root to terminal Event"
  | _ =>
      throw <| IO.userError "unexpected current original amount projection shape"

  -- 1b. Aggregate validity facts must not name Events outside the generation.
  let orphanValidity ← requireSome
    (evidence1.validity.addFact? (.base ⟨"orphan-event"⟩ "2026-09-10"))
    "could not construct orphan validity regression fixture"
  let orphanEvidence := { evidence1 with validity := orphanValidity }
  requireNone (admitActualEvidence? orphanEvidence)
    "admitted a validity fact for an absent Event"
  requireNone (encodeNormalizedActual? orphanEvidence)
    "encoded an orphan validity fact by silently dropping it"

  -- 1c. Merchant evidence must also remain referentially closed over retained Events.
  let orphanMerchants ← requireSome
    (EventMerchantEvidenceMemory.ofEntries? [
      { event := ⟨"orphan-event"⟩, disposition := .merchant ⟨"orphan-merchant"⟩ }
    ])
    "could not construct orphan Merchant regression fixture"
  let orphanMerchantEvidence := { evidence1 with merchants := orphanMerchants }
  requireNone (admitActualEvidence? orphanMerchantEvidence)
    "admitted Merchant evidence for an absent Event"
  requireNone (encodeNormalizedActual? orphanMerchantEvidence)
    "encoded orphan Merchant evidence by silently dropping it"

  -- 1d. Movement operation evidence must remain referentially closed over retained Events.
  let orphanOperations ← requireSome
    (MovementOperationEvidenceMemory.ofEntries? [
      { operation := ⟨"orphan-operation"⟩, event := ⟨"orphan-event"⟩ }
    ])
    "could not construct orphan Movement operation regression fixture"
  let orphanOperationEvidence := { evidence1 with movementOperations := orphanOperations }
  requireNone (admitActualEvidence? orphanOperationEvidence)
    "admitted Movement operation evidence for an absent Event"
  requireNone (encodeNormalizedActual? orphanOperationEvidence)
    "encoded orphan Movement operation evidence by silently dropping it"

  -- 2. Verify identity sparsity: anonymous effects are none, keyed is some
  let rootEv ← requireSome (evidence1.events.findById? ⟨"ev-root"⟩)
    "ev-root not found in decoded evidence"
  match rootEv.effects with
  | [e1, e2, e3] =>
      expect (e1.key.isNone) "first effect must be anonymous"
      expect (e2.key.isNone) "second effect must be anonymous"
      expect (e3.key == some ⟨"k-source"⟩) "third effect must be keyed k-source"
      expect (e1.locus.token == "wallet" && e1.quantity.quanta == -1000) "e1 coordinates wrong"
      expect (e2.locus.token == "wallet" && e2.quantity.quanta == -500) "e2 coordinates wrong"
  | _ => throw <| IO.userError "ev-root effect count mismatch"

  -- 3. Verify production frontiers against decoded evidence
  -- 3a. Correction frontier
  let frontierEvents ← requireSome
    (correctionFrontierMemory? evidence1.events evidence1.corrections)
    "correction frontier failed"
  expect ((frontierEvents.findById? ⟨"ev-corr-r2"⟩).isSome)
    "ev-corr-r2 should be current in frontier"
  expect ((frontierEvents.findById? ⟨"ev-corr-target"⟩).isNone)
    "ev-corr-target should be superseded"
  expect ((frontierEvents.findById? ⟨"ev-corr-r1"⟩).isNone)
    "ev-corr-r1 should be superseded"

  -- 3b. Validity frontier
  let admittedDates ← requireSome
    (admittedActualValidityMemory? evidence1.validity)
    "validity frontier failed"
  let rootDate ← requireSome (admittedDates.findByEventId? ⟨"ev-root"⟩)
    "root date missing"
  expect (rootDate == "2026-09-03")
    s!"root event date should be revised to 2026-09-03, got {rootDate}"

  -- 3c. Relation and discharge frontier
  let outstanding ← requireSome
    (relationOutstandingQuantity? evidence1.events evidence1.relations evidence1.discharges ⟨"rel-loan"⟩)
    "outstanding quantity failed"
  expect (outstanding.quanta == 600)
    s!"outstanding quantity should be 600 (1000 - 400), got {outstanding.quanta}"

  -- 3d. Quantity projection at wallet and bank
  let yen : MeasureId := ⟨"jpy"⟩
  let walletQuantity := Event.quantityAt rootEv ⟨"wallet"⟩ yen
  expect (walletQuantity.quanta == -1500)
    s!"wallet projection should aggregate both anonymous effects (-1500), got {walletQuantity.quanta}"

  -- 4. Encode evidence back to normalized wire
  let encodedWire ← requireSome (encodeNormalizedActual? evidence1)
    "encoding admitted evidence failed"

  -- Check wire preservation: anonymous effects do NOT have KEYED-EFFECT, Merchant rows are explicit.
  expect ((encodedWire.splitOn "EFFECT\twallet\tjpy\t-1000").length >= 2)
    "encoded wire lost anonymous effect"
  expect ((encodedWire.splitOn "KEYED-EFFECT\tk-source\tbank\tjpy\t1500").length >= 2)
    "encoded wire lost keyed effect"
  expect ((encodedWire.splitOn "KEYED-EFFECT\t").length == 2)
    "encoded wire has wrong number of keyed effects"
  expect ((encodedWire.splitOn "MERCHANT\tmerchant-grocery").length == 2)
    "encoded wire lost Merchant identity evidence"
  expect ((encodedWire.splitOn "NONMERCHANT").length == 2)
    "encoded wire lost explicit nonmerchant evidence"
  expect ((encodedWire.splitOn "OPERATION\tproposal-root").length == 2)
    "encoded wire lost Movement operation evidence"
  expect ((encodedWire.splitOn "ORIGINAL-AMOUNT\tusd\t3000").length == 2)
    "encoded wire lost OriginalAmount evidence"

  -- 5. Decode again and verify semantic round-trip
  let evidence2 ← requireSome (decodeNormalizedActual? encodedWire)
    "decoding re-encoded wire failed"
  expect (evidence1.events.events.length == evidence2.events.events.length)
    "round trip changed event count"
  expect (evidence1.merchants.entries.length == evidence2.merchants.entries.length)
    "round trip changed Merchant evidence count"
  expect (evidence1.movementOperations.entries.length ==
      evidence2.movementOperations.entries.length)
    "round trip changed Movement operation evidence count"
  expect (evidence1.originalAmounts.entries.length ==
      evidence2.originalAmounts.entries.length)
    "round trip changed OriginalAmount evidence count"
  expect (evidence1.relations.length == evidence2.relations.length)
    "round trip changed relation count"
  expect (evidence1.discharges.length == evidence2.discharges.length)
    "round trip changed discharge count"
  expect (evidence1.corrections.corrections.length == evidence2.corrections.corrections.length)
    "round trip changed correction count"
  expect (evidence1.reversals.reversals.length == evidence2.reversals.reversals.length)
    "round trip changed reversal count"
  expect (evidence2.merchants.findDisposition? ⟨"ev-root"⟩ ==
      some (.merchant ⟨"merchant-grocery"⟩))
    "round trip changed Merchant identity"
  expect (evidence2.merchants.findDisposition? ⟨"ev-discharge"⟩ == some .nonmerchant)
    "round trip changed explicit nonmerchant disposition"
  expect (evidence2.movementOperations.findEvent? ⟨"proposal-root"⟩ ==
      some ⟨"ev-root"⟩)
    "round trip changed Movement operation mapping"

  -- 6. Fail-closed tests on invalid fixtures

  -- 6a. Duplicate EventId
  let dupEvent :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n" ++
    "TX\tev-1\t2026-09-02\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t100\n" ++
    "EFFECT\tbank\tjpy\t-100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? dupEvent) "admitted duplicate EventId"

  -- 6b. Duplicate retained EffectKey
  let dupKey :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "KEYED-EFFECT\tsame-key\twallet\tjpy\t-100\n" ++
    "KEYED-EFFECT\tsame-key\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? dupKey) "admitted duplicate retained EffectKey"

  -- 6c. Open correction (target does not exist)
  let openCorrection :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-repl\t2026-09-01\tNODESC\n" ++
    "REPLACES\tmissing-target\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? openCorrection) "admitted open correction"

  -- 6d. Invalid date revision topology (names nonexistent REV)
  let invalidDateRev :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "DATE-REV\trev-1\t2026-09-02\tREPLACES\tREV\tmissing-rev\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidDateRev) "admitted invalid date revision"

  -- 6e. Unresolved Relation source (source key not in effect keys)
  let unresRelSource :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "KEYED-EFFECT\tk-1\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "RELATION\trel-1\tSOURCE\tmissing-key\texternal:f\thousehold\t50\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? unresRelSource) "admitted unresolved relation source"

  -- 6f. Unknown discharge target (relation does not exist)
  let unknownDischarge :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "DISCHARGE\tmissing-rel\t50\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? unknownDischarge) "admitted unknown discharge target"

  -- 6g. Over-discharge (discharge quantity > relation quantity)
  let overDischarge :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "KEYED-EFFECT\tk-1\tbank\tjpy\t100\n" ++
    "RELATION\trel-1\tSOURCE\tk-1\texternal:f\thousehold\t100\n" ++
    "ENDTX\n" ++
    "TX\tev-2\t2026-09-02\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t150\n" ++
    "EFFECT\tbank\tjpy\t-150\n" ++
    "DISCHARGE\trel-1\t150\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? overDischarge) "admitted over-discharge"

  -- 6gg. Raw discharge referencing nonexistent Event fails closed under persistence admission
  let missingEventDischargeEvidence : ActualEvidence := {
    evidence1 with
    discharges := { event := ⟨"nonexistent-event"⟩, target := ⟨"rel-loan"⟩, quantity := Quantity.ofQuanta 100 } :: evidence1.discharges
  }
  requireNone (admitActualImage? missingEventDischargeEvidence)
    "persistence admission must reject raw discharge referencing nonexistent Event"

  -- 6ggg. Raw discharge referencing nonexistent RelationUnit target fails closed under persistence admission
  let missingTargetDischargeEvidence : ActualEvidence := {
    evidence1 with
    discharges := { event := ⟨"ev-discharge"⟩, target := ⟨"nonexistent-relation"⟩, quantity := Quantity.ofQuanta 100 } :: evidence1.discharges
  }
  requireNone (admitActualImage? missingTargetDischargeEvidence)
    "persistence admission must reject raw discharge referencing nonexistent RelationUnit target"

  -- 6h. Invalid reversal (effects do not invert target)
  let invalidReversal :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n" ++
    "TX\tev-2\t2026-09-02\tNODESC\n" ++
    "REVERSAL-OF\tev-1\n" ++
    "EFFECT\twallet\tjpy\t90\n" ++ -- Should be +100!
    "EFFECT\tbank\tjpy\t-90\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidReversal) "admitted invalid reversal"

  -- 6ha. Self-reversal is rejected while constructing proof-carrying reversal memory.
  let selfReversal :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-self\t2026-09-01\tNODESC\n" ++
    "REVERSAL-OF\tev-self\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed selfReversal with
  | .error (.construction .reversalMemory) => pure ()
  | .error err =>
      throw <| IO.userError s!"expected construction .reversalMemory for self-reversal, got: {err}"
  | .ok _ =>
      throw <| IO.userError "expected self-reversal to fail while constructing ActualReversalMemory"
  requireNone (decodeNormalizedActual? selfReversal)
    "admitted self-reversal after endpoint uniqueness moved into Core memory"

  -- 6hb. Reversal-of-reversal chains are rejected by the same endpoint uniqueness invariant.
  let reversalChain :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-a\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n" ++
    "TX\tev-b\t2026-09-02\tNODESC\n" ++
    "REVERSAL-OF\tev-a\n" ++
    "EFFECT\twallet\tjpy\t100\n" ++
    "EFFECT\tbank\tjpy\t-100\n" ++
    "ENDTX\n" ++
    "TX\tev-c\t2026-09-03\tNODESC\n" ++
    "REVERSAL-OF\tev-b\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed reversalChain with
  | .error (.construction .reversalMemory) => pure ()
  | .error err =>
      throw <| IO.userError s!"expected construction .reversalMemory for reversal chain, got: {err}"
  | .ok _ =>
      throw <| IO.userError "expected reversal chain to fail while constructing ActualReversalMemory"
  requireNone (decodeNormalizedActual? reversalChain)
    "admitted reversal chain after endpoint uniqueness moved into Core memory"

  -- 6hc. Exact inverse does not excuse an unbalanced target Event.
  -- Reversal balance may be derived, but the target side must still pass runtime admission once.
  let exactInverseOfUnbalancedTarget :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-unbalanced-target\t2026-09-01\tNODESC\n" ++
    "EFFECT\tcash\tjpy\t50000\n" ++
    "ENDTX\n" ++
    "TX\tev-unbalanced-reversal\t2026-09-02\tNODESC\n" ++
    "REVERSAL-OF\tev-unbalanced-target\n" ++
    "EFFECT\tcash\tjpy\t-50000\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? exactInverseOfUnbalancedTarget)
    "exact inverse incorrectly bypassed target balance admission"

  -- 6hd. A valid exact reversal may span multiple Measures; each target Measure is
  -- admitted once and the reversal-side balance is proof-derived independently.
  let multiMeasureReversal :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-multi-target\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "EFFECT\tasset\tusd\t-5\n" ++
    "EFFECT\treserve\tusd\t5\n" ++
    "ENDTX\n" ++
    "TX\tev-multi-reversal\t2026-09-02\tNODESC\n" ++
    "REVERSAL-OF\tev-multi-target\n" ++
    "EFFECT\twallet\tjpy\t100\n" ++
    "EFFECT\tbank\tjpy\t-100\n" ++
    "EFFECT\tasset\tusd\t5\n" ++
    "EFFECT\treserve\tusd\t-5\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? multiMeasureReversal)
    "proof-derived reversal balance rejected a valid multi-Measure exact inverse"

  -- 6i. Invalid Effect coordinate token is rejected at canonical decode.
  let invalidLocusToken :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\t\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidLocusToken)
    "admitted an Effect with an invalid Locus token"

  -- 6j. One Event may retain at most one Merchant disposition row.
  let duplicateMerchant :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "MERCHANT\tshop-1\n" ++
    "NONMERCHANT\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? duplicateMerchant)
    "admitted two Merchant dispositions for one Event"

  -- 6k. Merchant identity uses the same canonical token syntax as other opaque identities.
  let invalidMerchantToken :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "MERCHANT\t\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidMerchantToken)
    "admitted malformed Merchant identity token"

  -- 6ka. One Event may retain at most one Movement operation identity.
  let duplicateOperationRow :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "OPERATION\top-1\n" ++
    "OPERATION\top-2\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? duplicateOperationRow)
    "admitted two Movement operation identities for one Event"

  -- 6kb. One Movement operation identity may not produce two different Events.
  let duplicateOperationIdentity :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "OPERATION\tsame-operation\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n" ++
    "TX\tev-2\t2026-09-02\tNODESC\n" ++
    "OPERATION\tsame-operation\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? duplicateOperationIdentity)
    "admitted one Movement operation identity for two Events"

  -- 6l. Quantity-bearing Events must close to zero at persistence re-admission.
  let unbalancedEvent :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-unbalanced\t2026-09-01\tNODESC\n" ++
    "EFFECT\tcash\tjpy\t50000\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? unbalancedEvent)
    "admitted an unbalanced quantity-bearing Event"

  -- 6m. Zero-quantity Effects are not retained as ghost physical evidence.
  let zeroEffect :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-zero\t2026-09-01\tNODESC\n" ++
    "EFFECT\tcash\tjpy\t0\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? zeroEffect)
    "admitted a zero-quantity Effect"

  -- 6n. Base dates must be real calendar dates, not merely valid text tokens.
  let invalidBaseDate :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-date\t2026-02-30\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidBaseDate)
    "admitted a nonexistent base calendar date"

  let nonsensicalBaseDate :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-date\tbanana\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? nonsensicalBaseDate)
    "admitted a non-date base token"

  -- 6o. Date revisions pass through the same calendar-semantic boundary.
  let invalidRevisionDate :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-date\t2026-09-01\tNODESC\n" ++
    "DATE-REV\trev-bad-date\t2026-02-30\tREPLACES\tROOT\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidRevisionDate)
    "admitted a nonexistent revision calendar date"

  -- 6p. Different Measures cannot cancel one another dimensionally.
  let crossMeasureCancellation :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-mixed\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tusd\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? crossMeasureCancellation)
    "admitted cross-Measure cancellation"

  -- 6pa. A qualified two-Measure exchange bypasses ordinary per-Measure
  -- balance without treating unlike Measures as arithmetically cancelling.
  let qualifiedExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-jpy-usd\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tjpy-source\tusd-destination\n" ++
    "KEYED-EFFECT\tjpy-source\tcash-jpy\tjpy\t-15000\n" ++
    "KEYED-EFFECT\tusd-destination\tcash-usd\tusd\t100\n" ++
    "ENDTX\n"
  let exchangeEvidence ← requireSome (decodeNormalizedActual? qualifiedExchange)
    "qualified cross-Measure exchange was rejected"
  let retainedExchange ← requireSome
    (exchangeEvidence.exchanges.findByEvent? ⟨"exchange-jpy-usd"⟩)
    "decoded exchange evidence was missing"
  expect (retainedExchange.source == ⟨"jpy-source"⟩ &&
      retainedExchange.destination == ⟨"usd-destination"⟩)
    "decoded exchange EffectKey anchors changed"
  let reencodedExchange ← requireSome (encodeNormalizedActual? exchangeEvidence)
    "qualified exchange failed to encode"
  expect ((reencodedExchange.splitOn "EXCHANGE\tjpy-source\tusd-destination").length == 2)
    "encoded wire lost exchange evidence"
  let _ ← requireSome (decodeNormalizedActual? reencodedExchange)
    "qualified exchange failed normalized round-trip"

  -- 6pb. Extra Effects in one selected Measure remain allowed, preserving one
  -- fee-bearing occurrence without assigning fee meaning here.
  let feeBearingExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-with-fee\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tjpy-source\tusd-destination\n" ++
    "KEYED-EFFECT\tjpy-source\tcash-jpy\tjpy\t-15100\n" ++
    "KEYED-EFFECT\tfee\texchange-fee\tjpy\t100\n" ++
    "KEYED-EFFECT\tusd-destination\tcash-usd\tusd\t100\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? feeBearingExchange)
    "fee-bearing qualified exchange was rejected"

  -- 6pc. EXCHANGE is not a generic unbalanced-Event escape hatch: a third
  -- Measure is outside the currently qualified production shape.
  let thirdMeasureExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-third-measure\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tjpy-source\tusd-destination\n" ++
    "KEYED-EFFECT\tjpy-source\tcash-jpy\tjpy\t-15000\n" ++
    "KEYED-EFFECT\tusd-destination\tcash-usd\tusd\t100\n" ++
    "KEYED-EFFECT\teur-fee\tfee\teur\t1\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? thirdMeasureExchange)
    "exchange admission allowed an unqualified third Measure"

  -- 6pd. Selected source and destination must use distinct Measures.
  let sameMeasureExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-same-measure\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tleft\tright\n" ++
    "KEYED-EFFECT\tleft\tcash-a\tjpy\t-100\n" ++
    "KEYED-EFFECT\tright\tcash-b\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? sameMeasureExchange)
    "exchange admission accepted same-Measure selected sides"

  -- 6pe. Direction comes from observed signs, not Measure names.
  let wrongDirectionExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-wrong-direction\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tusd-positive\tjpy-negative\n" ++
    "KEYED-EFFECT\tjpy-negative\tcash-jpy\tjpy\t-15000\n" ++
    "KEYED-EFFECT\tusd-positive\tcash-usd\tusd\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? wrongDirectionExchange)
    "exchange admission accepted reversed source/destination signs"

  -- 6pf. Both selected EffectKey anchors must resolve in the named Event.
  let missingExchangeEffect :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-missing-effect\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tjpy-source\tmissing-usd\n" ++
    "KEYED-EFFECT\tjpy-source\tcash-jpy\tjpy\t-15000\n" ++
    "KEYED-EFFECT\tactual-usd\tcash-usd\tusd\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? missingExchangeEffect)
    "exchange admission accepted a dangling EffectKey"

  -- 6pg. Exchange correction remains fail-closed until effect-level replacement
  -- semantics are independently qualified.
  let correctedExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-root\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tjpy-source\tusd-destination\n" ++
    "KEYED-EFFECT\tjpy-source\tcash-jpy\tjpy\t-15000\n" ++
    "KEYED-EFFECT\tusd-destination\tcash-usd\tusd\t100\n" ++
    "ENDTX\n" ++
    "TX\texchange-replacement\t2026-09-10\tNODESC\n" ++
    "REPLACES\texchange-root\n" ++
    "KEYED-EFFECT\tnew-jpy\tcash-jpy\tjpy\t-14900\n" ++
    "KEYED-EFFECT\tnew-usd\tcash-usd\tusd\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? correctedExchange)
    "exchange correction crossed canonical admission before replacement semantics were qualified"

  -- 6ph. Exact physical reversal may undo a qualified exchange without
  -- synthesizing a second EXCHANGE row for the reversal Event.
  let reversedExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-target\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\tjpy-source\tusd-destination\n" ++
    "KEYED-EFFECT\tjpy-source\tcash-jpy\tjpy\t-15000\n" ++
    "KEYED-EFFECT\tusd-destination\tcash-usd\tusd\t100\n" ++
    "ENDTX\n" ++
    "TX\texchange-reversal\t2026-09-10\tNODESC\n" ++
    "REVERSAL-OF\texchange-target\n" ++
    "KEYED-EFFECT\treverse-jpy\tcash-jpy\tjpy\t15000\n" ++
    "KEYED-EFFECT\treverse-usd\tcash-usd\tusd\t-100\n" ++
    "ENDTX\n"
  let reversedEvidence ← requireSome (decodeNormalizedActual? reversedExchange)
    "exact reversal of qualified exchange was rejected"
  expect ((reversedEvidence.exchanges.findByEvent? ⟨"exchange-target"⟩).isSome)
    "target exchange evidence disappeared across reversal admission"
  expect ((reversedEvidence.exchanges.findByEvent? ⟨"exchange-reversal"⟩).isNone)
    "reversal unexpectedly synthesized exchange evidence"

  -- 6pi. One Event may carry at most one EXCHANGE row.
  let duplicateExchange :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\texchange-duplicate\t2026-09-09\tNODESC\n" ++
    "EXCHANGE\ta\tb\n" ++
    "EXCHANGE\tc\td\n" ++
    "KEYED-EFFECT\ta\tcash-jpy\tjpy\t-100\n" ++
    "KEYED-EFFECT\tb\tcash-usd\tusd\t1\n" ++
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed duplicateExchange with
  | .error (.parse { reason := .duplicateExchange, .. }) => pure ()
  | .error err =>
      throw <| IO.userError s!"expected duplicateExchange parse failure, got: {err}"
  | .ok _ =>
      throw <| IO.userError "expected duplicate EXCHANGE rows to fail"

  -- 6q. Neutral empty-effect Events remain representable.
  let emptyEvent :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-empty\t2026-09-01\tNODESC\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? emptyEvent)
    "normalized Actual incorrectly rejected a neutral empty-effect Event"

  -- 6r. Canonical Actual may retain Correction and Reversal as independent facts.
  let correctionReversalOverlap :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-target\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n" ++
    "TX\tev-reversal\t2026-09-02\tNODESC\n" ++
    "REVERSAL-OF\tev-target\n" ++
    "EFFECT\twallet\tjpy\t100\n" ++
    "EFFECT\tbank\tjpy\t-100\n" ++
    "ENDTX\n" ++
    "TX\tev-correction\t2026-09-03\tNODESC\n" ++
    "REPLACES\tev-target\n" ++
    "EFFECT\twallet\tjpy\t-120\n" ++
    "EFFECT\tbank\tjpy\t120\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? correctionReversalOverlap)
    "canonical Actual incorrectly collapsed writer-local Correction/Reversal qualification into a global admission law"

  -- 6s. Canonical Actual may retain Correction and Relation provenance independently.
  let correctionRelationOverlap :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-related\t2026-09-01\tNODESC\n" ++
    "KEYED-EFFECT\tk-related\twallet\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "RELATION\trel-related\tSOURCE\tk-related\thousehold\texternal:friend\t50\n" ++
    "ENDTX\n" ++
    "TX\tev-correction\t2026-09-02\tNODESC\n" ++
    "REPLACES\tev-related\n" ++
    "EFFECT\twallet\tjpy\t-120\n" ++
    "EFFECT\tbank\tjpy\t120\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? correctionRelationOverlap)
    "canonical Actual incorrectly collapsed writer-local Correction/Relation qualification into a global admission law"

  -- 6t. Canonical Actual may retain Correction and Discharge provenance independently.
  let correctionDischargeOverlap :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-source\t2026-09-01\tNODESC\n" ++
    "KEYED-EFFECT\tk-source\tpaypay\tjpy\t-700\n" ++
    "EFFECT\tcoffee\tjpy\t700\n" ++
    "RELATION\trel-1\tSOURCE\tk-source\texternal:friend\thousehold\t700\n" ++
    "ENDTX\n" ++
    "TX\tev-discharge\t2026-09-02\tNODESC\n" ++
    "EFFECT\tpaypay\tjpy\t400\n" ++
    "EFFECT\tcoffee\tjpy\t-400\n" ++
    "DISCHARGE\trel-1\t400\n" ++
    "ENDTX\n" ++
    "TX\tev-correction\t2026-09-03\tNODESC\n" ++
    "REPLACES\tev-discharge\n" ++
    "EFFECT\tpaypay\tjpy\t410\n" ++
    "EFFECT\tcoffee\tjpy\t-410\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? correctionDischargeOverlap)
    "canonical Actual incorrectly collapsed writer-local Correction/Discharge qualification into a global admission law"

  -- 7. Persistence remains measure-neutral; JPY is a practical operation contract.
  let balancedUsd :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-usd\t2026-09-09\tNODESC\n" ++
    "EFFECT\twallet\tusd\t-100\n" ++
    "EFFECT\tbank\tusd\t100\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? balancedUsd)
    "normalized Actual incorrectly imposed the practical JPY operation contract"

  -- 7a. Original amount is Measure-neutral: EUR accounting may retain JPY
  -- merchant-presented amount without creating a JPY Effect.
  let eurDebitJpyOriginal :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\teur-debit-japan\t2026-09-10\tNODESC\n" ++
    "ORIGINAL-AMOUNT\tjpy\t5000\n" ++
    "EFFECT\tbank-eur\teur\t-3120\n" ++
    "EFFECT\ttransport\teur\t3120\n" ++
    "ENDTX\n"
  let eurEvidence ← requireSome (decodeNormalizedActual? eurDebitJpyOriginal)
    "EUR accounting with JPY original amount was rejected"
  let eurOriginal ← requireSome
    (eurEvidence.originalAmounts.findByEvent? ⟨"eur-debit-japan"⟩)
    "JPY original amount missing from EUR accounting Event"
  expect (eurOriginal.measure.token == "jpy" &&
      eurOriginal.quantity.quanta == 5000)
    "Measure-neutral original amount decoded incorrectly"

  -- 7b. OriginalAmountEvidence must be anchored to a stable correction root,
  -- not directly to a replacement Event.
  let originalOnReplacement :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\toriginal-root\t2026-09-10\tNODESC\n" ++
    "EFFECT\tbank\tjpy\t-100\n" ++
    "EFFECT\tfood\tjpy\t100\n" ++
    "ENDTX\n" ++
    "TX\toriginal-replacement\t2026-09-10\tNODESC\n" ++
    "REPLACES\toriginal-root\n" ++
    "ORIGINAL-AMOUNT\tusd\t1000\n" ++
    "EFFECT\tbank\tjpy\t-110\n" ++
    "EFFECT\tfood\tjpy\t110\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? originalOnReplacement)
    "admitted OriginalAmountEvidence anchored directly to a correction replacement"

  -- 7c. One Event root may retain at most one original amount.
  let duplicateOriginalAmount :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\toriginal-duplicate\t2026-09-10\tNODESC\n" ++
    "ORIGINAL-AMOUNT\tusd\t1000\n" ++
    "ORIGINAL-AMOUNT\teur\t900\n" ++
    "EFFECT\tbank\tjpy\t-100\n" ++
    "EFFECT\tfood\tjpy\t100\n" ++
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed duplicateOriginalAmount with
  | .error (.parse { reason := .duplicateOriginalAmount, .. }) => pure ()
  | .error err =>
      throw <| IO.userError s!"expected duplicateOriginalAmount parse failure, got: {err}"
  | .ok _ =>
      throw <| IO.userError "expected duplicate original amount to fail"

  -- 7d. Zero and negative original amounts are outside the retained evidence meaning.
  let zeroOriginalAmount :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\toriginal-zero\t2026-09-10\tNODESC\n" ++
    "ORIGINAL-AMOUNT\tusd\t0\n" ++
    "EFFECT\tbank\tjpy\t-100\n" ++
    "EFFECT\tfood\tjpy\t100\n" ++
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed zeroOriginalAmount with
  | .error (.construction .originalAmountMemory) => pure ()
  | .error err =>
      throw <| IO.userError s!"expected originalAmountMemory construction failure, got: {err}"
  | .ok _ =>
      throw <| IO.userError "expected zero original amount to fail"

  -- 8. Structured diagnostic parsing tests (detailed decoders)

  -- 8a. Unknown row inside transaction reports correct line and reason
  let unknownRowWire :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++     -- line 1
    "TX\tev-1\t2026-09-01\tNODESC\n" ++   -- line 2
    "FOOBAR\tsomething\n" ++              -- line 3
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed unknownRowWire with
  | .error (.parse { line := 3, reason := .unknownRowType "FOOBAR" }) => pure ()
  | .error err => throw <| IO.userError s!"expected unknownRowType at line 3, got: {err}"
  | .ok _ => throw <| IO.userError "expected unknownRowType at line 3, got unexpected success"
  requireNone (decodeNormalizedActual? unknownRowWire)
    "legacy decodeNormalizedActual? must fail closed on unknown row"

  -- 8b. Malformed quantity reports correct line and reason
  let malformedQuantaWire :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++     -- line 1
    "TX\tev-1\t2026-09-01\tNODESC\n" ++   -- line 2
    "EFFECT\twallet\tjpy\tnot-a-number\n" ++ -- line 3
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed malformedQuantaWire with
  | .error (.parse { line := 3, reason := .invalidInteger "not-a-number" }) => pure ()
  | .error err => throw <| IO.userError s!"expected invalidInteger at line 3, got: {err}"
  | .ok _ => throw <| IO.userError "expected invalidInteger at line 3, got unexpected success"
  requireNone (decodeNormalizedActual? malformedQuantaWire)
    "legacy decodeNormalizedActual? must fail closed on malformed quantity"

  -- 8c. Duplicate OPERATION within a transaction produces dedicated duplicateOperation reason
  let dupOpWire :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++     -- line 1
    "TX\tev-1\t2026-09-01\tNODESC\n" ++   -- line 2
    "OPERATION\top-1\n" ++                -- line 3
    "OPERATION\top-2\n" ++                -- line 4
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed dupOpWire with
  | .error (.parse { line := 4, reason := .duplicateOperation }) => pure ()
  | .error err => throw <| IO.userError s!"expected duplicateOperation at line 4, got: {err}"
  | .ok _ => throw <| IO.userError "expected duplicateOperation at line 4, got unexpected success"
  requireNone (decodeNormalizedActual? dupOpWire)
    "legacy decodeNormalizedActual? must fail closed on duplicate OPERATION"

  -- 8d. Missing ENDTX before EOF is identified with transaction context
  let missingEndTxWire :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++     -- line 1
    "TX\tev-unclosed\t2026-09-01\tNODESC\n" ++ -- line 2
    "EFFECT\twallet\tjpy\t-100\n"        -- line 3
  match decodeNormalizedActualImageDetailed missingEndTxWire with
  | .error (.parse { line := 3, reason := .missingEndTx ⟨"ev-unclosed"⟩ 2 }) => pure ()
  | .error err => throw <| IO.userError s!"expected missingEndTx for ev-unclosed, got: {err}"
  | .ok _ => throw <| IO.userError "expected missingEndTx for ev-unclosed, got unexpected success"
  requireNone (decodeNormalizedActual? missingEndTxWire)
    "legacy decodeNormalizedActual? must fail closed on missing ENDTX"

  -- 8e. Invalid header is identified at line 1
  let invalidHeaderWire :=
    "LOAM-NORMALIZED-ACTUAL\t999\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "ENDTX\n"
  match decodeNormalizedActualImageDetailed invalidHeaderWire with
  | .error (.parse { line := 1, reason := .invalidHeader "LOAM-NORMALIZED-ACTUAL\t999" }) => pure ()
  | .error err => throw <| IO.userError s!"expected invalidHeader at line 1, got: {err}"
  | .ok _ => throw <| IO.userError "expected invalidHeader at line 1, got unexpected success"
  requireNone (decodeNormalizedActual? invalidHeaderWire)
    "legacy decodeNormalizedActual? must fail closed on invalid header"

  -- 8f. Missing final newline is identified
  let noNewlineWire :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "ENDTX"
  match decodeNormalizedActualImageDetailed noNewlineWire with
  | .error (.parse { line := 3, reason := .missingFinalNewline }) => pure ()
  | .error err => throw <| IO.userError s!"expected missingFinalNewline, got: {err}"
  | .ok _ => throw <| IO.userError "expected missingFinalNewline, got unexpected success"
  requireNone (decodeNormalizedActual? noNewlineWire)
    "legacy decodeNormalizedActual? must fail closed on missing final newline"

  -- 8g. Distinction between syntax failure, construction failure, and semantic admission failure
  -- 8g-1. Cross-transaction duplicate OPERATION identity produces construction error (not syntax error)
  match decodeNormalizedActualImageDetailed duplicateOperationIdentity with
  | .error (.construction .movementOperationMemory) => pure ()
  | .error err => throw <| IO.userError s!"expected construction .movementOperationMemory, got: {err}"
  | .ok _ => throw <| IO.userError "expected construction .movementOperationMemory, got unexpected success"

  -- 8g-2. Unbalanced quantity produces semantic admission failure (not syntax or construction error)
  match decodeNormalizedActualImageDetailed unbalancedEvent with
  | .error .admission => pure ()
  | .error err => throw <| IO.userError s!"expected admission failure for unbalancedEvent, got: {err}"
  | .ok _ => throw <| IO.userError "expected admission failure for unbalancedEvent, got unexpected success"

  -- 8h. decodeNormalizedActualDetailed consistency
  match decodeNormalizedActualDetailed unknownRowWire with
  | .error (.parse { line := 3, reason := .unknownRowType "FOOBAR" }) => pure ()
  | .error err => throw <| IO.userError s!"expected decodeNormalizedActualDetailed to report parse error, got: {err}"
  | .ok _ => throw <| IO.userError "expected decodeNormalizedActualDetailed to report parse error, got unexpected success"

  IO.println "All NormalizedActualPersistence tests passed successfully!"
