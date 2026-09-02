# Observation 099 — Can temporal correction change current quantity without rewriting the Event?

## Question

Observations 091–098 established several separate boundaries:

- first-event current needs activity scoped to an origin rather than whole retained activity;
- origin-relative `Before / At / After` evidence can be enough for that scope;
- valid-time meaning is distinct from learned time;
- temporal evidence can remain outside the Event core;
- temporal evidence can be corrected append-only;
- current temporal frontier and historical as-known knowledge are different projections.

Observation 099 reconnects those temporal results to quantity:

> Can a correction to temporal scope change a derived current quantity while leaving the Event quantity itself untouched, and can the same append-only history still reconstruct the earlier as-known current quantity?

## Pressure case

Keep one fixed origin quantity:

```text
origin quantity = 0
```

and one Event whose quantity never changes:

```text
e0 amount = +100
```

At knowledge time 1, the retained temporal evidence says:

```text
t0:
  e0 is After(origin)
```

So the scoped current answer is:

```text
0 + 100 = 100
```

At knowledge time 3, later evidence corrects only the temporal placement:

```text
c0:
  t0 -> t1

t1:
  e0 is Before(origin)
```

The Event amount is still `+100`, but it no longer belongs to this origin-relative current scope:

```text
current = 0
```

## Why TLA+ is earned

The interesting property is temporal rather than arithmetic:

```text
as-known at 1
  current = 100

later append-only temporal correction

as-known at 3
  current = 0
```

The model must retain the same Event and quantity while changing only the derived membership of that Event in the selected scope.

The arithmetic itself is deliberately tiny.

## Model

`TemporalScopedQuantityCorrection.tla` keeps:

- one Event identity `e0`;
- fixed `EventAmount(e0) = 100`;
- fixed origin quantity `0`;
- temporal fact `t0 = After` learned at time 1;
- temporal fact `t1 = Before` learned at time 3;
- one append-only correction `c0: t0 -> t1` learned at time 3;
- append-only retained Event, temporal fact, and correction sets.

For a knowledge time `k`, the model derives the temporal frontier and then maps its unique temporal answer into scoped activity:

```text
After  -> include Event amount
Before -> include zero Event activity in this scope
missing or ambiguous temporal evidence -> no quantity answer
```

The current quantity answer is then:

```text
origin quantity + scoped activity
```

No Event quantity field is rewritten by the temporal correction.

## Observed TLA+ result

TLA+ tools 1.7.4 / TLC 2.19 completed the positive bounded exploration with no error:

```text
8 states generated
8 distinct states found
0 states left on queue
complete state graph depth: 6
```

The explored history preserved all intended safety properties:

- type safety;
- no retained Event or temporal evidence before its learned time;
- closed same-Event temporal correction references;
- at most one temporal frontier fact per Event at each knowledge time;
- missing temporal evidence invents no quantity answer;
- `EventAmount(e0)` remains exactly `100`;
- retained Event, temporal facts, and Corrections only grow.

Once `c0` is retained, the same final append-only history reconstructs:

```text
CurrentQuantityAnswersAt(1, e0) = {100}
CurrentQuantityAnswersAt(2, e0) = {100}
CurrentQuantityAnswersAt(3, e0) = {0}
```

The counterexample trace reaches the correction without replacing `e0`:

```text
knowledge time 1
  retainedEvents = {e0}
  retainedFacts  = {t0}

knowledge time 3, before correction
  retainedEvents = {e0}
  retainedFacts  = {t0}

knowledge time 3, after correction
  retainedEvents      = {e0}
  retainedFacts       = {t0, t1}
  retainedCorrections = {c0}
```

So the quantity change in this projection comes from corrected scope membership, not Event mutation.

## Deliberate boundary

The stronger claim was:

```text
retain only the final temporal frontier
  -> enough to reconstruct the earlier as-known quantity
```

TLC rejected it as expected:

```text
Invariant FinalTemporalFrontierCanReconstructPastQuantity is violated.
```

After correction, the final temporal frontier is only:

```text
{t1}
```

and `t1` was learned at time 3.

Filtering only that final frontier back to time 1 therefore yields no temporal answer, while the full append-only history retains `t0` and reconstructs:

```text
as-known at 1 = 100
```

So the bounded model supports:

```text
final temporal frontier
  != enough historical information for past quantity projection
```

## Finding

The observed model supports this qualified composition:

```text
immutable Event quantity
+ append-only temporal evidence
+ append-only temporal correction
+ origin-relative scoped projection
  ->
    earlier as-known current = 100
    later   as-known current = 0
```

without rewriting the Event quantity itself.

This connects the earlier time observations back to the quantity pressure first exposed by Observation 091:

```text
quantity fact
  says how much activity the Event carries

temporal evidence
  says whether that activity belongs in this selected origin-relative scope

current projection
  composes the two
```

Historical as-known quantity therefore depends on retained temporal history, not only the final temporal frontier.

This does **not** mean a temporal correction changes what physically happened. It changes the currently admitted temporal interpretation used by this selected projection.

## Non-goals

Observation 099 does not earn:

- a production temporal fact type;
- production temporal corrections or resolutions;
- a production origin-relative scope type;
- production Date/Time, timestamp, timezone, or total chronology;
- automatic temporal authority;
- any rewrite of production Event or Effect;
- persistence, CLI, wire-format, or private household data changes;
- a change to production `CurrentQuantity`.

## Practical Core impact

None.
