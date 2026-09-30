# Let's Kakeibo — input mechanics deep dive

Status: second-pass reconstruction from contemporary reviews and 2024 hands-on evidence.

## 1. Entry is cell-first, not form-first

The monthly ledger is not merely a report. It is the editing surface.

The repeated pattern across the public record is:

```text
focus cell
  -> type / choose / calculate
  -> commit
  -> remain in the same chronological table
```

This gives the user continuous spatial context while recording.

## 2. History reuse

The 2005 Vector review documents several low-friction paths for repeated data:

- previously used shop names and descriptions become reusable history;
- entering the first character can narrow/reach prior values;
- pressing Enter can open the relevant selection list;
- mouse double-click is offered as an equivalent to the Enter action.

This is an unusually deliberate pairing:

```text
keyboard repetition  <->  mouse discoverability
```

The same household vocabulary is therefore learned once and reused, instead of requiring repeated full-form entry.

## 3. Cross-field assistance

The same 2005 review says that entered "description/content" can assist or populate related fields such as:

- shop;
- category;
- amount.

It also mentions automatic consumption-tax calculation/input.

Version 5 later adds explicit input-assistance keywords associated with categories.

The important design pattern is not the exact heuristic. It is that **the table remains authoritative to the user while assistance proposes nearby values**.

## 4. Amount entry

Two generations of assistance are documented.

### Calculator popup

The 2008 Vector review says that pressing Enter in an income/expense amount cell can open a calculator for local computation.

### Formula-in-cell

The v5.00 release article says formulas can be entered directly into income/expense cells; after confirmation the calculated result is shown.

Examples given by the article include:

- buying several of the same item;
- splitting a bill.

This reduces the need to leave the ledger for arithmetic.

## 5. Row insertion and chronological editing

The 2024 hands-on series demonstrates inserting a row at a chosen date through a context menu ("ここに一行挿入").

This is important because direct-edit ledgers need a way to modify the chronological stream without reconstructing the whole entry elsewhere.

The interaction can be summarized as:

```text
select temporal location
  -> insert local row
  -> fill cells in place
```

## 6. Receipt grouping

Several items from the same shop/date can be presented as a receipt group with a computed "レシート合計(n件)".

The 2024 walkthrough shows this alongside credit-card payment markers.

The presentation therefore distinguishes:

- individual purchased items;
- their shared real-world receipt;
- aggregate receipt total;
- payment method.

For LOAM research, the reusable lesson is **local grouping over a chronological evidence stream**, not necessarily Let's家計簿's exact grouping rule.

## 7. Running balance at entry time

The 2008 review says each row can display the balance for the selected account at that point.

This turns entry into immediate feedback:

```text
movement-like household fact
        +
derived account state at this point in time
```

The row can therefore reveal an unexpected balance without switching to a separate account screen.

## 8. Account movement assistance

The 2008 review describes input support for:

- withdrawing cash from a bank account;
- moving money between bank accounts.

Later specialist analysis notes that Let's家計簿's underlying representation is not the same as a modern first-class transfer model.

For LOAM this distinction matters:

- **interaction idea to study:** make common movements easy to enter;
- **semantic idea not to copy:** do not weaken LOAM's Movement model to match the older representation.

## 9. Credit-card editing

Card configuration includes payment account, closing date, withdrawal date, credit limit, and revolving-payment settings.

Once a card is selected as the account for an expense:

- the ledger shows payment method such as lump-sum/installment;
- payment method can be changed from the ledger;
- withdrawal day receives a "クレジット清算" aggregate;
- that aggregate can expose its constituent purchases.

This is a strong example of keeping **future consequence attached to original evidence**.

## 10. Autosave

The current 窓の杜 library page states that household data is saved automatically whenever a change is made.

This complements the direct-edit model: the table behaves more like a continuously retained notebook than a modal form with a separate Save ceremony.

The exact write transaction boundaries still need primary/manual inspection.

## 11. Context help

Three guidance layers are publicly documented:

- bottom-of-window cell-specific/status hints;
- a "?" route to tab-specific help;
- first-use tutorial balloons/dialogs.

The density of the interface is therefore counterbalanced by **local explanation at the current point of action**.

## 12. Negative lesson: hidden contextual complexity

The 2024 hands-on reviewer explicitly warns that the single entry screen can behave quite differently depending on context.

This is the tension at the center of the product:

```text
stay in one workspace
        vs
many context-sensitive meanings
```

A LOAM Desk experiment should preserve the first property while making the second more visible, for example through:

- explicit selected-row state;
- command legend;
- typed preview;
- clear refusal/explanation;
- fewer invisible cell-specific modes.
