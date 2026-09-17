import Loam.ActualAuthority
import Loam.ActualEvidence
import Loam.Persistence.TokenSyntax

namespace Loam.EventMerchantPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Initial Event Merchant publication

Merchant disposition is independent retained evidence about an already-existing
Actual Event. This publisher admits only the first explicit classification of one
Event as either a Merchant relation to one role-free ExternalPartyId or explicit
`nonmerchant` evidence.

It deliberately does not implement replacement, deletion, aliasing, Party
registration, display names, generic Party roles, Merchant amounts, Effect-level
seller attribution, or inference from Event text.
-/

structure Draft where
  target : EventId
  disposition : MerchantDisposition
deriving Repr, DecidableEq

private def validateDisposition? (disposition : MerchantDisposition) : Except String Unit :=
  match disposition with
  | .merchant party =>
      if Loam.Persistence.validToken party.token then
        .ok ()
      else
        .error "loam: Merchant party token must be a non-empty single text field"
  | .nonmerchant =>
      .ok ()

/--
Admit one first Merchant disposition against the currently retained Actual
generation.

Absence remains unresolved. Once a disposition exists, this initial publisher
refuses all further classification so replacement semantics cannot enter
implicitly.
-/
def admit?
    (evidence : ActualEvidence)
    (draft : Draft) : Except String ActualEvidence := do
  let _ ← validateDisposition? draft.disposition
  if (EventMemory.findById? evidence.events draft.target).isNone then
    throw "loam: Merchant classification requires an existing Event"
  if (evidence.merchants.findDisposition? draft.target).isSome then
    throw "loam: Event Merchant is already classified; replacement is not qualified"
  let entry : EventMerchantEvidence := {
    event := draft.target
    disposition := draft.disposition
  }
  let some merchants := evidence.merchants.add? entry
    | throw "loam: Merchant classification would violate one disposition per Event"
  return { evidence with merchants := merchants }

private def publishUnderOwnership
    (root : System.FilePath)
    (draft : Draft) : IO (Except String Unit) := do
  let evidence ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok value => pure value
    | .error message => return .error message
  let updated ←
    match admit? evidence draft with
    | .ok value => pure value
    | .error message => return .error message
  Loam.ActualAuthority.publishActual? root updated

/--
Publish one first Event Merchant disposition through normalized Actual authority.
The admission check and atomic generation switch occur under the shared Actual
writer ownership boundary.
-/
def publishDisposition
    (rootPath : String)
    (draft : Draft) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (publishUnderOwnership root draft)

end Loam.EventMerchantPublisher
