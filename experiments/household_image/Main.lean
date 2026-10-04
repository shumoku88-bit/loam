import Loam.Application.CurrentCoverageInspection
import Loam.Authority.ActualAuthority
import Loam.HouseholdPaths
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
import Loam.Persistence.WriterOwnership
import Loam.Publisher.BoundedHistorySupportPublisher
import Loam.Review.AccountingRoleReview
import Loam.Review.ActualRoutingReview
import Loam.Review.AttentionReview
import Loam.Review.CapacityReview
import Loam.Review.CurrentBalanceReview
import Loam.Review.CurrentCoverageReview
import Loam.Review.RoleBalanceReview

set_option autoImplicit false

namespace Loam.HouseholdImageExperiment

open Loam.Core

/--
Research-only typed view of the thirteen household authority sections currently
under experiment.

This view is intentionally separate from the outer Image container. A future
binary may know more part names while an older generic container can still
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

The outer container owns only part identity, uniqueness, framing, and exact
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
  | part :: rest =>
      !(rest.any fun later => later.name == part.name) &&
        uniqueSectionNames rest

private def encodeSection (part : Section) : String :=
  "SECTION\t" ++ part.name ++ "\t" ++ toString part.body.length ++
    "\n" ++ part.body

/--
Encode one extensible outer image while leaving every part payload
byte-for-byte unchanged.

Unknown part names are allowed. Duplicate or syntactically unsafe names are
refused so part identity cannot become ambiguous.
-/
def encode? (image : Image) : Option String := do
  if !uniqueSectionNames image.sections then none
  if !(image.sections.all fun part => validSectionName part.name) then none
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
        let (part, remaining) ← takeSection? input
        if acc.any (fun existing => existing.name == part.name) then
          none
        else
          decodeSections? fuel remaining (part :: acc)

/--
Decode version 2 as a generic ordered part collection.

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

/-- Find one opaque payload by part identity. -/
def findBody? (image : Image) (name : String) : Option String :=
  match image.sections.find? (fun part => part.name == name) with
  | some part => some part.body
  | none => none

/--
Replace one known payload without interpreting or reconstructing any other
part. Unknown sections retain both their body and their position.
-/
def replaceBody? (image : Image) (name body : String) : Option Image :=
  if !(image.sections.any fun part => part.name == name) then
    none
  else
    some {
      sections := image.sections.map fun part =>
        if part.name == name then { part with body := body } else part
    }

/-- Add a new opaque part without changing the outer format version. -/
def appendSection? (image : Image) (part : Section) : Option Image :=
  if !validSectionName part.name ||
      image.sections.any (fun existing => existing.name == part.name) then
    none
  else
    some { sections := image.sections ++ [part] }

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


/-- Materialize the thirteen currently understood canonical documents unchanged. -/
private def writeKnownFiles
    (root : System.FilePath)
    (sections : Sections) : IO Unit := do
  IO.FS.createDirAll root
  IO.FS.writeFile (Loam.HouseholdPaths.actual root) sections.actual
  IO.FS.writeFile (Loam.HouseholdPaths.scheduled root) sections.scheduled
  IO.FS.writeFile (Loam.HouseholdPaths.capacity root) sections.capacity
  IO.FS.writeFile (Loam.HouseholdPaths.attention root) sections.attention
  IO.FS.writeFile (Loam.HouseholdPaths.actualRouting root) sections.actualRouting
  IO.FS.writeFile (Loam.HouseholdPaths.scheduledRouting root) sections.scheduledRouting
  IO.FS.writeFile (Loam.HouseholdPaths.accountingRole root) sections.accountingRole
  IO.FS.writeFile (Loam.HouseholdPaths.locusAdmission root) sections.locusAdmission
  IO.FS.writeFile (Loam.HouseholdPaths.zeroOriginCoverage root) sections.zeroOrigin
  IO.FS.writeFile (Loam.HouseholdPaths.openingSupport root) sections.openingSupport
  IO.FS.writeFile (Loam.HouseholdPaths.currentQuantityAnchor root) sections.currentQuantityAnchor
  IO.FS.writeFile (Loam.HouseholdPaths.currentQuantityPresence root) sections.currentQuantityPresence
  IO.FS.writeFile (Loam.HouseholdPaths.boundedHistorySupport root) sections.boundedHistorySupport

private def cleanupDir (root : System.FilePath) : IO Unit := do
  if ← root.pathExists then
    IO.FS.removeDirAll root

private def scheduledOpenIdsFromFiles
    (root : System.FilePath) : IO (Except String (List ScheduledId)) := do
  let actual ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let some scheduled ←
    Loam.Persistence.loadScheduledLifecycleImage? (Loam.HouseholdPaths.scheduled root)
    | return .error "H2: Scheduled lifecycle did not load"
  match Loam.Application.currentOpenScheduled
      scheduled.scheduled scheduled.terminals actual.evidence.events with
  | .open occurrences => return .ok (occurrences.map ScheduledOccurrence.id)
  | _ => return .error "H2: current Scheduled state was not open"

