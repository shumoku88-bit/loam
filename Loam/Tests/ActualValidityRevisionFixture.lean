import Loam.MovementManifestAuthority

open Loam.Core

set_option autoImplicit false

/--
Publish the smallest Movement world that contains a real occurrence-date
revision/correction chain. The compact-Actual experiment uses this fixture to
prove that root BASE dates may be inlined while later revision identity remains
sparse and observable through the current ActualReview frontier.
-/
def main (args : List String) : IO Unit := do
  let [rootPath] := args
    | throw (IO.userError "usage: ActualValidityRevisionFixture MANIFEST_ROOT")

  let eventId : EventId := ⟨"event-1"⟩
  let revisionId : ActualValidityRevisionId := ⟨"date-revision-1"⟩
  let effects :=
    [ Effect.ofQuantity ⟨"effect-1"⟩ ⟨"cash"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-100))
    , Effect.ofQuantity ⟨"effect-2"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 100)
    ]
  let some event := Event.ofEffects? eventId effects
    | throw (IO.userError "fixture Event admission failed")
  let some events := EventMemory.ofEvents? [event]
    | throw (IO.userError "fixture EventMemory admission failed")
  let some validity := ActualValidityHistory.ofParts?
      [ .base eventId "2026-09-01"
      , .revision revisionId eventId "2026-09-02"
      ]
      [{ target := .root eventId, replacement := revisionId }]
    | throw (IO.userError "fixture ActualValidityHistory admission failed")
  let some descriptions := EventDescriptionMemory.ofEntries?
      [{ event := eventId, text := "corrected date fixture" }]
    | throw (IO.userError "fixture EventDescription admission failed")
  let some locusAdmission := LocusAdmissionVocabulary.ofLoci?
      [⟨"cash"⟩, ⟨"food"⟩]
    | throw (IO.userError "fixture LocusAdmission admission failed")

  let world : Loam.MovementAdmission.World := {
    events := events
    validity := validity
    descriptions := descriptions
    relations := []
    discharges := []
    locusAdmission := locusAdmission
  }

  let root := System.FilePath.mk rootPath
  match ← Loam.MovementManifestAuthority.publishWorld? root world with
  | .ok _ => IO.println "Actual-validity revision fixture published."
  | .error message => throw (IO.userError message)
