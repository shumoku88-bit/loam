# LOAM household dogfood checkpoint

This checkpoint records the household-facing arc reached after Observation 104 and Applications 010–014, together with the later authority transition that made LOAM the sole active household system.

It supplements [`OBSERVATION_MAP.md`](../../../OBSERVATION_MAP.md). Detailed evidence remains in the individual experiment and application records.

## Why this checkpoint matters

LOAM began by refusing to assume familiar household nouns such as Account, Transaction, Budget, Envelope, Month, or Report as physical primitives.

The dogfood asked a stronger practical question:

> Can useful household-accounting behavior be reconstructed from a smaller set of neutral facts, explicit relations, question-local configuration, and independently qualified projections?

The answer became positive for a meaningful but bounded slice of ordinary use, and later household operation moved fully onto LOAM.

## Practical quantity path

The practical balance path composes:

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

Application 010 separates current balance selection from canonical quantity evidence. `config/balance-view.tsv` is replaceable application configuration, not an Account registry or canonical history.

Observation 104 and Application 011 then close a dogfood double-counting seam. A basis may explicitly state that it already reflects an Event correction-root occurrence. The relation is between correction roots on both sides, so later correction of either retained family does not require rewriting the relation.

This earns neither a global chronology nor Date/Time fields in Core Event. File order, EventMemory order, and Git history remain non-semantic.

See:

- [`experiments/application_010_replaceable_balance_view.md`](../../../experiments/application_010_replaceable_balance_view.md)
- [`experiments/104_basis_cut_by_occurrence_root.md`](../../../experiments/104_basis_cut_by_occurrence_root.md)
- [`experiments/application_011_basis_cut.md`](../../../experiments/application_011_basis_cut.md)

## Read-only household day

Applications 012–014 historically used an external canonical household source as read-only pressure without importing its ontology into LOAM Core.

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

- [`experiments/application_012_shadow_day_reader.md`](../../../experiments/application_012_shadow_day_reader.md)
- [`experiments/application_013_shadow_scheduled_day_reader.md`](../../../experiments/application_013_shadow_scheduled_day_reader.md)
- [`experiments/application_014_shadow_home_day_composition.md`](../../../experiments/application_014_shadow_home_day_composition.md)

## What real-data dogfood established

Private canonical household data exercised the following boundaries locally:

- whole-file quantity projection through run-local neutral identity;
- native non-zero quantity parity for the qualified quantity question;
- practical LOAM balance dogfood with explicit starting basis and correction-aware quantity;
- replaceable balance selection independent of basis presence;
- basis-cut evidence sufficient to remove a concrete double-counting mismatch without introducing chronology;
- recorded-day output corresponding to the native household day Actual section for inspected dogfood days;
- scheduled-day output for both an empty selected day and a future selected day already known at the observation horizon;
- one terminal interaction composing recorded and scheduled views.

Private household values, descriptions, identities, and paths were not copied into public qualification fixtures.

These results are parity for the questions actually asked. They do not establish lossless import or full semantic equivalence with HRA / h-kernel.

The one-off private comparison observers used to establish context scope, Series pressure, Plan-realization sufficiency, and refund provenance were later retired from `main` after their role was captured in repository evidence. Generic read-only shadow adapters remain available only where they still answer an independent research question.

## Current authority boundary

```text
LOAM
    = sole active household system
    = canonical household Actual authority

HRA / h-kernel
    = historical and research comparators
    ≠ operational fallback
    ≠ compatibility target
```

Household facts are no longer intentionally duplicated into HRA or h-kernel. A future comparison against those systems is research pressure only and must not recreate a second household authority.

The sealed historical-admission snapshot and receipt remain migration provenance. Retiring an old runtime or observer does not erase the finding or source boundary it established.

## What was still deliberately missing at the Observation 104 checkpoint

The following list is historical frontier context, not a current backlog. Later observations may already have qualified or implemented some items:

- effective-day interpretation where correction/reversal semantics matter;
- complete source include-graph traversal where a query actually needs it;
- issue / attention views;
- cycle-relative questions;
- month-relative questions;
- per-Locus and per-use history;
- category or other classification questions when they become observable;
- richer planned-payment questions such as overdue/upcoming and recurrence generation;
- envelope / entitlement behavior;
- a compact human editor/TUI for the growing projection set.

Each capability should still be introduced from a concrete household question. Historical HRA or h-kernel behavior may supply pressure, but their type taxonomies do not determine LOAM representation.

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

The checkpoint does not prove that Account, Plan, temporal, Issue, or Envelope concepts will never be earned. It establishes only that several real household capabilities were reconstructed without promoting those familiar nouns into the neutral Core.

Further work should resume from new LOAM dogfood pressure rather than from preserving retired-system compatibility or a speculative feature checklist.
