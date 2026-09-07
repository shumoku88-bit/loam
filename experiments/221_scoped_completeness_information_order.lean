import Loam.Core.Event

namespace Loam.Observation221

open Loam.Core

set_option autoImplicit false

/-!
Observation 221 asks whether the zero-origin coverage pressure from Observation 219
and the Scheduled completeness-horizon pressure from Observation 211 justify one
new household `Coverage` ontology.

This file deliberately tests a smaller claim.  Both cases can be viewed through a
read-side information law:

* direct evidence may already determine an answer;
* otherwise an explicit completeness predicate may authorize a domain-specific
  closed-world reconstruction;
* without either, the answer remains unknown.

The predicate is experiment-local.  The way a completeness claim is earned and
stored remains domain-specific.
-/

/-- Minimal open-world knowledge ordering used only by this experiment. -/
inductive Knowledge (α : Type) where
  | unknown
  | known (value : α)
deriving Repr, DecidableEq

namespace Knowledge

/--
`left` carries no more information than `right`.

Unknown is below every answer.  A known value refines only to the same known
value; distinct known values are intentionally incomparable.
-/
def le {α : Type} [DecidableEq α] : Knowledge α → Knowledge α → Bool
  | .unknown, _ => true
  | .known left, .known right => decide (left = right)
  | .known _, .unknown => false

end Knowledge

/--
Extensional read-side completeness: which queries are safe to close.

This is intentionally only a predicate over a query space.  It contains no
persistence format, witness identity, chronology, account meaning, or policy
semantics.
-/
structure CompletenessScope (Query : Type) where
  covers : Query → Bool

/--
One small read-side algebra shared by the two synthetic instantiations below.

`direct` is evidence that is sufficient even without a completeness claim.
`closedValue` is the answer that becomes justified when the query is covered.
If neither direct evidence nor completeness covers the query, the result stays
open-world `unknown`.
-/
def inspectWithCompleteness {Query Answer : Type}
    (direct : Query → Option Answer)
    (closedValue : Query → Answer)
    (scope : CompletenessScope Query)
    (query : Query) : Knowledge Answer :=
  match direct query with
  | some value => .known value
  | none =>
      if scope.covers query then
        .known (closedValue query)
      else
        .unknown

/-- Direct evidence remains authoritative regardless of completeness scope. -/
theorem directEvidenceIgnoresCoverage {Query Answer : Type}
    (direct : Query → Option Answer)
    (closedValue : Query → Answer)
    (scope : CompletenessScope Query)
    (query : Query)
    (value : Answer)
    (h : direct query = some value) :
    inspectWithCompleteness direct closedValue scope query = .known value := by
  simp [inspectWithCompleteness, h]

/-- Missing direct evidence plus missing completeness remains unknown. -/
theorem uncoveredWithoutDirectIsUnknown {Query Answer : Type}
    (direct : Query → Option Answer)
    (closedValue : Query → Answer)
    (scope : CompletenessScope Query)
    (query : Query)
    (hDirect : direct query = none)
    (hScope : scope.covers query = false) :
    inspectWithCompleteness direct closedValue scope query = .unknown := by
  simp [inspectWithCompleteness, hDirect, hScope]

/-- Completeness may safely turn the same missing direct evidence into a known value. -/
theorem coveredWithoutDirectIsKnown {Query Answer : Type}
    (direct : Query → Option Answer)
    (closedValue : Query → Answer)
    (scope : CompletenessScope Query)
    (query : Query)
    (hDirect : direct query = none)
    (hScope : scope.covers query = true) :
    inspectWithCompleteness direct closedValue scope query =
      .known (closedValue query) := by
  simp [inspectWithCompleteness, hDirect, hScope]

/-! ## Scheduled-shaped instantiation -/

structure ScheduledQuery where
  subject : String
  day : Nat
deriving Repr, DecidableEq

private def rentDay1 : ScheduledQuery := ⟨"rent", 1⟩
private def rentDay2 : ScheduledQuery := ⟨"rent", 2⟩
private def rentDay3 : ScheduledQuery := ⟨"rent", 3⟩

/-- One explicitly materialized due occurrence is direct positive evidence. -/
private def explicitScheduled : ScheduledQuery → Option Bool
  | ⟨"rent", 1⟩ => some true
  | _ => none

/-- Under a completeness claim, absence means the boolean identity: not due. -/
private def scheduledClosedValue (_ : ScheduledQuery) : Bool := false

private def scheduledCompleteThrough2 : CompletenessScope ScheduledQuery :=
  ⟨fun query => decide (query.day ≤ 2)⟩

