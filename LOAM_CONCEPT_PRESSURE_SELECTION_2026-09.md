# LOAM Concept-Pressure Reselection — September 2026

Status: **four probes completed; no production concept earned; no C-level Core-shape failure found; F088 is next**

Baseline selection checkpoint: `2fca5beaed65224a8d29d586fcc6735404bf599f`

The first domain queue found independently observable distinctions:

```text
F051  known existence != exact quantity                COUNTEREXAMPLE
F033  quantity != future movement rights               COUNTEREXAMPLE
F001  pending lifecycle != temporary reservation       COUNTEREXAMPLE
F076  existing evidence composes sufficiently          ABSORBED
F055  recurrence shape != generation policy            COUNTEREXAMPLE
F086  reconstruction != external/physical assertion    COUNTEREXAMPLE
```

Those findings do **not** imply one production noun per distinction or a Core rewrite. This checkpoint asks a narrower architectural question:

> Can the missing information be composed or added conservatively while keeping existing Core meanings exact and narrow?

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

Application 006 remains the architectural null hypothesis:

```text
new independent evidence
  -> add a typed family
  -> old fact meanings remain unchanged
  -> old projections remain unchanged unless they opt in
```

A counterexample earns B at most until a concrete observation also falsifies conservative extension. C must be demonstrated, not inferred.

## Execution checkpoint

Four concept-pressure probes are complete.

### Observation 202 / F052

```text
exact amount knowledge != exact temporal placement
result: COUNTEREXAMPLE
architectural pressure: B at most
```

Future existence, exact quantity, and exact scheduled coordinate can be independently knowable before a complete `ScheduledOccurrence`. The current exact occurrence remains a valid completed fact.

### Observation 203 / F001 + F033 compression

The tempting flat view:

```text
operation -> usable quantity
```

does not preserve reservation provenance and operation-right provenance.

```text
result: COUNTEREXAMPLE to scalar compression
architectural pressure: B, not C
```

A common carrier may share mechanics, but if it retains both meanings it is packaging rather than semantic compression.

### Observation 204 / F051 + F052 pre-Scheduled packaging

Observation-local candidate:

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

Lower-bound attacks showed that explicit known existence, independent due evidence, and stable subject correspondence cannot simply be erased. But once stable subject identity plus subject-attached amount and due evidence are fixed, Alloy found no counterexample to the selected views in scope.

This is packaging compression, not a claim that existence, quantity, and time are one semantic dimension. No production `Expectation`, `Obligation`, `Claim`, `Bill`, `Subject`, or partial-record framework is earned.

### Observation 205 / F113 one-to-many correction topology

F113 deliberately attacked the current one-to-one `EventCorrection` boundary:

```text
one historical Event
  -> ChildA
  -> ChildB

ChildA and ChildB are jointly effective replacements
```

The selected query included relation provenance, not merely the fact that both child Events exist.

Dedicated Observation 205 Alloy CI succeeded on executable head:

```text
4363d402fe3148a8a314d258e78af3b71bb77cfa
workflow run 34009186374
```

The successful PR merge ref already incorporated then-current main `f0cecbec9ef0cb81a3be258ffd15434c6dc4eedc`.

Observed matrix:

```text
rawSiblingF113                               SAT
siblingPairRejectedByCorrectionAdmission     SAT
correctionOnlyJointReplacement               UNSAT
AdmittedCorrectionNamesAtMostOneChild        UNSAT counterexample
additiveRefinementWitness                     SAT
sameCorrectionDifferentRefinementProvenance   SAT
```

So F113 found genuine missing information:

```text
current admitted EventCorrection evidence
  -/-> one parent with two jointly effective replacement children
```

But a separate experiment-local `parent -> children set` relation can preserve that provenance while ordinary Correction remains admitted under its existing rules.

Therefore:

```text
Correction-only completeness     FALSIFIED
independent one-to-many evidence  YES
conservative additive candidate   SURVIVED
architectural pressure            B, not C
```

This does not earn a production `EventRefinement`, `SplitCorrection`, generic graph framework, or generic relation ontology. If real use later requires the fact, begin with a narrow additive family rather than weakening `EventCorrection`.

## Current classification

