import Loam.CapacityPublisher
import Loam.CapacityReview
import Loam.CurrentCoverageReview
import Loam.Tui.CapacityRebalance
import Lean.Elab.Tactic.Omega

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def expectError {α : Type}
    (result : Except String α) (message : String) : IO Unit :=
  match result with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError message)

private def widgetText (widget : Widget) : String :=
  String.intercalate "\n" <| widget.lines.map fun cells =>
    String.ofList (cells.map Cell.glyph)

private def contains (needle haystack : String) : Bool :=
  (haystack.splitOn needle).length > 1

private def rowQuanta?
    (rows : List Loam.CapacityReview.Row) (token : String) : Option Int :=
  match rows with
  | [] => none
  | row :: rest =>
      if row.purpose.token = token then some row.entitlement.quanta
      else rowQuanta? rest token

private def loadSnapshot (capacityFile : System.FilePath) : IO Loam.CapacityReview.Snapshot := do
  let .ok snapshot ← Loam.CapacityReview.loadSnapshot capacityFile
    | throw (IO.userError "load Capacity snapshot")
  pure snapshot

private def applyKeys (state : Loam.Tui.CapacityRebalance.State) (keys : List Loam.Tui.Terminal.Key) :
    Loam.Tui.CapacityRebalance.State :=
  keys.foldl (fun s k => (Loam.Tui.CapacityRebalance.update s k).state) state

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let capacityFile := dataDir / "capacity.loam"

  -- Seed initial capacity
  let seedFood : Loam.CapacityPublisher.Draft := {
    effectiveOn := "2026-09-08"
    source := .unallocated
    destination := .purpose ⟨"food"⟩
    quanta := 39000
  }
  let .ok _ ← Loam.CapacityPublisher.publish capacityFile.toString seedFood
    | throw (IO.userError "seed food")
  let .ok _ ← Loam.CapacityPublisher.publish capacityFile.toString {
    effectiveOn := "2026-09-08"
    source := .unallocated
    destination := .purpose ⟨"stock"⟩
    quanta := 7000
  } | throw (IO.userError "seed stock")
  let .ok _ ← Loam.CapacityPublisher.publish capacityFile.toString {
    effectiveOn := "2026-09-08"
    source := .unallocated
    destination := .purpose ⟨"living"⟩
    quanta := 22346
  } | throw (IO.userError "seed living")

  let seedSnapshot ← loadSnapshot capacityFile
  expect (seedSnapshot.rows.length == 3) "seed rows count"

  let coverageSnapshot : Loam.CurrentCoverageReview.Snapshot := {
    currentWindowStart := "2026-08-15"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-01"
    rows := [
      { purpose := ⟨"food"⟩, entitlement := Quantity.ofQuanta 39000, consumption := Quantity.ofQuanta 18672,
        remaining := Quantity.ofQuanta 20328, commitment := Quantity.ofQuanta 0, headroom := Quantity.ofQuanta 20328 },
      { purpose := ⟨"stock"⟩, entitlement := Quantity.ofQuanta 7000, consumption := Quantity.ofQuanta 8180,
        remaining := Quantity.ofQuanta (-1180), commitment := Quantity.ofQuanta 0, headroom := Quantity.ofQuanta (-1180) },
      { purpose := ⟨"living"⟩, entitlement := Quantity.ofQuanta 22346, consumption := Quantity.ofQuanta 27892,
        remaining := Quantity.ofQuanta (-5546), commitment := Quantity.ofQuanta 0, headroom := Quantity.ofQuanta (-5546) }
    ]
    scheduledFrontier := some {
      unmanaged := Quantity.ofQuanta 0
      unrouted := Quantity.ofQuanta 0
      unresolvedEligibility := Quantity.ofQuanta 0
    }
  }

  let bounds : Bounds := { width := 80, height := 24 }

  -- 1. Initial state and view
  let state0 := Loam.Tui.CapacityRebalance.initial seedSnapshot (some coverageSnapshot) "2026-09-08"
  let view0 := widgetText (Loam.Tui.CapacityRebalance.view bounds state0)
  expect (contains "Capacity / Rebalance" view0) "heading missing"
  expect (contains "Proposal balance" view0 && contains "0  ✓" view0) "initial balance missing"
  expect (contains "Negative proposed entitlement" view0 && contains "none ✓" view0) "initial negs missing"
  expect (contains "food" view0 && contains "39000" view0) "food row missing"
  expect (contains "stock" view0 && contains "7000" view0) "stock row missing"
  expect (contains "living" view0 && contains "22346" view0) "living row missing"

  -- 2. Navigation: down to stock, then living, then up to food
  let stepDown1 := Loam.Tui.CapacityRebalance.update state0 .down
  expect (Loam.Tui.CapacityRebalance.selectedPurpose? stepDown1.state == some ⟨"stock"⟩) "down did not select stock"
  let stepDown2 := Loam.Tui.CapacityRebalance.update stepDown1.state .down
  expect (Loam.Tui.CapacityRebalance.selectedPurpose? stepDown2.state == some ⟨"living"⟩) "down did not select living"
  let stepUp1 := Loam.Tui.CapacityRebalance.update stepDown2.state .up
  expect (Loam.Tui.CapacityRebalance.selectedPurpose? stepUp1.state == some ⟨"stock"⟩) "up did not select stock"
  let stepUp2 := Loam.Tui.CapacityRebalance.update stepUp1.state .up
  expect (Loam.Tui.CapacityRebalance.selectedPurpose? stepUp2.state == some ⟨"food"⟩) "up did not select food"

  -- 3. Edit signed delta for food: e -> -3000 -> enter
  let stateFood := stepUp2.state
  let stepEditFood := Loam.Tui.CapacityRebalance.update stateFood (.input 'e')
  expect (match stepEditFood.state.mode with | .editingDelta _ => true | _ => false) "e did not enter editingDelta"

  -- Type "-3000" and enter
  let sFDone := applyKeys stepEditFood.state [.input '-', .input '3', .input '0', .input '0', .input '0', .enter]
  expect (sFDone.proposal.delta ⟨"food"⟩ == -3000) "food delta was not set to -3000"
  expect (!sFDone.proposal.isBalanced) "single edit should be unbalanced"
  expect (sFDone.proposal.balance == -3000) "balance should be -3000"

  -- 9. Live proposal balance rendering check while unbalanced
  let viewUnbalanced := widgetText (Loam.Tui.CapacityRebalance.view bounds sFDone)
  expect (contains "unbalanced" viewUnbalanced) "view did not show unbalanced warning"
  expect (contains "36000" viewUnbalanced) "proposed food entitlement 36000 missing"

  -- 4. Edit stock (+1180) and living (+1820)
  let sStock := (Loam.Tui.CapacityRebalance.update sFDone .down).state
  expect (Loam.Tui.CapacityRebalance.selectedPurpose? sStock == some ⟨"stock"⟩) "select stock"
  let sStockDone := applyKeys sStock [.input 'e', .input '1', .input '1', .input '8', .input '0', .enter]

  let sLiving := (Loam.Tui.CapacityRebalance.update sStockDone .down).state
  expect (Loam.Tui.CapacityRebalance.selectedPurpose? sLiving == some ⟨"living"⟩) "select living"
  let sBalanced := applyKeys sLiving [.input 'e', .input '1', .input '8', .input '2', .input '0', .enter]

  -- 9. Live proposal balance rendering check when balanced
  expect (sBalanced.proposal.isBalanced) "3-purpose rebalance should be balanced"
  expect (sBalanced.proposal.balance == 0) "balance should be 0"
  let viewBalanced := widgetText (Loam.Tui.CapacityRebalance.view bounds sBalanced)
  expect (contains "Proposal balance" viewBalanced && contains "0  ✓" viewBalanced) "view did not show 0 ✓"
  expect (contains "36000" viewBalanced) "proposed food 36000"
  expect (contains "8180" viewBalanced) "proposed stock 8180"
  expect (contains "24166" viewBalanced) "proposed living 24166"

  -- 5. Clear selected delta with '0'
  let stepClearZero := Loam.Tui.CapacityRebalance.update sBalanced (.input '0')
  expect (stepClearZero.state.proposal.delta ⟨"living"⟩ == 0) "0 key did not clear living delta"
  expect (!stepClearZero.state.proposal.isBalanced) "after 0 key proposal should be unbalanced"

  -- Restore living delta
  let sRestoredBalanced := applyKeys stepClearZero.state [.input 'e', .input '1', .input '8', .input '2', .input '0', .enter]
  expect (sRestoredBalanced.proposal.isBalanced) "restored balanced"

  -- 6. Clear entire proposal with 'c'
  let stepClearAll := Loam.Tui.CapacityRebalance.update sRestoredBalanced (.input 'c')
  expect (!stepClearAll.state.proposal.hasChanges) "c key did not clear all deltas"
  expect (stepClearAll.state.proposal.isBalanced) "cleared proposal is balanced"

  -- 7. Negative proposed entitlement refusal
  -- Re-enter proposal with stock overdraft (-8000 when stock entitlement is 7000)
  let sStockAgain := (Loam.Tui.CapacityRebalance.update state0 .down).state
  let sStockOverdraft := applyKeys sStockAgain [.input 'e', .input '-', .input '8', .input '0', .input '0', .input '0', .enter]
  -- Balance it with food +8000
  let sFoodAgain := (Loam.Tui.CapacityRebalance.update sStockOverdraft .up).state
  let sOverdraftBalanced := applyKeys sFoodAgain [.input 'e', .input '8', .input '0', .input '0', .input '0', .enter]

  expect (sOverdraftBalanced.proposal.isBalanced) "overdraft proposal is balanced in quanta"
  let viewOverdraft := widgetText (Loam.Tui.CapacityRebalance.view bounds sOverdraftBalanced)
  expect (contains "Negative proposed entitlement" viewOverdraft && contains "stock (-1000)" viewOverdraft)
    "negative entitlement warning missing from view"
  let stepRefusedEnter := Loam.Tui.CapacityRebalance.update sOverdraftBalanced .enter
  expect (stepRefusedEnter.publish.isNone) "negative entitlement must not emit publish draft"
  expect (match stepRefusedEnter.state.mode with | .preview _ _ => false | _ => true)
    "negative entitlement must not enter preview mode"

  -- 8. Cancel with 'q'
  let stepCancel := Loam.Tui.CapacityRebalance.update state0 (.input 'q')
  expect stepCancel.cancel "q key did not trigger cancel"

  -- 10. Preview mode, choice navigation, publish, and fresh review reload
  let sP0 := state0
  let sP_FoodDone := applyKeys sP0 [.input 'e', .input '-', .input '3', .input '0', .input '0', .input '0', .enter]
  let sP_StockSel := (Loam.Tui.CapacityRebalance.update sP_FoodDone .down).state
  let sP_StockDone := applyKeys sP_StockSel [.input 'e', .input '1', .input '1', .input '8', .input '0', .enter]
  let sP_LivingSel := (Loam.Tui.CapacityRebalance.update sP_StockDone .down).state
  let sP_Ready := applyKeys sP_LivingSel [.input 'e', .input '1', .input '8', .input '2', .input '0', .enter]

  expect (sP_Ready.proposal.isBalanced) "ready proposal must be balanced"
  let stepPreview := Loam.Tui.CapacityRebalance.update sP_Ready .enter
  expect (match stepPreview.state.mode with | .preview _ _ => true | _ => false) "enter did not enter preview mode"

  let previewText := widgetText (Loam.Tui.CapacityRebalance.view bounds stepPreview.state)
  expect (contains "Capacity / Rebalance / Preview" previewText) "preview heading missing"
  expect (contains "food" previewText && contains "-3000" previewText) "food change missing from preview"
  expect (contains "stock" previewText && contains "1180" previewText) "stock change missing from preview"
  expect (contains "living" previewText && contains "1820" previewText) "living change missing from preview"

  -- Preview choice navigation
  let stepChoiceNext := Loam.Tui.CapacityRebalance.update stepPreview.state .right
  expect (match stepChoiceNext.state.mode with | .preview _ c => c.val == 1 | _ => false) "right choice is Edit (1)"
  let stepBackToEdit := Loam.Tui.CapacityRebalance.update stepChoiceNext.state .enter
  expect (match stepBackToEdit.state.mode with | .selecting => true | _ => false) "Edit choice returned to selecting"

  -- Re-enter preview and publish
  let stepPreviewAgain := Loam.Tui.CapacityRebalance.update stepBackToEdit.state .enter
  let stepPublish := Loam.Tui.CapacityRebalance.update stepPreviewAgain.state .enter
  let some draft := stepPublish.publish | throw (IO.userError "publish draft missing")
  expect (draft.changes.length == 3) "draft must have 3 changes"

  let .ok receipt ← Loam.CapacityPublisher.publishBalanced capacityFile.toString draft
    | throw (IO.userError "failed to publish balanced draft")
  expect (receipt.movement.token == "capacity-4") "movement token"

  -- Fresh Capacity review reload
  let freshSnapshot ← loadSnapshot capacityFile
  expect (rowQuanta? freshSnapshot.rows "food" == some 36000) "fresh food 36000"
  expect (rowQuanta? freshSnapshot.rows "stock" == some 8180) "fresh stock 8180"
  expect (rowQuanta? freshSnapshot.rows "living" == some 24166) "fresh living 24166"

  IO.println "TUI Capacity Rebalance: initial view, cursor navigation, signed delta editing, live balance, negative entitlement refusal, clear actions, preview navigation, publish and fresh review passed."
