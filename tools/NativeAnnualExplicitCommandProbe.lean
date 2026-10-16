import Loam.Authority.AnnualExplicitCommandSandbox
import Loam.Review.AnnualSourceReadView

namespace Loam.Tools.NativeAnnualExplicitCommandProbe

open Loam.Core
open Loam.AnnualExplicitCommandSandbox

set_option autoImplicit false

private def expect (yes : Bool) (why : String) : IO Unit := do
  unless yes do throw (IO.userError why)

private def requireOk {α : Type} (x : Except String α)
    (why : String) : IO α := do
  match x with
  | .ok value => return value
  | .error reason => throw (IO.userError s!"{why}: {reason}")

private def expense (amount : Int) : Loam.MovementAdmission.Draft := {
  validOn := "2027-01-04"
  description := some "synthetic explicit source routing"
  effects := [
    Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
    Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
  ]
  relations := []
  discharges := []
  total := amount
}

private def quantity (generation : Loam.HouseholdAuthority.Generation) :
    IO Int := do
  let view ← requireOk
    (Loam.AnnualSourceReadView.fromGeneration? generation)
    "qualified source balance"
  let some row := view.currentBalances.exactRowFor?
    (⟨⟨"bank"⟩, ⟨"jpy"⟩⟩ : EffectCoordinate)
    | throw (IO.userError "exact bank evidence missing")
  expect (!(Loam.CurrentBalanceReview.selectExact
    view.currentBalances [(⟨⟨"cash"⟩, ⟨"jpy"⟩⟩ : EffectCoordinate)]).isOk)
    "unknown cash incorrectly reported as exact zero"
  return row.quantity.quanta

