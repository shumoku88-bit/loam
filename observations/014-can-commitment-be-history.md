# Observation 014: Can Commitment Be a History?

## Question

Observation 013 showed that commitment-bearing information cannot be reconstructed from physical placement-and-Use history alone.

That did not establish that **active commitment itself** must be stored as primitive state.

This observation asks a narrower question:

> Can active commitment be derived from an intentional history of declarations and releases?

## Construction

The stored `commitment` relation from Observation 013 is removed.

Each world instead carries two intentional event relations:

```text
declared: Time -> Unit -> Purpose
released: Time -> Unit -> Purpose
```

`activeCommitment[w, t]` is derived from declarations visible through `t` that have not subsequently been released.

The physical side remains separate:

```text
placement + Use history
        -> derived availability
        -> live holdings
```

The intentional side is:

```text
Declare + Release history
        -> active commitment
```

Present permission is then observed from both derived views.

No `Envelope` entity is introduced.

## Executed result

Alloy 6.2.0 / Sat4j, with exactly 5 Time, 2 Purpose, and 4 Unit atoms:

```text
samePhysicalTraceDifferentIntent             SAT
declareReleaseRedeclare                       SAT
PhysicalTraceDeterminesActiveCommitment       SAT
IntentionalHistoryDeterminesActiveCommitment  UNSAT
CombinedHistoryDeterminesPermission           UNSAT
ActiveCommitmentIsHonoredThroughHorizon       UNSAT
```

For the three `check` commands, SAT means a counterexample exists and UNSAT means no counterexample was found within the stated scope.

## Witness 1: same physics, different intent

Alloy found a witness using:

```text
Unit3
committed Purpose: Purpose1
proposed destination: Purpose0
```

Left and Right have the same complete physical placement-and-Use trace.

In Left, the intentional history leaves `Unit3 -> Purpose1` active at the present observation point. In Right, the same Unit has no active commitment. Therefore reassignment to `Purpose0` is forbidden in Left and permitted in Right.

So Observation 013 survives intact:

> Physical history alone does not determine commitment-bearing meaning.

## Witness 2: declaration, release, redeclaration

A second SAT witness demonstrates that the derived relation can disappear and later reappear without being stored directly:

```text
Time0: Declare(Unit3, Purpose1)
Time1: Release(Unit3, Purpose1)
Time2: Declare(Unit3, Purpose1)
Time2: Unit3 -> Purpose1 is active again
```

The current active relation is therefore a projection of the intentional event history in this model.

## Determinacy boundary

The bounded checks separate three claims.

### Physical history is insufficient

`PhysicalTraceDeterminesActiveCommitment` has a SAT counterexample.

Two worlds can be physically identical and still differ in active commitment because their intentional histories differ.

### Intentional history is sufficient for active commitment

`IntentionalHistoryDeterminesActiveCommitment` is UNSAT.

Within this Declare/Release vocabulary, two worlds with the same intentional history cannot disagree about the derived active commitment at any Time.

### Combined history is sufficient for present permission

`CombinedHistoryDeterminesPermission` is UNSAT.

When physical history and intentional history are both identical, the model cannot produce different present reassignment permission.

## Finding

Observation 013 established that some commitment-bearing information must exist beyond physical live holdings.

Observation 014 sharpens that result:

```text
commitment-bearing information must exist
                does not imply
active commitment must be stored as primitive state
```

For this bounded vocabulary, active commitment can instead be a derived view over an intentional event history.

The resulting shape is:

```text
physical history             intentional history
      |                              |
      v                              v
 live holding                  active commitment
      \                              /
       \                            /
        +-------- permission ------+
```

This suggests two provenance streams rather than one enlarged current-state object.

A world may have the same physical history while differing in what was promised, and therefore differ in what may be done next.

## What this does not establish

This is not a general theorem about event sourcing or about every possible notion of commitment.

The result is bounded by:

- the finite Alloy scope;
- the selected Declare/Release vocabulary;
- the rule that one Unit has at most one active commitment at a Time;
- the present permission question used here.

If future operations need to ask *when*, *why*, or *by whom* something was promised, the derived `activeCommitment` relation may no longer be a sufficient summary of intentional history.

## Next pressure point

The next question is now visible:

> Is active commitment the minimal sufficient summary of intentional history for the current permission vocabulary, or can intentional history be compressed further without changing any future-visible distinction?

That reconnects the commitment line with the earlier minimal-sufficient-state observations without assuming an Envelope-shaped object in advance.
