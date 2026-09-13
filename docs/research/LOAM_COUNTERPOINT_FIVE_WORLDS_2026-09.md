# LOAM counterpoint: five small worlds

Status: broad semantic sketch, not a production proposal

Checkpoint main: `9c4989a9772f7da91a34ab9f6da0544c4f38209e`

This note follows `LOAM_COUNTERPOINT_EXPLORATION_2026-09.md`, the C1 realization note, and the broad C2-C5 sketchbook.

The goal is deliberately small: construct five worlds using current production meanings and listen to which existing projections move together, which stay fixed, and which become undefined. No generic `Projection`, `Impact`, `Variance`, or provenance framework is proposed.

## Shared notation

For one Purpose `P` and Measure `M`, current coverage derives:

```text
Remaining(P,M) = Entitlement(P,M) - Consumption(P,M)
Headroom(P,M)  = Remaining(P,M) - Commitment(P,M)
```

For a transition from evidence world `E0` to `E1`, write:

```text
ΔX = X(E1) - X(E0)
```

The important quantities below are *projection contributions*, not whole Event or Scheduled totals:

- `sP`: positive current-open Scheduled contribution classified as managed Commitment for `P/M`;
- `aP`: signed Actual contribution whose Locus routing at the Actual-valid coordinate selects `P/M`;
- `t(c)`: contribution of the current Event frontier to exact EffectCoordinate `c`;
- `anchor(c)`: asserted observed current quantity for `c` plus only roots not reflected by its cut.

Capacity is held fixed in Worlds 1-4 unless stated otherwise.

---

## World 1 — consonant realization

### Evidence before

- one current-open Scheduled occurrence contributes `q > 0` to Purpose `P`, Measure `M`;
- its Scheduled routing at `observedAt` is `.managed P`;
- no corresponding Actual Event exists yet;
- current `Consumption(P,M) = c`;
- current `Commitment(P,M) = k + q`.

### Transition

The Scheduled occurrence is completed into an Actual Event.

The Actual Event:

- has a valid coordinate inside the current elapsed window;
- contributes exactly `q` to `P/M` through Actual historical routing;
- introduces no Capacity change.

The effective Scheduled completion removes the source from the current-open set.

### After

```text
ΔCommitment  = -q
ΔConsumption = +q
ΔRemaining   = -q
ΔHeadroom    = (-q) - (-q) = 0
```

### Voices

| Voice | Result |
| --- | --- |
| Scheduled Commitment | decreases by `q` |
| Actual Consumption | increases by `q` |
| Headroom | unchanged |
| Transactions Flow | gains the Actual Event column if inside the queried window |
| Stock-Flow | changes only through the Actual contribution on its selected zero-origin coordinates |
| Current balance | changes according to the Actual EffectCoordinate contributions unless a later observation cut already reflects them |

### Meaning

This is the cleanest realization cadence: future pressure becomes recorded consumption without changing available headroom.

The invariant is earned only because the *Purpose/Measure contributions* match. Equality of whole Scheduled and Actual movement totals is neither necessary nor sufficient.

---

## World 2 — equal money, different interpretation

### Evidence before

As in World 1, one Scheduled occurrence contributes `q` to `P/M`.

### Transition

Completion creates an Actual Event with the same relevant quantity `q`, but Actual routing at the Event's valid coordinate selects a different Purpose `Q`.

```text
Scheduled contribution: P += q
Actual contribution:    Q += q
```

Assume `P ≠ Q` and no other contribution changes.

### After for P

```text
ΔCommitment(P)  = -q
ΔConsumption(P) =  0
ΔHeadroom(P)    = +q
```

### After for Q

```text
ΔCommitment(Q)  =  0
ΔConsumption(Q) = +q
ΔHeadroom(Q)    = -q
```

If both Purpose answers are defined and Entitlement is unchanged, the two headroom deltas cancel when considered together:

```text
ΔHeadroom(P) + ΔHeadroom(Q) = 0
```

but neither Purpose is individually invariant.

### Voices

| Voice | Result |
| --- | --- |
| Scheduled lifecycle | ordinary completion |
| Total realized amount | may equal expectation exactly |
| Purpose P | pressure is released |
| Purpose Q | consumption appears |
| Physical balance | depends only on Event Effects, not the Purpose disagreement |
| AccountingRole | remains independently determined by Locus role evidence |

