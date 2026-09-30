import Loam.LocusAdmissionAuthority
import Loam.Persistence.TokenSyntax

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

/--
Pure proposal against one already-loaded current admission vocabulary.

The existing vocabulary remains the sole source of current permission. Historical
Events and display metadata are never consulted while deciding admission.
-/
def propose?
    (vocabulary : LocusAdmissionVocabulary) (draft : Draft) :
    Except String LocusAdmissionVocabulary := do
  if !Loam.Persistence.validToken draft.token then
    throw "loam: new Locus must be one valid stable token"
  let locus : LocusId := ⟨draft.token⟩
  let approved := vocabulary.approved ++ [locus]
  let updated ←
    match LocusAdmissionVocabulary.ofLoci? approved with
    | some updated => pure updated
    | none => throw "loam: Locus is already admitted for new writes"
  pure updated

/--
Admit one new Locus against the current admission-policy authority.

The local authority owns the current physical policy placement, writer lock, and
read/modify/publish protocol. This publisher contributes only the policy-local
proposal semantics and therefore does not depend on household Actual evidence.
-/
def publishAdmission
    (rootPath : String) (draft : Draft) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data root must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.LocusAdmissionAuthority.updateCurrent? root fun vocabulary => do
    let updated ← propose? vocabulary draft
    pure (updated, ())

end Loam.LocusAdmissionPublisher
