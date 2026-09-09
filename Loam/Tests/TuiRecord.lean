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
  return {
    events := events
    validity := {
      facts := []
      factIdNodup := by simp
      corrections := []
      correctionIdNodup := by simp }
    descriptions := .empty
    relations := []
    discharges := []
    locusAdmission := vocabulary }

private def readyForm : Form := {
  date := "2026-09-06"
  description := "数学ガール"
  rows := #[
    { locus := "paypay", amount := "-2470" },
    { locus := "books", amount := "2470" }] }

def main (args : List String) : IO Unit := do
  let [rootPath] := args | throw (IO.userError "supply isolated manifest root")
  let root := System.FilePath.mk rootPath
  let w ← world
  let .ok draft := draft? readyForm | throw (IO.userError "form parsing")
  expect (draft.effects.map (fun effect => effect.quantity.quanta) == [-2470, 2470])
    "signed postings did not preserve their quantities"
  let editor := preview w { form := readyForm }
  expect ((update w [] editor .enter).publish.isSome) "preview must produce explicit intent"
  expect ((update w [] editor .escape).publish.isNone) "cancel must not publish"
  let edited := update w [] (update w [] editor .tab).state .enter
  expect (edited.state.form.description == readyForm.description) "Edit lost description"
  expect (edited.state.form.rows == readyForm.rows) "Edit lost rows"

  let finalAmountForm := { readyForm with focus := ⟨5, by decide⟩ }
  let directPreview := update w [] { form := finalAmountForm } .enter
  match directPreview.state.mode with
  | .preview _ choice => expect (choice.val == 0) "direct preview did not select Publish"
  | .editing => throw (IO.userError "final amount Enter did not open preview")
  expect (directPreview.publish.isNone) "direct preview published without confirmation"
  expect ((update w [] directPreview.state .enter).publish.isSome)
    "direct preview did not preserve explicit publish confirmation"
  let finalAmountTab := update w [] { form := finalAmountForm } .tab
  expect (finalAmountTab.state.form.focus.val == 6)
    "Tab from final amount no longer reaches row actions"

  let addPostingForm := { readyForm with focus := ⟨6, by decide⟩ }
  let added := update w [] { form := addPostingForm } .enter
  expect (added.state.form.rows.size == 3) "Add posting did not append one row"
  expect (added.state.form.focus.val == 6) "Add posting did not focus the new Locus"
  expect (added.state.form.rows[2]!.locus.isEmpty && added.state.form.rows[2]!.amount.isEmpty)
    "Add posting did not append one neutral row"

  let reversedForm : Form := {
    readyForm with
    rows := #[
      { locus := "books", amount := "2470" },
      { locus := "paypay", amount := "-2470" }] }
  expect ((draft? reversedForm).isOk) "posting order became semantic"
  expect ((draft? { readyForm with rows := #[
    { locus := "paypay", amount := "2470" },
    { locus := "books", amount := "2470" }] }).isOk == false)
    "unbalanced same-sign postings were accepted"
  expect ((draft? { readyForm with rows := #[
    { locus := "paypay", amount := "0" },
    { locus := "books", amount := "0" }] }).isOk == false)
    "zero postings were accepted"

  expect ((Loam.MovementAdmission.admit? w { draft with total := 1 }).isOk == false)
    "forged total admitted"
  expect ((Loam.MovementAdmission.admit? w { draft with effects := draft.effects.take 1 }).isOk == false)
    "unbalanced draft admitted"
  expect ((Loam.MovementAdmission.admit? w { draft with validOn := "2026-02-29" }).isOk == false)
    "impossible date admitted"
  let invalid := preview w { form := { readyForm with date := "bad" } }
  expect ((update w [] invalid .enter).publish.isNone) "invalid preview emitted publication"

  let blankCandidateForm : Form := {
    readyForm with
    rows := #[
      { locus := "", amount := "-2470" },
      { locus := "books", amount := "2470" }]
    focus := ⟨2, by decide⟩ }
  let pickerKnown := ["paypay", "books", "point"]
  let pickerStart : State := { form := blankCandidateForm }
  let pickerDown := (update w pickerKnown pickerStart .down).state
  expect ((catalogCandidates pickerDown).map (fun entry => entry.locus.token) == ["paypay", "books"])
    "Record catalog was not reduced to current LocusAdmission"
  expect ((selectedCatalogCandidate? pickerDown).map (fun entry => entry.locus.token) == some "books")
    "Down did not move the catalog candidate cursor"
  let pickerWrapped := (update w pickerKnown pickerDown .down).state
  expect ((selectedCatalogCandidate? pickerWrapped).map (fun entry => entry.locus.token) == some "paypay")
    "catalog cursor escaped current LocusAdmission into recognition-only history"
  let pickerAccepted := (update w pickerKnown pickerDown .right).state
  expect (pickerAccepted.form.rows[0]!.locus == "books")
    "Right did not accept the selected catalog candidate"
  expect (pickerAccepted.form.rows[1]! == blankCandidateForm.rows[1]!)
    "catalog candidate selection changed another posting row"

  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root w
    | throw (IO.userError "initialize fixture")
  -- An already-previewed draft must be re-admitted against policy changed during think time.
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root
      { w with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "change fixture policy")
  let before ← IO.FS.readFile (root / "CURRENT")
  let refused ← Loam.MovementPublisher.publishManifestDraft root.toString draft
  expect (!refused.isOk) "stale preview bypassed current Locus policy"
  expect ((← IO.FS.readFile (root / "CURRENT")) == before) "refusal changed authority"
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? root w
    | throw (IO.userError "restore fixture policy")
  let .ok receipt ← Loam.MovementPublisher.publishManifestDraft root.toString draft
    | throw (IO.userError "canonical publish")
  let .ok records ← Loam.ActualReview.loadRecordsFromManifest root none
    | throw (IO.userError "canonical review reload")
  expect (records.length == 1) "reload did not see exactly one record"
  expect (records.any fun record => record.event.id.token == receipt.eventId.token &&
    record.description == "数学ガール" && record.date == some "2026-09-06")
    "fresh review lost published evidence"
  IO.println "TUI Record: signed postings, canonical catalog selection, admission, stale policy rejection, publication and fresh review passed."