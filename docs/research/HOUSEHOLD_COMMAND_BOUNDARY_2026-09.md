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

Read topology remains a separate audit question. A future query boundary is justified only if it removes independently repeated frontend knowledge without hiding useful low-level diagnostic entrances.

## Current result

The TUI write path no longer chooses publisher authority files before publication. Existing publisher Draft and Receipt types remain the shared contracts, while canonical production path selection has one owner above those publishers.
