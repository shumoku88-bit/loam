import Loam.Application.ReplacementFrontier

namespace Loam.Observation357

open Loam.Application

set_option autoImplicit false

/-!
# Observation 357 — booked-basis amendment can reuse the generic replacement frontier

Observation 356 separated two coordinates:

    historical as-booked basis
    current-restated basis

Selected practical story:

1. Original evidence:
       1000 / 3 -> per-unit ceil -> 334 JPY

2. 334 JPY is filed / booked externally.

3. Source evidence is corrected:
       999 / 3 -> 333 JPY current-restated

4. A formal amendment is then filed:
       original filing 334 -> amended filing 333

5. Source evidence is corrected again later:
       996 / 3 -> 332 JPY current-restated

At step 5 the latest filed amendment is still 333 while the current-restated
projection is 332.

The question is whether booked-basis amendment requires an investment-specific
correction lifecycle.

LOAM already has a domain-neutral structural mechanism below EventCorrection:

    Loam.Application.ReplacementFrontier

It admits closed, acyclic, one-to-one supersession paths and deliberately
refuses branching sibling replacements.

This observation applies only that generic mechanics to booking identities.
No Event is fabricated for a tax filing and no BookedBasis production type is
introduced.
-/

structure BasisInput where
  totalBasisJpy : Nat
  units : Nat
deriving Repr, DecidableEq

private def ceilUnitBasis? (input : BasisInput) : Option Nat :=
  if input.units = 0 then
    none
  else
    let q := input.totalBasisJpy / input.units
    let r := input.totalBasisJpy % input.units
    some (if r = 0 then q else q + 1)

private def originalInput : BasisInput :=
  ⟨1000, 3⟩

private def correctedInput : BasisInput :=
  ⟨999, 3⟩

private def correctedAgainInput : BasisInput :=
  ⟨996, 3⟩

theorem selected_restated_sequence :
    ceilUnitBasis? originalInput = some 334 ∧
    ceilUnitBasis? correctedInput = some 333 ∧
    ceilUnitBasis? correctedAgainInput = some 332 := by
  native_decide

inductive BookingId where
  | original
  | amended
  | alternative
deriving Repr, DecidableEq

structure BookedBasis where
  id : BookingId
  amountJpy : Nat
deriving Repr, DecidableEq

private def filed334 : BookedBasis :=
  ⟨.original, 334⟩

private def amended333 : BookedBasis :=
  ⟨.amended, 333⟩

private def alternative332 : BookedBasis :=
  ⟨.alternative, 332⟩

private structure BookingView where
  retained : List BookedBasis
  replacements : List (ReplacementFrontier.Edge BookingId)

private def present
    (items : List BookedBasis)
    (id : BookingId) : Bool :=
  items.any fun item => decide (item.id = id)

private def effectiveBookings?
    (view : BookingView) : Option (List BookedBasis) :=
  if ReplacementFrontier.structurallyAdmissible
      (present view.retained) view.replacements then
    some (ReplacementFrontier.frontier
      BookedBasis.id view.retained view.replacements)
  else
    none

private def beforeAmendment : BookingView := {
  retained := [filed334]
  replacements := []
}

private def afterAmendment : BookingView := {
  retained := [filed334, amended333]
  replacements := [
    { source := .original, successor := .amended }
  ]
}

/--
The same retained history can preserve the original filed value while the
current booking frontier moves to the amendment.
-/
theorem amendment_preserves_original_and_selects_current_filing :
    beforeAmendment.retained = [filed334] ∧
    effectiveBookings? beforeAmendment = some [filed334] ∧
    afterAmendment.retained = [filed334, amended333] ∧
    effectiveBookings? afterAmendment = some [amended333] := by
  native_decide

private def effectiveAmount? (view : BookingView) : Option Nat := do
  let rows ← effectiveBookings? view
  match rows with
  | [row] => some row.amountJpy
  | _ => none

/--
After the source evidence is corrected again, the current-restated answer can
move independently of the latest filed amendment.
-/
theorem booking_frontier_and_restated_source_frontier_are_independent :
    effectiveAmount? afterAmendment = some 333 ∧
    ceilUnitBasis? correctedAgainInput = some 332 := by
  native_decide

