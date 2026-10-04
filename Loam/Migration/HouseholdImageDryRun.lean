import Loam.Application.ScheduledInspection
import Loam.Authority.ActualAuthority
import Loam.Authority.HouseholdAuthority
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
import Loam.Review.AccountingRoleReview
import Loam.Review.ActualRoutingReview
import Loam.Review.AttentionReview
import Loam.Review.CapacityReview
import Loam.Review.CurrentBalanceReview
import Loam.Review.CurrentCoverageReview
import Loam.Review.RoleBalanceReview

namespace Loam.HouseholdImageDryRun

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# HouseholdImage dry-run migration

This is an offline admission gate for the future one-file household authority.

It reads the legacy thirteen canonical paths without changing them, preserves
physical absence exactly, builds one HouseholdImage candidate in a separate
scratch directory, reopens and qualifies that candidate, materializes its
present sections back into a temporary legacy-shaped projection, and compares
the same production Review answers used by the HouseholdImage H2 experiment.

It deliberately does not install `household.loam`, does not dual-write, and
does not move configuration into the image.
-/

structure ReviewProbe where
  currentWindowStart : String
  observedAt : String
  endExclusive : String
deriving Repr, BEq

structure Report where
  candidatePath : System.FilePath
  projectionRoot : System.FilePath
  presentSections : List String
  absentSections : List String
  wire : String
deriving Repr

private structure LegacySpec where
  name : String
  path : System.FilePath → System.FilePath
  canonical : String → Bool

private def canonicalRoundTrip? {α : Type}
    (body : String)
    (decode : String → Option α)
    (encode : α → Option String) : Bool :=
  match decode body with
  | none => false
  | some value => encode value == some body

private def legacySpecs : List LegacySpec := [
  {
    name := "Actual"
    path := Loam.HouseholdPaths.actual
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeNormalizedActual?
        Loam.Persistence.encodeNormalizedActual?
  },
  {
    name := "Scheduled"
    path := Loam.HouseholdPaths.scheduled
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeScheduledLifecycleImage?
        Loam.Persistence.encodeScheduledLifecycleImage?
  },
  {
    name := "Capacity"
    path := Loam.HouseholdPaths.capacity
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeNormalizedCapacity?
        Loam.Persistence.encodeNormalizedCapacity?
  },
  {
    name := "Attention"
    path := Loam.HouseholdPaths.attention
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeAttentionMemory?
        (fun image => Loam.Persistence.encodeAttentionMemory? image.1 image.2)
  },
  {
    name := "ActualRouting"
    path := Loam.HouseholdPaths.actualRouting
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeActualRoutingHistory?
        Loam.Persistence.encodeActualRoutingHistory?
  },
  {
    name := "ScheduledRouting"
    path := Loam.HouseholdPaths.scheduledRouting
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeScheduledRoutingHistory?
        Loam.Persistence.encodeScheduledRoutingHistory?
  },
  {
    name := "AccountingRole"
    path := Loam.HouseholdPaths.accountingRole
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeAccountingRoleMap?
        Loam.Persistence.encodeAccountingRoleMap?
  },
  {
    name := "LocusAdmission"
    path := Loam.HouseholdPaths.locusAdmission
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeLocusAdmissionVocabulary?
        Loam.Persistence.encodeLocusAdmissionVocabulary?
  },
  {
    name := "ZeroOrigin"
    path := Loam.HouseholdPaths.zeroOriginCoverage
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeZeroOriginCoverage?
        Loam.Persistence.encodeZeroOriginCoverage?
  },
  {
    name := "OpeningSupport"
    path := Loam.HouseholdPaths.openingSupport
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeOpeningSupportMap?
        Loam.Persistence.encodeOpeningSupportMap?
  },
  {
    name := "CurrentQuantityAnchor"
    path := Loam.HouseholdPaths.currentQuantityAnchor
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeCurrentQuantityAnchor?
        Loam.Persistence.encodeCurrentQuantityAnchor?
  },
  {
    name := "CurrentQuantityPresence"
    path := Loam.HouseholdPaths.currentQuantityPresence
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeCurrentQuantityPresence?
        Loam.Persistence.encodeCurrentQuantityPresence?
  },
  {
    name := "BoundedHistorySupport"
    path := Loam.HouseholdPaths.boundedHistorySupport
    canonical := fun body =>
      canonicalRoundTrip? body
        Loam.Persistence.decodeBoundedHistorySupport?
        Loam.Persistence.encodeBoundedHistorySupport?
  }
]

