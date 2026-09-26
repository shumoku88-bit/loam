import Loam.ActualAuthority
import Loam.ActualReview
import Loam.Application.ExchangeEvidenceFrontier
import Loam.Application.OriginalAmountFrontier
import Loam.RoleFlowReview
import Loam.TransactionsFlowReview

namespace Loam.MultimeasureSpendReview

open Loam.Core

set_option autoImplicit false

/-!
# Measure-neutral spending window

This read boundary answers the practical multicurrency question needed by travel
without introducing a Trip transaction kind, home/foreign Measure roles, FX
rates, or valuation.

For one explicit half-open date window it keeps four things separate:

- ordinary classified Expense quantities, grouped only within each Measure;
- Expense quantities attached to qualified Exchange Events, reported separately
  so exchange fees cannot silently become purchase spend;
- OriginalAmountEvidence on Events that have a positively classified Expense
  Effect, again grouped only within each original Measure;
- qualified Exchange occurrences, retaining their exact selected source and
  destination Effects rather than deriving a rate.

Missing AccountingRole evidence remains visible. If an Event has
OriginalAmountEvidence but no positively classified Expense Effect and still has
an unresolved nonzero Effect, the original amount is surfaced as unresolved
rather than silently included or discarded.
-/

structure MeasureTotal where
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

structure ExchangeOccurrence where
  event : EventId
  date : String
  description : String
  source : Effect
  destination : Effect
  extraEffects : List Effect
deriving Repr, DecidableEq

structure UnresolvedEffect where
  event : EventId
  date : String
  effect : Effect
deriving Repr, DecidableEq

structure UnresolvedOriginalAmount where
  event : EventId
  date : String
  measure : MeasureId
  quantity : Quantity
deriving Repr, DecidableEq

structure Snapshot where
  start : String
  endExclusive : String
  accountingExpense : List MeasureTotal
  exchangeExpense : List MeasureTotal
  originalPresentedExpense : List MeasureTotal
  exchanges : List ExchangeOccurrence
  unresolvedExpenseEffects : List UnresolvedEffect
  unresolvedExchangeEffects : List UnresolvedEffect
  unresolvedOriginalAmounts : List UnresolvedOriginalAmount
deriving Repr, DecidableEq

/--
Already-admitted evidence needed by the pure projection.

Original amounts are the current-terminal projection from
OriginalAmountFrontier. Exchange rows are re-admitted before this value is
constructed by the production loader.
-/
structure Evidence where
  records : List Loam.ActualReview.Record
  roles : AccountingRoleMap
  originalAmounts : List Loam.Application.CurrentOriginalAmount
  exchanges : ExchangeEvidenceMemory

private def totalLe (left right : MeasureTotal) : Bool :=
  left.measure.token <= right.measure.token

private def addTotal
    (totals : List MeasureTotal)
    (measure : MeasureId)
    (delta : Int) : List MeasureTotal :=
  match totals with
  | [] =>
      [{ measure := measure, quantity := Quantity.ofQuanta delta }]
  | row :: rest =>
      if row.measure = measure then
        { row with
            quantity := Quantity.ofQuanta (row.quantity.quanta + delta) } :: rest
      else
        row :: addTotal rest measure delta

private def sortedTotals (totals : List MeasureTotal) : List MeasureTotal :=
  totals.mergeSort totalLe

private def isExchangeEvent
    (memory : ExchangeEvidenceMemory)
    (event : EventId) : Bool :=
  (memory.findByEvent? event).isSome

private def expenseRole
    (roles : AccountingRoleMap)
    (effect : Effect) : Bool :=
  match roles.roleOf? effect.locus with
  | some .expense => true
  | _ => false

private def addExpenseEffects
    (roles : AccountingRoleMap)
    (totals : List MeasureTotal)
    (event : Event) : List MeasureTotal :=
  event.effects.foldl
    (fun state effect =>
      if expenseRole roles effect then
        addTotal state effect.measure effect.quantity.quanta
      else
        state)
    totals

private def accountingExpenseTotals
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap)
    (exchanges : ExchangeEvidenceMemory) : List MeasureTotal :=
  sortedTotals <|
    flow.columns.foldl
      (fun totals column =>
        if isExchangeEvent exchanges column.event.id then
          totals
        else
          addExpenseEffects roles totals column.event)
      []

private def exchangeExpenseTotals
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap)
    (exchanges : ExchangeEvidenceMemory) : List MeasureTotal :=
  sortedTotals <|
    flow.columns.foldl
      (fun totals column =>
        if isExchangeEvent exchanges column.event.id then
          addExpenseEffects roles totals column.event
        else
          totals)
      []

private def unresolvedEffectsFor
    (wantExchange : Bool)
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap)
    (exchanges : ExchangeEvidenceMemory) : List UnresolvedEffect :=
  flow.columns.flatMap fun column =>
    if (isExchangeEvent exchanges column.event.id) == wantExchange then
      column.event.effects.filterMap fun effect =>
        if effect.quantity.quanta = 0 then
          none
        else
          match roles.roleOf? effect.locus with
          | some _ => none
          | none =>
              some {
                event := column.event.id
                date := column.date
                effect := effect
              }
    else
      []

private def hasPositiveExpense
    (roles : AccountingRoleMap)
    (event : Event) : Bool :=
  event.effects.any fun effect =>
    decide (effect.quantity.quanta > 0) && expenseRole roles effect

private def hasUnresolvedNonzero
    (roles : AccountingRoleMap)
    (event : Event) : Bool :=
  event.effects.any fun effect =>
    decide (effect.quantity.quanta != 0) &&
      (roles.roleOf? effect.locus).isNone

