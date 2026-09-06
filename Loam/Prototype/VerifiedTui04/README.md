# LOAM UI Prototype 04 — minimal verified Lean TUI kernel

This is a synthetic comparison experiment, not a production frontend.

Prototype 03 established that Brick/Vty makes stable raw-key redraw comparatively easy, and human dogfood preferred a fixed September 2026 month grid to the earlier five-day strip. Prototype 04 asks a different question:

> Can LOAM reproduce the same small calendar interaction with a tiny Lean-owned kernel whose useful pure laws are directly checkable, without trying to rebuild Brick?

Prototype 04 is a sibling of the Brick experiment: both branch from the Prototype 01 head. This keeps the Haskell/Brick implementation and the Lean implementation independent enough to compare their costs.

## Boundary

The retained pure pipeline is deliberately small:

```text
Widget
  -> abstract Screen
  -> semantic diff / Patch
  -> TerminalOp
  -> external ANSI adapter
```

Interaction is likewise split into a pure transition and an external key reader:

```text
State × Event -> Step
```

The terminal is outside the verified model. ANSI escape sequences, `stty`, the OS terminal driver, Alacritty, and physical keyboard decoding are adapters / environment assumptions. Prototype 04 does not claim to verify them.

The prototype intentionally does **not** add Forms, mouse support, a file browser, a general scrolling framework, Brick compatibility, canonical household reads, or canonical writes.

## First retained law

The first proof is the screen reconstruction law:

```lean
applyOps old (diff old new) = new
```

`Screen` is a finite coordinate space of styled cells. `diff` returns a semantic patch, not ANSI bytes. `applyOps` interprets that patch back into an abstract screen. This keeps terminal-specific behavior out of the proof.

The current Lean specimen also closes several smaller implementation properties:

- selection is represented by `Fin 30`;
- focus is closed over Actual/Scheduled;
- `update` is a pure function, so the same state/event pair has one result.

These are intentionally modest claims. They do not prove that a real terminal displays the abstract screen correctly.

## Alloy bounded observation

`Interaction.als` independently explores the small interaction state machine before treating its shape as settled implementation vocabulary. It checks:

- selected day remains in September;
- focus remains Actual/Scheduled;
- one state/event pair determines one next-state shape;
- month-edge arrows clamp rather than leaving September;
- arrow keys outside Home do not move the interaction state.

It also requires witnesses for one-week calendar movement and Tab-then-open-Scheduled.

## Synthetic UI

The comparison surface follows Prototype 03 closely:

- September 2026 fixed month grid;
- Left/Right: previous/next day;
- Up/Down: previous/next week;
- Tab: Actual/Scheduled selection;
- Enter: open selected object;
- `r`: mock Record draft;
- `b`: back;
- `q`: quit;
- `PayPay -138 JPY` / `coffee +138 JPY` Actual effect;
- `bank -50,000 JPY` / `rent +50,000 JPY` Scheduled effect.

No file is read or written.

## Build and run

From the repository root:

```sh
lake build loamUiPrototype04
./.lake/build/bin/loamUiPrototype04
```

The target is non-default so this prototype does not become part of the ordinary LOAM executable surface merely by existing.

## Human comparison

The useful comparison with Prototype 03 is not whether Lean can imitate every Brick feature. Observe instead whether this subset is enough to preserve the stable calendar feel, whether selection remains visually trackable, whether redraw is quiet, and how much implementation/kernel machinery had to be retained to achieve that result.

A successful Prototype 04 would justify further investigation of this narrow kernel. It would not, by itself, select Lean as LOAM's production TUI framework.
