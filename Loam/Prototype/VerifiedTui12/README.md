# Prototype 12: verified Movement record editor pressure

This is a synthetic, no-write form experiment built from production `main`.

It asks whether the small Lean-owned TUI kernel that already survived a month calendar and a vertical Actual review can also support a third, differently-shaped interaction: a focused record form with candidate selection, text editing, validation, and preview.

## Why this branch starts from production main

The active Home/Scheduled prototype stack remains independent. Prototype 12 imports only the previously earned `VerifiedTui04` semantic screen kernel and compiled sparse-row runtime onto current production main. It does not import the old calendar or review state machines.

## Current form

The edit state has exactly five local fields:

```text
Description
From locus
From amount
To locus
To amount
```

This is deliberately not a generic Form/List/Input framework. Five fields are enough to pressure focus movement and preview admission before dynamic posting rows are earned.

Known Locus candidates are synthetic presentation data. Up/Down selects a candidate while a Locus field has focus; Enter accepts it. Tab and Shift-Tab move focus. ASCII characters edit the active field. Backspace removes one character.

The selected-day seed is synthetic `2026-09-07` and models the HRA property that Record inherits an explicit Home temporal coordinate rather than asking the human to rediscover it inside every operation.

## Semantic boundary

The draft is presentation state only. Preview is admitted through production:

```text
BalancedMovement.ofChanges? ⟨"jpy"⟩
```

so a preview exists only when:

- both Locus fields are nonempty;
- both amounts are positive integers;
- signed From/To quantities close exactly to zero.

The preview then displays the admitted `BalancedMovement`. No separate debit/credit, purchase/transfer/income kind, or form-specific accounting fact is retained.

## Safety boundary

There are **no writes** in Prototype 12. Enter on preview reaches a visible disabled publication boundary and does not call a publisher.

The next gate, only after human dogfood, is to decide whether this editing shape deserves connection to the existing Movement writer. Writer ownership, stale admission, and canonical refresh must remain production application concerns rather than becoming form state.

## Local laws

Lean checks include:

- focus is structurally bounded by `Fin 5`;
- candidate selection is structurally bounded by `Fin 6`;
- any admitted preview movement has exact zero signed total;
- attempting preview does not mutate the draft;
- returning from preview to edit preserves the draft;
- Enter at the disabled preview publication boundary preserves the draft;
- compiled sparse rendering equals the semantic screen.

The existing sparse-row reconstruction theorem remains shared underneath.

## Deliberate omissions

- no canonical read or write;
- no dynamic posting rows yet;
- no split-payment editor yet;
- no Scheduled-prefilled draft yet;
- no UTF-8 input decoder yet;
- no mouse or paste support;
- no generic Form/Input/Router abstraction;
- no production TUI decision.

## Run

```sh
lake build loamUiPrototype12
./.lake/build/bin/loamUiPrototype12
```

Controls:

```text
Tab / Shift-Tab   move field focus
Up / Down         candidate selection on Locus fields
Enter             next / accept candidate / preview
Backspace         erase one character
E or B            preview -> edit
Ctrl-Q             quit
```

## Human gate

Try one ordinary balanced movement such as `paypay -> coffee, 138 JPY` and observe:

1. whether field movement feels spatially predictable;
2. whether visible Locus candidates reduce recall burden;
3. whether the final Enter naturally feels like entering preview rather than publishing;
4. whether balance failure is understandable and recovery is short;
5. whether redraw stays immediate while typing and moving focus;
6. whether a five-field local state machine is enough, or real use immediately demands dynamic posting rows.
