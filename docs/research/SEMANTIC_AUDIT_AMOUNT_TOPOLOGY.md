# Standalone Amount product-topology audit

Status: **AUDIT COMPLETE — DELETE IMPLEMENTED BY #740**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`
Related persistence audit: `docs/research/SEMANTIC_AUDIT_SA006_PERSISTENCE.md`
Production resolution: PR #740, merge `9d43f788579f8320defea2eef9822853f1726941`

## Question

SA-006 deliberately did not delete `AmountPersistence` merely because normal household execution did not use standalone Amount files. It deferred one narrower question:

> Does standalone Amount persistence still earn an independent low-level product role after Event/EventMemory and Movement became the practical plumbing path?

This is a product-topology/reachability question, not a semantic-codec compression question.

## Evidence

The standalone `LOAM-AMOUNT` format entered in PR #74 as LOAM's first practical persisted value. At the #740 checkpoint its remaining production topology was:

```text
AmountPersistence.save?   -> no production caller
AmountPersistence.load?   -> low-level `amount show` only
`amount show`             -> read-only; no paired producer command
```

No current practical household, TUI, Movement, publisher, review, or canonical-data path produced or consumed standalone Amount files.

By contrast, retained low-level Event plumbing is compositional:

```text
event create
    -> standalone Event file
    -> event quantity
    -> event-memory add
    -> event-memory get / review / quantity
```

The Core concept `SomeAmount` remains independently earned and widely live inside Effects. The audit therefore separated:

```text
SomeAmount semantic value        KEEP
standalone LOAM-AMOUNT wire      DELETE
read-only amount show entrance   DELETE
```

## Why no formal model was added

No semantic worlds were being merged and no crash/retry protocol changed. The claim was reachability and independent product usefulness. A Lean equivalence theorem, Alloy model, or TLA+ transition model would not answer that question better than the production call graph plus exact-head qualification.

The smallest appropriate instrument was therefore:

1. current production reachability inspection;
2. history check showing the surface began as the first practical persistence foothold;
3. candidate deletion;
4. exact-head regression of all retained low-level and production paths.

## Implementation

PR #740 removed:

- `Loam/Persistence/AmountPersistence.lean`;
- standalone `LOAM-AMOUNT` wire ownership;
- low-level `amount show` and its renderer/help/import surface;
- Amount-only persistence tests;
- Amount-only CI qualification.

It retained:

- Core `SomeAmount`, `Amount`, `MeasureId`, and `Quantity` semantics;
- Effect/Event quantity meaning;
- Event/EventMemory persistence and low-level plumbing;
- Movement and household production paths;
- writer ownership and correction behavior.

Candidate production delta was 4 files, +1 / -138, net -137, including one deleted persistence module.

## Qualification

The exact #740 head passed all triggered workflows:

- Practical Lean Core, including retained Event/EventMemory persistence and low-level CLI boundary;
- Practical Movement;
- Practical Correction Projection;
- Practical Writer Ownership on Ubuntu and macOS;
- Selected Lean Observations;
- Compression Audit.

No canonical household data changed.

## Verdict

`AmountPersistence` was not an independently necessary semantic concept. It was an early practical foothold whose standalone product role disappeared after richer Event/Movement plumbing became current.

The important subtraction rule is:

> A low-level object earns permanence by participating in a useful compositional path, not merely by being small, typed, versioned, and testable.

This does not prohibit a future standalone Amount interchange format from being re-earned by a concrete product need. At the #740 checkpoint, no such need exists.
