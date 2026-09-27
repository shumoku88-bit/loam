import Loam.LocusCoherenceReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

def main : IO Unit := do
  let current : LocusId := ⟨"current"⟩
  let mystery : LocusId := ⟨"mystery"⟩
  let noLabel : LocusId := ⟨"no-label"⟩
  let old : LocusId := ⟨"old-expense"⟩
  let yen : MeasureId := ⟨"jpy"⟩
  let food : PurposeId := ⟨"food"⟩

  let admission ← requireSome
    (LocusAdmissionVocabulary.ofLoci? [current, mystery, noLabel])
    "admission fixture"

  let event : Event := {
    id := ⟨"historical-1"⟩
    effects := [Effect.ofAnonymousQuantity old yen (Quantity.ofQuanta 10)]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity]
  }
  let events ← requireSome (EventMemory.ofEvents? [event]) "event fixture"

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [{ locus := current, role := .expense },
       { locus := old, role := .expense }])
    "role fixture"

  let routing ← requireSome
    (Loam.Core.RoutingHistory.ofEntries?
      [{ subject := current, effectiveOn := Loam.Core.RoutingEffective.initial,
         purpose := some food },
       { subject := old, effectiveOn := Loam.Core.RoutingEffective.initial,
         purpose := some food }])
    "routing fixture"

  let some metadata := Loam.LocusCatalog.decode?
      ("current\tCurrent expense\tcurrent display row\n" ++
       "mystery\tMystery\trole intentionally unresolved\n" ++
       "old-expense\tOld expense\thistorical display row\n")
    | throw (IO.userError "metadata fixture")

  let snapshot := Loam.LocusCoherenceReview.review
    admission events roles routing metadata

  expect (snapshot.admittedLoci.map (fun locus => locus.token) ==
      ["current", "mystery", "no-label"])
    "admission order changed"
  expect (snapshot.retainedActualLoci.map (fun locus => locus.token) == ["old-expense"])
    "retained Actual Locus inventory changed"
  expect (snapshot.admittedMissingRole.map (fun locus => locus.token) ==
      ["mystery", "no-label"])
    "missing AccountingRole differences were not reported"
  expect (snapshot.admittedMissingMetadata.map (fun locus => locus.token) == ["no-label"])
    "missing display metadata was not reported"
  expect (snapshot.nonAdmitted.length == 1)
    "non-admitted evidence inventory changed"

  let row ← requireSome snapshot.nonAdmitted.head? "historical row"
  expect (row.locus == old) "wrong historical row"
  expect (row.actualOccurrences == 1) "historical Actual occurrence count"
  expect (row.role == some .expense) "historical AccountingRole disappeared"
  expect row.hasRoutingEvidence "historical routing evidence disappeared"
  expect (row.label == "Old expense") "historical display metadata disappeared"
  expect (row.help == "historical display row") "historical display help disappeared"

  expect (!(snapshot.nonAdmitted.any fun historical => historical.locus == current))
    "current admission was incorrectly reported as historical-only"

  IO.println "Locus coherence review: independent authorities remain separate and their differences stay visible."
