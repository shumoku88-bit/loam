import Loam.Authority.AnnualSingleOwnerMovementSandbox
import Loam.Review.AnnualSourceQueryPolicy

namespace Loam.Tools.NativeAnnualSingleOwnerMovementProbe

open Loam.Core
open Loam.AnnualSingleOwnerSandbox
open Loam.AnnualSourceHeadSandbox

set_option autoImplicit false

private def expect (ok : Bool) (why : String) : IO Unit := do
  unless ok do throw (IO.userError why)

private def requireOk {α : Type} (value : Except String α)
    (why : String) : IO α := do
  match value with
  | .ok answer => return answer
  | .error reason => throw (IO.userError s!"{why}: {reason}")

private def draft
    (source : String) (withdrawn : Int) : Loam.MovementAdmission.Draft := {
  validOn := "2028-12-31"  -- intentionally different from 2030 publication day
  description := some "synthetic annual practical Movement"
  effects := [
    Effect.ofAnonymousQuantity ⟨source⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-withdrawn)),
    Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta withdrawn)
  ]
  relations := []
  discharges := []
  total := withdrawn
}

private def run (ordinary annual : System.FilePath) : IO Unit := do
  let ordinarySource := Loam.HouseholdAuthority.path ordinary
  let ordinaryPrevious := Loam.HouseholdAuthority.previousPath ordinary
  let unchanged ← IO.FS.readFile ordinarySource
  let previous ← IO.FS.readFile ordinaryPrevious
  let configPool ← IO.FS.readFile (ordinary / "config" / "daily-pace.tsv")
  let configCycle ← IO.FS.readFile (ordinary / "config" / "boundary-presets.tsv")
  let startingHead ← IO.FS.readFile (headPath annual)
  let prior ← requireOk (← open? annual startingHead)
    "pin selected annual root before Movement"
  expect (prior.selected.head.years == ["2028", "2029"] &&
          !(← (annual / "journal" / "2030").pathExists))
    "unexpected 2030 source before first Movement admission"
  let priorHome ← requireOk
    (← prior.readHome? ordinary "2030-01-01")
    "Home before synthetic 2030 Movement"
  let count := priorHome.home.actual.allRecords.length
  expect (count == 4 && priorHome.view.openScheduled.isEmpty)
    "initial Actual or Scheduled frontier differs from Jan1 fixture"

  -- A valid date label or a failed draft cannot create a 2030 file.
  let zero : MovementOperationId := ⟨"bad-unbalanced"⟩
  match ← prior.recordMovement? "2030-01-01" zero (draft "bank" 0) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "empty/unbalanced Movement not refused")
  let unknown : MovementOperationId := ⟨"unknown-locus"⟩
  match ← prior.recordMovement? "2030-01-01" unknown (draft "not-admitted" 75) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "unapproved Locus admitted for annual Movement")
  let nonDate : MovementOperationId := ⟨"invalid-admission-day"⟩
  match ← prior.recordMovement? "2030-02-30" nonDate (draft "bank" 75) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "invalid journal admission day not refused")
  expect ((← IO.FS.readFile (headPath annual)) == startingHead &&
          !(← (annual / "journal" / "2030").pathExists))
    "invalid semantic operation created physical journal or changed HEAD"

  -- Native MovementAdmission allocates Event, applies approved vocabulary,
  -- and updates the same Actual event/validity/operation evidence families
  -- that the ordinary HouseholdCommand writer uses.
  let movement : MovementOperationId := ⟨"annual-2030-expense"⟩
  let published ← prior.recordMovement? "2030-01-01" movement (draft "bank" 75)
  let (eventId, latest) ← match published with
  | .committed event selected => pure (event, selected)
  | .refusedBeforeHead reason =>
      throw (IO.userError s!"valid practical Movement refused: {reason}")
  | .outcomeUnknown _ reason =>
      throw (IO.userError s!"native annual Movement was not durably acknowledged: {reason}")
  expect (latest.head.years == ["2028", "2029", "2030"] &&
          latest.operations.getLast? == some "movement-annual-2030-expense" &&
          (← (annual / "journal" / "2030" / "3.full.loam").pathExists))
    "first 2030 Movement failed same-HEAD native annual publication"

  -- The same pre-write pin cannot produce stale reads or a second fork.
  expect (!(← prior.readHome? ordinary "2030-01-01").isOk &&
          !(← open? annual startingHead).isOk)
    "stale read silently advanced to newly published annual HEAD"
  let stale : MovementOperationId := ⟨"stale-different-expense"⟩
  match ← prior.recordMovement? "2030-01-02" stale (draft "bank" 125) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "stale concurrent annual Movement not refused")
  expect (!(← (annual / "journal" / "2030" / "4.full.loam").pathExists))
    "stale annual Movement fabricated an unselected object"

  let selected ← requireOk (← open? annual latest.headWire)
    "reopen selected HEAD after real Movement"
  let after ← requireOk
    (← selected.readHome? ordinary "2030-01-01")
    "read Home after admitted native Movement"
  expect (after.home.actual.allRecords.length == count + 1 &&
          ((after.home.actual.allRecords.map fun row => row.event.id.token).contains
            eventId.token) &&
          after.view.openScheduled.isEmpty &&
          after.view.generation.wire == latest.generation.wire)
    "new annual Event not visible to ordinary Home read composer"

  let actual ← requireOk
    (Loam.ActualAuthority.decodeHouseholdGeneration? latest.generation)
    "decode selected Movement evidence"
  expect (actual.evidence.movementOperations.findEvent? movement == some eventId)
    "annual Movement did not retain durable idempotent operation mapping"
  let bank : EffectCoordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩
  let cash : EffectCoordinate := ⟨⟨"cash"⟩, ⟨"jpy"⟩⟩
  let some bankRow := after.view.currentBalances.exactRowFor? bank
    | throw (IO.userError "post-Movement exact bank support missing")
  expect (bankRow.quantity.quanta == 7775 &&
          !(Loam.CurrentBalanceReview.selectExact
            after.view.currentBalances [cash]).isOk)
    "Movement altered known/unknown support or the expected balance"
  let policy ← requireOk
    (Loam.AnnualSourceQueryPolicy.admit?
      ⟨"jpy"⟩ "2027-01-03" configPool configCycle)
    "external pension policy"
  let pace ← requireOk (policy.project? after.view) "selected native Daily Pace"
  expect (pace.eligiblePool.quanta == 7775 &&
          pace.endExclusive == "2027-02-15")
    "native Movement lost new current quantity or changed pension cycle"

  -- Operation ID is retained both by AnnualSource HEAD and native Actual.
  match ← selected.recordMovement? "2030-01-03" movement (draft "bank" 75) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "native Movement operation identity duplicated")
  let badToken : MovementOperationId := ⟨"invalid\\ntoken"⟩
  match ← selected.recordMovement? "2030-01-03" badToken (draft "bank" 75) with
  | .refusedBeforeHead _ => pure ()
  | _ => throw (IO.userError "invalid Movement operation token admitted")
  expect ((← IO.FS.readFile (headPath annual)) == latest.headWire &&
          !(← (annual / "journal" / "2030" / "4.full.loam").pathExists))
    "rejected duplicate/invalid Movement modified selected HEAD"

  -- The original installed source was only the read-only config/parity fixture.
  expect ((← IO.FS.readFile ordinarySource) == unchanged &&
          (← IO.FS.readFile ordinaryPrevious) == previous &&
          (← IO.FS.readFile (ordinary / "config" / "daily-pace.tsv")) == configPool &&
          (← IO.FS.readFile (ordinary / "config" / "boundary-presets.tsv")) == configCycle)
    "native Movement dual-published into old household or changed policy"
  IO.println "NATIVE_ANNUAL_MOVEMENT_SINGLE_OWNER_PASS actual Movement admission; 2028-effective/2030-publication; 7775 exact bank; unknown cash; Home/Pace; stale/duplicate/unapproved/invalid refusal; no dual write"

def main (args : List String) : IO Unit := do
  match args with
  | [ordinary, annual] =>
      run (System.FilePath.mk ordinary) (System.FilePath.mk annual)
  | _ => throw (IO.userError
      "usage: NativeAnnualSingleOwnerMovementProbe SYNTHETIC_HOUSEHOLD ANNUAL_ROOT")

end Loam.Tools.NativeAnnualSingleOwnerMovementProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualSingleOwnerMovementProbe.main args
