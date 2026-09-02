# Practical Slice A2: Actual Locus Routing and Capacity Consumption

Slice A2 implements the first vertical practical slice derived from Observation 106 and Observation 111:

```text
Capacity evidence
    -> Entitlement projection

Actual Event / Effect
+ Actual-valid coordinate evidence
+ historical Locus routing
    -> Consumption projection

Remaining
    = Entitlement - Consumption
```

## Boundaries implemented

1. **Event structure remains date-free**:
   Observations 092–094 established that Event identity does not contain an inherent calendar/date field. Actual occurrence validity is therefore represented as separate typed evidence (`ActualValidity (Time : Type)` and `ActualValidityMemory (Time : Type)`), linking an `EventId` to a valid coordinate.

2. **Polymorphic linear order for time**:
   No calendar parser, timezone, or Gregorian date framework is introduced. Route selection requires only a minimal `LinearOrder Time` parameter for latest-visible selection.

3. **Shared Purpose coordinate without registry**:
   `PurposeId` is placed in `Loam.Core.Purpose`, shared cleanly by `Loam.Core.Capacity` and `Loam.Core.HistoricalRouting`. No Purpose registry is introduced.

4. **Three-way historical routing status**:
   `RoutingStatus` explicitly distinguishes:
   - `managed (purpose : PurposeId)`: latest visible route names a Purpose
   - `unmanaged`: latest visible route exists and names no Purpose (explicitly unmanaged)
   - `unrouted`: no visible routing evidence exists

5. **Fail-closed coordinate admission**:
   - `RoutingHistory.ofEntries?` rejects duplicate `(Subject, Time)` evidence. Storage order carries no semantic latest authority.
   - `ActualValidityMemory.ofEntries?` rejects duplicate `EventId` evidence.
   - `consumptionAtRecorded?` fails closed (`none`) if any remembered Event lacks valid coordinate evidence.

6. **Projections remain projections**:
   Neither Consumption nor Remaining is stored state. Quantities are projected on demand:
   - `consumptionAtRecorded?` sums signed Effect quantities of routed Loci as-is.
   - `remainingAtRecorded?` projects `Entitlement - Consumption`.
   - Effects in distinct Measures remain isolated and never mix.
   - Physical Event holdings are unaffected by Capacity movements.
