import Loam.Core.QuantityBasisMemory
import Loam.Core.Event

namespace Loam.Observation091

open Loam.Core

set_option autoImplicit false

/--
Experiment-local evidence for one coordinate that begins at exact zero
immediately before one retained Event identity.

This is not a production fact. Observation 091 only needs enough shape to ask
whether it can feed the same projection arithmetic as `QuantityBasis` without
becoming the same canonical fact.
-/
structure FirstEventAdmission where
  coordinate : EffectCoordinate
  originEvent : EventId
deriving Repr, DecidableEq

/--
A derived projection input, not canonical storage.

The two constructors deliberately retain why the origin is valid. They share an
arithmetic interface without erasing application-start versus first-event
provenance.
-/
inductive OriginView where
  | applicationStart (coordinate : EffectCoordinate) (quantity : Quantity)
  | beforeFirstEvent (coordinate : EffectCoordinate) (originEvent : EventId)
deriving Repr, DecidableEq

namespace OriginView

/-- Coordinate selected by this derived origin view. -/
def coordinate : OriginView → EffectCoordinate
  | .applicationStart coordinate _ => coordinate
  | .beforeFirstEvent coordinate _ => coordinate

/-- Exact quantity at the selected origin boundary. -/
def quantity : OriginView → Quantity
  | .applicationStart _ quantity => quantity
  | .beforeFirstEvent _ _ => 0

/-- Stable Event evidence exists only for the first-event origin form. -/
def originEvent? : OriginView → Option EventId
  | .applicationStart _ _ => none
  | .beforeFirstEvent _ originEvent => some originEvent

end OriginView

/-- Adapt the existing production basis meaning without changing it. -/
def fromBasis (basis : QuantityBasis) : OriginView :=
  .applicationStart basis.coordinate basis.quantity

/-- Adapt first-event admission while preserving its stable Event evidence. -/
def fromAdmission (admission : FirstEventAdmission) : OriginView :=
  .beforeFirstEvent admission.coordinate admission.originEvent

/--
One quantity contribution already scoped to activity after the supplied origin.

The word `scoped` is intentional. Observation 091 does not claim that current
`EventMemory` can derive this scope for a first-event origin.
-/
structure ScopedActivity where
  coordinate : EffectCoordinate
  quantity : Quantity
deriving Repr, DecidableEq

/--
Common arithmetic once an origin and correctly scoped activity are both known.

A coordinate mismatch is refused instead of silently composing unrelated facts.
-/
def currentWithScopedActivity?
    (origin : OriginView)
    (activity : ScopedActivity) : Option Quantity :=
  if origin.coordinate = activity.coordinate then
    some (origin.quantity + activity.quantity)
  else
    none

@[simp] theorem fromBasis_coordinate (basis : QuantityBasis) :
    (fromBasis basis).coordinate = basis.coordinate := by
  rfl

@[simp] theorem fromBasis_quantity (basis : QuantityBasis) :
    (fromBasis basis).quantity = basis.quantity := by
  rfl

@[simp] theorem fromBasis_hasNoOriginEvent (basis : QuantityBasis) :
    (fromBasis basis).originEvent? = none := by
  rfl

@[simp] theorem fromAdmission_coordinate (admission : FirstEventAdmission) :
    (fromAdmission admission).coordinate = admission.coordinate := by
  rfl

@[simp] theorem fromAdmission_quantity_zero (admission : FirstEventAdmission) :
    (fromAdmission admission).quantity = 0 := by
  rfl

@[simp] theorem fromAdmission_originEvent (admission : FirstEventAdmission) :
    (fromAdmission admission).originEvent? = some admission.originEvent := by
  rfl

private def wallet : LocusId := ⟨"wallet"⟩
private def jpy : MeasureId := ⟨"jpy"⟩
private def walletJpy : EffectCoordinate := ⟨wallet, jpy⟩
private def otherJpy : EffectCoordinate := ⟨⟨"other"⟩, jpy⟩

private def sampleBasis : QuantityBasis :=
  QuantityBasis.ofQuantity
    ⟨"basis-wallet"⟩ wallet jpy (Quantity.ofQuanta 500)

private def zeroBasis : QuantityBasis :=
  QuantityBasis.ofQuantity
    ⟨"basis-wallet-zero"⟩ wallet jpy 0

private def sampleAdmission : FirstEventAdmission :=
  ⟨walletJpy, ⟨"event-origin"⟩⟩

private def postOriginActivity : ScopedActivity :=
  ⟨walletJpy, Quantity.ofQuanta 100⟩

/--
A deliberately unscoped whole-memory aggregate for the same coordinate.
It includes 40 quanta that, in this specimen, belong before the first-event
origin plus 100 quanta after it.
-/
private def wholeRetainedActivity : ScopedActivity :=
  ⟨walletJpy, Quantity.ofQuanta 140⟩

/-- Existing application-start basis arithmetic fits the common adapter. -/
example :
    currentWithScopedActivity? (fromBasis sampleBasis) postOriginActivity =
      some (Quantity.ofQuanta 600) := by
  native_decide

/-- A first-event exact-zero origin also fits once activity is correctly scoped. -/
example :
    currentWithScopedActivity? (fromAdmission sampleAdmission) postOriginActivity =
      some (Quantity.ofQuanta 100) := by
  native_decide

/--
Feeding the first-event origin a whole retained aggregate produces a different
answer. The arithmetic adapter therefore cannot itself decide the post-origin
activity scope.
-/
example :
    currentWithScopedActivity? (fromAdmission sampleAdmission) wholeRetainedActivity =
      some (Quantity.ofQuanta 140) := by
  native_decide

/-- A zero application-start basis still does not become first-event evidence. -/
example : (fromBasis zeroBasis).originEvent? = none := by
  native_decide

example : (fromAdmission sampleAdmission).originEvent? = some ⟨"event-origin"⟩ := by
  native_decide

/-- Unrelated coordinate evidence is refused at the common arithmetic boundary. -/
example :
    currentWithScopedActivity?
      (fromAdmission sampleAdmission)
      ⟨otherJpy, Quantity.ofQuanta 100⟩ = none := by
  native_decide

end Loam.Observation091
