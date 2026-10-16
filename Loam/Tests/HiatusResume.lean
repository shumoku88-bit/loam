import Loam.Cli.NewHouseholdCli
import Loam.Cli.ResumeCli
import Loam.HouseholdCommand
import Loam.Authority.ActualAuthority
import Loam.Authority.CurrentSupportAuthority
import Loam.Application.CurrentQuantityAnchor
import Loam.Tests.Support

namespace Loam.Tests.HiatusResume

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

private def bank : EffectCoordinate := ⟨⟨"bank"⟩, ⟨"jpy"⟩⟩

private def record (root : System.FilePath) (at : String) (amount : Int) :
    IO EventId := do
  let draft : Loam.MovementAdmission.Draft := {
    validOn := at
    description := some "synthetic ordinary purchase"
    effects := [
      Effect.ofAnonymousQuantity ⟨"bank"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-amount)),
      Effect.ofAnonymousQuantity ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta amount)
    ]
    relations := []
    discharges := []
    total := amount
  }
  requireOk (← Loam.HouseholdCommand.record root draft) "ordinary resumed record"

private def quantity (n : Int) : List Loam.CurrentQuantityAnchor.Assertion :=
  [{ coordinate := bank, quantity := Quantity.ofQuanta n }]

def main : IO Unit := do
  let parent ← IO.FS.createTempDir
  let root := parent / "ordinary-household"
  let _ ← requireOk (← Loam.NewHouseholdCli.create root)
    "new household not bootable"

  for locus in ["bank", "food"] do
    let _ ← requireOk
      (← Loam.HouseholdCommand.admitLocus root { token := locus })
      ("admit " ++ locus)
    pure ()
  let _ ← requireOk
    (← Loam.HouseholdCommand.assignInitialAccountingRole root {
      locus := ⟨"bank"⟩, role := .asset })
    "asset role"
  let _ ← requireOk
    (← Loam.HouseholdCommand.assignInitialAccountingRole root {
      locus := ⟨"food"⟩, role := .expense })
    "expense role"

  let oldEvent ← record root "2026-10-15" 250
  let movement ← requireSome
    (BalancedMovement.ofChanges? ⟨"jpy"⟩ [
      { coordinate := ⟨"bank"⟩, quantity := Quantity.ofQuanta (-2000) },
      { coordinate := ⟨"food"⟩, quantity := Quantity.ofQuanta 2000 }
    ])
    "Scheduled movement for overdue review"
  let oldScheduled ← requireOk
    (← Loam.HouseholdCommand.createScheduled root {
      scheduledOn := "2026-10-22", movement := movement
    })
    "create an old still-open Scheduled payment"

  let _ ← requireOk
    (← Loam.HouseholdCommand.observeCurrentQuantities root (quantity 10000))
    "initial current observed bank quantity"
  let _ ← requireOk
    (← Loam.HouseholdCommand.updateBoundedHistorySupport root {
      coordinate := bank, startDay := some "2026-10-15"
    })
    "initial bounded complete-history assertion"

  let before ← IO.FS.readFile (root / "household.loam")
  let snapshot ← requireOk
    (← Loam.ResumeCli.inspectAt root "2028-10-16")
    "review original household after two-year gap"
  expect (snapshot.overdue.length == 1)
    "old current-open Scheduled occurrence was silently considered paid"
  expect (snapshot.overdue.head?.map (·.id) == some oldScheduled)
    "overdue Scheduled identity was not retained"
  expect (snapshot.boundedClaims.length == 1)
    "old bounded-history completeness claim was hidden"
  expect (snapshot.exactAnchors.length == 1)
    "current anchored bank coordinate was lost"
  let guide := Loam.ResumeCli.render root snapshot
  expect (guide.includes "does NOT declare missing days complete")
    "hiatus guide claimed complete recording"
  expect (guide.includes "Shift-Tab")
    "hiatus guide omitted the route to clear stale history certification"
  expect ((← IO.FS.readFile (root / "household.loam")) == before)
    "read-only resume assessment modified canonical data"

  -- Under a retained 2026-onward *complete history* claim, reobserving a
  -- different 2028 bank balance must REFUSE, not quietly rewrite the gap.
  expect (!(← Loam.HouseholdCommand.observeCurrentQuantities root (quantity 9400)).isOk)
    "a stale bounded completeness claim incorrectly allowed reconciliation"
  expect ((← IO.FS.readFile (root / "household.loam")) == before)
    "refused 2028 reconciliation changed existing data"

  -- The normal household command removes the obsolete completeness claim,
  -- not the historical Actual or the household identity.
  let _ ← requireOk
    (← Loam.HouseholdCommand.updateBoundedHistorySupport root {
      coordinate := bank, startDay := none
    })
    "remove invalid pre-gap bounded-history claim"
  let _ ← requireOk
    (← Loam.HouseholdCommand.observeCurrentQuantities root (quantity 9400))
    "reobserve bank after hiatus"
  let newEvent ← record root "2028-10-16" 100

  let admitted ← requireOk (← Loam.ActualAuthority.loadHouseholdActual? root)
    "reopen retained and resumed Actual"
  expect (admitted.events.findById? oldEvent |>.isSome)
    "resumption lost original Actual"
  expect (admitted.events.findById? newEvent |>.isSome)
    "resumption lost new Actual"
  expect (admitted.events.events.length == 2)
    "unrecorded 2027 was filled with synthetic Actual"
  let supports ← requireOk (← Loam.CurrentSupportAuthority.loadHousehold? root)
    "load resumed known-current support"
  expect ((supports.snapshot.bounded.supportFor? bank).isNone)
    "historical completeness was silently reinstated"
  let some now ← requireOk
      (Loam.CurrentQuantityAnchor.inspectQuantity
        admitted.events admitted.corrections supports.snapshot.anchor bank)
      "inspect newly anchored bank"
    | throw (IO.userError "current bank quantity disappeared after resuming")
  expect (now.quanta == 9300)
    "current bank balance ignored explicit reconciliation and later movement"

  let after ← requireOk
    (← Loam.ResumeCli.inspectAt root "2028-10-17")
    "reopen resumed household report"
  expect (after.overdue.length == 1 && after.boundedClaims.isEmpty)
    "reopened household changed overdue or bounded-history status"
  IO.println "Long hiatus: old Actual preserved; overdue open; complete-history claim refused/removed; current balance observed and new Actual recorded; no fake missing-year events passed."

end Loam.Tests.HiatusResume

def main : IO Unit := Loam.Tests.HiatusResume.main
