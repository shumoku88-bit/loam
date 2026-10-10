import Loam.HouseholdCommand
import Loam.ActualDate

open Loam.Core

def main (args : List String) : IO Unit := do
  match args with
  | [root, "seed"] =>
      for i in List.range 30 do
        let context := if i == 0 then String.ofList (List.replicate 90 '界') ++ "-context-tail"
          else s!"MATTER-{i + 1} target"
        let due : AttentionDue String := if i % 3 == 0 then .dueOn "2026-11-20"
          else if i % 3 == 1 then .noDueDate else .dueUndetermined
        match ← Loam.HouseholdCommand.addAttention (System.FilePath.mk root) {context, due} with
        | .ok _ => pure ()
        | .error message => throw (IO.userError message)
  | [root, "close", id] =>
      let some today ← Loam.ActualDate.todayIso? | throw (IO.userError "fixture date unavailable")
      match ← Loam.HouseholdCommand.closeAttention (System.FilePath.mk root)
          {attention := ⟨id⟩, knownOn := today, kind := .resolved} with
      | .ok () => pure ()
      | .error message => throw (IO.userError message)
  | _ => throw (IO.userError "isolated fixture ROOT seed | ROOT close ID")
