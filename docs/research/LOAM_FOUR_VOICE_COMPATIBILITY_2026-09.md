# LOAM Four-Voice Compatibility Exercises

Date: 2026-09-14
Base checkpoint: PR #833 / `b9b69d9a6054d88d21bd3f59c856a96874643f1a`

## Why this exists

PR #833 established that LOAM already carries at least four independently moving semantic voices:

1. **Expectation** — Scheduled occurrence + Scheduled routing
2. **Occurrence** — Actual Event + validity + correction frontier
3. **Interpretation** — Purpose / AccountingRole relations
4. **Observed present** — current quantity anchor + reflected-root cut

The five-world probe showed that these voices may agree, diverge, or become undefined independently. The next task is not to add another report. It is to discover the exact compatibility conditions under which cross-voice statements are earned.

Do not introduce a generic `Projection`, `Impact`, provenance graph, or new canonical authority in this exercise.

## Working question

For one household occurrence/root, which agreements are sufficient to justify human claims such as:

- "realized as expected"
- "same amount, different purpose"
- "history corrected, current observation unchanged"
- "record and observation disagree"
- "this answer is no longer justified"

The objective is to find the smallest semantic conditions behind those claims.

## Candidate compatibility dimensions

Treat these as independent until evidence proves otherwise:

- **quantity compatibility** — expected and realized contribution agree in one Measure
- **purpose compatibility** — Scheduled and Actual contributions land in the same Purpose
- **time compatibility** — Scheduled horizon / Actual validity coordinates support the same comparison
- **physical compatibility** — relevant EffectCoordinate deltas agree with the claimed realization
- **present compatibility** — current derived quantity and later observed current quantity agree
- **support compatibility** — the evidence families needed by the answer are non-overlapping and current

No single dimension is assumed to dominate the others.

## First exercise set

### V1 — Exact realization

Hold quantity, Measure, Purpose, and relevant timing compatible.

Question:

> Is Headroom invariance the strongest earned claim, or can LOAM justify a narrower notion of `realized as expected` without importing new semantics?

Try to falsify with split Loci, unrelated coordinates, and correction history.

#### V1 result — `exact realization` was too strong a name

The executable probe `Loam/Tests/FourVoiceCompatibilityV1.lean` passed four counterexample worlds against current production semantics.

1. **Split physical shape still preserves local Headroom.** Scheduled pressure may be split across two Loci while the completed Actual contribution lands on a third Locus. If the selected Purpose/Measure contribution is equal, Headroom can remain unchanged even though the physical shape is not the same.
2. **Extra movement in another Purpose still preserves local Headroom.** The completed Actual may contain an additional physical movement routed to another Purpose. The queried Purpose can still preserve Headroom even though the whole Actual movement is not equal to the Scheduled movement.
3. **Raw quantity equality is insufficient when time coordinates disagree.** A completion can remove current-open Scheduled pressure while its equal Actual contribution lies after `observedAt`; Commitment disappears before elapsed Consumption appears, so current Headroom changes.
4. **Raw completion equality is insufficient after correction.** A Scheduled occurrence may complete into an Actual Event whose raw contribution matches exactly, yet a current correction replacement may change the correction-frontier contribution. Current Headroom follows the correction frontier, not the raw completion endpoint.

The earned arithmetic is query-local:

```text
Headroom = Entitlement - Consumption - Commitment
```

For a transition where Entitlement and all other selected contributions are stable:

```text
Headroom_after = Headroom_before
iff
removed managed Scheduled commitment contribution
  = added correction-frontier Actual consumption contribution
```

This does **not** justify whole-event equivalence or the broad human statement `realized as expected`.

The explicit Scheduled terminal relation already earns the narrower statement `realized` by linking one Scheduled identity to one Actual Event identity. Headroom invariance adds only a selected coverage fact. A safe descriptive wording is therefore closer to:

> this transition was coverage-neutral for Purpose P / Measure M at the queried coordinates

or, when the transition is isolated enough to attribute the deltas:

> equal Purpose/Measure pressure moved from open Commitment into elapsed Consumption

