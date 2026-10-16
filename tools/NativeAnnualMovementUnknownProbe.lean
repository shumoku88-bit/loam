import Loam.Authority.AnnualSingleOwnerMovementSandbox

namespace Loam.Tools.NativeAnnualMovementUnknownProbe

open Loam.Core
open Loam.AnnualSingleOwnerSandbox
open Loam.AnnualSourceHeadSandbox

set_option autoImplicit false

private def expect (ok : Bool) (why : String) : IO Unit := do
  unless ok do throw (IO.userError why)

private def requireOk {α : Type} (x : Except String α) (label : String) :
    IO α := do
  match x with
  | .ok value => return value
  | .error reason => throw (IO.userError s!"{label}: {reason}")

private def expense (amount : Int) : Loam.MovementAdmission.Draft := {
  validOn := "2027-01-02"
  description := some "synthetic receipt unknown after HEAD directory sync"
  effects := [
    Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
    Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]
  relations := []
  discharges := []
  total := amount
}

private def run (ordinary annual : System.FilePath) : IO Unit := do
  let original ← IO.FS.readFile (Loam.HouseholdAuthority.path ordinary)
  let prev ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath ordinary)
  let earlierHead ← IO.FS.readFile (headPath annual)
  let pin ← requireOk (← open? annual earlierHead)
    "load original selected 2030 source before uncertainty injection"
  expect (pin.selected.head.years == ["2028", "2029", "2030"] &&
          !(← (annual / "journal" / "2030" / "4.full.loam").pathExists))
    "test expected a clean pinned Movement source after previous probe"

  let op : MovementOperationId := ⟨"unknown-movement-2030"⟩
  let (expectedEvent, candidate) ← requireOk
    (prepareMovement? pin op (expense 30))
    "reuse real qualified Movement admission to build fault candidate"
  -- This is intentionally an observation before attempting any publication.
  -- A visible prior HEAD does NOT mean it is safe to retry an uncertain write.
  match ← pin.observeMovement? "2030-01-04" op expectedEvent with
  | .priorHeadVisible => pure ()
  | _ => throw (IO.userError "prior HEAD was not classified read-only")
  expect (!(← (annual / "journal" / "2030" / "4.full.loam").pathExists))
    "read-only inspection installed an annual source"

  let normal := Loam.AnnualSandboxDurabilityBarriers.barriers annual
  let reached ← IO.mkRef false
  let injected : PublicationBarriers := {
    syncFile := normal.syncFile
    syncParents := fun path => do
      if path.toString == (headPath annual).toString then
        reached.set true
        throw (IO.userError "test-injected HEAD parent fullsync failure")
      normal.syncParents path
  }
  let outcome ← appendWithOutcome?
    annual pin.selected.headWire "2030-01-04"
    ("movement-" ++ op.token) ["Actual"] candidate injected
  expect (← reached.get)
    "post-rename HEAD directory barrier injection not reached"
  match outcome with
  | .outcomeUnknown name _ =>
      expect (name == "movement-" ++ op.token)
        "unknown source operation lost semantic Movement ID"
  | _ => throw (IO.userError
      "after-HEAD Movement must be result-unknown, not durable success")

  -- The full annual source may now be visible, but the barrier failed.
  -- Verify the native retained identity and event, not merely a HEAD name.
  match ← pin.observeMovement? "2030-01-04" op expectedEvent with
  | .requestedMovementVisible id =>
      expect (id == expectedEvent) "uncertain Movement identity changed"
  | _ => throw (IO.userError
      "unknown Movement could not be requalified as process-visible")
  let unknownEvent : EventId := ⟨"event-not-ours"⟩
  match ← pin.observeMovement? "2030-01-04" op unknownEvent with
  | .cannotClassify _ => pure ()
  | _ => throw (IO.userError "wrong expected Event ID was accepted")
  match ← pin.observeMovement? "2030-01-05" op expectedEvent with
  | .cannotClassify _ => pure ()
  | _ => throw (IO.userError "wrong admission day was accepted")
  match ← pin.observeMovement? "2030-01-04"
      ⟨"unrelated-operation"⟩ expectedEvent with
  | .cannotClassify _ => pure ()
  | _ => throw (IO.userError "unrelated operation was accepted")

  let currentWire ← IO.FS.readFile (headPath annual)
  let current ← requireOk (← open? annual currentWire)
    "qualified selected source after failed post-HEAD sync"
  let actual ← requireOk
    (Loam.ActualAuthority.decodeHouseholdGeneration? current.selected.generation)
    "decode actual native Movement idempotency map after failed HEAD sync"
  expect (actual.evidence.movementOperations.findEvent? op == some expectedEvent &&
          (actual.evidence.events.findById? expectedEvent).isSome &&
          current.selected.head.years == ["2028", "2029", "2030", "2030"])
    "post-HEAD actual/event mapping not selected and replayable"

  -- Neither an old session nor the newly reopened selected source may
  -- resend the uncertain same logical ID as a new Event.
  match ← pin.recordMovement? "2030-01-05" op (expense 30) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "old pin resent unknown Movement")
  match ← current.recordMovement? "2030-01-05" op (expense 30) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "new pin duplicated unknown Movement")
  expect (!(← (annual / "journal" / "2030" / "5.full.loam").pathExists))
    "unknown Movement retry introduced a duplicate annual generation"

  -- A valid but OLD HEAD is only process-visible and is NOT automatic proof
  -- of rollback safety. Reinsert under a disposable test root only.
  IO.FS.writeFile (headPath annual) earlierHead
  match ← pin.observeMovement? "2030-01-04" op expectedEvent with
  | .priorHeadVisible => pure ()
  | _ => throw (IO.userError "valid old selected HEAD did not classify as prior")
  IO.FS.writeFile (headPath annual) currentWire

  -- Corruption and mixed source owners must not be mistaken for a negative
  -- receipt or success; both are strictly unclassifiable.
  IO.FS.writeFile (headPath annual) "bad native annual head\n"
  match ← pin.observeMovement? "2030-01-04" op expectedEvent with
  | .cannotClassify _ => pure ()
  | _ => throw (IO.userError "corrupt HEAD was classified as a receipt")
  IO.FS.writeFile (headPath annual) currentWire
  IO.FS.writeFile (Loam.HouseholdAuthority.path annual) original
  match ← pin.observeMovement? "2030-01-04" op expectedEvent with
  | .cannotClassify _ => pure ()
  | _ => throw (IO.userError "competing household owner was silently accepted")
  IO.FS.removeFile (Loam.HouseholdAuthority.path annual)

  let restored ← requireOk (← open? annual currentWire)
    "clean selected source after refusal cases"
  let after ← requireOk
    (← restored.readHome? ordinary "2030-01-04")
    "ordinary Home from requalified post-unknown native generation"
  let some bankRow := after.view.currentBalances.exactRowFor?
      (⟨⟨"bank"⟩, ⟨"jpy"⟩⟩ : EffectCoordinate)
    | throw (IO.userError "exact bank missing after uncertain Movement")
  expect (bankRow.quantity.quanta == 7745 &&
          after.view.openScheduled.isEmpty &&
          (← IO.FS.readFile (Loam.HouseholdAuthority.path ordinary)) == original &&
          (← IO.FS.readFile
            (Loam.HouseholdAuthority.previousPath ordinary)) == prev)
    "reobserved uncertain Movement broke Home, balance, or dual-wrote old owner"
  IO.println "NATIVE_ANNUAL_MOVEMENT_UNKNOWN_PASS post-HEAD barrier failure remains uncertain; retained operation+Event replay visible; old/unrelated/mismatched/corrupt HEAD refused; no blind retry"

def main (args : List String) : IO Unit := do
  match args with
  | [ordinary, annual] =>
      run (System.FilePath.mk ordinary) (System.FilePath.mk annual)
  | _ => throw (IO.userError
      "usage: NativeAnnualMovementUnknownProbe SYNTHETIC_HOUSEHOLD ANNUAL_ROOT")

end Loam.Tools.NativeAnnualMovementUnknownProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualMovementUnknownProbe.main args
