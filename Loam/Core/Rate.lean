import Init.Data.Rat.Lemmas
import Loam.Core.Measure

namespace Loam.Core

set_option autoImplicit false

/--
An exact rational quantity at one measure coordinate.

This is an intermediate calculation value. Unlike `Amount`, it is not yet a
settled integer number of indivisible quanta and therefore cannot be published
as an `Amount` without an explicit quantization step.
-/
structure RationalAmount (measure : MeasureId) where
  quanta : Rat
deriving Repr, DecidableEq

namespace RationalAmount

/-- Lift an exact rational number of quanta into one measure coordinate. -/
def ofRat {measure : MeasureId} (quanta : Rat) : RationalAmount measure :=
  ⟨quanta⟩

@[simp] theorem quanta_ofRat
    {measure : MeasureId} (quanta : Rat) :
    (ofRat (measure := measure) quanta).quanta = quanta :=
  rfl

end RationalAmount

/--
An exact rational relation from one measure coordinate to another.

`Rate` is an overlay relation, not an event kind. It deliberately carries no
assumption that the relation is a price, exchange rate, valuation authority,
invertible relation, or time-stable fact.
-/
structure Rate (from to : MeasureId) where
  ratio : Rat
deriving Repr, DecidableEq

namespace Rate

/-- Construct an exact relation value. -/
def ofRat {from to : MeasureId} (ratio : Rat) : Rate from to :=
  ⟨ratio⟩

/-- Apply a relation without quantizing the target result. -/
def apply {from to : MeasureId}
    (rate : Rate from to) (amount : Amount from) : RationalAmount to :=
  RationalAmount.ofRat (Rat.ofInt amount.quantity.quanta * rate.ratio)

@[simp] theorem quanta_apply
    {from to : MeasureId} (rate : Rate from to) (amount : Amount from) :
    (rate.apply amount).quanta =
      Rat.ofInt amount.quantity.quanta * rate.ratio :=
  rfl

end Rate

/-- A caller-supplied policy that chooses settled integer quanta explicitly. -/
abbrev Quantizer := Rat → Int

/--
The result of explicitly quantizing a rational target amount.

The retained remainder stays at the same measure coordinate, so information
lost from the settled integer amount remains first-class rather than vanishing
inside an implicit rounding operation.
-/
structure Quantized (measure : MeasureId) where
  amount : Amount measure
  remainder : RationalAmount measure
deriving Repr, DecidableEq

namespace RationalAmount

/--
Choose settled integer quanta with an explicit policy and retain the exact
rational remainder.
-/
def quantize {measure : MeasureId}
    (choose : Quantizer) (value : RationalAmount measure) : Quantized measure :=
  let settled := choose value.quanta
  {
    amount := Amount.ofQuantity (Quantity.ofQuanta settled)
    remainder := ofRat (value.quanta - Rat.ofInt settled)
  }

/-- Quantization never silently loses the discarded rational part. -/
@[simp] theorem quantize_reconstructs
    {measure : MeasureId} (choose : Quantizer) (value : RationalAmount measure) :
    Rat.ofInt (quantize choose value).amount.quantity.quanta +
        (quantize choose value).remainder.quanta = value.quanta := by
  simp [quantize]

end RationalAmount

end Loam.Core
