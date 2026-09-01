# Observation 087 — Can a new anchored coordinate begin at its first Event?

## Question

Observation 085 established that starting basis is a premise of one query mode rather than an intrinsic property of every coordinate.

Observation 086 then established:

```text
basis presence + Event presence
    -/-> anchored-current selection
```

Real daily-use pressure now suggests a temporal candidate for coordinates that legitimately join an anchored-current question only after the application origin.

Instead of requiring an application-start basis for every later coordinate, perhaps a concrete operation can say:

```text
this coordinate joins anchored-current now
```

at the same transition as the coordinate's first admitted Event activity.

The new question is:

> Can that first admitted Event provide a local zero-origin for a newly anchored coordinate, without making every newly observed coordinate automatically join anchored-current?

In household language this is close to saying that a new account-like coordinate may begin when it is first used. The experiment deliberately does not promote `Account`, `Holding`, `Use`, or `Expense Category` into the model.

## Candidate transition

The TLA+ model begins with one already anchored coordinate carrying an application-origin anchor. Two other neutral coordinates are initially unseen.

For a previously unseen coordinate, two experiment-local operations are possible.

### Observe only

```text
unseen
  -> first Event activity
  -> seen
  -> not enrolled in anchored-current
```

### Admit anchored at first Event

```text
unseen
  -> first Event activity
  + anchored-current enrollment
  + first-event origin
```

The first-event origin is exact zero immediately before the first activity:

```text
origin quantity = 0
first Event      = +q
current          = q
```

This is not an application-start basis fact. It is an experiment-local temporal origin for a coordinate whose anchored-current relevance begins later.

## Why TLA+ is earned here

Observation 086 already answered the static independence question with Alloy. The new distinction depends on transition order:

```text
unseen
  -> first Event
  -> later current reading
```

The claim is specifically that enrollment and origin creation must occur at the first-appearance transition rather than being reconstructed later from an unordered fact set. TLA+ / TLC therefore adds a distinct answer.

## Positive safety

The candidate specification checks:

- type safety;
- enrolled coordinates always have an origin;
- unseen coordinates have no prior activity or origin;
- a first-event origin contributes exact zero, so current equals activity accumulated since that origin;
- whenever a first-event origin is introduced, the coordinate was unseen with zero prior activity and the same transition records its first activity.

Expected positive result:

```text
complete finite state graph
no error
```

## Reachability witness

A deliberately false invariant asks whether a first-event origin can never appear:

```text
NoFirstEventOriginEverAppears
```

Expected result:

```text
counterexample
```

The witness demonstrates that a coordinate can really move from unseen to anchored with a zero origin and first activity in one transition. This is the precise bounded form of "the new coordinate begins when first used."

## Why first appearance alone is still insufficient

The model also retains an `ObserveOnly` entrance. Therefore a first appearance need not imply anchored-current enrollment.

A second deliberately false invariant asks whether every first appearance is automatically enrolled:

```text
AutoEnrollAllFirstAppearancesMatchesSelection
```

Expected result:

```text
counterexample
```

This protects the pressure exposed by the real use-shaped coordinate: first appearance is allowed to remain activity-only for the selected question.

## Same physical first appearance, different enrollment

The central boundary composes Observation 086 with time.

Two coordinates may both have:

```text
previously unseen
first activity = 1
no application-origin basis
```

while one first-appearance operation enrolls the coordinate and another does not.

Expected boundary:

```text
PhysicalFirstAppearanceDeterminesEnrollment
    counterexample
```

So:

```text
first appearance
    can provide the time of a new anchor

first appearance
    -/-> whether that anchor should exist
```

The missing distinction belongs to the operation/query vocabulary, not to the neutral Event quantity shape alone.

## Interpretation if qualified

If all expected results hold, the candidate boundary is:

```text
application-origin basis
  one way to anchor a coordinate already relevant at application start

first-event origin
  possible way to anchor a coordinate that becomes relevant later
```

but only when a concrete operation simultaneously admits that coordinate to the anchored-current question.

This would make the following practical future plausible without yet implementing it:

```text
new coordinate first used by an anchoring operation
  -> no manual starting quantity required
  -> origin is exact zero immediately before its first Event
  -> current begins from that Event
```

It would *not* justify:

```text
any new Locus appearing in any Event
  -> automatically current-like
```

That universal rule remains too strong.

## Open pressure

Even if this temporal candidate qualifies, production still needs to earn what concrete operation is allowed to admit a coordinate.

Possible later sources include:

- an explicit human-facing creation/admission operation;
- a transfer entrance that explicitly names a new anchored destination;
- another typed application relation;
- a query-local enrollment decision.

The experiment does not choose among them.

It also does not yet answer how later correction of the first Event interacts with the origin, whether origin admission is itself correctable, or whether an enrolled coordinate can later leave an anchored view.

## Practical Core impact

None at this checkpoint.

- no Core change;
- no Persistence change;
- no CLI change;
- no wire-format change;
- no Account / HoldingRole / UseRole / Expense Category primitive;
- no persistent generic Query or enrollment type;
- no private household values committed.
