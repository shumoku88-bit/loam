# LOAM Concept-Pressure Reselection — September 2026

Status: **three probes completed; no production concept earned; F113 is next selected C-seeking probe**

Baseline main: `2fca5beaed65224a8d29d586fcc6735404bf599f`

This checkpoint changes the question asked after the first six-item domain falsification queue.

The first queue found independently observable distinctions:

```text
F051  known existence != exact quantity                COUNTEREXAMPLE
F033  quantity != future movement rights               COUNTEREXAMPLE
F001  pending lifecycle != temporary reservation       COUNTEREXAMPLE
F076  existing evidence composes sufficiently          ABSORBED
F055  recurrence shape != generation policy            COUNTEREXAMPLE
F086  reconstruction != external/physical assertion    COUNTEREXAMPLE
```

That result does **not** imply five production nouns or a Core rewrite.

The architectural question is narrower:

> Do these counterexamples require changing existing Core meanings/shapes, or can they be retained as a small number of conservative typed extensions or existing-evidence compositions?

## Rebuild-pressure scale

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

Therefore a counterexample earns B at most until a separate observation falsifies conservative extension for the concrete seam. C must be demonstrated, not inferred.

## Execution checkpoint

Three concept-pressure probes are now complete.

### Observation 202 / F052

```text
exact amount knowledge != exact temporal placement
result: COUNTEREXAMPLE
architectural pressure: B at most
```

Observation 202 strengthens the case that future existence, exact quantity, and exact scheduled coordinate can be independently knowable before a complete `ScheduledOccurrence`, while preserving the current exact occurrence shape as a valid completed fact.

### Observation 203 / F001 + F033 compression

The tempting flat view:

```text
operation -> usable quantity
```

does not preserve reservation provenance and operation-right provenance.

Result:

```text
COUNTEREXAMPLE to scalar compression
architectural pressure: B, not C
```

A common carrier may still share mechanics, but retaining both dimensions would be packaging rather than semantic compression.

### Observation 204 / F051 + F052 pre-Scheduled packaging compression

Observation 204 deliberately inserted one additional compression probe before F113.

Candidate observation-local carrier:

```text
known   : set Subject
amount  : Subject -> lone Amount
due     : Subject -> lone Due
```

Result:

```text
bounded subject-attached candidate SURVIVED
state-specific noun proliferation not required for selected F051/F052 views
architectural pressure: B, not C
```

Lower bounds also survived:

```text
amount/due attachments alone
  -/-> known existence

known existence + amount
  -/-> exact due placement

identity-free amount/due pools
  -/-> subject-specific amount/time correspondence
```

But once stable known-subject identity, subject-attached amount, and subject-attached due are all fixed, Alloy found no counterexample to the selected derived views in scope.

The interpretation is deliberately narrow:

```text
state-specific nouns can be compressed
without compressing away the independent information dimensions
```

So F051 and F052 do not currently justify separate production types such as `UnknownAmountObligation` and `KnownAmountUnknownDue`. They also do not yet earn one production `Expectation` or `Subject` type. Observation 204 only shows that a single subject-centered additive family is a viable smaller packaging candidate if real dogfood later requires partial future knowledge.

No completed concept-pressure probe has demonstrated that an existing Core family must change meaning or shape.

## Current classification

| Pressure | Current reading | Why |
|---|---|---|
| F051 + F052 pre-Scheduled knowledge | **B pressure; bounded packaging compression survived** | Observation 204 can represent selected existence-before-quantity and amount-before-time states with one subject-attached carrier; stable identity/existence/quantity/time distinctions still matter. |
| F033 movement rights | **B pressure, not scalar-compressible with F001** | Observation 203 shows current usable quantity cannot reconstruct future rights, including when held quantity is zero. |
| F001 temporary reservation | **B pressure, not scalar-compressible with F033** | Observation 203 shows an all-zero operational envelope can mask different reservation provenance. |
| F055 recurrence boundary policy | **future B constraint, not current rewrite pressure** | Production does not currently own a recurrence generator. The result constrains any future generator rather than invalidating current Scheduled occurrences. |
| F086 external/physical assertion | **B-or-query-layer candidate** | Assertion is independent of reconstruction, but authority/repair/completeness are still untested. Existing history remains truthful as reconstructed history. |
| F076 shared full refund | **A** | Existing burden + refund provenance + discharge already compose; no new family earned. |

