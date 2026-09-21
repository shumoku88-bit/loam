import Loam.RoleBalanceReview

namespace Loam.Observation286

open Loam.Core

set_option autoImplicit false

/-!
# Observation 286 — incomplete bank history without invented opening history

This observation composes existing production boundaries around one ordinary
"adopt LOAM midway through a bank account's life" specimen.

The selected scenario is:

```text
history before LOAM adoption        unknown

retained pre-observation purchase
  bank                              -3,000
  food                              +3,000

external bank balance observation   80,000

retained post-observation purchase
  bank                              -1,000
  food                              +1,000
```

The desired current answer is therefore:

```text
80,000 + (-1,000) = 79,000
```

The pressure is whether LOAM can answer that current question without silently
claiming that the unknown earlier bank history began at zero.

No new production type is introduced. The observation deliberately reuses:

- `ZeroOriginCoverage` for strong zero-origin historical support;
- `CurrentQuantityAnchor` for one later observed current quantity;
- the existing correction-aware Event frontier;
- `RoleBalanceReview` for current support routing.

The important distinction is:

```text
known retained flows
    !=
complete history from zero

later observed current quantity
    !=
proof of origin completeness
```
-/

private def bank : LocusId := ⟨"bank"⟩
private def food : LocusId := ⟨"food"⟩
private def yen : MeasureId := ⟨"jpy"⟩

private def bankCoordinate : EffectCoordinate := ⟨bank, yen⟩
private def foodCoordinate : EffectCoordinate := ⟨food, yen⟩

private def effect
    (key : String)
    (locus : LocusId)
    (quanta : Int) : Effect :=
  Effect.ofQuantity
    ⟨key⟩
    locus
    yen
    (Quantity.ofQuanta quanta)

private def beforeObservation? : Option Event :=
  Event.ofEffects?
    ⟨"known-before-observation"⟩
    [
      effect "before-bank" bank (-3000),
      effect "before-food" food 3000
    ]

private def afterObservation? : Option Event :=
  Event.ofEffects?
    ⟨"known-after-observation"⟩
    [
      effect "after-bank" bank (-1000),
      effect "after-food" food 1000
    ]

private def scenarioEvents? : Option EventMemory := do
  let before ← beforeObservation?
  let after ← afterObservation?
  EventMemory.ofEvents? [before, after]

private def noCorrections : EventCorrectionMemory := {
  corrections := []
  idNodup := by simp
}

private def anchor? : Option Loam.CurrentQuantityAnchor.Evidence := do
  let before ← beforeObservation?
  Loam.CurrentQuantityAnchor.Evidence.ofLists?
    [before.id]
    [{
      coordinate := bankCoordinate
      quantity := Quantity.ofQuanta 80000
    }]

/--
The later bank observation supports the current quantity even though the old
origin is unknown.

The retained Event before the observation is explicitly inside the reflected-root
cut, while the later Event remains outside and contributes its -1,000 delta.
-/
private def anchoredCurrentBank? : Option Int := do
  let events ← scenarioEvents?
  let anchor ← anchor?
  match Loam.CurrentQuantityAnchor.inspectQuantity
      events noCorrections anchor bankCoordinate with
  | .ok (some quantity) => some quantity.quanta
  | _ => none

theorem current_bank_is_observation_plus_later_delta :
    anchoredCurrentBank? = some 79000 := by
  native_decide

/--
The exact same retained Event history does not justify a zero-origin balance
query when no `ZeroOriginCoverage` evidence exists.

This is the critical refusal for imported / partial bank history.
-/
private def zeroOriginQueryRefused : Bool :=
  match scenarioEvents? with
  | none => false
  | some events =>
      match Loam.BalanceReview.project
          events noCorrections ZeroOriginCoverage.empty [bankCoordinate] with
      | .error _ => true
      | .ok _ => false

theorem missing_origin_history_stays_unavailable :
    zeroOriginQueryRefused = true := by
  native_decide

/--
Counterfactual diagnostic only.

If the caller *invented* zero-origin coverage for this partial history, ordinary
balance reconstruction would answer only the retained flow from zero:

```text
-3,000 + -1,000 = -4,000
```

That is not the observed current bank quantity 79,000. The arithmetic is correct
under the false premise; the premise is what LOAM must not infer.
-/
private def counterfactualZeroOriginBank? : Option Int := do
  let events ← scenarioEvents?
  let coverage ← ZeroOriginCoverage.ofCoordinates? [bankCoordinate]
  match Loam.BalanceReview.project
      events noCorrections coverage [bankCoordinate] with
  | .error _ => none
  | .ok snapshot =>
      match snapshot.rows with
      | [row] => some row.quantity.quanta
      | _ => none

theorem pretending_partial_history_started_at_zero_changes_the_answer :
    counterfactualZeroOriginBank? = some (-4000) ∧
    anchoredCurrentBank? = some 79000 := by
  native_decide

private def roles? : Option AccountingRoleMap :=
  AccountingRoleMap.ofAssignments? [
    { locus := bank, role := .asset },
    { locus := food, role := .expense }
  ]

/--
RoleBalance can expose the supported *current* bank quantity while leaving the
other partial-history coordinate unsupported.

The current anchor therefore does not become a blanket "history is complete"
flag for the Event image.
-/
private def roleBalanceScenario? : Option (Int × Bool) := do
  let events ← scenarioEvents?
  let anchor ← anchor?
  let roles ← roles?
  let evidence : Loam.BalanceReview.Evidence := {
    events := events
    corrections := noCorrections
    coverage := ZeroOriginCoverage.empty
  }
  match Loam.RoleBalanceReview.project
      evidence OpeningSupportMap.empty anchor roles with
  | .error _ => none
  | .ok snapshot =>
      let some bankRow :=
          snapshot.rows.find? fun row => row.coordinate = bankCoordinate
        | none
      let foodUnsupported :=
        snapshot.unsupportedBalances.any fun row =>
          decide (row.coordinate = foodCoordinate)
      some (bankRow.quantity.quanta, foodUnsupported)

theorem current_support_is_coordinate_local :
    roleBalanceScenario? = some (79000, true) := by
  native_decide

/-!
## Finding

The existing production evidence families already compose for the selected
incomplete-bank-history pressure:

```text
partial retained Events
+
explicit later current quantity observation
+
explicit reflected-root cut
    -> justified current quantity

partial retained Events
+
no zero-origin evidence
    -> historical / zero-origin balance unavailable
```

No synthetic opening Event is needed.

No padding amount is materialized into Actual.

No rule infers:

```text
first retained Event
    -> account started at zero
```

and no current assertion implies:

```text
history is complete from origin
```

This observation therefore strengthens the reading of Observations 201, 206,
243, 244 and 246 with one production-shaped composition specimen.

It does **not** earn:

- automatic bank import;
- statement reconciliation policy;
- a generic `HistoryCompleteness` type;
- padding / suspense publication;
- source-trust ranking;
- automatic opening-balance inference;
- permission to use occurrence date or file order to decide the reflected-root
  cut;
- historical as-of answers before the admitted current anchor.

The useful practical rule is smaller:

> A bank account may join LOAM midway through its life. A qualified current
> observation can support current answers from that boundary onward while the
> unknown earlier history remains honestly unknown.
-/

end Loam.Observation286
