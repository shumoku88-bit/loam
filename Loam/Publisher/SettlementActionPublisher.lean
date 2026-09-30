import Loam.ActualAuthority
import Loam.ActualDate
import Loam.FreshNumberedToken
import Loam.Publisher.SettlementPublisher

namespace Loam.SettlementActionPublisher

open Loam.Core

set_option autoImplicit false

/-!
# Human-intent settlement actions

This boundary translates a very small user-facing vocabulary into the explicit
append-only settlement evidence accepted by `SettlementPublisher`.

The frontend supplies no retained row identity. Fresh typed identities are
allocated only after the canonical Actual generation has been re-read under the
ordinary writer lock.

The three actions intentionally correspond to distinct meanings:

- changing the commitment amount corrects evidence about the obligation;
- retracting the commitment says that obligation record itself was erroneous;
- reducing without payment says a valid obligation later lost an exact quantity
  without physical/net settlement.

No matching, reason taxonomy, or date inference occurs here.
-/

structure AmountCorrection where
  target : SettlementCommitmentId
  quantity : Quantity
deriving Repr, DecidableEq

structure Retraction where
  target : SettlementCommitmentId
deriving Repr, DecidableEq

structure NonSettlementReduction where
  target : SettlementCommitmentId
  quantity : Quantity
  effectiveOn : Option String := none
deriving Repr, DecidableEq

structure ReductionCorrection where
  target : SettlementExtinguishmentId
  quantity : Quantity
  effectiveOn : Option String := none
deriving Repr, DecidableEq

structure ReductionRetraction where
  target : SettlementExtinguishmentId
deriving Repr, DecidableEq

private def freshCommitmentId
    (evidence : ActualEvidence) : SettlementCommitmentId :=
  let used := evidence.settlements.commitments.map
    (fun row => row.id.token)
  ⟨Loam.firstUnusedNumberedToken "settlement-commitment-" used 1⟩

private def freshExtinguishmentId
    (evidence : ActualEvidence) : SettlementExtinguishmentId :=
  let used := evidence.settlements.extinguishments.map
    (fun row => row.id.token)
  ⟨Loam.firstUnusedNumberedToken "settlement-extinguishment-" used 1⟩

private def currentCommitment?
    (image : Loam.ActualAuthority.Image)
    (target : SettlementCommitmentId) :
    Except String SettlementCommitment := do
  let admitted ←
    match image.settlement.commitments.find?
        (fun row => decide (row.commitment.id = target)) with
    | some row => pure row
    | none =>
        throw
          "loam: selected settlement item is no longer current; reload the settlement view"
  pure admitted.commitment

private def currentReduction?
    (image : Loam.ActualAuthority.Image)
    (target : SettlementExtinguishmentId) :
    Except String SettlementCommitmentExtinguishment := do
  let admitted ←
    match image.settlement.extinguishments.find?
        (fun row => decide (row.extinguishment.id = target)) with
    | some row => pure row
    | none =>
        throw
          "loam: selected non-payment reduction is no longer current; reload the settlement view"
  pure admitted.extinguishment

private def validateReductionShape
    (quantity : Quantity)
    (effectiveOn : Option String) : Except String Unit := do
  if quantity.quanta <= 0 then
    throw "loam: non-payment reduction must be greater than zero"
  match effectiveOn with
  | some date =>
      if !Loam.ActualDate.validIsoDate date then
        throw "loam: reduction date must be a real YYYY-MM-DD calendar date"
  | none => pure ()

private def publishDraft
    (root : System.FilePath)
    (evidence : ActualEvidence)
    (draft : Loam.SettlementPublisher.Draft) :
    IO (Except String Unit) := do
  let candidate ←
    match Loam.SettlementPublisher.admit? evidence draft with
    | .ok candidate => pure candidate
    | .error message => return .error message
  Loam.ActualAuthority.publishActual? root candidate

private def correctAmountUnderOwnership
    (root : System.FilePath)
    (intent : AmountCorrection) :
    IO (Except String SettlementCommitmentId) := do
  if intent.quantity.quanta <= 0 then
    return .error "loam: settlement amount must be greater than zero"
  let image ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let current ←
    match currentCommitment? image intent.target with
    | .ok current => pure current
    | .error message => return .error message
  if current.quantity = intent.quantity then
    return .error "loam: settlement amount is unchanged"
  let replacementId := freshCommitmentId image.evidence
  let replacement : SettlementCommitment := {
    current with
    id := replacementId
    quantity := intent.quantity
  }
  let draft : Loam.SettlementPublisher.Draft := {
    commitments := [replacement]
    commitmentRevisions := [{
      target := current.id
      replacement := some replacementId
    }]
  }
  match ← publishDraft root image.evidence draft with
  | .ok () => return .ok replacementId
  | .error message => return .error message

