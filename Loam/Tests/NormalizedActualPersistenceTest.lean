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
  "EFFECT\twallet\tjpy\t400\n" ++
  "EFFECT\tbank\tjpy\t-400\n" ++
  "DISCHARGE\trel-loan\t400\n" ++
  "ENDTX\n" ++
  "TX\tev-corr-target\t2026-09-06\tNODESC\n" ++
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

  -- 1b. Aggregate validity facts must not name Events outside the generation.
  let orphanValidity ← requireSome
    (evidence1.validity.addFact? (.base ⟨"orphan-event"⟩ "2026-09-10"))
    "could not construct orphan validity regression fixture"
  let orphanEvidence := { evidence1 with validity := orphanValidity }
  requireNone (admitActualEvidence? orphanEvidence)
    "admitted a validity fact for an absent Event"
  requireNone (encodeNormalizedActual? orphanEvidence)
    "encoded an orphan validity fact by silently dropping it"

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

  -- Check wire preservation: anonymous effects do NOT have KEYED-EFFECT
  expect ((encodedWire.splitOn "EFFECT\twallet\tjpy\t-1000").length >= 2)
    "encoded wire lost anonymous effect"
  expect ((encodedWire.splitOn "KEYED-EFFECT\tk-source\tbank\tjpy\t1500").length >= 2)
    "encoded wire lost keyed effect"
  expect ((encodedWire.splitOn "KEYED-EFFECT\t").length == 2)
    "encoded wire has wrong number of keyed effects"

  -- 5. Decode again and verify semantic round-trip
  let evidence2 ← requireSome (decodeNormalizedActual? encodedWire)
    "decoding re-encoded wire failed"
  expect (evidence1.events.events.length == evidence2.events.events.length)
    "round trip changed event count"
  expect (evidence1.relations.length == evidence2.relations.length)
    "round trip changed relation count"
  expect (evidence1.discharges.length == evidence2.discharges.length)
    "round trip changed discharge count"
  expect (evidence1.corrections.corrections.length == evidence2.corrections.corrections.length)
    "round trip changed correction count"
  expect (evidence1.reversals.reversals.length == evidence2.reversals.reversals.length)
    "round trip changed reversal count"

  -- 6. Fail-closed tests on invalid fixtures

  -- 6a. Duplicate EventId
  let dupEvent :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "ENDTX\n" ++
    "TX\tev-1\t2026-09-02\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t100\n" ++
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
    "ENDTX\n"
  requireNone (decodeNormalizedActual? openCorrection) "admitted open correction"

  -- 6d. Invalid date revision topology (names nonexistent REV)
  let invalidDateRev :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "DATE-REV\trev-1\t2026-09-02\tREPLACES\tREV\tmissing-rev\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidDateRev) "admitted invalid date revision"

  -- 6e. Unresolved Relation source (source key not in effect keys)
  let unresRelSource :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "KEYED-EFFECT\tk-1\twallet\tjpy\t-100\n" ++
    "RELATION\trel-1\tSOURCE\tmissing-key\texternal:f\thousehold\t50\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? unresRelSource) "admitted unresolved relation source"

  -- 6f. Unknown discharge target (relation does not exist)
  let unknownDischarge :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t-100\n" ++
    "DISCHARGE\tmissing-rel\t50\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? unknownDischarge) "admitted unknown discharge target"

  -- 6g. Over-discharge (discharge quantity > relation quantity)
  let overDischarge :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "KEYED-EFFECT\tk-1\tbank\tjpy\t100\n" ++
    "RELATION\trel-1\tSOURCE\tk-1\texternal:f\thousehold\t100\n" ++
    "ENDTX\n" ++
    "TX\tev-2\t2026-09-02\tNODESC\n" ++
    "EFFECT\twallet\tjpy\t150\n" ++
    "DISCHARGE\trel-1\t150\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? overDischarge) "admitted over-discharge"

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

  -- 6i. Invalid Effect coordinate token is rejected at canonical decode.
  let invalidLocusToken :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-1\t2026-09-01\tNODESC\n" ++
    "EFFECT\t\tjpy\t-100\n" ++
    "EFFECT\tbank\tjpy\t100\n" ++
    "ENDTX\n"
  requireNone (decodeNormalizedActual? invalidLocusToken)
    "admitted an Effect with an invalid Locus token"

  -- 7. Persistence remains measure-neutral; JPY is a practical operation contract.
  let balancedUsd :=
    "LOAM-NORMALIZED-ACTUAL\t1\n" ++
    "TX\tev-usd\t2026-09-09\tNODESC\n" ++
    "EFFECT\twallet\tusd\t-100\n" ++
    "EFFECT\tbank\tusd\t100\n" ++
    "ENDTX\n"
  let _ ← requireSome (decodeNormalizedActual? balancedUsd)
    "normalized Actual incorrectly imposed the practical JPY operation contract"

  IO.println "All NormalizedActualPersistence tests passed successfully!"
