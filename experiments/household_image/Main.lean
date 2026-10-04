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
Research-only typed view of the thirteen household authority sections currently
under experiment.

This view is intentionally separate from the outer Image container. A future
binary may know more section names while an older generic container can still
preserve those unknown payloads byte-for-byte.
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

/-- One opaque named payload in the extensible outer household image. -/
structure Section where
  name : String
  body : String
deriving Repr, BEq

/--
Extensible physical image.

The outer container owns only section identity, uniqueness, framing, and exact
payload preservation. It does not interpret unknown sections.
-/
structure Image where
  sections : List Section
deriving Repr, BEq

def householdImageHeader : String := "LOAM-HOUSEHOLD-IMAGE\t2"

private def validSectionName (name : String) : Bool :=
  !name.isEmpty &&
    !name.contains '\t' &&
    !name.contains '\n' &&
    !name.contains '\r'

private def uniqueSectionNames : List Section → Bool
  | [] => true
  | section :: rest =>
      !(rest.any fun later => later.name == section.name) &&
        uniqueSectionNames rest

private def encodeSection (section : Section) : String :=
  "SECTION\t" ++ section.name ++ "\t" ++ toString section.body.length ++
    "\n" ++ section.body

/--
Encode one extensible outer image while leaving every section payload
byte-for-byte unchanged.

Unknown section names are allowed. Duplicate or syntactically unsafe names are
refused so section identity cannot become ambiguous.
-/
def encode? (image : Image) : Option String := do
  if !uniqueSectionNames image.sections then none
  if !(image.sections.all fun section => validSectionName section.name) then none
  pure <| householdImageHeader ++ "\n" ++
    String.join (image.sections.map encodeSection)

private def takeLine? (input : String) : Option (String × String) :=
  match input.splitOn "\n" with
  | line :: next :: rest =>
      some (line, String.intercalate "\n" (next :: rest))
  | _ => none

private def takeSection? (input : String) : Option (Section × String) := do
  let (line, rest) ← takeLine? input
  match line.splitOn "\t" with
  | ["SECTION", name, lengthText] =>
      if !validSectionName name then
        none
      else do
        let count ← lengthText.toNat?
        if rest.length < count then
          none
        else
          let body := (rest.take count).toString
          let remaining := (rest.drop count).toString
          some ({ name := name, body := body }, remaining)
  | _ => none

private def decodeSections? :
    Nat → String → List Section → Option (List Section)
  | 0, _, _ => none
  | Nat.succ fuel, input, acc =>
      if input.isEmpty then
        some acc.reverse
      else do
        let (section, remaining) ← takeSection? input
        if acc.any (fun existing => existing.name == section.name) then
          none
        else
          decodeSections? fuel remaining (section :: acc)

/--
Decode version 2 as a generic ordered section collection.

No knowledge of the current thirteen semantic families is required at this
boundary. Unknown sections survive decode and later encode unchanged.
-/
def decode? (input : String) : Option Image := do
  let headerPrefix := householdImageHeader ++ "\n"
  if !input.startsWith headerPrefix then
    none
  else
    let rest := (input.drop headerPrefix.length).toString
    let sections ← decodeSections? (rest.length + 1) rest []
    some { sections := sections }

/-- Find one opaque payload by section identity. -/
def findBody? (image : Image) (name : String) : Option String :=
  match image.sections.find? (fun section => section.name == name) with
  | some section => some section.body
  | none => none

/--
Replace one known payload without interpreting or reconstructing any other
section. Unknown sections retain both their body and their position.
-/
def replaceBody? (image : Image) (name body : String) : Option Image :=
  if !(image.sections.any fun section => section.name == name) then
    none
  else
    some {
      sections := image.sections.map fun section =>
        if section.name == name then { section with body := body } else section
    }

/-- Add a new opaque section without changing the outer format version. -/
def appendSection? (image : Image) (section : Section) : Option Image :=
  if !validSectionName section.name ||
      image.sections.any (fun existing => existing.name == section.name) then
    none
  else
    some { sections := image.sections ++ [section] }

/-- Build the extensible outer image from the thirteen semantic families known today. -/
def imageFromKnown (sections : Sections) : Image := {
  sections := [
    { name := "Actual", body := sections.actual },
    { name := "Scheduled", body := sections.scheduled },
    { name := "Capacity", body := sections.capacity },
    { name := "Attention", body := sections.attention },
    { name := "ActualRouting", body := sections.actualRouting },
    { name := "ScheduledRouting", body := sections.scheduledRouting },
    { name := "AccountingRole", body := sections.accountingRole },
    { name := "LocusAdmission", body := sections.locusAdmission },
    { name := "ZeroOrigin", body := sections.zeroOrigin },
    { name := "OpeningSupport", body := sections.openingSupport },
    { name := "CurrentQuantityAnchor", body := sections.currentQuantityAnchor },
    { name := "CurrentQuantityPresence", body := sections.currentQuantityPresence },
    { name := "BoundedHistorySupport", body := sections.boundedHistorySupport }
  ]
}

