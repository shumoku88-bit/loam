import Loam.ActualRoutingPublisher
import Loam.ActualRoutingReview
import Loam.Persistence.ActualRoutingPersistence
import Loam.Tui.ActualRoutingAdministration
import Loam.Tui.Kernel

open Loam.Core
open Loam.Persistence
open Loam.Tui.Kernel
open Loam.Tui.Terminal

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

private def sample : Loam.ActualRoutingReview.Snapshot :=
  { observedAt := "2026-09-09"
    rows :=
      [ { locus := ⟨"coffee"⟩, status := .managed ⟨"food"⟩ }
      , { locus := ⟨"shipping"⟩, status := .unrouted }
      , { locus := ⟨"tobacco"⟩, status := .unmanaged }
      ]
    purposes := [⟨"food"⟩, ⟨"general"⟩]
    unresolvedRoleLoci := [⟨"mystery"⟩]
    historicalOnlyRouteLoci := [⟨"old-expense"⟩] }


def main (args : List String) : IO Unit := do
  let bounds : Bounds := { width := 100, height := 28 }
  let s0 := Loam.Tui.ActualRoutingAdministration.initial sample
  expect (s0.phase == .selectLocus) "initial phase"
  expect (s0.locusIndex == 0) "initial locus index"

  let v0 := text (Loam.Tui.ActualRoutingAdministration.view bounds s0)
  expect (contains "Purpose Administration / Actual Routing" v0) "title visible"
  expect (contains "coffee" v0 && contains "managed food" v0) "managed row visible"
  expect (contains "shipping" v0 && contains "UNROUTED" v0) "unrouted row visible"
  expect (contains "unrouted: 1" v0) "unrouted count visible"
  expect (contains "Unresolved AccountingRole: 1" v0) "role audit visible"
  expect (contains "historical-only routes: 1" v0) "historical route audit visible"

  let down := Loam.Tui.ActualRoutingAdministration.update s0 (.input 'j')
  expect (down.state.locusIndex == 1) "select shipping"
  let target := Loam.Tui.ActualRoutingAdministration.update down.state .enter
  expect (target.state.phase == .selectTarget) "enter route type"
  let purpose := Loam.Tui.ActualRoutingAdministration.update target.state .enter
  expect (purpose.state.phase == .selectPurpose) "managed opens Purpose picker"
  let purposeDown := Loam.Tui.ActualRoutingAdministration.update purpose.state .down
  expect (purposeDown.state.purposeIndex == 1) "select general"
  let preview := Loam.Tui.ActualRoutingAdministration.update purposeDown.state .enter
  expect (preview.state.phase == .preview) "purpose opens preview"
  let draft ← requireSome (Loam.Tui.ActualRoutingAdministration.draft? preview.state) "managed draft"
  expect (draft.locus.token == "shipping") "draft locus"
  expect (draft.effectiveOn == .dated "2026-09-09") "draft date"
  expect (draft.target == .managed ⟨"general"⟩) "draft target"
  let publish := Loam.Tui.ActualRoutingAdministration.update preview.state .enter
  expect (publish.publish == some draft) "preview emits draft"

  let unmanagedState := { target.state with targetChoice := .unmanaged }
  let unmanagedPreview := Loam.Tui.ActualRoutingAdministration.update unmanagedState .enter
  expect (unmanagedPreview.state.phase == .preview) "unmanaged skips Purpose picker"
  let unmanagedDraft ← requireSome
    (Loam.Tui.ActualRoutingAdministration.draft? unmanagedPreview.state) "unmanaged draft"
  expect (unmanagedDraft.target == .unmanaged) "unmanaged draft target"

  let cancel := Loam.Tui.ActualRoutingAdministration.update s0 .escape
  expect cancel.cancel "escape cancels administration"

  if args.length >= 1 then
    let root := System.FilePath.mk args.head!
    IO.FS.createDirAll root
    let routing := root / "actual-routing.loam"
    IO.FS.writeFile routing
      ("LOAM-ACTUAL-ROUTING\t1\n" ++
       "ROUTE\tcoffee\tINITIAL\tMANAGED\tfood\n")

    let result ← Loam.ActualRoutingPublisher.publish routing.toString draft
    let .ok receipt := result | throw (IO.userError "Actual routing publish failed")
    expect (receipt.locus.token == "shipping") "receipt locus"
    expect (receipt.effectiveOn == .dated "2026-09-09") "receipt date"
    expect (receipt.target == .managed ⟨"general"⟩) "receipt target"

    let history ← requireSome (← loadActualRoutingHistory? routing) "reload Actual routing"
    expect (history.entries.length == 2) "history appended"
    expect (history.statusAt ⟨"coffee"⟩ (.dated "2026-09-09") == .managed ⟨"food"⟩)
      "initial route preserved"
    expect (history.statusAt ⟨"shipping"⟩ (.dated "2026-09-09") == .managed ⟨"general"⟩)
      "dated route visible"

    let duplicate ← Loam.ActualRoutingPublisher.publish routing.toString draft
    expect (!duplicate.isOk) "duplicate locus/date rejected"

  IO.println "TUI Actual routing administration: audit rows, navigation, drafts and shared publication passed."
