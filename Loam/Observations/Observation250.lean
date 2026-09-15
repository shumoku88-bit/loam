import Loam.Core.Effect
import Loam.Observations.Observation159

namespace Loam.Observation250

open Loam.Core

set_option autoImplicit false

/-!
# Observation 250 — LOAM to Ledger denotation boundary

`ledger/ledger-semantics` represents the balance-level Pacioli skeleton as a
finitely supported function from `(AccountName × Commodity)` accounts to exact
rational flow. LOAM Observation 159 already established that one fixed-Measure
`BalancedMovement` has a free-Abelian coordinate-vector projection.

This observation asks the smaller cross-project question without adding a
Mathlib or external repository dependency to LOAM:

> Can one LOAM balanced movement be read through an Account × Commodity shaped
> flow boundary while preserving every same-Measure coordinate quantity and the
> exact zero-total law?

The local `LedgerAccountShadow` is deliberately only the bridge shape. It does
not claim that a `LocusId` is intrinsically an accounting Account or that a
`MeasureId` is intrinsically a Ledger Commodity.
-/

/--
Type-preserving shadow of Ledger's atomic AccountName × Commodity coordinate.
Keeping LOAM identities here avoids smuggling display-name or accounting-role
meaning into the bridge.
-/
structure LedgerAccountShadow where
  locus : LocusId
  measure : MeasureId
  deriving Repr, DecidableEq

/-- One quantity-bearing row in the bridge presentation. -/
structure LedgerPostingShadow where
  account : LedgerAccountShadow
  quantity : Quantity
  deriving Repr, DecidableEq

/-- Embed one LOAM coordinate into the Ledger-shaped account coordinate. -/
def accountOf (locus : LocusId) (measure : MeasureId) : LedgerAccountShadow :=
  ⟨locus, measure⟩

/-- Map one represented movement change into the Ledger-shaped presentation. -/
def postingOf (measure : MeasureId)
    (change : MovementChange LocusId) : LedgerPostingShadow :=
  ⟨accountOf change.coordinate measure, change.quantity⟩

/-- The finite bridge presentation for one fixed-Measure LOAM movement. -/
def ledgerPresentation (measure : MeasureId)
    (changes : List (MovementChange LocusId)) : List LedgerPostingShadow :=
  changes.map (postingOf measure)

/-- Exact represented total of a Ledger-shaped bridge presentation. -/
def ledgerPresentationTotalQuanta
    (postings : List LedgerPostingShadow) : Int :=
  postings.foldr (fun posting total => posting.quantity.quanta + total) 0

/--
Pacioli-style coordinate observation before the canonical `Int → Rat` embedding
used by ledger-semantics. This is the exact integer-quanta subdomain LOAM owns.
-/
def ledgerFlowQuantaAtChanges
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (account : LedgerAccountShadow) : Int :=
  changes.foldr
    (fun change total =>
      if accountOf change.coordinate measure = account then
        change.quantity.quanta + total
      else
        total)
    0

/-- Quantity-valued wrapper around the exact bridge coordinate observation. -/
def ledgerFlowAtChanges
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (account : LedgerAccountShadow) : Quantity :=
  Quantity.ofQuanta (ledgerFlowQuantaAtChanges measure changes account)

/-- One admitted movement observed through the Ledger-shaped balance boundary. -/
def ledgerFlowAt
    (movement : BalancedMovement LocusId)
    (account : LedgerAccountShadow) : Quantity :=
  ledgerFlowAtChanges movement.measure movement.changes account

/-- Mapping the presentation does not change its exact represented total. -/
theorem ledgerPresentation_total_eq_movementTotal
    (measure : MeasureId)
    (changes : List (MovementChange LocusId)) :
    ledgerPresentationTotalQuanta (ledgerPresentation measure changes) =
      movementTotalQuanta changes := by
  induction changes with
  | nil => rfl
  | cons change rest ih =>
      change
        change.quantity.quanta +
            ledgerPresentationTotalQuanta (ledgerPresentation measure rest) =
          change.quantity.quanta + movementTotalQuanta rest
      rw [ih]

/-- A LOAM balanced movement therefore maps to an exactly zero-total presentation. -/
theorem balancedMovement_maps_to_zero_total
    (movement : BalancedMovement LocusId) :
    ledgerPresentationTotalQuanta
        (ledgerPresentation movement.measure movement.changes) = 0 := by
  rw [ledgerPresentation_total_eq_movementTotal]
  exact movement.balanced

