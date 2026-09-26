namespace Loam.Observation356

set_option autoImplicit false

/-!
# Observation 356 — historically booked basis is distinct from current-restated basis

Observation 355 showed that historical apportionment retention is query-relative.

The next practical investment pressure is stronger than pure reconstruction:

> What happens when a derived integer basis answer is acted on externally,
> then the upstream acquisition evidence is corrected later?

Selected history:

1. Original retained acquisition evidence implies:

       exact average basis = 1000 / 3 JPY per share

2. Selected booking policy is per-unit ceil:

       booked unit basis = 334 JPY

3. That 334 JPY answer is committed as a historical booked result.

4. Later correction changes the exact acquisition basis to:

       999 / 3 JPY per share

5. Current-restated recomputation becomes:

       333 JPY

The intended distinction is:

    historical as-booked answer = 334
    current-restated answer     = 333

This observation asks whether either can be reconstructed from the other.

It does not assume every derived report value deserves persistence.

The pressure only applies when the derived result has become independently
observable historical meaning, for example because it was filed, posted,
published, exported, or otherwise committed outside the current recomputation.
-/

structure BasisInput where
  totalBasisJpy : Nat
  units : Nat
deriving Repr, DecidableEq

private def originalInput : BasisInput := {
  totalBasisJpy := 1000
  units := 3
}

private def correctedInput : BasisInput := {
  totalBasisJpy := 999
  units := 3
}

private def ceilUnitBasis? (input : BasisInput) : Option Nat :=
  if input.units = 0 then
    none
  else
    let q := input.totalBasisJpy / input.units
    let r := input.totalBasisJpy % input.units
    some (if r = 0 then q else q + 1)

theorem selected_original_and_corrected_answers_diverge :
    ceilUnitBasis? originalInput = some 334 ∧
    ceilUnitBasis? correctedInput = some 333 := by
  native_decide

structure BookingId where
  token : String
deriving Repr, DecidableEq

private def filing : BookingId := ⟨"selected-filing"⟩

structure BookedBasis where
  booking : BookingId
  amountJpy : Nat
deriving Repr, DecidableEq

private def booked334 : BookedBasis := {
  booking := filing
  amountJpy := 334
}

private def booked333 : BookedBasis := {
  booking := filing
  amountJpy := 333
}

/--
Current-restated basis is a projection of the corrected upstream evidence.
-/
private def currentRestated? : Option Nat :=
  ceilUnitBasis? correctedInput

/--
Historical as-booked basis is the amount that was actually committed at the
historical booking boundary.
-/
private def asBooked
    (booked : BookedBasis) : Nat :=
  booked.amountJpy

theorem current_restated_and_as_booked_can_coexist :
    currentRestated? = some 333 ∧
    asBooked booked334 = 334 := by
  native_decide

structure CurrentVisibleState where
  correctedInput : BasisInput
deriving Repr, DecidableEq

private def currentVisible : CurrentVisibleState := {
  correctedInput := correctedInput
}

/--
Two histories can have identical current corrected evidence while differing in
what was historically booked.

So current corrected input and current policy do not determine the old booked
answer.
-/
structure HistoricalWorld where
  current : CurrentVisibleState
  booked : BookedBasis
deriving Repr, DecidableEq

private def worldBooked334 : HistoricalWorld := {
  current := currentVisible
  booked := booked334
}

private def worldBooked333 : HistoricalWorld := {
  current := currentVisible
  booked := booked333
}

theorem current_evidence_does_not_determine_historical_booking :
    worldBooked334.current = worldBooked333.current ∧
    worldBooked334.booked ≠ worldBooked333.booked := by
  native_decide

/--
Conversely, the same booked amount can coexist with different current-restated
upstream evidence.

So the booked result alone is not a replacement for current corrected source
evidence.
-/
private def correctedInputAlt : BasisInput := {
  totalBasisJpy := 996
  units := 3
}

private def currentVisibleAlt : CurrentVisibleState := {
  correctedInput := correctedInputAlt
}

private def worldSameBookedDifferentCurrent : HistoricalWorld := {
  current := currentVisibleAlt
  booked := booked334
}

