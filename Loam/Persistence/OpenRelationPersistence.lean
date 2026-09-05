import Loam.Core.OpenRelation
import Loam.Persistence

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Raw open-relation-unit persistence

Observation 177 earned one independent physical stream for retained positive
`RelationUnit` candidates before any concrete Movement writer is changed.

This module deliberately persists raw `RelationUnit` values only. It does not
persist `RelationRevision`, source-level negative evidence, completeness, or a
routine `NoRelation` receipt, and it does not require the referenced Event or
Effect to exist while decoding.

Wire format (version 1):

```text
LOAM-RELATION-UNIT-MEMORY<TAB>1
RELATION<TAB><relation-id><TAB><event-id><TAB><effect-key><TAB><debtor-kind><TAB><debtor-token><TAB><creditor-kind><TAB><creditor-token><TAB><signed-quanta>
...
```

Endpoint encoding uses two fields so external endpoint tokens remain opaque:

- `H<TAB>` means the distinguished Household endpoint and requires an empty
  endpoint-token field;
- `E<TAB><external-id>` means one opaque external endpoint and requires a
  `validToken` external identity.

The quantity is raw exact `Quantity`. Negative and zero values are syntactically
representable because positivity and source-magnitude bounds belong to
Application admission, not persistence.

Repeated `RelationUnitId` rows are likewise retained by this syntax boundary.
They are a global semantic conflict for the Application frontier rather than a
reason for the persistence decoder to silently discard raw provenance.

Publication uses a sibling staging path plus filesystem rename, like the other
independent practical streams. This is not a cross-stream transaction,
concurrent-writer lock, rollback protocol, fsync guarantee, or power-loss
durability claim. A relation row may survive before its source Event publication;
source admission keeps such residue semantically inert until the source exists.
-/

/-- Version marker for the first raw RelationUnit stream. -/
def openRelationUnitMemoryHeader : String :=
  "LOAM-RELATION-UNIT-MEMORY\t1"

/-- Place raw RelationUnit persistence adjacent to the canonical Event memory. -/
def openRelationUnitPathForEventMemory
    (memoryPath : System.FilePath) : System.FilePath :=
  System.FilePath.mk (memoryPath.toString ++ ".relations")

private def encodeRelationEndpoint?
    (endpoint : RelationEndpoint) : Option (String × String) :=
  match endpoint with
  | .household => some ("H", "")
  | .external id =>
      if validToken id.token then
        some ("E", id.token)
      else
        none

private def decodeRelationEndpoint?
    (kind token : String) : Option RelationEndpoint :=
  match kind with
  | "H" =>
      if token.isEmpty then some .household else none
  | "E" =>
      if validToken token then some (.external ⟨token⟩) else none
  | _ => none

private def encodeOpenRelationUnitRow?
    (relation : RelationUnit) : Option String := do
  let relationToken := relation.id.token
  let eventToken := relation.sourceEvent.token
  let effectToken := relation.sourceEffect.token
  if !(validToken relationToken && validToken eventToken && validToken effectToken) then
    none
  else
    let debtor ← encodeRelationEndpoint? relation.debtor
    let creditor ← encodeRelationEndpoint? relation.creditor
    some <| String.intercalate "\t" [
      "RELATION",
      relationToken,
      eventToken,
      effectToken,
      debtor.1,
      debtor.2,
      creditor.1,
      creditor.2,
      toString relation.quantity.quanta
    ]

private def decodeOpenRelationUnitRow? (row : String) : Option RelationUnit :=
  match row.splitOn "\t" with
  | ["RELATION", relationToken, eventToken, effectToken,
      debtorKind, debtorToken, creditorKind, creditorToken, quantaText] => do
      if !(validToken relationToken && validToken eventToken && validToken effectToken) then
        none
      else
        let debtor ← decodeRelationEndpoint? debtorKind debtorToken
        let creditor ← decodeRelationEndpoint? creditorKind creditorToken
        let quanta ← quantaText.toInt?
        some {
          id := ⟨relationToken⟩
          sourceEvent := ⟨eventToken⟩
          sourceEffect := ⟨effectToken⟩
          debtor := debtor
          creditor := creditor
          quantity := Quantity.ofQuanta quanta
        }
  | _ => none

/--
Encode raw RelationUnit rows without assigning semantic authority to row order.
Duplicate relation identity and source availability remain later Application
questions.
-/
def encodeOpenRelationUnits?
    (relations : List RelationUnit) : Option String := do
  let rows ← relations.mapM encodeOpenRelationUnitRow?
  some (String.intercalate "\n" (openRelationUnitMemoryHeader :: rows) ++ "\n")

/--
Decode one raw RelationUnit stream.

Malformed syntax, unsupported versions, invalid opaque tokens, malformed endpoint
encoding, or non-integer quantity text return `none`. Missing source Events,
negative/zero quantity, duplicate RelationUnit identity, and relation semantics
are deliberately not rejected here.
-/
def decodeOpenRelationUnits? (input : String) : Option (List RelationUnit) :=
  match input.splitOn "\n" with
  | header :: rows =>
      if header = openRelationUnitMemoryHeader then
        match rows.reverse with
        | "" :: reversedRows => reversedRows.reverse.mapM decodeOpenRelationUnitRow?
        | _ => none
      else
        none
  | _ => none

private def openRelationUnitStagePath
    (path : System.FilePath) : System.FilePath :=
  System.FilePath.mk (path.toString ++ ".loam-stage")

/--
Publish the complete raw RelationUnit stream through sibling staging + rename.
-/
def saveOpenRelationUnits?
    (path : System.FilePath)
    (relations : List RelationUnit) : IO Bool := do
  match encodeOpenRelationUnits? relations with
  | none => pure false
  | some text =>
      let stagePath := openRelationUnitStagePath path
      IO.FS.writeFile stagePath text
      IO.FS.rename stagePath path
      pure true

/-- Load and syntactically decode one raw RelationUnit stream. -/
def loadOpenRelationUnits?
    (path : System.FilePath) : IO (Option (List RelationUnit)) := do
  let input ← IO.FS.readFile path
  pure (decodeOpenRelationUnits? input)

end Loam.Persistence
