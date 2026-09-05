import Loam.Observations.Observation179

namespace Loam.Observation180

open Loam.Core
open Loam.Observation159

set_option autoImplicit false

/-!
# Observation 180 — observational closure and a minimal additive basis

Observation 179 found a Galois polarity between chosen observations and the
retained-presentation transformations that preserve them. This observation
asks the next practical question:

* what observations are forced once a family of observations is already fixed?
* does the resulting double-polarity operator satisfy the closure laws?
* can a report field be redundant while the observations from which it is
  derived are individually necessary?

The witness stays on Observation 159's finite `{wallet, food}` presentation
plane. No production abstraction is introduced.
-/

abbrev Evidence := Loam.Observation179.Presentation
abbrev Transform := Evidence → Evidence

/--
The deliberately tiny observation language for this field trial.

`totalQuantity` is defined from the two coordinate quantities. The retained list
length is representation evidence rather than an additive observation.
-/
inductive Observable where
  | walletQuantity
  | foodQuantity
  | totalQuantity
  | representationLength
  deriving Repr, DecidableEq

/-- Evaluate one observation as an exact integer. -/
def observe : Observable → Evidence → Int
  | .walletQuantity, changes => (aggregateAt changes .wallet).quanta
  | .foodQuantity, changes => (aggregateAt changes .food).quanta
  | .totalQuantity, changes =>
      (aggregateAt changes .wallet).quanta +
        (aggregateAt changes .food).quanta
  | .representationLength, changes => Int.ofNat changes.length

/-- A retained-evidence endomap preserves one observation everywhere. -/
def Preserves (transform : Transform) (observable : Observable) : Prop :=
  ∀ changes, observe observable changes = observe observable (transform changes)

/-- A transform preserves every observation selected by a family predicate. -/
def PreserverOf
    (observables : Observable → Prop)
    (transform : Transform) : Prop :=
  ∀ observable, observables observable → Preserves transform observable

/-- An observation is invariant under every transform selected by a predicate. -/
def InvariantUnder
    (transforms : Transform → Prop)
    (observable : Observable) : Prop :=
  ∀ transform, transforms transform → Preserves transform observable

/--
Double polarity: all observations preserved by every transform that preserves
the starting observation family.
-/
def Closure
    (observables : Observable → Prop)
    (observable : Observable) : Prop :=
  InvariantUnder (PreserverOf observables) observable

/-! ## Generic closure laws -/

/-- Every chosen observation belongs to its double-polarity closure. -/
theorem closure_extensive
    (observables : Observable → Prop) :
    ∀ observable, observables observable → Closure observables observable := by
  intro observable hObservable transform hTransform
  exact hTransform observable hObservable

/-- Adding observations can only enlarge the resulting observational closure. -/
theorem closure_monotone
    {smaller larger : Observable → Prop}
    (h : ∀ observable, smaller observable → larger observable) :
    ∀ observable, Closure smaller observable → Closure larger observable := by
  intro observable hClosed transform hLarger
  apply hClosed transform
  intro observed hSmaller
  exact hLarger observed (h observed hSmaller)

/-- Applying the double-polarity closure twice adds nothing further. -/
theorem closure_idempotent
    (observables : Observable → Prop)
    (observable : Observable) :
    Closure (Closure observables) observable ↔ Closure observables observable := by
  constructor
  · intro h transform hTransform
    apply h transform
    intro observed hClosed
    exact hClosed transform hTransform
  · intro h
    exact closure_extensive (Closure observables) observable h

/-! ## Concrete additive basis -/

/-- Wallet quantity alone. -/
def WalletOnly : Observable → Prop
  | .walletQuantity => True
  | _ => False

/-- Food quantity alone. -/
def FoodOnly : Observable → Prop
  | .foodQuantity => True
  | _ => False

/-- The two coordinate quantities that determine the finite additive image. -/
def AdditiveBasis : Observable → Prop
  | .walletQuantity => True
  | .foodQuantity => True
  | _ => False

