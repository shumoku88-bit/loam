import Loam.Tests.ActualWorldFixture
import Loam.Tui.Record
import Loam.Tui.UnresolvedActivation
import Loam.MovementDraftReview
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
      factRefNodup := by simp
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
  let [rootPath] := args | throw (IO.userError "supply isolated data root")
  let root := System.FilePath.mk rootPath
  let w ← world
  let sharedInput : Loam.Presentation.Record.Input := {
    date := "2026-09-06"
    description := "数学ガール"
    rows := #[
      { locus := "paypay", amount := "-2470" },
      { locus := "books", amount := "2470" }]
  }
  let .ok sharedPreview := Loam.Presentation.Record.preview? w [] sharedInput
    | throw (IO.userError "shared Record preview")
  let .ok draft := draft? readyForm | throw (IO.userError "form parsing")
  expect
    (sharedPreview.draft.validOn == draft.validOn &&
      sharedPreview.draft.description == draft.description &&
      sharedPreview.draft.total == draft.total &&
      sharedPreview.draft.effects.map (fun effect =>
        (effect.locus.token, effect.measure.token, effect.quantity.quanta)) ==
      draft.effects.map (fun effect =>
        (effect.locus.token, effect.measure.token, effect.quantity.quanta)))
    "TUI Record draft diverged from shared Record preview"
  expect (draft.effects.map (fun effect => effect.quantity.quanta) == [-2470, 2470])
    "signed postings did not preserve their quantities"
  let usdForm : Form := {
    readyForm with
    measure := "usd"
    rows := #[
      { locus := "paypay", amount := "-25" },
      { locus := "books", amount := "25" }] }
  let .ok usdDraft := draft? usdForm
    | throw (IO.userError "USD form parsing")
  expect (usdDraft.effects.all fun effect => effect.measure == ⟨"usd"⟩)
    "TUI Record did not preserve selected Measure"

  let decimalPresentation : List Loam.MeasurePresentation.Metadata :=
    [ { measure := ⟨"usd"⟩, scale := 2 }
    , { measure := ⟨"ils"⟩, scale := 2 }
    ]
  let decimalUsdForm : Form := {
    readyForm with
    measure := "usd"
    rows := #[
      { locus := "paypay", amount := "-12.34" },
      { locus := "books", amount := "12.34" }] }
  let .ok decimalUsdDraft := draftWithPresentation? decimalPresentation decimalUsdForm
    | throw (IO.userError "decimal USD form parsing")
  expect
    (decimalUsdDraft.effects.map (fun effect => effect.quantity.quanta) == [-1234, 1234])
    "decimal USD input did not map exactly to quanta"
  expect
    (Loam.MeasurePresentation.formatQuanta decimalPresentation ⟨"usd"⟩ (-5) == "-0.05")
    "decimal USD formatting did not zero-pad exact quanta"
  expect
    ((draftWithPresentation? decimalPresentation
      { decimalUsdForm with rows := #[
          { locus := "paypay", amount := "-12.345" },
          { locus := "books", amount := "12.345" }] }).isOk == false)
    "decimal input accepted more fractional digits than the configured scale"
  expect
    (Loam.MeasurePresentation.parseQuanta? decimalPresentation ⟨"ils"⟩ "27.9" == some 2790)
    "ILS scale did not right-pad a shorter exact fractional input"

  let originalBase : State := {
    form := readyForm
    measurePresentation := decimalPresentation
  }
  let openedOriginal := update w [] originalBase (.ctrl 'o')
  match openedOriginal.state.mode with
  | .originalAmount editor =>
      expect (editor.measure.isEmpty && editor.amount.isEmpty)
        "Ctrl-O did not open an empty original amount editor"
  | _ => throw (IO.userError "Ctrl-O did not open original amount editor")

  let originalEditor : OriginalAmountEditor := {
    measure := "usd"
    amount := "30.00"
    focus := ⟨1, by decide⟩
  }
  let attached := update w []
    { originalBase with mode := .originalAmount originalEditor } .enter
  let original ←
    match attached.state.originalAmount with
    | some value => pure value
    | none => throw (IO.userError "valid original amount was not attached")
  expect (original.measure == ⟨"usd"⟩ && original.quantity.quanta == 3000)
    "decimal original amount did not retain exact USD quanta"
  match attached.state.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "attaching original amount did not return to ordinary editor")

  let invalidOriginal : OriginalAmountEditor := {
    measure := "usd"
    amount := "30.001"
    focus := ⟨1, by decide⟩
  }
  expect
    ((attachOriginalAmount? originalBase invalidOriginal).isOk == false)
    "original amount accepted too many decimal places"

  let originalPreview := preview w attached.state
  let originalPublish := update w [] originalPreview .enter
  match originalPublish.publish with
  | some (.movementWithOriginalAmount publishedDraft publishedOriginal) =>
      expect (publishedDraft.total == 2470)
        "original amount changed the ordinary Movement total"
      expect
        (publishedOriginal.measure == ⟨"usd"⟩ &&
          publishedOriginal.quantity.quanta == 3000)
        "preview lost attached original amount"
  | _ => throw (IO.userError "attached original amount did not emit atomic publication intent")

  let cleared := update w []
    { attached.state with mode := .originalAmount originalEditor } (.ctrl 'd')
  expect cleared.state.originalAmount.isNone
    "Ctrl-D did not clear attached original amount"
  match cleared.state.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "clearing original amount did not return to editor")
  let editor := preview w { form := readyForm }
  match (update w [] editor .enter).publish with
  | some (.movement _) => pure ()
  | _ => throw (IO.userError "ordinary preview no longer emits ordinary Movement intent")
  expect ((update w [] editor .escape).publish.isNone) "cancel must not publish"
  let edited := update w [] (update w [] editor .tab).state .enter
  expect (edited.state.form.description == readyForm.description) "Edit lost description"
  expect (edited.state.form.rows == readyForm.rows) "Edit lost rows"

  let finalAmountForm := { readyForm with focus := ⟨6, by decide⟩ }
  let directPreview := update w [] { form := finalAmountForm } .enter
  match directPreview.state.mode with
  | .preview _ choice => expect (choice.val == 0) "direct preview did not select Publish"
  | .editing => throw (IO.userError "final amount Enter did not open preview")
  | .enableUnresolved => throw (IO.userError "final amount Enter opened unresolved activation")
  | .originalAmount _ => throw (IO.userError "final amount Enter opened original amount editor")
  expect (directPreview.publish.isNone) "direct preview published without confirmation"
  expect ((update w [] directPreview.state .enter).publish.isSome)
    "direct preview did not preserve explicit publish confirmation"
  let finalAmountTab := update w [] { form := finalAmountForm } .tab
  expect (finalAmountTab.state.form.focus.val == 7)
    "Tab from final amount reaches Preview action"
  let previewActionForm := { readyForm with focus := ⟨7, by decide⟩ }
  let previewed := update w [] { form := previewActionForm } .enter
  match previewed.state.mode with
  | .preview _ choice => expect (choice.val == 0) "Preview action did not open preview"
  | .editing => throw (IO.userError "Preview action did not open preview")
  | .enableUnresolved => throw (IO.userError "Preview action opened unresolved activation")
  | .originalAmount _ => throw (IO.userError "Preview action opened original amount editor")

  let addPostingForm := { readyForm with focus := ⟨8, by decide⟩ }
  let added := update w [] { form := addPostingForm } .enter
  expect (added.state.form.rows.size == 3) "Add posting did not append one row"
  expect (added.state.form.focus.val == 7) "Add posting did not focus the new Locus"
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

  let unresolvedStartForm : Form := {
    readyForm with
    description := "bulk purchase"
    rows := #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" }] }
  let unresolvedPrompt := update w [] { form := unresolvedStartForm } (.ctrl 'u')
  expect (unresolvedPrompt.state.form.rows == unresolvedStartForm.rows)
    "unresolved activation prompt changed rows before policy admission"
  expect (!unresolvedPrompt.enableUnresolved)
    "unresolved activation prompt requested durable policy without confirmation"
  match unresolvedPrompt.state.mode with
  | .enableUnresolved => pure ()
  | _ => throw (IO.userError "missing suspense Locus did not open explicit activation confirmation")
  let unresolvedEnable := update w [] unresolvedPrompt.state .enter
  expect unresolvedEnable.enableUnresolved
    "explicit unresolved confirmation did not emit activation intent"
  expect (unresolvedEnable.publish.isNone)
    "unresolved activation confirmation also emitted Actual publication"
  let unresolvedBack := update w [] unresolvedPrompt.state (.input 'e')
  match unresolvedBack.state.mode with
  | .editing => pure ()
  | _ => throw (IO.userError "unresolved activation return did not restore editing")

  let activationRoot := root / "unresolved-activation"
  IO.FS.createDirAll activationRoot
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? activationRoot w
    | throw (IO.userError "initialize unresolved activation fixture")
  let actualBeforeActivation ← IO.FS.readFile (activationRoot / "actual.loam")
  let .ok enabled ← Loam.Tui.UnresolvedActivation.enable? activationRoot
    | throw (IO.userError "enable unresolved recording")
  expect (enabled.world.locusAdmission.allows unresolvedLocus)
    "unresolved activation did not survive canonical world reload"
  expect ((← IO.FS.readFile (activationRoot / "actual.loam")) == actualBeforeActivation)
    "unresolved activation changed Actual authority"
  let .ok enabledAgain ← Loam.Tui.UnresolvedActivation.enable? activationRoot
    | throw (IO.userError "repeat unresolved activation did not converge")
  expect (enabledAgain.world.locusAdmission.allows unresolvedLocus)
    "repeat unresolved activation lost admitted suspense Locus"
  expect ((← IO.FS.readFile (activationRoot / "actual.loam")) == actualBeforeActivation)
    "repeat unresolved activation changed Actual authority"

  let some unresolvedVocabulary := LocusAdmissionVocabulary.ofLoci?
      [⟨"paypay"⟩, ⟨"books"⟩, ⟨"food"⟩, unresolvedLocus]
    | throw (IO.userError "unresolved vocabulary")
  let unresolvedWorld : Loam.MovementAdmission.World := {
    w with locusAdmission := unresolvedVocabulary }

  let unresolvedFilled := update unresolvedWorld [] { form := unresolvedStartForm } (.ctrl 'u')
  expect (unresolvedFilled.state.form.rows == #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" },
      { locus := "suspense", amount := "4600" }])
    "unresolved remainder did not append the exact balancing posting"
  let .ok unresolvedDraft := draft? unresolvedFilled.state.form
    | throw (IO.userError "filled unresolved Movement did not parse")
  expect ((Loam.MovementAdmission.admit? unresolvedWorld unresolvedDraft).isOk)
    "filled unresolved Movement did not pass ordinary Movement admission"

  let partialForm : Form := replaceRows unresolvedStartForm #[
    { locus := "paypay", amount := "-5800" },
    { locus := "books", amount := "1200" },
    { locus := "food", amount := "2000" },
    { locus := "suspense", amount := "4600" }]
  let partialAdjusted := update unresolvedWorld [] { form := partialForm } (.ctrl 'u')
  expect (partialAdjusted.state.form.rows == #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" },
      { locus := "food", amount := "2000" },
      { locus := "suspense", amount := "2600" }])
    "unresolved remainder did not adjust an existing suspense posting"

  let resolvedForm : Form := replaceRows unresolvedStartForm #[
    { locus := "paypay", amount := "-5800" },
    { locus := "books", amount := "1200" },
    { locus := "food", amount := "4600" },
    { locus := "suspense", amount := "2600" }]
  let resolvedFilled := update unresolvedWorld [] { form := resolvedForm } (.ctrl 'u')
  expect (resolvedFilled.state.form.rows == #[
      { locus := "paypay", amount := "-5800" },
      { locus := "books", amount := "1200" },
      { locus := "food", amount := "4600" }])
    "zero unresolved remainder did not remove the suspense posting"
  let .ok resolvedDraft := draft? resolvedFilled.state.form
    | throw (IO.userError "fully classified Movement did not parse")
  expect ((Loam.MovementAdmission.admit? unresolvedWorld resolvedDraft).isOk)
    "fully classified Movement failed ordinary admission after suspense removal"

  let blankCandidateForm : Form := {
    readyForm with
    rows := #[
      { locus := "", amount := "-2470" },
      { locus := "books", amount := "2470" }]
    focus := ⟨3, by decide⟩ }
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

  -- Exact matching token must not be substituted by a prefix neighbor on Enter or Right
  let some foodVocab := LocusAdmissionVocabulary.ofLoci? [⟨"food"⟩, ⟨"food-stock"⟩]
    | throw (IO.userError "prefix vocabulary")
  let foodWorld : Loam.MovementAdmission.World := { w with locusAdmission := foodVocab }
  let exactTypedForm : Form := {
    readyForm with
    rows := #[
      { locus := "food", amount := "170" },
      { locus := "paypay", amount := "-170" }]
    focus := ⟨3, by decide⟩ }
  let exactKnown := ["food", "food-stock"]
  let exactStart : State := { form := exactTypedForm }
  let exactPrepared := (update foodWorld exactKnown exactStart .other).state
  expect ((catalogCandidates exactPrepared).map (fun entry => entry.locus.token) == ["food", "food-stock"])
    "exact match was not ordered first in catalog candidates"
  expect ((selectedCatalogCandidate? exactPrepared).map (fun entry => entry.locus.token) == some "food")
    "exact match was not the default selected candidate"
  let exactEnter := (update foodWorld exactKnown exactStart .enter).state
  expect (exactEnter.form.rows[0]!.locus == "food")
    "Enter substituted exact typed Locus with another candidate"
  expect (exactEnter.form.focus.val == 4)
    "Enter from Locus did not advance to Amount field"
  let exactRight := (update foodWorld exactKnown exactStart .right).state
  expect (exactRight.form.rows[0]!.locus == "food")
    "Right substituted exact typed Locus with another candidate"
  expect (exactRight.form.focus.val == 4)
    "Right from Locus did not advance to Amount field"
  let exactDown := (update foodWorld exactKnown exactStart .down).state
  expect ((selectedCatalogCandidate? exactDown).map (fun entry => entry.locus.token) == some "food-stock")
    "Down did not select prefix neighbor candidate"
  let chosenEnter := (update foodWorld exactKnown exactDown .enter).state
  expect (chosenEnter.form.rows[0]!.locus == "food-stock")
    "Enter did not accept explicitly chosen candidate"

  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root w
    | throw (IO.userError "initialize fixture")
  let beforeReview ← IO.FS.readFile (root / "actual.loam")
  let .ok () ← Loam.MovementDraftReview.check root draft
    | throw (IO.userError "read-only Movement draft review")
  expect ((← IO.FS.readFile (root / "actual.loam")) == beforeReview)
    "Movement draft review changed Actual authority"
  -- An already-previewed draft must be re-admitted against policy changed during think time.
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root
      { w with locusAdmission := LocusAdmissionVocabulary.empty }
    | throw (IO.userError "change fixture policy")
  let before ← IO.FS.readFile (root / "actual.loam")
  let refusedReview ← Loam.MovementDraftReview.check root draft
  expect (!refusedReview.isOk) "Movement draft review bypassed current Locus policy"
  expect ((← IO.FS.readFile (root / "actual.loam")) == before)
    "refused Movement draft review changed authority"
  let refused ← Loam.MovementPublisher.publishDraft root.toString draft
  expect (!refused.isOk) "stale preview bypassed current Locus policy"
  expect ((← IO.FS.readFile (root / "actual.loam")) == before) "refusal changed authority"
  let .ok _ ← Loam.Tests.ActualWorldFixture.publishWorld? root w
    | throw (IO.userError "restore fixture policy")
  let .ok eventId ← Loam.MovementPublisher.publishDraft root.toString draft
    | throw (IO.userError "canonical publish")
  let .ok records ← Loam.ActualReview.loadRecordsFromActual root
    | throw (IO.userError "canonical review reload")
  expect (records.length == 1) "reload did not see exactly one record"
  expect (records.any fun record => record.event.id.token == eventId.token &&
    record.description == "数学ガール" && record.date == some "2026-09-06")
    "fresh review lost published evidence"
  IO.println "TUI Record: signed postings, canonical catalog selection, read-only proposal review, admission, stale policy rejection, publication and fresh review passed."
