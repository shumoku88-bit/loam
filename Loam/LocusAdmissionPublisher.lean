import Loam.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax
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

/-- Receipt for one successful admission-policy change. -/
structure Receipt where
  locus : LocusId
  previousCount : Nat
  currentCount : Nat
  deriving Repr, DecidableEq

/--
Pure proposal against one already-loaded current admission vocabulary.

The existing vocabulary remains the sole source of current permission. Historical
Events and display metadata are never consulted while deciding admission.
-/
def propose?
    (vocabulary : LocusAdmissionVocabulary) (draft : Draft) :
    Except String (LocusAdmissionVocabulary × Receipt) := do
  if !Loam.Persistence.validToken draft.token then
    throw "loam: new Locus must be one valid stable token"
  let locus : LocusId := ⟨draft.token⟩
  if vocabulary.allows locus then
    throw "loam: Locus is already admitted for new writes"
  let approved := vocabulary.approved ++ [locus]
  let updated ←
    match LocusAdmissionVocabulary.ofLoci? approved with
    | some updated => pure updated
    | none => throw "loam: proposed Locus admission vocabulary is not unique"
  pure (updated, {
    locus := locus
    previousCount := vocabulary.approved.length
    currentCount := updated.approved.length
  })

private def publishUnderOwnership
    (root : System.FilePath) (draft : Draft) : IO (Except String Receipt) := do
  let vocabulary ←
    match ← Loam.LocusAdmissionAuthority.loadCurrent? root with
    | .ok vocabulary => pure vocabulary
    | .error message => return .error message
  let (updated, receipt) ←
    match propose? vocabulary draft with
    | .ok value => pure value
    | .error message => return .error message
  match ← Loam.LocusAdmissionAuthority.replaceCurrent? root updated with
  | .error message => return .error message
  | .ok _ => return .ok receipt

/--
Admit one new Locus against the current admission-policy authority.

The caller keeps the existing Movement `CURRENT` ownership anchor while the local
`LocusAdmissionAuthority` hides the policy's current manifest-backed placement.
No household evidence is exposed to this publisher's proposal semantics.
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
