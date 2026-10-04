import Loam.Authority.ActualAuthority
import Loam.Authority.CapacityAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.Authority.ScheduledLifecycleAuthority
import Loam.HouseholdPaths
import Loam.Presentation.MeasurePresentation

namespace Loam.MeasurePresentationAuthority

open Loam.Core

set_option autoImplicit false

/-!
# Measure presentation administration

A Measure presentation scale is editable only before any retained household
quantity uses that Measure. Once retained quantity evidence exists, changing the
scale would reinterpret already-retained integer quanta and therefore requires a
separate explicit migration operation.

The production administration boundary closes the check/update race by owning
all current retained-quantity authority families in one fixed compatible order:

```text
Scheduled -> Actual -> HouseholdImage
```

Scheduled, Capacity, and current support are re-read from HouseholdImage only
after shared Household ownership is held. The presentation file is then replaced
atomically through a sibling stage.
-/

def configPath (root : System.FilePath) : System.FilePath :=
  Loam.HouseholdPaths.measurePresentation root

private def usedInActual
    (evidence : Loam.ActualEvidence) (measure : MeasureId) : Bool :=
  evidence.events.events.any fun event =>
    event.effects.any fun effect => effect.measure == measure

private def usedInScheduled
    (image : Loam.Persistence.ScheduledLifecycleImage)
    (measure : MeasureId) : Bool :=
  image.scheduled.occurrences.any fun occurrence =>
    occurrence.measure == measure

private def usedInCapacity
    (image : Loam.CapacityAuthority.Image)
    (measure : MeasureId) : Bool :=
  image.movements.movements.any fun movement =>
    movement.measure == measure

private def usedInAnchor
    (evidence : Loam.CurrentQuantityAnchor.Evidence)
    (measure : MeasureId) : Bool :=
  evidence.assertions.any fun assertion =>
    assertion.coordinate.measure == measure

private def replaceScale
    (metadata : List Loam.MeasurePresentation.Metadata)
    (measure : MeasureId)
    (scale : Nat) : List Loam.MeasurePresentation.Metadata :=
  if metadata.any fun row => row.measure == measure then
    metadata.map fun row =>
      if row.measure == measure then { row with scale := scale } else row
  else
    metadata ++ [{ measure := measure, scale := scale }]

private def publishMetadata
    (path : System.FilePath)
    (metadata : List Loam.MeasurePresentation.Metadata) :
    IO (Except String Unit) := do
  let text ←
    match Loam.MeasurePresentation.encode? metadata with
    | some encoded => pure encoded
    | none => return .error "loam: Measure presentation encoder rejected metadata"
  if let some parent := path.parent then
    IO.FS.createDirAll parent
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  try
    IO.FS.writeFile stage text
    let staged ← IO.FS.readFile stage
    if staged != text then
      return .error "loam: staged Measure presentation bytes did not round-trip"
    match Loam.MeasurePresentation.decode? staged with
    | none =>
        return .error "loam: staged Measure presentation failed typed decoding"
    | some decoded =>
        if decoded = metadata then
          IO.FS.rename stage path
          return .ok ()
        else
          return .error "loam: staged Measure presentation changed admitted metadata"
  catch error =>
    return .error ("loam: Measure presentation publication failed: " ++ error.toString)

private def setScaleUnderOwnership
    (root : System.FilePath)
    (measure : MeasureId)
    (scale : Nat) : IO (Except String Unit) := do
  let actual ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let scheduled ←
    match ← Loam.ScheduledLifecycleAuthority.loadHouseholdCurrent? root with
    | .ok image => pure image
    | .error message => return .error message
  let anchor ←
    match ← Loam.CurrentSupportAuthority.loadHousehold? root with
    | .ok observed => pure observed.snapshot.anchor
    | .error message => return .error message
  let capacity ←
    match ← Loam.CapacityAuthority.loadHouseholdOrEmpty root with
    | .ok image => pure image
    | .error message => return .error message
  let metadata ←
    match ← Loam.MeasurePresentation.loadMetadata root with
    | .ok rows => pure rows
    | .error message => return .error message

  let currentScale := Loam.MeasurePresentation.scaleFor metadata measure
  if currentScale = scale then
    return .ok ()

  let used :=
    usedInActual actual measure ||
    usedInScheduled scheduled measure ||
    usedInAnchor anchor measure ||
    usedInCapacity capacity measure
  if used then
    return .error
      ("loam: Measure '" ++ measure.token ++
        "' already has retained household quantity; changing its scale requires explicit migration")

  publishMetadata (configPath root) (replaceScale metadata measure scale)

/--
Set one Measure presentation scale through the production administration boundary.

Scale 0..9 and a persistable Measure token are accepted. Re-selecting the current
effective scale is a harmless no-op, including the historical missing-config
scale-0 convention. Any real scale change is refused once Actual, Scheduled,
CurrentQuantityAnchor, or Capacity retains that Measure.

After Scheduled lifecycle cutover the production ownership order is:
Actual -> HouseholdImage.

The one Household lock freezes Scheduled, CurrentQuantityAnchor, and Capacity
together while the Actual lock excludes concurrent Actual and Scheduled writers.
-/
def setScale
    (root : System.FilePath)
    (measure : MeasureId)
    (scale : Nat) : IO (Except String Unit) := do
  if !Loam.Persistence.validToken measure.token then
    return .error "loam: Measure token is not persistable"
  if scale > 9 then
    return .error "loam: Measure presentation scale must be between 0 and 9"
  Loam.ActualAuthority.withActualOwnership root <|
    Loam.HouseholdAuthority.withOwnership root <|
      setScaleUnderOwnership root measure scale

end Loam.MeasurePresentationAuthority
