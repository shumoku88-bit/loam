import Std

set_option autoImplicit false

namespace Loam.Application006

universe u v w

/--
A deliberately small image of the already admitted fact families.
The element types are abstract because this experiment is about extension
shape, not about Event or Correction internals.
-/
structure ExistingImage (Event : Type u) (Correction : Type v) where
  events : List Event
  corrections : List Correction

/--
One later fact family extends the image without changing the representation of
already existing families and without introducing a universal fact union.
-/
structure ExtendedImage
    (Event : Type u) (Correction : Type v) (LaterFact : Type w) where
  events : List Event
  corrections : List Correction
  laterFacts : List LaterFact

/-- Extend an existing image with an independently typed later fact family. -/
def extend
    {Event : Type u} {Correction : Type v} {LaterFact : Type w}
    (base : ExistingImage Event Correction)
    (laterFacts : List LaterFact) : ExtendedImage Event Correction LaterFact :=
  {
    events := base.events
    corrections := base.corrections
    laterFacts := laterFacts
  }

/-- Forget the later family and recover exactly the pre-extension image. -/
def forgetLater
    {Event : Type u} {Correction : Type v} {LaterFact : Type w}
    (image : ExtendedImage Event Correction LaterFact) : ExistingImage Event Correction :=
  {
    events := image.events
    corrections := image.corrections
  }

/-- A representative query that depends only on the pre-existing fact families. -/
def existingProjection
    {Event : Type u} {Correction : Type v}
    (image : ExistingImage Event Correction) : Nat :=
  image.events.length + image.corrections.length

/-- Read the same old query from an extended image by forgetting the new family. -/
def extendedExistingProjection
    {Event : Type u} {Correction : Type v} {LaterFact : Type w}
    (image : ExtendedImage Event Correction LaterFact) : Nat :=
  existingProjection (forgetLater image)

/-- Adding an arbitrary later family is conservative for the old image. -/
theorem forget_extend
    {Event : Type u} {Correction : Type v} {LaterFact : Type w}
    (base : ExistingImage Event Correction)
    (laterFacts : List LaterFact) :
    forgetLater (extend base laterFacts) = base := by
  rfl

/-- Existing Event membership is unchanged by adding the later family. -/
theorem events_preserved
    {Event : Type u} {Correction : Type v} {LaterFact : Type w}
    (base : ExistingImage Event Correction)
    (laterFacts : List LaterFact) :
    (extend base laterFacts).events = base.events := by
  rfl

/-- Existing Correction membership is unchanged by adding the later family. -/
theorem corrections_preserved
    {Event : Type u} {Correction : Type v} {LaterFact : Type w}
    (base : ExistingImage Event Correction)
    (laterFacts : List LaterFact) :
    (extend base laterFacts).corrections = base.corrections := by
  rfl

/--
Any old projection factored through the old image remains unchanged after the
extension. This is the small law needed before LOAM starts daily-use growth.
-/
theorem existing_projection_preserved
    {Event : Type u} {Correction : Type v} {LaterFact : Type w}
    (base : ExistingImage Event Correction)
    (laterFacts : List LaterFact) :
    extendedExistingProjection (extend base laterFacts) = existingProjection base := by
  rfl

end Loam.Application006
