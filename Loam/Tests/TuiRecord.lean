import Loam.Tui.Record
import Loam.MovementPublisher
import Loam.ActualReview

open Loam.Core Loam.Tui.Record

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def world : IO Loam.MovementAdmission.World := do
  let some events := EventMemory.ofEvents? [] | throw (IO.userError "empty events")
  let some vocabulary := LocusAdmissionVocabulary.ofLoci? [⟨"paypay"⟩, ⟨"books"⟩]
    | throw (IO.userError "vocabulary")
  return { events := events, validity := { facts := [], factIdNodup := by simp, corrections := [], correctionIdNodup := by simp }, descriptions := .empty,
    relations := [], discharges := [], locusAdmission := vocabulary }

private def readyForm : Form := {
  date := "2026-09-06", description := "数学ガール",
  rows := #[{ fromSide := true, locus := "paypay", amount := "2470" },
            { fromSide := false, locus := "books", amount := "2470" }] }

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated manifest root")
  let root := System.FilePath.mk rootPath
  let w ← world
  let .ok draft := draft? readyForm | throw (IO.userError "form parsing")
  let editor := preview w { form := readyForm }
  expect ((update w [] editor .enter).publish.isSome) "preview must produce explicit intent"
  expect ((update w [] editor .escape).publish.isNone) "cancel must not publish"
  let edited := update w [] (update w [] editor .tab).state .enter
  expect (edited.state.form.description == readyForm.description) "Edit lost description"
  expect (edited.state.form.rows == readyForm.rows) "Edit lost rows"
  expect ((Loam.MovementAdmission.admit? w { draft with total := 1 }).isOk == false)
    "forged total admitted"
  expect ((Loam.MovementAdmission.admit? w { draft with effects := draft.effects.take 1 }).isOk == false)
    "unbalanced draft admitted"
  expect ((Loam.MovementAdmission.admit? w { draft with validOn := "2026-02-29" }).isOk == false)
    "impossible date admitted"
  let invalid := preview w { form := { readyForm with date := "bad" } }
  expect ((update w [] invalid .enter).publish.isNone) "invalid preview emitted publication"
  let candidateForm := { readyForm with focus := ⟨2, by decide⟩ }
  let accepted := acceptCandidate ["paypay-extra"] candidateForm
  expect (accepted.rows[0]!.locus == "paypay-extra") "candidate did not fill focused locus"
  expect (accepted.rows[1]! == readyForm.rows[1]!) "candidate changed another row"
  expect (accepted.description == readyForm.description) "candidate changed description"
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root w
    | throw (IO.userError "initialize fixture")
  -- An already-previewed draft must be re-admitted against policy changed during think time.
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root
      { w with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "change fixture policy")
  let before ← IO.FS.readFile (root / "CURRENT")
  let refused ← Loam.MovementPublisher.publishManifest root draft
  expect (!refused.isOk) "stale preview bypassed current Locus policy"
  expect ((← IO.FS.readFile (root / "CURRENT")) == before) "refusal changed authority"
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root w
    | throw (IO.userError "restore fixture policy")
  let .ok id ← Loam.MovementPublisher.publishManifest root draft
    | throw (IO.userError "canonical publish")
  let .ok records ← Loam.ActualReview.loadRecordsFromManifest root none
    | throw (IO.userError "canonical review reload")
  expect (records.length == 1) "reload did not see exactly one record"
  expect (records.any fun record => record.event.id.token == id.token &&
    record.description == "数学ガール" && record.date == some "2026-09-06")
    "fresh review lost published evidence"
  IO.println "TUI Record: admission, stale policy rejection, publication and fresh review passed."
