import Loam.ActualAuthority
import Loam.CurrentQuantityAnchor
import Loam.LocusAdmissionAuthority
import Loam.HouseholdPaths
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

/--
Prepare one complete current reconciliation image from quantities observed
together now.

The shared cut is not supplied by the caller. It is derived from every stable
Event correction root represented by the admitted Actual world while Actual is
held under writer ownership. This prevents file order, dates, EventId spelling,
or Git history from becoming a hidden temporal boundary.

New assertions must use a currently admitted Locus. This is publication policy,
not an invariant of retained anchor evidence: an older anchor using a later-
disallowed Locus remains readable, but a new reconciliation write cannot create
an unapproved canonical quantity coordinate.

The first production boundary also refuses coordinates already supported by
ZeroOriginCoverage or OpeningSupport. Choosing precedence between independent
support families has not been qualified and is therefore not invented here.
-/
def propose?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (locusAdmission : LocusAdmissionVocabulary)
    (coverage : ZeroOriginCoverage)
    (opening : OpeningSupportMap)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) :
    Except String Loam.CurrentQuantityAnchor.Evidence := do
  if assertions.isEmpty then
    throw "loam: current quantity anchor requires at least one observed quantity"
  if !assertions.all (fun assertion =>
      locusAdmission.allows assertion.coordinate.locus) then
    throw "loam: current quantity anchor uses a Locus not approved for new publication"
  if assertions.any (overlapsExistingSupport coverage opening) then
    throw "loam: current quantity anchor refuses a coordinate already supported by zero-origin or opening evidence"
  let some roots := Loam.Application.correctionRootIds? events corrections
    | throw "loam: current quantity anchor requires one admitted Event correction frontier"
  let some anchor := Loam.CurrentQuantityAnchor.Evidence.ofLists? roots assertions
    | throw "loam: current quantity anchor requires unique roots and unique asserted coordinates"
  return anchor

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

private def publishUnderOwnership
    (root anchorPath : System.FilePath)
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
  let anchor ←
    match propose?
        actual.events actual.corrections locusAdmission coverage opening assertions with
    | .ok evidence => pure evidence
    | .error message => return .error message
  if !(← Loam.Persistence.saveCurrentQuantityAnchor? anchorPath anchor) then
    return .error "loam: current quantity anchor could not be published"
  return .ok ()

/--
Publish one complete current reconciliation image while holding both the Actual
world and the anchor image against concurrent replacement.

Current Locus admission is re-read during this publication interval. The only
production Locus-admission mutation is currently add-only, so a concurrent new
admission can make this read conservatively stale only in the refusal direction;
no extra Locus-policy lock is added until revocation/replacement is qualified.

Replacement means a new current reconciliation session, not historical
correction of an earlier assertion. No anchor identity or revision graph is
introduced until such history becomes independently useful.
-/
def publish
    (rootPath : String)
    (assertions : List Loam.CurrentQuantityAnchor.Assertion) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  let anchorPath := path root
  Loam.ActualAuthority.withActualOwnership root <|
    Loam.WriterOwnership.withOwnership anchorPath
      (publishUnderOwnership root anchorPath assertions)

end Loam.CurrentQuantityAnchorPublisher
