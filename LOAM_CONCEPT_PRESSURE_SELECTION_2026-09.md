# LOAM Concept-Pressure Reselection — September 2026

Status: **selection-only; no production concept earned; domain READY remains unchanged**

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

## Current provisional classification

| Pressure | Current reading | Why |
|---|---|---|
| F051 known obligation / unknown amount | **B candidate, strongest concept pressure** | `ScheduledOccurrence` and `RelationUnit` both require exact quantity. Existing meanings remain valid, but there is nowhere canonical for existence-before-quantity. |
| F033 movement rights | **B candidate, possibly compressible with F001** | Operation-specific rights are independent of quantity and coarse allocation eligibility, but the result did not require changing Event, Locus, Quantity, or Capacity meaning. |
| F001 temporary reservation | **B candidate, possibly compressible with F033** | Reservation changes selected availability while physical quantity remains unchanged; this looks like an overlay/encumbrance seam rather than a broken physical Event. |
| F055 recurrence boundary policy | **future B constraint, not current rewrite pressure** | Production does not currently own a recurrence generator. The result constrains any future generator rather than invalidating current Scheduled occurrences. |
| F086 external/physical assertion | **B-or-query-layer candidate** | Assertion is independent of reconstruction, but authority/repair/completeness are still untested. Existing history remains truthful as reconstructed history. |
| F076 shared full refund | **A** | Existing burden + refund provenance + discharge already compose; no new family earned. |

No current selected result has yet demonstrated C.

## Concept-pressure near probes

These are **selection candidates**, not F-series `READY` state. `LOAM_FALSIFICATION_PROGRESS.md` remains the Work/Finding authority and stays at domain `READY = 0` until one concrete observation is deliberately opened.

### 1. F052 — Scheduled skeleton symmetry

Pressure:

```text
amount is known
but
due date is unknown
```

Why first:

F051 already showed that obligation existence can precede exact quantity. Current `ScheduledOccurrence` requires both an explicit scheduled coordinate and an exact `BalancedMovement`.

If F052 also demonstrates that exact quantity can exist before temporal placement, then the two mandatory Scheduled dimensions are independently knowable:

```text
existence
quantity
scheduled coordinate
```

That would strongly motivate testing a smaller pre-Scheduled identity/claim skeleton with independently attachable quantity/time evidence, rather than weakening `ScheduledOccurrence` by turning its established exact fields into nullable state.

Desired result:

- determine whether F051 + F052 can be represented by one smaller additive evidence boundary;
- preserve existing exact `ScheduledOccurrence` unchanged if possible;
- do not introduce `Obligation`, `Claim`, `Plan`, or `Option Quantity` by vocabulary preference.

Likely first instrument: Alloy.

### 2. F001 + F033 — availability/admissibility compression probe

This is a post-counterexample compression experiment rather than a new Atlas specimen.

Question:

> Can temporary reservation and operation-specific wallet rights be represented by one smaller information-equivalent boundary for the selected future-use queries, without introducing separate `Hold`, `WalletKind`, and generic `Capability` concepts?

Candidate experiment-local shape might resemble:

```text
resource × operation -> available / permitted quantity
```

but that shape is deliberately not privileged. It must preserve the provenance distinction between:

- quantity temporarily encumbered by an authorization-like fact;
- an operation prohibited by a right/policy distinction.

A successful compression would reduce two counterexamples to one additive concept seam. Failure would justify keeping reservation and rights evidence distinct.

Likely first instrument: Alloy.

### 3. F113 — one historical Event -> two jointly effective replacements

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

### 4. F088 — discrepancy epistemic/repair boundary

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

## What is deliberately not selected

### S008

Structural S008 remains the structural authority's only `READY` item and is valuable, but it asks whether a Correction-frontier terminal-contribution law generalizes to arbitrary admitted finite chain length.

That improves proof/generalization confidence. It does **not** directly answer the present question, "does LOAM need new concepts or a redesign?" Therefore it remains structurally READY without preempting this concept-pressure investigation.

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
1. F052
   test whether F051 points to a general pre-Scheduled skeleton

2. F001 + F033 compression probe
   test whether two apparent concepts collapse to one availability/admissibility seam

3. F113
   deliberately attack current Correction topology for genuine Core-shape pressure

4. F088
   determine whether assertion conflict earns canonical epistemic evidence or remains a query/source boundary
```

The ordering is not a product roadmap. It is chosen to maximize the chance of **avoiding unnecessary concepts** before testing the one candidate most likely to force a structural change.

## Current conclusion

At this checkpoint:

```text
wholesale rewrite required          NOT SUPPORTED
proven Core-shape failure            NONE YET
possible additive concept seams      YES
number of such seams                 NOT YET KNOWN
```

The next observations should therefore try to compress the discovered counterexamples before adding production vocabulary.
