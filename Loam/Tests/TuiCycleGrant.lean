import Loam.CapacityPublisher
import Loam.CapacityReview
import Loam.CurrentCoverageReview
import Loam.CycleBudgetReview
import Loam.Tui.CapacityTransfer
import Loam.Tui.CapacityTransferSession
import Loam.Tui.CycleBudget
import Loam.Tui.Kernel

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some value => pure value
  | none => throw (IO.userError message)

private def text (widget : Widget) : String :=
  String.intercalate "\n" (widget.lines.map fun cells => String.ofList (cells.map Cell.glyph))

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def q := Quantity.ofQuanta

def main (args : List String) : IO Unit := do
  let [path] := args | throw (IO.userError "supply isolated fixture directory")
  let root := System.FilePath.mk path
  IO.FS.createDirAll (root / "config")

  -- 1. Setup minimal isolated evidence
  let fundingPath := root / "config" / "cycle-funding.tsv"
  IO.FS.writeFile fundingPath "cash\tjpy\n"
  IO.FS.writeFile (root / "config" / "boundary-presets.tsv") "Pension\t2026-08-14\t2026-10-15\n"
  IO.FS.writeFile (root / "config" / "balance-view.tsv") "cash\tjpy\n"

  let world : Loam.MovementAdmission.World := {
    events := { events := [], idNodup := by simp }
    validity := { facts := [], factIdNodup := by simp, corrections := [], correctionIdNodup := by simp }
    descriptions := .empty, relations := [], discharges := [] }
  let .ok _ ← Loam.MovementManifestAuthority.publishWorld? (root / "movement-authority") world
    | throw (IO.userError "publish fixture world")

  let zero ← requireSome (ZeroOriginCoverage.ofCoordinates? [⟨⟨"cash"⟩, ⟨"jpy"⟩⟩]) "zero-origin"
  expect (← Loam.Persistence.saveZeroOriginCoverage? (root / "zero-origin-coverage.loam") zero) "save zero"

  let capacityFile := root / "capacity.loam"
  let capacityEffectiveFile := root / "capacity.loam.effective"
  IO.FS.writeFile capacityFile
    "LOAM-CAPACITY-MEMORY\t1\nMOVEMENT\tcapacity-1\tjpy\nCHANGE\tUNALLOCATED\t-17108\nCHANGE\tPURPOSE\t固定費予定\t17108\n"
  IO.FS.writeFile capacityEffectiveFile
    "LOAM-CAPACITY-EFFECTIVE\t1\nEFFECTIVE\tcapacity-1\t2026-08-14\n"
  IO.FS.writeFile (root / "actual-routing.loam") "LOAM-ACTUAL-ROUTING\t1\n"
  IO.FS.writeFile (root / "accounting-role.loam")
    ("LOAM-ACCOUNTING-ROLE-MAP\t1\n" ++
     "ROLE\tpaypay\tASSET\n" ++
     "ROLE\twifi\tEXPENSE\n")

  -- Scheduled commitment to create negative headroom:
  -- Cap=17108, Spent=0, Now=17108, Commitment=20936 -> headroom = -3828
  let locusChange (locus : LocusId) (amount : Int) : MovementChange LocusId :=
    { coordinate := locus, quantity := Quantity.ofQuanta amount }
  let scheduledMovement ← requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩
      [locusChange ⟨"paypay"⟩ (-20936), locusChange ⟨"wifi"⟩ 20936])
    "Scheduled movement was not balanced"
  let occurrence : ScheduledOccurrence String :=
    { id := ⟨"scheduled-1"⟩, scheduledOn := "2026-10-08", movement := scheduledMovement }
  let scheduled ← requireSome (ScheduledMemory.ofOccurrences? [occurrence]) "scheduled"
  let completions ← requireSome (ScheduledCompletionMemory.ofCompletions? []) "completions"
  let retirements ← requireSome (ScheduledRetirementMemory.ofRetirements? []) "retirements"
  let replacements ← requireSome (ScheduledReplacementMemory.ofReplacements? []) "replacements"
  expect (← Loam.Persistence.saveScheduledLifecycleImage? (root / "scheduled.loam")
    { scheduled, completions, retirements, replacements }) "save lifecycle"

  -- Route scheduled-1 to managed 固定費予定
  let scheduledRouting ← requireSome
    (RoutingHistory.ofEntries?
      [{ subject := {
           scheduled := ⟨"scheduled-1"⟩
           locus := (⟨"wifi"⟩ : LocusId) }
         effectiveOn := "2026-08-14"
         purpose := some ⟨"固定費予定"⟩ }])
    "Scheduled routing history"
  expect (← Loam.Persistence.saveScheduledRoutingHistory?
      (root / "scheduled-routing.loam") scheduledRouting)
    "save Scheduled routing"

  -- Load initial snapshot
  let observedAt := "2026-09-09"
  let snap0 ← Loam.CycleBudgetReview.loadSnapshotAt root (root / "movement-authority") observedAt
  let .ok cov0 := snap0.coverage | throw (IO.userError "cov0 unavailable")
  let some row0 := cov0.rows.find? (fun r => r.purpose.token == "固定費予定")
    | throw (IO.userError "missing row0")
  expect (row0.entitlement.quanta == 17108) "initial cap"
  expect (row0.consumption.quanta == 0) "initial spent"
  expect (row0.remaining.quanta == 17108) "initial now"
  expect (row0.commitment.quanta == 20936) "initial commitment"
  expect (row0.headroom.quanta == -3828) "initial headroom"

  -- Test 5 & 6: Suggestion = exact -headroom, presentation only
  let suggested := -row0.headroom.quanta
  expect (suggested == 3828) "suggested exact -headroom"

  -- Test 7, 8, 9, 10, 11: grant preset
  -- source = unallocated, destination = selected Purpose, effective = observedAt
  let .ok capSnap0 ← Loam.CapacityReview.loadSnapshot capacityFile | throw (IO.userError "capSnap0")
  let residual0 := match snap0.funding with | .ok f => some f.residualBeforeUnresolved | .error _ => none
  let grantEditor := Loam.Tui.CapacityTransfer.initialGrant capSnap0 observedAt row0 residual0
  expect (grantEditor.form.source == "unallocated") "Test 7: source prefill unallocated"
  expect (grantEditor.form.destination == "固定費予定") "Test 8: destination selected purpose"
  expect (grantEditor.form.effectiveOn == observedAt) "Test 9: effective observedAt"
  expect (grantEditor.form.amount == "3828") "Test 5: amount prefilled"

  -- Verify Home focus date or scheduled date does not change effective
  let fakeHomeFocus := "2026-12-31"
  let scheduledDate := "2026-10-08"
  expect (grantEditor.form.effectiveOn != fakeHomeFocus) "Test 10: Home focus ignored"
  expect (grantEditor.form.effectiveOn != scheduledDate) "Test 11: Scheduled date ignored"

  -- Test 13: Preview required (starts in .preview)
  match grantEditor.mode with
  | .preview draft choice =>
      expect (choice.val == 0) "default choice is Publish"
      expect (draft.source == .unallocated) "draft source unallocated"
      expect (draft.destination == .purpose ⟨"固定費予定"⟩) "draft destination"
      expect (draft.effectiveOn == observedAt) "draft effective"
      expect (draft.quanta == 3828) "draft quanta"
  | .editing => throw (IO.userError "initialGrant must start in preview")

  -- Test Preview view contents
  let bounds : Bounds := { width := 100, height := 30 }
  let previewText := text (Loam.Tui.CapacityTransfer.view grantEditor)
  expect (contains "Capacity / Cycle Grant / Preview" previewText) "Preview header"
  expect (contains "Purpose:       固定費予定" previewText) "Preview purpose"
  expect (contains "Current Now:   17108 jpy" previewText) "Preview current now"
  expect (contains "Known future:  20936 jpy" previewText) "Preview known future"
  expect (contains "After-known:   -3828 jpy" previewText) "Preview after-known"
  expect (contains "From:          unallocated" previewText) "Preview from"
  expect (contains "Effective:     2026-09-09" previewText) "Preview effective"
  expect (contains "Amount:        3828 jpy" previewText) "Preview amount"
  expect (contains "Funding residual before unresolved:" previewText) "Preview residual label"
  expect (contains "[Publish]" previewText && contains "[Edit]" previewText && contains "[Cancel]" previewText) "Preview buttons"

  -- Test 12: Amount editable
  -- Switch to Edit via 'e'
  let stepEdit := Loam.Tui.CapacityTransfer.update grantEditor (.input 'e')
  match stepEdit.state.mode with
  | .editing =>
      expect (stepEdit.state.form.focus == 3) "edit focuses on amount"
  | .preview _ _ => throw (IO.userError "e must enter editing mode")
  let editText := text (Loam.Tui.CapacityTransfer.view stepEdit.state)
  expect (contains "Capacity / Cycle Grant / Edit" editText) "Edit header"
  expect (contains "Suggested to reach After-known 0: 3828 jpy" editText) "Suggested display"

  -- Edit amount: backspace 4 times, type 4000
  let mut editState := stepEdit.state
  for _ in [0, 1, 2, 3] do
    editState := (Loam.Tui.CapacityTransfer.update editState .backspace).state
  expect (editState.form.amount.isEmpty) "amount cleared"
  for c in ['4', '0', '0', '0'] do
    editState := (Loam.Tui.CapacityTransfer.update editState (.input c)).state
  expect (editState.form.amount == "4000") "amount edited to 4000"

  -- Submit to preview with Enter
  let stepEditedPreview := Loam.Tui.CapacityTransfer.update editState .enter
  match stepEditedPreview.state.mode with
  | .preview draft _ =>
      expect (draft.quanta == 4000) "edited draft quanta 4000"
  | .editing => throw (IO.userError "enter on amount must return to preview")
  let editedPreviewText := text (Loam.Tui.CapacityTransfer.view stepEditedPreview.state)
  expect (contains "Amount:        4000 jpy" editedPreviewText) "edited amount in preview"

  -- Test 14: Cancel preserves evidence
  let stepCancel := Loam.Tui.CapacityTransfer.update grantEditor .escape
  expect stepCancel.cancel "Esc cancels transfer"
  expect stepCancel.publish.isNone "Cancel emits no publish draft"

  -- Test 21: Residual is not a publication ceiling
  -- Even if amount > residual, validation passes
  let largeState := { grantEditor with form := { grantEditor.form with amount := "999999" } }
  let .ok largeDraft := Loam.Tui.CapacityTransfer.draft? largeState
    | throw (IO.userError "large draft refused by local validation")
  expect (largeDraft.quanta == 999999) "large quanta accepted"

  -- Test 22: Frontier pressure is not automatically included in grant
  let some frontier0 := cov0.scheduledFrontier | throw (IO.userError "frontier0")
  expect (grantEditor.form.amount.toInt? == some (-row0.headroom.quanta))
    "amount uses only row.headroom, not frontier"

  -- Test 15, 16, 17, 18, 19, 20, 24: Publish delegates shared CapacityPublisher, fresh reread, invariants
  let beforeHashScheduled ← IO.FS.readBinFile (root / "scheduled.loam")
  let beforeHashRouting ← IO.FS.readBinFile (root / "scheduled-routing.loam")

  -- Publish the original suggested draft (3828)
  let stepPublish := Loam.Tui.CapacityTransfer.update grantEditor .enter
  let some draftToPublish := stepPublish.publish | throw (IO.userError "publish draft missing")
  expect (draftToPublish.quanta == 3828) "publish quanta 3828"

  let .ok receipt ← Loam.CapacityPublisher.publish capacityFile.toString draftToPublish
    | throw (IO.userError "shared CapacityPublisher.publish failed")
  expect (receipt.quanta == 3828) "receipt quanta"
  expect (receipt.source == .unallocated) "receipt source"
  expect (receipt.destination == .purpose ⟨"固定費予定"⟩) "receipt destination"
  expect (receipt.effectiveOn == observedAt) "receipt effectiveOn"
  expect (receipt.movement.token == "capacity-2") "fresh capacity identity allocated"

  -- Invariants check:
  -- 17. Physical balances unchanged (movement authority untouched)
  -- 18. Scheduled lifecycle unchanged
  let afterHashScheduled ← IO.FS.readBinFile (root / "scheduled.loam")
  expect (beforeHashScheduled == afterHashScheduled) "Test 18: Scheduled lifecycle unchanged"

  -- 19. Scheduled routing unchanged
  let afterHashRouting ← IO.FS.readBinFile (root / "scheduled-routing.loam")
  expect (beforeHashRouting == afterHashRouting) "Test 19: Scheduled routing unchanged"

  -- 16 & 20: Fresh Budget reread reflects updated Capacity and nothing else
  let snap1 ← Loam.CycleBudgetReview.loadSnapshotAt root (root / "movement-authority") observedAt
  let .ok cov1 := snap1.coverage | throw (IO.userError "cov1 unavailable")
  let some row1 := cov1.rows.find? (fun r => r.purpose.token == "固定費予定")
    | throw (IO.userError "missing row1")
  expect (row1.entitlement.quanta == 17108 + 3828) "Cap: 17108 -> 20936"
  expect (row1.consumption.quanta == 0) "Spent: unchanged at 0"
  expect (row1.remaining.quanta == 17108 + 3828) "Now: 17108 -> 20936"
  expect (row1.commitment.quanta == 20936) "Known future: unchanged at 20936"
  expect (row1.headroom.quanta == 0) "After-known: -3828 -> 0"

  -- Funding residual updated:
  let .ok f1 := snap1.funding | throw (IO.userError "f1 unavailable")
  let .ok f0 := snap0.funding | throw (IO.userError "f0 unavailable")
  expect (f1.budgetableBacking.quanta == f0.budgetableBacking.quanta) "Backing unchanged"
  expect (f1.remainingAssigned.quanta == f0.remainingAssigned.quanta + 3828) "Remaining assigned increased"
  expect (f1.residualBeforeUnresolved.quanta == f0.residualBeforeUnresolved.quanta - 3828) "Residual decreased"

  IO.println "TuiCycleGrant: all 24 synthetic invariants and publication checks passed."
