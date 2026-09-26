import Loam.ActualAuthority
import Loam.BoundedHistorySupport
import Loam.CurrentQuantityAnchor
import Loam.LocusAdmissionAuthority
import Loam.HouseholdPaths
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.OpeningSupportPersistence
import Loam.Persistence.ZeroOriginCoveragePersistence
import Loam.WriterOwnership

namespace Loam.CurrentQuantityAnchorPublisher

open Loam.Core

set_option autoImplicit false

/-- Canonical filename for the optional current reconciliation image. -/
def fileName : String := Loam.HouseholdPaths.currentQuantityAnchorFileName

/-- Canonical path for current reconciliation evidence under one household root. -/
def path (root : System.FilePath) : System.FilePath := Loam.HouseholdPaths.currentQuantityAnchor root

private def overlapsExistingSupport
    (coverage : ZeroOriginCoverage)
    (opening : OpeningSupportMap)
    (assertion : Loam.CurrentQuantityAnchor.Assertion) : Bool :=
  coverage.covers assertion.coordinate ||
    (opening.supportFor? assertion.coordinate).isSome

private def validateNewAssertions
    (locusAdmission : LocusAdmissionVocabulary)
    (coverage : ZeroOriginCoverage)
    (opening : OpeningSupportMap)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) : Except String Unit := do
  if assertions.isEmpty then
    throw "loam: current quantity anchor requires at least one observed quantity"
  if !assertions.all (fun assertion =>
      locusAdmission.allows assertion.coordinate.locus) then
    throw "loam: current quantity anchor uses a Locus not approved for new publication"
  if assertions.any (overlapsExistingSupport coverage opening) then
    throw "loam: current quantity anchor refuses a coordinate already supported by zero-origin or opening evidence"

private def currentRoots?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Except String (List EventId) := do
  let some roots := Loam.Application.correctionRootIds? events corrections
    | throw "loam: current quantity anchor requires one admitted Event correction frontier"
  return roots

private def retainedRootsStillRepresented
    (roots : List EventId)
    (evidence : Loam.CurrentQuantityAnchor.Evidence) : Bool :=
  evidence.groups.all fun group =>
    group.reflectedRoots.all fun root => roots.contains root

/--
Prepare one fresh one-group current reconciliation image from quantities observed
together now.

This remains the narrow pure constructor used by tests and callers that
intentionally do not retain a prior image.
-/
def propose?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locusAdmission : LocusAdmissionVocabulary)
    (coverage : ZeroOriginCoverage)
    (opening : OpeningSupportMap)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) :
    Except String Loam.CurrentQuantityAnchor.Evidence := do
  validateNewAssertions locusAdmission coverage opening assertions
  let roots ← currentRoots? events corrections
  let some anchor := Loam.CurrentQuantityAnchor.Evidence.ofLists? roots assertions
    | throw "loam: current quantity anchor requires unique roots and unique asserted coordinates"
  return anchor

/--
Prepare an incremental current-support replacement image.

Assertions supplied now are observed together against the current stable-root
cut. Coordinates not supplied now keep their prior reconciliation group.
Re-observed coordinates are removed from their old group and moved to the fresh
group. Empty old groups disappear.

Retained group roots must still name represented stable roots in the current
Actual correction world. The writer does not silently reinterpret a stale cut.

Group identity is not retained or corrected. Only the resulting coordinate-local
assertion and reflected-root cut matter to current answers.
-/
def proposeUpdate?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locusAdmission : LocusAdmissionVocabulary)
    (coverage : ZeroOriginCoverage)
    (opening : OpeningSupportMap)
    (existing : Loam.CurrentQuantityAnchor.Evidence)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) :
    Except String Loam.CurrentQuantityAnchor.Evidence := do
  validateNewAssertions locusAdmission coverage opening assertions
  let roots ← currentRoots? events corrections
  if !retainedRootsStillRepresented roots existing then
    throw "loam: current quantity anchor retained group references a root no longer represented by Actual"
  let some freshGroup := Loam.CurrentQuantityAnchor.Group.ofLists? roots assertions
    | throw "loam: current quantity anchor requires unique roots and unique asserted coordinates"
  let some updated := existing.replacingWithGroup? freshGroup
    | throw "loam: current quantity anchor could not preserve unique coordinate support"
  if updated.assertions.any (overlapsExistingSupport coverage opening) then
    throw "loam: current quantity anchor retained support now overlaps zero-origin or opening evidence"
  return updated

private def loadCoverage
    (root : System.FilePath) : IO (Except String ZeroOriginCoverage) := do
  let coveragePath := Loam.HouseholdPaths.zeroOriginCoverage root
  if !(← coveragePath.pathExists) then
    return .error "loam: zero-origin coverage authority is missing"
  let some coverage ← Loam.Persistence.loadZeroOriginCoverage? coveragePath
    | return .error "loam: zero-origin coverage authority is malformed or unsupported"
  return .ok coverage