| Pressure | Current reading | Why |
|---|---|---|
| F051 + F052 pre-Scheduled knowledge | **B; bounded packaging compression survived** | Observation 204 packages selected partial future knowledge around stable subject identity without weakening exact `ScheduledOccurrence`. |
| F033 movement rights | **B; not scalar-compressible with F001** | Observation 203 shows current usable quantity cannot reconstruct future rights. |
| F001 temporary reservation | **B; not scalar-compressible with F033** | Observation 203 shows operational availability can hide different reservation provenance. |
| F113 one-to-many corrected interpretation | **B; additive relation survived** | Observation 205 shows current Correction cannot carry the provenance, but a separate relation can without changing Correction shape. |
| F055 recurrence boundary policy | **future B constraint** | No production recurrence generator currently owns this policy. |
| F086 external/physical assertion | **B-or-query-layer candidate** | Assertion is independent of reconstruction, but completeness/repair semantics remain untested. |
| F076 shared full refund | **A** | Existing burden + refund provenance + discharge compose. |

**No completed concept-pressure probe has demonstrated C.**

## Concept-pressure probes

These are architectural probes, not a second F-series Work authority. `LOAM_FALSIFICATION_PROGRESS.md` remains the Work/Finding authority for F001-F200.

### 1. F052 — Scheduled skeleton symmetry — COMPLETE

Observation 202 established:

```text
known existence != exact quantity
exact quantity  != exact temporal placement
```

B-level pressure only. Exact `ScheduledOccurrence` stays exact.

### 2. F001 + F033 — availability/admissibility compression — COMPLETE

Observation 203 falsified a flat scalar operational envelope as an information-equivalent replacement for reservation and rights evidence.

No production Hold/Capability nouns are earned.

### 2.5. F051 + F052 — pre-Scheduled subject-attached compression — COMPLETE

Observation 204 found a smaller bounded packaging candidate around stable subject identity with independently attachable amount/time evidence.

No production noun is earned.

### 3. F113 — one historical Event -> two jointly effective replacements — COMPLETE

Observation 205 confirmed both sides of the boundary:

```text
current Correction-only representation   too small
separate additive provenance relation     sufficient in bounded witness
```

This was the strongest selected C-seeking attack and it still landed at B.

### 4. F088 — discrepancy epistemic/repair boundary — NEXT

F086 established that physical/external assertion and reconstructed history are independent evidence. It deliberately did not decide what a conflict means.

F088 asks whether incomplete history must support distinctions such as:

```text
known complete reconstruction
vs
known incomplete / unknown reconstruction
vs
history repaired/padded by explicit policy
```

The probe should first ask whether assertion + explicit completeness/repair evidence can remain additive and query-local. Do not let `asserted != reconstructed` silently create an adjustment Event or mutate historical evidence.

Likely first instrument: Alloy.

## Structural relation

Structural S003 and S008 are complete.

S003 shows quantity-preserving Effect split/merge is invisible to `Event.quantityAt` while representation/provenance remains retained.

S008 shows that, after successful Correction-frontier admission, frontier membership is remembered-and-untargeted and does not depend on admitted linear path length.

Observation 205 adds complementary topology evidence: the current one-to-one Correction family should remain narrow even when a distinct one-to-many provenance fact is independently observable, because the latter can be added beside it.

S007 remains watchlist pressure and is not automatically promoted.

## What is deliberately not selected

F055 weekend/holiday and richer recurrence follow-ups remain later work because no production recurrence generator exists yet.

Broad inventory, tax, insurance, payroll, marketplace, BNPL, subscription, securities, and distributed-sync cases remain adversarial pressure, not a reason to grow vocabulary before smaller seams are understood.

## Decision rule

Do not call for a rewrite unless at least one concrete seam reaches C:

```text
1. selected query is legitimate and independently observable
2. existing evidence composition is insufficient
3. a separate conservatively added typed family is also insufficient
4. the failure specifically comes from the semantic shape of an existing Core family
```

So far every selected concept-pressure result has stopped at A or B.

## Recommended order

```text
1. F052                              COMPLETE
2. F001 + F033 compression          COMPLETE
2.5 F051 + F052 packaging probe     COMPLETE
3. F113                              COMPLETE
4. F088                              NEXT
```

The ordering is not a product roadmap. It is chosen to maximize the chance of avoiding unnecessary concepts before changing an established Core meaning.

## Current conclusion

```text
wholesale rewrite required                   NOT SUPPORTED
proven Core-shape failure                     NONE
selected C-seeking attacks survived Core      YES
possible additive concept seams               YES
F001/F033 flat scalar compression             FALSIFIED
F051/F052 state-noun packaging compression    SURVIVED IN BOUNDED SCOPE
F113 Correction-only completeness             FALSIFIED
F113 conservative additive representation     SURVIVED IN BOUNDED SCOPE
production concept earned by these probes     NO
next selected probe                           F088
```

The current evidence increasingly favors a small exact Core with independently earned additive evidence families rather than broadening established facts to absorb every new case.
