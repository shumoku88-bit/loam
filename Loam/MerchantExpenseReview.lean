import Loam.ActualAuthority
import Loam.ActualReview
import Loam.Persistence.AccountingRolePersistence
import Loam.TransactionsFlowReview

namespace Loam.MerchantExpenseReview

open Loam.Core

set_option autoImplicit false

/-!
# Exact Merchant Expense projection

This read boundary composes only evidence already owned elsewhere:

- current dated Events and Effects from `TransactionsFlowReview`;
- Event Merchant disposition from normalized Actual evidence;
- explicit `AccountingRole` classification for Effect Loci.

It does not retain a Merchant amount. A total is derived only when Merchant
coverage is complete for every selected Event that could change the requested
Measure's Expense answer, and every nonzero Effect in the requested Measure on
the selected Merchant's Events has an explicit AccountingRole.

Missing Merchant evidence and missing AccountingRole evidence remain separate
witnesses. Neither is converted to zero, `nonmerchant`, or a default role.
-/

/-- One selected Event whose Merchant disposition is still unresolved. -/
structure UnresolvedMerchantEvent where
  event : EventId
  date : String
deriving Repr, DecidableEq

/-- One target-Merchant Effect whose AccountingRole is unresolved. -/
structure UnresolvedRoleEffect where
  event : EventId
  date : String
  effect : Effect

/--
One Event-level contribution derived from the Event's Effects whose Loci are
explicitly classified as `expense` in the requested Measure.

This is transient query evidence, not retained Merchant amount authority.
-/
structure Contribution where
  event : EventId
  date : String
  quantity : Quantity
deriving Repr, DecidableEq

/--
Inspectable result of one Merchant / Measure / window query.

`contributions` may be useful while classification is incomplete, but callers
must use `exactTotal?` before presenting a quantity as an exact Merchant total.
-/
structure Snapshot where
  start : String
  endExclusive : String
  party : ExternalPartyId
  measure : MeasureId
  contributions : List Contribution
  unresolvedMerchantEvents : List UnresolvedMerchantEvent
  unresolvedRoleEffects : List UnresolvedRoleEffect

private def isTargetMerchant
    (merchants : EventMerchantEvidenceMemory)
    (party : ExternalPartyId)
    (event : EventId) : Bool :=
  match merchants.findDisposition? event with
  | some (.merchant retained) => decide (retained = party)
  | _ => false

private def eventCouldAffectMerchantExpense
    (roles : AccountingRoleMap)
    (measure : MeasureId)
    (column : Loam.TransactionsFlowReview.Column) : Bool :=
  column.event.effects.any fun effect =>
    if effect.measure != measure || effect.quantity.quanta == 0 then
      false
    else
      match roles.roleOf? effect.locus with
      | some role => decide (role = .expense)
      | none => true

private def merchantCoverageGaps
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (merchants : EventMerchantEvidenceMemory)
    (roles : AccountingRoleMap)
    (measure : MeasureId) : List UnresolvedMerchantEvent :=
  flow.columns.filterMap fun column =>
    match merchants.findDisposition? column.event.id with
    | some _ => none
    | none =>
        if eventCouldAffectMerchantExpense roles measure column then
          some { event := column.event.id, date := column.date }
        else
          none

private def unresolvedRoleEffects
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (merchants : EventMerchantEvidenceMemory)
    (roles : AccountingRoleMap)
    (party : ExternalPartyId)
    (measure : MeasureId) : List UnresolvedRoleEffect :=
  flow.columns.flatMap fun column =>
    if !isTargetMerchant merchants party column.event.id then
      []
    else
      column.event.effects.filterMap fun effect =>
        if effect.measure != measure || effect.quantity.quanta == 0 then
          none
        else if (roles.roleOf? effect.locus).isNone then
          some { event := column.event.id, date := column.date, effect := effect }
        else
          none

private def contributionFor?
    (merchants : EventMerchantEvidenceMemory)
    (roles : AccountingRoleMap)
    (party : ExternalPartyId)
    (measure : MeasureId)
    (column : Loam.TransactionsFlowReview.Column) : Option Contribution :=
  if !isTargetMerchant merchants party column.event.id then
    none
  else
    let quanta := column.event.effects.foldl
      (fun total effect =>
        if effect.measure != measure then
          total
        else
          match roles.roleOf? effect.locus with
          | some .expense => total + effect.quantity.quanta
          | _ => total)
      0
    if quanta == 0 then
      none
    else
      some {
        event := column.event.id
        date := column.date
        quantity := Quantity.ofQuanta quanta
      }

/--
Pure Merchant-expense projection over one already-selected TransactionsFlow
window and the two explicit classification relations.
-/
def project
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (merchants : EventMerchantEvidenceMemory)
    (roles : AccountingRoleMap)
    (party : ExternalPartyId)
    (measure : MeasureId) : Snapshot :=
  {
    start := flow.start
    endExclusive := flow.endExclusive
    party := party
    measure := measure
    contributions := flow.columns.filterMap (contributionFor? merchants roles party measure)
    unresolvedMerchantEvents := merchantCoverageGaps flow merchants roles measure
    unresolvedRoleEffects := unresolvedRoleEffects flow merchants roles party measure
  }

/-- Signed Expense-role quantity derived from currently classified contributions. -/
def Snapshot.knownTotal (snapshot : Snapshot) : Quantity :=
  Quantity.ofQuanta <|
    snapshot.contributions.foldl (fun total row => total + row.quantity.quanta) 0

/--
Return a Merchant total only when both independent completeness boundaries close.

Merchant coverage is query-relative. An unclassified Event blocks exactness only
when it has a nonzero Effect in the requested Measure whose AccountingRole is
either `expense` or still unresolved. Events that provably cannot change this
Merchant/Measure Expense answer do not require an unrelated Merchant disposition.

For Events already classified as the requested Merchant, every nonzero Effect in
the requested Measure still requires explicit AccountingRole evidence.
-/
def Snapshot.exactTotal? (snapshot : Snapshot) : Option Quantity :=
  if snapshot.unresolvedMerchantEvents.isEmpty && snapshot.unresolvedRoleEffects.isEmpty then
    some snapshot.knownTotal
  else
    none

/--
Load one normalized Actual generation and current AccountingRole authority, then
compose the existing correction/date window projection with Merchant evidence.

Actual is decoded once so Event selection and Merchant disposition come from the
same retained generation. AccountingRole remains its independent authority.
-/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start endExclusive : String)
    (party : ExternalPartyId)
    (measure : MeasureId) : IO (Except String Snapshot) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let evidence ←
    match ← Loam.ActualAuthority.loadActualFile? actualPath with
    | .ok value => pure value
    | .error message => return .error message
  let records ←
    match Loam.ActualReview.recordsFromActualEvidence? evidence with
    | .ok value => pure value
    | .error message => return .error message
  let flow ←
    match Loam.TransactionsFlowReview.project records start endExclusive with
    | .ok value => pure value
    | .error message => return .error message

  let rolePath := dataDir / "accounting-role.loam"
  if !(← rolePath.pathExists) then
    return .error "loam: required AccountingRole evidence is missing"
  let roles ←
    match ← Loam.Persistence.loadAccountingRoleMap? rolePath with
    | some value => pure value
    | none => return .error "loam: malformed or unsupported AccountingRole evidence"

  return .ok (project flow evidence.merchants roles party measure)

end Loam.MerchantExpenseReview
