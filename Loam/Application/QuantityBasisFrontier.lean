import Loam.Core.QuantityBasisCorrectionMemory

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

private def basisPresent (bases : QuantityBasisMemory) (id : QuantityBasisId) : Bool :=
  match QuantityBasisMemory.findById? bases id with
  | some _ => true
  | none => false

private def targetUsed
    (corrections : QuantityBasisCorrectionMemory)
    (id : QuantityBasisId) : Bool :=
  corrections.corrections.any fun correction => decide (correction.target = id)

private def uniqueTargets : List QuantityBasisCorrection → Bool
  | [] => true
  | correction :: rest =>
      !(rest.any fun other => decide (other.target = correction.target)) &&
        uniqueTargets rest

private def uniqueReplacements : List QuantityBasisCorrection → Bool
  | [] => true
  | correction :: rest =>
      !(rest.any fun other => decide (other.replacement = correction.replacement)) &&
        uniqueReplacements rest

private def closedReferences
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : Bool :=
  corrections.corrections.all fun correction =>
    basisPresent bases correction.target && basisPresent bases correction.replacement

private def preservesCoordinate
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : Bool :=
  corrections.corrections.all fun correction =>
    match QuantityBasisMemory.findById? bases correction.target,
        QuantityBasisMemory.findById? bases correction.replacement with
    | some target, some replacement => decide (target.coordinate = replacement.coordinate)
    | _, _ => false

private def nextReplacement? :
    List QuantityBasisCorrection → QuantityBasisId → Option QuantityBasisId
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then
        some correction.replacement
      else
        nextReplacement? rest id

private def pathAcyclicFrom
    (corrections : List QuantityBasisCorrection)
    (start : QuantityBasisId) : Nat → QuantityBasisId → Bool
  | 0, _ => true
  | fuel + 1, current =>
      match nextReplacement? corrections current with
      | none => true
      | some next =>
          if next = start then
            false
          else
            pathAcyclicFrom corrections start fuel next

private def acyclic (corrections : QuantityBasisCorrectionMemory) : Bool :=
  corrections.corrections.all fun correction =>
    pathAcyclicFrom
      corrections.corrections correction.target corrections.corrections.length correction.target

/-- Historical basis facts remain stored; only correction targets leave the current frontier. -/
def quantityBasisFrontier
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : List QuantityBasis :=
  bases.bases.filter fun basis => !(targetUsed corrections basis.id)

private def uniqueCoordinates : List QuantityBasis → Bool
  | [] => true
  | basis :: rest =>
      !(rest.any fun other => decide (other.coordinate = basis.coordinate)) &&
        uniqueCoordinates rest

/--
Admit only a finite collection of disjoint same-coordinate correction paths.

Production is deliberately stricter than the Application 009 probe in one
respect: replacement identity must also be unique across correction facts. Two
corrections may therefore not smuggle a multi-parent resolution through a
shared replacement basis. If such settlement is later needed, it should earn an
explicit resolution relation rather than changing Correction meaning.
-/
def quantityBasisFrontierAdmissible
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : Bool :=
  uniqueTargets corrections.corrections &&
    uniqueReplacements corrections.corrections &&
    closedReferences bases corrections &&
    preservesCoordinate bases corrections &&
    acyclic corrections &&
    uniqueCoordinates (quantityBasisFrontier bases corrections)

/-- Return one current basis frontier only when all correction premises hold. -/
def admittedQuantityBasisFrontier?
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : Option (List QuantityBasis) :=
  if quantityBasisFrontierAdmissible bases corrections then
    some (quantityBasisFrontier bases corrections)
  else
    none

end Loam.Application
