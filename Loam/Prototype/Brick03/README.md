# LOAM UI Prototype 03 — Brick stable-redraw spike

This is a synthetic human-dogfood experiment, not a production frontend.

It asks one narrow follow-up question from Prototype 02:

> Does Brick's terminal rendering make immediate day/row navigation visually stable enough that the changed value is easy to track?

## Boundary

- synthetic data only;
- no canonical household reads;
- no writes;
- no LOAM Core/Application/Persistence changes;
- no Haskell/Brick production decision;
- no Forms, mouse layer, scrolling framework, or LOAM-specific terminal runtime.

The experiment deliberately keeps the same basic interaction as Prototype 02 while changing the rendering/runtime technology.

## Run

From the repository root:

```sh
cd Loam/Prototype/Brick03
cabal run loam-ui-prototype-03
```

## Keys

- Left / Right: move selected day immediately
- Up / Down: move between Actual and Scheduled immediately
- Enter: open the selected synthetic object
- `r`: open the mock Record draft
- Esc or `b`: return
- `q`: quit

## Human evidence to notice

Do not try to "pass" the prototype. Raw reactions are the evidence.

- When pressing Left/Right repeatedly, does the screen feel stationary while only the selected day changes?
- Can you visually follow which day changed without searching for it?
- Is `PayPay -138 JPY` / `coffee +138 JPY` easier to parse than the old arrow-only movement display?
- Does Up/Down selection feel immediate and easy to track?
- Is there visible flicker, jumping, or other redraw noise?
- Would you rather touch this tomorrow than Prototype 01 or Prototype 02?

## Why this is separate from Prototype 02

Prototype 02 showed that LeanTEA can provide raw arrow-key interaction, but the human dogfood session exposed two runtime-level issues on macOS/Alacritty:

1. raw-mode LF without carriage return caused diagonal row drift until locally patched;
2. full-frame repaint made day changes visually hard to track.

Prototype 03 does not patch or extend LeanTEA. It uses Brick as an independent comparator so the interaction question is not confounded by building another terminal framework inside LOAM.