private def attentionSummariesFromFiles
    (root : System.FilePath) : IO (Except String (List String)) := do
  match ← Loam.AttentionReview.loadEvidence (Loam.HouseholdPaths.attention root) with
  | .error message => return .error message
  | .ok .unavailable => return .error "H2: Attention became unavailable"
  | .ok (.available snapshot) =>
      return .ok (snapshot.openItems.map Loam.AttentionReview.summary)

/--
H2: compare production read answers from an ordinary authority directory with
the same canonical documents recovered from one HouseholdImage.

The Review boundaries are not taught about HouseholdImage. The experiment only
materializes the known opaque payloads under their established filenames, then
calls the existing production readers unchanged.
-/
private def validateReviewEquivalence
    (ordinaryRoot imageRoot : System.FilePath)
    (image : Image) : IO Unit := do
  let recovered ← requireSome (knownSections? image)
    "H2: known sections unavailable from HouseholdImage"

  cleanupDir ordinaryRoot
  cleanupDir imageRoot
  writeKnownFiles ordinaryRoot coherentSections
  writeKnownFiles imageRoot recovered

  let ordinaryActual ← requireOk
    (← Loam.ActualAuthority.loadImage? ordinaryRoot)
    "H2 ordinary Actual"
  let imageActual ← requireOk
    (← Loam.ActualAuthority.loadImage? imageRoot)
    "H2 HouseholdImage Actual"
  let ordinaryActualCanonical ← requireSome
    (Loam.Persistence.encodeNormalizedActual? ordinaryActual.evidence)
    "H2 ordinary Actual canonical encoding"
  let imageActualCanonical ← requireSome
    (Loam.Persistence.encodeNormalizedActual? imageActual.evidence)
    "H2 HouseholdImage Actual canonical encoding"
  expect (ordinaryActualCanonical == imageActualCanonical)
    "H2 Actual evidence changed across storage topology"
  expect
    (ordinaryActual.currentEvents.events.map Event.id ==
      imageActual.currentEvents.events.map Event.id)
    "H2 current Actual frontier changed across storage topology"

  let ordinaryBalances ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot ordinaryRoot ordinaryRoot)
    "H2 ordinary current balances"
  let imageBalances ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot imageRoot imageRoot)
    "H2 HouseholdImage current balances"
  expect (decide (ordinaryBalances = imageBalances))
    "H2 CurrentBalanceReview answer changed across storage topology"

  let ordinaryRoleBalances ← requireOk
    (← Loam.RoleBalanceReview.loadSnapshot ordinaryRoot ordinaryRoot)
    "H2 ordinary role balances"
  let imageRoleBalances ← requireOk
    (← Loam.RoleBalanceReview.loadSnapshot imageRoot imageRoot)
    "H2 HouseholdImage role balances"
  expect (decide (ordinaryRoleBalances = imageRoleBalances))
    "H2 RoleBalanceReview answer changed across storage topology"

  let ordinaryCapacity ← requireOk
    (← Loam.CapacityReview.loadSnapshot (Loam.HouseholdPaths.capacity ordinaryRoot))
    "H2 ordinary Capacity"
  let imageCapacity ← requireOk
    (← Loam.CapacityReview.loadSnapshot (Loam.HouseholdPaths.capacity imageRoot))
    "H2 HouseholdImage Capacity"
  expect (decide (ordinaryCapacity = imageCapacity))
    "H2 CapacityReview answer changed across storage topology"

  let ordinaryAttention ← requireOk
    (← attentionSummariesFromFiles ordinaryRoot)
    "H2 ordinary Attention"
  let imageAttention ← requireOk
    (← attentionSummariesFromFiles imageRoot)
    "H2 HouseholdImage Attention"
  expect (ordinaryAttention == imageAttention)
    "H2 AttentionReview answer changed across storage topology"

  let ordinaryScheduled ← requireOk
    (← scheduledOpenIdsFromFiles ordinaryRoot)
    "H2 ordinary Scheduled"
  let imageScheduled ← requireOk
    (← scheduledOpenIdsFromFiles imageRoot)
    "H2 HouseholdImage Scheduled"
  expect (ordinaryScheduled == imageScheduled)
    "H2 current Scheduled answer changed across storage topology"

  let ordinaryRouting ← requireOk
    (← Loam.ActualRoutingReview.loadSnapshot ordinaryRoot ordinaryRoot "2026-10-04")
    "H2 ordinary Actual routing"
  let imageRouting ← requireOk
    (← Loam.ActualRoutingReview.loadSnapshot imageRoot imageRoot "2026-10-04")
    "H2 HouseholdImage Actual routing"
  expect (decide (ordinaryRouting = imageRouting))
    "H2 ActualRoutingReview answer changed across storage topology"

  let ordinaryRoleCandidates ← requireOk
    (← Loam.AccountingRoleReview.loadInitialCandidates ordinaryRoot ordinaryRoot)
    "H2 ordinary AccountingRole candidates"
  let imageRoleCandidates ← requireOk
    (← Loam.AccountingRoleReview.loadInitialCandidates imageRoot imageRoot)
    "H2 HouseholdImage AccountingRole candidates"
  expect (ordinaryRoleCandidates == imageRoleCandidates)
    "H2 AccountingRoleReview answer changed across storage topology"

  let ordinaryCoverage ← requireOk
    (← Loam.CurrentCoverageReview.loadSnapshotAt
      ordinaryRoot ordinaryRoot "2026-09-01" "2026-10-04" "2026-11-01")
    "H2 ordinary current coverage"
  let imageCoverage ← requireOk
    (← Loam.CurrentCoverageReview.loadSnapshotAt
      imageRoot imageRoot "2026-09-01" "2026-10-04" "2026-11-01")
    "H2 HouseholdImage current coverage"
  expect (decide (ordinaryCoverage = imageCoverage))
    "H2 CurrentCoverageReview answer changed across storage topology"

  cleanupDir ordinaryRoot
  cleanupDir imageRoot

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
    "bounded-history part was not admitted by the production proposal law"

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