private def currentOriginalFor?
    (rows : List Loam.Application.CurrentOriginalAmount)
    (event : EventId) : Option Loam.Application.CurrentOriginalAmount :=
  rows.find? fun row => decide (row.event = event)

private structure OriginalProjection where
  totals : List MeasureTotal
  unresolved : List UnresolvedOriginalAmount

private def originalProjection
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (roles : AccountingRoleMap)
    (originals : List Loam.Application.CurrentOriginalAmount)
    (exchanges : ExchangeEvidenceMemory) : OriginalProjection :=
  let accumulated :=
    flow.columns.foldl
      (fun state column =>
        if isExchangeEvent exchanges column.event.id then
          state
        else
          match currentOriginalFor? originals column.event.id with
          | none => state
          | some original =>
              if hasPositiveExpense roles column.event then
                { state with
                    totals :=
                      addTotal
                        state.totals original.measure original.quantity.quanta }
              else if hasUnresolvedNonzero roles column.event then
                { state with
                    unresolved := {
                      event := column.event.id
                      date := column.date
                      measure := original.measure
                      quantity := original.quantity
                    } :: state.unresolved }
              else
                state)
      { totals := [], unresolved := [] }
  {
    totals := sortedTotals accumulated.totals
    unresolved := accumulated.unresolved.reverse
  }

private def findSelectedEffect?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect =>
    decide (effect.key = some key)

private def exchangeOccurrence
    (column : Loam.TransactionsFlowReview.Column)
    (evidence : ExchangeEvidence) : Except String ExchangeOccurrence := do
  let some source := findSelectedEffect? column.event evidence.source
    | throw
        ("loam: admitted exchange source Effect is unavailable for Event " ++
          column.event.id.token)
  let some destination := findSelectedEffect? column.event evidence.destination
    | throw
        ("loam: admitted exchange destination Effect is unavailable for Event " ++
          column.event.id.token)
  let extraEffects :=
    column.event.effects.filter fun effect =>
      !(decide (effect.key = some evidence.source)) &&
        !(decide (effect.key = some evidence.destination))
  return {
    event := column.event.id
    date := column.date
    description := column.description
    source := source
    destination := destination
    extraEffects := extraEffects
  }

private def exchangeOccurrences
    (flow : Loam.TransactionsFlowReview.Snapshot)
    (memory : ExchangeEvidenceMemory) :
    Except String (List ExchangeOccurrence) :=
  (flow.columns.filter fun column =>
      isExchangeEvent memory column.event.id).mapM fun column => do
    let some evidence := memory.findByEvent? column.event.id
      | throw
          ("loam: exchange Event lost its admitted ExchangeEvidence: " ++
            column.event.id.token)
    exchangeOccurrence column evidence

/--
Project one explicit window without converting or arithmetically combining
distinct Measures.
-/
def project
    (evidence : Evidence)
    (start endExclusive : String) : Except String Snapshot := do
  let flow ←
    Loam.TransactionsFlowReview.project evidence.records start endExclusive
  let originals :=
    originalProjection
      flow evidence.roles evidence.originalAmounts evidence.exchanges
  let exchangeRows ← exchangeOccurrences flow evidence.exchanges
  return {
    start := start
    endExclusive := endExclusive
    accountingExpense :=
      accountingExpenseTotals flow evidence.roles evidence.exchanges
    exchangeExpense :=
      exchangeExpenseTotals flow evidence.roles evidence.exchanges
    originalPresentedExpense := originals.totals
    exchanges := exchangeRows
    unresolvedExpenseEffects :=
      unresolvedEffectsFor false flow evidence.roles evidence.exchanges
    unresolvedExchangeEffects :=
      unresolvedEffectsFor true flow evidence.roles evidence.exchanges
    unresolvedOriginalAmounts := originals.unresolved
  }

/--
Load one coherent admitted Actual generation plus the independent current
AccountingRole authority.

The loader reuses the existing correction-aware OriginalAmount projection and
re-admits ExchangeEvidence before exposing the pure report evidence value.
-/
def loadEvidence
    (dataDir actualRoot : System.FilePath) : IO (Except String Evidence) := do
  let actualPath := Loam.ActualAuthority.actualPathFromRootOrFile actualRoot
  let image ←
    match ← Loam.ActualAuthority.loadImageFile? actualPath with
    | .ok image => pure image
    | .error message => return .error message
  let roles ←
    match ← Loam.RoleFlowReview.loadRoleMap dataDir with
    | .ok roles => pure roles
    | .error message => return .error message
  let originals ←
    match Loam.Application.currentOriginalAmounts?
        image.evidence.events
        image.evidence.corrections
        image.evidence.originalAmounts with
    | some rows => pure rows
    | none =>
        return .error
          "loam: admitted Actual image did not yield a current OriginalAmount projection"
  let exchanges ←
    match Loam.Application.admittedExchangeEvidence?
        image.evidence.events
        image.evidence.corrections
        image.evidence.exchanges with
    | some rows => pure rows
    | none =>
        return .error
          "loam: admitted Actual image did not yield qualified ExchangeEvidence"
  return .ok {
    records := Loam.ActualReview.recordsFromActualImage image
    roles := roles
    originalAmounts := originals
    exchanges := exchanges
  }

/-- Load and project one Measure-neutral spending window. -/
def loadSnapshot
    (dataDir actualRoot : System.FilePath)
    (start endExclusive : String) : IO (Except String Snapshot) := do
  let evidence ←
    match ← loadEvidence dataDir actualRoot with
    | .ok evidence => pure evidence
    | .error message => return .error message
  return project evidence start endExclusive

end Loam.MultimeasureSpendReview