private def noScheduledCompleteness : CompletenessScope ScheduledQuery :=
  ⟨fun _ => false⟩

/-- Positive Scheduled evidence is known even outside any completeness claim. -/
example :
    inspectWithCompleteness
        explicitScheduled scheduledClosedValue noScheduledCompleteness rentDay1 =
      .known true := by
  native_decide

/-- Covered absence can safely become NotDue. -/
example :
    inspectWithCompleteness
        explicitScheduled scheduledClosedValue scheduledCompleteThrough2 rentDay2 =
      .known false := by
  native_decide

/-- Absence beyond the completeness horizon remains Unknown. -/
example :
    inspectWithCompleteness
        explicitScheduled scheduledClosedValue scheduledCompleteThrough2 rentDay3 =
      .unknown := by
  native_decide

/--
A mere visibility horizon is not completeness.  Reusing a broader visibility
predicate as completeness would strengthen the same absent day from Unknown to a
false negative claim.
-/
private def visibleThrough3ButNotComplete : CompletenessScope ScheduledQuery :=
  ⟨fun query => decide (query.day ≤ 3)⟩

example :
    inspectWithCompleteness
        explicitScheduled scheduledClosedValue scheduledCompleteThrough2 rentDay3 ≠
      inspectWithCompleteness
        explicitScheduled scheduledClosedValue visibleThrough3ButNotComplete rentDay3 := by
  native_decide

/-! ## Quantity-shaped instantiation -/

private def wallet : LocusId := ⟨"wallet"⟩
private def newWallet : LocusId := ⟨"new-wallet"⟩
private def jpy : MeasureId := ⟨"jpy"⟩
private def walletJpy : EffectCoordinate := ⟨wallet, jpy⟩
private def newWalletJpy : EffectCoordinate := ⟨newWallet, jpy⟩

/--
Retained Event activity is not by itself direct evidence of current stock.
Current quantity still needs an origin-completeness claim.
-/
private def noDirectCurrentQuantity (_ : EffectCoordinate) : Option Quantity := none

/-- Synthetic correction-aware Event aggregate used after origin completeness is known. -/
private def eventAggregate (coordinate : EffectCoordinate) : Quantity :=
  if coordinate = walletJpy then
    Quantity.ofQuanta 7
  else
    0

private def walletOriginComplete : CompletenessScope EffectCoordinate :=
  ⟨fun coordinate => decide (coordinate = walletJpy)⟩

private def noOriginCompleteness : CompletenessScope EffectCoordinate :=
  ⟨fun _ => false⟩

/-- Covered zero-origin history makes the retained Event aggregate a known current quantity. -/
example :
    inspectWithCompleteness
        noDirectCurrentQuantity eventAggregate walletOriginComplete walletJpy =
      .known (Quantity.ofQuanta 7) := by
  native_decide

/-- The same nonzero Event aggregate is still not a current balance without origin coverage. -/
example :
    inspectWithCompleteness
        noDirectCurrentQuantity eventAggregate noOriginCompleteness walletJpy =
      .unknown := by
  native_decide

/--
New-write admission is also not completeness.  A vocabulary may authorize a new
Locus while saying nothing about its prehistory.  Treating permission as origin
coverage would manufacture a known zero current balance.
-/
private def writeAdmissionLike : CompletenessScope EffectCoordinate :=
  ⟨fun coordinate => decide (coordinate = walletJpy ∨ coordinate = newWalletJpy)⟩

example :
    inspectWithCompleteness
        noDirectCurrentQuantity eventAggregate walletOriginComplete newWalletJpy =
      .unknown := by
  native_decide

example :
    inspectWithCompleteness
        noDirectCurrentQuantity eventAggregate writeAdmissionLike newWalletJpy =
      .known 0 := by
  native_decide

/-! ## Information-order witnesses -/

/-- Adding justified coverage can refine Unknown into Known without changing the payload. -/
example :
    Knowledge.le
      (inspectWithCompleteness
        noDirectCurrentQuantity eventAggregate noOriginCompleteness walletJpy)
      (inspectWithCompleteness
        noDirectCurrentQuantity eventAggregate walletOriginComplete walletJpy) = true := by
  native_decide

/-- Direct positive Scheduled evidence is unchanged by adding completeness. -/
example :
    inspectWithCompleteness
        explicitScheduled scheduledClosedValue noScheduledCompleteness rentDay1 =
      inspectWithCompleteness
        explicitScheduled scheduledClosedValue scheduledCompleteThrough2 rentDay1 := by
  native_decide

end Loam.Observation221
