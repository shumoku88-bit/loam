import Loam.CurrentCoverageReview
import Loam.ScheduledRoutingPublisher
import Loam.Tui.ScheduledRouting
import Loam.Tui.ScheduledRoutingSession
import Loam.Tui.Kernel

open Loam.Core
open Loam.Application
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

private def sampleCoverage : Loam.CurrentCoverageReview.Snapshot :=
  { currentWindowStart := "2026-08-14"
    observedAt := "2026-09-08"
    endExclusive := "2026-10-15"
    rows :=
      [ { purpose := ⟨"food"⟩
          entitlement := Quantity.ofQuanta 30000
          consumption := Quantity.ofQuanta 10000
          remaining := Quantity.ofQuanta 20000
          commitment := Quantity.ofQuanta 0
          headroom := Quantity.ofQuanta 20000 }
      , { purpose := ⟨"fixed-cost"⟩
          entitlement := Quantity.ofQuanta 15000
          consumption := Quantity.ofQuanta 5000
          remaining := Quantity.ofQuanta 10000
          commitment := Quantity.ofQuanta 0
          headroom := Quantity.ofQuanta 10000 }
      ]
    scheduledFrontier := some
      { unmanaged := Quantity.ofQuanta 0
        unrouted := Quantity.ofQuanta 0
        unresolvedEligibility := Quantity.ofQuanta 4810 }
    unresolvedScheduled :=
      [ { subject := { scheduled := ⟨"scheduled-1"⟩, locus := ⟨"wifi"⟩ }
          scheduledOn := "2026-10-08"
          measure := ⟨"jpy"⟩
          quantity := Quantity.ofQuanta 4810 }
      , { subject := { scheduled := ⟨"scheduled-2"⟩, locus := ⟨"gas"⟩ }
          scheduledOn := "2026-09-25"
          measure := ⟨"jpy"⟩
          quantity := Quantity.ofQuanta 3000 }
      ]
  }