/--
Project only the semantic families this experiment currently understands.

Additional future sections are ignored by the semantic view but remain retained
inside Image. Missing current sections fail closed instead of being invented as
empty evidence.
-/
def knownSections? (image : Image) : Option Sections := do
  let actual ← findBody? image "Actual"
  let scheduled ← findBody? image "Scheduled"
  let capacity ← findBody? image "Capacity"
  let attention ← findBody? image "Attention"
  let actualRouting ← findBody? image "ActualRouting"
  let scheduledRouting ← findBody? image "ScheduledRouting"
  let accountingRole ← findBody? image "AccountingRole"
  let locusAdmission ← findBody? image "LocusAdmission"
  let zeroOrigin ← findBody? image "ZeroOrigin"
  let openingSupport ← findBody? image "OpeningSupport"
  let currentQuantityAnchor ← findBody? image "CurrentQuantityAnchor"
  let currentQuantityPresence ← findBody? image "CurrentQuantityPresence"
  let boundedHistorySupport ← findBody? image "BoundedHistorySupport"
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

  let baseImage := imageFromKnown coherentSections
  let futureBody :=
    "LOAM-SECURITIES\t1\nPOSITION\tglobal-index\t42\nNOTE\t将来の意味論はこの版では未知\n"
  let imageWithFuture ← requireSome
    (appendSection? baseImage { name := "Securities", body := futureBody })
    "future section append"

  let wire ← requireSome (encode? imageWithFuture)
    "extensible household image encoding"
  let decoded ← requireSome (decode? wire)
    "extensible household image decoder rejected coherent household"

  expect (decoded == imageWithFuture)
    "outer image round-trip changed known or unknown sections"

  let decodedKnown ← requireSome (knownSections? decoded)
    "known household sections disappeared behind future section"
  validateCanonical decodedKnown
  validateCoherentWorld decodedKnown

  let updatedAttention :=
    String.intercalate "\n" [
      Loam.Persistence.attentionMemoryHeader,
      "ITEM\tattention-1\tDUE_ON\t2026-10-31\trenew-insurance",
      "ITEM\tattention-2\tNO_DUE_DATE\t-\tcheck-future-refund"
    ] ++ "\n"

  let rewritten ← requireSome
    (replaceBody? decoded "Attention" updatedAttention)
    "known Attention replacement"
  let rewrittenWire ← requireSome (encode? rewritten)
    "rewritten extensible household image encoding"
  let reopened ← requireSome (decode? rewrittenWire)
    "rewritten extensible household image decoding"

  expect (findBody? reopened "Securities" == some futureBody)
    "writer that changed one known section lost or changed unknown future evidence"
  expect
    (reopened.sections.map (fun section => section.name) ==
      rewritten.sections.map (fun section => section.name))
    "known-section rewrite changed section ordering"

  let reopenedKnown ← requireSome (knownSections? reopened)
    "known projection failed after preserving unknown future section"
  validateCanonical reopenedKnown
  validateCoherentWorld reopenedKnown

  let duplicate : Image := {
    sections := reopened.sections ++
      [{ name := "Securities", body := "duplicate must be refused\n" }]
  }
  expect (encode? duplicate).isNone
    "duplicate section identity was encodable"

  let missingKnown : Image := {
    sections := reopened.sections.filter (fun section => section.name != "Capacity")
  }
  expect (knownSections? missingKnown).isNone
    "missing known authority was silently invented as empty evidence"

  let truncated := (rewrittenWire.dropEnd 1).toString
  expect (decode? truncated).isNone
    "truncated household image was accepted"

  let badHeader := "LOAM-HOUSEHOLD-IMAGE\t999\n" ++
    (rewrittenWire.drop (householdImageHeader.length + 1)).toString
  expect (decode? badHeader).isNone
    "unknown household image version was accepted"

  let knownPayload := payloadChars coherentSections
  let totalPayload :=
    reopened.sections.foldl (fun total section => total + section.body.length) 0
  let overhead := rewrittenWire.length - totalPayload

  IO.println "[ok] canonical known documents: 13 / 13, all non-empty"
  IO.println "[ok] extensible outer image accepted an unknown Securities section"
  IO.println "[ok] unknown section survived decode / encode byte-for-byte"
  IO.println "[ok] Attention-only rewrite preserved unknown section bytes and position"
  IO.println "[ok] missing known section and duplicate section identity fail closed"
  IO.println "[ok] current support: cash=8000, food=2000, savings=3000, debt=known-present"
  IO.println "[ok] managed Scheduled commitment: 1000"
  IO.println "[ok] Capacity=5000, Actual consumption=2000, Remaining=3000, Headroom=2000"
  IO.println s!"[info] current-known payload characters: {knownPayload}"
  IO.println s!"[info] total payload characters with future section: {totalPayload}"
  IO.println s!"[info] outer framing characters: {overhead}"
  IO.println "[result] future authority families can be added without changing the outer format or losing unknown evidence"

end Loam.HouseholdImageExperiment

def main : IO Unit :=
  Loam.HouseholdImageExperiment.run
