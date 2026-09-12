import Loam.ActualReview

set_option autoImplicit false

/--
Read-only Actual observation that deliberately excludes EffectKey for ordinary
quantity Effects. Effect-level identity is observed separately through the
Relation frontier when it is semantically referenced.
-/
def main (args : List String) : IO Unit := do
  let [path] := args
    | throw (IO.userError "usage: SparseEffectKeyActualObservation DATA_DIR")
  let dataDir := System.FilePath.mk path
  let correctionPath := (dataDir / "corrections.loam").toString
  let recordsResult ←
    Loam.ActualReview.loadRecordsFromManifest
      (dataDir / "movement-authority") (some correctionPath)
  let records ←
    match recordsResult with
    | .ok records => pure records
    | .error message => throw (IO.userError ("ActualReview unavailable: " ++ message))

  for record in records do
    let date := record.date.getD "-"
    let replacement := record.replacement.map (·.token) |>.getD "-"
    let description := Loam.Persistence.escapeText record.description
    IO.println <|
      String.intercalate "\t"
        [ "RECORD"
        , record.event.id.token
        , date
        , if record.isCurrent then "current" else "superseded"
        , replacement
        , description
        ]
    for effect in record.event.effects do
      IO.println <|
        String.intercalate "\t"
          [ "EFFECT"
          , record.event.id.token
          , effect.locus.token
          , effect.measure.token
          , toString effect.quantity.quanta
          ]
