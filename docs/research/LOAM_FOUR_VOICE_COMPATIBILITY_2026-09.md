# LOAM Four-Voice Compatibility Checkpoint

Date: 2026-09-14
Base checkpoint: PR #833 / `b9b69d9a6054d88d21bd3f59c856a96874643f1a`

## Question

PR #833 suggested that LOAM already retains several independently useful semantic voices whose agreements and disagreements may be more expressive than another report family.

The working voices were:

1. **Expectation** — Scheduled occurrence + Scheduled routing
2. **Occurrence** — Actual Event + validity + correction frontier
3. **Interpretation** — Purpose / AccountingRole relations
4. **Observed present** — CurrentQuantityAnchor + reflected-root cut

The experiment asked:

> Which cross-voice statements are actually justified by current production semantics, and which tempting human descriptions assert more than LOAM retains?

No generic `Projection`, `Impact`, `Compatibility`, provenance graph, or retained expected-vs-actual state was introduced.

## Result in one sentence

LOAM's useful expressiveness comes from **keeping independently justified voices distinct long enough that local agreement, disagreement, residual, invalidation, and re-observation can be derived without collapsing them into one stored status**.

The executable probes are:

- `Loam/Tests/FourVoiceCompatibilityV1.lean`
- `Loam/Tests/FourVoiceCompatibilityV2.lean`
- `Loam/Tests/FourVoiceCompatibilityV3.lean`
- `Loam/Tests/FourVoiceCompatibilityV4.lean`
- `Loam/Tests/FourVoiceCompatibilityV5.lean`
- `Loam/Tests/FourVoiceCompatibilityV6.lean`

All run through the existing Practical Slice B workflow.

---

## V1 — Headroom invariance is query-local

The name `exact realization` was too strong.

Headroom is:

```text
Headroom = Entitlement - Consumption - Commitment
```

For an isolated realization transition with Entitlement and unrelated selected contributions stable:

```text
Headroom_after = Headroom_before
iff
removed managed Scheduled Commitment
  = added correction-frontier Actual Consumption
```

The probe showed that Headroom can remain unchanged even when:

- Scheduled pressure is split across different Loci from Actual;
- the completed Actual contains extra movement in another Purpose;
- whole-event physical shape differs.

Conversely, raw Scheduled/Actual quantity equality is not enough when:

- Actual validity lies outside the queried elapsed window;
- correction changes the current realized contribution.

Therefore Headroom invariance earns only a selected coverage statement such as:

> equal Purpose/Measure pressure moved from open Commitment into elapsed Consumption

It does **not** earn whole-event equality or `realized as expected`.

---

## V2 — Purpose divergence is not automatically reclassification

Scheduled and Actual interpretation remain independent:

```text
Scheduled routing subject = ScheduledId × LocusId
Actual routing subject    = LocusId
completion relation       = ScheduledId → Actual EventId
```

The probe showed that:

- same Locus + same quantity + explicit completion can still route to different Purposes;
- aggregate Purpose deltas can look like `+10 / -10` without any retained correspondence saying which 10 units moved;
- Actual may remain unrouted, so there may be no comparable Actual Purpose at all.

Thus:

- `realized` may be justified;
- `same amount` may be derived for one selected comparison;
- `different Purpose` may be derived when both routings are defined;
- `reclassified` is generally too strong because it asserts a provenance transition LOAM need not retain.

The useful disagreement requires no new canonical fact.

---

## V3 — Quantity divergence is an exact selected residual

Once Purpose, Measure, time window, lifecycle selection, correction frontier, and valid-time routing are fixed, quantity difference becomes precise:

```text
ΔHeadroom
  = removed managed Scheduled Commitment
  - added correction-frontier Actual Consumption
```

The probe covered:

- `30 → 27` yielding `+3` Headroom;
- `30 → 35` yielding `-5` Headroom;
- split Scheduled physical shape preserving the same residual;
- correction changing raw Actual `27` to current contribution `24`, producing `+6` rather than `+3`;
- later routing changes not rewriting an earlier Actual's valid-time Purpose.

Therefore a narrow derived statement such as:

> this realization released 3 units of coverage for Purpose P / Measure M

is justified without retaining a `Variance` object.

---

## V4 — Observed present is a cut, not a replay of history

CurrentQuantityAnchor does not mean either:

- `the present is independent of history`, or
- `the present is always recomputed from all history`.

Its effective rule is:

```text
anchored current quantity
  = asserted observed quantity
  + current terminal quantities of roots outside reflectedRoots
```

The probe showed five boundaries:

1. changing the terminal Event inside an already reflected stable root changes ordinary correction-frontier history but leaves the observed present unchanged;
2. correcting a root outside the cut changes the anchored current quantity;
3. a wholly new root after observation is also a genuine delta;
4. if later evidence changes stable-root identity itself, the old anchor fails closed rather than silently migrating its cut;
5. a fresh observation creates a new complete cut rather than revising the old anchor into a historical version.

The useful interpretation is:

> the observation separates history already reflected by the observed quantity from history not yet reflected by it.

No anchor revision graph is required.

---

## V5 — Disagreement is observable; reconciliation authority is not implied

A prior observed-present projection and a fresh observation can disagree exactly:

```text
prior implied current = -60
fresh observation     = -55
residual              =  +5
```

