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

### V2 — Same quantity, different interpretation

Hold quantity and Measure equal while Purpose differs.

Expected observation:

- realization relation remains valid;
- Purpose-local Headroom does not remain invariant;
- equal and opposite Purpose deltas may appear across the compared Purposes.

Question:

> Which wording is justified by existing evidence: `same amount`, `realized`, `reclassified`, or only a conjunction of separate facts?

Do not create a retained classification-difference fact.

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

The next observations should try to break that hypothesis before promoting it into a design law.