def main (args : List String) : IO Unit := do
  let bounds : Bounds := { width := 100, height := 30 }

  -- 1. Initial state inspection
  let s0 := Loam.Tui.ScheduledRouting.initial sampleCoverage "2026-09-08"
  expect (s0.phase == .selectSubject) "initial phase must be selectSubject"
  expect (s0.subjectIndex == 0) "initial subjectIndex must be 0"
  expect (s0.effectiveOn == "2026-09-08") "effectiveOn must preserve observedAt"
  expect ((Loam.Tui.ScheduledRouting.unresolvedRows s0).length == 2) "unresolved rows count"
  expect ((Loam.Tui.ScheduledRouting.availablePurposes s0).length == 2) "available purposes count"

  -- 2. View of selectSubject
  let v0 := text (Loam.Tui.ScheduledRouting.view bounds s0)
  expect (contains "Scheduled Routing / Select Subject" v0) "view title"
  expect (contains "scheduled-1" v0 && contains "wifi" v0 && contains "4810 jpy" v0) "row 0 visible"
  expect (contains "scheduled-2" v0 && contains "gas" v0 && contains "3000 jpy" v0) "row 1 visible"

  -- 3. Cursor movement in selectSubject
  let stepDown := Loam.Tui.ScheduledRouting.update bounds s0 (.input 'j')
  expect (stepDown.state.subjectIndex == 1) "down moved cursor to 1"
  let stepDown2 := Loam.Tui.ScheduledRouting.update bounds stepDown.state .down
  expect (stepDown2.state.subjectIndex == 1) "down clamped at length - 1"
  let stepUp := Loam.Tui.ScheduledRouting.update bounds stepDown2.state (.input 'k')
  expect (stepUp.state.subjectIndex == 0) "up moved cursor to 0"
  let stepUp2 := Loam.Tui.ScheduledRouting.update bounds stepUp.state .up
  expect (stepUp2.state.subjectIndex == 0) "up clamped at 0"

  -- 4. Cancel from selectSubject
  let cancelB := Loam.Tui.ScheduledRouting.update bounds s0 (.input 'b')
  expect cancelB.cancel "b cancels selectSubject"
  let cancelEsc := Loam.Tui.ScheduledRouting.update bounds s0 .escape
  expect cancelEsc.cancel "Esc cancels selectSubject"
  let cancelQ := Loam.Tui.ScheduledRouting.update bounds s0 (.input 'q')
  expect cancelQ.cancel "q cancels selectSubject"

  -- 5. Advance from selectSubject to selectTarget
  let stepEnter := Loam.Tui.ScheduledRouting.update bounds s0 .enter
  expect (!stepEnter.cancel && stepEnter.publish.isNone) "enter did not cancel or publish"
  let sTarget := stepEnter.state
  expect (sTarget.phase == .selectTarget) "advanced to selectTarget"
  expect (sTarget.targetChoice == .managed) "default target is managed"

  -- 6. Toggle target choice
  let vTarget := text (Loam.Tui.ScheduledRouting.view bounds sTarget)
  expect (contains "Scheduled Routing / Select Route Type" vTarget) "target view title"
  expect (contains "Subject: scheduled-1 / wifi" vTarget) "target subject shown"
  let stepToggle := Loam.Tui.ScheduledRouting.update bounds sTarget .down
  expect (stepToggle.state.targetChoice == .unmanaged) "down toggled to unmanaged"
  let stepToggle2 := Loam.Tui.ScheduledRouting.update bounds stepToggle.state .tab
  expect (stepToggle2.state.targetChoice == .managed) "tab toggled back to managed"

  -- 7. Back from selectTarget to selectSubject
  let stepBack := Loam.Tui.ScheduledRouting.update bounds sTarget (.input 'b')
  expect (stepBack.state.phase == .selectSubject) "b returns to selectSubject"

  -- 8. Select unmanaged -> enters preview directly
  let sUnmanaged := { sTarget with targetChoice := .unmanaged }
  let stepUnmanagedEnter := Loam.Tui.ScheduledRouting.update bounds sUnmanaged .enter
  expect (stepUnmanagedEnter.state.phase == .preview) "unmanaged enters preview"
  let vUnmanagedPreview := text (Loam.Tui.ScheduledRouting.view bounds stepUnmanagedEnter.state)
  expect (contains "Scheduled Routing / Preview" vUnmanagedPreview) "preview title"
  expect (contains "Route Target:   unmanaged" vUnmanagedPreview) "unmanaged target displayed"
  expect (contains "Effective On:   2026-09-08" vUnmanagedPreview) "effectiveOn displayed"

  -- 9. In preview for unmanaged: check draft and Enter publish
  let draftUnmanaged ← requireSome (Loam.Tui.ScheduledRouting.draft? stepUnmanagedEnter.state) "draft unmanaged"
  expect (draftUnmanaged.subject.scheduled.token == "scheduled-1") "draft scheduled"
  expect (draftUnmanaged.subject.locus.token == "wifi") "draft locus"
  expect (draftUnmanaged.effectiveOn == "2026-09-08") "draft effectiveOn == observedAt"
  expect (draftUnmanaged.target == .unmanaged) "draft target == unmanaged"

  let stepPubUnmanaged := Loam.Tui.ScheduledRouting.update bounds stepUnmanagedEnter.state .enter
  expect (stepPubUnmanaged.publish == some draftUnmanaged) "publish emitted unmanaged draft"

  -- 10. Select managed -> enters selectPurpose
  let stepManagedEnter := Loam.Tui.ScheduledRouting.update bounds sTarget .enter
  expect (stepManagedEnter.state.phase == .selectPurpose) "managed enters selectPurpose"
  let sPurpose := stepManagedEnter.state
  let vPurpose := text (Loam.Tui.ScheduledRouting.view bounds sPurpose)
  expect (contains "Scheduled Routing / Select Purpose" vPurpose) "purpose view title"
  expect (contains "food" vPurpose && contains "fixed-cost" vPurpose) "purposes listed"

  -- 11. Cursor movement in selectPurpose
  let stepPurpDown := Loam.Tui.ScheduledRouting.update bounds sPurpose (.input 'j')
  expect (stepPurpDown.state.purposeIndex == 1) "purpose down to 1"
  let stepPurpUp := Loam.Tui.ScheduledRouting.update bounds stepPurpDown.state (.input 'k')
  expect (stepPurpUp.state.purposeIndex == 0) "purpose up to 0"

  -- 12. Back from selectPurpose to selectTarget
  let stepPurpBack := Loam.Tui.ScheduledRouting.update bounds sPurpose .escape
  expect (stepPurpBack.state.phase == .selectTarget) "Esc returns to selectTarget"

  -- 13. Select purpose index 1 (fixed-cost) -> enters preview
  let stepPurp1 := { sPurpose with purposeIndex := 1 }
  let stepPurpEnter := Loam.Tui.ScheduledRouting.update bounds stepPurp1 .enter
  expect (stepPurpEnter.state.phase == .preview) "purpose selection enters preview"
  let sManagedPreview := stepPurpEnter.state
  let vManagedPreview := text (Loam.Tui.ScheduledRouting.view bounds sManagedPreview)
  expect (contains "Scheduled Routing / Preview" vManagedPreview) "preview title"
  expect (contains "Route Target:   managed fixed-cost" vManagedPreview) "managed fixed-cost displayed"
  expect (contains "Effective On:   2026-09-08" vManagedPreview) "effectiveOn displayed"
  expect (contains "Scheduled On:   2026-10-08" vManagedPreview) "scheduledOn distinct from effectiveOn"

  -- 14. In preview for managed: check draft
  let draftManaged ← requireSome (Loam.Tui.ScheduledRouting.draft? sManagedPreview) "draft managed"
  expect (draftManaged.subject.scheduled.token == "scheduled-1") "draft scheduled"
  expect (draftManaged.subject.locus.token == "wifi") "draft locus"
  expect (draftManaged.effectiveOn == "2026-09-08") "draft effectiveOn is observedAt, not scheduledOn"
  expect (draftManaged.effectiveOn != "2026-10-08") "draft effectiveOn never scheduledOn"
  expect (draftManaged.target == .managed ⟨"fixed-cost"⟩) "draft target managed fixed-cost"

  -- 15. Edit key 'e' in preview returns to selectTarget
  let stepEdit := Loam.Tui.ScheduledRouting.update bounds sManagedPreview (.input 'e')
  expect (stepEdit.state.phase == .selectTarget) "e in preview returns to selectTarget"

  -- 16. Esc in preview returns to selectPurpose (when managed)
  let stepPrevEsc := Loam.Tui.ScheduledRouting.update bounds sManagedPreview .escape
  expect (stepPrevEsc.state.phase == .selectPurpose) "Esc in preview returns to selectPurpose"

  -- 17. Esc in preview returns to selectTarget (when unmanaged)
  let stepUnmanEsc := Loam.Tui.ScheduledRouting.update bounds stepUnmanagedEnter.state .escape
  expect (stepUnmanEsc.state.phase == .selectTarget) "Esc in preview returns to selectTarget for unmanaged"

  -- 18. Enter in preview publishes draft
  let stepPubManaged := Loam.Tui.ScheduledRouting.update bounds sManagedPreview .enter
  expect (stepPubManaged.publish == some draftManaged) "publish emitted managed draft"

  -- 19. Empty unresolvedScheduled behaves fail-closed
  let emptyCoverage := { sampleCoverage with unresolvedScheduled := [] }
  let sEmpty := Loam.Tui.ScheduledRouting.initial emptyCoverage "2026-09-08"
  let stepEmptyEnter := Loam.Tui.ScheduledRouting.update bounds sEmpty .enter
  expect (stepEmptyEnter.state.phase == .selectSubject) "empty unresolved stays in selectSubject"
  expect (contains "No unresolved Scheduled routing subjects" stepEmptyEnter.state.notice) "notice set"

  -- 20. End-to-end publisher integration with isolated test directory
  if args.length >= 1 then
    let root := System.FilePath.mk args.head!
    IO.FS.createDirAll root
    let scheduledPath := root / "scheduled.loam"
    let routingPath := root / "scheduled-routing.loam"

    IO.FS.writeFile scheduledPath
      ("LOAM-SCHEDULED-LIFECYCLE\t1\n" ++
       "BEGIN\tScheduled\n" ++
       "LOAM-SCHEDULED-MEMORY\t1\n" ++
       "SCHEDULED\tscheduled-1\t2026-10-08\tjpy\n" ++
       "CHANGE\tpaypay\t-4810\n" ++
       "CHANGE\twifi\t4810\n" ++
       "END\tScheduled\n" ++
       "BEGIN\tCompletion\nLOAM-SCHEDULED-COMPLETION-MEMORY\t1\nEND\tCompletion\n" ++
       "BEGIN\tRetirement\nLOAM-SCHEDULED-RETIREMENT-MEMORY\t1\nEND\tRetirement\n" ++
       "BEGIN\tReplacement\nLOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\nEND\tReplacement\n")
    IO.FS.writeFile routingPath "LOAM-SCHEDULED-ROUTING\t1\n"

    -- Publish through shared ScheduledRoutingPublisher
    let res ← Loam.ScheduledRoutingPublisher.publish routingPath.toString scheduledPath.toString draftManaged
    let .ok receipt := res | throw (IO.userError "publication failed")
    expect (receipt.subject.scheduled.token == "scheduled-1") "published receipt scheduled"
    expect (receipt.subject.locus.token == "wifi") "published receipt locus"
    expect (receipt.effectiveOn == "2026-09-08") "published receipt effectiveOn"
    expect (receipt.target == .managed ⟨"fixed-cost"⟩) "published receipt target"

    -- Re-read from disk verifies persistence
    let some history ← Loam.Persistence.loadScheduledRoutingHistory? routingPath
      | throw (IO.userError "re-reading routing history failed")
    expect (history.entries.length == 1) "1 entry in history"
    let some entry := history.entries.head? | throw (IO.userError "missing entry")
    expect (entry.subject.scheduled.token == "scheduled-1") "persisted subject scheduled"
    expect (entry.subject.locus.token == "wifi") "persisted subject locus"
    expect (entry.effectiveOn == "2026-09-08") "persisted effectiveOn"
    expect (entry.purpose == some ⟨"fixed-cost"⟩) "persisted purpose"

    -- Duplicate rejected fail-closed
    let dupRes ← Loam.ScheduledRoutingPublisher.publish routingPath.toString scheduledPath.toString draftManaged
    expect (!dupRes.isOk) "duplicate publication was rejected"

  IO.println "TUI Scheduled Routing: navigation, target selection, purpose cursor, preview, drafts, effective date invariants and publication passed."
