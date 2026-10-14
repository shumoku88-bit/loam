import Loam.HouseholdCommand
import Loam.Authority.HouseholdAuthority
import Loam.Authority.ActualAuthority
import Loam.Application.ActualValidityFrontier

/-!
One-off #1969 research probe. This operates *only* on a caller-provided synthetic
temporary HouseholdImage. Timed operation uses existing production HouseholdCommand
writer; verification and stale-retry refusal happen strictly *outside* the timer.
Do not use on operational household data.
-/

open Loam.Core

private def need {α : Type} (result : Except String α) : IO α :=
  match result with
  | .ok value => pure value
  | .error message => throw (IO.userError message)

private def expect (p : Bool) (message : String) : IO Unit :=
  unless p do throw (IO.userError message)

private def effects (amount : Int) : List Effect :=
  [ Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount))
  , Effect.ofAnonymousQuantity ⟨"wifi"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]

private def record (root : System.FilePath) (validOn : String) : IO Unit := do
  let draft : Loam.MovementAdmission.Draft := {
    validOn := validOn
    description := some "synthetic horizon record"
    effects := effects 25
    relations := []
    discharges := []
    total := 25
  }
  let _ ← need (← Loam.HouseholdCommand.record root draft)

private def correct (root : System.FilePath) (target : EventId) : IO Unit := do
  let draft : Loam.CorrectionPublisher.Draft := {
    target := target
    effects := effects 2
    description := some "synthetic old-Event correction"
  }
  need (← Loam.HouseholdCommand.correctActual root draft)

private def reviseDate (root : System.FilePath) (target : EventId)
    (validOn : String) : IO Unit := do
  need (← Loam.HouseholdCommand.correctActualDate root {
    target := target, validOn := validOn
  })

private def verify (mode : String) (target : EventId) (validOn : String)
    (before after : Loam.HouseholdAuthority.Generation)
    (previous : String)
    (root : System.FilePath) : IO Unit := do
  expect (after.wire != before.wire) "accepted write did not change generation"
  expect (previous == before.wire) "previous generation differs from exact pre-write bytes"
  expect (Loam.HouseholdAuthority.preservesUntouched before.image after.image ["Actual"])
    "writing Actual changed another named Household section"
  let admitted ← need (← Loam.ActualAuthority.loadActual? root)
  let original := admitted.events.findById? target
  match mode with
  | "record" =>
      expect (admitted.events.events.length > 1) "recorded Event not retained"
      expect (admitted.events.events.any fun e =>
        e.id.token.startsWith "record-") "record publication did not append new Event"
  | "correct" =>
      expect original.isSome "original corrected Event disappeared"
      let some relation := admitted.corrections.corrections.find? (fun r => r.target == target)
        | throw (IO.userError "correction correspondence missing")
      expect ((admitted.events.findById? relation.replacement).isSome)
        "replacement Event not retained"
      expect (admitted.corrections.targetsEvent target)
        "original target still current after correction"
  | "date" =>
      expect original.isSome "date revision dropped original Event"
      let currentFacts := Loam.Application.actualValidityFrontierFacts admitted.validity
      expect (currentFacts.any fun fact =>
        fact.event == target && fact.validOn == validOn)
        "new date not visible on exact Event identity"
  | _ => throw (IO.userError "unknown mode")
  -- A writer holding exact old-generation bytes must refuse. The negative
  -- attempt must not modify the newly accepted generation.
  let stale ← Loam.HouseholdAuthority.publishObserved?
    root before.wire ["Actual"] before.image
  expect (!stale.isOk) "stale Household generation was accepted"
  let unchanged ← need (← Loam.HouseholdAuthority.loadCurrent? root)
  expect (unchanged.wire == after.wire) "stale writer changed accepted generation"

def main (args : List String) : IO Unit := do
  let [rootText, mode, targetToken, validOn] := args
    | throw (IO.userError "usage: ROOT record|correct|date TARGET_ID YYYY-MM-DD")
  let root := System.FilePath.mk rootText
  let target : EventId := ⟨targetToken⟩
  let before ← need (← Loam.HouseholdAuthority.loadCurrent? root)
  let start ← IO.monoNanosNow
  match mode with
  | "record" => record root validOn
  | "correct" => correct root target
  | "date" => reviseDate root target validOn
  | _ => throw (IO.userError "unknown write mode")
  let finish ← IO.monoNanosNow
  IO.println s!"HORIZON_WRITE mode={mode} publish_ms={(finish - start) / 1000000}"
  let after ← need (← Loam.HouseholdAuthority.loadCurrent? root)
  let previous ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath root)
  verify mode target validOn before after previous root
  IO.println s!"HORIZON_WRITE_VERIFIED mode={mode} bytes_before={before.wire.utf8ByteSize} bytes_after={after.wire.utf8ByteSize} prev_identical=true stale_refused=true"
