# Observation 227 — Can Scheduled Capacity pressure be derived without a new eligibility fact?

Status: **QUALIFIED by Alloy 6.2.0 / SAT4J at exact model head `18af43cef29bd642fdee37221fd738338277b86c`; selected bounded rule uses AccountingRole + polarity + ScheduledRouting while preserving unresolved role evidence**

## Pressure

The production household uses `Scheduled` for roughly fixed expected future cashflow, not only future expense.

Current retained examples therefore include both sides of that practical idea:

```text
wifi / povo / subscriptions / insurance / rent / utilities / debt repayment
pension / support receipts
```

Observation 108 qualified a bounded Commitment projection from open Scheduled quantity-bearing claims plus lifecycle and historical routing. The current Lean projection concretized every positive Scheduled Locus as one of:

```text
managed
explicitly unmanaged
unrouted
```

That is now under stronger household pressure. A positive Asset receipt such as pension landing in `smbc` is Scheduled, but it should not consume household Capacity merely because its quantity is positive.

At the same time, simply changing the default to positive Expense only would lose another real household pressure: a debt repayment has a positive Liability coordinate and is still a fixed outgoing obligation.

The question is therefore narrower than inventing a new fixed-cost ontology:

> Can LOAM select the Scheduled coordinates that exert Capacity pressure from already-retained AccountingRole, sign, and ScheduledRouting evidence, without retaining a new CommitmentEligibility fact?

## Existing evidence reused

This observation extends rather than replaces earlier results.

- Observation 049 established that physical Locus does not determine AccountingRole.
- Observation 108 established that lifecycle and routing are both required for the selected bounded Commitment view, but explicitly did not claim a universal Commitment law.
- Observation 110 established the selected accounting presentation convention `positive Effect -> Debit`, so positive Liability can represent liability reduction while positive Asset can represent an asset increase.
- Observation 153 selected `ScheduledId × LocusId` as the practical routing subject.
- Observations 216–217 established that AccountingRole is intentionally partial and that unresolved role evidence must remain visible rather than being treated as zero or irrelevant.
- Production now retains explicit `AccountingRole` and explicit `ScheduledRouting` authorities.

No HRA type or Envelope ontology is imported by this experiment.

## Household provenance pressure

The current 11 Scheduled occurrences in `loam-data` were imported from the then-current HRA household source into direct LOAM Loci without copying HRA AccountType, recurrence, series, anchor, or other HRA ontology.

The source evidence distinguishes representative shapes:

```text
positive Expense       wifi, rent, utilities, insurance, subscriptions
positive Liability     debt repayment
positive Asset         pension/support receipt into smbc
```

The old all-positive projection therefore visibly over-approximates Capacity pressure in this real household slice.

## Selected bounded rule

The smallest surviving rule is:

```text
negative coordinate
    -> resolved non-pressure

positive coordinate with explicit ScheduledRouting
    -> Capacity pressure, even when AccountingRole is unresolved

positive + no route + Expense or Liability role
    -> Capacity pressure

positive + no route + Asset / Income / Equity role
    -> resolved non-pressure

positive + no route + unresolved AccountingRole
    -> unresolved eligibility frontier
```

Once a coordinate is selected as pressure, existing routing outcomes still partition it:

```text
managed route      -> managed pressure
unmanaged route    -> explicitly unmanaged pressure
no route           -> unrouted pressure
```

The complete query-local partition is therefore:

```text
selected pressure
resolved non-pressure
unresolved eligibility
```

This gives the current household the intended distinctions without a new retained eligibility bit:

```text
wifi               Expense + managed route -> managed pressure
pension receipt    Asset + no route         -> resolved non-pressure
debt repayment     Liability + no route     -> unrouted pressure
planned savings    Asset + managed route    -> managed pressure
unknown new Locus  no role + no route       -> unresolved eligibility
funding source     negative                 -> resolved non-pressure
```

## Why AccountingRole alone is not enough

Role and sign should not erase explicit intent.

Two positive Asset coordinates can have the same AccountingRole while differing in ScheduledRouting:

```text
ordinary incoming Asset + no route
planned savings Asset   + managed route
```

The former need not consume Capacity; the latter can explicitly do so.

