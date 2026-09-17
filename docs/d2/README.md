# D2 projection experiment

This directory tests whether LOAM benefits from a second visual projection beside DRAKON.

The experiment does **not** adopt D2 as architecture authority, does not replace DRAKON, and does not add a production or CI dependency. It asks a narrower question:

> Does a structure-first projection make existing LOAM audit evidence easier for a human and an AI to inspect without erasing the execution/refusal information for which DRAKON is useful?

## First probe: G2-012 Current Actual target

`current_actual_target_comparison.d2` projects the same evidence already recorded by:

- `docs/research/CURRENT_ACTUAL_TARGET_OBLIGATION_DAG.md`;
- `docs/drakon/build_current_actual_target_audit_map.py`.

The subject is useful because three writers share one semantic root but immediately diverge in what they consume:

- Correction needs the retained Event payload;
- Reversal needs the retained Event payload;
- Date correction needs Event identity only.

The D2 projection deliberately emphasizes that ownership / obligation shape. DRAKON remains the better reference when exact decision order, refusal routing, or recovery flow is the question.

## Second probe: Scheduled / Actual ownership topology

`scheduled_actual_ownership_topology.d2` projects a materially different kind of evidence: several production operations share one fixed ownership mechanic while retaining different semantic authority responsibilities.

The shared mechanic is intentionally small:

```text
Scheduled writer ownership
        ->
Actual writer ownership
```

The callers do not therefore become one semantic operation. Creation, replacement, completion, cancellation, reversal, and initial AccountingRole publication read and mutate different authorities for different reasons. AccountingRole additionally extends the lock order through current-quantity-anchor and role ownership.

This probe asks whether D2 makes that topology easier to inspect than a procedural flow diagram without encouraging a generic publisher or merged authority abstraction.

## Render

Install the D2 CLI and verify it first:

```sh
d2 version
```

Then, from the LOAM repository root, render every committed D2 probe to both a human-facing SVG and a terminal/AI-friendly ASCII projection:

```sh
sh docs/d2/render.sh
```

Outputs are written under the already-ignored `scratch/d2/` tree with matching base names, for example:

```text
scratch/d2/current_actual_target_comparison.svg
scratch/d2/current_actual_target_comparison.txt
scratch/d2/scheduled_actual_ownership_topology.svg
scratch/d2/scheduled_actual_ownership_topology.txt
```

On macOS, render and open all SVG probes in Safari:

```sh
sh docs/d2/render.sh --open
```

The renderer uses ELK and an explicit SVG scale so local browser zoom and scrolling remain useful. The committed `.d2` source remains the inspectable evidence projection; generated SVG / ASCII output is disposable and not canonical evidence.

## Evaluation questions

Do not judge the experiment by appearance alone. Across the two probes, ask whether D2 repeatedly exposes distinctions that are awkward in DRAKON:

1. Can a reviewer identify shared semantic or ownership structure faster?
2. Are divergent consumers or mutation owners immediately visible?
3. Does the view preserve the distinction between shared mechanics and separate semantic authority?
4. Does it accidentally suggest a shared runtime helper or generic publisher that the evidence does not justify?
5. Does DRAKON still answer execution-order, refusal-path, and recovery questions more clearly?
6. Can an AI inspect the text source and recover the same structural distinctions without needing a screenshot?
7. Does maintaining the second projection reveal enough additional structure to justify its maintenance cost?

## Promotion rule

Keep this directory experimental until at least two materially different audit subjects show a repeatable benefit.

If D2 only redraws information already obvious in DRAKON, remove it. If it repeatedly exposes architecture, ownership, or proof-obligation relationships that DRAKON makes awkward, the next step is not to duplicate every diagram manually. The next step would be to test a small neutral observation representation from which DRAKON and D2 can both be projected.

That neutral representation must be earned by repeated evidence. Do not introduce a diagram framework merely because two renderers exist.
