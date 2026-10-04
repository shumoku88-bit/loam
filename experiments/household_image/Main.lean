import Loam.Application.CurrentCoverageInspection
import Loam.Persistence.AccountingRolePersistence
import Loam.Persistence.ActualRoutingPersistence
import Loam.Persistence.AttentionPersistence
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.CurrentQuantityPresencePersistence
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Persistence.NormalizedActualPersistence
import Loam.Persistence.NormalizedCapacityPersistence
import Loam.Persistence.OpeningSupportPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.Persistence.ScheduledRoutingPersistence
import Loam.Persistence.ZeroOriginCoveragePersistence
import Loam.Publisher.BoundedHistorySupportPublisher
import Loam.Review.CurrentBalanceReview

set_option autoImplicit false

namespace Loam.HouseholdImageExperiment

open Loam.Core

/--
Research-only outer envelope for the existing canonical household authority
documents.

The fields deliberately remain opaque text. This experiment does not merge
their semantic types, change their inner codecs, or authorize a new production
persistence boundary.
-/
structure Sections where
  actual : String
  scheduled : String
  capacity : String
  attention : String
  actualRouting : String
  scheduledRouting : String
  accountingRole : String
  locusAdmission : String
  zeroOrigin : String
  openingSupport : String
  currentQuantityAnchor : String
  currentQuantityPresence : String
  boundedHistorySupport : String
deriving Repr, BEq

def householdImageHeader : String := "LOAM-HOUSEHOLD-IMAGE\t1"

private def encodeSection (name body : String) : String :=
  "SECTION\t" ++ name ++ "\t" ++ toString body.length ++ "\n" ++ body

/--
Encode one outer image while leaving every inner canonical document byte-for-byte
unchanged.

The character-count prefix avoids sentinel collisions with future inner row
syntax. Current LOAM canonical documents are text; the experiment intentionally
does not invent escaping or a second schema language.
-/
def encode (sections : Sections) : String :=
  householdImageHeader ++ "\n" ++
    encodeSection "Actual" sections.actual ++
    encodeSection "Scheduled" sections.scheduled ++
    encodeSection "Capacity" sections.capacity ++
    encodeSection "Attention" sections.attention ++
    encodeSection "ActualRouting" sections.actualRouting ++
    encodeSection "ScheduledRouting" sections.scheduledRouting ++
    encodeSection "AccountingRole" sections.accountingRole ++
    encodeSection "LocusAdmission" sections.locusAdmission ++
    encodeSection "ZeroOrigin" sections.zeroOrigin ++
    encodeSection "OpeningSupport" sections.openingSupport ++
    encodeSection "CurrentQuantityAnchor" sections.currentQuantityAnchor ++
    encodeSection "CurrentQuantityPresence" sections.currentQuantityPresence ++
    encodeSection "BoundedHistorySupport" sections.boundedHistorySupport

private def takeLine? (input : String) : Option (String × String) :=
  match input.splitOn "\n" with
  | line :: next :: rest =>
      some (line, String.intercalate "\n" (next :: rest))
  | _ => none

private def takeSection?
    (expected : String)
    (input : String) : Option (String × String) := do
  let (line, rest) ← takeLine? input
  match line.splitOn "\t" with
  | ["SECTION", found, lengthText] =>
      if found != expected then
        none
      else do
        let count ← lengthText.toNat?
        if rest.length < count then
          none
        else
          let body := (rest.take count).toString
          let remaining := (rest.drop count).toString
          some (body, remaining)
  | _ => none

/--
Decode exactly the version-1 fixed section set.

This boundary checks only outer framing. Inner semantic validity is checked
separately through the existing production decoders.
-/
def decode? (input : String) : Option Sections := do
  let headerPrefix := householdImageHeader ++ "\n"
  if !input.startsWith headerPrefix then
    none
  else
    let rest0 := (input.drop headerPrefix.length).toString
    let (actual, rest1) ← takeSection? "Actual" rest0
    let (scheduled, rest2) ← takeSection? "Scheduled" rest1
    let (capacity, rest3) ← takeSection? "Capacity" rest2
    let (attention, rest4) ← takeSection? "Attention" rest3
    let (actualRouting, rest5) ← takeSection? "ActualRouting" rest4
    let (scheduledRouting, rest6) ← takeSection? "ScheduledRouting" rest5
    let (accountingRole, rest7) ← takeSection? "AccountingRole" rest6
    let (locusAdmission, rest8) ← takeSection? "LocusAdmission" rest7
    let (zeroOrigin, rest9) ← takeSection? "ZeroOrigin" rest8
    let (openingSupport, rest10) ← takeSection? "OpeningSupport" rest9
    let (currentQuantityAnchor, rest11) ← takeSection? "CurrentQuantityAnchor" rest10
    let (currentQuantityPresence, rest12) ← takeSection? "CurrentQuantityPresence" rest11
    let (boundedHistorySupport, rest13) ← takeSection? "BoundedHistorySupport" rest12
    if !rest13.isEmpty then
      none
    else
      some {
        actual := actual
        scheduled := scheduled
        capacity := capacity
        attention := attention
        actualRouting := actualRouting
        scheduledRouting := scheduledRouting
        accountingRole := accountingRole
        locusAdmission := locusAdmission
        zeroOrigin := zeroOrigin
        openingSupport := openingSupport
        currentQuantityAnchor := currentQuantityAnchor
        currentQuantityPresence := currentQuantityPresence
        boundedHistorySupport := boundedHistorySupport
      }

