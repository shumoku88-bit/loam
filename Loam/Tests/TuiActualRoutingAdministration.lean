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

private def typeText
    (state : Loam.Tui.ActualRoutingAdministration.State)
    (value : String) : Loam.Tui.ActualRoutingAdministration.State :=
  value.toList.foldl
    (fun current char =>
      (Loam.Tui.ActualRoutingAdministration.update current (.input char)).state)
    state

private def sample : Loam.ActualRoutingReview.Snapshot :=
  { observedAt := "2026-09-09"
    rows :=
      [ { locus := ⟨"coffee"⟩, role := .expense, status := .managed ⟨"food"⟩ }
      , { locus := ⟨"shipping"⟩, role := .expense, status := .unrouted }
      , { locus := ⟨"tobacco"⟩, role := .expense, status := .unmanaged }
      ]
    otherRows :=
      [ { locus := ⟨"yucho"⟩, role := .asset, status := .unrouted }
      , { locus := ⟨"all-country"⟩, role := .asset, status := .managed ⟨"investing"⟩ }
      , { locus := ⟨"pension"⟩, role := .income, status := .unrouted }
      ]
    purposes := [⟨"food"⟩, ⟨"general"⟩, ⟨"savings"⟩, ⟨"investing"⟩]
    unresolvedRoleLoci := [⟨"mystery"⟩]
    historicalOnlyRouteLoci := [⟨"old-expense"⟩] }


