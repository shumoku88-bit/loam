# Semantic audit SA-003 — temporal / effective evidence

Status: **AUDIT VERDICT COMPLETE — current semantic distinctions retained**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `b110f6cd21dafd94d05826fc6ad1957d962e5510`

This record asks whether LOAM has accumulated too many independent-looking time/effective concepts, and whether any can be derived, merged, or represented by one generic temporal ontology.

The current family under review is:

```text
ActualValidity / ActualValidityHistory
CapacityEffective
HistoricalRouting
RoutingEffective
ScheduledRouting specialization
```

The target is not to remove names merely because all of them mention time. The target is to distinguish retained information from reusable ordering/selection mechanics.

## 1. Current information shapes

The current temporal surface contains several different structures.

### Actual occurrence validity

```text
EventId -> occurrence-valid coordinate
```

`ActualValidity` is separate typed evidence rather than a field embedded in `Event`.

Current raw provenance is `ActualValidityHistory`: one Event-rooted base date plus identified later revisions and explicit correction relations. `ActualValidityMemory` is the admitted current one-date-per-Event projection consumed downstream.

### Capacity effective coordinate

```text
CapacityMovementId -> effective coordinate
```

`CapacityEffectiveMemory` is independent retained effective evidence for Capacity movement timing. There is currently no separate Capacity-effective revision history.

### Historical routing

```text
(subject, effective coordinate) -> Purpose?
```

`RoutingHistory Subject Time` is already a generic algebra. It permits several assertions for one subject at different coordinates and derives the latest visible assertion by coordinate order, never list order.

### Routing-specific initial coordinate

```text
RoutingEffective Time
  = initial
  | dated Time
```

`initial` is a real routing distinction: effective before every dated coordinate. It is not a fabricated earliest date.

## 2. Existing formal evidence already establishes semantic independence

### ActualValidity cannot be derived from Event

Observations 092–094 did not earn a built-in Event time field. Observation 111 later found that the occurrence-valid coordinate is independently observable for historical routing and Consumption.

A representative counterexample shape is:

```text
same physical Event
same routing history with a route change
validity at t1 vs validity at t2
=> different historical routed Consumption
```

Therefore Event content alone does not determine Actual validity.

Decision: `ActualValidity` meaning is `KEEP`.

### CapacityEffective cannot be derived from CapacityMovement

Observation 112 found effective time independently observable for historical Capacity admission questions, and Observation 158 later uses effective coordinates for windowed household projections.

Representative shape:

```text
same CapacityMovement
same query window
movement effective inside vs outside the window
=> different Entitlement / Capacity answer
```

Therefore movement algebra alone does not determine Capacity effective time.

Decision: `CapacityEffective` meaning is `KEEP`.

### Routing initial cannot be replaced by an ordinary date

Observation 156 qualified a distinction between:

```text
assertion effective before every dated coordinate
vs
assertion effective from the earliest represented ordinary date
```

A fabricated date collapses those worlds and changes queries before the first ordinary date.

Decision: the `initial | dated` distinction is `KEEP_WRAPPER` / `KEEP_MEANING`.

No new Alloy experiments are necessary for these three deletion questions; the relevant counterexamples already exist and remain aligned with current production semantics.

## 3. Important authority asymmetry: ActualValidityMemory vs CapacityEffectiveMemory

`ActualValidityMemory Time` and `CapacityEffectiveMemory Time` are structurally similar finite functions:

```text
subject identity -> Time
unique subject key
lookup independent of representation order
```

However their architectural status is not the same.

### ActualValidityMemory

Current raw authority is `ActualValidityHistory`.

`ActualValidityMemory` is a **derived current view** produced only after Application frontier admission of append-only base/revision/correction provenance.

### CapacityEffectiveMemory

`CapacityEffectiveMemory` is itself the currently retained effective-coordinate evidence used by persistence/application code.

There is no current Capacity-effective correction history analogous to ActualValidityHistory.

### Consequence

A generic `TemporalMap Subject Time` would hide an important distinction:

```text
current projection of revision history
vs
retained effective evidence authority
```

Structural isomorphism is therefore not evidence for semantic or authority unification.

## 4. Repeated finite-function mechanics are already shared at the right level

Both `ActualValidityMemory` and `CapacityEffectiveMemory` use `FiniteKeyed.findBy?` and its permutation-independence theorem.

They still each spell a small domain-specific `ofEntries?` constructor and typed lookup wrapper.

A hypothetical generic carrier such as:

```text
TemporalAttachment Subject Time
TemporalMap Subject Time
EffectiveEvidence Subject Time
```

would need semantic wrappers anyway to preserve:

- Event validity meaning;
- Capacity movement effective meaning;
- authority ownership;
- persistence naming;
- correction-history status;
- domain-specific caller signatures.

With only these two one-coordinate attachment families, the adapter/type cost is likely greater than the duplicated `Nodup` constructor code.

Decision: keep semantic wrappers; continue sharing only finite-key lookup mechanics through `FiniteKeyed`.

Reopen if a third live family repeats the exact same one-subject-one-coordinate representation and wrapper overhead can be shown net-negative.

## 5. HistoricalRouting is already the successful genericization

Actual and Scheduled routing both reuse:

