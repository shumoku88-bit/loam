import Loam.Core.EventCorrection

namespace Loam.Examples.PhysicalInventory

open Loam.Core

set_option autoImplicit false

/-!
# Non-household Core probe: physical inventory

This file deliberately models no money, account, budget, debit/credit role, or
household party. It asks whether the existing low-level LOAM vocabulary can
describe one physical book-copy movement and an explicit correction without
changing Core.
-/

def shelfA : LocusId := ⟨"inventory:shelf-a"⟩
def shelfB : LocusId := ⟨"inventory:shelf-b"⟩
def desk : LocusId := ⟨"inventory:desk"⟩

def bookCopies : MeasureId := ⟨"inventory:book-copy"⟩

def oneBook : Quantity := Quantity.ofQuanta 1
def minusOneBook : Quantity := Quantity.ofQuanta (-1)

def recordedMoveId : EventId := ⟨"inventory:move-recorded"⟩
def correctedMoveId : EventId := ⟨"inventory:move-corrected"⟩

/--
The first observation says one book-copy left shelf A and appeared on the desk.
Both Effects remain anonymous because nothing in this probe needs to reference
either Effect independently.
-/
def recordedMove : Event :=
  { id := recordedMoveId
    effects :=
      [ Effect.ofAnonymousQuantity shelfA bookCopies minusOneBook
      , Effect.ofAnonymousQuantity desk bookCopies oneBook
      ]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

/--
The corrected observation says the departure was actually from shelf B. The
destination observation is unchanged.
-/
def correctedMove : Event :=
  { id := correctedMoveId
    effects :=
      [ Effect.ofAnonymousQuantity shelfB bookCopies minusOneBook
      , Effect.ofAnonymousQuantity desk bookCopies oneBook
      ]
    keyNodup := by
      simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

def moveCorrection : EventCorrection :=
  { target := recordedMoveId
    replacement := correctedMoveId }

/-- Both observations remain retained as facts; correction is a separate edge. -/
def observedHistory : EventMemory :=
  { events := [recordedMove, correctedMove]
    idNodup := by
      simp [recordedMove, correctedMove, recordedMoveId, correctedMoveId] }

private theorem recordedMove_shelfA :
    Event.quantityAt recordedMove shelfA bookCopies = minusOneBook := by
  simp [recordedMove, shelfA, desk, bookCopies, oneBook, minusOneBook,
    Event.quantityAt, Effect.coordinate, Effect.ofAnonymousQuantity,
    Effect.measure, Effect.quantity, SomeAmount.measure, SomeAmount.quantity, SomeAmount.ofQuantity,
    Amount.ofQuantity, Quantity.ofQuanta]

private theorem recordedMove_desk :
    Event.quantityAt recordedMove desk bookCopies = oneBook := by
  simp [recordedMove, shelfA, desk, bookCopies, oneBook, minusOneBook,
    Event.quantityAt, Effect.coordinate, Effect.ofAnonymousQuantity,
    Effect.measure, Effect.quantity, SomeAmount.measure, SomeAmount.quantity, SomeAmount.ofQuantity,
    Amount.ofQuantity, Quantity.ofQuanta]

private theorem correctedMove_shelfA :
    Event.quantityAt correctedMove shelfA bookCopies = Quantity.ofQuanta 0 := by
  simp [correctedMove, shelfA, shelfB, desk, bookCopies, oneBook, minusOneBook,
    Event.quantityAt, Effect.coordinate, Effect.ofAnonymousQuantity,
    Effect.measure, Effect.quantity, SomeAmount.measure, SomeAmount.quantity, SomeAmount.ofQuantity,
    Amount.ofQuantity, Quantity.ofQuanta]

private theorem correctedMove_shelfB :
    Event.quantityAt correctedMove shelfB bookCopies = minusOneBook := by
  simp [correctedMove, shelfB, desk, bookCopies, oneBook, minusOneBook,
    Event.quantityAt, Effect.coordinate, Effect.ofAnonymousQuantity,
    Effect.measure, Effect.quantity, SomeAmount.measure, SomeAmount.quantity, SomeAmount.ofQuantity,
    Amount.ofQuantity, Quantity.ofQuanta]

/--
The concrete physical movement conserves book-copy quantity across its source
and destination. This law is proved about the example rather than built into
Locus, Effect, or Event.
-/
theorem recordedMove_conserves_bookCopies :
    Event.quantityAt recordedMove shelfA bookCopies +
        Event.quantityAt recordedMove desk bookCopies =
      (0 : Quantity) := by
  rw [recordedMove_shelfA, recordedMove_desk]
  rfl

/--
The correction edge closes over retained Events without mutating or deleting the
original observation.
-/
theorem correction_projects :
    (EventCorrection.project? observedHistory moveCorrection).isSome = true := by
  simp [EventCorrection.project?, observedHistory, moveCorrection,
    EventMemory.findById?, FiniteKeyed.findBy?, recordedMove, correctedMove,
    recordedMoveId, correctedMoveId]

/--
After correction, the source coordinate can be stated as shelf B without
changing any Core vocabulary.
-/
theorem corrected_source_is_shelfB :
    Event.quantityAt correctedMove shelfB bookCopies = minusOneBook :=
  correctedMove_shelfB

/--
The original raw observation remains inspectable independently of the correction
edge.
-/
theorem original_source_remains_shelfA :
    Event.quantityAt recordedMove shelfA bookCopies = minusOneBook :=
  recordedMove_shelfA

end Loam.Examples.PhysicalInventory
