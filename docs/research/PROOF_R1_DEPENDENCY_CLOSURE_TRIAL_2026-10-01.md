# Proof-R1-inspired dependency-closure distillation trial

Status: **BOUNDED REPOSITORY DISTILLATION EXPERIMENT**

Date: **2026-10-01**

External trigger: *Learning to Prove, Not Just to Answer: Reinforcement Learning
from Formal Verification for Natural-Language Logical Reasoning* (Proof-R1,
arXiv:2609.37203).

## Question

Can LOAM strengthen its existing research-graduation rule from:

> the experiment is verified and historically useful

to the narrower review question:

> is the executable artifact still inside the dependency closure of a current
> production, durable-proof, or active-research claim?

This trial deliberately does not add a framework or a new CI obligation.

## Scope

Only the future-context retention thread is inspected.

The later live research arc includes:

```text
Observation 299
  bounded SearchSpace / continuation enumeration
        |
        v
Observation 308
  bounded behavioural signatures
        |
        +--> 309 / 310 / 311
        |
        +--> 313
        |
        v
314 -> 315 -> 316 -> 317
  finite bases / characterization / minimality / finite quotient
```

The positive/exact-classification side also retains:

```text
192 -> 297 -> 298 -> 304 -> 305 -> 306 -> 307
```

Observation 308 joins the 299 and 307 lines.

## Closure finding

Four live modules were leaves with respect to the later synthesis and
classification results:

- Observation 300: bounded search against Correction semantics;
- Observation 301: bounded search against document provenance;
- Observation 302: bounded search against ActualReversal provenance;
- Observation 303: summary-collision filtering fixture.

Repository search found no current Lean consumer for those modules other than
the broad `Loam.Observations` umbrella. Their experimental findings are already
summarized in `docs/research/FUTURE_CONTEXT_RETENTION_CHECKPOINT_2026-09-23.md`.

Observation 299 is different. It remains a live dependency of later synthesis
work and therefore stays compiled.

## Action

Graduate Observations 300–303 from the live Lean research umbrella and remove
their executable modules from the working tree.

Preserve:

- the compressed checkpoint prose;
- historical references in later observations;
- Git history;
- Observation 299 as the shared search primitive;
- Observations 304–317 as the later positive/synthesis/classification arc.

## Boundary

This trial does **not** establish:

- that every module outside product reachability should be deleted;
- that import reachability is equivalent to semantic importance;
- that independent counterexamples or checker-diversity witnesses are expendable;
- that a generic dependency-closure framework is needed.

Dependency closure is used only as a candidate selector. LOAM's existing
ownership, qualification, and historical-evidence rules still decide retention.

## Result to evaluate

If the ordinary `Loam.Observations` build and repository qualification remain
green after removing 300–303, the experiment demonstrates one concrete benefit:
verified discovery artifacts can graduate once later live results no longer
depend on them and their findings have been compressed elsewhere.

If qualification fails or a distinct current obligation is uncovered, restore or
reshape the boundary instead of forcing the deletion.