/-- Add the derived total to the two-coordinate additive basis. -/
def AdditiveWithTotal (observable : Observable) : Prop :=
  AdditiveBasis observable ∨ observable = .totalQuantity

/-- Preserving both coordinate quantities necessarily preserves their total. -/
theorem preserves_total_of_wallet_and_food
    (transform : Transform)
    (hWallet : Preserves transform .walletQuantity)
    (hFood : Preserves transform .foodQuantity) :
    Preserves transform .totalQuantity := by
  intro changes
  have hw := hWallet changes
  have hf := hFood changes
  simp [observe] at hw hf
  change
    (aggregateAt changes .wallet).quanta +
        (aggregateAt changes .food).quanta =
      (aggregateAt (transform changes) .wallet).quanta +
        (aggregateAt (transform changes) .food).quanta
  calc
    (aggregateAt changes .wallet).quanta +
        (aggregateAt changes .food).quanta =
      (aggregateAt (transform changes) .wallet).quanta +
        (aggregateAt changes .food).quanta := by
          exact congrArg
            (fun wallet : Int =>
              wallet + (aggregateAt changes .food).quanta)
            hw
    _ = (aggregateAt (transform changes) .wallet).quanta +
        (aggregateAt (transform changes) .food).quanta := by
          exact congrArg
            (fun food : Int =>
              (aggregateAt (transform changes) .wallet).quanta + food)
            hf

/-- The derived total is forced by the two-coordinate additive basis. -/
theorem total_is_in_additive_closure :
    Closure AdditiveBasis .totalQuantity := by
  intro transform hTransform
  exact preserves_total_of_wallet_and_food transform
    (hTransform .walletQuantity (by simp [AdditiveBasis]))
    (hTransform .foodQuantity (by simp [AdditiveBasis]))

/-! ## Representation shape is not forced -/

/-- Observation 179's normalization, viewed as an arbitrary evidence endomap. -/
def normalizeTransform : Transform :=
  Loam.Observation179.normalize

/-- Normalization preserves wallet quantity. -/
theorem normalize_preserves_wallet :
    Preserves normalizeTransform .walletQuantity := by
  intro changes
  exact congrArg (fun quantity => quantity.quanta)
    (Loam.Observation179.normalize_vector_equivalent changes .wallet)

/-- Normalization preserves food quantity. -/
theorem normalize_preserves_food :
    Preserves normalizeTransform .foodQuantity := by
  intro changes
  exact congrArg (fun quantity => quantity.quanta)
    (Loam.Observation179.normalize_vector_equivalent changes .food)

/-- Therefore normalization preserves the whole additive basis. -/
theorem normalize_preserves_additive_basis :
    PreserverOf AdditiveBasis normalizeTransform := by
  intro observable hObservable
  cases observable with
  | walletQuantity => exact normalize_preserves_wallet
  | foodQuantity => exact normalize_preserves_food
  | totalQuantity => simp [AdditiveBasis] at hObservable
  | representationLength => simp [AdditiveBasis] at hObservable

/-- But normalization does not preserve retained presentation length. -/
theorem normalize_does_not_preserve_representation_length :
    ¬ Preserves normalizeTransform .representationLength := by
  intro h
  have hLength := h splitPresentation
  simp [observe, normalizeTransform, Loam.Observation179.normalize,
    splitPresentation] at hLength

/-- Representation length is therefore outside the additive closure. -/
theorem representation_length_not_in_additive_closure :
    ¬ Closure AdditiveBasis .representationLength := by
  intro h
  exact normalize_does_not_preserve_representation_length
    (h normalizeTransform normalize_preserves_additive_basis)

/-! ## Both basis coordinates are genuinely needed for the total -/

/-- Forget food while retaining the exact wallet aggregate. -/
def eraseFood : Transform := fun changes =>
  [ { coordinate := .wallet, quantity := aggregateAt changes .wallet },
    { coordinate := .food, quantity := 0 } ]

