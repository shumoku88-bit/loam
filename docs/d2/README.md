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

## Render

Install the D2 CLI and verify it first:

```sh
d2 version
```

Then, from the LOAM repository root, render both a human-facing SVG and a terminal/AI-friendly ASCII projection:

```sh
sh docs/d2/render.sh
```

Outputs are written under the already-ignored `scratch/` tree:

```text
scratch/d2/current_actual_target_comparison.svg
scratch/d2/current_actual_target_comparison.txt
```

On macOS, render and open the SVG in one command:

```sh
sh docs/d2/render.sh --open
```

The renderer uses ELK because this probe is a hierarchical graph with three sibling consumer branches. The committed `.d2` source remains the inspectable evidence projection; generated SVG / ASCII output is disposable and not canonical evidence.

For a direct CLI invocation, the equivalent SVG command is:

```sh
d2 --layout=elk docs/d2/current_actual_target_comparison.d2 \
  scratch/d2/current_actual_target_comparison.svg
```

## Evaluation questions

Do not judge the experiment by appearance alone. Compare the D2 view with the DRAKON map and the obligation DAG and ask:

1. Can a reviewer identify the already-shared semantic law faster?
2. Is it immediately visible that Correction/Reversal consume Event payload while Date correction consumes identity only?
3. Does the view make authority preconditions and downstream consumers easier to distinguish?
4. Does it accidentally suggest a shared runtime helper that the audit evidence does not justify?
5. Does DRAKON still answer execution-order and refusal-path questions more clearly?
6. Can an AI inspect the text source and recover the same structural distinctions without needing a screenshot?
7. Does maintaining the second projection reveal enough additional structure to justify its maintenance cost?

## Promotion rule

Keep this directory experimental until at least two materially different audit subjects show a repeatable benefit.

If D2 only redraws information already obvious in DRAKON, remove it. If it repeatedly exposes architecture, ownership, or proof-obligation relationships that DRAKON makes awkward, the next step is not to duplicate every diagram manually. The next step would be to test a small neutral observation representation from which DRAKON and D2 can both be projected.

That neutral representation must be earned by repeated evidence. Do not introduce a diagram framework merely because two renderers exist.
