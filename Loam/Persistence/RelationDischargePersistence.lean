import Loam.Core.OpenRelation
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Raw relation-discharge persistence

Observation 178 qualified quantified discharge provenance and the discharge
publication activation observation qualified pre-Event raw residue as inert.
This module therefore retains only raw `RelationDischarge` rows in one
independent stream. It deliberately performs no Application admission.

Wire format (version 1):

```text
LOAM-RELATION-DISCHARGE-MEMORY<TAB>1
DISCHARGE<TAB><later-event-id><TAB><target-relation-id><TAB><signed-quanta>
...
```

There is intentionally no `DischargeId`. The current semantic boundary permits
at most one admitted `(EventId, RelationUnitId)` correspondence, while raw
persistence retains repeated pairs so Application can fail closed rather than
silently choosing one by row order.

The quantity remains raw exact signed `Quantity`. Zero and negative rows,
missing later Events, and missing relation targets are syntactically retained;
activation and semantic validity belong to Application.

Publication uses sibling staging + rename like the other independent practical
streams. This is not a cross-stream transaction, rollback protocol, concurrent
writer protocol, fsync guarantee, or power-loss durability claim.
-/

/-- Version marker for the first raw RelationDischarge stream. -/
def relationDischargeMemoryHeader : String :=
  "LOAM-RELATION-DISCHARGE-MEMORY\t1"

/-- Place raw discharge persistence adjacent to the canonical Event memory. -/
def relationDischargePathForEventMemory
    (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".discharges")

private def encodeRelationDischargeRow?
    (discharge : RelationDischarge) : Option String := do
  let eventToken := discharge.event.token
  let targetToken := discharge.target.token
  if !(validToken eventToken && validToken targetToken) then
    none
  else
    some <| String.intercalate "\t" [
      "DISCHARGE",
      eventToken,
      targetToken,
      toString discharge.quantity.quanta
    ]

private def decodeRelationDischargeRow?
    (row : String) : Option RelationDischarge :=
  match row.splitOn "\t" with
  | ["DISCHARGE", eventToken, targetToken, quantaText] => do
      if !(validToken eventToken && validToken targetToken) then
        none
      else
        let quanta ← quantaText.toInt?
        some {
          event := ⟨eventToken⟩
          target := ⟨targetToken⟩
          quantity := Quantity.ofQuanta quanta
        }
  | _ => none

/--
Encode retained raw discharge rows without assigning authority to list order.
-/
def encodeRelationDischarges?
    (discharges : List RelationDischarge) : Option String := do
  let rows ← discharges.mapM encodeRelationDischargeRow?
  some (String.intercalate "\n" (relationDischargeMemoryHeader :: rows) ++ "\n")

/--
Decode one raw RelationDischarge stream.

Malformed syntax, unsupported versions, invalid opaque tokens, or non-integer
quantity text return `none`. Missing referenced Events/relations, non-positive
quantity, duplicate `(EventId, RelationUnitId)` pairs, and aggregate discharge
bounds are intentionally not decided here.
-/
def decodeRelationDischarges?
    (input : String) : Option (List RelationDischarge) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = relationDischargeMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows => reversedRows.reverse.mapM decodeRelationDischargeRow?
        | _ => none
      else
        none
  | _ => none

private def relationDischargeStagePath
    (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/-- Publish the complete raw RelationDischarge image through sibling staging + rename. -/
def saveRelationDischarges?
    (path : System.FilePath)
    (discharges : List RelationDischarge) : IO Bool := do
  match encodeRelationDischarges? discharges with
  | none => pure false
  | some text =>
      let stagePath := relationDischargeStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      pure true

/-- Load and syntactically decode one raw RelationDischarge stream. -/
def loadRelationDischarges?
    (path : System.FilePath) : IO (Option (List RelationDischarge)) := do
  let input ← IO.FS.readFile path
  pure (decodeRelationDischarges? input)

end Loam.Persistence
