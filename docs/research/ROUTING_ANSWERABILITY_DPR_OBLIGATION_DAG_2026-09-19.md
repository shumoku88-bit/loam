# Actual / Scheduled Routing — D/P/R answerability audit

Status: **focused audit — routing algebra KEEP; Current Coverage answerability residual exposed**

Date: 2026-09-19

Baseline:

```text
8efadf5dc66b12fd4958b4a339c6ef0116571f61
docs(audit): recheck Scheduled generation with D/P/R (#1086)
```

Method: `docs/OBLIGATION_SCAFFOLD_METHOD.md`

## Root question

Do Actual and Scheduled routing use one coherent historical-routing algebra and
compatible time coordinates, and does Current Coverage make every routing
uncertainty that can change a household answer visible?

The root decomposes into:

```text
Routing
  |
  +--> O1 latest-visible selection is independent of storage order
  +--> O2 duplicate subject/effective coordinates fail closed
  +--> O3 Actual initial < every dated coordinate
  +--> O4 Actual Consumption reads routing at each Event's current valid date
  +--> O5 date correction may therefore re-route Consumption
  +--> O6 Scheduled pressure reads routing at observedAt
  +--> O7 Actual and Scheduled subject/time specializations remain distinct
  +--> O8 explicit unmanaged remains distinct from missing routing
  +--> O9 Current Coverage exposes every unresolved routing frontier that can
           change the displayed Purpose answer
```

## D — deterministic closure

### D1 — historical routing algebra

`RoutingHistory` owns:

- uniqueness of `(subject, effectiveOn)`;
- latest-visible selection on or before the query coordinate;
- the three-way result `managed | unmanaged | unrouted`;
- permutation-invariance of the selected result.

List order has no winner or temporal meaning.

No new routing theorem is justified here.

### D2 — Actual effective coordinate

Actual routing uses:

```text
RoutingEffective String
  = initial
  | dated YYYY-MM-DD
```

with `initial` a distinct least element.

Actual validity remains an ordinary date. The composition adapter
`eventConsumptionAtEffectiveRouting` explicitly queries routing at:

```text
dated(current Event validOn)
```

rather than fabricating a calendar date for `initial`.

### D3 — Actual date correction changes historical interpretation

Current Consumption first selects the current Event frontier, then the current
Actual-validity frontier, then selects routing at that valid coordinate.

Therefore a later validity correction may legitimately move one unchanged
physical Event across a routing change and alter its Purpose contribution.

This behavior is already pinned by the corrected-Actual Consumption
qualification and is not an accidental cross-family interaction.

### D4 — Scheduled routing coordinate

Scheduled routing uses the independently earned subject:

```text
ScheduledId × LocusId
```

and ordinary dated effective coordinates.

Current Scheduled pressure selects routing at `observedAt`, not at the future
Scheduled due date.

This is coherent with routing's meaning as historical administration evidence:
a future Scheduled occurrence may already be classified now.

### D5 — publication specializations

Actual and Scheduled writers share only `RoutingHistory.add?`.

Their remaining differences are independently meaningful:

```text
Actual
  subject = LocusId
  time = initial | dated
  missing routing authority may bootstrap empty

Scheduled
  subject = ScheduledId × LocusId
  time = dated
  Scheduled occurrence + Locus membership must resolve
  missing routing authority fails
```

No generic RoutingPublisher is earned.

## P — previously earned boundaries

This audit reuses rather than reopens:

- Observation 107/111 historical routing;
- Observation 156 `initial | dated` Actual routing;
- Observation 114 correction-aware valid-time Consumption;
- Observation 153 Scheduled routing subject granularity;
- Observation 227 Scheduled pressure classification;
- G2-018 routing append ownership;
- G2-008 Actual routing administration partition.

In particular:

```text
unmanaged
!=
unrouted
```

remains a semantic distinction.

`unmanaged` is explicit evidence.
`unrouted` means no visible routing assertion at the queried coordinate.

## R — residual

### R1 / production answerability — Actual unrouted evidence is not surfaced by Current Coverage

Current Coverage exposes a query-global Scheduled frontier:

```text
unmanaged future pressure
unrouted future pressure
unresolved future eligibility
```

but it exposes no analogous Actual-routing frontier.

Actual Consumption for one Purpose includes only Effects whose Locus has:

```text
routing.statusAt locus (dated Event.validOn)
  = managed thatPurpose
```

An unrouted Effect therefore contributes to no Purpose row.

This is correct for the narrow selected-Purpose projection, but the current
Cycle Budget presents the resulting row directly as:

```text
Spent
Now
Known future
After-known
```

without showing whether current-window Actual evidence remains unrouted.

### Deterministic witness

Hold fixed:

```text
Capacity(food) = 100

Actual Event @ 2026-09-08
  paypay        -30
  groceries     +30

AccountingRole(groceries) = Expense
Scheduled managed commitment = 0
```

World A:

```text
groceries routing at 2026-09-08 = unrouted
```

Then the existing Purpose projection can return:

```text
food Consumption = 0
food Remaining   = 100
food Headroom    = 100
```

World B differs only by adding:

```text
groceries INITIAL -> managed food
```

Then:

```text
food Consumption = 30
food Remaining   = 70
food Headroom    = 70
```

No Event, validity, Capacity, Scheduled, or quantity evidence changed.

