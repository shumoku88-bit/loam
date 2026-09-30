# loam

LOAM is a personal household system and research project built in Lean 4.

It is used for ordinary day-to-day household money recording and review. At the same time, it is a place to study how explicit facts, derived views, and question-driven formal methods can support small, long-lived personal software.

The project is public so its experiments, design decisions, proofs, and practical results can be inspected and reused by others. Broad adoption is not a project goal; if the work helps other people or projects, that is a welcome result.

The production interface is one standalone terminal app. You do not need Lean, Alloy, TLA+, or a repository checkout to use LOAM.

## Project stance

LOAM is driven by concrete household use, demonstrated simplification, and clearly scoped research questions. It is not trying to maximize features, user count, or abstraction for hypothetical future users.

The project therefore treats everyday use and research as one loop: real household needs expose design questions, and research is retained when it makes the working system clearer, safer, or easier to reason about.

## What LOAM does

LOAM currently supports everyday household work such as:

- recording purchases, income, transfers, and split payments;
- reviewing and correcting recorded Actual events;
- tracking Scheduled payments and capacity;
- inspecting balances, daily pace, trends, and household reports;
- exporting a disposable Beancount view for Fava.

The TUI is the main human interface. Named commands remain available for focused, scriptable, diagnostic, or export work.

## Quick start

Download the archive for your platform from the [latest GitHub Release](https://github.com/shumoku88-bit/loam/releases/latest), extract it, then run:

```text
./loam
```

With no arguments, `loam` opens the production terminal UI.

Release archives are published for macOS Intel, macOS Apple Silicon, Linux x86_64, and Linux aarch64, together with SHA-256 checksums.

LOAM uses `LOAM_DATA_DIR` as its household data directory. If it is not set, the default is `../loam-data`.

## Recording a movement

LOAM records ordinary same-Measure value flow as one balanced movement.

For example:

```text
paypay -> food
smbc   -> paypay
pension -> smbc
```

LOAM does not require a transaction kind such as “purchase”, “transfer”, or “income” before recording. The retained fact is the signed movement itself.

The explicit line entrance is:

```text
./loam movement [LOAM_DATA_DIR]
```

A normal movement uses one Measure. Cross-Measure exchange, such as JPY → USD, is kept separate because exchange and valuation carry additional meaning.

See [Adding a currency](docs/ADDING_CURRENCY.md) for Measure setup.

## Household data

The selected data directory is the household authority root. Normalized Actual evidence is stored in `actual.loam`.

LOAM prefers explicit failure to silent fallback. If selected authority is missing or malformed, the program refuses the read or write instead of quietly switching to an older sidecar or inventing an empty world.

Operational household facts live outside this repository. Changes that affect their representation need an explicit migration, reconstruction, or other qualified transition.

See [Household operating mode](docs/HOUSEHOLD_OPERATING_MODE.md) for the current authority policy.

## Development

For repository development, install Lean through `elan` and make sure `lake` is on `PATH`.

Run the checkout through:

```text
./tools/loam
```

The main product build is:

```text
lake build
```

Two additional Lean surfaces are checked separately:

```text
lake build Loam.DurableProofs
lake build Loam.Observations
```

The product, durable proofs, and broader research witnesses are intentionally not one giant build surface.

## Documentation

Start with these documents when you need more detail:

- [TUI guide](docs/TUI.md) — everyday terminal use;
- [Semantic blueprint](docs/SEMANTIC_BLUEPRINT.md) — compact map of meanings and authority boundaries;
- [Beancount / Fava](docs/BEANCOUNT_FAVA.md) — disposable accounting projection;
- [CI obligation map](docs/CI_OBLIGATION_MAP.md) — what the repository checks and why;
- [AI workbench](docs/AI_WORKBENCH.md) — tools for cross-cutting repository work;
- [Research index](docs/research/README.md) — active and historical research material.

## Research

LOAM also serves as a small research laboratory.

The project asks how much useful household behavior can be derived from explicit facts, relations, and projections without forcing every familiar accounting or budgeting concept into the lowest-level data model.

Lean 4 hosts the practical core and retained proofs. Alloy, TLA+, and other tools are used only when they answer a distinct design question. The longer research history is indexed by [OBSERVATION_MAP.md](OBSERVATION_MAP.md).

None of that is required for ordinary household use.

## Status

LOAM is used as the current day-to-day household system.