private def readLegacySections
    (root : System.FilePath) : IO (Except String (List Section)) := do
  let mut sections : List Section := []
  for spec in legacySpecs do
    let source := spec.path root
    if ← source.pathExists then
      let body ← IO.FS.readFile source
      if !spec.canonical body then
        return .error
          ("loam: dry-run migration refused non-canonical " ++ spec.name ++
            " at " ++ source.toString)
      sections := sections ++ [{ name := spec.name, body := body }]
  return .ok sections

private def sectionPath?
    (root : System.FilePath)
    (name : String) : Option System.FilePath :=
  match name with
  | "Actual" => some (Loam.HouseholdPaths.actual root)
  | "Scheduled" => some (Loam.HouseholdPaths.scheduled root)
  | "Capacity" => some (Loam.HouseholdPaths.capacity root)
  | "Attention" => some (Loam.HouseholdPaths.attention root)
  | "ActualRouting" => some (Loam.HouseholdPaths.actualRouting root)
  | "ScheduledRouting" => some (Loam.HouseholdPaths.scheduledRouting root)
  | "AccountingRole" => some (Loam.HouseholdPaths.accountingRole root)
  | "LocusAdmission" => some (Loam.HouseholdPaths.locusAdmission root)
  | "ZeroOrigin" => some (Loam.HouseholdPaths.zeroOriginCoverage root)
  | "OpeningSupport" => some (Loam.HouseholdPaths.openingSupport root)
  | "CurrentQuantityAnchor" => some (Loam.HouseholdPaths.currentQuantityAnchor root)
  | "CurrentQuantityPresence" => some (Loam.HouseholdPaths.currentQuantityPresence root)
  | "BoundedHistorySupport" => some (Loam.HouseholdPaths.boundedHistorySupport root)
  | _ => none

private def materializeLegacyProjection
    (root : System.FilePath)
    (image : Image) : IO (Except String Unit) := do
  IO.FS.createDirAll root
  for part in image.sections do
    let some target := sectionPath? root part.name
      | return .error
          ("loam: dry-run projection encountered unknown section: " ++ part.name)
    IO.FS.writeFile target part.body
  return .ok ()

private def configPairs
    (source target : System.FilePath) :
    List (System.FilePath × System.FilePath) := [
  (Loam.HouseholdPaths.boundaryPresets source,
    Loam.HouseholdPaths.boundaryPresets target),
  (Loam.HouseholdPaths.measurePresentation source,
    Loam.HouseholdPaths.measurePresentation target),
  (Loam.HouseholdPaths.locusCatalog source,
    Loam.HouseholdPaths.locusCatalog target),
  (Loam.HouseholdPaths.purposeCatalog source,
    Loam.HouseholdPaths.purposeCatalog target),
  (Loam.HouseholdPaths.balanceView source,
    Loam.HouseholdPaths.balanceView target),
  (Loam.HouseholdPaths.cycleFunding source,
    Loam.HouseholdPaths.cycleFunding target),
  (Loam.HouseholdPaths.dailyPace source,
    Loam.HouseholdPaths.dailyPace target),
  (Loam.HouseholdPaths.scheduledCoverage source,
    Loam.HouseholdPaths.scheduledCoverage target)
]

private def copyConfigForProjection
    (source target : System.FilePath) : IO Unit := do
  IO.FS.createDirAll (Loam.HouseholdPaths.configDir target)
  for pair in configPairs source target do
    if ← pair.1.pathExists then
      IO.FS.writeFile pair.2 (← IO.FS.readFile pair.1)

private def actualAnswer
    (root : System.FilePath) :
    IO (Except String (String × List EventId)) := do
  match ← Loam.ActualAuthority.loadImage? root with
  | .error message => return .error message
  | .ok image =>
      let some canonical :=
          Loam.Persistence.encodeNormalizedActual? image.evidence
        | return .error "loam: dry-run H2 Actual could not re-encode"
      return .ok
        (canonical, image.currentEvents.events.map Event.id)

