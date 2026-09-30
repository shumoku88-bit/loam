# Let's Kakeibo — interaction model

## 1. The user remains in the ledger

The defining interaction is not "open a transaction form." It is:

```text
see row -> move to cell -> enter/change value -> remain in household context
```

This matters because each edit happens while surrounding days, nearby purchases, account choice, and running balance remain visible.

## 2. Direct manipulation plus assistance

The program combines direct table editing with many small assistive behaviors.

Observed examples:

- reuse a previous shop or description;
- use a leading character to reach prior values;
- assign category from keywords;
- calculate inside the amount cell;
- enter a formula and store the result;
- group adjacent lines into a receipt total;
- choose accounts/cards in the row;
- show contextual hints for the focused cell.

The interaction burden is reduced without replacing the user's explicit record with a black-box classifier.

## 3. Keyboard and mouse parity

The 2005 review explicitly praises the ability to reach equivalent functions from keyboard and mouse.

That is a durable desktop principle:

```text
mouse for discovery / pointing
keyboard for repetition / speed
```

A LOAM TUI naturally preserves the second half. A future GUI should avoid making pointer interaction the only efficient route.

## 4. Context-dependent behavior

The 2024 hands-on review warns that the single recording screen can behave differently depending on context and may initially confuse users.

This is a useful negative lesson.

Rich direct editing has a cost:

```text
fewer modal screens
        vs
more hidden cell-specific behavior
```

For LOAM, a desk surface should keep directness while making state transitions explicit. A status line, command legend, preview, or typed action may be preferable to hidden magic.

## 5. Insertion and grouping

A later walkthrough demonstrates inserting a row at a chosen date via context menu, then entering purchases.

Receipt grouping is visually derived from related rows. The grouping uses line/background differences rather than forcing every item into a separate dialog hierarchy.

The general pattern is:

```text
chronological stream
  + local groups
  + visible subtotal
```

This may map well to a terminal table if grouping remains a presentation of underlying evidence rather than a second storage model.

## 6. Credit-card interaction

The card workflow is notable because future settlement remains connected to the original purchases.

Observed shape:

```text
purchase row
   |
   +--> payment method marker
   |
settlement aggregate on withdrawal day
   |
   +--> underlying purchase details
```

The important interaction idea is traceability, not Let's家計簿's specific accounting representation.

## 7. Reconciliation and uncertainty

The author's own recommended workflow is unusually pragmatic:

1. enter what is remembered;
2. compare current cash with ledger cash;
3. create an unknown-use adjustment for the difference;
4. correct it later if the true use is remembered;
5. do not let a small mismatch stop continued use.

For LOAM research this is relevant to human factors, but the exact correction semantics must remain LOAM-native.

## 8. Guidance

Observed guidance layers include:

- initial sample book;
- tutorial balloons/dialogs for unfamiliar actions;
- cell-sensitive status help;
- online help;
- reminder after several days of inactivity.

This makes the dense interface learnable without stripping it down to a low-capability form.

## 9. Interaction topology

A compact reconstruction:

```text
                 +------------------+
                 |   calendar/date  |
                 +---------+--------+
                           |
                           v
+---------+      +---------+---------+       +----------------+
| history | ---> | monthly ledger    | ----> | detail / source|
| keyword |      | focused row/cell  |       +----------------+
| formula |      +---------+---------+
+---------+                |
                           +--> account balance
                           +--> card settlement
                           +--> budget/report
                           +--> graph
```

The ledger is the hub, but analysis can return to evidence.

## 10. Candidate terminal translation, not yet a design

The behavior suggests a low-risk experimental shape:

```text
calendar      Actual table
daily info    selected-row context
status/help   command hints
```

This remains only a research hypothesis until tested against current LOAM workflows.
