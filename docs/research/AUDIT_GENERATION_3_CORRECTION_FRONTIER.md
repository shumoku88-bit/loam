# Audit Generation 3 candidate: Correction Frontier topology

Status: **ACTIVE OBSERVATION, NO PRODUCTION CHANGE AUTHORIZED**

Baseline:

```text
6fdb058eda787414078cffa4597bb4583e93d62c
docs: add AI workbench entrance (#1213)
```

## Why this audit reopened

Generation 2 and the first Module Granularity Audit both closed with explicit
reopening rules. Since those checkpoints, `Loam/Application/CorrectionFrontier.lean`
has changed substantially, most notably through PR #1148, which introduced a
transient indexed implementation and general semantic correspondence to the
legacy reference specification.

The reopening pressure is not file size by itself. The current module now
contains three distinguishable responsibilities:

1. the production Correction semantic facade;
2. a transient indexed implementation used to accelerate admission and reads;
3. a large reference-specification correspondence proof body used to qualify the
   indexed implementation against the earlier list-based semantics.

This audit asks whether those responsibilities still have one physical reason to
change.

## Root question

> After the Phase 3H correction linearization, does one physical
> `CorrectionFrontier` module still best express the current ownership boundary,
> or has the successful optimization created an independently useful
> qualification boundary that should move out of the production semantic module?

This is a module-topology question first. It is not a request to alter Correction
semantics, canonical evidence, or the indexed algorithm.

## Tool choice

The AI Workbench selection policy points first to structural instruments:

```text
question: ownership / dependency / proof-obligation shape
    -> module dependency DAG + D2

not yet:
    Alloy      no unresolved structural possibility question
    TLA+/SPIN  no temporal or interleaving residual
    Lean       semantic correspondence is already proved
    DRAKON     execution order is not the current uncertainty
```

A D2 projection is therefore added as an audit instrument. It is evidence only.

## Obligation scaffold

```text
Does current CorrectionFrontier have one physical change reason?
|
+-- D1  Is it live production?
|       -> YES. Multiple Application/Review/Persistence consumers import it.
|
+-- D2  Is the indexed implementation production-relevant?
|       -> YES. NormalizedActualAdmission builds CorrectionFrontierIndex and
|          production correctionFrontierMemory? delegates through it.
|
+-- P1  Does indexed production preserve the prior semantics?
|       -> YES. PR #1148 proved general correspondence, including
|          correctionFrontierMemory?_eq_legacy.
|
+-- D3  Are the broad indexed-vs-legacy correspondence theorems consumed by
|       other production modules?
|       -> NO evidence found. Repository search finds the major
|          buildCorrectionFrontierIndex_*_eq and *_eq_legacy theorems only in
|          CorrectionFrontier.lean itself.
|
+-- D4  Is the legacy reference specification used as production authority?
|       -> NO evidence found. correctionFrontierMemoryLegacy? is referenced by
|          the Correction frontier benchmark and semantic correspondence test,
|          while ordinary production consumers use correctionFrontierMemory?.
|
+-- R1  structural
|       -> Would moving only reference-spec + correspondence qualification into
|          a separate verification-oriented module reduce navigation/change
|          coupling without hiding a law needed by production consumers?
|
+-- R2  structural
        -> If R1 succeeds, should the transient index remain beside the semantic
           facade, or does it itself have an independent implementation boundary?
```

R2 is deliberately downstream of R1. Do not split runtime implementation merely
because a three-box diagram can be drawn.

## Deterministic evidence collected

Current direct import/search evidence shows live consumers including:

- `NormalizedActualAdmission`
- `ActualReview`
- `BalanceReview`
- `QuantityInspection`
- `ConsumptionInspection`
- `ActualRoutingInspection`
- `CapacityWindowInspection`
- `CurrentQuantityAnchor`
- `RoleBalanceReview`

The transient index is also directly used by
`NormalizedActualAdmission.admitActualImage?`, so the optimized path is not a
test-only implementation.

By contrast, repository search for these correspondence theorem names returns
only `Loam/Application/CorrectionFrontier.lean`:

- `buildCorrectionFrontierIndex_acyclic_eq`
- `buildCorrectionFrontierIndex_endpointUnique_eq`
- `buildCorrectionFrontierIndex_referencesClosed_eq`
- `buildCorrectionFrontierIndex_admissible_eq`
- `correctionFrontierMemoryIndexed?_eq_legacy`
- `correctionFrontierMemory?_eq_legacy`

This does not yet prove that extraction is desirable. It establishes a concrete
independent qualification surface worth testing.

## Candidate topology

The first candidate intentionally moves no semantics:

```text
Production consumers
        |
        v
CorrectionFrontier
  semantic facade
  + transient index implementation
        |
        | qualified by
        v
CorrectionFrontier correspondence module
  legacy reference specification
  indexed <-> reference proofs
        ^
        |
 benchmark / semantic qualification tests
```

The candidate boundary is accepted only if production imports become no broader,
the public Correction API remains unchanged, and the extracted qualification
module has an independently understandable reason to exist.

## Falsification conditions

Reject the split if any of these becomes true during an implementation
experiment:

1. production callers require the reference specification or broad correspondence
   lemmas for ordinary construction;
2. moving the proof body creates circular imports or a forwarding facade that is
   harder to understand than the current file;
3. the split duplicates semantic definitions merely to avoid an import edge;
4. qualification tests become less direct;
5. source navigation gains another file without reducing responsibility density;
6. the production theorem boundary becomes weaker or relies on an unqualified
   assumption.

A rejected split is a successful audit result if it records why the current
boundary is earned.

## Next experiment

Perform one narrow branch-only extraction experiment:

1. keep the public production API and indexed runtime implementation unchanged;
2. move only the legacy reference specification and the proof chain whose purpose
   is indexed-vs-reference correspondence;
3. route the benchmark and semantic correspondence test through the extracted
   qualification module;
4. run the ordinary build, Correction semantic tests, benchmark compile path,
   Normalized Actual qualification, Compression Audit, Module Granularity Audit,
   and Selected Lean Observations;
5. compare import topology and source responsibility before deciding KEEP or
   SPLIT_QUALIFIED.

Do not merge merely because the branch becomes green. Green CI answers
preservation, not whether the physical boundary is better.

## Stop point

This observation does **not** justify:

- changing Correction semantics;
- replacing the transient index;
- changing canonical Actual persistence;
- adding another retained authority;
- introducing a generic optimization/proof framework;
- splitting `ReplacementFrontier`;
- starting a repository-wide file-size cleanup.

The only live question is whether Phase 3H's successful qualification apparatus
has earned one independent physical module boundary.