Likewise, absence of AccountingRole is not a third role. Because `AccountingRoleMap` is partial, a positive unrouted coordinate with no role must not silently become either pressure or non-pressure.

The bounded result therefore rejects:

```text
AccountingRole + polarity alone determine pressure
missing AccountingRole means resolved non-pressure
```

while supporting the selected query projection from:

```text
polarity + partial AccountingRole + ScheduledRouting
```

## Executed Alloy result

Exact model/workflow head:

```text
18af43cef29bd642fdee37221fd738338277b86c
```

Workflow: `Observation 227`, run 12, Alloy 6.2.0 / SAT4J.

The expected-result checker completed successfully. The executed matrix was:

```text
representativeHousehold                               SAT
sameRoleDifferentPressure                             SAT
liabilityWithoutRouteStillPressures                   SAT
unresolvedPositiveStaysVisible                        SAT

AllPositiveCoordinatesArePressure                     SAT counterexample
RoleAndPolarityAloneDetermineSelectedPressure          SAT counterexample
RolePolarityAndRoutingDetermineSelectedPressure        UNSAT counterexample
PositiveExpenseOrLiabilityAlwaysPressures              UNSAT counterexample
UnroutedPositiveAssetDoesNotPressure                   UNSAT counterexample
ExplicitlyRoutedPositiveAssetPressures                 UNSAT counterexample
ExplicitRouteResolvesMissingRoleIntoPressure           UNSAT counterexample
MissingRoleWithoutRouteRemainsUnresolved               UNSAT counterexample
MissingRoleIsResolvedNonPressure                       SAT counterexample
NegativeCoordinatesNeverPressure                       UNSAT counterexample
PressurePartitionsSelectedCoordinates                  UNSAT counterexample
PressureNonPressureUnresolvedPartition                 UNSAT counterexample
```

For Alloy `check`, `UNSAT counterexample` means no counterexample was found in the bounded scope.

Two failed intermediate receipts were useful rather than hidden. When `role` was changed from `one Role` to `lone Role`, Alloy's subset semantics made `none in Expense + Liability` true until the model explicitly required `some role`. The final model therefore records the same absence distinction that production `AccountingRoleMap` already owns.

## Qualified decision

Within this household scope, the selected production direction is:

```text
KEEP
  Scheduled lifecycle
  partial AccountingRole
  ScheduledRouting
  managed / unmanaged / unrouted pressure visibility
  unresolved role/eligibility visibility

DERIVE
  Capacity-pressure eligibility from
    polarity + partial AccountingRole + ScheduledRouting

DEFAULT PRESSURE
  positive Expense
  positive Liability

RESOLVED NON-PRESSURE
  positive Asset / Income / Equity with no route
  negative coordinates

EXPLICIT PRESSURE
  any positive coordinate carrying explicit ScheduledRouting

UNRESOLVED
  positive + no route + no AccountingRole

DO NOT ADD
  FixedCost Core type
  CommitmentEligibility authority
  retained Commitment state
  HRA Envelope / Fulfillment ontology
```

## Important boundary

This experiment does **not** establish:

- a Core `FixedCost` type;
- a retained Commitment or eligibility object;
- that every Liability movement is household spending in every possible domain;
- that every Asset routing is savings;
- recurrence or fixed-cost generation policy;
- Purpose assignment for currently unrouted rent, utilities, or debt;
- that HRA's Commitment implementation is LOAM's specification.

It establishes only that the current household Capacity-pressure distinction can be represented by evidence LOAM already owns in the selected bounded vocabulary, with missing AccountingRole retained as an unresolved frontier.

## Production gate

Production work remains separate from this Observation:

1. change `ScheduledCommitmentInspection` to select pressure using ScheduledRouting first and AccountingRole as the default classifier;
2. thread the already-existing partial AccountingRole evidence into the application read boundary;
3. preserve managed / unmanaged / unrouted pressure plus unresolved-role visibility;
4. add representative tests for Asset receipt, Liability repayment, Expense, routed Asset, missing-role/unrouted, and negative funding coordinates;
5. only then consider admitting household ScheduledRouting rows supported by explicit provenance.

No canonical routing rows should be guessed merely from labels such as `wifi`, `rent`, or `utilities`.
