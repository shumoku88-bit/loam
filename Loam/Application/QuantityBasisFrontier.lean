import Loam.Core.QuantityBasisCorrectionMemory
import Loam.Application.ReplacementFrontier

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

private def correctionEdges
    (corrections : QuantityBasisCorrectionMemory) :
    List (ReplacementFrontier.Edge QuantityBasisId) :=
  corrections.corrections.map fun correction =>
    { source := correction.target, successor := correction.replacement }

private def basisPresent (bases : QuantityBasisMemory) (id : QuantityBasisId) : Bool :=
  (QuantityBasisMemory.findById? bases id).isSome

private def preservesCoordinate
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : Bool :=
  corrections.corrections.all fun correction =>
    match QuantityBasisMemory.findById? bases correction.target,
        QuantityBasisMemory.findById? bases correction.replacement with
    | some target, some replacement => decide (target.coordinate = replacement.coordinate)
    | _, _ => false

/-- Historical basis facts remain stored; only correction targets leave the current frontier. -/
def quantityBasisFrontier
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : List QuantityBasis :=
  ReplacementFrontier.frontier
    QuantityBasis.id bases.bases (correctionEdges corrections)

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
  ReplacementFrontier.structurallyAdmissible
      (basisPresent bases) (correctionEdges corrections) &&
    preservesCoordinate bases corrections &&
    uniqueCoordinates (quantityBasisFrontier bases corrections)

/-- Return one current basis frontier only when all correction premises hold. -/
def admittedQuantityBasisFrontier?
    (bases : QuantityBasisMemory)
    (corrections : QuantityBasisCorrectionMemory) : Option (List QuantityBasis) :=
  if quantityBasisFrontierAdmissible bases corrections then
    some (quantityBasisFrontier bases corrections)
  else
    none

/-- Empty raw basis and correction memories admit the empty current frontier. -/
@[simp] theorem admittedQuantityBasisFrontier?_empty :
    admittedQuantityBasisFrontier?
      { bases := [], idNodup := by simp }
      { corrections := [], idNodup := by simp } = some [] := by
  rfl

end Loam.Application