```text
RoutingEntry Subject Time
RoutingHistory Subject Time
RoutingStatus
latest-visible selection
coordinate uniqueness
permutation independence
```

while specializing different subjects and effective-coordinate types.

This is exactly the desired architecture:

> share temporal selection mathematics; keep semantic subjects and evidence owners distinct.

`HistoricalRouting` is therefore a positive control analogous to `BalancedMovement`, `FiniteKeyed`, and `ReplacementFrontier`.

Decision: `KEEP`.

Do not add a second generic temporal-history framework.

## 6. Actual and Scheduled routing are intentionally different specializations

Current Actual routing uses:

```text
RoutingHistory LocusId (RoutingEffective String)
```

because real household pressure earned an explicit pre-dated `initial` route.

Current Scheduled routing uses:

```text
RoutingHistory ScheduledRoutingSubject Time
```

where `ScheduledRoutingSubject = ScheduledId × LocusId` was separately earned so distinct Scheduled intent is not collapsed by bare Locus identity.

The shared algebra is already the same. The differing subject/effective types are semantic parameters, not duplicate engines.

Do not force Scheduled routing to gain `RoutingEffective` merely for type symmetry, and do not erase Actual `initial` merely so both instantiations look alike.

## 7. RoutingEffective representation audit

`RoutingEffective` is information-isomorphic to several generic encodings, for example an optional/bottom-extended time:

```text
none / bottom -> initial
some t        -> dated t
```

Information isomorphism alone does not justify replacement.

The current type carries useful constraints:

- the meaning is routing-specific rather than a global time ontology;
- constructors read as `initial` / `dated` at callers and persistence boundaries;
- the linear-order instance explicitly proves `initial` is below all dates;
- no other current semantic family needs the same bottom-extended coordinate type.

Replacing it with a generic bottom/option representation would either lose the semantic name or require a wrapper/alias that preserves nearly the same surface.

Decision: `KEEP_WRAPPER`.

Reopen only if another live domain earns exactly the same pre-dated coordinate algebra or a standard already-used dependency yields a clear net proof/source reduction without leaking generic bottom semantics into household code.

## 8. Revision mechanics must not be generalized from ActualValidity alone

ActualValidity currently has append-only base/revision/correction provenance because date correction is a real supported operation.

CapacityEffective currently does not.

Do not create a generic `TemporalRevision`, `EffectiveHistory`, or `CorrectableTimeEvidence` framework merely because Capacity timing might someday be corrected.

The revision abstraction should be earned by another live revision-bearing domain with the same law, not by anticipated symmetry.

## 9. What is primitive vs representation

The audit distinguishes semantic information from convenient types:

### Independent retained semantic information

```text
Actual occurrence-valid coordinate
Capacity movement effective coordinate
historical routing assertions
routing pre-dated initial-vs-dated distinction where used
```

### Shared mathematics / representation

```text
FiniteKeyed lookup mechanics
RoutingHistory latest-visible algebra
RoutingEffective ordered sum representation
ActualValidityMemory current-view representation
```

This prevents physical type/module count from being mistaken for the number of independent household facts.

## 10. Rejected simplifications

Current evidence rejects or does not justify:

```text
NO date field moved into Event merely to remove ActualValidity
NO effective date moved into CapacityMovement merely to remove CapacityEffective
NO generic TemporalMap / TimeEvidence household ontology
NO generic temporal revision framework
NO fabricated earliest date in place of routing `initial`
NO forcing Actual and Scheduled routing to use identical subject/effective types
NO second historical-routing algebra
```

## 11. Formal-method verdict

Existing Alloy/observation work already provides the needed counterexamples for semantic deletion:

```text
ActualValidity independent of Event
CapacityEffective independent of CapacityMovement
initial routing coordinate not equivalent to earliest dated coordinate
```

Existing Lean code already provides the positive shared-mechanics proofs:

```text
FiniteKeyed lookup permutation independence
RoutingHistory latest-visible permutation independence
RoutingEffective linear-order laws
```

No new formal artifact is currently needed because no unresolved semantic merge hypothesis survived the census.

If a future refactor proposes a generic one-coordinate attachment carrier, use Lean representation isomorphisms and caller-level observational equivalence rather than Alloy: that would be a pure representation refactor, not a semantic state-space merge.

## 12. SA-003 verdict

### Keep semantic evidence

```text
ActualValidity / ActualValidityHistory
CapacityEffective
HistoricalRouting evidence
RoutingEffective initial-vs-dated meaning
```

### Already shared correctly

```text
FiniteKeyed for finite keyed lookup
RoutingHistory for historical latest-visible selection
```

### Keep as wrappers / derived representations, not count as new household primitives

```text
ActualValidityMemory
RoutingEffective representation type
ScheduledRoutingHistory specialization
```

### Not earned

```text
NO TemporalMap
NO TimeEvidence supertype
NO generic EffectiveHistory
NO generic temporal revision ontology
```

### Implementation state

No production refactor is recommended directly from SA-003 at this checkpoint.

This is another useful negative result: the apparent temporal multiplicity mostly reflects independently observable evidence plus already-factored mathematics, not accidental duplicated domain concepts.

Next ledger step: SA-008 Scheduled semantic amplification, followed by SA-005 Core public surface.