/-- Forget wallet while retaining the exact food aggregate. -/
def eraseWallet : Transform := fun changes =>
  [ { coordinate := .wallet, quantity := 0 },
    { coordinate := .food, quantity := aggregateAt changes .food } ]

/-- Erasing food still preserves the wallet observation. -/
theorem eraseFood_preserves_wallet :
    Preserves eraseFood .walletQuantity := by
  intro changes
  simp [observe, eraseFood, aggregateAt]

/-- Erasing wallet still preserves the food observation. -/
theorem eraseWallet_preserves_food :
    Preserves eraseWallet .foodQuantity := by
  intro changes
  simp [observe, eraseWallet, aggregateAt]

/-- The compact Observation-159 witness shows that erasing food changes total. -/
theorem eraseFood_does_not_preserve_total :
    ¬ Preserves eraseFood .totalQuantity := by
  intro h
  have hTotal := h compactPresentation
  simp [observe, eraseFood, aggregateAt, compactPresentation] at hTotal

/-- The same witness shows that erasing wallet changes total. -/
theorem eraseWallet_does_not_preserve_total :
    ¬ Preserves eraseWallet .totalQuantity := by
  intro h
  have hTotal := h compactPresentation
  simp [observe, eraseWallet, aggregateAt, compactPresentation] at hTotal

/-- One coordinate alone does not force total quantity. -/
theorem wallet_only_does_not_force_total :
    ¬ Closure WalletOnly .totalQuantity := by
  intro h
  apply eraseFood_does_not_preserve_total
  apply h eraseFood
  intro observable hObservable
  cases observable with
  | walletQuantity => exact eraseFood_preserves_wallet
  | foodQuantity => simp [WalletOnly] at hObservable
  | totalQuantity => simp [WalletOnly] at hObservable
  | representationLength => simp [WalletOnly] at hObservable

/-- Nor does the other coordinate alone force total quantity. -/
theorem food_only_does_not_force_total :
    ¬ Closure FoodOnly .totalQuantity := by
  intro h
  apply eraseWallet_does_not_preserve_total
  apply h eraseWallet
  intro observable hObservable
  cases observable with
  | walletQuantity => simp [FoodOnly] at hObservable
  | foodQuantity => exact eraseWallet_preserves_food
  | totalQuantity => simp [FoodOnly] at hObservable
  | representationLength => simp [FoodOnly] at hObservable

/-! ## A redundant derived observation does not increase distinguishing power -/

/--
A transform preserves the two-coordinate basis iff it preserves the same basis
with derived total explicitly added.
-/
theorem additive_basis_preserver_iff_with_total
    (transform : Transform) :
    PreserverOf AdditiveBasis transform ↔
      PreserverOf AdditiveWithTotal transform := by
  constructor
  · intro hBasis observable hObservable
    rcases hObservable with hBasisObservable | hTotal
    · exact hBasis observable hBasisObservable
    · subst observable
      exact preserves_total_of_wallet_and_food transform
        (hBasis .walletQuantity (by simp [AdditiveBasis]))
        (hBasis .foodQuantity (by simp [AdditiveBasis]))
  · intro hWithTotal observable hObservable
    exact hWithTotal observable (Or.inl hObservable)

/--
Adding the already-derived total does not change the complete observational
closure. In this witness plane, `totalQuantity` is therefore redundant once
wallet and food quantities are already observed.
-/
theorem adding_total_does_not_change_closure
    (observable : Observable) :
    Closure AdditiveBasis observable ↔
      Closure AdditiveWithTotal observable := by
  constructor
  · intro h transform hWithTotal
    exact h transform
      ((additive_basis_preserver_iff_with_total transform).mpr hWithTotal)
  · intro h transform hBasis
    exact h transform
      ((additive_basis_preserver_iff_with_total transform).mp hBasis)

end Loam.Observation180
