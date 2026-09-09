import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.LocusAdmissionPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Locus admission publisher

Surface-independent add-only administration for the current new-write Locus
vocabulary. This publisher deliberately does not create display metadata,
AccountingRole evidence, Purpose routing, aliases, rename semantics, or retirement
semantics.
-/

/-- Request to admit one new stable Locus identity for future quantity writes. -/
structure Draft where
  token : String
  deriving Repr, DecidableEq

/-- Receipt for one successful manifest-backed admission change. -/
structure Receipt where
  locus : LocusId
  previousCount : Nat
  currentCount : Nat
  deriving Repr, DecidableEq

/--
Pure proposal against one already-loaded Movement world.

The existing vocabulary remains the sole source of current permission. Historical
Events and display metadata are never consulted while deciding admission.
-/
def propose?
    (world : Loam.MovementAdmission.World) (draft : Draft) :
    Except String (Loam.MovementAdmission.World × Receipt) := do
  if !Loam.Persistence.validToken draft.token then
    throw "loam: new Locus must be one valid stable token"
  let locus : LocusId := ⟨draft.token⟩
  if world.locusAdmission.allows locus then
    throw "loam: Locus is already admitted for new writes"
  let approved := world.locusAdmission.approved ++ [locus]
  let vocabulary ←
    match LocusAdmissionVocabulary.ofLoci? approved with
    | some vocabulary => pure vocabulary
    | none => throw "loam: proposed Locus admission vocabulary is not unique"
  pure ({ world with locusAdmission := vocabulary }, {
    locus := locus
    previousCount := world.locusAdmission.approved.length
    currentCount := vocabulary.approved.length
  })

private def publishUnderOwnership
    (root : System.FilePath) (draft : Draft) : IO (Except String Receipt) := do
  let world ←
    match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
    | .ok world => pure world
    | .error message => return .error message
  let (updated, receipt) ←
    match propose? world draft with
    | .ok value => pure value
    | .error message => return .error message
  match ← Loam.MovementManifestAuthority.publishWorld? root updated with
  | .error message => return .error message
  | .ok _ => return .ok receipt

/--
Admit one new Locus against the current Movement manifest authority.

Publication re-reads the selected generation while holding the shared `CURRENT`
ownership anchor and republishes one complete generation with only
`world.locusAdmission` changed.
-/
def publishManifestAdmission
    (rootPath : String) (draft : Draft) : IO (Except String Receipt) := do
  if rootPath.isEmpty then
    return .error "loam: LOAM_MOVEMENT_MANIFEST_ROOT must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.WriterOwnership.withOwnership
    (root / "CURRENT")
    (publishUnderOwnership root draft)

end Loam.LocusAdmissionPublisher
