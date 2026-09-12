# Household command boundary

Status: implementation audit checkpoint

The production TUI historically called presentation-neutral publishers directly, but it also selected canonical physical files such as `scheduled.loam`, `capacity.loam`, and routing authorities. That made the publisher semantics reusable while leaving production topology coupled to the TUI.

This change introduces `Loam.HouseholdCommand` as a deliberately thin production command port for presentation surfaces.

## Boundary rule

High-level frontends choose one household root and submit existing publisher Draft values. `HouseholdCommand` selects canonical production paths and delegates to the existing publisher. It does not own domain validation, authoritative re-read, identity, writer ownership, serialization, recovery behavior, or a second copy of canonical state.

Intended high-level consumers include the production TUI, a future high-level CLI, GUI adapters, and AI adapters.

Low-level diagnostic CLIs may continue to call publishers with explicit arbitrary file paths when that explicit path selection is part of their independent role.

## Non-goals

This change does not create a new semantic engine, translate Draft or Receipt values into compatibility types, or move read/query projections into the command boundary.

Read topology is deliberately asymmetric with write topology. A single generic `HouseholdQuery` service is not justified merely because there is one `HouseholdCommand` write port.

## Read-side audit verdict

Read questions already have different semantic owners and independent reasons to change. Balance, Capacity, Scheduled lifecycle, conditional balance paths, current coverage, routing review, and administration candidates should therefore remain query-specific Review boundaries rather than being gathered into one service layer.

The rule established by the audit is:

- a query-specific Review owns its projection semantics;
- a Review may also own canonical household file selection when high-level callers would otherwise repeat that physical topology;
- explicit-path entrances remain available when arbitrary-path inspection is part of a low-level diagnostic or scriptable CLI contract;
- a new Review is justified when a frontend is composing multiple authorities or projections to answer one presentation-neutral question that another frontend would otherwise have to reconstruct;
- future GUI or AI use alone is not sufficient evidence for an abstraction.

Applied results:

- `CapacityReview` now provides a canonical household-root entrance while retaining its explicit-path entrance;
- `ScheduledReview` now owns canonical `scheduled.loam` selection for household-oriented reads while preserving the separate Actual source distinction and explicit-path diagnostic entrance;
- `AccountingRoleReview` owns the canonical evidence composition for the initial-role candidate query, while eligibility semantics remain the existing `AccountingRolePublisher.eligibleInitialLoci` pure projection;
- `OperationalContinuity` and `ConditionalBalancePathReview` no longer choose the canonical Scheduled file themselves.

Deliberate deferrals:

- `AttentionReview` has no second high-level production consumer yet, so adding a root wrapper now would be speculative;
- `ScheduledBalanceCli` composes Scheduled evidence with replaceable balance-view configuration, so hiding only one filename would not remove its actual composition responsibility; it should be reconsidered only if that query is reused or its ownership otherwise becomes independently justified;
- remaining TUI calls that can use the new Capacity or Scheduled household entrances are mechanical caller migration, not evidence for a generic query service.

## Current result

The TUI write path no longer chooses publisher authority files before publication. Existing publisher Draft and Receipt types remain the shared contracts, while canonical production write-path selection has one owner above those publishers.

On the read side, canonical topology is being moved into the existing query-specific Review that already owns the corresponding semantics, or into a dedicated Review only where the frontend had acquired a real cross-authority query. No parallel read semantic engine, generic DTO family, compatibility layer, or `HouseholdQuery` umbrella has been introduced.
