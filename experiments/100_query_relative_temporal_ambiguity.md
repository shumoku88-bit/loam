# Observation 100: Is temporal ambiguity the same as quantity ambiguity?

## Question

Observation 099 showed that corrected temporal scope can change a derived current quantity without rewriting the Event quantity itself.

A tempting next rule would be:

```text
unresolved temporal conflict
  -> quantity current unavailable
```

Observation 100 asks whether that implication is always justified, or whether ambiguity is relative to the selected projection.

## Pressure cases

Keep two immutable Events with the same quantity:

```text
e0 amount = 100
e1 amount = 100
origin quantity = 0
```

At knowledge time 1 both Events have one retained temporal fact saying `After(origin)`, so both quantity answers are `100`.

At knowledge time 2 each Event receives a sibling temporal correction conflict.

For `e0` the two frontier candidates disagree about origin membership:

```text
t1 = Before(origin)
t2 = After(origin)

candidate quantities = {0, 100}
```

For `e1` the two frontier facts remain structurally distinct and unresolved, but they agree for this quantity projection:

```text
u1 = After(origin)
u2 = After(origin)

candidate quantities = {100}
```

At knowledge time 3 an explicit whole-frontier Resolution settles only the divergent `e0` conflict with a new `After(origin)` result.

## Model

`QueryRelativeTemporalAmbiguity.tla` keeps:

- two immutable Event identities and quantities;
- append-only temporal facts;
- append-only sibling Corrections;
- one later Resolution for the divergent conflict;
- origin-relative `Before / After` temporal meanings;
- candidate quantity values derived from every current temporal frontier fact;
- a selected quantity answer only when all current temporal candidates collapse to exactly one quantity value.

The selected quantity projection therefore distinguishes:

```text
temporal frontier has multiple facts

from

selected quantity projection has multiple possible values
```

These need not be the same condition.

## Positive properties

The positive configuration checks:

- retained knowledge never appears before its learned time;
- Correction and Resolution references remain closed and same-Event;
- Event quantities remain exactly `100`;
- time 1 yields quantity `100` for both Events;
- the divergent conflict yields temporal candidates `{Before, After}`, quantity candidates `{0, 100}`, and no selected quantity answer;
- the convergent conflict remains a structural temporal conflict while its quantity candidate set is `{100}` and its quantity answer remains `100`;
- the later Resolution restores the divergent Event quantity answer to `100`;
- the final retained history reconstructs the historical quantity views at knowledge times 1, 2, and 3;
- retained Events, facts, Corrections, and Resolutions only grow.

## Deliberate boundaries

The first deliberately too-strong claim is:

```text
any temporal conflict
  -> quantity unavailable
```

The convergent `After / After` conflict should reject that claim because this quantity projection still has the unique value `100`.

The second deliberately too-strong claim is the opposite:

```text
any temporal conflict
  -> quantity still available
```

The divergent `Before / After` conflict should reject that claim because it produces quantity candidates `{0, 100}`.

## Observed TLA+ 1.7.4 result

The positive bounded exploration completed successfully:

```text
Model checking completed. No error has been found.
10 states generated
10 distinct states found
0 states left on queue
depth 7
```

At knowledge time 2 the same retained history contains both kinds of temporal conflict:

```text
e0 frontier = {t1, t2}
positions   = {Before, After}
quantity candidates = {0, 100}
quantity answer      = unavailable

e1 frontier = {u1, u2}
positions   = {After, After}
quantity candidates = {100}
quantity answer      = 100
```

The blanket blocking claim was rejected as expected:

```text
Invariant AnyTemporalConflictBlocksQuantity is violated.
```

The counterexample reaches the knowledge-time-2 state with both sibling conflicts retained. `e1` is still a structural temporal conflict, but both unresolved candidates map to quantity `100`.

The blanket availability claim was also rejected as expected:

```text
Invariant AnyTemporalConflictStillYieldsQuantity is violated.
```

The counterexample reaches the same knowledge-time-2 state. `e0` has unresolved `Before / After` candidates that map to distinct quantities `0` and `100`, so no unique quantity answer exists.

The useful boundary is therefore narrower than either blanket rule:

```text
temporal conflict
  -/-> quantity ambiguity by itself

quantity ambiguity
  depends on whether unresolved temporal candidates
  disagree under the selected quantity projection
```

A later explicit Resolution can settle the divergent `e0` conflict and restore quantity `100`, while the convergent `e1` temporal conflict may remain unresolved even though this selected quantity projection is already determined.

This does not erase or settle the underlying temporal conflict. It only shows that a coarser projection can sometimes be determined even when richer retained meaning remains unresolved.

## Why TLA+ is earned

The structural distinction could be stated without transitions, but the desired observation also includes a sequence:

```text
settled
  -> sibling temporal conflict
  -> query-relative quantity result
  -> explicit Resolution
  -> settled quantity again
```

TLA+ keeps the learned-time history and append-only retained evidence visible while checking that transition.

## Non-goals

Observation 100 does not earn:

- production temporal fact, Correction, or Resolution types;
- a production quantity result type for conflict status;
- a rule that unresolved temporal meaning may always be hidden by a determined projection;
- production Date/Time, timestamps, timezone, or total chronology;
- persistence, CLI, wire-format, or private household data changes;
- a change to production `CurrentQuantity`.

## Practical Core impact

None.
