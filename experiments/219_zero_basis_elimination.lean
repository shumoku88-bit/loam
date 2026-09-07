import Loam.Core.EventMemory
import Loam.Core.QuantityBasisMemory

namespace Loam.Observation219

open Loam.Core

set_option autoImplicit false

/--
Experiment-local evidence that one finite coordinate domain is known to begin at
exact zero at the selected application-history boundary.

This deliberately preserves the distinction `outside domain != known zero`.
It is not a production proposal yet.
-/
structure ZeroOriginDomain where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup

namespace ZeroOriginDomain

/-- Membership is the only current meaning of the experiment-local origin domain. -/
def contains (domain : ZeroOriginDomain) (coordinate : EffectCoordinate) : Bool :=
  decide (coordinate ∈ domain.coordinates)

end ZeroOriginDomain

/--
Current quantity derived directly from retained Event history when one coordinate
is explicitly admitted into an application-start exact-zero domain.
-/
def currentFromZeroOrigin?
    (domain : ZeroOriginDomain)
    (events : EventMemory)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity :=
  let coordinate : EffectCoordinate := ⟨locus, measure⟩
  if domain.contains coordinate then
    some (EventMemory.quantityAtRecorded events locus measure)
  else
    none

/--
The corresponding arithmetic shape of one ordinary QuantityBasis fact, before
basis-correction or basis-cut machinery is considered.
-/
def currentFromBasis
    (basis : QuantityBasis)
    (events : EventMemory) : Quantity :=
  basis.quantity + EventMemory.quantityAtRecorded events basis.locus basis.measure

private def wallet : LocusId := ⟨"wallet"⟩
private def savings : LocusId := ⟨"savings"⟩
private def unknown : LocusId := ⟨"unknown"⟩
private def jpy : MeasureId := ⟨"jpy"⟩
private def walletJpy : EffectCoordinate := ⟨wallet, jpy⟩
private def savingsJpy : EffectCoordinate := ⟨savings, jpy⟩

private def zeroDomain : ZeroOriginDomain :=
  { coordinates := [walletJpy, savingsJpy], nodup := by decide }

private def sampleEvent : Event :=
  { id := ⟨"event-1"⟩
    effects :=
      [ Effect.ofQuantity ⟨"effect-1"⟩ wallet jpy (Quantity.ofQuanta 100)
      , Effect.ofQuantity ⟨"effect-2"⟩ savings jpy (Quantity.ofQuanta (-100)) ]
    keyNodup := by decide }

private def sampleEvents : EventMemory :=
  { events := [sampleEvent], idNodup := by simp }

private def zeroWalletBasis : QuantityBasis :=
  QuantityBasis.ofQuantity ⟨"basis-wallet"⟩ wallet jpy 0

private def nonzeroWalletBasis : QuantityBasis :=
  QuantityBasis.ofQuantity
    ⟨"basis-wallet-nonzero"⟩ wallet jpy (Quantity.ofQuanta 40)

/-- A zero QuantityBasis contributes no arithmetic information beyond domain admission. -/
example :
    currentFromBasis zeroWalletBasis sampleEvents =
      EventMemory.quantityAtRecorded sampleEvents wallet jpy := by
  native_decide

/-- The explicit zero-origin domain yields the same selected-coordinate answer. -/
example :
    currentFromZeroOrigin? zeroDomain sampleEvents wallet jpy =
      some (currentFromBasis zeroWalletBasis sampleEvents) := by
  native_decide

/-- The same factorization holds for another admitted coordinate. -/
example :
    currentFromZeroOrigin? zeroDomain sampleEvents savings jpy =
      some (EventMemory.quantityAtRecorded sampleEvents savings jpy) := by
  native_decide

/-- Outside the finite origin domain, absence remains absence rather than implicit zero. -/
example :
    currentFromZeroOrigin? zeroDomain sampleEvents unknown jpy = none := by
  native_decide

/-- Nonzero opening quantity is real information and cannot be eliminated this way. -/
example :
    currentFromBasis nonzeroWalletBasis sampleEvents !=
      EventMemory.quantityAtRecorded sampleEvents wallet jpy := by
  native_decide

/-- Erasing the domain would strengthen unknown coordinates into known-zero origins. -/
example : zeroDomain.contains ⟨unknown, jpy⟩ = false := by
  native_decide

end Loam.Observation219