Therefore missing Actual routing is independently capable of changing the
user-facing Current Coverage answer.

This is not a bug in `ConsumptionInspection`: that projection correctly answers
the routing evidence it was given.

The residual is that the higher read surface does not expose the condition under
which its Purpose answer is incomplete with respect to still-unrouted Actual
interpretation.

### Why this is not closed by ActualRoutingReview

`ActualRoutingReview` separately exposes currently admitted Expense Loci whose
current route is `unrouted`.

That is useful administration evidence, but it does not make the Cycle Budget
answer self-describing:

- it is a different read surface;
- it classifies current admitted Loci, not exact current-window Event
  contributions;
- Cycle Budget currently shows Scheduled uncertainty inline but not Actual
  routing uncertainty inline.

The production consumer therefore exists, unlike the Relation/Discharge
cross-family residual where no user-facing current-outstanding consumer existed.

### R subtype

This residual contains a deterministic fact and a policy choice.

Deterministically observable:

```text
there are current-window Actual Effect contributions whose Purpose interpretation
can still change because routing is unrouted
```

Policy not yet earned:

```text
which of those should count as an actionable Current Coverage frontier?
```

Questions that require an explicit decision include:

- Expense only, or also Liability?
- should missing AccountingRole form a second frontier?
- should negative Expense quantities/refunds be shown signed, separately, or only
  as rows?
- should Current Coverage continue to return numeric rows with a visible frontier,
  or fail closed until routing is complete?

## Smallest justified next experiment

Do **not** change Consumption arithmetic or routing authority.

The smallest next step is a read-only experiment that derives current-window
unrouted Actual coordinates from evidence already loaded by
`CurrentCoverageReview`:

```text
current Event frontier
+ current validity
+ current window
+ ActualRouting.statusAt at Event.validOn
+ AccountingRole
  ->
query-global Actual routing frontier
```

Prefer explicit rows first over a single aggregate amount, because rows avoid
premature policy about signed refunds, cross-Purpose allocation, and role
eligibility.

A candidate row may retain only enough evidence to inspect the unresolved
coordinate, for example:

```text
EventId
validOn
LocusId
MeasureId
Quantity
AccountingRole?
```

No new canonical fact is earned. This would be a derived review surface only.

## D/P/R result

```text
D
├─ latest-visible routing algebra
├─ duplicate-coordinate refusal
├─ Actual initial/dates ordering
├─ valid-time Actual Consumption
├─ observedAt Scheduled routing
└─ specialization-specific publication

P
├─ routing subject/time distinctions
├─ date-correction rerouting semantics
├─ Scheduled pressure classification
└─ unmanaged != unrouted

R
└─ production answerability:
     Cycle Budget exposes Scheduled routing frontiers
     but not Actual routing uncertainty that can change Purpose rows
```

## Verdict

```text
HistoricalRouting algebra                    KEEP
Actual RoutingEffective                      KEEP
Actual / Scheduled specializations           KEEP SEPARATE
generic RoutingPublisher                     DO NOT ADD
Consumption arithmetic                       KEEP
Scheduled observedAt routing                 KEEP
Current Coverage Actual-routing completeness REOPEN
```

**Routing itself does not need another abstraction. Current Coverage needs one
focused answerability experiment before its Purpose rows can be treated as fully
self-describing under incomplete Actual routing.**

## Stop point

Do not yet:

- fail all Current Coverage whenever any Locus is unrouted;
- infer Purpose from AccountingRole;
- route Expense automatically;
- make `unrouted` mean `unmanaged`;
- add a retained "routing complete" bit;
- sum all unresolved Actual quantities into one number without first qualifying
  signed/refund and role semantics;
- couple Actual routing publication atomically to Actual events.

The residual is a read-side visibility question, not a reason to enlarge
canonical routing state.


## Production closure follow-up — Observation 275

Observation 275 qualified the smallest read-side representation before any
Current Coverage policy change:

```text
current Event
+ current valid coordinate
+ historical Actual routing
+ AccountingRole?
  ->
explicit signed unrouted Actual rows
```

The row retains Event, valid coordinate, Locus, Measure, signed Quantity, and
optional AccountingRole. Machine-checked witnesses pin that:

- an unrouted balanced Event may contain both Asset and Expense rows;
- routing only the Expense Locus removes only that row;
- refund sign is preserved;
- missing AccountingRole remains unresolved.

Production Current Coverage now consumes that projection and exposes only the
default Actual-routing administration obligations:

```text
unrouted Expense rows
role-unresolved rows
```

Known non-Expense rows remain outside the default frontier, matching
`ActualRoutingReview` where Asset / Income / Liability / Equity routing is an
optional human choice rather than an automatic Purpose obligation.

Cycle Budget renders only row counts. It does not:

- aggregate unresolved Actual quantities;
- backdate routing;
- infer a Purpose;
- fail all Purpose rows;
- change canonical routing evidence.

A regression pins the temporal seam directly: a route effective after one
Actual occurrence must not rewrite that occurrence's historical Consumption,
while the still-unrouted Expense row becomes visible in the answerability
frontier.

Updated verdict:

```text
HistoricalRouting algebra        KEEP
Consumption arithmetic           KEEP
Actual routing administration    KEEP
Current Coverage visibility      QUALIFIED / PROMOTED
canonical state                  NO CHANGE
```
