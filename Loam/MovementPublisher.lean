import Loam.ActualDate
import Loam.Persistence.ActualValidityPersistence
import Loam.Persistence.EventDescriptionPersistence
import Loam.Persistence.LocusAdmissionPersistence
import Loam.Persistence.OpenRelationPersistence
import Loam.Persistence.RelationDischargePersistence
import Loam.MovementAdmission
import Loam.MovementManifestAuthority
import Loam.Persistence
import Loam.WriterOwnership

namespace Loam.MovementPublisher

set_option autoImplicit false

private def loadEventDescriptionMemoryOrEmpty?
    (path : System.FilePath) : IO (Option Loam.Core.EventDescriptionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventDescriptionMemory? path
  else
    return some Loam.Core.EventDescriptionMemory.empty

private def loadOpenRelationUnitsOrEmpty?
    (path : System.FilePath) : IO (Option (List Loam.Core.RelationUnit)) := do
  if ← path.pathExists then
    Loam.Persistence.loadOpenRelationUnits? path
  else
    return some []

private def loadRelationDischargesOrEmpty?
    (path : System.FilePath) : IO (Option (List Loam.Core.RelationDischarge)) := do
  if ← path.pathExists then
    Loam.Persistence.loadRelationDischarges? path
  else
    return some []

private def loadEventMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventMemory? path
  else
    return Loam.Core.EventMemory.ofEvents? []

/--
Re-read current canonical state and publish one already-collected draft while
holding the existing writer-ownership boundary.

Fresh Event/RelationUnit identities are chosen by `MovementAdmission.admit?`, not
while the user types. The same typed admission seam is usable by a different
physical publisher without teaching admission about sidecars or authority
selectors.

The isolated sidecar fixture additionally requires an explicit sibling Locus
admission vocabulary. It is loaded here, under the same writer ownership as the
Event memory, immediately before semantic admission. Missing policy therefore
fails closed rather than being reconstructed from historical completion hints.

Publication order remains the currently qualified sidecar protocol:

```text
validity / optional description supporting evidence
-> required positive RelationUnit stream update when any
-> required RelationDischarge stream update when any
-> Event last as authority commit
```

The relative order among supporting families is not a cross-stream transaction.
If Event publication fails after a relation or discharge update, retained rows
remain raw inert provenance under the existing sidecar recovery rules.
-/
private def publishDraftUnderOwnership
    (memoryPath : String)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Loam.Core.EventId) := do
  let memoryFile := System.FilePath.mk memoryPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
  let descriptionFile := Loam.Persistence.eventDescriptionPathForEventMemory memoryFile
  let relationFile := Loam.Persistence.openRelationUnitPathForEventMemory memoryFile
  let dischargeFile := Loam.Persistence.relationDischargePathForEventMemory memoryFile
  let locusAdmissionFile :=
    Loam.Persistence.locusAdmissionVocabularyPathForEventMemory memoryFile
  match ← loadEventMemoryForEntry? memoryFile with
  | none =>
      return .error "loam: malformed or unsupported event-memory file"
  | some memory =>
      match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
      | none =>
          return .error "loam: malformed or unsupported actual-validity history"
      | some history =>
          match ← loadEventDescriptionMemoryOrEmpty? descriptionFile with
          | none =>
              return .error "loam: malformed or unsupported event-description memory"
          | some descriptions =>
              match ← loadOpenRelationUnitsOrEmpty? relationFile with
              | none =>
                  return .error "loam: malformed or unsupported open-relation stream"
              | some relations =>
                  match ← loadRelationDischargesOrEmpty? dischargeFile with
                  | none =>
                      return .error "loam: malformed or unsupported relation-discharge stream"
                  | some discharges =>
                      if !(← locusAdmissionFile.pathExists) then
                        return .error "loam: Locus admission vocabulary is missing"
                      else
                        match ← Loam.Persistence.loadLocusAdmissionVocabulary? locusAdmissionFile with
                        | none =>
                            return .error "loam: malformed or unsupported Locus admission vocabulary"
                        | some locusAdmission =>
                            let world : Loam.MovementAdmission.World := {
                              events := memory
                              validity := history
                              descriptions := descriptions
                              relations := relations
                              discharges := discharges
                              locusAdmission := locusAdmission
                            }
                            match Loam.MovementAdmission.admit? world draft with
                            | Except.error message =>
                                return .error message
                            | Except.ok admitted =>
                                if ← Loam.Persistence.saveActualValidityHistory?
                                    validityFile admitted.world.validity then
                                  let descriptionPublished ←
                                    match draft.description with
                                    | none => pure true
                                    | some _ =>
                                        Loam.Persistence.saveEventDescriptionMemory?
                                          descriptionFile admitted.world.descriptions
                                  if !descriptionPublished then
                                    return .error "loam: description was not published; the already-published date evidence remains inert"
                                  else
                                    let relationPublished ←
                                      if admitted.newRelations.isEmpty then
                                        pure true
                                      else
                                        Loam.Persistence.saveOpenRelationUnits?
                                          relationFile admitted.world.relations
                                    if !relationPublished then
                                      return .error "loam: open relation evidence was not published; Event authority was not published"
                                    else
                                      let dischargePublished ←
                                        if admitted.newDischarges.isEmpty then
                                          pure true
                                        else
                                          Loam.Persistence.saveRelationDischarges?
                                            dischargeFile admitted.world.discharges
                                      if !dischargePublished then
                                        return .error "loam: relation discharge evidence was not published; Event authority was not published"
                                      else if ← Loam.Persistence.saveEventMemory?
                                          memoryFile admitted.world.events then
                                        return .ok admitted.event.id
                                      else
                                        return .error "loam: event was not published; already-published supporting, open-relation, and relation-discharge evidence remains inert until that EventId exists"
                                else
                                  return .error "loam: occurrence date evidence could not be published"

/--
Manifest production path.

The selected manifest generation is re-read under writer ownership and is the
only state used for world-dependent admission and publication. Version 2 carries
the explicit Locus new-write vocabulary in the same selected generation. Version
1 remains readable but its closed default vocabulary refuses publication.

There is deliberately no fallback to sidecars if selected manifest authority is
missing or malformed.
-/
private def publishDraftUnderManifestOwnership
    (rootPath : String)
    (draft : Loam.MovementAdmission.Draft) : IO (Except String Loam.Core.EventId) := do
  let root := System.FilePath.mk rootPath
  match ← Loam.MovementManifestAuthority.loadSelectedWorld? root with
  | Except.error message =>
      return .error message
  | Except.ok world =>
      match Loam.MovementAdmission.admit? world draft with
      | Except.error message =>
          return .error message
      | Except.ok admitted =>
          match ← Loam.MovementManifestAuthority.publishWorld? root admitted.world with
          | Except.error message =>
              return .error message
          | Except.ok _ =>
              return .ok admitted.event.id


/-- Publish a collected draft with fresh admission under the one writer lock.
No terminal input or output occurs here. Callers keep human think time outside.
-/
def publishManifest (root : System.FilePath) (draft : Loam.MovementAdmission.Draft) :
    IO (Except String Loam.Core.EventId) :=
  Loam.WriterOwnership.withOwnership (root / "CURRENT")
    (publishDraftUnderManifestOwnership root.toString draft)

/-- Explicit isolated sidecar fixture publisher; production uses publishManifest. -/
def publishSidecar (memory : System.FilePath) (draft : Loam.MovementAdmission.Draft) :
    IO (Except String Loam.Core.EventId) :=
  Loam.WriterOwnership.withOwnership memory
    (publishDraftUnderOwnership memory.toString draft)

end Loam.MovementPublisher
