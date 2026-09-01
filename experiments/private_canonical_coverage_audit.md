# Private canonical coverage audit

## Purpose

LOAM now has several read-only private dogfood paths, but those paths answer different questions. Before starting a household-facing application layer, this checkpoint asks a narrower practical question:

> How much of the current canonical household source can LOAM already observe honestly, and which parts remain outside direct private shadow coverage?

This is not Observation 085. It introduces no new ontology, schema, persistence stream, or application command.

The audit intentionally distinguishes four levels that are easy to blur:

```text
source shape is visible
    !=
semantic distinction is understood
    !=
identity is stable across runs
    !=
information is ready for a concrete application operation
```

A source family may be useful for one read-only question without being losslessly importable or writable by LOAM.

## Evidence used

This checkpoint consolidates only already-recorded public evidence from the current private dogfood boundary:

- whole-file quantity shadow and native quantity parity;
- source-shape summary around projected quantities versus deliberately unprojected source evidence;
- explicit Plan-realization shadow;
- explicit Series-membership shadow;
- refund-provenance pressure;
- Event-versus-Effect descriptive-context scope dogfood;
- imported-identity observations 074–078;
- the context-relative sufficiency checkpoint 079–084.

No private descriptions, dates, quantities, identities, coordinates, policy values, notebook entries, source paths, hashes, or repository history are copied here.

## Reading levels

The table uses these terms:

- **Observed**: a current read-only private path has exercised the source family or distinction.
- **Characterized**: LOAM has an explicit semantic boundary for the selected question rather than only lexical recognition.
- **Continuity-safe**: the evidence needed by the selected question has stable identity across runs where cross-run identity matters.
- **Application-ready**: enough evidence exists for a named application operation without guessing missing meaning.

`Application-ready` is intentionally query-local. It never means that the whole source family has been modeled.

## Current coverage

| Source concern | Observed | Characterized | Continuity-safe | Current application reading |
| --- | --- | --- | --- | --- |
| Actual exact quantities and multi-Effect shape | strong | strong for quantity projection | only where identity is not observed, or where explicit stable identity exists | **ready for read-only quantity inspection** |
| Locus / Measure quantity coordinates | strong | strong as neutral physical coordinates | coordinate identity is not Effect identity | **ready for quantity queries, not an imported Account ontology** |
| Event-level human description channel | strong | scope boundary characterized | not a continuity question by itself | **usable only as Event-scope evidence; ontology deliberately unassigned** |
| Effect-level descriptive context | current source channel not established | possible distinction characterized by Observation 073 | not established | **not ready; do not reconstruct from prose or physical shape** |
| Plan records with explicit Plan identity | strong | partial, around identity and selected Plan structure | strong for the explicitly retained Plan identity under current source pressure | **ready for selected read-only Plan questions** |
| Plan -> Actual realization correspondence | strong | strong as independent linkage | explicit linkage is the evidence; physical matching is insufficient | **ready as a typed overlay for selected realization queries** |
| Series membership | strong | strong as independent grouping | explicit membership is the evidence; missing membership stays missing | **ready for selected membership queries** |
| Recurrence classification | observed alongside Plan / Series pressure | characterized as distinct from Series membership | not promoted to continuity identity | **usable as classification evidence, not as a recurrence engine** |
| Refund / reimbursement provenance | physical reversal pressure observed | strong negative boundary: physical reversal does not recover provenance | source correspondence not established by physical records alone | **not ready for answering which earlier Event was refunded unless explicit evidence is supplied** |
| Correction / Resolution semantics | strongly characterized in Practical Core and formal work | strong | typed relation identities exist in LOAM practical facts | **not yet evidence that the private canonical source can be losslessly imported into those streams** |
| Budget movement and movement provenance | no dedicated current private shadow checkpoint | not audited against the current private canonical family | not established | **not yet application-ready through private dogfood** |
| Budget / household policy | no dedicated current private shadow checkpoint | formal policy observations exist, but not equivalent to direct current private coverage | not established | **not yet application-ready through private dogfood** |
| Report / presentation policy | no dedicated current private shadow checkpoint | intentionally application-facing rather than neutral physical meaning | not established | **not required for the first neutral read operation** |
| Issue / notebook information | no dedicated current private shadow checkpoint | not characterized as a current LOAM private source family | not established | **not yet application-ready through private dogfood** |