No current selected result has demonstrated C.

## Concept-pressure probes

These are architectural probes, not a second F-series Work authority. `LOAM_FALSIFICATION_PROGRESS.md` remains the Work/Finding authority for F001-F200.

### 1. F052 — Scheduled skeleton symmetry — COMPLETE

Observation 202 found a counterexample to the claim that exact amount knowledge determines exact temporal placement.

Together with F051:

```text
known existence != exact quantity
exact quantity  != exact temporal placement
```

The result is B-level pressure at most and does not weaken exact `ScheduledOccurrence`.

### 2. F001 + F033 — availability/admissibility compression — COMPLETE

Observation 203 falsified one flat scalar operational envelope as an information-equivalent replacement for reservation and rights evidence.

This does not earn separate production `Hold` and `Capability` nouns. It only says any shared carrier must retain both meanings rather than erase them.

### 2.5. F051 + F052 — pre-Scheduled subject-attached compression — COMPLETE

Observation 204 tested whether the adjacent partial-knowledge states require separate state-specific nouns.

They do not for the selected bounded queries.

One observation-local stable subject with independent amount and due attachments represents both selected pressures, while smaller candidates fail:

```text
no explicit known existence        too small
no independent due evidence        too small
no stable subject correspondence   too small

known + subject amount + subject due
                                   bounded selected sufficiency survived
```

This is packaging compression, not a claim that existence, quantity, and time are one semantic dimension.

No production noun is earned.

### 3. F113 — one historical Event -> two jointly effective replacements — NEXT

This remains the strongest current **C-level probe**.

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

If such a query is independently observable, do **not** automatically generalize `EventCorrection`. First test whether a separate split/refinement relation can be added conservatively alongside current Correction. Only if that additive representation cannot preserve the required queries should the existing Correction shape be reconsidered.

Likely first instrument: Alloy for information/topology independence, followed by Lean only if a candidate additive relation survives.

### 4. F088 — discrepancy epistemic/repair boundary — SELECTED LATER

F086 established that physical/external assertion and reconstructed history are independent evidence. It deliberately did not decide what a conflict means.

F088 asks whether incomplete history must support distinctions such as:

```text
known complete reconstruction
vs
known incomplete / unknown reconstruction
vs
history repaired/padded by explicit policy
```

Do not let `asserted != reconstructed` silently create an adjustment Event.

Likely first instrument: Alloy.

## Structural relation

Structural S003 and S008 are both complete.

S003 shows quantity-preserving Effect split/merge is invisible to the existing `Event.quantityAt` query while representation/provenance remains retained.

S008 shows that, after successful Correction-frontier admission, frontier membership is remembered-and-untargeted and does not depend on admitted linear path length.

These results strengthen confidence in the current Core skeleton but do not answer F113's distinct one-to-many joint-replacement question.

S007 remains watchlist pressure and is not automatically promoted.

## What is deliberately not selected

### F055 follow-ups

Weekend/holiday shifting and richer recurrence policies remain useful later, but no production recurrence generator exists yet. They cannot currently establish that existing Core must change.

### Broad domain families

Inventory, tax, insurance, payroll, marketplace, BNPL, subscription, and securities cases remain adversarial pressure, not a reason to grow product vocabulary before the smaller concept seams above are understood.

## Decision rule

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
1. F052                              COMPLETE
2. F001 + F033 compression          COMPLETE
2.5 F051 + F052 packaging probe     COMPLETE
3. F113                              NEXT
4. F088                              LATER
```

The ordering is not a product roadmap. It is chosen to maximize the chance of avoiding unnecessary concepts before testing the candidate most likely to force structural change.

## Current conclusion

```text
wholesale rewrite required                 NOT SUPPORTED
proven Core-shape failure                   NONE YET
possible additive concept seams             YES
F001/F033 flat scalar compression            FALSIFIED
F051/F052 state-noun packaging compression   SURVIVED IN BOUNDED SCOPE
production pre-Scheduled noun earned         NO
next deliberate C-seeking attack             F113
```

The next observation should attack F113 without generalizing `EventCorrection` in advance.