theorem historical_booking_does_not_determine_current_restated_basis :
    worldBooked334.booked = worldSameBookedDifferentCurrent.booked ∧
    worldBooked334.current ≠ worldSameBookedDifferentCurrent.current ∧
    ceilUnitBasis? worldBooked334.current.correctedInput = some 333 ∧
    ceilUnitBasis? worldSameBookedDifferentCurrent.current.correctedInput =
      some 332 := by
  native_decide

inductive BasisView where
  | asBooked
  | currentRestated
deriving Repr, DecidableEq

private def basisView?
    (world : HistoricalWorld)
    (view : BasisView) : Option Nat :=
  match view with
  | .asBooked => some world.booked.amountJpy
  | .currentRestated => ceilUnitBasis? world.current.correctedInput

theorem one_history_supports_both_coordinate_answers :
    basisView? worldBooked334 .asBooked = some 334 ∧
    basisView? worldBooked334 .currentRestated = some 333 := by
  native_decide

/--
If no historical booking promise exists, retaining a booked copy would add no
new answer for a current-restated-only vocabulary.

This models the opposite case: pure projection remains projection.
-/
private def currentOnlyAnswer? (input : BasisInput) : Option Nat :=
  ceilUnitBasis? input

theorem current_only_query_needs_no_separate_booked_copy :
    currentOnlyAnswer? correctedInput = some 333 := by
  native_decide

/--
The historical booked amount also does not identify *why* it was booked.

Different historical exact inputs can quantize to the same booked integer.
-/
private def anotherOriginalInput : BasisInput := {
  totalBasisJpy := 1001
  units := 3
}

theorem booked_result_does_not_reconstruct_historical_exact_input :
    ceilUnitBasis? originalInput = some 334 ∧
    ceilUnitBasis? anotherOriginalInput = some 334 ∧
    originalInput ≠ anotherOriginalInput := by
  native_decide

/-!
## Finding

A derived basis value has two very different roles depending on whether it ever
crosses a historical commitment boundary.

### Pure projection

If the application only asks:

    what is the basis under current corrected evidence and current policy?

then the integer answer is still a projection.

Retaining a second canonical copy would create duplicated truth and a
synchronization obligation.

### Historically booked result

If the application must later answer:

    what integer basis was actually booked / filed / posted then?

then later source correction creates two independently observable answers:

    as-booked
    current-restated

The selected witness proves neither answer determines the other.

This is the investment-specific instance of the earlier as-published versus
current-restated boundary.

The important new point is where persistence becomes earned:

    computation
        does not itself earn retention

    externally committed computation result
        may become independent historical evidence

provided the product promises to answer that historical question.

### Retaining the booked result is still not enough for explanation

The booked integer 334 does not reconstruct the original exact input:

    1000 / 3 -> ceil -> 334
    1001 / 3 -> ceil -> 334

So if future questions ask why 334 was booked, historical source/policy
provenance remains separately relevant.

The current candidate decomposition is therefore:

    immutable / correction-aware acquisition evidence
        ->
    current-restated exact basis projection
        +
    selected current policy
        ->
    current-restated integer basis

and, only when independently observed:

    historical booking act
        ->
    retained booked integer result
        +
    provenance sufficient for selected audit/explanation questions

No universal AllocationHistory is earned.

A future production design should first identify the real commitment boundary:

- tax filing;
- ledger posting;
- exported immutable statement;
- broker-reported booked basis;
- another user-visible act.

Only then should a retained booked-basis evidence family be considered.

Still not earned:

- production BookedBasis;
- tax-filing persistence;
- automatic retention of every projection result;
- a new Core booking primitive;
- one universal booking coordinate;
- correction/supersession semantics for a booked filing;
- policy-version persistence;
- treating a filed value as current accounting truth.

The next pressure is correction semantics after booking:

> If a historically booked basis itself is later amended or corrected, should
> LOAM reuse the ordinary correction frontier pattern rather than inventing a
> second booking-specific lifecycle?

That should be tested before any production booking evidence is introduced.
-/

end Loam.Observation356