### Meaning

"The money matched" does not imply "the expectation matched".

LOAM can distinguish realization of quantity from realization of interpretation because Scheduled routing and Actual routing are independent authorities at independent effective coordinates.

This is not a defect to repair by copying Scheduled routing into Actual. The disagreement may be the useful answer.

---

## World 3 — correction without a later current observation

### Evidence before

One current Actual root has terminal Event `A`.

For some projection voice `P`, let the current contribution of `A` be `x`.

No current-quantity anchor for the observed coordinate cuts this root out of later Event arithmetic.

### Transition

A correction retains `A`, appends replacement Event `B`, and retains `A -> B`.

Production correction publication preserves the current occurrence date of the target on `B`, while the replacement may carry different Effects and therefore different coordinates, routing outcomes, accounting roles, or quantities.

Let the replacement contribution to the same projection voice be `y`.

### Frontier change

The correction frontier removes targeted `A` and retains terminal `B`:

```text
ΔP = y - x
```

whenever the projection is a defined additive read of the same admitted frontier and the relevant classification conditions are unchanged.

### Voices

| Voice | Result |
| --- | --- |
| Transactions Flow | target column disappears from current selection; replacement contributes instead |
| Stock-Flow | selected-coordinate net changes by replacement minus target contribution when both reports remain defined |
| Purpose Consumption | changes by replacement-vs-target routed contributions at the retained validity coordinate |
| Zero-origin Balance | changes by coordinate delta on the correction frontier |
| Role Flow | may change differently when replacement Effects land on Loci with different roles |
| Capacity | unchanged by correction itself |

### Meaning

A correction is not "editing one number". It changes one shared Event frontier, and each independent projection hears the replacement through its own selection/classification rules.

The interesting object is not a stored `CorrectionImpact`; it is the vector of already-existing projection deltas.

---

## World 4 — correction after the present was observed

### Evidence before

There is an explicit current-quantity anchor for coordinate `c`.

Its assertion was observed after stable correction root `r` had already been reflected, so:

```text
r ∈ anchor.reflectedRoots
```

The anchor answer is:

```text
observed scalar at c
+ current terminal contributions from roots outside the reflected cut
```

### Transition

A later correction changes the terminal Event inside root `r`.

The raw/current Event explanation of the root changes. Transactions Flow, Purpose Consumption, Role Flow, or other correction-frontier projections may therefore change.

But current-anchor quantity at `c` does **not** replay the corrected root, because the whole stable root remains inside the reflected cut.

### Voices

| Voice | Result |
| --- | --- |
| Correction frontier | terminal Event changes |
| Transactions / Role / Purpose flow | may change |
| Historical explanation | changes |
| Current anchored quantity | unchanged by changes internal to reflected root `r` |
| New roots after the observation | still contribute normally as deltas |

### Meaning

This is stronger than an ordinary correction delta law:

> A later correction can change LOAM's explanation of the past without changing a current quantity that was independently observed after that past had already been physically reflected.

The apparent non-coherence is deliberate temporal independence, not contradiction.

A useful household phrasing, if this ever earns a surface, would be closer to:

```text
The history changed; the observed current balance did not.
```

rather than "correction had zero impact".

---

## World 5 — more retained evidence, less answerability

### Evidence before

Coordinate `c` has OpeningSupport naming Event `A` as its opening witness.

`A` is on the current correction frontier and contains `c`, so RoleBalance can validate the opening support and derive a current quantity through the ordinary correction-aware quantity path.

### Transition

A correction appends replacement `B` and relation `A -> B`.

The retained evidence set has grown:

- `A` still exists;
- `B` exists;
- the correction relation exists;
- the old OpeningSupport relation still names `A`.

But `A` is no longer on the current correction frontier.

### After

`RoleBalanceReview.validateOpeningSupport` requires the named opening witness to be one current Event. The old support therefore fails validation.

The result is not a different balance and not an implicit migration of support from `A` to `B`:

```text
previously answerable RoleBalance
        -> unavailable / refused
```

until independently justified support is supplied.

### Voices

| Voice | Result |
| --- | --- |
| Retained Event/correction evidence | strictly richer |
| Correction frontier | well-defined |
| Ordinary correction-aware quantities | may remain answerable |
| Opening-supported RoleBalance for c | becomes unavailable |
| Opening support | is not silently retargeted to B |

