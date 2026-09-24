import Loam.ActualAuthority
import Loam.CapacityAuthority
import Loam.MeasurePresentation
import Loam.Persistence.CurrentQuantityAnchorPersistence
import Loam.Persistence.ScheduledLifecyclePersistence
import Loam.WriterOwnership

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
Scheduled -> Actual -> CurrentQuantityAnchor -> Capacity
```

The authority images are re-read only after those ownership scopes are held.
The presentation file is then replaced atomically through a sibling stage.
-/

def configPath (root : System.FilePath) : System.FilePath :=
  root / "config" / Loam.MeasurePresentation.configFileName

private def scheduledPath (root : System.FilePath) : System.FilePath :=
  root / "scheduled.loam"

private def anchorPath (root : System.FilePath) : System.FilePath :=
  root / "current-quantity-anchor.loam"

private def capacityPath (root : System.FilePath) : System.FilePath :=
  root / "capacity.loam"

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

private def loadScheduled
    (path : System.FilePath) :
    IO (Except String Loam.Persistence.ScheduledLifecycleImage) := do
  let some image ← Loam.Persistence.loadScheduledLifecycleImage? path
    | return .error
        "loam: Scheduled lifecycle authority is missing, malformed, or unsupported"
  return .ok image

private def loadAnchorOrEmpty
    (path : System.FilePath) :
    IO (Except String Loam.CurrentQuantityAnchor.Evidence) := do
  if ← path.pathExists then
    match ← Loam.Persistence.loadCurrentQuantityAnchor? path with
    | some evidence => return .ok evidence
    | none =>
        return .error
          "loam: current quantity anchor authority is malformed or unsupported"
  else
    return .ok Loam.CurrentQuantityAnchor.Evidence.empty

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
    (root scheduledFile anchorFile capacityFile : System.FilePath)
    (measure : MeasureId)
    (scale : Nat) : IO (Except String Unit) := do
  let actual ←
    match ← Loam.ActualAuthority.loadActual? root with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let scheduled ←
    match ← loadScheduled scheduledFile with
    | .ok image => pure image
    | .error message => return .error message
  let anchor ←
    match ← loadAnchorOrEmpty anchorFile with
    | .ok evidence => pure evidence
    | .error message => return .error message
  let capacity ←
    match ← Loam.CapacityAuthority.loadOrEmpty capacityFile with
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

The ownership order corresponds to the qualified D3 protocol and is compatible
with current production multi-authority paths:
Scheduled -> Actual -> CurrentQuantityAnchor -> Capacity.
-/
def setScale
    (root : System.FilePath)
    (measure : MeasureId)
    (scale : Nat) : IO (Except String Unit) := do
  if !Loam.Persistence.validToken measure.token then
    return .error "loam: Measure token is not persistable"
  if scale > 9 then
    return .error "loam: Measure presentation scale must be between 0 and 9"
  let scheduledFile := scheduledPath root
  let currentAnchorFile := anchorPath root
  let currentCapacityFile := capacityPath root
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.ActualAuthority.withActualOwnership root <|
      Loam.WriterOwnership.withOwnership currentAnchorFile <|
        Loam.WriterOwnership.withOwnership currentCapacityFile <|
          setScaleUnderOwnership
            root scheduledFile currentAnchorFile currentCapacityFile measure scale

end Loam.MeasurePresentationAuthority
