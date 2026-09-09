# loam

LOAM is a household system for day-to-day recording and review, with formal-modeling experiments used to test parts of its design.

The research began with a deliberately narrow question:

> If finite resources are distributed through time and purpose without assuming accounts, transactions, budgets, or envelopes, what structures appear on their own?

## Method

Use the smallest set of tools that can answer the current question.

The default core is:

- **Alloy** explores possible structures and counterexamples.
- **J** observes structures as arrays and exposes projection, loss, and shape.
- **Lean 4** proves observed laws generally when they become worth keeping and hosts the practical core.

Additional tools are introduced only when they add a distinct kind of answer:

- **TLA+ / TLC** for temporal behavior, operation order, and state-transition questions.
- **Apalache** for symbolic checking of selected TLA+ transition systems and inductive invariants.
- **SPIN / Promela** for explicit interleaving and protocol-order questions where concurrent process scheduling is the pressure point.
- **miniKanren** for genuinely relational or backwards search that the core cannot provide clearly enough.

Before adding an optional tool to a new observation, state what the current toolset cannot answer and what distinct result the extra tool is expected to produce.

Past observations that used an optional tool remain part of the evidence. They show cases where that tool had a distinct role; they do not create a permanent dependency.

Observations 006–007 are the historical miniKanren example. Their first Racket/miniKanren source and dedicated CI were later retired after that role was established. Observation 187 supplies a new concrete backwards-search pressure, so one observation-only Racket/miniKanren source and dedicated CI are present again. This does not make miniKanren a production or steady-state runtime dependency; a relational question must earn its use each time.

Using every tool is not a goal. If two tools answer the same question in the same way, prefer the smaller combination.

Repository-backed research surveys, checkpoints, and falsification catalogs are grouped under [`docs/research/`](docs/research/README.md). `OBSERVATION_MAP.md` remains the root-level map into numbered observation history.

## Local practical entrance

LOAM's practical Lean boundary is selected by the repository's `lean-toolchain`. Install Lean through `elan`, make sure `lake` is on `PATH`, then run the wrapper from the repository root:

```text
./tools/loam
```

With no arguments, the wrapper opens the production `loamTui` household workspace. The TUI resolves `LOAM_DATA_DIR` itself, defaulting to `../loam-data`, and resolves `LOAM_MOVEMENT_MANIFEST_ROOT`, defaulting to `DATA_DIR/movement-authority`. Missing or corrupt selected authority fails closed rather than falling back to retired Movement sidecars.

Explicit named CLI commands remain available for scriptable, diagnostic, and lower-level use. The default human entrance does not replace those commands.

Household recording has one explicit line-CLI entrance:

```text
LOAM_MOVEMENT_MANIFEST_ROOT=DIR ./tools/loam movement MEMORY_FILE
```

The line CLI requires an initialized Movement manifest root and never falls back to a sidecar Movement world. `MEMORY_FILE` is retained only as a positional compatibility argument for the current command shape; Movement preflight and publication use the selected manifest authority, not that path.

Enter one or more FROM loci and positive JPY amounts, leave the next FROM locus blank, then enter one or more TO loci and amounts and leave the next TO locus blank. The two totals must match exactly before LOAM publishes one Event. The retained Core fact is only the resulting signed Effects: FROM contributes `-q`, TO contributes `+q`.

Purchases, transfers, income, split payments, and other value flows use this same entrance. LOAM does not ask for a transaction kind at recording time. For example, `paypay -> food`, `smbc -> paypay`, and `pension -> smbc` are all the same movement shape. The specialized `spend`, `income`, and `transfer` commands have been retired rather than kept as compatibility aliases.

### Household manifest authority

The production TUI owns default household authority selection. `LOAM_DATA_DIR` may select the household data directory; otherwise it uses `../loam-data`. `LOAM_MOVEMENT_MANIFEST_ROOT` may explicitly select a Movement manifest root; otherwise the TUI uses `DATA_DIR/movement-authority`.

Movement recording, correction, occurrence-date correction, Actual review, and other production TUI paths consume the selected manifest authority through shared readers and publishers. The former sidecar-only `correct` and `correct-date` CLI entrances are retired rather than kept beside the current authority.

Explicit line commands remain available where their separate scriptable or diagnostic role is still useful. Commands that expose lower-level authority selection must continue to fail closed rather than silently manufacture a sidecar world. The historical shell-menu manifest cutover is retained as provenance in [`docs/movement_manifest_menu_cutover.md`](docs/movement_manifest_menu_cutover.md); it is not current entrance guidance.

### Focused record review

The explicit `review` CLI remains available for scripted and focused record inspection even though the default interactive human entrance is now the production TUI.

```text
./tools/loam review MEMORY_FILE CORRECTION_FILE
./tools/loam review MEMORY_FILE CORRECTION_FILE 2026-09-03
./tools/loam review MEMORY_FILE CORRECTION_FILE '/スーパー'
```

Review is intentionally **one-shot and bounded**. With no query, or with `t`, it prints at most ten summaries from the seven occurrence dates ending today together with a small date/count strip. It is **not** a most-recently-entered log. `YYYY-MM-DD` selects one occurrence date, `u` selects current records whose date is unknown, and `/text` searches all dates and **all recorded Events**, including clearly marked correction originals. Search uses literal, case-insensitive substrings over descriptions, loci, measures, quantity spellings, dates, and EventIds.

Daily counts and lists reflect movement and date corrections. The correction path is explicit; a not-yet-created correction file means no correction facts, as in balances. Standard input is ignored and the command never opens a paging or prompt loop. Use the production TUI Actual workspace for interactive browsing and selected-record detail.

