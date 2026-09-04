# Observation 155: Can one complete Actual image be published without mixed-generation visibility?

Status: **QUALIFIED** by bounded TLA+ / TLC state exploration and one public same-filesystem runtime fixture. No production unified-Actual writer is introduced here.

## Pressure

Observation 154 showed that one typed outer frame can carry the existing production EventMemory, ActualValidity, EventDescription, and EventCorrection wire representations without becoming a second semantic parser.

The next question is temporal rather than structural:

> If a future complete Actual image is built at a sibling staging path and then replaces one authority path, can canonical readers observe only the complete old image or the complete new image, never an in-progress mixture?

LOAM already stages and renames EventMemory and EventCorrectionMemory independently. Those helpers deliberately do **not** claim a cross-stream transaction. Observation 155 does not widen that claim. It asks whether a future *single complete image* has a smaller publication topology: build the whole replacement off-authority, then make one authority transition.

## Why TLA+ / TLC

The important distinction is operation order and reachable intermediate state:

```text
old authority
    -> partial sibling stage
    -> complete sibling stage
    -> atomic authority replace
    -> new authority
```

This is a state-transition question, so TLA+ / TLC is the primary formal instrument.

The positive model checks that:

- the authority target is always a complete old or complete new image;
- readers of the authority path observe only complete images;
- before publication the authority remains old;
- after publication the authority is new;
- a partial sibling stage never changes the authority target.

Two intentionally-too-strong reachability boundaries must fail:

- `NoPartialStageState`, proving an incomplete sibling stage is genuinely reachable;
- `NoPublishedState`, proving the complete new image is genuinely publishable.

A deliberately weaker direct-write comparison writes the authority path incrementally. TLC must find a counterexample to `ReadersSeeOnlyCompleteImages`, demonstrating why direct target mutation is not equivalent to sibling staging plus one authority transition.

## Why a filesystem fixture too

The TLA+ model treats `Publish` as one atomic transition. That is the right abstraction for reasoning, but it does not itself establish what the CI filesystem does.

`tests/observation_155_atomic_replace.py` therefore runs a separate public fixture on the GitHub Ubuntu filesystem:

1. write one complete old image to the authority path;
2. start four concurrent readers of that path;
3. write the new image gradually to a sibling path, creating a long partial-stage window;
4. require sibling and target to be on the same filesystem;
5. replace the target with `os.replace`;
6. require every concurrent read to be byte-identical to either the old image or the new image;
7. require both old and new observations to occur;
8. simulate interruption before replace and require the authority target to remain byte-identical to old while a partial sibling remains.

The runtime fixture and TLA+ model answer different questions. Neither is treated as a substitute for the other.

## Observed qualification receipt

TLA+ tools 1.7.4 / TLC 2.19 completed the positive model with no error:

```text
17 states generated
10 distinct states found
0 states left on queue
depth 6
Model checking completed. No error has been found.
```

The partial-stage reachability boundary failed as intended after `BeginStage`:

```text
target = "old-image"
stage = "partial-image"
published = FALSE
```

The published-state reachability boundary failed as intended after the complete transition sequence:

```text
old authority
-> partial sibling stage
-> complete sibling stage
-> published new authority
```

with the final state:

```text
target = "new-image"
stage = "no-stage"
published = TRUE
```

The direct-write comparison produced the intended three-state counterexample:

```text
State 1: target = "old-image", observed = {}
State 2: target = "partial-image", observed = {}
State 3: target = "partial-image", observed = {"partial-image"}
```

so `ReadersSeeOnlyCompleteImages` is false for incremental authority-path mutation.

The public filesystem fixture also passed:

```text
old_reads=704
new_reads=8
partial_reads=0
interrupted_target=old
```

The exact old/new read counts are scheduler-dependent and carry no semantic meaning. The qualified result is that both complete generations were observed, no partial generation or target disappearance was observed, and an interrupted sibling stage left the authority target unchanged.

## Qualified boundary

Within this bounded temporal model and the exercised same-filesystem Ubuntu fixture, the surviving publication topology is:

```text
complete sibling image
    + one same-filesystem authority replace
    => no mixed-generation canonical visibility
```

The direct-write alternative does not survive the same reader-visibility law.

This result does **not** claim:

- that Observation 152/154 framing is now the production canonical format;
- a production unified-Actual writer or migration;
- power-loss durability or directory-entry fsync semantics;
- serialization of concurrent writers;
- atomicity across several authority paths;
- safety when stage and target live on different filesystems;
- anything about private canonical household bytes.

The next production decision may now ask whether one complete Actual authority file is actually simpler than retaining coordinated sidecars. That remains a separate design choice, not a consequence smuggled into this observation.