Do not retain either phrase as a new fact. They are descriptions of existing relations and projections.

The important negative result is that **physical compatibility, time compatibility, and current correction-frontier compatibility remain independent of Headroom invariance**.

### V2 — Same quantity, different interpretation

Hold quantity and Measure equal while Purpose differs.

Question:

> Which wording is justified by existing evidence: `same amount`, `realized`, `reclassified`, or only a conjunction of separate facts?

Do not create a retained classification-difference fact.

#### V2 result — `reclassified` is not earned by cross-voice divergence

The executable probe `Loam/Tests/FourVoiceCompatibilityV2.lean` passed three worlds using only current production semantics.

1. **Same physical Locus, same quantity, different Purpose.** The Scheduled occurrence and completed Actual may have the same positive quantity at the same physical Locus while Scheduled routing selects `food` and Actual routing selects `books`. Food Headroom rises by the released Commitment and books Headroom falls by the new Consumption. The completion relation remains valid.
2. **Aggregate Purpose deltas do not provide provenance correspondence.** A Scheduled occurrence can split 10 units to `food` and 20 to `books`, while the completed Actual contains one 30-unit coordinate routed to `books`. The resulting Headroom deltas are +10 for food and -10 for books, but no retained relation says which Scheduled coordinate maps onto which Actual Effect. The numerical transfer does not establish a 10-unit reclassification event.
3. **A comparable Actual Purpose may be absent entirely.** Completion and exact physical quantity can both hold while the Actual Locus is still `.unrouted`. The Scheduled side may have an explicit Purpose and the Actual side none. This is missing interpretation evidence, not evidence that classification changed.

The reason is structural:

```text
Scheduled routing subject = ScheduledId × LocusId
Actual routing subject    = LocusId
completion relation       = ScheduledId → Actual EventId
```

The completion relation connects occurrence identities. It does not retain a mapping between Scheduled routing assertions and Actual routing assertions, nor between Scheduled positive coordinates and Actual Effects.

Therefore the following claims have different support:

- **`realized`** — earned by the explicit Scheduled terminal relation when its target is an Actual Event;
- **`same amount`** — derivable only for an explicitly selected quantity comparison;
- **`different Purpose`** — derivable when both routing projections are defined and disagree;
- **`reclassified`** — generally too strong because it asserts a classification transition/provenance relation that current evidence need not contain.

Safer derived descriptions are compositional:

> this Scheduled occurrence realized as Actual; the selected expected contribution routed to food, while the selected Actual contribution routes to books

or, for an aggregate view:

> food pressure released by 10; books pressure increased by 10

The latter does not justify inferring that a particular 10 units were reclassified from food to books unless a future independent relation earns that correspondence.

No new canonical fact is needed for the useful observation. The disagreement is already visible by composing existing routing and completion evidence.

### V3 — Same interpretation, different quantity

Hold Purpose and Measure equal while realized quantity differs from expected quantity.

Candidate law:

```text
Headroom_after - Headroom_before
  = removed Scheduled commitment contribution
  - added Actual consumption contribution
```

Question:

> Does this remain exact under split Loci, corrections, and current routing history?

#### V3 result — quantity mismatch is an exact query-local residual

The executable probe `Loam/Tests/FourVoiceCompatibilityV3.lean` passed five worlds against current production semantics.

1. **Under-realization.** Scheduled managed Commitment 30 completed into correction-frontier Actual Consumption 27 for the same Purpose/Measure. Headroom moved from 70 to 73: the unmatched 3 units were released.
2. **Over-realization.** Scheduled Commitment 30 completed into Consumption 35. Headroom moved from 70 to 65: the excess 5 units consumed additional coverage.
3. **Split physical shape.** Scheduled 10 + 20 across two Loci completed into one 27-unit Actual coordinate. The physical shape differed, but the same +3 Headroom residual remained because the selected managed Commitment and Consumption contributions were still 30 and 27.
4. **Correction changes the realized contribution.** A Scheduled 30 completed into raw Actual 27, but the current correction replacement contributed 24. Current Headroom moved by +6, not +3. The law follows current correction-frontier Consumption rather than the raw completion target.
5. **Later routing does not rewrite valid-time interpretation.** An Actual valid at time 2 routed to `food` at time 2 even though the same Locus changed to `books` at time 3. The later routing assertion did not retroactively alter the earlier Consumption contribution, and the +3 residual remained.

