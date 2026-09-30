import Loam.ActualAuthority
import Loam.ActualDate
import Loam.BoundedHistorySupport
import Loam.CurrentQuantityAnchor
import Loam.HouseholdPaths
import Loam.LocusAdmissionAuthority
import Loam.Persistence.BoundedHistorySupportPersistence
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.WriterOwnership

namespace Loam.BoundedHistorySupportPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Bounded historical support publisher

This publisher changes only the explicit coordinate/start-day claim. It does not
invent an opening quantity, infer completeness from numeric agreement, or alter
Actual / CurrentQuantityAnchor.

A positive claim is admitted only when:

- the Locus is admitted for current household use;
- the start day is a real YYYY-MM-DD date;
- the coordinate has exact CurrentQuantityAnchor support;
- the retained exact CurrentQuantityAnchor resolves against the admitted current
  Actual correction world.

`ActualAuthority.Image` already proves every retained Event has one admitted
real calendar occurrence date, so this publisher does not rebuild that
production admission a second time.

Removing a claim is always allowed when the authority image is readable.
-/

structure Draft where
  coordinate : EffectCoordinate
  startDay : Option String
deriving Repr, DecidableEq

def propose?
    (image : Loam.ActualAuthority.Image)
    (locusAdmission : LocusAdmissionVocabulary)
    (anchor : Loam.CurrentQuantityAnchor.Evidence)
    (existing : Loam.BoundedHistorySupport.Evidence)
    (draft : Draft) : Except String Loam.BoundedHistorySupport.Evidence := do
  match draft.startDay with
  | none =>
      let some updated := existing.withoutCoordinate? draft.coordinate
        | throw "loam: bounded historical support could not preserve a unique support image"
      return updated
  | some startDay =>
      if !locusAdmission.allows draft.coordinate.locus then
        throw "loam: bounded historical support uses a Locus not approved for current household use"
      if !Loam.ActualDate.validIsoDate startDay then
        throw "loam: bounded historical support start must be a real YYYY-MM-DD calendar day"
      if (anchor.assertionFor? draft.coordinate).isNone then
        throw "loam: bounded historical support requires exact CurrentQuantityAnchor support"
      let resolved ←
        Loam.CurrentQuantityAnchor.inspectQuantity
          image.evidence.events image.evidence.corrections anchor draft.coordinate
      if resolved.isNone then
        throw "loam: bounded historical support requires a usable exact CurrentQuantityAnchor"
      let support : Loam.BoundedHistorySupport.Support := {
        coordinate := draft.coordinate
        startDay := startDay
      }
      let some updated := existing.withSupport? support
        | throw "loam: bounded historical support could not admit the requested start boundary"
      return updated

private def loadAnchor
    (path : System.FilePath) : IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  if !(← path.pathExists) then
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty
  let some evidence ← Loam.Persistence.loadCurrentQuantityAnchor? path
    | return .error "loam: current quantity anchor authority is malformed or unsupported"
  return .ok evidence

private def loadExisting
    (path : System.FilePath) : IO (Except String Loam.BoundedHistorySupport.Evidence) := do
  if !(← path.pathExists) then
    return .ok Loam.BoundedHistorySupport.Evidence.empty
  let some evidence ← Loam.Persistence.loadBoundedHistorySupport? path
    | return .error "loam: bounded historical support authority is malformed or unsupported"
  return .ok evidence

private def publishUnderOwnership
    (root anchorPath supportPath : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let image ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let locusAdmission ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok vocabulary => pure vocabulary
    | .error message => return .error message
  let anchor ←
    match ← loadAnchor anchorPath with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let existing ←
    match ← loadExisting supportPath with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let proposed ←
    match propose? image locusAdmission anchor existing draft with
    | .ok evidence => pure evidence
    | .error message => return .error message
  if !(← Loam.Persistence.saveBoundedHistorySupport? supportPath proposed) then
    return .error "loam: bounded historical support could not be published"
  return .ok ()

def publish
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let anchorPath := Loam.HouseholdPaths.currentQuantityAnchor root
  let supportPath := Loam.HouseholdPaths.boundedHistorySupport root
  Loam.ActualAuthority.withActualOwnership root <|
    Loam.WriterOwnership.withOwnership anchorPath <|
      Loam.WriterOwnership.withOwnership supportPath
        (publishUnderOwnership root anchorPath supportPath draft)

end Loam.BoundedHistorySupportPublisher
