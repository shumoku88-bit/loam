# LOAM Evidence Atlas

This page collects a few cases where a question about LOAM's production design was followed from observation to evidence and, when justified, to a production change.

It is not a claim that LOAM is fully formally verified.

The aim is smaller: to make a few design decisions inspectable.

## How investigations work

A typical investigation may look like this:

```text
production path or question
        ↓
source inspection / DRAKONview
        ↓
small obligations or counterexamples
        ↓
Lean / Alloy / TLA+ / tests / other evidence
        ↓
KEEP / SIMPLIFY / REPAIR
        ↓
production change, when justified
```

This is not a required pipeline.

The tool should follow the question. Sometimes source inspection is enough. Sometimes a diagram, model, proof, or test is useful. Sometimes the result is simply KEEP.

## Development process

LOAM is developed with extensive assistance from AI systems.

I do not personally write the formal-method artifacts or production code used in these investigations. AI systems generate that material.

My part is mainly to choose and refine questions, inspect the resulting structure and behavior, ask for stronger evidence where needed, and decide whether a proposed change is justified.

Machine-checked artifacts here should be read as evidence checked by their respective tools, not as a claim about my personal formal-methods expertise.

## Three examples

### G2-010 — Scheduled Creation / Replacement

**Question**

Two Scheduled writers looked similar when drawn at the same scale. Was one of their repeated runtime decisions actually necessary?

**Observation**

Both contained the same positive-total admission decision:

```text
positiveTotalQuanta movement > 0 ?
```

Their input had already been admitted as a `BalancedMovement`, and both writers independently established that the movement was nonempty and all retained quantities were nonzero.

**Evidence**

Lean establishes that those retained conditions already imply the existence of a positive side:

```text
positiveTotalQuanta_pos_of_nonempty_nonzero
```

**Result**

The duplicated runtime decision was removed from both paths.

The writers themselves remain separate because Replacement still has independent source and lifecycle obligations.

**Verdict:** `SIMPLIFY + KEEP`

This does not prove the whole Scheduled subsystem correct. It establishes one local implication strongly enough to remove one local decision.

Evidence: [obligation DAG](research/SCHEDULED_CREATION_REPLACEMENT_OBLIGATION_DAG.md) · [Lean theorem](../Loam/ScheduledOccurrenceConstruction.lean) · [production change #930](https://github.com/shumoku88-bit/loam/pull/930) · [DRAKON source](drakon/build_scheduled_creation_replacement_audit_map.py)

---

### G2-004 — Stock Flow / Transactions Flow

**Question**

Could one composed report observe two different generations of the same Actual authority?

**Observation**

Stock Flow performed two individually valid Actual reads during one answer. Nothing required the selected Actual generation to remain unchanged between them.

**Result**

The two reads were placed inside one short Actual observation interval.

Similar-looking date validation remains separate where it serves a different semantic purpose.

**Verdict:** `REPAIR + KEEP`

This is a local authority-boundary repair, not a general snapshot-isolation claim.

Evidence: [obligation DAG](research/FLOW_REVIEW_OBLIGATION_DAG.md) · [production source](../Loam/StockFlowReview.lean) · [production change #917](https://github.com/shumoku88-bit/loam/pull/917) · [DRAKON source](drakon/build_flow_review_audit_map.py)

---

### G2-009 — Attention

**Question**

Attention already had a read path, but it was not practically writable. Was the model wrong, or was a path missing?

**Observation**

The existing read spine was retained:

```text
Core
↓
Persistence
↓
Application
↓
AttentionReview
↓
TUI
```

The missing part was a production writer.

**Result**

A small write path was added:

```text
TUI
↓
HouseholdCommand
↓
AttentionPublisher
↓
WriterOwnership
↓
attention.loam
```

The initial writer supports only `Add`, `Resolve`, and `Drop`.

**Verdict:** `KEEP + ADD MISSING PATH`

The audit did not make the system smaller. It found that the smallest justified change was to add a missing connection.

Evidence: [obligation DAG](research/ATTENTION_DELIVERY_OBLIGATION_DAG.md) · [production writer](../Loam/AttentionPublisher.lean) · [production change #927](https://github.com/shumoku88-bit/loam/pull/927) · [DRAKON source](drakon/build_attention_delivery_audit_map.py)

## Evidence labels

The labels used here are intentionally narrow:

- `OBSERVED` means a property or pressure was found through source, runtime, or diagram inspection.
- `PROVED` means a stated proposition was checked by a proof assistant under stated assumptions.
- `MODEL-CHECKED` means a specified model was explored by a model checker.
- `TESTED` means executable behavior was checked by tests.
- `PRODUCTION` means the relevant change is present in a production path.

A local theorem should not be read as proof of an entire subsystem.

## Generation 2 index

Generation 2 currently includes:

```text
G2-001  Actual Review
G2-002  Balance Review
G2-003  Balance Review shared quantity world
G2-004  Stock Flow / Transactions Flow
G2-005  Role Balance
G2-006  Role Balance quantity worlds
G2-007  Liquidity / Budget Window
G2-008  Accounting Role / Actual Routing
G2-009  Attention
G2-010  Scheduled Creation / Replacement
```

Detailed DRAKON sources, obligation DAGs, proof artifacts, production code, pull requests, and qualification results remain in their existing repository locations.

This page is only an index into that evidence.

## Limits

This Atlas does not claim that:

- LOAM is completely formally verified;
- every production behavior has a formal model;
- every theorem captures all surrounding runtime behavior;
- passing CI proves semantic correctness;
- these methods replace specialist review or certification;
- a method useful in LOAM will transfer unchanged to another system.

LOAM remains an ongoing personal project and research environment.

## Supporting the work

LOAM is developed in public.

I may also be interested in small, clearly scoped investigations of existing software, such as one read path, write path, authority boundary, or branch-heavy subsystem.

The aim would not be certification or complete formal verification.

The aim would be to examine one concrete question, make the relevant structure visible, use stronger evidence where useful, and report what the evidence supports.

Small scopes are preferred.
