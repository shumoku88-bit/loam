import Loam.Tui.AccountingRoleAdministration

open Loam.Core
open Loam.Tui.Kernel

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

def main : IO Unit := do
  let initial := Loam.Tui.AccountingRoleAdministration.initial [⟨"first"⟩, ⟨"second"⟩]
  expect (Loam.Tui.AccountingRoleAdministration.draft? initial).isNone
    "initial state invented a default AccountingRole"

  let selectedSecond :=
    (Loam.Tui.AccountingRoleAdministration.update initial .down).state
  let choseExpense :=
    (Loam.Tui.AccountingRoleAdministration.update selectedSecond (.input '5')).state
  let some draft := Loam.Tui.AccountingRoleAdministration.draft? choseExpense
    | throw (IO.userError "explicit candidate and role did not form a draft")
  expect (draft.locus.token == "second" && draft.role == .expense)
    "explicit role selection produced the wrong draft"

  let previewStep := Loam.Tui.AccountingRoleAdministration.update choseExpense .enter
  expect (previewStep.state.phase == .preview && previewStep.publish.isNone)
    "first Enter did not enter non-publishing preview"
  let publishStep := Loam.Tui.AccountingRoleAdministration.update previewStep.state .enter
  let some publishDraft := publishStep.publish
    | throw (IO.userError "preview confirmation did not emit publication draft")
  expect (publishDraft == draft)
    "preview confirmation changed the selected role assignment"

  let noCandidates := Loam.Tui.AccountingRoleAdministration.initial []
  let refused := Loam.Tui.AccountingRoleAdministration.update noCandidates .enter
  expect (refused.state.phase == .choosing && refused.publish.isNone && !refused.state.notice.isEmpty)
    "empty candidate set entered preview or failed without explanation"

  let cancel := Loam.Tui.AccountingRoleAdministration.update initial .escape
  expect cancel.cancel "Esc did not cancel initial role administration"

  IO.println "AccountingRole TUI: explicit role choice, preview-before-publish, empty refusal and cancel passed."