The residual is derivable from existing evidence.

But the probe also showed that:

- exact agreement is just residual `0`; no retained agreement/disagreement status is needed;
- the same `+5` residual can arise from different correction/history decompositions;
- RoleBalance can faithfully consume either complete anchor image without deciding which observation wins.

Therefore the strongest earned statement is numerical and evidential:

> the fresh observation differs by 5 units from the quantity implied by the prior observation plus roots outside its reflected cut.

The following are **not** implied by current evidence:

- `reconciliation required`;
- `the record is wrong`;
- `the observation is authoritative`;
- `insert an adjustment of 5`.

Those would add workflow or policy authority.

---

## V6 — Answerability is not monotone under raw evidence inclusion

The naive hypothesis

```text
more retained evidence
  => at least as many justified answers
```

is false.

The executable probe established:

1. **Compatible support can add an answer.** A role-known but unsupported coordinate becomes answerable when explicit OpeningSupport is added.
2. **A stale witness can remove an answer.** Adding a valid correction may supersede the Event named by OpeningSupport; the old current-balance answer then becomes unavailable.
3. **Explicit re-support can restore the answer.** Naming the current replacement as a new opening witness restores answerability. Correction alone does not migrate the support relation.
4. **Overlapping independent support is not "more support".** OpeningSupport plus CurrentQuantityAnchor on the same coordinate fails closed; the CurrentQuantityAnchor publisher refuses to create that overlap as well.
5. **More raw correction facts can remove all current answers.** A branching correction relation is retainable raw evidence but does not justify one current frontier, so RoleBalance refuses the projection.
6. **Zero-origin and OpeningSupport overlap now fails closed too.** V6 exposed a small implementation seam: RoleBalance's module contract already said support families were non-overlapping, but the reader previously selected zero-origin first for this pair. The boundary was tightened to match the declared semantics instead of inventing precedence.

The household canonical data did not contain this overlap when checked: OpeningSupport names `debt-friend-k / jpy`, while zero-origin coverage names a disjoint set of coordinates.

### Consequence for information-order ideas

Raw retained-evidence set inclusion is **not** an information order for LOAM answerability.

A future lattice or abstract-interpretation model must not assume:

```text
E₀ ⊆ E₁  =>  Answers(E₀) ⊆ Answers(E₁)
```

because new evidence may:

- invalidate a witness;
- create competing support;
- make frontier topology unresolved;
- change the premises under which an earlier claim was justified.

A more promising order, if one is useful at all, would need to be **claim-relative and compatibility-aware**, not raw-evidence inclusion.

---

## Cross-exercise synthesis

V1–V6 reveal one recurring shape.

### 1. Compatibility is local to a claim

There is no single global `compatible / incompatible` state.

A world can be:

- quantity-compatible;
- Purpose-incompatible;
- time-incompatible;
- physical-shape-different;
- observed-present-compatible;
- support-incompatible;

all at once.

The correct question is always:

> compatible **for which claim, at which coordinates, under which evidence premises?**

### 2. Agreement does not collapse identity

Equal Headroom, equal quantity, or equal Purpose contribution never proves that two Events, routings, or observations are the same semantic thing.

Agreement is a derived relation between selected projections, not a reason to merge the underlying voices.

### 3. Disagreement is useful precisely because the voices remain independent

LOAM can say, without new retained comparison state:

- realization occurred, but Purpose differs;
- realization occurred, but quantity left a residual;
- historical explanation changed, but an already observed present did not;
- prior implied present and fresh observation differ by an exact amount;
- a formerly justified answer is no longer justified.

If these voices had been collapsed earlier, those statements would disappear.

### 4. Fail-closed behavior is semantic, not merely defensive

When support overlaps, a witness becomes stale, or correction topology has no unique frontier, refusing an answer preserves the distinction between:

- retained facts;
- justified current interpretation;
- unresolved policy/authority.

The refusal itself is informative.

### 5. Useful statements remain derived

None of V1–V6 earned a new canonical object such as:

- `ExpectedVsActual`;
- `Variance`;
- `Reclassification`;
- `ReconciliationStatus`;
- `Impact`;
- generic `Compatibility`.

The useful answers arise by composing existing facts at query time.

---

## Candidate design law

The strongest law currently supported by the exercises is:

> **Retain independently justified evidence without prematurely collapsing it. Derive cross-voice claims only when the exact compatibility premises required by that claim are satisfied. When those premises become ambiguous, stale, overlapping, or structurally unresolved, retract the claim rather than invent precedence.**

This is stronger and more precise than "more evidence is better" or "everything is eventually reconciled."

It also matches the desired generative economy:

```text
small retained distinctions
    + explicit relations
    + claim-local compatibility checks
    -> many useful household statements
```

without retaining those statements as a second semantic layer.

## What this says about LOAM's latent sound

The main latent capability discovered here is not another numeric report.

It is the ability to let **expectation, occurrence, interpretation, and observed present form independent voices**, then make their agreements and disagreements answer household questions without erasing the distinctions that made those answers possible.

In that sense, the interesting behavior lies in the intervals between the voices rather than in any one voice alone.

## Stop condition reached

The first compatibility exercise set is complete enough to stop expanding it.

Before adding another framework, the next decision should be whether any one of these derived relations deserves a small read-only product surface, or whether the research result itself is the useful outcome.