### Meaning

Naive evidence monotonicity is false:

```text
more retained facts ≠ more justified answers
```

What matters is **compatibility of evidence with the current projection domain**.

This is related to another current rule: adding a current anchor on a coordinate already supported by zero-origin or opening evidence is refused rather than treated as extra confidence, because precedence/equivalence between independent support families has not been qualified.

---

# The five-world score

Legend:

- `↑/↓` — quantity can move in the stated direction in the constructed world;
- `↔` — invariant under the stated transition;
- `Δ` — changes by replacement minus target contribution according to that projection's own selection;
- `?` — depends on independent routing/coordinate/support choices;
- `⊥` — answer becomes unavailable / undefined at that boundary.

| Voice | W1 exact realization | W2 route drift | W3 correction | W4 corrected reflected root | W5 corrected opening witness |
| --- | --- | --- | --- | --- | --- |
| Scheduled Commitment(P) | `↓q` | `↓q` | ↔ | ↔ | ↔ |
| Actual Consumption(P) | `↑q` | ↔ for P | `Δ` | `Δ` | `Δ` |
| Headroom(P) | ↔ | `↑q` | `-ΔConsumption` if other terms fixed | may change | may change |
| Transactions Flow | new Actual column | new Actual column | `Δ` | `Δ` | `Δ` |
| Purpose / Role interpretation | agrees | diverges | `Δ/?` | `Δ/?` | `Δ/?` |
| Zero-origin current balance | Actual delta | Actual delta | `Δ` | not an anchor case | ordinary frontier delta if independently supported |
| Current-anchor balance | n/a | n/a | n/a | **↔ for reflected root** | n/a |
| Opening-supported RoleBalance | n/a | n/a | may require witness to remain current | n/a | **⊥** |

The table is intentionally not a universal algebra. Some cells are partial because the corresponding production projection is partial.

# What these worlds reveal

The strongest common theme is not merely conservation.

LOAM currently retains enough independent meaning to distinguish at least three temporal/epistemic layers:

```text
expectation
    Scheduled + routing

recorded occurrence
    Actual + validity + correction frontier + interpretations

observed present
    current quantity anchor + reflected correction-root cut
```

A transition can move one layer without forcing the others to collapse into it.

World 1 shows **transfer**: expectation becomes occurrence while one derived resource quantity stays invariant.

World 2 shows **interpretive divergence**: quantity realization does not imply Purpose realization.

World 3 shows **shared-frontier propagation**: one correction is heard by many projections through their own selection rules.

World 4 shows **observational independence**: corrected history need not rewrite an independently observed present.

World 5 shows **partial answerability**: retaining more evidence can invalidate a previously admissible support relation without making the underlying world inconsistent.

This suggests that LOAM's latent "sound" may be less about producing unusual reports and more about making explicit how expectation, occurrence, interpretation, and observation remain related without becoming the same thing.

# Candidate research question after the broad pass

Do not yet build a generic abstraction. Instead ask a narrower question:

> For one stable household occurrence/root, which transitions are allowed to alter expectation, recorded occurrence, interpretation, and observed-present answers independently, and which cross-layer equalities are earned only under explicit compatibility conditions?

The five worlds suggest that this question subsumes the most interesting parts of C1, C3, and C4 without forcing C2/C5 into the same model.

# Next falsification probes

Before any production surface, theorem family, or framework is earned, falsify these claims with small executable/formal probes:

1. **W1 exact realization** — confirm equal Purpose/Measure contributions preserve Headroom through current production functions.
2. **W2 route drift** — confirm equal movement quantity can transfer Headroom delta from P to Q without changing the physical Event quantity.
3. **W3 correction delta** — find the smallest case where different projection classification makes two correction deltas legitimately unequal.
4. **W4 reflected-root stability** — reuse the current-anchor root-cut semantics and demonstrate that a changed terminal inside a reflected root does not change the anchor answer while an unreflected new root does.
5. **W5 opening invalidation** — demonstrate that correcting the named opening witness makes RoleBalance refuse the stale support rather than silently following the replacement.

Only after these probes should we decide whether the useful result is:

- one or two local Lean theorems;
- a bounded Alloy model of compatibility/answerability;
- a read-only derived explanation;
- or simply a design law that constrains future LOAM work.