private def scheduledAnswer
    (root : System.FilePath) :
    IO (Except String (List ScheduledId)) := do
  let actual ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let some scheduled :=
      Loam.Persistence.loadScheduledLifecycleImage?
        (Loam.HouseholdPaths.scheduled root)
    | return .error "loam: dry-run H2 Scheduled lifecycle unavailable"
  match Loam.Application.currentOpenScheduled
      scheduled.scheduled scheduled.terminals actual.evidence.events with
  | .open occurrences =>
      return .ok (occurrences.map ScheduledOccurrence.id)
  | _ =>
      return .error "loam: dry-run H2 Scheduled current-open answer unavailable"

private def attentionAnswer
    (root : System.FilePath) :
    IO (Except String (Option (List String))) := do
  match ← Loam.AttentionReview.loadEvidence (Loam.HouseholdPaths.attention root) with
  | .error message => return .error message
  | .ok .unavailable => return .ok none
  | .ok (.available snapshot) =>
      return .ok (some (snapshot.openItems.map Loam.AttentionReview.summary))

private def compareExceptBy {α : Type}
    (label : String)
    (same : α → α → Bool)
    (legacy projected : Except String α) : Except String Unit :=
  match legacy, projected with
  | .ok left, .ok right =>
      if same left right then
        .ok ()
      else
        .error ("loam: dry-run H2 Review mismatch: " ++ label)
  | .error _, .error _ => .ok ()
  | .error _, .ok _ =>
      .error
        ("loam: dry-run H2 availability changed from refusal to answer: " ++ label)
  | .ok _, .error _ =>
      .error
        ("loam: dry-run H2 availability changed from answer to refusal: " ++ label)

private def validateReviewEquivalence
    (legacyRoot projectedRoot : System.FilePath)
    (probe : ReviewProbe) : IO (Except String Unit) := do
  let actualLegacy ← actualAnswer legacyRoot
  let actualProjected ← actualAnswer projectedRoot
  match compareExceptBy "Actual"
      (fun left right => decide (left = right))
      actualLegacy actualProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let balancesLegacy ←
    Loam.CurrentBalanceReview.loadSnapshot legacyRoot legacyRoot
  let balancesProjected ←
    Loam.CurrentBalanceReview.loadSnapshot projectedRoot projectedRoot
  match compareExceptBy "CurrentBalanceReview"
      (fun left right => decide (left = right))
      balancesLegacy balancesProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let roleBalancesLegacy ←
    Loam.RoleBalanceReview.loadSnapshot legacyRoot legacyRoot
  let roleBalancesProjected ←
    Loam.RoleBalanceReview.loadSnapshot projectedRoot projectedRoot
  match compareExceptBy "RoleBalanceReview"
      (fun left right => decide (left = right))
      roleBalancesLegacy roleBalancesProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let capacityLegacy ←
    Loam.CapacityReview.loadSnapshot (Loam.HouseholdPaths.capacity legacyRoot)
  let capacityProjected ←
    Loam.CapacityReview.loadSnapshot (Loam.HouseholdPaths.capacity projectedRoot)
  match compareExceptBy "CapacityReview"
      (fun left right => decide (left = right))
      capacityLegacy capacityProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let attentionLegacy ← attentionAnswer legacyRoot
  let attentionProjected ← attentionAnswer projectedRoot
  match compareExceptBy "AttentionReview"
      (fun left right => left == right)
      attentionLegacy attentionProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let scheduledLegacy ← scheduledAnswer legacyRoot
  let scheduledProjected ← scheduledAnswer projectedRoot
  match compareExceptBy "Scheduled"
      (fun left right => left == right)
      scheduledLegacy scheduledProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let routingLegacy ←
    Loam.ActualRoutingReview.loadSnapshot
      legacyRoot legacyRoot probe.observedAt
  let routingProjected ←
    Loam.ActualRoutingReview.loadSnapshot
      projectedRoot projectedRoot probe.observedAt
  match compareExceptBy "ActualRoutingReview"
      (fun left right => decide (left = right))
      routingLegacy routingProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let rolesLegacy ←
    Loam.AccountingRoleReview.loadInitialCandidates legacyRoot legacyRoot
  let rolesProjected ←
    Loam.AccountingRoleReview.loadInitialCandidates projectedRoot projectedRoot
  match compareExceptBy "AccountingRoleReview"
      (fun left right => left == right)
      rolesLegacy rolesProjected with
  | .error message => return .error message
  | .ok () => pure ()

  let coverageLegacy ←
    Loam.CurrentCoverageReview.loadSnapshotAt
      legacyRoot legacyRoot
      probe.currentWindowStart probe.observedAt probe.endExclusive
  let coverageProjected ←
    Loam.CurrentCoverageReview.loadSnapshotAt
      projectedRoot projectedRoot
      probe.currentWindowStart probe.observedAt probe.endExclusive
  match compareExceptBy "CurrentCoverageReview"
      (fun left right => decide (left = right))
      coverageLegacy coverageProjected with
  | .error message => return .error message
  | .ok () => pure ()

  return .ok ()

