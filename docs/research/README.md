# LOAM research documents

This directory contains repository-backed research catalogs, checkpoints, surveys, and progress authorities that are useful to LOAM but are not root-level project entrances or production semantics.

The root stays intentionally small:

- `README.md` — project and practical entrance;
- `AGENTS.md` — repository working rules;
- `DESIGN_PHILOSOPHY.md` — design stance;
- `OBSERVATION_MAP.md` — map into numbered observation history.

Research documents are grouped by the semantic question they serve.

## Household

`household/` contains household capability, evidence, vocabulary, compression, and dogfood checkpoints.

Current compact household checkpoint:

- [`HOUSEHOLD_CHECKPOINT.md`](household/HOUSEHOLD_CHECKPOINT.md)

Historical dated checkpoints live under `household/checkpoints/`.

## External pressure

`external-pressure/` contains surveys and compression checkpoints derived from mature accounting and household systems used as adversarial pressure against LOAM's current evidence model.

## Falsification

`falsification/` contains the domain falsification atlas, progress authority, selection checkpoints, and concept-pressure checkpoint.

- [`LOAM_FALSIFICATION_ATLAS.md`](falsification/LOAM_FALSIFICATION_ATLAS.md)
- [`LOAM_FALSIFICATION_PROGRESS.md`](falsification/LOAM_FALSIFICATION_PROGRESS.md)
- [`LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md`](falsification/LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md)

Structural/meta falsification has its own subdirectory:

- [`falsification/structural/`](falsification/structural/)

## Interaction

`interaction/` contains UI/HCI and interaction-design research. It is evidence for evaluating shells and workflows, not a selected UI specification or production semantic boundary.

- [`LOAM_INTERACTION_ATLAS.md`](interaction/LOAM_INTERACTION_ATLAS.md)
- [`LOAM_UI_EVALUATION_FRAMEWORK.md`](interaction/LOAM_UI_EVALUATION_FRAMEWORK.md)
- [`LOAM_UI_EVALUATION_EXPERIMENT_01.md`](interaction/LOAM_UI_EVALUATION_EXPERIMENT_01.md)

## Placement rule

Keep executable observation material in `experiments/`, `observations/`, `Loam/Observations/`, `tla/`, or `verification/` according to instrument and role. Do not move numbered executable evidence here merely because it is research.

Keep a research document at the root only when it is genuinely a repository entrance used to navigate the whole project. Otherwise place it under the narrowest research boundary that owns its meaning.

Existing filenames are intentionally preserved in this move so historical pull requests, commit messages, and discussion can still identify documents without an unrelated rename.
