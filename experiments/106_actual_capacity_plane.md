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

Observed: **SAT**.

### 2. The same signed Effects can support different household answers when plane changes

The Flow / Effect atoms and quantities are world-independent. A Flow can be Actual in one world and Capacity in the other.

Observed: **SAT**.

This is the direct pressure against erasing semantic plane.

### 3. Capacity operation labels can be derived from endpoints

Grant, reallocation, and release are all witnessable without an operation-kind enum.

Observed: **SAT**.

## Executed result

Alloy 6.2.0 + Sat4j, with exactly 4 Flows / 8 Effects / 2 Purposes / 2 Holdings / 2 Worlds and 6-bit Ints:

```text
representativeMixedPlanes                              SAT
sameSignedEffectsDifferentPlaneSensitiveAnswers        SAT
capacityLabelsComeFromEndpoints                        SAT
UntypedEffectMemoryDeterminesPlaneSensitiveAnswers     SAT counterexample
ExplicitPlaneDeterminesSelectedAnswers                 UNSAT counterexample
CapacityOperationKindsPartitionCapacityFlows           UNSAT counterexample
PlaneSeparatesEffectOwnership                           UNSAT counterexample
```

The complete expected result set passed in CI.

The first execution attempt was blocked before solving because `releases` is an Alloy 6 temporal keyword. Renaming the helper to `capacityReleases` changed no model meaning. A second small syntactic clarification parenthesized the signed sum expression. The final exact-head run executed the model and expectation check successfully.

## Finding

Within the bounded vocabulary, the same signed Flow / Effect representation can serve both Actual and Capacity evidence, but the semantic plane is independently observable.

Keeping Flow and Effect atoms fixed while changing only `planeOf` can change which Effects contribute to Actual holdings and which contribute to Capacity. Therefore an untyped Effect memory is too small for these household questions.

At the same time, once `planeOf` is fixed, Alloy found no counterexample where the selected Actual/Capacity answers or capacity endpoint labels differ.

The useful compression is:

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

So LOAM may be able to reuse the small Event / Effect arithmetic and movement interaction shape when Envelope capacity arrives without allowing Entitlement movement to alter physical household holdings.

The independently observable distinction does not itself earn a Practical Core `Plane` type. A tag, disjoint namespace, typed wrapper, separate authority stream, or another information-equivalent representation could preserve it.

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

## Next pressure

The whole-household map points next to historical routing:

> Can Actual Consumption routing and Scheduled Fulfillment / Commitment routing share one typed time-indexed relation shape without losing the subject distinction that later questions observe?

That question should remain separate from this algebra-reuse observation.

## Practical realization in Practical Slice A1

Practical Slice A1 realized this boundary in `main`:
- `CapacityCoordinate` (`PurposeId` or `unallocated`) is explicitly separated from physical `LocusId`.
- `Loam.Core.Capacity` (`CapacityMovement`, `CapacityCoordinate`) and `Loam.Core.BalancedMovement` implement the typed capacity boundary without altering physical holdings.
- `Entitlement` is a pure projection over capacity movements (`Loam.Application.CapacityInspection`).

See `experiments/106_practical_slice_a1.md` for details.