For a fixed Purpose/Measure query context, with Entitlement and unrelated selected contributions unchanged, the observed law is:

```text
ΔHeadroom
  = removed managed Scheduled Commitment
  - added correction-frontier Actual Consumption
```

This is stronger than an informal expected-minus-actual comparison because both terms are already qualified by the current production semantics:

- the Scheduled term is current-open, horizon-selected, Measure-selected, positive, and managed to the queried Purpose;
- the Actual term is validity-selected, historical-routing-selected at each Event's valid coordinate, and correction-frontier-selected.

Therefore `expected 30 / actual 27 / difference 3` is only safe when those two values name these selected contributions. Raw Event quantity, current routing state, or whole-movement totals are not interchangeable substitutes.

Useful derived wording can remain narrow:

> this realization released 3 units of coverage for Purpose P / Measure M

or:

> this realization exceeded its previously managed pressure by 5 units

Neither wording needs retained comparison state. Both are arithmetic descriptions of existing projections under a stated query context.

### V4 — Corrected history versus observed present

Start from a current quantity anchor that reflects one stable correction root, then change the terminal Event behind that root.

Expected observation:

- ordinary correction-frontier history changes;
- the already observed current quantity remains invariant;
- a fresh observation may create a new anchor image without mutating the old semantic claim.

Question:

> What exact statement connects `history changed` and `present unchanged` without pretending the present was derived from the new history?

### V5 — Record versus observation disagreement

Construct a world where correction-aware derived current quantity after the anchor cut and an independent fresh observation disagree.

Question:

> Does current production already expose enough information to say `reconciliation required`, or would that wording smuggle in a new authority concept?

The important result may be only the existence of two independently justified quantities with distinct evidence coordinates.

### V6 — More evidence, fewer answers

Exercise stale OpeningSupport, overlapping support families, and any other current fail-closed evidence conflict.

Question:

> Can answerability be described as monotone only inside one compatibility domain, rather than globally over retained evidence?

This is the main falsification target for any future lattice interpretation.

## What to record for every world

For each world, record only:

1. retained evidence changed;
2. which voices changed;
3. which projections remain defined;
4. exact delta or equality when one is earned;
5. smallest counterexample to a tempting stronger statement;
6. whether the result needs any new canonical fact.

Prefer executable Lean probes using existing production functions. Use Alloy only when bounded combinatorial search would reveal compatibility conditions more efficiently than hand-written worlds.

## Stop conditions

Stop and reconsider if the exercise starts producing:

- a universal semantic wrapper around all projections;
- report-specific duplicate engines;
- retained `ExpectedVsActual`, `Impact`, `Compatibility`, or provenance state;
- a new authority merely to name a relation already derivable from current facts.

The desired result is a small set of discovered laws and counterexamples, not another subsystem.

## Current hypothesis

LOAM's latent expressive core may be the ability to keep **expectation, occurrence, interpretation, and observed present distinct long enough for their agreements and disagreements to become informative**.

V1 showed that realization plus local coverage invariance does not collapse physical shape, temporal membership, correction status, or unrelated interpretation into one notion of sameness.

V2 strengthened the same hypothesis from the interpretation side: even exact quantity and physical equality plus an explicit realization relation do not collapse Scheduled and Actual Purpose assertions into one classification history. Their disagreement is informative precisely because the two routing authorities remain distinct.

V3 adds the complementary positive law: once Purpose/Measure/query selection is fixed, quantity divergence becomes an exact residual without requiring whole-event identity. The residual is stable across split physical shape, but only after correction-frontier selection and valid-time routing have chosen the Actual contribution that is semantically current for the query.

The next observations should continue trying to break that hypothesis before promoting it into a design law.
