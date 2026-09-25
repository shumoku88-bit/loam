import Loam.Tests.ActualWorldFixture
import Loam.Web.Record
import Loam.HouseholdCommand
import Loam.ActualReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def world : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? []
    | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"books"⟩]
    | throw (IO.userError "vocabulary")
  return {
    events := events
    validity := {
      facts := []
      factRefNodup := by simp
      corrections := []
      correctionIdNodup := by simp
    }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary
  }

private def request : Loam.Web.Record.Request := {
  date := "2026-09-25"
  description := "web publication"
  measure := "jpy"
  fromLocus := "paypay"
  fromAmount := "2470"
  toLocus := "books"
  toAmount := "2470"
}

private def draft : IO Loam.MovementAdmission.Draft := do
  let .ok input := request.toInput?
    | throw (IO.userError "Web request input")
  let .ok draft := Loam.Presentation.Record.draftWithPresentation? [] input
    | throw (IO.userError "Web shared draft")
  return draft

def main (args : List String) : IO Unit := do
  let [rootPath] := args
    | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  IO.FS.createDirAll root
  let w ← world
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root w
    | throw (IO.userError "initialize Web publication fixture")

  let d ← draft
  let operation : MovementOperationId := ⟨"web-test-operation"⟩

  let .ok first ← Loam.HouseholdCommand.recordIdempotent root operation d
    | throw (IO.userError "first Web publication")
  let event ←
    match first with
    | .applied event => pure event
    | .alreadyApplied _ =>
        throw (IO.userError "fresh Web operation unexpectedly already applied")

  let .ok second ← Loam.HouseholdCommand.recordIdempotent root operation d
    | throw (IO.userError "retry Web publication")
  match second with
  | .alreadyApplied retried =>
      expect (retried == event)
        "retry-safe Web operation returned a different Event"
  | .applied _ =>
      throw (IO.userError "repeated Web Confirm published a duplicate Event")

  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "fresh Web publication reread")
  expect (records.length == 1)
    "repeated Web Confirm created more than one canonical Event"
  expect (records.any fun record =>
      record.event.id == event &&
      record.date == some request.date &&
      record.description == request.description)
    "fresh canonical reread did not expose the published Web Event"

  -- A reviewed draft is not publication authority. Change only the isolated
  -- stale fixture's policy after preview and require the writer to refuse it.
  let staleRoot := root / "stale"
  IO.FS.createDirAll staleRoot
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? staleRoot w
    | throw (IO.userError "initialize stale Web fixture")
  let catalog := Loam.LocusCatalog.fallback w.locusAdmission
  let reviewed := Loam.Web.Record.review w {
    operation := "web-stale-operation"
    request := request
    catalog := catalog
    measurePresentation := []
  }
  match reviewed.review with
  | .ready _ => pure ()
  | _ => throw (IO.userError "stale Web fixture did not preview")

  let some closedVocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"other"⟩]
    | throw (IO.userError "closed vocabulary")
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? staleRoot
      { w with locusAdmission := closedVocabulary }
    | throw (IO.userError "change stale Web policy")
  let before ← IO.FS.readFile (staleRoot / "actual.loam")
  let refused ← Loam.HouseholdCommand.recordIdempotent
    staleRoot ⟨"web-stale-operation"⟩ d
  expect (!refused.isOk)
    "Web Confirm trusted preview instead of current Locus policy"
  expect ((← IO.FS.readFile (staleRoot / "actual.loam")) == before)
    "refused stale Web Confirm changed canonical Actual authority"

  IO.println "Web Record publication: explicit retry identity, one canonical Event, fresh reread, and stale-policy refusal passed."
