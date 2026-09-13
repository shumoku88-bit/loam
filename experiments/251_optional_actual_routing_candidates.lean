import Loam.ActualRoutingPublisher
import Loam.ActualRoutingReview

open Loam.Core
open Loam.Persistence

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw <| IO.userError message

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw <| IO.userError message

private structure CandidateRow where
  locus : LocusId
  role : AccountingRole
  status : RoutingStatus
  deriving Repr, DecidableEq

private def rowFor?
    (roles : AccountingRoleMap)
    (routing : ActualRoutingHistory)
    (effective : RoutingEffective String)
    (locus : LocusId) : Option CandidateRow := do
  let role ← roles.roleOf? locus
  return { locus := locus, role := role, status := routing.statusAt locus effective }

private def defaultExpenseRows
    (admission : LocusAdmissionVocabulary)
    (roles : AccountingRoleMap)
    (routing : ActualRoutingHistory)
    (effective : RoutingEffective String) : List CandidateRow :=
  admission.approved.filterMap fun locus => do
    let row ← rowFor? roles routing effective locus
    if row.role = .expense then some row else none

private def optionalKnownNonExpenseRows
    (admission : LocusAdmissionVocabulary)
    (roles : AccountingRoleMap)
    (routing : ActualRoutingHistory)
    (effective : RoutingEffective String) : List CandidateRow :=
  admission.approved.filterMap fun locus => do
    let row ← rowFor? roles routing effective locus
    if row.role = .expense then none else some row

private def unresolvedRoleLoci
    (admission : LocusAdmissionVocabulary)
    (roles : AccountingRoleMap) : List LocusId :=
  admission.approved.filter fun locus => (roles.roleOf? locus).isNone

private def unroutedDefaultCount (rows : List CandidateRow) : Nat :=
  (rows.filter fun row => row.status == .unrouted).length

def main : IO Unit := do
  let food : LocusId := ⟨"food"⟩
  let yucho : LocusId := ⟨"yucho"⟩
  let allCountry : LocusId := ⟨"all-country"⟩
  let cash : LocusId := ⟨"cash"⟩
  let pension : LocusId := ⟨"pension"⟩
  let debt : LocusId := ⟨"debt-friend-k"⟩
  let mystery : LocusId := ⟨"mystery"⟩
  let oldAsset : LocusId := ⟨"old-asset"⟩

  let foodPurpose : PurposeId := ⟨"食費"⟩
  let savingsPurpose : PurposeId := ⟨"ゆうちょ貯金"⟩
  let investingPurpose : PurposeId := ⟨"オルカン積立"⟩

  let admission ← requireSome
    (LocusAdmissionVocabulary.ofLoci?
      [food, yucho, allCountry, cash, pension, debt, mystery])
    "admission fixture was not admitted"

  let roles ← requireSome
    (AccountingRoleMap.ofAssignments?
      [ { locus := food, role := .expense }
      , { locus := yucho, role := .asset }
      , { locus := allCountry, role := .asset }
      , { locus := cash, role := .asset }
      , { locus := pension, role := .income }
      , { locus := debt, role := .liability } ])
    "AccountingRole fixture was not admitted"

  let routing ← requireSome
    (RoutingHistory.ofEntries?
      ([ { subject := food
         , effectiveOn := (RoutingEffective.initial : RoutingEffective String)
         , purpose := some foodPurpose }
       , { subject := allCountry
         , effectiveOn := RoutingEffective.dated "2026-09-01"
         , purpose := some investingPurpose }
       , { subject := oldAsset
         , effectiveOn := (RoutingEffective.initial : RoutingEffective String)
         , purpose := some savingsPurpose } ] : List (RoutingEntry LocusId (RoutingEffective String))))
    "routing fixture was not admitted"

  let observed := RoutingEffective.dated "2026-09-13"
  let defaults := defaultExpenseRows admission roles routing observed
  let optional := optionalKnownNonExpenseRows admission roles routing observed
  let unresolved := unresolvedRoleLoci admission roles

  expect (defaults.map (fun row => row.locus.token) == ["food"])
    "default administration stopped being Expense-only"
  expect (defaults.head?.map (fun row => row.status) == some (.managed foodPurpose))
    "default Expense route status changed"
  expect (unroutedDefaultCount defaults == 0)
    "optional unrouted Loci leaked into the default warning count"

  expect
    (optional.map (fun row => (row.locus.token, row.role)) ==
      [ ("yucho", .asset)
      , ("all-country", .asset)
      , ("cash", .asset)
      , ("pension", .income)
      , ("debt-friend-k", .liability) ])
    "optional candidates did not preserve admitted known non-Expense roles"

  let yuchoRow ← requireSome (optional.find? fun row => row.locus = yucho)
    "yucho was not available as an optional routing candidate"
  expect (yuchoRow.status == .unrouted)
    "unrouted optional Asset was not shown as ordinary current status"
  expect (!(defaults.any fun row => row.locus = yucho))
    "optional Asset became a default routing obligation"

  let allCountryRow ← requireSome (optional.find? fun row => row.locus = allCountry)
    "all-country was not available as an optional routing candidate"
  expect (allCountryRow.status == .managed investingPurpose)
    "existing non-Expense route was not visible in optional administration"

  expect (unresolved.map (fun locus => locus.token) == ["mystery"])
    "unknown AccountingRole stopped remaining a separate audit frontier"
  expect (!(optional.any fun row => row.locus = mystery))
    "unknown-role Locus was guessed into optional routing candidates"
  expect (!(optional.any fun row => row.locus = oldAsset))
    "historical-only non-admitted route leaked into current candidates"

  let savingsDraft : Loam.ActualRoutingPublisher.Draft := {
    locus := yucho
    effectiveOn := RoutingEffective.dated "2026-08-17"
    target := .managed savingsPurpose }
  expect (savingsDraft.locus == yucho)
    "explicit optional routing changed the selected Locus"
  expect (savingsDraft.effectiveOn == RoutingEffective.dated "2026-08-17")
    "explicit historical effective coordinate was lost"
  expect (savingsDraft.target == .managed savingsPurpose)
    "explicit savings Purpose target was lost"

  let investingDraft : Loam.ActualRoutingPublisher.Draft := {
    locus := allCountry
    effectiveOn := (RoutingEffective.initial : RoutingEffective String)
    target := .managed investingPurpose }
  expect (investingDraft.effectiveOn == .initial)
    "initial optional routing coordinate was not representable"

  IO.println "Observation 251 witness: default Expense routing and optional admitted non-Expense routing can coexist without inventing a new routing obligation or Purpose kind."