private def h3UpdatedAttention : String :=
  String.intercalate "\n" [
    Loam.Persistence.attentionMemoryHeader,
    "ITEM\tattention-1\tDUE_ON\t2026-10-31\trenew-insurance",
    "ITEM\tattention-2\tNO_DUE_DATE\t-\tcheck-future-refund"
  ] ++ "\n"

/--
Synthetic canonical Actual text for the H3 write-amplification benchmark.

Generation is deliberately outside the timed publication windows. Every Event is
balanced, has one real occurrence date, and uses only the ordinary normalized V1
shape. H3 measures HouseholdImage mechanics, not fixture construction.
-/
private def syntheticActual (count : Nat) : String :=
  Loam.Persistence.normalizedActualHeaderV1 ++ "\n" ++
    String.join ((List.range count).map fun i =>
      "TX\tbench-" ++ toString i ++ "\t2026-10-01\tNODESC\n" ++
      "EFFECT\tcash\tjpy\t-1\n" ++
      "EFFECT\tfood\tjpy\t1\n" ++
      "ENDTX\n")

private def h3Sections (count : Nat) : Sections :=
  { coherentSections with actual := syntheticActual count }

/--
Decode every known inner family once without re-encoding it.

This models the conservative upper-bound reopen path for a single HouseholdImage:
all retained semantic families are re-admitted after the outer file is read.
-/
private def validateDecodable (sections : Sections) : IO Unit := do
  let _ ← requireSome
    (Loam.Persistence.decodeNormalizedActual? sections.actual)
    "H3 Actual decode"
  let _ ← requireSome
    (Loam.Persistence.decodeScheduledLifecycleImage? sections.scheduled)
    "H3 Scheduled decode"
  let _ ← requireSome
    (Loam.Persistence.decodeNormalizedCapacity? sections.capacity)
    "H3 Capacity decode"
  let _ ← requireSome
    (Loam.Persistence.decodeAttentionMemory? sections.attention)
    "H3 Attention decode"
  let _ ← requireSome
    (Loam.Persistence.decodeActualRoutingHistory? sections.actualRouting)
    "H3 Actual routing decode"
  let _ ← requireSome
    (Loam.Persistence.decodeScheduledRoutingHistory? sections.scheduledRouting)
    "H3 Scheduled routing decode"
  let _ ← requireSome
    (Loam.Persistence.decodeAccountingRoleMap? sections.accountingRole)
    "H3 AccountingRole decode"
  let _ ← requireSome
    (Loam.Persistence.decodeLocusAdmissionVocabulary? sections.locusAdmission)
    "H3 Locus admission decode"
  let _ ← requireSome
    (Loam.Persistence.decodeZeroOriginCoverage? sections.zeroOrigin)
    "H3 zero-origin decode"
  let _ ← requireSome
    (Loam.Persistence.decodeOpeningSupportMap? sections.openingSupport)
    "H3 opening support decode"
  let _ ← requireSome
    (Loam.Persistence.decodeCurrentQuantityAnchor? sections.currentQuantityAnchor)
    "H3 current quantity anchor decode"
  let _ ← requireSome
    (Loam.Persistence.decodeCurrentQuantityPresence? sections.currentQuantityPresence)
    "H3 current quantity presence decode"
  let _ ← requireSome
    (Loam.Persistence.decodeBoundedHistorySupport? sections.boundedHistorySupport)
    "H3 bounded history decode"
  pure ()

private def replaceViaStage
    (path : System.FilePath)
    (text : String) : IO Unit := do
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  IO.FS.rename stage path

