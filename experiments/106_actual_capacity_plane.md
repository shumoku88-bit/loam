# Observation 106: Can Actual and Capacity reuse signed Effects without becoming the same thing?

## Question

The household evidence graph exposes a cross-domain seam before LOAM implements more HRA / h-kernel capability.

Ordinary Actual recording is already compressed into balanced Movement:

```text
source -> target
```

with retained signed Effects.

HRA / h-kernel Envelope Entitlement uses a strikingly similar source shape:

```text
unallocated -> purpose
purpose -> purpose
purpose -> unallocated
```

Those endpoints are presented as grant, reallocation, and release, but the operation name is derived from endpoint shape.

The question is not whether both domains can be forced into one generic struct. It is narrower:

> Can Actual value movement and Capacity movement reuse one signed Effect algebra while still retaining enough evidence to keep physical holdings and spending authority semantically separate?

## Candidate compression

The bounded model keeps one intrinsic flow representation:

```text
Flow
  -> exactly two signed Effects
  -> one negative source Effect
  -> one positive target Effect
  -> exact zero sum
```

The Effect vector itself does not say whether it changes actual holdings or capacity.

A world supplies one explicit semantic plane per Flow:

```text
ActualPlane
CapacityPlane
```

This is an information distinction, not a persistence decision. An implementation could retain the distinction as a tag, a disjoint coordinate namespace, separate typed wrappers, or another information-equivalent representation.

## Why the plane is pressure, not decoration

The same signed Effect atoms and endpoint quantities exist in both bounded worlds. Only the plane assignment varies.

Therefore the model can ask whether an untyped Effect memory by itself determines:

```text
which Effects contribute to Actual holdings
which Effects contribute to Capacity / Entitlement
```

If changing only plane assignment changes those answers, then the plane carries independently observable information.

## Capacity endpoint meaning

Capacity flows are constrained to the purpose boundary:

```text
Unallocated -> Purpose = grant
Purpose -> Purpose     = reallocation
Purpose -> Unallocated = release
```

No operation-kind field is stored.

The model asks whether these three labels partition the admitted Capacity flows purely from source and target shape.

This mirrors current h-kernel reality pressure without importing its Envelope object graph or persistence format.

## Probes

### 1. Mixed Actual and Capacity evidence can coexist

One world contains:

- an Actual flow between Holding nodes;
- one Capacity grant;
- one Capacity reallocation;
- one Capacity release.

Expected: **SAT**.

### 2. The same signed Effects can support different household answers when plane changes

The Flow / Effect atoms and quantities are world-independent. A Flow can be Actual in one world and Capacity in the other.

Expected: **SAT**.

This is the direct pressure against erasing semantic plane.

### 3. Capacity operation labels can be derived from endpoints

Grant, reallocation, and release should all be witnessable without an operation-kind enum.

Expected: **SAT**.

## Checks

Expected results:

```text
UntypedEffectMemoryDeterminesPlaneSensitiveAnswers      SAT counterexample
ExplicitPlaneDeterminesSelectedAnswers                  UNSAT counterexample
CapacityOperationKindsPartitionCapacityFlows            UNSAT counterexample
PlaneSeparatesEffectOwnership                            UNSAT counterexample
```

The first assertion is deliberately false. The same untyped signed Effects should not determine whether they belong to Actual or Capacity.

The remaining assertions ask whether retaining the plane is sufficient for the selected bounded answers and whether capacity labels are derivable from endpoints.

## What a successful observation would mean

If the expected witnesses and checks hold, the useful compression is:

```text
shared signed Effect algebra
    yes

shared semantic meaning
    no

explicit Actual / Capacity distinction
    required

stored grant / reallocation / release kind
    not required for the admitted endpoint shapes
```

This would give LOAM a way to reuse the small Event / Effect machinery and possibly the movement interaction shape when Envelope capacity arrives, without allowing Entitlement transfers to change actual household holdings.

The result would not by itself earn a `Plane` type in Practical Core. The independently observable distinction could be represented in several ways.

## Important boundaries

Observation 106 does not establish:

- a practical Entitlement writer;
- a Capacity persistence stream;
- Purpose identity or registry semantics;
- historical routing;
- Consumption, Fulfillment, Commitment, Remaining, or Headroom;
- that Actual and Capacity should share one Event identity space;
- that Capacity uses the same Locus namespace as physical holdings;
- that `Unallocated` is a physical account or balance;
- non-negative cumulative Entitlement laws;
- stock-origin semantics;
- multi-Commodity capacity behavior beyond exact signed quantities;
- correction of Capacity movement;
- a generic semantic-plane framework.

Those questions remain separate pressure points.

## Next pressure if this survives

The whole-household map points next to historical routing:

> Can Actual Consumption routing and Scheduled Fulfillment / Commitment routing share one typed time-indexed relation shape without losing the subject distinction that later questions observe?

That question should remain separate from this algebra-reuse observation.