private def loadOpening
    (root : System.FilePath) : IO (Except String OpeningSupportMap) := do
  let openingPath := Loam.HouseholdPaths.openingSupport root
  if !(← openingPath.pathExists) then
    return .error "loam: opening-support authority is missing"
  let some opening ← Loam.Persistence.loadOpeningSupportMap? openingPath
    | return .error "loam: opening-support authority is malformed or unsupported"
  return .ok opening

private def loadExistingAnchor
    (anchorPath : System.FilePath) : IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  if !(← anchorPath.pathExists) then
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty
  let some existing ← Loam.Persistence.loadCurrentQuantityAnchor? anchorPath
    | return .error "loam: current quantity anchor authority is malformed or unsupported"
  return .ok existing


private def loadBoundedHistorySupport
    (path : System.FilePath) : IO (Except String Loam.BoundedHistorySupport.Evidence) := do
  if !(← path.pathExists) then
    return .ok Loam.BoundedHistorySupport.Evidence.empty
  let some evidence ← Loam.Persistence.loadBoundedHistorySupport? path
    | return .error "loam: bounded historical support authority is malformed or unsupported"
  return .ok evidence

/--
A bounded historical completeness claim may survive a fresh observation only
when the new observation agrees with the already-derived current quantity.

A different observed quantity is evidence that the old completeness claim may no
longer be true. The current-anchor writer therefore refuses instead of silently
turning reconciliation into historical support.
-/
def validateBoundedHistoryReobservation
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (existing : Loam.CurrentQuantityAnchor.Evidence)
    (bounded : Loam.BoundedHistorySupport.Evidence)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) : Except String Unit := do
  for support in bounded.supports do
    if (existing.assertionFor? support.coordinate).isNone then
      throw
        ("loam: bounded historical support for " ++ support.coordinate.locus.token ++
          " / " ++ support.coordinate.measure.token ++
          " has no retained exact current anchor; clear or repair the support claim first")
  for assertion in assertions do
    if (bounded.supportFor? assertion.coordinate).isSome then
      let some current ←
        Loam.CurrentQuantityAnchor.inspectQuantity
          events corrections existing assertion.coordinate
        | throw "loam: bounded historical support lost its exact current anchor"
      if current != assertion.quantity then
        throw
          ("loam: observed quantity differs while bounded historical support is active for " ++
            assertion.coordinate.locus.token ++ " / " ++ assertion.coordinate.measure.token ++
            "; correct recorded Actual or move/remove the historical start before reconciling")

private def publishUnderOwnership
    (root anchorPath historyPath : System.FilePath)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) : IO (Except String Unit) := do
  let actual ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok vocabulary => pure vocabulary
    | .error message => return .error message
  let coverage ←
    match ← loadCoverage root with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let opening ←
    match ← loadOpening root with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let existing ←
    match ← loadExistingAnchor anchorPath with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let bounded ←
    match ← loadBoundedHistorySupport historyPath with
    | .ok evidence => pure evidence
    | .error message => return .error message
  match validateBoundedHistoryReobservation
      actual.events actual.corrections existing bounded assertions with
  | .ok () => pure ()
  | .error message => return .error message
  let anchor ←
    match proposeUpdate?
        actual.events actual.corrections locusAdmission coverage opening existing assertions with
    | .ok evidence => pure evidence
    | .error message => return .error message
  if !(← Loam.Persistence.saveCurrentQuantityAnchor? anchorPath anchor) then
    return .error "loam: current quantity anchor could not be published"
  return .ok ()

/--
Publish one new reconciliation group while holding both the Actual world and the
replaceable anchor image against concurrent replacement.

Unmentioned prior coordinates remain in their existing groups. Re-observed
coordinates move to the new group derived from the current Actual root cut.

Current Locus admission is re-read during this publication interval. The only
production Locus-admission mutation is currently add-only, so a concurrent new
admission can make this read conservatively stale only in the refusal direction;
no extra Locus-policy lock is added until revocation/replacement is qualified.

This is current-support replacement, not historical anchor correction. No stable
anchor identity or revision graph is introduced.
-/
def publish
    (rootPath : String)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  let anchorPath := path root
  let historyPath := Loam.HouseholdPaths.boundedHistorySupport root
  Loam.ActualAuthority.withActualOwnership root <|
    Loam.WriterOwnership.withOwnership anchorPath <|
      Loam.WriterOwnership.withOwnership historyPath
        (publishUnderOwnership root anchorPath historyPath assertions)

end Loam.CurrentQuantityAnchorPublisher