/-- Same-Measure account observation is exactly LOAM's coordinate aggregate. -/
theorem ledgerFlowQuanta_accountOf
    (measure : MeasureId)
    (changes : List (MovementChange LocusId))
    (locus : LocusId) :
    ledgerFlowQuantaAtChanges measure changes (accountOf locus measure) =
      (Observation159.aggregateAt changes locus).quanta := by
  induction changes with
  | nil => rfl
  | cons change rest ih =>
      change
        (if accountOf change.coordinate measure = accountOf locus measure then
            change.quantity.quanta +
              ledgerFlowQuantaAtChanges measure rest (accountOf locus measure)
          else
            ledgerFlowQuantaAtChanges measure rest (accountOf locus measure)) =
          (if change.coordinate = locus then
              change.quantity.quanta + (Observation159.aggregateAt rest locus).quanta
            else
              (Observation159.aggregateAt rest locus).quanta)
      by_cases h : change.coordinate = locus
      · subst locus
        simp [ih]
      · have hAccount :
            accountOf change.coordinate measure ≠ accountOf locus measure := by
          intro hEqual
          have hLocus : change.coordinate = locus :=
            congrArg LedgerAccountShadow.locus hEqual
          exact h hLocus
        simp [h, hAccount, ih]

/--
Every same-Measure Ledger-shaped account observes exactly the quantity that
`BalancedMovement.quantityAt` observes at the corresponding LOAM Locus.
-/
theorem ledgerFlowAt_mapped_locus
    (movement : BalancedMovement LocusId)
    (locus : LocusId) :
    ledgerFlowAt movement (accountOf locus movement.measure) =
      movement.quantityAt locus := by
  unfold ledgerFlowAt ledgerFlowAtChanges
  rw [ledgerFlowQuanta_accountOf]
  simp [Observation159.aggregateAt, BalancedMovement.quantityAt]

/-- A different Measure cannot acquire flow from a single-Measure movement. -/
theorem ledgerFlowQuanta_other_measure_zero
    (measure otherMeasure : MeasureId)
    (hDifferent : otherMeasure ≠ measure)
    (changes : List (MovementChange LocusId))
    (locus : LocusId) :
    ledgerFlowQuantaAtChanges measure changes (accountOf locus otherMeasure) = 0 := by
  induction changes with
  | nil => rfl
  | cons change rest ih =>
      change
        (if accountOf change.coordinate measure = accountOf locus otherMeasure then
            change.quantity.quanta +
              ledgerFlowQuantaAtChanges measure rest (accountOf locus otherMeasure)
          else
            ledgerFlowQuantaAtChanges measure rest (accountOf locus otherMeasure)) = 0
      have hAccount :
          accountOf change.coordinate measure ≠ accountOf locus otherMeasure := by
        intro hEqual
        have hMeasure : measure = otherMeasure :=
          congrArg LedgerAccountShadow.measure hEqual
        exact hDifferent hMeasure.symm
      simp [hAccount, ih]

/-- Quantity-valued form of the cross-Measure isolation law. -/
theorem ledgerFlowAt_other_measure_zero
    (movement : BalancedMovement LocusId)
    (otherMeasure : MeasureId)
    (hDifferent : otherMeasure ≠ movement.measure)
    (locus : LocusId) :
    ledgerFlowAt movement (accountOf locus otherMeasure) = 0 := by
  unfold ledgerFlowAt ledgerFlowAtChanges
  rw [ledgerFlowQuanta_other_measure_zero movement.measure otherMeasure hDifferent]
  rfl

/--
Observation 159's vector equivalence is sufficient for equality at every
same-Measure Ledger-shaped account. The bridge therefore factors through the
same additive quotient that LOAM had already observed internally.
-/
theorem ledger_flow_respects_vector_equivalence
    (measure : MeasureId)
    (left right : List (MovementChange LocusId))
    (hEquivalent : Observation159.VectorEquivalent left right)
    (locus : LocusId) :
    ledgerFlowAtChanges measure left (accountOf locus measure) =
      ledgerFlowAtChanges measure right (accountOf locus measure) := by
  unfold ledgerFlowAtChanges
  rw [ledgerFlowQuanta_accountOf, ledgerFlowQuanta_accountOf]
  simpa using hEquivalent locus

end Loam.Observation250