def main (args : List String) : IO Unit := do
  let bounds : Bounds := { width := 100, height := 28 }
  let s0 := Loam.Tui.ActualRoutingAdministration.initial sample
  expect (s0.scope == .expense) "initial scope"
  expect (s0.phase == .selectLocus) "initial phase"
  expect (s0.locusIndex == 0) "initial locus index"
  expect (s0.effectiveOn == .dated "2026-09-09") "initial effective coordinate"

  let v0 := text (Loam.Tui.ActualRoutingAdministration.view bounds s0)
  expect (contains "Purpose Administration / Actual Routing" v0) "title visible"
  expect (contains "coffee" v0 && contains "managed food" v0) "managed row visible"
  expect (contains "shipping" v0 && contains "UNROUTED" v0) "unrouted row visible"
  expect (contains "unrouted: 1" v0) "default Expense unrouted count visible"
  expect (contains "Other admitted loci" v0) "optional entrance help visible"
  expect (contains "Unresolved AccountingRole: 1" v0) "role audit visible"
  expect (contains "historical-only routes: 1" v0) "historical route audit visible"

  -- Existing Expense route workflow stays the default and uses observedAt when
  -- the effective-coordinate editor is submitted blank.
  let down := Loam.Tui.ActualRoutingAdministration.update s0 (.input 'j')
  expect (down.state.locusIndex == 1) "select shipping"
  let target := Loam.Tui.ActualRoutingAdministration.update down.state .enter
  expect (target.state.phase == .selectTarget) "enter route type"
  let purpose := Loam.Tui.ActualRoutingAdministration.update target.state .enter
  expect (purpose.state.phase == .selectPurpose) "managed opens Purpose picker"
  let purposeDown := Loam.Tui.ActualRoutingAdministration.update purpose.state .down
  expect (purposeDown.state.purposeIndex == 1) "select general"
  let effective := Loam.Tui.ActualRoutingAdministration.update purposeDown.state .enter
  expect (effective.state.phase == .editEffective "") "Purpose continues to effective coordinate"
  let preview := Loam.Tui.ActualRoutingAdministration.update effective.state .enter
  expect (preview.state.phase == .preview) "blank effective editor uses observed date"
  let draft ← requireSome (Loam.Tui.ActualRoutingAdministration.draft? preview.state) "managed draft"
  expect (draft.locus.token == "shipping") "draft locus"
  expect (draft.effectiveOn == .dated "2026-09-09") "default draft date"
  expect (draft.target == .managed ⟨"general"⟩) "draft target"
  let publish := Loam.Tui.ActualRoutingAdministration.update preview.state .enter
  expect (publish.publish == some draft) "preview emits draft"

  -- Other admitted Loci are reachable only through an explicit scope toggle.
  -- Their unrouted state is shown as status, not added to the Expense warning.
  let other := Loam.Tui.ActualRoutingAdministration.update s0 (.input 'a')
  expect (other.state.scope == .other && other.state.locusIndex == 0)
    "optional scope toggle"
  let otherView := text (Loam.Tui.ActualRoutingAdministration.view bounds other.state)
  expect (contains "Other admitted loci: 3" otherView) "optional summary visible"
  expect (contains "yucho" otherView && contains "Asset" otherView)
    "optional Asset row visible with role"
  expect (contains "optional routing only" otherView)
    "optional rows are not presented as obligations"

  let optionalTarget := Loam.Tui.ActualRoutingAdministration.update other.state .enter
  expect (optionalTarget.state.phase == .selectTarget) "optional Asset enters route type"
  let optionalPurpose := Loam.Tui.ActualRoutingAdministration.update optionalTarget.state .enter
  let optionalPurpose1 := Loam.Tui.ActualRoutingAdministration.update optionalPurpose.state .down
  let optionalPurpose2 := Loam.Tui.ActualRoutingAdministration.update optionalPurpose1.state .down
  expect (optionalPurpose2.state.purposeIndex == 2) "select savings Purpose"
  let optionalEffective := Loam.Tui.ActualRoutingAdministration.update optionalPurpose2.state .enter
  expect (optionalEffective.state.phase == .editEffective "")
    "optional route requires explicit effective-coordinate step"

  let datedState := typeText optionalEffective.state "2026-08-17"
  let datedPreview := Loam.Tui.ActualRoutingAdministration.update datedState .enter
  expect (datedPreview.state.phase == .preview) "dated optional route previews"
  let savingsDraft ← requireSome
    (Loam.Tui.ActualRoutingAdministration.draft? datedPreview.state) "savings draft"
  expect (savingsDraft.locus.token == "yucho") "optional draft locus"
  expect (savingsDraft.effectiveOn == .dated "2026-08-17")
    "explicit historical effective date retained"
  expect (savingsDraft.target == .managed ⟨"savings"⟩)
    "optional Asset routed to savings Purpose"

  let initialPreview :=
    Loam.Tui.ActualRoutingAdministration.update optionalEffective.state (.input 'i')
  expect (initialPreview.state.phase == .preview) "initial shortcut previews"
  let initialDraft ← requireSome
    (Loam.Tui.ActualRoutingAdministration.draft? initialPreview.state) "initial savings draft"
  expect (initialDraft.effectiveOn == .initial)
    "initial routing coordinate retained explicitly"

  -- Unmanaged still skips the Purpose picker but now passes through the same
  -- explicit effective-coordinate step.
  let unmanagedState := { target.state with targetChoice := .unmanaged }
  let unmanagedEffective := Loam.Tui.ActualRoutingAdministration.update unmanagedState .enter
  expect (unmanagedEffective.state.phase == .editEffective "")
    "unmanaged route opens effective-coordinate editor"
  let unmanagedPreview := Loam.Tui.ActualRoutingAdministration.update unmanagedEffective.state .enter
  expect (unmanagedPreview.state.phase == .preview) "unmanaged date continues to preview"
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
    let .ok () := result | throw (IO.userError "Actual routing publish failed")

    let history ← requireSome (← loadActualRoutingHistory? routing) "reload Actual routing"
    expect (history.entries.length == 2) "history appended"
    expect (history.statusAt ⟨"coffee"⟩ (.dated "2026-09-09") == .managed ⟨"food"⟩)
      "initial route preserved"
    expect (history.statusAt ⟨"shipping"⟩ (.dated "2026-09-09") == .managed ⟨"general"⟩)
      "dated route visible"

    let duplicate ← Loam.ActualRoutingPublisher.publish routing.toString draft
    expect (!duplicate.isOk) "duplicate locus/date rejected"

    let optionalResult ← Loam.ActualRoutingPublisher.publish routing.toString savingsDraft
    let .ok () := optionalResult | throw (IO.userError "optional Asset routing publish failed")
    let optionalHistory ← requireSome (← loadActualRoutingHistory? routing)
      "reload optional Actual routing"
    expect
      (optionalHistory.statusAt ⟨"yucho"⟩ (.dated "2026-08-18") == .managed ⟨"savings"⟩)
      "explicitly dated optional Asset route visible at later Event coordinate"

  IO.println "TUI Actual routing administration: default Expense rows, optional admitted Loci, effective coordinates and shared publication passed."