private def retractUnderOwnership
    (root : System.FilePath)
    (intent : Retraction) : IO (Except String Unit) := do
  let image ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let current ←
    match currentCommitment? image intent.target with
    | .ok current => pure current
    | .error message => return .error message
  let draft : Loam.SettlementPublisher.Draft := {
    commitmentRevisions := [{
      target := current.id
      replacement := none
    }]
  }
  publishDraft root image.evidence draft

private def reduceUnderOwnership
    (root : System.FilePath)
    (intent : NonSettlementReduction) :
    IO (Except String SettlementExtinguishmentId) := do
  match validateReductionShape intent.quantity intent.effectiveOn with
  | .error message => return .error message
  | .ok () => pure ()
  let image ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let current ←
    match currentCommitment? image intent.target with
    | .ok current => pure current
    | .error message => return .error message
  let id := freshExtinguishmentId image.evidence
  let draft : Loam.SettlementPublisher.Draft := {
    extinguishments := [{
      id := id
      target := current.id
      quantity := intent.quantity
      effectiveOn := intent.effectiveOn
    }]
  }
  match ← publishDraft root image.evidence draft with
  | .ok () => return .ok id
  | .error message => return .error message

/--
Correct only the amount of one current commitment.

Source provenance, direction, and Measure are copied from the current admitted
commitment. Existing settlement/extinguishment evidence is then re-admitted
against the replacement, so an amount smaller than already-explained quantity
fails closed.
-/
def correctAmount
    (rootPath : String)
    (intent : AmountCorrection) :
    IO (Except String SettlementCommitmentId) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (correctAmountUnderOwnership root intent)

/--
Retract one current commitment as erroneous evidence.

This is not payment, forgiveness, or another real-world reduction. Admission
refuses the operation while current dependent settlement/extinguishment evidence
would be orphaned.
-/
def retract
    (rootPath : String)
    (intent : Retraction) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (retractUnderOwnership root intent)

/--
Record one exact quantity that ceased to bind without settlement.

The optional effective date is retained only when supplied. `none` stays
historically unplaced and is never replaced with today's date or another guess.
-/
def reduceWithoutPayment
    (rootPath : String)
    (intent : NonSettlementReduction) :
    IO (Except String SettlementExtinguishmentId) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (reduceUnderOwnership root intent)

private def correctReductionUnderOwnership
    (root : System.FilePath)
    (intent : ReductionCorrection) :
    IO (Except String SettlementExtinguishmentId) := do
  match validateReductionShape intent.quantity intent.effectiveOn with
  | .error message => return .error message
  | .ok () => pure ()
  let image ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let current ←
    match currentReduction? image intent.target with
    | .ok current => pure current
    | .error message => return .error message
  if current.quantity = intent.quantity &&
      current.effectiveOn = intent.effectiveOn then
    return .error "loam: non-payment reduction is unchanged"
  let replacementId := freshExtinguishmentId image.evidence
  let replacement : SettlementCommitmentExtinguishment := {
    current with
    id := replacementId
    quantity := intent.quantity
    effectiveOn := intent.effectiveOn
  }
  let draft : Loam.SettlementPublisher.Draft := {
    extinguishments := [replacement]
    extinguishmentRevisions := [{
      target := current.id
      replacement := some replacementId
    }]
  }
  match ← publishDraft root image.evidence draft with
  | .ok () => return .ok replacementId
  | .error message => return .error message

private def retractReductionUnderOwnership
    (root : System.FilePath)
    (intent : ReductionRetraction) : IO (Except String Unit) := do
  let image ←
    match ← Loam.ActualAuthority.loadImage? root with
    | .ok image => pure image
    | .error message => return .error message
  let current ←
    match currentReduction? image intent.target with
    | .ok current => pure current
    | .error message => return .error message
  let draft : Loam.SettlementPublisher.Draft := {
    extinguishmentRevisions := [{
      target := current.id
      replacement := none
    }]
  }
  publishDraft root image.evidence draft

/--
Correct one current non-payment reduction without exposing its replacement row
identity to the caller.

The historical target commitment is copied from the current admitted reduction,
and the complete settlement image is re-admitted before publication.
-/
def correctReduction
    (rootPath : String)
    (intent : ReductionCorrection) :
    IO (Except String SettlementExtinguishmentId) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (correctReductionUnderOwnership root intent)

/--
Retract one erroneous current non-payment reduction row.

This restores only that reduction. It does not retract or rewrite the target
commitment.
-/
def retractReduction
    (rootPath : String)
    (intent : ReductionRetraction) : IO (Except String Unit) := do
  if rootPath.isEmpty then
    return .error "loam: data directory must not be empty"
  let root := System.FilePath.mk rootPath
  Loam.ActualAuthority.withActualOwnership root
    (retractReductionUnderOwnership root intent)

end Loam.SettlementActionPublisher
