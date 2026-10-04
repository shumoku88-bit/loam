import Loam.Authority.ActualAuthority
import Loam.ActualDate
import Loam.Core.BoundedHistorySupport
import Loam.Application.CurrentQuantityAnchor
import Loam.Authority.LocusAdmissionAuthority
import Loam.Authority.CurrentSupportAuthority

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

private def publishFromGeneration
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let observedSupport ←
    match ← Loam.CurrentSupportAuthority.loadHousehold? root with
    | .ok observed => pure observed
    | .error message => return .error message
  let generation := observedSupport.generation
  let image ←
    match Loam.ActualAuthority.decodeHouseholdGeneration? generation with
    | .ok image => pure image
    | .error message => return .error message
  let some locusBody :=
      Loam.Persistence.HouseholdImage.body? generation.image "LocusAdmission"
    | return .error "loam: required HouseholdImage Locus admission section is missing"
  let some locusAdmission := Loam.Persistence.decodeLocusAdmissionVocabulary? locusBody
    | return .error "loam: malformed or unsupported HouseholdImage Locus admission authority"
  let anchor := observedSupport.snapshot.anchor
  let existing := observedSupport.snapshot.bounded
  let proposed ←
    match propose? image locusAdmission anchor existing draft with
    | .ok evidence => pure evidence
    | .error message => return .error message
  match ← Loam.CurrentSupportAuthority.publishObserved?
      root observedSupport {
        anchor := observedSupport.snapshot.anchor
        presence := observedSupport.snapshot.presence
        bounded := proposed
      } with
  | .ok _ => return .ok ()
  | .error message => return .error message

/--
Publish bounded historical support from one observed Household generation.
Actual, LocusAdmission, and current-support evidence are decoded from that exact
generation; concurrent Household publication is refused by the shared
stale-generation check.
-/
def publish
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) :=
  publishFromGeneration root draft

end Loam.BoundedHistorySupportPublisher