private def run
    (source legacy annual : System.FilePath) : IO Unit := do
  let sourceFile := Loam.HouseholdAuthority.path source
  let sourcePrevious := Loam.HouseholdAuthority.previousPath source
  let sourceBytes ← IO.FS.readFile sourceFile
  let sourcePreviousBytes ← IO.FS.readFile sourcePrevious
  let legacyFile := Loam.HouseholdAuthority.path legacy
  let legacyBefore ← IO.FS.readFile legacyFile
  let annualHead := Loam.AnnualSourceHeadSandbox.headPath annual
  let annualBefore ← IO.FS.readFile annualHead
  let annualSnapshot ← requireOk
    (← Loam.AnnualSingleOwnerSandbox.open? annual annualBefore)
    "capture annual source before ordinary route"
  expect (annualSnapshot.selected.head.years == ["2028", "2029", "2030", "2030"] &&
          (← quantity annualSnapshot.selected.generation) == 7745)
    "expected qualified previous synthetic Movement uncertain state"
  Loam.AnnualSandboxDurabilityBarriers.markDisposableRoot legacy

  let legacyOp : MovementOperationId := ⟨"chosen-ordinary-movement"⟩
  let first ← recordIdempotent? (.ordinary legacy)
    "2030-01-05" legacyOp (expense 60)
  let applied ← match first with
    | .ordinary (.ok (.applied event)) => pure event
    | _ => throw (IO.userError
        "explicit ordinary target did not run normal HouseholdCommand")
  let legacyCurrent ← IO.FS.readFile legacyFile
  let legacyGeneration ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? legacy)
    "installed ordinary source after chosen ordinary command"
  expect (legacyCurrent != legacyBefore &&
          (← quantity legacyGeneration) == 7790 &&
          (← IO.FS.readFile annualHead) == annualBefore)
    "ordinary branch changed the annual HEAD or used wrong source"

  let repeated ← recordIdempotent? (.ordinary legacy)
    "2030-01-06" legacyOp (expense 999)
  match repeated with
  | .ordinary (.ok (.alreadyApplied event)) =>
      expect (event == applied) "ordinary idempotent replay changed Event ID"
  | _ => throw (IO.userError
      "ordinary idempotent retry was not preserved by explicit route")
  expect ((← IO.FS.readFile legacyFile) == legacyCurrent)
    "ordinary idempotent replay published again"

  -- Invalid legacy drafts keep the ORIGINAL legacy error contract; never
  -- misclassify an unknown legacy IO outcome as a pre-HEAD refusal.
  let invalid : MovementOperationId := ⟨"invalid-ordinary-expense"⟩
  match ← recordIdempotent? (.ordinary legacy)
      "2030-01-06" invalid (expense 0) with
  | .ordinary (.error _) => pure ()
  | _ => throw (IO.userError "ordinary error was translated into wrong outcome")

  let annualOp : MovementOperationId := ⟨"chosen-annual-movement"⟩
  let annualResult ← recordIdempotent?
    (.annual annual annualBefore) "2030-01-05" annualOp (expense 55)
  let (event, committed) ← match annualResult with
    | .annual (.committed event selected) => pure (event, selected)
    | .annual (.outcomeUnknown _ _ why) =>
        throw (IO.userError s!"annual operation returned uncertain: {why}")
    | _ => throw (IO.userError
        "explicit annual target did not commit through pinned HEAD")
  let selected ← requireOk
    (← Loam.AnnualSingleOwnerSandbox.open? annual committed.headWire)
    "reopen one selected annual root after routed command"
  expect (committed.head.years == ["2028", "2029", "2030", "2030", "2030"] &&
          committed.operations.getLast? == some "movement-chosen-annual-movement" &&
          (← (annual / "journal" / "2030" / "5.full.loam").pathExists) &&
          (← quantity selected.selected.generation) == 7690)
    "annual branch did not select expected 2030 Movement generation"
  let actual ← requireOk
    (Loam.ActualAuthority.decodeHouseholdGeneration? selected.selected.generation)
    "decode routed annual Movement mapping"
  expect (actual.evidence.movementOperations.findEvent? annualOp == some event &&
          (← IO.FS.readFile legacyFile) == legacyCurrent)
    "annual route modified ordinary root or lost operation identity"

  -- A stale explicit annual pin never turns into a legacy command or retries
  -- as an update to a newer annual HEAD.
  match ← recordIdempotent? (.annual annual annualBefore)
      "2030-01-06" ⟨"stale-explicit-route"⟩ (expense 20) with
  | .refusedSelection _ => pure ()
  | _ => throw (IO.userError "stale selected HEAD was auto-upgraded")
  expect ((← IO.FS.readFile annualHead) == committed.headWire &&
          !(← (annual / "journal" / "2030" / "6.full.loam").pathExists))
    "rejected source choice created an immutable annual object"

  -- No silent fallback between physical owner kinds.
  match ← recordIdempotent? (.ordinary annual)
      "2030-01-06" ⟨"legacy-against-head"⟩ (expense 10) with
  | .refusedSelection _ => pure ()
  | _ => throw (IO.userError "ordinary branch accepted native HEAD"))
  match ← recordIdempotent? (.annual legacy committed.headWire)
      "2030-01-06" ⟨"annual-against-household"⟩ (expense 10) with
  | .refusedSelection _ => pure ()
  | _ => throw (IO.userError "annual branch accepted ordinary household"))
  match ← recordIdempotent? (.ordinary source)
      "2030-01-06" ⟨"unmarked-ordinary"⟩ (expense 10) with
  | .refusedSelection _ => pure ()
  | _ => throw (IO.userError "unmarked original source allowed as writable test"))
  IO.FS.writeFile (Loam.AnnualSourceHeadSandbox.headPath legacy)
    committed.headWire
  match ← recordIdempotent? (.ordinary legacy)
      "2030-01-06" ⟨"mixed-owner-request"⟩ (expense 10) with
  | .refusedSelection _ => pure ()
  | _ => throw (IO.userError "mixed ordinary+annual physical owner admitted"))
  IO.FS.removeFile (Loam.AnnualSourceHeadSandbox.headPath legacy)

  -- Source roots are not aliases for a command: an explicitly selected
  -- target only ever writes the requested canonical owner.
  expect ((← IO.FS.readFile sourceFile) == sourceBytes &&
          (← IO.FS.readFile sourcePrevious) == sourcePreviousBytes &&
          (← IO.FS.readFile legacyFile) == legacyCurrent &&
          (← IO.FS.readFile annualHead) == committed.headWire)
    "cross-owner dual write or silent fallback altered another source"
  IO.println "NATIVE_ANNUAL_EXPLICIT_ROUTE_PASS explicit legacy+annual Movement owner, legacy idempotency, annual CAS, stale/mixed/unmarked refusal, never dual-write"

def main (args : List String) : IO Unit := do
  match args with
  | [source, legacy, annual] =>
      run (System.FilePath.mk source)
        (System.FilePath.mk legacy) (System.FilePath.mk annual)
  | _ => throw (IO.userError
      "usage: NativeAnnualExplicitCommandProbe SOURCE_SYNTHETIC LEGACY_SYNTHETIC ANNUAL_SYNTHETIC")

end Loam.Tools.NativeAnnualExplicitCommandProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualExplicitCommandProbe.main args
