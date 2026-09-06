# LOAM household dogfood checkpoint

This checkpoint records the practical household-facing state reached after Observation 104 and Applications 010–014.

It supplements [`OBSERVATION_MAP.md`](OBSERVATION_MAP.md), whose integrated historical map currently closes at Observation 084. Detailed evidence remains in the individual experiment and application records.

## Why this checkpoint matters

LOAM began by refusing to assume familiar household nouns such as Account, Transaction, Budget, Envelope, Month, or Report as physical primitives.

The current dogfood asks a stronger practical question:

> Can useful household-accounting behavior be reconstructed from a smaller set of neutral facts, explicit relations, question-local configuration, and independently qualified projections?

The answer is now positive for a meaningful but still bounded slice of ordinary use.

## Practical quantity path

The practical balance path now composes:

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

Application 010 separates current balance selection from canonical quantity evidence. `balance-view.tsv` is replaceable application configuration, not an Account registry or canonical history.

Observation 104 and Application 011 then close a dogfood double-counting seam. A basis may explicitly state that it already reflects an Event correction-root occurrence. The relation is between correction roots on both sides, so later correction of either retained family does not require rewriting the relation.

This earns neither a global chronology nor Date/Time fields in Core Event. File order, EventMemory order, and Git history remain non-semantic.

See:

- [`experiments/application_010_replaceable_balance_view.md`](experiments/application_010_replaceable_balance_view.md)
- [`experiments/104_basis_cut_by_occurrence_root.md`](experiments/104_basis_cut_by_occurrence_root.md)
- [`experiments/application_011_basis_cut.md`](experiments/application_011_basis_cut.md)

## Read-only household day

Applications 012–014 use an external canonical household source as read-only pressure without importing its ontology into LOAM Core.

Application 012 answers one narrow question:

```text
what was recorded on this selected day?
```

Source date and human context remain adapter-local. Source account-looking tokens become neutral Locus tokens; quantity-bearing postings become neutral Effects with run-local identity. The reader is explicitly recorded-day, not effective-day, and it does not follow source `include` directives yet.

Application 013 separately answers:

```text
what is scheduled for this selected day
as known through this horizon?
```

It retains only the distinctions that change that answer: scheduled identity, scheduled day, neutral Effects, explicit completion or retirement evidence, known-through horizon, and selected day. It does not import recurrence, Series, AccountType, report policy, or a Core Plan type.

Application 014 then composes the two already-qualified questions at the terminal boundary:

```text
selected day ───────┬──> recorded-day projection
                    │
known-through ──────┴──> scheduled-day projection
                              ↓
                    one household-day view
```

No canonical HouseholdHome or Day aggregate was required merely because the two answers appear on one screen.

See:

- [`experiments/application_012_shadow_day_reader.md`](experiments/application_012_shadow_day_reader.md)
- [`experiments/application_013_shadow_scheduled_day_reader.md`](experiments/application_013_shadow_scheduled_day_reader.md)
- [`experiments/application_014_shadow_home_day_composition.md`](experiments/application_014_shadow_home_day_composition.md)

## What real-data dogfood has established

Private canonical household data has exercised the following boundaries locally:

- whole-file quantity projection through run-local neutral identity;
- native non-zero quantity parity for the qualified quantity question;
- practical LOAM balance dogfood with explicit starting basis and correction-aware quantity;
- replaceable balance selection independent of basis presence;
- basis-cut evidence sufficient to remove a concrete double-counting mismatch without introducing chronology;
- recorded-day output corresponding to the native household day Actual section for inspected dogfood days;
- scheduled-day output for both an empty selected day and a future selected day already known at the observation horizon;
- one terminal interaction composing recorded and scheduled views.

Private household values, descriptions, identities, and paths are not copied into public qualification fixtures.

These results are parity for the questions actually asked. They do not establish lossless import or full semantic equivalence with HRA / h-kernel.

## Deliberate authority boundary

For the current dual-dogfood period:

```text
HRA canonical household source
    = authority for household truth

LOAM local data and entrances
    = dogfood, reconstruction experiment, and comparison target
```

The same real occurrence may therefore be recorded through both applications while this comparison remains useful. If the two disagree, the discrepancy is pressure on LOAM rather than a reason to rewrite the canonical HRA source to match LOAM.

The read-only adapters provide a path toward reducing duplicate entry later. That future convenience should not turn the HRA source taxonomy into LOAM Core ontology.

## What is still deliberately missing

This checkpoint does not yet claim a complete household application. Concrete remaining pressures include:

- effective-day interpretation where correction/reversal semantics matter;
- complete source include-graph traversal where a query actually needs it;
- issue / attention views;
- cycle-relative questions;
- month-relative questions;
- per-Locus and per-use history;
- category or other classification questions when they become observable;
- richer planned-payment questions such as overdue/upcoming and recurrence generation;
- envelope / entitlement behavior;
- a compact human editor/TUI for the growing projection set;
- deciding when LOAM should stop requiring duplicate entry and rely on read-only canonical-source observation for some questions.

Each should be introduced from a concrete household question. HRA may tell LOAM which capability is useful; HRA's type taxonomy does not automatically determine how LOAM represents that capability.

## Compactness checkpoint

The working direction is now:

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

The checkpoint does not prove that Account, Plan, temporal, Issue, or Envelope concepts will never be earned. It establishes only that several real household capabilities have already been reconstructed without promoting those familiar nouns into the neutral Core.

This is a natural stopping point. Further work should resume from new dogfood pressure rather than from a speculative feature checklist.
