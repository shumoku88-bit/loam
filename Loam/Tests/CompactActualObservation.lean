import Loam.ActualReview

set_option autoImplicit false

/--
Path-independent read-only observation of the public ActualReview answer.
The compact-Actual experiment compares this stream byte-for-byte before and
after representation change so date, description, correction frontier, EventId,
EffectKey, locus, measure, and exact quantity all remain observable.
-/
def main (args : List String) : IO Unit := do
  let [path] := args
    | throw (IO.userError "usage: CompactActualObservation DATA_DIR")
  let dataDir := System.FilePath.mk path
  let correctionPath := (dataDir / "corrections.loam").toString
  let recordsResult ←
    Loam.ActualReview.loadRecordsFromManifest
      (dataDir / "movement-authority") (some correctionPath)
  let .ok records := recordsResult
    | throw (IO.userError s!"ActualReview unavailable: {repr recordsResult}")

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
          , effect.key.token
          , effect.locus.token
          , effect.measure.token
          , toString effect.quantity.quanta
          ]
