import Loam.ActualAuthority
import Loam.ActualDate
import Loam.ActualReview
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
- every current Actual Event carrying nonzero quantity for the coordinate has a
  usable occurrence date.

The last rule is deliberately conservative: an undated current Event cannot be
proven to fall before the claimed start boundary.

Removing a claim is always allowed when the authority image is readable.
-/

structure Draft where
  coordinate : EffectCoordinate
  startDay : Option String
deriving Repr, DecidableEq

private def coordinateQuanta (event : Event) (coordinate : EffectCoordinate) : Int :=
  event.effects.foldl
    (fun total effect =>
      if effect.coordinate = coordinate then total + effect.quantity.quanta else total)
    0

private def validateCurrentDates
    (coordinate : EffectCoordinate) :
    List Loam.ActualReview.Record → Except String Unit
  | [] => .ok ()
  | record :: rest =>
      if !record.isCurrent || coordinateQuanta record.event coordinate = 0 then
        validateCurrentDates coordinate rest
      else
        match record.date with
        | some day =>
            if Loam.ActualDate.validIsoDate day then
              validateCurrentDates coordinate rest
            else
              .error
                ("loam: bounded historical support requires a valid occurrence date for Event " ++
                  record.event.id.token)
        | none =>
            .error
              ("loam: bounded historical support cannot place current Event " ++
                record.event.id.token ++ " on either side of the start boundary")

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
      validateCurrentDates draft.coordinate (Loam.ActualReview.recordsFromActualImage image)
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
