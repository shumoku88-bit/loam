import Loam.Application.CurrentQuantity

namespace Loam.Observation219

open Loam.Core
open Loam.Application

set_option autoImplicit false

/--
Experiment-local evidence that one finite coordinate domain is known to begin at
exact zero at the selected application-history boundary.

This deliberately preserves the distinction `outside domain != known zero`.
It carries no per-coordinate stable basis identity and no stored quantity beyond
the common zero premise.
-/
structure ZeroOriginDomain where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup
  deriving Repr, DecidableEq

namespace ZeroOriginDomain

/-- Fail-closed construction of a ZeroOriginDomain: duplicates refuse. -/
def ofCoordinates? (coordinates : List EffectCoordinate) : Option ZeroOriginDomain :=
  if h : coordinates.Nodup then
    some ⟨coordinates, h⟩
  else
    none

/-- Membership in the finite coordinate domain. -/
def contains (domain : ZeroOriginDomain) (coordinate : EffectCoordinate) : Bool :=
  decide (coordinate ∈ domain.coordinates)

end ZeroOriginDomain

private def liftInspection : QuantityInspectionAnswer → CurrentQuantityAnswer
  | .recorded quantity => .current quantity
  | .singleCorrectionEffective quantity => .current quantity
  | .frontierEffective quantity => .current quantity
  | .missingCorrectionEndpoint => .missingEventCorrectionEndpoint
  | .frontierRequired => .eventFrontierRequired

/--
Project one current quantity from an explicit finite zero-origin domain:
- coordinate in domain: correction-aware effective Event quantity;
- coordinate outside domain: basisMissing (refusal / missing evidence, never implicit zero).
-/
def inspectWithZeroOriginDomain
    (domain : ZeroOriginDomain)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) : CurrentQuantityAnswer :=
  if domain.contains coordinate then
    liftInspection <|
      inspectQuantity events eventCorrections coordinate.locus coordinate.measure
  else
    .basisMissing

-- Coordinates corresponding to current household dogfood
private def cash : LocusId := ⟨"cash"⟩
private def paypay : LocusId := ⟨"paypay"⟩
private def smbc : LocusId := ⟨"smbc"⟩
private def yucho : LocusId := ⟨"yucho"⟩
private def allCountry : LocusId := ⟨"all-country"⟩
private def food : LocusId := ⟨"food"⟩
private def unknown : LocusId := ⟨"unknown"⟩
private def jpy : MeasureId := ⟨"jpy"⟩

private def cashJpy : EffectCoordinate := ⟨cash, jpy⟩
private def paypayJpy : EffectCoordinate := ⟨paypay, jpy⟩
private def smbcJpy : EffectCoordinate := ⟨smbc, jpy⟩
private def yuchoJpy : EffectCoordinate := ⟨yucho, jpy⟩
private def allCountryJpy : EffectCoordinate := ⟨allCountry, jpy⟩
private def foodJpy : EffectCoordinate := ⟨food, jpy⟩
private def unknownJpy : EffectCoordinate := ⟨unknown, jpy⟩

private def householdCoordinates : List EffectCoordinate :=
  [cashJpy, paypayJpy, smbcJpy, yuchoJpy, allCountryJpy]

private def householdZeroDomain : ZeroOriginDomain :=
  match ZeroOriginDomain.ofCoordinates? householdCoordinates with
  | some d => d
  | none => ⟨[], by decide⟩

private def emptyEventCorrections : EventCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def emptyBasisCorrections : QuantityBasisCorrectionMemory :=
  { corrections := [], idNodup := by simp }

private def householdZeroBases : QuantityBasisMemory :=
  { bases :=
      [ QuantityBasis.ofQuantity ⟨"hpb-cash"⟩ cash jpy 0
      , QuantityBasis.ofQuantity ⟨"hpb-paypay"⟩ paypay jpy 0
      , QuantityBasis.ofQuantity ⟨"hpb-smbc"⟩ smbc jpy 0
      , QuantityBasis.ofQuantity ⟨"hpb-yucho"⟩ yucho jpy 0
      , QuantityBasis.ofQuantity ⟨"hpb-all-country"⟩ allCountry jpy 0
      ]
    idNodup := by decide }

