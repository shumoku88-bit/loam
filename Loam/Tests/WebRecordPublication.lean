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
      [⟨"paypay"⟩, ⟨"books"⟩, ⟨"food"⟩, ⟨"shipping"⟩]
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
  toLocus := "books"
  amount := "2470"
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

  let postingRequest : Loam.Web.Record.PostingRequest := {
    date := "2026-09-25"
    description := "web split publication"
    measure := "jpy"
    rows := #[
      { locus := "paypay", amount := "-3000" },
      { locus := "books", amount := "2000" },
      { locus := "food", amount := "700" },
      { locus := "shipping", amount := "300" },
      {},
      {}
    ]
  }
  let .ok postingDraft :=
      Loam.Presentation.Record.draftWithPresentation? [] postingRequest.toInput
    | throw (IO.userError "Web multiple-posting shared draft")
  let postingOperation : MovementOperationId := ⟨"web-postings-operation"⟩
  let .ok postingFirst ←
      Loam.HouseholdCommand.recordIdempotent root postingOperation postingDraft
    | throw (IO.userError "first Web multiple-posting publication")
  let postingEvent ←
    match postingFirst with
    | .applied event => pure event
    | .alreadyApplied _ =>
        throw (IO.userError "fresh Web multiple-posting operation unexpectedly already applied")
  let .ok postingRetry ←
      Loam.HouseholdCommand.recordIdempotent root postingOperation postingDraft
    | throw (IO.userError "retry Web multiple-posting publication")
  match postingRetry with
  | .alreadyApplied retried =>
      expect (retried == postingEvent)
        "retry-safe multiple-posting Web operation returned a different Event"
  | .applied _ =>
      throw (IO.userError "repeated multiple-posting Confirm published a duplicate Event")

  let .ok afterSplit ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "fresh multiple-posting Web publication reread")
  expect (afterSplit.length == 2)
    "multiple-posting Web publication did not add exactly one canonical Event"
  expect (afterSplit.any fun record =>
      record.event.id == postingEvent &&
      record.event.effects.length == 4 &&
      record.description == postingRequest.description)
    "fresh canonical reread did not expose all four Web postings"

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

  IO.println "Web Record publication: ordinary and multiple-posting retry identity, canonical publication, fresh reread, and stale-policy refusal passed."
