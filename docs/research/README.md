# LOAM research documents

This directory contains repository-backed research catalogs, checkpoints, surveys, and progress authorities that are useful to LOAM but are not root-level project entrances or production semantics.

The root stays intentionally small:

- `README.md` — project and practical entrance;
- `AGENTS.md` — repository working rules;
- `DESIGN_PHILOSOPHY.md` — design stance;
- `OBSERVATION_MAP.md` — map into numbered observation history.

Research documents are grouped by the semantic question they serve.


## Research/history distillation Phase 1 closure

Status: **CLOSED — reopen only on concrete ownership evidence**

Closure baseline:

```text
8b54581b7320f03d621c6ee05304d37099cb6f24
research: graduate normalized Capacity cutover history (#1538)
```

The repository-wide research/history distillation pass is complete.

The stop condition is not "nothing old remains". It is that the remaining research
surface is now dominated by material with a current reason to exist:

- current production/design boundaries whose distinctions are still operationally meaningful;
- executable proof, model, CI, regression, or counterexample evidence;
- external/literature comparison that is not reproduced by production source;
- future-semantic pressure for behavior that production does not yet implement;
- compact audit/navigation records that explain why a broader campaign stopped.

Detailed campaign-local discovery prose may graduate once production, proofs/tests,
or a later synthesis owns its surviving meaning more strongly. Git history is the
archive for that retired exploration; creating an `archive/` directory is not the
default retention strategy.

The closure-first scan found that further broad deletion mining would now mostly
remove guardrails rather than obsolete scaffolding. Recent graduations include
completed Generation-2 implementation-detail notes and the finished normalized
Capacity migration/cutover history, while boundaries such as current-write
admission versus historical readability, open-world `Unknown`, recovery
asymmetry, and explicit KEEP/DO-NOT-COUPLE stop points remain live.

Reopen this distillation only when there is concrete evidence such as:

```text
production/proof/test now subsumes a retained research note
or
an executable witness retires with no independent current role
or
a later synthesis makes an older navigation/detail record redundant
or
a supposedly current boundary becomes unreachable or ownerless
```

The next repository-compression phase must start from the then-current `main`,
not from historical line-count estimates. Its default unit remains one semantic
correspondence per PR: preserve meaning, canonical data, user-visible behavior,
refusal/recovery semantics, and safety before removing mechanics.


## Household

`household/` contains household capability, evidence, vocabulary, compression, and dogfood checkpoints.

Current compact household checkpoint:

- [`HOUSEHOLD_CHECKPOINT.md`](household/HOUSEHOLD_CHECKPOINT.md)

Historical dated checkpoints live under `household/checkpoints/`.

## External pressure

`external-pressure/` contains surveys and compression checkpoints derived from mature accounting and household systems used as adversarial pressure against LOAM's current evidence model.

- [`LOAM_TEXT_SQLITE_PERSISTENCE_STUDY_2026-10.md`](external-pressure/LOAM_TEXT_SQLITE_PERSISTENCE_STUDY_2026-10.md) — compares text authority, disposable SQLite projection, and SQLite canonical authority before any persistence migration.

## Falsification

`falsification/` contains the domain falsification atlas, progress authority, selection checkpoints, and concept-pressure checkpoint.

- [`LOAM_FALSIFICATION_ATLAS.md`](falsification/LOAM_FALSIFICATION_ATLAS.md)
- [`LOAM_FALSIFICATION_PROGRESS.md`](falsification/LOAM_FALSIFICATION_PROGRESS.md)
- [`LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md`](falsification/LOAM_CONCEPT_PRESSURE_SELECTION_2026-09.md)

Structural/meta falsification has its own subdirectory:

- [`falsification/structural/`](falsification/structural/)

## Verified development skills

`verified-skills/` contains an experimental AI-development skill loop inspired
by verifier-backed skill evolution research. Candidate procedures are measured
against ordinary repository-guided work before they can be promoted.

- [`verified-skills/README.md`](verified-skills/README.md) — lifecycle, paired-trial
  protocol, promotion / mutation / retirement rules, and current candidates.

The directory is research evidence and agent guidance, not production semantics
or household authority. If the mechanism later proves useful across several
Qualified skills, extraction into a separate library or project can be evaluated
then rather than assumed now.

## Interaction

`interaction/` contains UI/HCI and interaction-design research. It is evidence for evaluating shells and workflows, not a selected UI specification or production semantic boundary.

- [`LOAM_INTERACTION_ATLAS.md`](interaction/LOAM_INTERACTION_ATLAS.md)
- [`LOAM_UI_EVALUATION_FRAMEWORK.md`](interaction/LOAM_UI_EVALUATION_FRAMEWORK.md)
- [`LOAM_UI_EVALUATION_EXPERIMENT_01.md`](interaction/LOAM_UI_EVALUATION_EXPERIMENT_01.md)
- [`interaction/lets-kakeibo/`](interaction/lets-kakeibo/) — evidence-backed study of the long-lived Let's家計簿 desktop interaction model.

## Placement rule

Keep executable observation material in `experiments/`, `observations/`, `Loam/Observations/`, `tla/`, or `verification/` according to instrument and role. Do not move numbered executable evidence here merely because it is research.

Keep a research document at the root only when it is genuinely a repository entrance used to navigate the whole project. Otherwise place it under the narrowest research boundary that owns its meaning.

Existing filenames are intentionally preserved in this move so historical pull requests, commit messages, and discussion can still identify documents without an unrelated rename.

## Observation storage roles

The observation-shaped directories are intentionally different boundaries rather than three interchangeable archives.

| Path | Role | Retention meaning |
| --- | --- | --- |
| `observations/` | Prose-only observation records from the earlier research sequence. | Historical project memory; not a production contract. |
| `experiments/` | Numbered experiment notes and solver/model artifacts such as Alloy, Promela, TLA+, J, and local Lean probes. | Evidence for a question, witness, or result; may remain historical after its law is integrated elsewhere. |
| `Loam/Observations/` | Lean proof obligations selected to remain executable against the current codebase. | Live only when the proof still justifies an active boundary; `Loam/Observations.lean` is the selected umbrella. |
| `docs/research/` | Compressed checkpoints, catalogs, surveys, and research navigation. | Current research map, not an observation-by-observation evidence store. |

When an experiment becomes an integrated production law, prefer keeping the smallest current executable obligation and letting detailed historical apparatus remain research evidence or Git history. Do not move files merely to make directory names look uniform.