private def sampleEvent : Event :=
  { id := ⟨"event-1"⟩
    effects :=
      [ Effect.ofQuantity ⟨"eff-1"⟩ cash jpy (Quantity.ofQuanta 909)
      , Effect.ofQuantity ⟨"eff-2"⟩ paypay jpy (Quantity.ofQuanta 728)
      , Effect.ofQuantity ⟨"eff-3"⟩ smbc jpy (Quantity.ofQuanta 81575)
      , Effect.ofQuantity ⟨"eff-4"⟩ yucho jpy (Quantity.ofQuanta 5000)
      , Effect.ofQuantity ⟨"eff-5"⟩ allCountry jpy (Quantity.ofQuanta 5600)
      , Effect.ofQuantity ⟨"eff-6"⟩ food jpy (Quantity.ofQuanta (-93812))
      ]
    keyNodup := by decide }

private def sampleEvents : EventMemory :=
  { events := [sampleEvent], idNodup := by simp }

/-- 1. Exact parity on cash / jpy -/
example :
    inspectCurrentQuantityWithBasisCorrections
        sampleEvents emptyEventCorrections householdZeroBases emptyBasisCorrections cash jpy =
      inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections cashJpy := by
  decide

/-- 2. Exact parity on paypay / jpy -/
example :
    inspectCurrentQuantityWithBasisCorrections
        sampleEvents emptyEventCorrections householdZeroBases emptyBasisCorrections paypay jpy =
      inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections paypayJpy := by
  decide

/-- 3. Exact parity on smbc / jpy -/
example :
    inspectCurrentQuantityWithBasisCorrections
        sampleEvents emptyEventCorrections householdZeroBases emptyBasisCorrections smbc jpy =
      inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections smbcJpy := by
  decide

/-- 4. Exact parity on yucho / jpy -/
example :
    inspectCurrentQuantityWithBasisCorrections
        sampleEvents emptyEventCorrections householdZeroBases emptyBasisCorrections yucho jpy =
      inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections yuchoJpy := by
  decide

/-- 5. Exact parity on all-country / jpy -/
example :
    inspectCurrentQuantityWithBasisCorrections
        sampleEvents emptyEventCorrections householdZeroBases emptyBasisCorrections allCountry jpy =
      inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections allCountryJpy := by
  decide

/-! ## Negative Controls -/

private def domainWithoutCash : ZeroOriginDomain :=
  { coordinates := [paypayJpy, smbcJpy, yuchoJpy, allCountryJpy], nodup := by decide }

/--
Negative Control 1: Removing a coordinate makes it unavailable (basisMissing),
never implicit zero.
-/
example :
    inspectWithZeroOriginDomain
        domainWithoutCash sampleEvents emptyEventCorrections cashJpy =
      .basisMissing := by
  decide

example :
    inspectWithZeroOriginDomain
        domainWithoutCash sampleEvents emptyEventCorrections cashJpy ≠
      .current (Quantity.ofQuanta 0) := by
  decide

/--
Negative Control 2: An unrelated coordinate with recorded Event activity (food)
does not automatically become an admitted balance unless the domain explicitly includes it.
-/
example :
    inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections foodJpy =
      .basisMissing := by
  decide

example :
    inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections unknownJpy =
      .basisMissing := by
  decide

private def nonzeroBases : QuantityBasisMemory :=
  { bases :=
      [ QuantityBasis.ofQuantity ⟨"hpb-cash"⟩ cash jpy (Quantity.ofQuanta 100)
      , QuantityBasis.ofQuantity ⟨"hpb-paypay"⟩ paypay jpy 0
      , QuantityBasis.ofQuantity ⟨"hpb-smbc"⟩ smbc jpy 0
      , QuantityBasis.ofQuantity ⟨"hpb-yucho"⟩ yucho jpy 0
      , QuantityBasis.ofQuantity ⟨"hpb-all-country"⟩ allCountry jpy 0
      ]
    idNodup := by decide }

/--
Negative Control 3: Synthetic nonzero basis cannot be eliminated into an
Event-only zero-origin answer.
-/
example :
    inspectCurrentQuantityWithBasisCorrections
        sampleEvents emptyEventCorrections nonzeroBases emptyBasisCorrections cash jpy ≠
      inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections cashJpy := by
  decide

example :
    inspectCurrentQuantityWithBasisCorrections
        sampleEvents emptyEventCorrections nonzeroBases emptyBasisCorrections cash jpy =
      .current (Quantity.ofQuanta 1009) := by
  decide

example :
    inspectWithZeroOriginDomain
        householdZeroDomain sampleEvents emptyEventCorrections cashJpy =
      .current (Quantity.ofQuanta 909) := by
  decide

/--
Negative Control 4: Duplicate coordinate rows in domain specification fail closed.
-/
example :
    ZeroOriginDomain.ofCoordinates? [cashJpy, cashJpy] = none := by
  decide

end Loam.Observation219