## What "LOAM can read the household data" means today

For the best-exercised slice, the statement can already be strong:

```text
current canonical Actual quantity facts
    -> read-only parse
    -> neutral Event / Effect quantity projection
    -> current-run aggregate answer
```

The quantity dogfood has already compared LOAM's non-zero quantity projection with the native household accounting projection for the same canonical snapshot.

That makes a first read-only household application operation credible.

But a stronger statement would still be false:

```text
whole canonical household source
    -> one lossless LOAM semantic model
```

LOAM has not directly shadowed every current authority family, and the imported-identity boundary prevents pretending that source shape alone provides stable Event / Effect continuity.

The accurate checkpoint is therefore:

```text
Actual / Plan semantic pressure:
    broadly readable for several concrete questions

whole canonical household authority:
    not yet exhaustively readable

lossless import / replacement authority:
    not earned
```

## The remaining gaps are not all blockers

Context-relative sufficiency matters here.

The first application operation does not need to understand every source family. It needs enough retained evidence for the distinctions that operation observes.

So this would be a poor rule:

```text
shadow every private source family completely
    -> only then start an application layer
```

A better rule is:

```text
choose one application question
    -> identify the source distinctions it observes
    -> require honest coverage for those distinctions
    -> fail closed on everything else
```

This allows application work to become a new source of semantic pressure rather than waiting for an imaginary complete ontology.

## Recommended first application boundary

The safest first household-facing application experiment is read-only:

```text
inspect current exact quantities
```

Its intended path is:

```text
private canonical source
    -> existing read-only quantity adapter
    -> neutral LOAM quantity projection
    -> thin typed application presentation
```

This operation is attractive because:

- the underlying quantity projection has the strongest real-data parity evidence;
- it can use run-local identity because the selected query is identity-renaming-invariant;
- it does not require LOAM to claim canonical write authority;
- it does not require Plan, Series, refund, policy, notebook, or descriptive ontology to be solved first;
- unsupported source evidence can remain explicitly outside the selected projection.

The first application experiment should therefore be a **reader**, not an importer and not a writer.

## What should block a future writer

A future operation that records or mutates canonical household facts has a stronger burden.

Before LOAM may honestly write or retain continuity-sensitive imported state, it must not derive stable Event / Effect identity from:

- mutable content;
- source line or presentation position;
- quantity coordinates;
- textual resemblance;
- current-run generated identity.

The identity owner and publication authority for the specific operation must be explicit.

So application-layer progress should separate:

```text
read-only application entrance
    !=
lossless importer
    !=
canonical writer
```

## Next pressure after the first reader

Once the first read-only quantity application is usable, the next source family should be chosen by an actual household question rather than by file order.

Examples of pressure that could justify a new private observer include:

- a household operation that needs Budget movement provenance;
- a Plan operation that requires lifecycle evidence beyond the currently observed realization / Series questions;
- an Issue-facing operation that needs notebook information;
- a report operation whose answer depends on retained household policy rather than physical quantity alone.

Each should remain typed and question-specific until a domain-independent law genuinely survives abstraction.

## Checkpoint

```text
Observation 085:          not introduced
Practical Core additions: 0
Persistence additions:    0
CLI additions:            0
wire-format additions:    0
private canonical writes: 0
```

The architectural conclusion is deliberately asymmetric:

> LOAM has enough real canonical coverage to begin a small read-only household application layer, but not enough evidence to claim complete canonical-source understanding or write authority.