private def timedNs (action : IO Unit) : IO Nat := do
  let started ← IO.monoNanosNow
  action
  let finished ← IO.monoNanosNow
  pure (finished - started)

private def average3Ns (action : IO Unit) : IO Nat := do
  let a ← timedNs action
  let b ← timedNs action
  let c ← timedNs action
  pure ((a + b + c) / 3)

private def nsToMs (value : Nat) : Float :=
  value.toFloat / 1000000.0

private structure H3Result where
  events : Nat
  imageChars : Nat
  splitAttentionChars : Nat
  splitPublishNs : Nat
  wholePublishNs : Nat
  selectiveReopenNs : Nat
  fullReopenNs : Nat

private def h3ResultLine (result : H3Result) : String :=
  "[h3] events=" ++ toString result.events ++
    " image_chars=" ++ toString result.imageChars ++
    " split_attention_chars=" ++ toString result.splitAttentionChars ++
    " split_publish_ms=" ++ toString (nsToMs result.splitPublishNs) ++
    " whole_publish_ms=" ++ toString (nsToMs result.wholePublishNs) ++
    " selective_reopen_ms=" ++ toString (nsToMs result.selectiveReopenNs) ++
    " full_reopen_ms=" ++ toString (nsToMs result.fullReopenNs)

private def benchmarkPublicationCost
    (root : System.FilePath)
    (count : Nat) : IO H3Result := do
  cleanupDir root
  IO.FS.createDirAll root

  let sections := h3Sections count
  -- Untimed qualification: the generated large Actual must be a real canonical
  -- document before its bytes are allowed into the benchmark.
  let decodedActual ← requireSome
    (Loam.Persistence.decodeNormalizedActual? sections.actual)
    ("H3 synthetic Actual rejected at " ++ toString count ++ " Events")
  let canonicalActual ← requireSome
    (Loam.Persistence.encodeNormalizedActual? decodedActual)
    ("H3 synthetic Actual could not re-encode at " ++ toString count ++ " Events")
  expect (canonicalActual == sections.actual)
    ("H3 synthetic Actual was not canonical at " ++ toString count ++ " Events")

  let futureBody :=
    "LOAM-SECURITIES\t1\nPOSITION\tglobal-index\t42\nNOTE\tfuture opaque evidence\n"
  let base ← requireSome
    (appendSection? (imageFromKnown sections)
      { name := "Securities", body := futureBody })
    "H3 future section append"
  let candidate ← requireSome
    (replaceBody? base "Attention" h3UpdatedAttention)
    "H3 Attention replacement"
  let candidateWire ← requireSome (encode? candidate)
    "H3 HouseholdImage encoding"

  let attentionPair ← requireSome
    (Loam.Persistence.decodeAttentionMemory? h3UpdatedAttention)
    "H3 split Attention fixture"

  let splitPath := root / "attention.loam"
  let imagePath := root / "household.loam"

  let splitPublish : IO Unit := do
    let ok ← Loam.Persistence.saveAttentionMemory?
      splitPath attentionPair.1 attentionPair.2
    expect ok "H3 split Attention publication failed"

  let wholePublish : IO Unit := do
    let current ← requireSome
      (replaceBody? base "Attention" h3UpdatedAttention)
      "H3 timed Attention replacement"
    let wire ← requireSome (encode? current)
      "H3 timed HouseholdImage encoding"
    replaceViaStage imagePath wire

  let selectiveReopen : IO Unit := do
    let staged ← IO.FS.readFile imagePath
    let reopened ← requireSome (decode? staged)
      "H3 selective outer decode"
    expect (reopened == candidate)
      "H3 selective reopen changed the intended generation"
    let attention ← requireSome (findBody? reopened "Attention")
      "H3 selective Attention section"
    let _ ← requireSome
      (Loam.Persistence.decodeAttentionMemory? attention)
      "H3 selective Attention decode"
    pure ()

  let fullReopen : IO Unit := do
    let staged ← IO.FS.readFile imagePath
    let reopened ← requireSome (decode? staged)
      "H3 full outer decode"
    expect (reopened == candidate)
      "H3 full reopen changed the intended generation"
    let known ← requireSome (knownSections? reopened)
      "H3 full known-section projection"
    validateDecodable known

  -- Warm filesystem/runtime paths before the three measured repetitions.
  splitPublish
  wholePublish
  selectiveReopen
  fullReopen

  let splitPublishNs ← average3Ns splitPublish
  let wholePublishNs ← average3Ns wholePublish
  let selectiveReopenNs ← average3Ns selectiveReopen
  let fullReopenNs ← average3Ns fullReopen

  cleanupDir root

  pure {
    events := count
    imageChars := candidateWire.length
    splitAttentionChars := h3UpdatedAttention.length
    splitPublishNs := splitPublishNs
    wholePublishNs := wholePublishNs
    selectiveReopenNs := selectiveReopenNs
    fullReopenNs := fullReopenNs
  }

