# Application 011: basis cut by correction roots

## Pressure

Private dogfood exposed one concrete mismatch in the practical balance view:
a quantity basis had been observed after one real occurrence, while that same
occurrence was also remembered as a LOAM Event. The existing projection added
all effective Event activity to the basis and therefore counted that occurrence
twice.

Observation 104 showed that storage order, Git chronology, a timestamp, or the
Event id that happens to be the current correction terminal are all stronger or
less stable than the pressure requires.

## Small production boundary

Application 011 introduces one application relation:

```text
basis correction root
        ×
Event correction root
```

Its current persistence image is a tiny TSV file:

```text
basis-cut.tsv

<basis-root-id><TAB><event-root-id>
```

The relation means:

> the quantity observed by this basis occurrence already reflects this Event
> occurrence.

The row does not say when either fact happened. It does not make file order,
EventMemory order, or Git history semantic.

## Why roots on both sides

Both retained families are append-only and correction-aware.

If a basis quantity is corrected later:

```text
basis-v1 -> basis-v2
```

and an already-reflected Event is also corrected later:

```text
event-v1 -> event-v2 -> event-v3
```

the same cut row remains sufficient:

```text
basis-v1    event-v1
```

The application resolves the current basis back to its correction root, resolves
the Event root forward to its current correction terminal, and excludes that
terminal from the post-basis Event contribution.

No cut-specific stable identity or cut-correction relation is introduced.

## Admission

For a nonempty cut:

- the ordinary quantity-basis frontier must still admit;
- the ordinary Event correction projection must still admit;
- every cut endpoint must be remembered;
- each cut endpoint must name a correction root, not an interior replacement;
- representation order is not used to choose either root or terminal.

Malformed or non-root evidence fails closed. A missing `basis-cut.tsv` means an
empty cut and preserves the earlier current-quantity behavior exactly.

## What stays out

This application does not introduce:

- Account or AccountType;
- Date, timestamp, transaction sequence, or accounting period;
- Git commit order as semantic history;
- a second quantity implementation;
- a basis-cut identity or writer protocol;
- arbitrary historical backfill inference.

A later historical occurrence that was already included in an old basis still
needs explicit cut evidence. If that pressure becomes common enough, a richer
valid-time model can be reconsidered then rather than imported preemptively.

## Compactness checkpoint

The practical quantity path remains:

```text
Event / EventCorrection
QuantityBasis / QuantityBasisCorrection
            +
     tiny root relation
            |
            v
 post-basis current quantity
            |
            v
      balance view
```

The new semantic distinction is retained directly instead of rebuilding an
Account ledger or a global temporal order around it.
