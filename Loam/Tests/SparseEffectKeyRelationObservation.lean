import Loam.Application.OpenRelationFrontier
import Loam.MovementManifestAuthority

set_option autoImplicit false

/--
Read-only observation of the semantic reason EffectKey exists: one retained
RelationUnit must continue to resolve the same `(EventId, EffectKey)` source and
therefore the same source payload after representation compression.
-/
def main (args : List String) : IO Unit := do
  let [path] := args
    | throw (IO.userError "usage: SparseEffectKeyRelationObservation DATA_DIR")
  let root := System.FilePath.mk path / "movement-authority"
  let worldResult ← Loam.MovementManifestAuthority.loadSelectedWorld? root
  let world ←
    match worldResult with
    | .ok world => pure world
    | .error message => throw (IO.userError message)
  let frontier ←
    match Loam.Application.admittedRelationFrontier? world.events world.relations with
    | some frontier => pure frontier
    | none => throw (IO.userError "relation frontier unresolved")

  for admitted in frontier do
    IO.println <|
      String.intercalate "\t"
        [ "RELATION"
        , admitted.relation.id.token
        , admitted.relation.sourceEvent.token
        , admitted.relation.sourceEffect.token
        , admitted.source.locus.token
        , admitted.source.measure.token
        , toString admitted.source.quantity.quanta
        , toString admitted.relation.quantity.quanta
        ]
  IO.println "STATUS\tcomplete"