private def requireSome {α : Type}
    (value : Option α)
    (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw <| IO.userError message

private def requireOk {α : Type}
    (value : Except String α)
    (message : String) : IO α :=
  match value with
  | .ok value => pure value
  | .error detail => throw <| IO.userError (message ++ ": " ++ detail)

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def expectCanonical {α : Type}
    (label original : String)
    (decodeInner : String → Option α)
    (encodeInner : α → Option String) : IO Unit := do
  let value ← requireSome (decodeInner original)
    ("inner decoder rejected " ++ label)
  let encoded ← requireSome (encodeInner value)
    ("inner encoder rejected decoded " ++ label)
  expect (encoded == original)
    ("inner canonical round-trip changed " ++ label)

/--
Re-run every embedded document through the production decoder and encoder.

This is the key experiment law: the outer image owns no household interpretation.
If an inner document is malformed or non-canonical, the combined candidate is
not accepted by this research checkpoint.
-/
def validateCanonical (sections : Sections) : IO Unit := do
  expectCanonical "Actual" sections.actual
    Loam.Persistence.decodeNormalizedActual?
    Loam.Persistence.encodeNormalizedActual?

  expectCanonical "Scheduled" sections.scheduled
    Loam.Persistence.decodeScheduledLifecycleImage?
    Loam.Persistence.encodeScheduledLifecycleImage?

  expectCanonical "Capacity" sections.capacity
    Loam.Persistence.decodeNormalizedCapacity?
    Loam.Persistence.encodeNormalizedCapacity?

  expectCanonical "Attention" sections.attention
    Loam.Persistence.decodeAttentionMemory?
    (fun image => Loam.Persistence.encodeAttentionMemory? image.1 image.2)

  expectCanonical "ActualRouting" sections.actualRouting
    Loam.Persistence.decodeActualRoutingHistory?
    Loam.Persistence.encodeActualRoutingHistory?

  expectCanonical "ScheduledRouting" sections.scheduledRouting
    Loam.Persistence.decodeScheduledRoutingHistory?
    Loam.Persistence.encodeScheduledRoutingHistory?

  expectCanonical "AccountingRole" sections.accountingRole
    Loam.Persistence.decodeAccountingRoleMap?
    Loam.Persistence.encodeAccountingRoleMap?

  expectCanonical "LocusAdmission" sections.locusAdmission
    Loam.Persistence.decodeLocusAdmissionVocabulary?
    Loam.Persistence.encodeLocusAdmissionVocabulary?

  expectCanonical "ZeroOrigin" sections.zeroOrigin
    Loam.Persistence.decodeZeroOriginCoverage?
    Loam.Persistence.encodeZeroOriginCoverage?

  expectCanonical "OpeningSupport" sections.openingSupport
    Loam.Persistence.decodeOpeningSupportMap?
    Loam.Persistence.encodeOpeningSupportMap?

  expectCanonical "CurrentQuantityAnchor" sections.currentQuantityAnchor
    Loam.Persistence.decodeCurrentQuantityAnchor?
    Loam.Persistence.encodeCurrentQuantityAnchor?

  expectCanonical "CurrentQuantityPresence" sections.currentQuantityPresence
    Loam.Persistence.decodeCurrentQuantityPresence?
    Loam.Persistence.encodeCurrentQuantityPresence?

  expectCanonical "BoundedHistorySupport" sections.boundedHistorySupport
    Loam.Persistence.decodeBoundedHistorySupport?
    Loam.Persistence.encodeBoundedHistorySupport?

private def coherentActual : String :=
  String.intercalate "\n" [
    Loam.Persistence.normalizedActualHeaderV1,
    "TX\topening-event\t2026-09-01\tNODESC",
    "EFFECT\tcash\tjpy\t10000",
    "EFFECT\topening-offset\tjpy\t-10000",
    "ENDTX",
    "TX\tspend-event\t2026-10-02\tNODESC",
    "EFFECT\tcash\tjpy\t-2000",
    "EFFECT\tfood\tjpy\t2000",
    "ENDTX"
  ] ++ "\n"

private def coherentScheduled : String :=
  String.intercalate "\n" [
    Loam.Persistence.scheduledLifecycleHeader,
    "BEGIN\tScheduled",
    Loam.Persistence.scheduledMemoryHeader,
    "SCHEDULED\tscheduled-1\t2026-10-20\tjpy",
    "CHANGE\tcash\t-1000",
    "CHANGE\tfood\t1000",
    "END\tScheduled",
    "BEGIN\tCompletion",
    "LOAM-SCHEDULED-COMPLETION-MEMORY\t1",
    "END\tCompletion",
    "BEGIN\tRetirement",
    "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1",
    "END\tRetirement",
    "BEGIN\tReplacement",
    "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1",
    "END\tReplacement"
  ] ++ "\n"

private def coherentSections : Sections := {
  actual := coherentActual
  scheduled := coherentScheduled
  capacity :=
    String.intercalate "\n" [
      Loam.Persistence.normalizedCapacityHeader,
      "MOVEMENT\tcapacity-1\t2026-09-15\tjpy",
      "CHANGE\tUNALLOCATED\t-5000",
      "CHANGE\tPURPOSE\tfood-budget\t5000",
      "ENDMOVEMENT"
    ] ++ "\n"
  attention :=
    String.intercalate "\n" [
      Loam.Persistence.attentionMemoryHeader,
      "ITEM\tattention-1\tDUE_ON\t2026-10-31\trenew-insurance"
    ] ++ "\n"
  actualRouting :=
    String.intercalate "\n" [
      Loam.Persistence.actualRoutingHeader,
      "ROUTE\tfood\tINITIAL\tMANAGED\tfood-budget"
    ] ++ "\n"
  scheduledRouting :=
    String.intercalate "\n" [
      Loam.Persistence.scheduledRoutingHeader,
      "ROUTE\tscheduled-1\tfood\tFROM\t2026-10-01\tMANAGED\tfood-budget"
    ] ++ "\n"
  accountingRole :=
    String.intercalate "\n" [
      "LOAM-ACCOUNTING-ROLE-MAP\t1",
      "ROLE\tcash\tASSET",
      "ROLE\topening-offset\tEQUITY",
      "ROLE\tfood\tEXPENSE",
      "ROLE\tsavings\tASSET",
      "ROLE\tdebt\tLIABILITY"
    ] ++ "\n"
  locusAdmission :=
    String.intercalate "\n" [
      Loam.Persistence.locusAdmissionVocabularyHeader,
      "LOCUS\tcash",
      "LOCUS\topening-offset",
      "LOCUS\tfood",
      "LOCUS\tsavings",
      "LOCUS\tdebt"
    ] ++ "\n"
  zeroOrigin :=
    String.intercalate "\n" [
      Loam.Persistence.zeroOriginCoverageHeader,
      "COORDINATE\tfood\tjpy"
    ] ++ "\n"
  openingSupport :=
    String.intercalate "\n" [
      "LOAM-OPENING-SUPPORT\t1",
      "OPENING\tcash\tjpy\topening-event"
    ] ++ "\n"
  currentQuantityAnchor :=
    String.intercalate "\n" [
      "LOAM-CURRENT-QUANTITY-ANCHOR\t2",
      "GROUP",
      "ROOT\topening-event",
      "ROOT\tspend-event",
      "ASSERT\tsavings\tjpy\t3000",
      "END"
    ] ++ "\n"
  currentQuantityPresence :=
    String.intercalate "\n" [
      "LOAM-CURRENT-QUANTITY-PRESENCE\t1",
      "ROOT\topening-event",
      "ROOT\tspend-event",
      "PRESENT\tdebt\tjpy"
    ] ++ "\n"
  boundedHistorySupport :=
    String.intercalate "\n" [
      Loam.Persistence.boundedHistorySupportHeader,
      "SUPPORT\tsavings\tjpy\t2026-09-01"
    ] ++ "\n"
}

private def payloadChars (sections : Sections) : Nat :=
  [
    sections.actual,
    sections.scheduled,
    sections.capacity,
    sections.attention,
    sections.actualRouting,
    sections.scheduledRouting,
    sections.accountingRole,
    sections.locusAdmission,
    sections.zeroOrigin,
    sections.openingSupport,
    sections.currentQuantityAnchor,
    sections.currentQuantityPresence,
    sections.boundedHistorySupport
  ].foldl (fun total body => total + body.length) 0

private def rowQuantity?
    (snapshot : Loam.CurrentBalanceReview.Snapshot)
    (coordinate : EffectCoordinate) : Option Int :=
  snapshot.rows.find? (fun row => decide (row.coordinate = coordinate))
    |>.map (fun row => row.quantity.quanta)

/--
H1: prove the thirteen non-empty sections describe one mutually usable household
world through existing LOAM application boundaries.

The checks deliberately compose current production semantics rather than adding
cross-family rules to the outer envelope.
-/
private def validateCoherentWorld (sections : Sections) : IO Unit := do
  let actualImage ← requireSome
    (Loam.Persistence.decodeNormalizedActualImage? sections.actual)
    "coherent Actual image"
  let scheduled ← requireSome
    (Loam.Persistence.decodeScheduledLifecycleImage? sections.scheduled)
    "coherent Scheduled lifecycle"
  let capacity ← requireSome
    (Loam.Persistence.decodeNormalizedCapacity? sections.capacity)
    "coherent Capacity"
  let attention ← requireSome
    (Loam.Persistence.decodeAttentionMemory? sections.attention)
    "coherent Attention"
  let actualRouting ← requireSome
    (Loam.Persistence.decodeActualRoutingHistory? sections.actualRouting)
    "coherent Actual routing"
  let scheduledRouting ← requireSome
    (Loam.Persistence.decodeScheduledRoutingHistory? sections.scheduledRouting)
    "coherent Scheduled routing"
  let roles ← requireSome
    (Loam.Persistence.decodeAccountingRoleMap? sections.accountingRole)
    "coherent AccountingRole"
  let locusAdmission ← requireSome
    (Loam.Persistence.decodeLocusAdmissionVocabulary? sections.locusAdmission)
    "coherent Locus admission"
  let zeroOrigin ← requireSome
    (Loam.Persistence.decodeZeroOriginCoverage? sections.zeroOrigin)
    "coherent zero-origin coverage"
  let openingSupport ← requireSome
    (Loam.Persistence.decodeOpeningSupportMap? sections.openingSupport)
    "coherent opening support"
  let anchor ← requireSome
    (Loam.Persistence.decodeCurrentQuantityAnchor? sections.currentQuantityAnchor)
    "coherent current quantity anchor"
  let presence ← requireSome
    (Loam.Persistence.decodeCurrentQuantityPresence? sections.currentQuantityPresence)
    "coherent current quantity presence"
  let bounded ← requireSome
    (Loam.Persistence.decodeBoundedHistorySupport? sections.boundedHistorySupport)
    "coherent bounded historical support"

  expect (!actualImage.evidence.events.events.isEmpty) "Actual evidence was empty"
  expect (!scheduled.scheduled.occurrences.isEmpty) "Scheduled evidence was empty"
  expect (!capacity.movements.movements.isEmpty) "Capacity evidence was empty"
  expect (!attention.1.items.isEmpty) "Attention evidence was empty"
  expect (!actualRouting.entries.isEmpty) "Actual routing evidence was empty"
  expect (!scheduledRouting.entries.isEmpty) "Scheduled routing evidence was empty"
  expect (!roles.assignments.isEmpty) "AccountingRole evidence was empty"
  expect (!locusAdmission.approved.isEmpty) "Locus admission evidence was empty"
  expect (!zeroOrigin.coordinates.isEmpty) "zero-origin evidence was empty"
  expect (!openingSupport.supports.isEmpty) "opening support evidence was empty"
  expect (!anchor.assertions.isEmpty) "current quantity anchor evidence was empty"
  expect (!presence.coordinates.isEmpty) "current quantity presence evidence was empty"
  expect (!bounded.supports.isEmpty) "bounded history evidence was empty"

  for assignment in roles.assignments do
    expect (locusAdmission.allows assignment.locus)
      ("role Locus was not admitted: " ++ assignment.locus.token)

  for entry in actualRouting.entries do
    expect (locusAdmission.allows entry.subject)
      ("Actual routing Locus was not admitted: " ++ entry.subject.token)

  for entry in scheduledRouting.entries do
    expect (locusAdmission.allows entry.subject.locus)
      ("Scheduled routing Locus was not admitted: " ++ entry.subject.locus.token)
    expect
      ((ScheduledMemory.findById? scheduled.scheduled entry.subject.scheduled).isSome)
      ("Scheduled routing referenced missing occurrence: " ++ entry.subject.scheduled.token)

  let currentBalances ← requireOk
    (Loam.CurrentBalanceReview.projectImage
      actualImage zeroOrigin openingSupport anchor presence)
    "coherent current-balance composition"

  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let food : EffectCoordinate := ⟨⟨"food"⟩, ⟨"jpy"⟩⟩
  let savings : EffectCoordinate := ⟨⟨"savings"⟩, ⟨"jpy"⟩⟩
  let debt : EffectCoordinate := ⟨⟨"debt"⟩, ⟨"jpy"⟩⟩

  expect (rowQuantity? currentBalances cash == some 8000)
    "opening-supported cash did not resolve to 8000"
  expect (rowQuantity? currentBalances food == some 2000)
    "zero-origin food did not resolve to 2000"
  expect (rowQuantity? currentBalances savings == some 3000)
    "anchored savings did not resolve to 3000"
  expect (currentBalances.knownPresent.contains debt)
    "amount-unknown debt did not remain known-present"

  let proposedBounded ← requireOk
    (Loam.BoundedHistorySupportPublisher.propose?
      actualImage locusAdmission anchor Loam.BoundedHistorySupport.Evidence.empty {
        coordinate := savings
        startDay := some "2026-09-01"
      })
    "bounded support proposal"
  expect (decide (proposedBounded = bounded))
    "bounded-history section was not admitted by the production proposal law"

  let commitment ← requireSome
    (Loam.Application.currentScheduledCommitment?
      scheduled.scheduled scheduled.terminals actualImage.evidence.events
      roles scheduledRouting ⟨"food-budget"⟩ ⟨"jpy"⟩
      "2026-10-04" "2026-11-01")
    "current Scheduled commitment"
  expect (commitment.managed.quanta == 1000)
    "Scheduled managed commitment was not 1000"
  expect (commitment.unmanaged.quanta == 0)
    "coherent Scheduled world unexpectedly had unmanaged pressure"
  expect (commitment.unrouted.quanta == 0)
    "coherent Scheduled world unexpectedly had unrouted pressure"
  expect (commitment.unresolvedEligibility.quanta == 0)
    "coherent Scheduled world unexpectedly had unresolved eligibility"

  let coverage ← requireSome
    (Loam.Application.currentCoverageAtCorrectionFrontierEffectiveRoutingWithCommitment?
      capacity.movements capacity.effective
      actualImage.evidence.events actualImage.evidence.corrections
      actualImage.currentValidities actualRouting
      ⟨"food-budget"⟩ ⟨"jpy"⟩
      "2026-09-01" "2026-10-04" commitment.managed)
    "current Capacity / Actual coverage"

  expect (coverage.entitlement.quanta == 5000)
    "Capacity entitlement was not 5000"
  expect (coverage.consumption.quanta == 2000)
    "Actual routed consumption was not 2000"
  expect (coverage.remaining.quanta == 3000)
    "Remaining was not 3000"
  expect (coverage.headroom.quanta == 2000)
    "Capacity minus Actual minus Scheduled headroom was not 2000"

def run : IO Unit := do
  validateCanonical coherentSections
  validateCoherentWorld coherentSections

  let wire := encode coherentSections
  let decoded ← requireSome (decode? wire)
    "outer household image decoder rejected coherent household"

  expect (decoded == coherentSections)
    "outer household image round-trip changed one or more inner documents"

  validateCanonical decoded
  validateCoherentWorld decoded

  let truncated := (wire.dropEnd 1).toString
  expect (decode? truncated).isNone
    "truncated household image was accepted"

  let badHeader := "LOAM-HOUSEHOLD-IMAGE\t999\n" ++
    (wire.drop (householdImageHeader.length + 1)).toString
  expect (decode? badHeader).isNone
    "unknown household image version was accepted"

  let payload := payloadChars coherentSections
  let overhead := wire.length - payload
  IO.println "[ok] canonical inner documents: 13 / 13, all non-empty"
  IO.println "[ok] outer round-trip preserved every inner document exactly"
  IO.println "[ok] current support: cash=8000, food=2000, savings=3000, debt=known-present"
  IO.println "[ok] managed Scheduled commitment: 1000"
  IO.println "[ok] Capacity=5000, Actual consumption=2000, Remaining=3000, Headroom=2000"
  IO.println "[ok] bounded historical support admitted through the production law"
  IO.println "[ok] truncated and unknown-version images fail closed"
  IO.println s!"[info] payload characters: {payload}"
  IO.println s!"[info] outer framing characters: {overhead}"
  IO.println "[result] one physical image preserved one coherent thirteen-authority household world"

end Loam.HouseholdImageExperiment

def main : IO Unit :=
  Loam.HouseholdImageExperiment.run
