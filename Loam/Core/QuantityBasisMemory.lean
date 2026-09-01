import Loam.Core.Event

namespace Loam.Core

set_option autoImplicit false

/-- Stable identity for one quantity-basis fact. -/
structure QuantityBasisId where
  token : String
deriving Repr, DecidableEq

/--
One exact quantity already present at one locus/measure coordinate when the
selected application image begins.

This is deliberately not an Event: it does not claim that the quantity changed
at the application origin. The basis identity is independent of its coordinate
so a later append-only revision relation can refer to one historical basis fact
without using list position or the coordinate itself as identity.
-/
structure QuantityBasis where
  id : QuantityBasisId
  locus : LocusId
  amount : SomeAmount
deriving Repr, DecidableEq

namespace QuantityBasis

/-- Construct one basis fact from explicit neutral quantity coordinates. -/
def ofQuantity
    (id : QuantityBasisId)
    (locus : LocusId)
    (measure : MeasureId)
    (quantity : Quantity) : QuantityBasis :=
  ⟨id, locus, SomeAmount.ofQuantity measure quantity⟩

/-- Recover the exact measure coordinate. -/
def measure (basis : QuantityBasis) : MeasureId :=
  basis.amount.measure

/-- Recover the exact signed quantity. -/
def quantity (basis : QuantityBasis) : Quantity :=
  basis.amount.quantity

/-- Project one basis fact onto the same neutral coordinate used by Effects. -/
def coordinate (basis : QuantityBasis) : EffectCoordinate :=
  ⟨basis.locus, basis.measure⟩

end QuantityBasis

/--
Append-only memory for quantity-basis facts.

Only basis identity is unique here. Several historical basis facts may share one
`Locus × Measure` coordinate because Application 009 showed that append-only
revision necessarily retains both an old basis and its replacement. Which basis
is current is therefore not a raw-memory law.

List position is deterministic representation only and has no temporal,
priority, authority, or winner meaning.
-/
structure QuantityBasisMemory where
  bases : List QuantityBasis
  idNodup : (bases.map QuantityBasis.id).Nodup

namespace QuantityBasisMemory

/-- Admit runtime basis facts only when stable basis identity is unique. -/
def ofBases? (bases : List QuantityBasis) : Option QuantityBasisMemory :=
  if h : (bases.map QuantityBasis.id).Nodup then
    some { bases := bases, idNodup := h }
  else
    none

/-- Add one raw basis fact without assigning coordinate-level winner semantics. -/
def add?
    (memory : QuantityBasisMemory)
    (basis : QuantityBasis) : Option QuantityBasisMemory :=
  ofBases? (memory.bases ++ [basis])

private def findBasisById? :
    List QuantityBasis → QuantityBasisId → Option QuantityBasis
  | [], _ => none
  | basis :: rest, id =>
      if basis.id = id then
        some basis
      else
        findBasisById? rest id

/-- Find one historical basis fact by stable basis identity. -/
def findById?
    (memory : QuantityBasisMemory)
    (id : QuantityBasisId) : Option QuantityBasis :=
  findBasisById? memory.bases id

@[simp] theorem ofBases?_nil :
    ofBases? [] = some { bases := [], idNodup := by simp } := by
  simp [ofBases?]

@[simp] theorem ofBases?_singleton (basis : QuantityBasis) :
    ofBases? [basis] = some { bases := [basis], idNodup := by simp } := by
  simp [ofBases?]

@[simp] theorem add?_empty (basis : QuantityBasis) :
    add? { bases := [], idNodup := by simp } basis =
      some { bases := [basis], idNodup := by simp } := by
  simp [add?, ofBases?]

end QuantityBasisMemory

end Loam.Core
