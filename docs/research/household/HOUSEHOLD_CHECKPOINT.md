# LOAM household dogfood checkpoint

Status: **CURRENT DISTILLATION — historical dogfood findings retained, retired quantity machinery removed**

This checkpoint records the household-facing arc that began around Observation 104 and Applications 010–014, then follows the authority transition that made LOAM the sole active household system.

Exact historical probes, old ontology, and migration-era implementation details remain recoverable in Git history. Current working-tree documentation should describe the surviving laws and the current Product boundary rather than require retired experiments to remain present.

It supplements [`OBSERVATION_MAP.md`](../../../OBSERVATION_MAP.md).

## Why this checkpoint matters

LOAM began by refusing to assume familiar household nouns such as Account, Transaction, Budget, Envelope, Month, or Report as physical primitives.

The dogfood asked a stronger practical question:

> Can useful household-accounting behavior be reconstructed from a smaller set of neutral facts, explicit relations, question-local configuration, and independently qualified projections?

The answer became positive for a meaningful but bounded slice of ordinary use, and household operation later moved fully onto LOAM.

## Historical quantity path — retired

The Observation 104 era used this practical balance path:

```text
Event / EventCorrection
QuantityBasis / QuantityBasisCorrection
        +
already-reflected occurrence-root cut
        +
replaceable balance-view coordinates
        ↓
CurrentQuantity
        ↓
human balance view
```

That path established two durable distinctions:

- replaceable balance selection is not canonical quantity evidence;
- avoiding double counting requires explicit evidence about what starting-state material already reflects, rather than inferring chronology from file order, EventMemory order, or Git history.

QuantityBasis, QuantityBasisCorrection, BasisCut, and their current-quantity production path have since retired. Observation 104's executable occurrence-root-cut probe was migration-era evidence for that retired design and no longer owns a current Product contract.

The exact old source remains in Git history. Application 010/011 material may still be consulted as historical context while it remains in the tree, but it must not be read as current household authority.

## Current quantity path

The current household balance path is instead:

```text
selected Movement manifest
        ↓
Event / EventCorrection
        +
explicit ZeroOriginCoverage
        +
replaceable balance-view coordinates
        ↓
ZeroOriginQuantity
        ↓
BalanceReview
```

The surviving rules are owned near current Product:

- `MovementManifestAuthority` selects the current Movement world;
- `ZeroOriginCoverage` is explicit evidence that a selected coordinate has complete zero-origin history;
- Event correction remains fail-closed through the current correction frontier;
- `config/balance-view.tsv` chooses presentation coordinates only and does not manufacture completeness;
- missing origin evidence remains different from a known zero quantity;
- `BalanceReview` composes the current evidence without falling back to retired sidecar or QuantityBasis authority.

This is an intentional semantic change from the old starting-basis path, not merely a rename.

## Read-only household-day findings

Applications 012–014 historically used an external canonical household source as read-only pressure without importing its ontology into LOAM Core.

The useful surviving distinctions were:

```text
selected day
    -> recorded-day projection

selected day + knowledge horizon
    -> scheduled-day projection

those two answers
    -> terminal composition
```

Source account-looking tokens could remain neutral Locus tokens, quantity-bearing postings could remain neutral Effects, and one screen did not require a canonical `HouseholdHome` or `Day` aggregate.

These were bounded query results, not proof of lossless import or full semantic equivalence with HRA / h-kernel.

## What real-data dogfood established

Private household data historically exercised:

- whole-file quantity projection through neutral identity;
- non-zero quantity parity for the then-qualified starting-state question;
- replaceable balance selection independent of canonical quantity evidence;
- an explicit old BasisCut sufficient to remove one concrete double-counting mismatch without introducing chronology;
- recorded-day and scheduled-day projections for inspected dogfood cases;
- terminal composition of the two day views.

Those points are historical evidence. The current household quantity contract is the ZeroOrigin path described above.

Private household values, descriptions, identities, and paths were not copied into public qualification fixtures.

One-off private comparison observers were later retired after their findings were distilled. Generic read-only adapters should remain only while they answer an independent current question.

## Current authority boundary

```text
LOAM
    = sole active household system
    = canonical household Actual authority

HRA / h-kernel
    = historical and research comparators
    != operational fallback
    != compatibility target
```

Household facts are no longer intentionally duplicated into HRA or h-kernel. A future comparison against those systems is research pressure only and must not recreate a second household authority.

Retiring an old runtime, observer, ontology, or migration proof does not erase the result it established. Current rationale belongs beside current Product; exact exploration belongs in Git history.

## Historical frontier context

At the Observation 104 checkpoint, still-open pressures included effective-day interpretation, source include traversal, Issue/Attention views, cycle/month questions, per-Locus history, classification, richer Scheduled behavior, entitlement behavior, and a compact editor/TUI.

That list is historical context, not a current backlog. Later work has qualified or implemented several of those areas. New work should be selected from current LOAM dogfood pressure rather than by completing an old checklist.

## Compactness checkpoint

The working direction remains:

```text
small retained facts / relations
        ↓
question-specific admission and projection
        ↓
independent views
        ↓
terminal composition
```

rather than one large household domain model created in advance.

The checkpoint does not claim that familiar concepts can never be earned. It records that several real household capabilities were reconstructed without requiring those concepts as neutral Core primitives, and that retired research machinery need not remain live once its surviving meaning has moved to current owners.