def runH3 : IO Unit := do
  let root := System.FilePath.mk ".household-image-h3"
  let mut results : List H3Result := []
  for count in [1000, 10000, 100000] do
    let result ← benchmarkPublicationCost root count
    results := results ++ [result]
    IO.println (h3ResultLine result)

  let some largest := results.getLast?
    | throw <| IO.userError "H3 benchmark produced no results"

  IO.println "[ok] H3 compared current split Attention publication with whole-image publication"
  IO.println "[ok] H3 measured selective reopen separately from conservative full semantic reopen"
  IO.println s!"[info] H3 largest synthetic Actual: {largest.events} Events / {largest.imageChars} image characters"
  IO.println "[result] H3 publication cost measured; interpret the CI numbers before production promotion"


private def householdPath (root : System.FilePath) : System.FilePath :=
  root / "household.loam"

private def householdStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

private def householdPreviousPath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".prev")

private def householdPreviousStagePath (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".prev.loam-stage")

private def h4AttentionB : String :=
  String.intercalate "\n" [
    Loam.Persistence.attentionMemoryHeader,
    "ITEM\tattention-1\tDUE_ON\t2026-10-31\trenew-insurance",
    "ITEM\tattention-2\tNO_DUE_DATE\t-\tcheck-future-refund"
  ] ++ "\n"

private def h4AttentionC : String :=
  String.intercalate "\n" [
    Loam.Persistence.attentionMemoryHeader,
    "ITEM\tattention-1\tDUE_ON\t2026-10-31\trenew-insurance",
    "ITEM\tattention-3\tDUE_UNDETERMINED\t-\tfuture-follow-up"
  ] ++ "\n"

private def decodableKnownSections (sections : Sections) : Bool :=
  (Loam.Persistence.decodeNormalizedActual? sections.actual).isSome &&
  (Loam.Persistence.decodeScheduledLifecycleImage? sections.scheduled).isSome &&
  (Loam.Persistence.decodeNormalizedCapacity? sections.capacity).isSome &&
  (Loam.Persistence.decodeAttentionMemory? sections.attention).isSome &&
  (Loam.Persistence.decodeActualRoutingHistory? sections.actualRouting).isSome &&
  (Loam.Persistence.decodeScheduledRoutingHistory? sections.scheduledRouting).isSome &&
  (Loam.Persistence.decodeAccountingRoleMap? sections.accountingRole).isSome &&
  (Loam.Persistence.decodeLocusAdmissionVocabulary? sections.locusAdmission).isSome &&
  (Loam.Persistence.decodeZeroOriginCoverage? sections.zeroOrigin).isSome &&
  (Loam.Persistence.decodeOpeningSupportMap? sections.openingSupport).isSome &&
  (Loam.Persistence.decodeCurrentQuantityAnchor? sections.currentQuantityAnchor).isSome &&
  (Loam.Persistence.decodeCurrentQuantityPresence? sections.currentQuantityPresence).isSome &&
  (Loam.Persistence.decodeBoundedHistorySupport? sections.boundedHistorySupport).isSome

private def fullyDecodableImage? (wire : String) : Option Image := do
  let image ← decode? wire
  let known ← knownSections? image
  if decodableKnownSections known then some image else none

private def unchangedExceptAttention (base candidate : Image) : Bool :=
  base.sections.length == candidate.sections.length &&
    (base.sections.zip candidate.sections).all fun pair =>
      pair.1.name == pair.2.name &&
        (if pair.1.name == "Attention" then true else pair.1.body == pair.2.body)

private def validateAttentionTransition
    (base candidate : Image) : Except String Unit := do
  if !unchangedExceptAttention base candidate then
    throw "H4: a supposedly Attention-only transition changed another section"
  let before ←
    match findBody? base "Attention" with
    | some body => pure body
    | none => throw "H4: base image has no Attention section"
  let after ←
    match findBody? candidate "Attention" with
    | some body => pure body
    | none => throw "H4: candidate image has no Attention section"
  if before == after then
    throw "H4: Attention-only transition did not change Attention"
  let pair ←
    match Loam.Persistence.decodeAttentionMemory? after with
    | some pair => pure pair
    | none => throw "H4: changed Attention section is malformed"
  let canonical ←
    match Loam.Persistence.encodeAttentionMemory? pair.1 pair.2 with
    | some text => pure text
    | none => throw "H4: changed Attention section cannot be canonically encoded"
  if canonical != after then
    throw "H4: changed Attention section is not canonical"
  pure ()

/--
Research candidate for one selective HouseholdImage publication.

The caller supplies the exact admitted bytes it observed. Ownership is acquired
before the current authority is re-read; a byte mismatch rejects a stale writer.
Only Attention may change. Untouched known and unknown sections must remain
byte-identical.