private def verifyLegacyUnchanged
    (root : System.FilePath)
    (candidate : Image) : IO (Except String Unit) := do
  for spec in legacySpecs do
    let source := spec.path root
    match body? candidate spec.name with
    | some original =>
        if !(← source.pathExists) then
          return .error
            ("loam: legacy source changed during dry-run: " ++ source.toString)
        let current ← IO.FS.readFile source
        if current != original then
          return .error
            ("loam: legacy source bytes changed during dry-run: " ++ source.toString)
    | none =>
        if ← source.pathExists then
          return .error
            ("loam: absent legacy source appeared during dry-run: " ++ source.toString)
  if ← (Loam.HouseholdAuthority.path root).pathExists then
    return .error "loam: dry-run unexpectedly created household.loam in the source root"
  return .ok ()

/--
Build and qualify one migration candidate without changing authority.

The scratch path must not already exist. This keeps the dry-run from deleting or
overwriting unrelated evidence. The resulting candidate and projection are left
in scratch for inspection.
-/
def run
    (legacyRoot scratchRoot : System.FilePath)
    (probe : ReviewProbe) : IO (Except String Report) := do
  if !(← legacyRoot.pathExists) then
    return .error
      ("loam: dry-run legacy root is missing: " ++ legacyRoot.toString)
  if legacyRoot.toString == scratchRoot.toString then
    return .error "loam: dry-run scratch root must differ from the legacy root"
  if ← scratchRoot.pathExists then
    return .error
      ("loam: dry-run scratch root already exists: " ++ scratchRoot.toString)
  if ← (Loam.HouseholdAuthority.path legacyRoot).pathExists then
    return .error
      "loam: dry-run refused because household.loam already exists in the legacy root"

  let sections ←
    match ← readLegacySections legacyRoot with
    | .ok sections => pure sections
    | .error message => return .error message
  if sections.isEmpty then
    return .error "loam: dry-run found no legacy household canonical files"

  let candidate : Image := { sections := sections }
  let some wire := Loam.Persistence.HouseholdImage.encode? candidate
    | return .error "loam: dry-run HouseholdImage candidate could not be encoded"

  IO.FS.createDirAll scratchRoot
  let candidatePath := scratchRoot / "household.loam.candidate"
  IO.FS.writeFile candidatePath wire

  let reopenedWire ← IO.FS.readFile candidatePath
  if reopenedWire != wire then
    return .error "loam: dry-run candidate readback changed bytes"
  let some reopened := Loam.Persistence.HouseholdImage.decode? reopenedWire
    | return .error "loam: dry-run candidate failed outer decode"
  if reopened != candidate then
    return .error "loam: dry-run candidate changed across outer decode"

  match Loam.HouseholdAuthority.qualifyKnownSections reopened with
  | .error message => return .error message
  | .ok () => pure ()

  let projectionRoot := scratchRoot / "legacy-projection"
  match ← materializeLegacyProjection projectionRoot reopened with
  | .error message => return .error message
  | .ok () => pure ()
  copyConfigForProjection legacyRoot projectionRoot

  match ← validateReviewEquivalence legacyRoot projectionRoot probe with
  | .error message => return .error message
  | .ok () => pure ()

  match ← verifyLegacyUnchanged legacyRoot candidate with
  | .error message => return .error message
  | .ok () => pure ()

  let presentSections := candidate.sections.map Section.name
  let absentSections :=
    Loam.HouseholdAuthority.knownSectionNames.filter
      (fun name => !(presentSections.contains name))

  return .ok {
    candidatePath := candidatePath
    projectionRoot := projectionRoot
    presentSections := presentSections
    absentSections := absentSections
    wire := wire
  }

end Loam.HouseholdImageDryRun
