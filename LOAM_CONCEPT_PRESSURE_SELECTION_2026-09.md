# LOAM Concept-Pressure Reselection — September 2026

Status: **first two probes completed; no production concept earned; F113 is next selected probe**

Baseline main: `2fca5beaed65224a8d29d586fcc6735404bf599f`

This checkpoint changes the question asked after the first six-item domain falsification queue.

The first queue was designed to find missing independently observable information. It succeeded:

```text
F051  known existence != exact quantity                COUNTEREXAMPLE
F033  quantity != future movement rights               COUNTEREXAMPLE
F001  pending lifecycle != temporary reservation       COUNTEREXAMPLE
F076  existing evidence composes sufficiently          ABSORBED
F055  recurrence shape != generation policy            COUNTEREXAMPLE
F086  reconstruction != external/physical assertion    COUNTEREXAMPLE
```

That result does **not** imply five production nouns or a Core rewrite.

The next question is narrower and more architectural:

> Do the new counterexamples require changing existing Core meanings/shapes, or can they be compressed into a small number of conservatively added typed evidence families or existing-evidence compositions?

## Execution checkpoint

Two selected probes are now complete:

```text
Observation 202 / F052
  exact amount knowledge != exact temporal placement
  result: COUNTEREXAMPLE
  architectural pressure: B at most

Observation 203 / F001 + F033 compression
  flat operation -> usable quantity does not preserve
  reservation provenance + operation-right provenance
  result: COUNTEREXAMPLE to scalar compression
  architectural pressure: B, not C
```

Observation 202 strengthens the case that existence, exact quantity, and exact scheduled coordinate are independently knowable before a complete `ScheduledOccurrence`, while preserving the current exact occurrence shape as a valid completed fact.

Observation 203 shows that F001 and F033 do not collapse into one scalar future-use envelope. Reservation and operation-right evidence remain independently observable. A shared carrier may still share mechanics, but retaining both dimensions would be packaging rather than semantic compression.

Neither observation demonstrated that an existing Core family must change meaning or shape.

The next selected probe is therefore **F113**, the first deliberately C-seeking attack in this checkpoint.

## Rebuild-pressure scale

Use three outcomes rather than treating every counterexample alike:

```text
A  COMPOSITION
   existing retained evidence already composes to answer the selected query

B  CONSERVATIVE EXTENSION
   genuinely new information is needed, but it can live in a separate typed family
   while old facts and old projections keep their current meaning

C  CORE SHAPE PRESSURE
   the selected legitimate query cannot be represented without changing the
   semantic shape/meaning of an existing Core family
```

Application 006 is the default architectural null hypothesis:

```text
new independent evidence
  -> add a typed family
  -> old fact meanings remain unchanged
  -> old projections remain unchanged unless they opt in
```

Therefore a `COUNTEREXAMPLE` earns B at most until a separate observation falsifies conservative extension for the concrete seam. C must be demonstrated, not inferred.

Structural S003 supplies complementary evidence: quantity-preserving Effect split/merge is invisible to the existing `Event.quantityAt` query even though representation/provenance remains retained. The Event/Effect quantity algebra therefore has survived one direct representation attack and should not be redesigned merely because adjacent information families are incomplete.

## Current classification

| Pressure | Current reading | Why |
|---|---|---|
| F051 + F052 pre-Scheduled knowledge | **B pressure** | Observation 202 confirms exact quantity and exact temporal placement can be independently knowable. No existing exact `ScheduledOccurrence` meaning was invalidated. |
| F033 movement rights | **B pressure, not scalar-compressible with F001** | Observation 203 shows current usable quantity cannot reconstruct future rights, including when held quantity is zero. |
| F001 temporary reservation | **B pressure, not scalar-compressible with F033** | Observation 203 shows an all-zero operational envelope can mask different reservation provenance. |
| F055 recurrence boundary policy | **future B constraint, not current rewrite pressure** | Production does not currently own a recurrence generator. The result constrains any future generator rather than invalidating current Scheduled occurrences. |
| F086 external/physical assertion | **B-or-query-layer candidate** | Assertion is independent of reconstruction, but authority/repair/completeness are still untested. Existing history remains truthful as reconstructed history. |
| F076 shared full refund | **A** | Existing burden + refund provenance + discharge already compose; no new family earned. |

No current selected result has yet demonstrated C.

## Concept-pressure probes

These are concept-pressure probes, not a second F-series Work authority. `LOAM_FALSIFICATION_PROGRESS.md` remains the Work/Finding authority for F001-F200.

### 1. F052 — Scheduled skeleton symmetry — COMPLETE

