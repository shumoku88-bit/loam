# Application 029 — Generation-scoped physical read boundary

## Question

Application 028 found seven retained steady-state CLI modules whose role is read-only at the canonical persistence boundary. This application asks:

> Can those seven read shapes share one generation capture / object-resolution mechanism while preserving each caller's own missing-evidence and projection policy?

The target is not a generic repository framework. Only physical authority selection is shared.

## Freshness and stack

This observation is stacked on Application 028 / PR #406 head `c42fddab413b8f976acf1f9731ce96e135c3dbc2`.

At observation start actual `main` is `2954ed1cb83e569f81bec5023cf619eec6bb0df1` (`experiment: separate spending description from decision role (#407)`), unrelated to the publication stack.

Application 028 is open and mergeable, with exact-head Application 028 workflows successful.

## Current read-only call-site closure

The seven modules are:

```text
Loam/Cli/BudgetWindowCli.lean
Loam/Cli/CorrectionIntegrityCli.lean
Loam/Cli/EffectiveCli.lean
Loam/Cli/JournalExportCli.lean
Loam/Cli/OpenScheduledCli.lean
Loam/Cli/ReviewCli.lean
Loam/Cli/ScheduledBalanceCli.lean
```

They do not all assign the same meaning to physical absence. Examples include:

- BudgetWindow requires several families while EventCorrection is optional;
- JournalExport requires Event but treats correction, validity, and description evidence according to their existing local policies;
- Review requires Event while several adjacent evidence families may be absent/empty;
- Effective treats absent Event as an empty recorded world;
- Scheduled views treat absent Scheduled/lifecycle/Event storage as empty;
- CorrectionIntegrity can answer "no corrections" without requiring Event when correction evidence is absent.

Therefore `missing -> empty` or `missing -> error` must not become one global storage rule.

## Scratch boundary

The scratch mechanism adds one operational generation snapshot:

```text
read CURRENT once
  -> parse family presence/reference metadata once
  -> hold captured manifest
  -> resolve only the families requested by this view
  -> verify each requested object's digest
  -> existing meaning-specific typed decoder/admission boundary
```

A `GenerationSnapshot` never re-reads `CURRENT`. If authority advances while a view is in progress, every family read in that view continues from the captured generation.

The scratch manifest makes physical family presence explicit with `PRESENT` or `ABSENT`. This is operational metadata, not a household fact. The reason for observing it explicitly is that the seven existing callers already distinguish physical absence in different ways; silently materializing every absent family as one generic empty object could change those caller-visible policies.

The physical reader returns presence plus verified bytes. The seven tiny adapters still decide which families are required and which absence means an empty local evidence set.

## Qualification targets

The executable probe checks:

1. all seven read-only call-site shapes run through one shared generation capture mechanism;
2. each view captures `CURRENT` once;
3. a `CURRENT` replacement between two reads cannot mix generations inside one view;
4. corruption of a requested family fails closed;
5. corruption of an unrelated family does not make a view that never reads it unavailable, matching today's family-local read pressure;
6. six representative missing-evidence decisions remain caller-specific, including required Event refusal versus empty-world presentation;
7. the current seven source modules are measured for qualified persistence-load calls and physical presence checks;
8. the scratch shared reader and meaning-specific adapters are measured separately in lines and bytes, without treating LOC as the sole definition of simplicity.

## Boundary

No production source, canonical persistence path, manifest format, CLI behavior, typed decoder, household projection, migration contract, writer path, or household data changes. `PRESENT` / `ABSENT` is a scratch pressure on the future operational manifest shape, not a production format decision.

The result should determine whether physical read centralization is genuinely small, and whether explicit family presence is required to preserve existing evidence policy during a future manifest migration.
