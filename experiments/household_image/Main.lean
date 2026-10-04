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

set_option autoImplicit false

namespace Loam.HouseholdImageExperiment

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

private def sampleActual : String :=
  String.intercalate "\n" [
    Loam.Persistence.normalizedActualHeaderV1,
    "TX\tevent-grocery\t2026-10-01\tNODESC",
    "EFFECT\twallet\tjpy\t-1000",
    "EFFECT\tfood\tjpy\t1000",
    "ENDTX"
  ] ++ "\n"

private def sampleScheduled : String :=
  String.intercalate "\n" [
    Loam.Persistence.scheduledLifecycleHeader,
    "BEGIN\tScheduled",
    Loam.Persistence.scheduledMemoryHeader,
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

private def sampleSections : Sections := {
  actual := sampleActual
  scheduled := sampleScheduled
  capacity := Loam.Persistence.normalizedCapacityHeader ++ "\n"
  attention := Loam.Persistence.attentionMemoryHeader ++ "\n"
  actualRouting :=
    String.intercalate "\n" [
      Loam.Persistence.actualRoutingHeader,
      "ROUTE\twallet\tINITIAL\tMANAGED\tspending"
    ] ++ "\n"
  scheduledRouting := Loam.Persistence.scheduledRoutingHeader ++ "\n"
  accountingRole :=
    String.intercalate "\n" [
      "LOAM-ACCOUNTING-ROLE-MAP\t1",
      "ROLE\twallet\tASSET",
      "ROLE\tfood\tEXPENSE"
    ] ++ "\n"
  locusAdmission :=
    String.intercalate "\n" [
      Loam.Persistence.locusAdmissionVocabularyHeader,
      "LOCUS\twallet",
      "LOCUS\tfood"
    ] ++ "\n"
  zeroOrigin := Loam.Persistence.zeroOriginCoverageHeader ++ "\n"
  openingSupport := "LOAM-OPENING-SUPPORT\t1\n"
  currentQuantityAnchor := "LOAM-CURRENT-QUANTITY-ANCHOR\t2\n"
  currentQuantityPresence := "LOAM-CURRENT-QUANTITY-PRESENCE\t1\n"
  boundedHistorySupport := Loam.Persistence.boundedHistorySupportHeader ++ "\n"
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

def run : IO Unit := do
  validateCanonical sampleSections

  let wire := encode sampleSections
  let decoded ← requireSome (decode? wire)
    "outer household image decoder rejected encoded sample"

  expect (decoded == sampleSections)
    "outer household image round-trip changed one or more inner documents"

  validateCanonical decoded

  let truncated := (wire.dropEnd 1).toString
  expect (decode? truncated).isNone
    "truncated household image was accepted"

  let badHeader := "LOAM-HOUSEHOLD-IMAGE\t999\n" ++
    (wire.drop (householdImageHeader.length + 1)).toString
  expect (decode? badHeader).isNone
    "unknown household image version was accepted"

  let payload := payloadChars sampleSections
  let overhead := wire.length - payload
  IO.println s!"[ok] canonical inner documents: 13 / 13"
  IO.println s!"[ok] outer round-trip preserved every inner document exactly"
  IO.println s!"[ok] truncated and unknown-version images fail closed"
  IO.println s!"[info] payload characters: {payload}"
  IO.println s!"[info] outer framing characters: {overhead}"
  IO.println "[result] one physical image can wrap current authorities without merging their semantics"

end Loam.HouseholdImageExperiment

def main : IO Unit :=
  Loam.HouseholdImageExperiment.run