Pressure:

```text
amount is known
but
due date is unknown
```

Observation 202 found a counterexample to the claim that exact amount knowledge determines exact temporal placement.

Together with F051, the result says the three dimensions can be independently knowable:

```text
existence
quantity
scheduled coordinate
```

The result is B-level pressure at most. It motivates a future additive pre-Scheduled evidence boundary if practical use demands one, rather than weakening `ScheduledOccurrence` by making its established exact fields nullable.

No production concept is earned yet.

### 2. F001 + F033 — availability/admissibility compression — COMPLETE

Observation 203 tested the tempting experiment-local scalar view:

```text
operation -> usable quantity
```

The compression failed.

Alloy found selected worlds where the same operational envelope came from different causes:

```text
fully reserved + operations permitted
vs
unreserved + operations prohibited
```

It also found that zero held quantity masks future operation rights, and blocked operations mask reservation evidence.

Therefore reservation provenance and operation-right provenance remain independent selected information dimensions.

This does not earn separate production `Hold` and `Capability` nouns. A common carrier could still share mechanics, but it must not erase the distinction merely to obtain one vocabulary item.

### 3. F113 — one historical Event -> two jointly effective replacements — NEXT

This is the strongest current **C-level probe**.

Current `EventCorrection` is explicitly:

```text
target : EventId
replacement : EventId
```

and `CorrectionFrontier` admits disjoint finite paths. Two sibling corrections from one target are intentionally treated as unresolved competing alternatives, not as two jointly effective descendants. `EventResolution` handles the opposite many-parent -> one-replacement topology.

F113 asks whether a legitimate correction can instead mean:

```text
one historical Event
  -> two replacement Events

both replacements jointly constitute the corrected interpretation
```

If such a query is independently observable, the next task is **not** automatically to generalize `EventCorrection`. First test whether a separate split/refinement relation can be added conservatively alongside current Correction. Only if that additive representation cannot preserve the required queries should the existing Correction shape be reconsidered.

Likely first instrument: Alloy for information/topology independence, followed by Lean only if a candidate additive relation survives.

### 4. F088 — discrepancy epistemic/repair boundary — SELECTED LATER

F086 established that physical/external assertion and reconstructed history are independent evidence. It deliberately did not decide what a conflict means.

F088 asks whether incomplete history must support a distinction such as:

```text
known complete reconstruction
vs
known incomplete / unknown reconstruction
vs
history repaired/padded by explicit policy
```

This is needed before promoting F086 into a canonical assertion concept. It may show that assertions can remain external evidence plus an explicit completeness/repair policy, or that another independently retained epistemic fact is required.

Do not let `asserted != reconstructed` silently create an adjustment Event.

Likely first instrument: Alloy.

## Structural relation

Structural S003 and S008 are both complete.

S008 established that, after successful Correction-frontier admission, frontier membership is remembered-and-untargeted and therefore does not depend on admitted linear path length. That result strengthens confidence in the existing Correction path semantics but does not answer F113's distinct one-to-many joint-replacement question.

S007 remains watchlist pressure and is not automatically promoted.

## What is deliberately not selected

### F055 follow-ups

Weekend/holiday shifting and richer recurrence policies remain useful later, but no production recurrence generator exists yet. They cannot currently establish that existing Core must change.

### Broad domain families

Inventory, tax, insurance, payroll, marketplace, BNPL, subscription, and securities cases remain adversarial pressure, not a reason to grow product vocabulary before the smaller concept seams above are understood.

## Decision rule after these probes

Do not call for a rewrite unless at least one concrete seam reaches C:

```text
1. selected query is legitimate and independently observable
2. existing evidence composition is insufficient
3. a separate conservatively added typed family is also insufficient
4. the failure specifically comes from the semantic shape of an existing Core family
```

If the investigation instead yields only A and B results, the interpretation is the opposite:

> LOAM's existing skeleton is surviving; it merely needs a small number of earned orthogonal evidence families as real use demands them.

## Recommended order

```text
1. F052                          COMPLETE
2. F001 + F033 compression      COMPLETE
3. F113                          NEXT
4. F088                          LATER
```

The ordering is not a product roadmap. It is chosen to maximize the chance of **avoiding unnecessary concepts** before testing the one candidate most likely to force a structural change.

## Current conclusion

At this checkpoint:

```text
wholesale rewrite required          NOT SUPPORTED
proven Core-shape failure            NONE YET
possible additive concept seams      YES
flat F001/F033 scalar compression    FALSIFIED
next deliberate C-seeking attack     F113
```

The next observation should attack F113 without generalizing `EventCorrection` in advance.