Long recognition text and additional Effects are explicitly elided only in the summary. Search examines the full retained text. Date-unknown counts remain visible. No match is not proof that something was never recorded. Invalid correction evidence refuses the review instead of appearing as an empty list.

Unbounded raw inspection is deliberately lower-level:

```text
./tools/loam event-memory review MEMORY_FILE
```

See [Application 015](experiments/application_015_focused_record_review.md) for scope and local composition checks. Review adds no persistence or writer path.

### Quantities and shadow readers

Current quantity and balance reads combine correction-aware Event effects with explicit `ZeroOriginCoverage`. A coordinate is answerable only when that independent coverage evidence states that its selected retained Event history is complete from zero. Event activity, Locus admission, and `config/balance-view.tsv` selection do not create coverage; an uncovered coordinate remains unavailable rather than becoming an implicit zero. The replaceable balance view selects presentation questions only and does not turn Locus into an Account primitive. Routine starting-quantity writers are retired; zero-origin coverage changes only through explicit reconstruction or cutover. Lower-level Event and EventMemory commands remain available for inspecting the neutral practical representation.

A separate stateless shadow entrance remains available for read-only research against historical or external journal snapshots. It does not participate in current household authority:

```text
./tools/loam shadow-quantity PATH/TO/external.journal
```

This entrance assigns fresh EventId / EffectKey values only for the lifetime of the process and uses them solely for the identity-renaming-invariant `EventMemory.quantityAtRecorded` projection established by Observation 078. It does not create a sidecar, retain a source mapping, or claim cross-run identity continuity. Header context, metadata, and include directives are counted as explicitly unprojected information rather than silently absorbed into the Practical Core.

The command prints source locus tokens and exact quantity results, so runs against private snapshots remain local research and their output should not be copied into public CI, issues, or pull requests.

Historically, a private whole-file dogfood run crossed this boundary successfully: its non-zero locus × measure quantity projection matched the native h-kernel accounting projection for the same canonical snapshot. This remains a quantity-projection checkpoint only. The one-off private parity and source-shape wrappers used around that checkpoint have since been retired; descriptive header context, metadata, include semantics, persistent imported identity, correction attachment, and other continuity-sensitive questions remain outside the result.

Generic read-only shadow tools remain only where they answer an independent research question. They are not operational bridges, migration authority, or compatibility layers for HRA / h-kernel.

## Current household use

LOAM is the current day-to-day household system. Ordinary real-life recording is now done in LOAM rather than in a parallel HRA workflow.

Selected `loam-data` objects, manifests, and configuration carry current operational household meaning. The implementation can continue to change, but a representation change that affects operational data needs an explicit migration, reconstruction, or other qualified transition that preserves the household facts being carried forward.

HRA remains useful as historical implementation, migration provenance, and comparison material. It is not a second operational authority and does not need to be kept structurally synchronized with LOAM.

Historical research documents and experiments may still describe an earlier HRA-authority or parallel-dogfood phase. Those statements are part of the project history. The current policy is [`HOUSEHOLD_OPERATING_MODE.md`](docs/HOUSEHOLD_OPERATING_MODE.md).

The one-time Historical Actual prepare / publish runtime has been retired from current LOAM after the cutover completed. The sealed source snapshot and admission receipt remain migration provenance for that historical cutover in `loam-data`; shadow and comparison adapters, where retained, are research instruments rather than current operational bridges or authority.

There is no requirement to keep adding features when ordinary use does not expose a need. New work should come from concrete household use, a demonstrated simplification, or a clearly scoped research question.

## Current map

Observations 001–061 build the neutral physical core and the bounded persistence/publication protocols around Event, Effect, Locus, Measure, exact Quantity, Correction, Resolution, and explicit relation admission.

Observations 062–065 apply anonymized household pressure without forcing familiar product nouns back into that core. Plan realization, Series membership, and refund provenance become observable as explicit relations rather than properties recoverable from endpoint shape alone.

Observations 066–071 apply external accounting pressure and then close with a Practical Core audit. Valuation, acquisition basis, disposal provenance, policy-selected attribution, retained historical attribution, policy provenance, and historical policy definition remain distinct when the question can observe them, but the checkpoint earns no new Practical Core, Persistence, CLI, or wire-format primitive.

Observations 072–084 establish the first private real-data shadow boundary, run-local identity for identity-renaming-invariant queries, and the return of context-relative sufficiency in formal-result and privacy-safe observation work.

The integrated [`OBSERVATION_MAP.md`](OBSERVATION_MAP.md) currently records that history through Observation 084 in detail.

Observations 085–104 and Applications 010–014 then apply direct household dogfood pressure to query-relative basis evidence, balance selection, practical-core compression, replaceable balance configuration, basis-origin double counting, and read-only household day views. The compact checkpoint for that later arc is [`HOUSEHOLD_CHECKPOINT.md`](docs/research/household/HOUSEHOLD_CHECKPOINT.md).

The latest practical result is not a claim that familiar household concepts are permanently unnecessary. It is evidence that several useful household questions can already be answered by small retained facts / relations, question-specific projections, and terminal composition without importing the source application's ontology wholesale.

## Observation 001 — A World Before Envelopes

Start without these concepts:

- Account
- Transaction
- Budget
- Envelope
- Month
- Report

Begin only with finite resource units, time, purposes, and changing placement.

The first question is whether something we would later call an envelope is primitive data, or merely a projection that emerges from stable placement through time.

See `observations/001-a-world-before-envelopes.md` as the experiment develops.
