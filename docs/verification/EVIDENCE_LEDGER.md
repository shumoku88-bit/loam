# LOAM Evidence Ledger

## Purpose

This ledger records a small set of claims whose evidence should remain visible as
LOAM changes.

It is deliberately **not** a theorem inventory, proof-coverage percentage, test
catalogue, or second source of truth. Its job is narrower:

> for an important claim, say what kind of evidence supports it, how that
> evidence reaches production, and what trust edge remains.

A Lean theorem, a conformance test, a qualified experiment, and a human-reviewed
correspondence bridge are different kinds of evidence. This file keeps those
differences visible instead of flattening all of them into "verified".

The ledger is selective. A row belongs here when losing track of its evidence
class would make a future design or maintenance decision materially worse.

## Evidence vocabulary

| Evidence | Meaning |
| --- | --- |
| `kernel proof` | Lean checks a theorem about the stated definitions. |
| `production correspondence proof` | A Lean theorem directly relates a production acceleration or representation to its canonical semantics. |
| `conformance/test` | Executed examples or external vectors agree with expected behaviour. This is not a proof of all cases. |
| `qualified experiment` | A focused experiment established what a tool or boundary does and does not justify. |
| `human-reviewed bridge` | A deliberately small semantic mapping remains a human trust edge. |
| `external assumption` | Correctness depends on a component or fact LOAM does not prove itself. |

## Status vocabulary

| Status | Meaning |
| --- | --- |
| `proved` | The stated claim is mechanically established within its explicit hypotheses. |
| `qualified` | The evidence establishes a bounded capability or limitation, not full production correctness. |
| `tested` | Behaviour is supported by tests or conformance evidence only. |
| `reviewed` | The remaining evidence is intentionally human review. |
| `open` | The claim is worth tracking but its requested evidence is not yet present. |

## Ledger

| Claim / surface | Evidence | Production correspondence | Remaining trust edge | Status | Source |
| --- | --- | --- | --- | --- | --- |
| A transient finite-keyed hash lookup preserves the canonical first-match list lookup when the hash-key projection is injective. | `kernel proof`: `FiniteKeyed.hashIndexBy_get?_eq_findBy?` | The generic index is explicitly derived acceleration; the finite list remains canonical. Production adapters reuse this theorem rather than re-proving local hash/list equivalence. | Correctness of the stated injectivity witness; Lean kernel/toolchain. | `proved` | [`Loam/Core/FiniteKeyed.lean`](../../Loam/Core/FiniteKeyed.lean) |
| The transient Event index used by relation-discharge lookup is extensionally identical to `EventMemory.findById?`. | `production correspondence proof`: `buildEventIndex_get?_eq_findById?` | Direct theorem over the production helper, discharged through the generic `FiniteKeyed` correspondence theorem. | `EventId.token` injectivity witness; Lean kernel/toolchain. | `proved` | [`Loam/Application/RelationDischargeFrontier.lean`](../../Loam/Application/RelationDischargeFrontier.lean) |
| The transient source-coverage hash index used by the open-relation frontier returns exactly the direct semantic aggregation for every raw relation list and queried source. | `production correspondence proof`: `buildCoverageIndex_getD_eq_currentCoverageFor` | Direct theorem relating the production acceleration structure to the list aggregation it replaces. | Lean kernel/toolchain. | `proved` | [`Loam/Application/OpenRelationFrontier.lean`](../../Loam/Application/OpenRelationFrontier.lean) |
| An implementation-independent semantic statement can be connected to the production Scheduled boundary without pretending the correspondence edge disappears. | `qualified experiment` + `human-reviewed bridge`: Observations 237–238 | A small explicit bridge can connect independent meaning to production, but Comparator acceptance cannot establish that the independent statement was derived from production semantics. | Human review of independent meaning -> production mapping. | `reviewed` | [verification boundary checkpoint](../experiments/verification-boundary-checkpoint.md), [Observation 238](../../experiments/238_comparator_production_correspondence.md) |
| Comparator can qualify exact statement identity and permitted-axiom policy for the tested exported proof boundary. | `qualified experiment`: Observations 165–167 | This qualifies statement comparison, axiom restriction, and replay. It does **not** establish production correspondence. | Comparator/export integration and the reviewed statement itself. | `qualified` | [verification boundary checkpoint](../experiments/verification-boundary-checkpoint.md) |
| A second checker can add checker diversity for the tested Comparator artifact without erasing semantic trust edges. | `qualified experiment`: Observation 168 with Nanoda | Independent kernel acceptance strengthens evidence for that exported artifact only. | Export path, checker implementations, temporary `propext` allowance, and semantic correspondence outside the proof artifact. | `qualified` | [verification boundary checkpoint](../experiments/verification-boundary-checkpoint.md) |

## Rules for maintaining this file

1. **Do not turn it into an exhaustive theorem list.** Ordinary local lemmas stay
   with the code.
2. **Do not upgrade evidence by wording.** Tests remain tests; a qualified tool
   remains qualified; a human bridge remains human-reviewed.
3. **Prefer one durable row over many implementation-detail rows.** If several
   proofs discharge the same stable claim, point to the smallest useful evidence
   surface.
4. **Update a row when its evidence class changes.** For example, a
   human-reviewed bridge may become a production correspondence proof, or a
   tested property may gain a theorem.
5. **Keep the trust edge explicit.** A row with no remaining trust edge should be
   rare and must not silently mean "the whole product is verified".
6. **Remove stale rows rather than preserving archaeology here.** Git history and
   research checkpoints own historical detail.

## Why there is no coverage percentage

LOAM currently has no single honest denominator comparable to a specification
whose surface is a uniform set of functions.

Its evidence crosses several boundaries:

```text
human intent
    |
independent meaning
    |
production correspondence
    |
implementation
    |
proof / test / conformance
    |
checker or runtime
```

A single percentage would collapse materially different questions into one
number. If a future subsystem develops a natural denominator, it may own a local
coverage metric without making that number a project-wide verification score.

## Automation policy

There is intentionally no ledger checker yet.

The ledger should first prove useful as a small human-readable map. Add
automation only after a concrete drift mode appears, such as:

- repeated stale source references;
- a mechanically detectable status/evidence mismatch;
- an important claim repeatedly losing its production correspondence link.

Until then, a new framework would cost more repository surface than the evidence
requires.
