import Loam.CapacityPublisher
import Loam.CapacityReview
import Loam.Tui.CapacityTransfer
import Lean.Elab.Tactic.Omega

open Loam.Core Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def expectError {α : Type}
    (result : Except String α) (message : String) : IO Unit :=
  match result with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

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

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let capacityFile := dataDir / "capacity.loam"

  let empty ← loadSnapshot capacityFile
  expect empty.rows.isEmpty "isolated Capacity fixture was not empty"
  let initial := Loam.Tui.CapacityTransfer.initial empty "2026-09-12"
  expect (initial.form.source == "unallocated" && initial.form.destination.isEmpty)
    "empty Capacity transfer did not seed the minimal unallocated entrance"
  expect (initial.form.effectiveOn == "2026-09-12")
    "Capacity transfer did not seed the caller's explicit focus date"
  let initialText := widgetText (Loam.Tui.CapacityTransfer.view initial)
  expect (contains "not money available to allocate" initialText)
    "Capacity transfer editor lost the unallocated boundary warning"
  expect (Loam.CapacityPublisher.parseCoordinate? "food" == some (.purpose ⟨"food"⟩))
    "shared Capacity endpoint parser rejected a new Purpose token"

  let grantState : Loam.Tui.CapacityTransfer.State := {
    initial with form := {
      initial.form with destination := "food", amount := "5000" } }
  let .ok grantDraft := Loam.Tui.CapacityTransfer.draft? grantState
    | throw (IO.userError "build TUI Capacity grant draft")
  expect (grantDraft.source == .unallocated &&
      grantDraft.destination == .purpose ⟨"food"⟩ && grantDraft.quanta == 5000)
    "TUI Capacity grant draft changed endpoint or amount semantics"
  let grantPreview : Loam.Tui.CapacityTransfer.State := {
    grantState with mode := .preview grantDraft ⟨0, by omega⟩ }
  let grantStep := Loam.Tui.CapacityTransfer.update grantPreview .enter
  let grantIntent ← requireSome grantStep.publish
    "Capacity Preview/Publish did not emit a shared publisher draft"
  let .ok grantReceipt ← Loam.CapacityPublisher.publish capacityFile.toString grantIntent
    | throw (IO.userError "publish TUI Capacity grant")
  expect (grantReceipt.movement.token == "capacity-1")
    "TUI Capacity grant did not publish the first fresh identity"

  let afterGrant ← loadSnapshot capacityFile
  expect (rowQuanta? afterGrant.rows "food" == some 5000)
    "fresh Capacity review did not expose the granted food Entitlement"

  let selectedFood := Loam.Tui.CapacityTransfer.initial
    afterGrant "2026-09-13" (some ⟨"food"⟩)
  expect (selectedFood.form.destination == "food")
    "selected Capacity Purpose was not used as a presentation-only destination seed"
  let transferState : Loam.Tui.CapacityTransfer.State := {
    selectedFood with form := {
      selectedFood.form with
      source := "food"
      destination := "rent"
      amount := "2000"
    } }
  let .ok transferDraft := Loam.Tui.CapacityTransfer.draft? transferState
    | throw (IO.userError "build TUI Capacity purpose transfer draft")
  expect (transferDraft.source == .purpose ⟨"food"⟩ &&
      transferDraft.destination == .purpose ⟨"rent"⟩ &&
      transferDraft.effectiveOn == "2026-09-13")
    "TUI Capacity transfer changed source, destination, or effective day"
  let transferPreview : Loam.Tui.CapacityTransfer.State := {
    transferState with mode := .preview transferDraft ⟨0, by omega⟩ }
  let transferIntent ← requireSome
    (Loam.Tui.CapacityTransfer.update transferPreview .enter).publish
    "Capacity purpose transfer preview did not emit publication intent"
  let .ok transferReceipt ← Loam.CapacityPublisher.publish capacityFile.toString transferIntent
    | throw (IO.userError "publish TUI Capacity purpose transfer")
  expect (transferReceipt.movement.token == "capacity-2")
    "TUI Capacity purpose transfer did not allocate the next fresh identity"

  let fresh ← loadSnapshot capacityFile
  expect (rowQuanta? fresh.rows "food" == some 3000)
    "fresh Capacity review did not reduce the source Entitlement"
  expect (rowQuanta? fresh.rows "rent" == some 2000)
    "fresh Capacity review did not increase the destination Entitlement"

  let insufficientBase := Loam.Tui.CapacityTransfer.initial fresh "2026-09-14"
  let insufficient : Loam.Tui.CapacityTransfer.State := {
    insufficientBase with form := {
      insufficientBase.form with
      source := "food"
      destination := "rent"
      amount := "4000"
    } }
  expectError (Loam.Tui.CapacityTransfer.draft? insufficient)
    "Capacity editor previewed more than the visible named-source Entitlement"

  let cancelled := Loam.Tui.CapacityTransfer.update initial .escape
  expect (cancelled.cancel && cancelled.publish.isNone)
    "Capacity transfer Esc emitted publication"

  let previewText := widgetText (Loam.Tui.CapacityTransfer.view transferPreview)
  expect (contains "food: 5000 -> 3000 jpy" previewText)
    "Capacity transfer preview omitted source current-to-after Entitlement"
  expect (contains "rent: 0 -> 2000 jpy" previewText)
    "Capacity transfer preview omitted destination current-to-after Entitlement"

  IO.println "TUI Capacity transfer: empty grant, selected-purpose seed, purpose transfer, preview impact, shared publication and fresh review passed."
