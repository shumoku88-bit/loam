# Observation 227 — Can Scheduled Capacity pressure be derived without a new eligibility fact?

Status: **QUALIFIED by Alloy 6.2.0 / SAT4J at exact head `c12493a26c78a231361b3f4be64878a6afed5cdf`; selected bounded rule uses AccountingRole + polarity + ScheduledRouting**

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

The smallest rule tested here is:

```text
negative coordinate
    -> not Capacity pressure

positive Expense or Liability
    -> Capacity pressure by default

positive Asset / Income / Equity
    -> not Capacity pressure by default

any positive coordinate with explicit ScheduledRouting
    -> Capacity pressure
```

Once a coordinate is selected as pressure, existing routing outcomes still partition it:

```text
managed route      -> managed pressure
unmanaged route    -> explicitly unmanaged pressure
no route           -> unrouted pressure
```

This gives the current household the intended distinctions without a new retained eligibility bit:

```text
wifi               Expense + managed route -> managed pressure
pension receipt    Asset + no route         -> not pressure
debt repayment     Liability + no route     -> unrouted pressure
planned savings    Asset + managed route    -> managed pressure
funding source     negative                 -> not pressure
```

## Why AccountingRole alone is not enough

Role and sign should not erase explicit intent.

Two positive Asset coordinates can have the same AccountingRole while differing in ScheduledRouting:

```text
ordinary incoming Asset + no route
planned savings Asset   + managed route
```

The former need not consume Capacity; the latter can explicitly do so.

The bounded result therefore rejects:

```text
AccountingRole + polarity alone determine pressure
```

while supporting the selected projection from:

```text
AccountingRole + polarity + routing status
```

## Executed Alloy result

Exact head:

```text
c12493a26c78a231361b3f4be64878a6afed5cdf
```

Workflow: `Observation 227`, run 2, Alloy 6.2.0 / SAT4J.

The expected-result checker completed successfully, so the executed matrix was exactly:

```text
representativeHousehold                               SAT
sameRoleDifferentPressure                             SAT
liabilityWithoutRouteStillPressures                   SAT

AllPositiveCoordinatesArePressure                     SAT counterexample
RoleAndPolarityAloneDetermineSelectedPressure          SAT counterexample
RolePolarityAndRoutingDetermineSelectedPressure        UNSAT counterexample
PositiveExpenseOrLiabilityAlwaysPressures              UNSAT counterexample
UnroutedPositiveAssetDoesNotPressure                   UNSAT counterexample
ExplicitlyRoutedPositiveAssetPressures                 UNSAT counterexample
NegativeCoordinatesNeverPressure                       UNSAT counterexample
PressurePartitionsSelectedCoordinates                  UNSAT counterexample
```

For Alloy `check`, `UNSAT counterexample` means no counterexample was found in the bounded scope.

The important discriminations are:

1. the old all-positive rule is too broad because a positive Asset can be Scheduled without exerting Capacity pressure;
2. AccountingRole and sign alone are too small because explicit routing can make an otherwise non-default Asset coordinate pressure-bearing;
3. positive Expense and Liability coordinates remain visible as pressure even without a route, so currently unrouted rent, utilities, and debt repayment do not disappear;
4. adding the existing ScheduledRouting status to AccountingRole and polarity is sufficient for the selected bounded pressure projection;
5. no separately retained eligibility bit is required by this selected view.

## Qualified decision

Within this household scope, the selected production direction is:

```text
KEEP
  Scheduled lifecycle
  AccountingRole
  ScheduledRouting
  managed / unmanaged / unrouted pressure visibility

DERIVE
  Capacity-pressure eligibility from
    polarity + AccountingRole + ScheduledRouting

DEFAULT PRESSURE
  positive Expense
  positive Liability

DEFAULT NON-PRESSURE
  positive Asset
  positive Income
  positive Equity
  negative coordinates

ALLOW EXPLICIT OVERRIDE INTO PRESSURE
  any positive coordinate carrying explicit ScheduledRouting

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

It establishes only that the current household Capacity-pressure distinction can be represented by evidence LOAM already owns in the selected bounded vocabulary.

## Production gate

Production work remains separate from this Observation:

1. change `ScheduledCommitmentInspection` to admit only selected pressure coordinates;
2. thread the already-existing AccountingRole evidence into the application read boundary;
3. preserve managed / unmanaged / unrouted visibility for selected pressure;
4. add representative tests for Asset receipt, Liability repayment, Expense, routed Asset, and negative funding coordinates;
5. only then consider admitting household ScheduledRouting rows supported by explicit provenance.

No canonical routing rows should be guessed merely from labels such as `wifi`, `rent`, or `utilities`.