The old current image is first staged and atomically installed as the previous
generation. Only then is the already-validated candidate atomically renamed over
current. If interruption happens before the last rename, current still names the
old complete generation.
-/
private def publishAttentionFromObserved?
    (path : System.FilePath)
    (observedWire newAttention : String) : IO (Except String String) :=
  Loam.WriterOwnership.withOwnership path do
    if !(← path.pathExists) then
      return .error "H4: household authority is missing"
    let currentWire ← IO.FS.readFile path
    if currentWire != observedWire then
      return .error "H4: stale household generation"

    let some base := fullyDecodableImage? currentWire
      | return .error "H4: current household generation is malformed"
    let some candidate := replaceBody? base "Attention" newAttention
      | return .error "H4: current household generation has no Attention section"

    match validateAttentionTransition base candidate with
    | .error message => return .error message
    | .ok () => pure ()

    let some candidateWire := encode? candidate
      | return .error "H4: candidate household image cannot be encoded"

    let stage := householdStagePath path
    IO.FS.writeFile stage candidateWire
    let stagedWire ← IO.FS.readFile stage
    if stagedWire != candidateWire then
      return .error "H4: staged household bytes differ from candidate"
    let some staged := fullyDecodableImage? stagedWire
      | return .error "H4: staged household image failed typed decoding"
    if staged != candidate then
      return .error "H4: staged household image changed during round-trip"
    match validateAttentionTransition base staged with
    | .error message => return .error message
    | .ok () => pure ()

    let previousStage := householdPreviousStagePath path
    IO.FS.writeFile previousStage currentWire
    let previousStaged ← IO.FS.readFile previousStage
    if previousStaged != currentWire then
      return .error "H4: previous-generation staging mismatch"
    let some _ := fullyDecodableImage? previousStaged
      | return .error "H4: previous generation stopped being decodable"

    IO.FS.rename previousStage (householdPreviousPath path)
    IO.FS.rename stage path
    return .ok candidateWire

inductive H4RecoverySource where
  | current
  | previous
deriving Repr, DecidableEq

structure H4Recovered where
  source : H4RecoverySource
  wire : String
  image : Image
deriving Repr, BEq

/--
Fail closed on an invalid current generation, but expose a fully decoded previous
generation explicitly when one exists. Falling back is observable in the result;
the caller never receives previous evidence disguised as current evidence.
-/
private def loadRecoverable?
    (path : System.FilePath) : IO (Except String H4Recovered) := do
  if ← path.pathExists then
    let wire ← IO.FS.readFile path
    match fullyDecodableImage? wire with
    | some image =>
        return .ok { source := .current, wire := wire, image := image }
    | none => pure ()

  let previous := householdPreviousPath path
  if ← previous.pathExists then
    let wire ← IO.FS.readFile previous
    match fullyDecodableImage? wire with
    | some image =>
        return .ok { source := .previous, wire := wire, image := image }
    | none => pure ()

  return .error "H4: neither current nor previous household generation is usable"

/-- Explicitly restore a qualified previous generation through the same final rename boundary. -/
private def restorePrevious?
    (path : System.FilePath) : IO (Except String Unit) :=
  Loam.WriterOwnership.withOwnership path do
    let previous := householdPreviousPath path
    if !(← previous.pathExists) then
      return .error "H4: previous household generation is missing"
    let previousWire ← IO.FS.readFile previous
    let some _ := fullyDecodableImage? previousWire
      | return .error "H4: previous household generation is malformed"
    let stage := householdStagePath path
    IO.FS.writeFile stage previousWire
    let staged ← IO.FS.readFile stage
    if staged != previousWire then
      return .error "H4: recovery stage mismatch"
    let some _ := fullyDecodableImage? staged
      | return .error "H4: recovery stage failed typed decoding"
    IO.FS.rename stage path
    return .ok ()

private def expectFileBytes
    (path : System.FilePath)
    (expected : String)
    (message : String) : IO Unit := do
  let actual ← IO.FS.readFile path
  expect (actual == expected) message