/--
A second amendment may supersede the first amendment by extending the same
one-to-one replacement path.
-/
private def afterSecondAmendment : BookingView := {
  retained := [filed334, amended333, alternative332]
  replacements := [
    { source := .original, successor := .amended },
    { source := .amended, successor := .alternative }
  ]
}

theorem amendment_chain_reuses_existing_one_to_one_frontier_shape :
    effectiveBookings? afterSecondAmendment = some [alternative332] ∧
    afterSecondAmendment.retained =
      [filed334, amended333, alternative332] := by
  native_decide

/--
Two competing amendments to the same original filing are not silently ordered
by list position.

This is exactly the existing Correction-frontier safety property we want to
reuse rather than recreate for booked basis.
-/
private def competingAmendments : BookingView := {
  retained := [filed334, amended333, alternative332]
  replacements := [
    { source := .original, successor := .amended },
    { source := .original, successor := .alternative }
  ]
}

theorem sibling_booking_amendments_remain_unresolved :
    ReplacementFrontier.structurallyAdmissible
      (present competingAmendments.retained)
      competingAmendments.replacements = false ∧
    effectiveBookings? competingAmendments = none := by
  native_decide

/--
Missing amendment payloads also fail closed rather than manufacturing a current
booked amount from an open reference.
-/
private def missingReplacementPayload : BookingView := {
  retained := [filed334]
  replacements := [
    { source := .original, successor := .amended }
  ]
}

theorem open_booking_replacement_reference_fails_closed :
    ReplacementFrontier.structurallyAdmissible
      (present missingReplacementPayload.retained)
      missingReplacementPayload.replacements = false ∧
    effectiveBookings? missingReplacementPayload = none := by
  native_decide

/-!
## Finding

The selected booked-basis amendment lifecycle does not require a new structural
correction engine.

The existing generic ReplacementFrontier already supplies the mechanical laws:

    retained old + new facts
    one-to-one supersession path
    closed references
    cycle refusal
    sibling-conflict refusal
    current frontier projection

Those mechanics are sufficient for the selected sequence:

    filed 334
        ->
    amended 333
        ->
    later amended 332

while preserving every earlier booked value in retained history.

The important semantic boundaries remain separate.

### Booking amendment is not source correction

At one point the selected world can simultaneously say:

    latest filed basis       = 333
    current-restated basis   = 332

because a later source correction does not retroactively amend the filing.

So these are independent frontiers:

    acquisition/source correction
        -> current-restated projection

    booking amendment
        -> current effective booked filing

One must not become an implicit correction of the other.

### Reuse the mechanics, not EventCorrection vocabulary

A tax filing or booked basis is not automatically a household Event.

The reusable production candidate, if a real booking family is later earned, is
therefore:

    domain-specific booked-basis evidence
        +
    generic ReplacementFrontier mechanics

not:

    fabricate Event rows
        +
    reuse EventCorrection merely for convenience

This follows the same architecture law already used elsewhere:

    share mechanics
    preserve semantic authority

### No new booking lifecycle is currently earned

Observation 357 only shows structural reuse is sufficient.

It does not yet justify retaining booked-basis evidence in production at all.
Observation 356 already restricted that promotion to a real externally observed
commitment boundary.

Still not earned:

- production BookedBasis evidence;
- production FilingId / BookingId;
- tax-specific filing semantics;
- a generic public Revision object;
- automatic correction of a filing when source evidence changes;
- automatic amended filing generation;
- sibling-amendment resolution authority;
- policy-version persistence;
- replacing EventCorrection with a generic production relation.

The next practical pressure is therefore not another correction abstraction.

It is the whole investment path:

> Given the boundaries now qualified separately, can LOAM admit and project one
> realistic security acquisition, basis, disposal, booked filing, later source
> correction, and amended filing without introducing a new Core primitive?

That vertical composition would be the strongest test before considering any
production investment persistence.
-/

end Loam.Observation357
