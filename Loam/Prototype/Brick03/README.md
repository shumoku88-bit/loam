# LOAM UI Prototype 03 — Brick calendar-navigation spike

This is a synthetic human-dogfood experiment, not a production frontend.

Prototype 03 first established that Brick/Vty can provide visually stable raw-key redraw without growing a LOAM terminal runtime. The next human observation was that a five-day horizontal strip still did not feel strongly calendar-like.

This revision asks one narrow follow-up question:

> Does a real month-grid spatial shape make the selected date easier to understand and move through?

## Boundary

- synthetic data only;
- September 2026 only;
- no adjacent-month navigation yet;
- no canonical household reads;
- no writes;
- no LOAM Core/Application/Persistence changes;
- no Haskell/Brick production decision;
- no Forms, mouse layer, scrolling framework, or LOAM-specific terminal runtime.

The month boundary is intentionally incomplete. If an arrow would leave September, the prototype stays put and reports that adjacent months are omitted. This keeps the experiment about calendar recognition rather than date-library design.

## Run

From the repository root:

```sh
cd Loam/Prototype/Brick03
cabal run loam-ui-prototype03
```

The Cabal package/executable is named `loam-ui-prototype03` because Cabal package-name components separated by hyphens cannot end in an all-numeric component such as `-03`.

## Keys

- Left / Right: previous / next day
- Up / Down: previous / next week
- Tab: switch the selected synthetic object between Actual and Scheduled
- Enter: open the selected synthetic object
- `r`: open the mock Record draft
- Esc or `b`: return
- `q`: quit

Arrow keys are deliberately reserved for time navigation on Home. Object selection no longer consumes Up/Down.

## Human evidence to notice

Do not try to "pass" the prototype. Raw reactions are the evidence.

- Does the month grid immediately read as a calendar without reading the footer?
- Do Left/Right feel naturally like one-day movement?
- Do Up/Down feel naturally like one-week movement because the selected cell stays in the same weekday column?
- Can you visually follow the selected day without searching for the changed number?
- Does the stable month geometry reduce eye travel compared with the five-day strip?
- Is Tab an acceptable separate gesture for switching Actual/Scheduled, or does it feel hidden?
- Is `PayPay -138 JPY` / `coffee +138 JPY` still easy to parse?
- Is there visible flicker, jumping, or other redraw noise?
- Would you rather touch this tomorrow than the strip version?

## Why this is separate from Prototype 02

Prototype 02 showed that LeanTEA can provide raw arrow-key interaction, but the human dogfood session exposed two runtime-level issues on macOS/Alacritty:

1. raw-mode LF without carriage return caused diagonal row drift until locally patched;
2. full-frame repaint made day changes visually hard to track.

Prototype 03 does not patch or extend LeanTEA. It uses Brick as an independent comparator so the interaction question is not confounded by building another terminal framework inside LOAM.