def runH4 : IO Unit := do
  let root := System.FilePath.mk ".household-image-h4"
  cleanupDir root
  IO.FS.createDirAll root
  let path := householdPath root
  let stage := householdStagePath path
  let previous := householdPreviousPath path
  let previousStage := householdPreviousStagePath path

  let futureBody :=
    "LOAM-SECURITIES\t1\nPOSITION\tglobal-index\t42\nNOTE\tfuture opaque evidence\n"
  let baseImage ← requireSome
    (appendSection? (imageFromKnown coherentSections)
      { name := "Securities", body := futureBody })
    "H4 base future section"
  let baseWire ← requireSome (encode? baseImage)
    "H4 base image encoding"
  let some _ := fullyDecodableImage? baseWire
    | throw <| IO.userError "H4 base image was not fully decodable"
  IO.FS.writeFile path baseWire

  -- A. Partial/corrupt stage must not affect current.
  IO.FS.writeFile stage "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tAttention\t999\npartial"
  expectFileBytes path baseWire
    "H4 A: partial stage changed current household generation"
  IO.println "[h4-ok] partial stage left current generation intact"

  -- B. A complete valid candidate sitting pre-rename is still inert.
  let candidateB ← requireSome
    (replaceBody? baseImage "Attention" h4AttentionB)
    "H4 candidate B"
  let candidateBWire ← requireSome (encode? candidateB)
    "H4 candidate B encoding"
  IO.FS.writeFile stage candidateBWire
  expectFileBytes path baseWire
    "H4 B: completed pre-rename stage changed current generation"
  IO.println "[h4-ok] complete pre-rename stage left current generation intact"

  -- C. Even after previous has switched, interruption before the final rename
  -- leaves current on the old complete generation.
  IO.FS.writeFile previousStage baseWire
  IO.FS.rename previousStage previous
  expectFileBytes previous baseWire
    "H4 C: previous generation did not retain old current"
  expectFileBytes path baseWire
    "H4 C: pre-final-rename interruption changed current"
  IO.println "[h4-ok] previous switch before final rename still left old current intact"

  -- D. Qualified selective publication installs B and retains A as previous.
  let publishedB ← requireOk
    (← publishAttentionFromObserved? path baseWire h4AttentionB)
    "H4 D selective publication"
  expectFileBytes path publishedB
    "H4 D: current did not switch to generation B"
  expectFileBytes previous baseWire
    "H4 D: previous did not retain generation A"
  let some publishedBImage := fullyDecodableImage? publishedB
    | throw <| IO.userError "H4 D: published B was not fully decodable"
  expect (findBody? publishedBImage "Securities" == some futureBody)
    "H4 D: unknown future section was not preserved"
  IO.println "[h4-ok] final rename installed B and retained A as previous"

  -- E. Writer 2 observed A before writer 1 installed B. It must fail stale
  -- after ownership/re-read rather than publishing over B.
  let stale ← publishAttentionFromObserved? path baseWire h4AttentionC
  match stale with
  | .ok _ =>
      throw <| IO.userError "H4 E: stale writer unexpectedly published"
  | .error _ => pure ()
  expectFileBytes path publishedB
    "H4 E: stale writer changed current generation"
  IO.println "[h4-ok] stale observed generation was refused without mutation"

  -- F. Malformed changed semantics must fail before authority replacement.
  let malformedAttention :=
    "LOAM-ATTENTION-MEMORY\t1\nITEM\tbroken\tDUE_ON\t2026-99-99\tbad\n"
  let malformed ← publishAttentionFromObserved? path publishedB malformedAttention
  match malformed with
  | .ok _ =>
      throw <| IO.userError "H4 F: malformed Attention unexpectedly published"
  | .error _ => pure ()
  expectFileBytes path publishedB
    "H4 F: malformed changed section altered current generation"
  IO.println "[h4-ok] malformed changed section failed closed"

  -- G. Whole-current outer corruption is observable and previous is returned
  -- explicitly, never disguised as current.
  IO.FS.writeFile path "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tActual\t999\ntruncated"
  let recoveredOuter ← requireOk
    (← loadRecoverable? path)
    "H4 G outer-corruption recovery read"
  expect (recoveredOuter.source == .previous)
    "H4 G: outer corruption did not select explicit previous generation"
  expect (recoveredOuter.wire == baseWire)
    "H4 G: outer corruption selected unexpected previous bytes"
  let _ ← requireOk (← restorePrevious? path)
    "H4 G restore previous"
  expectFileBytes path baseWire
    "H4 G: explicit restore did not recover A"
  IO.println "[h4-ok] malformed current fell back explicitly to previous and restored"

  -- H. Corruption can preserve valid outer framing while breaking one inner
  -- semantic section. Full recovery qualification must still reject it.
  let badInnerImage ← requireSome
    (replaceBody? baseImage "Attention" malformedAttention)
    "H4 H malformed inner candidate"
  let badInnerWire ← requireSome (encode? badInnerImage)
    "H4 H malformed inner outer encoding"
  expect (decode? badInnerWire).isSome
    "H4 H: test fixture did not preserve valid outer framing"
  expect (fullyDecodableImage? badInnerWire).isNone
    "H4 H: malformed inner section passed full recovery qualification"
  IO.FS.writeFile path badInnerWire
  let recoveredInner ← requireOk
    (← loadRecoverable? path)
    "H4 H inner-corruption recovery read"
  expect (recoveredInner.source == .previous)
    "H4 H: inner corruption did not select explicit previous generation"
  IO.println "[h4-ok] outer-valid but inner-malformed current fell back to previous"

  cleanupDir root

  -- I. Partial migration from the current 13-file topology is inert until one
  -- complete household image is atomically installed. Existing split readers
  -- remain usable throughout this research migration staging.
  let migrationRoot := System.FilePath.mk ".household-image-h4-migration"
  cleanupDir migrationRoot
  writeKnownFiles migrationRoot coherentSections
  let migrationPath := householdPath migrationRoot
  let migrationStage := householdStagePath migrationPath

  let splitBefore ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot migrationRoot migrationRoot)
    "H4 I split review before migration"
  IO.FS.writeFile migrationStage
    "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tActual\t999\npartial-migration"
  expect (!(← migrationPath.pathExists))
    "H4 I: partial migration accidentally created current HouseholdImage"
  let splitDuring ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot migrationRoot migrationRoot)
    "H4 I split review during partial migration"
  expect (decide (splitBefore = splitDuring))
    "H4 I: partial migration changed existing split Review answer"

  IO.FS.writeFile migrationStage baseWire
  let stagedMigration ← IO.FS.readFile migrationStage
  expect ((fullyDecodableImage? stagedMigration).isSome)
    "H4 I: complete migration candidate was not fully decodable"
  IO.FS.rename migrationStage migrationPath
  expectFileBytes migrationPath baseWire
    "H4 I: migration final rename did not install HouseholdImage"
  let splitAfter ← requireOk
    (← Loam.CurrentBalanceReview.loadSnapshot migrationRoot migrationRoot)
    "H4 I split review after image installation"
  expect (decide (splitBefore = splitAfter))
    "H4 I: HouseholdImage installation mutated legacy split evidence"
  cleanupDir migrationRoot
  IO.println "[h4-ok] partial migration remained inert and preserved split Review answers"

  IO.println "[result] H4 selective generation publication survived staged interruption, stale writer, malformed section, recoverable corruption and partial migration"

def run : IO Unit := do
  validateCanonical coherentSections
  validateCoherentWorld coherentSections

  let baseImage := imageFromKnown coherentSections
  let futureBody :=
    "LOAM-SECURITIES\t1\nPOSITION\tglobal-index\t42\nNOTE\t将来の意味論はこの版では未知\n"
  let imageWithFuture ← requireSome
    (appendSection? baseImage { name := "Securities", body := futureBody })
    "future part append"

  let wire ← requireSome (encode? imageWithFuture)
    "extensible household image encoding"
  let decoded ← requireSome (decode? wire)
    "extensible household image decoder rejected coherent household"

  expect (decoded == imageWithFuture)
    "outer image round-trip changed known or unknown sections"

  let decodedKnown ← requireSome (knownSections? decoded)
    "known household sections disappeared behind future part"
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
    "writer that changed one known part lost or changed unknown future evidence"
  expect
    (reopened.sections.map (fun part => part.name) ==
      rewritten.sections.map (fun part => part.name))
    "known-part rewrite changed part ordering"

  let reopenedKnown ← requireSome (knownSections? reopened)
    "known projection failed after preserving unknown future part"
  validateCanonical reopenedKnown
  validateCoherentWorld reopenedKnown


  let ordinaryRoot := System.FilePath.mk ".household-image-h2-ordinary"
  let imageRoot := System.FilePath.mk ".household-image-h2-recovered"
  validateReviewEquivalence ordinaryRoot imageRoot imageWithFuture

  let duplicate : Image := {
    sections := reopened.sections ++
      [{ name := "Securities", body := "duplicate must be refused\n" }]
  }
  expect (encode? duplicate).isNone
    "duplicate part identity was encodable"

  let missingKnown : Image := {
    sections := reopened.sections.filter (fun part => part.name != "Capacity")
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
    reopened.sections.foldl (fun total part => total + part.body.length) 0
  let overhead := rewrittenWire.length - totalPayload

  IO.println "[ok] canonical known documents: 13 / 13, all non-empty"
  IO.println "[ok] extensible outer image accepted an unknown Securities part"
  IO.println "[ok] unknown part survived decode / encode byte-for-byte"
  IO.println "[ok] Attention-only rewrite preserved unknown part bytes and position"
  IO.println "[ok] missing known part and duplicate part identity fail closed"
  IO.println "[ok] current support: cash=8000, food=2000, savings=3000, debt=known-present"
  IO.println "[ok] managed Scheduled commitment: 1000"
  IO.println "[ok] Capacity=5000, Actual consumption=2000, Remaining=3000, Headroom=2000"
  IO.println "[ok] H2 Review equivalence: Actual, CurrentBalance, RoleBalance, Capacity, Attention, Scheduled, ActualRouting, AccountingRole and CurrentCoverage"
  IO.println s!"[info] current-known payload characters: {knownPayload}"
  IO.println s!"[info] total payload characters with future part: {totalPayload}"
  IO.println s!"[info] outer framing characters: {overhead}"
  IO.println "[result] future authority families can be added without changing the outer format or losing unknown evidence"

end Loam.HouseholdImageExperiment

def main (args : List String) : IO Unit :=
  if args.contains "--h4" then
    Loam.HouseholdImageExperiment.runH4
  else if args.contains "--h3" then
    Loam.HouseholdImageExperiment.runH3
  else
    Loam.HouseholdImageExperiment.run
