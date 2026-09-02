# loam

A small laboratory for asking what structures appear before we decide what a household system is supposed to be.

The project begins with a deliberately narrow question:

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

Observations 006–007 are the concrete miniKanren example. Their executed findings remain in the observation records and Git history, while the Racket/miniKanren source and dedicated CI have been retired from the current checkout after that role was established. A later genuinely relational or backwards-search question may earn that runtime again; historical use alone does not keep it active.

Using every tool is not a goal. If two tools answer the same question in the same way, prefer the smaller combination.

## Local practical CLI

LOAM's practical Lean boundary is selected by the repository's `lean-toolchain`. Install Lean through `elan`, make sure `lake` is on `PATH`, then run the wrapper from the repository root:

```text
./tools/loam
```

Household recording now has one human-facing entrance:

```text
./tools/loam movement MEMORY_FILE
```

Enter one or more FROM loci and positive JPY amounts, leave the next FROM locus blank, then enter one or more TO loci and amounts and leave the next TO locus blank. The two totals must match exactly before LOAM publishes one Event. The retained Core fact is only the resulting signed Effects: FROM contributes `-q`, TO contributes `+q`.

Purchases, transfers, income, split payments, and other value flows use this same entrance. LOAM does not ask for a transaction kind at recording time. For example, `paypay -> food`, `smbc -> paypay`, and `pension -> smbc` are all the same movement shape. The specialized `spend`, `income`, and `transfer` commands have been retired rather than kept as compatibility aliases.

A Locus is not silently given a zero starting basis. If `current` encounters a recorded Locus without basis evidence, set its starting quantity explicitly, including an explicit `0` when that is the truthful application-origin basis. The replaceable balance view can select only the loci intended for a household balance display without turning Locus into an Account primitive. Lower-level Event and EventMemory commands remain available for inspecting the neutral practical representation.

A separate stateless shadow entrance can read one journal snapshot without changing it or creating LOAM persistence:

```text
./tools/loam shadow-quantity CANONICAL_ROOT/actual.journal
```

This entrance assigns fresh EventId / EffectKey values only for the lifetime of the process and uses them solely for the identity-renaming-invariant `EventMemory.quantityAtRecorded` projection established by Observation 078. It does not create a sidecar, retain a source mapping, or claim cross-run identity continuity. Header context, metadata, and include directives are counted as explicitly unprojected information rather than silently absorbed into the Practical Core.

The command prints source locus tokens and exact quantity results, so real canonical runs are local/private dogfood and their output should not be copied into public CI, issues, or pull requests.

A private whole-file dogfood run has now crossed this boundary successfully. Its non-zero locus × measure quantity projection matched the native h-kernel accounting projection for the same canonical snapshot. This is a quantity-projection checkpoint only: descriptive header context, metadata, include semantics, persistent imported identity, correction attachment, and other continuity-sensitive questions remain outside the result.

That comparison can now be repeated locally without publishing the private projection. The harness accepts one private journal and one local native adapter:

```text
./tools/private-quantity-parity CANONICAL_ROOT/actual.journal /path/to/native-quantity-adapter
```

The adapter receives the journal path as its first argument and emits already-aggregated rows in the private contract `LOCUS<TAB>MEASURE<TAB>QUANTA`, with canonical signed integer `QUANTA`. The harness captures both the native stream and LOAM's `shadow-quantity --parity-rows` stream in mode-0700 temporary storage, removes zero coordinates, sorts the non-zero rows, and compares them locally. It verifies that the source file did not change during observation and deletes all captured rows on exit.

On success or mismatch, the harness reports only structural status and coordinate counts. It does not print private locus names, measures, quantities, projection hashes, or a value diff. The adapter itself is intentionally local: LOAM does not make h-kernel's invocation or presentation format part of LOAM semantics. Public CI qualifies the harness only with synthetic data.

To inspect the source shapes that the quantity shadow already recognizes without printing private coordinates or values, use the local summary wrapper:

```text
./tools/private-source-shape-summary CANONICAL_ROOT/actual.journal
```

It captures the ordinary shadow output in mode-0700 temporary storage, extracts only the existing structural evidence counts, verifies that the source did not change, and removes the captured output on exit. The summary reports projected Event/Effect counts and counts of header context, metadata lines, and include directives that remain explicitly unprojected. Those counts are observation pressure, not new domain semantics: they do not make description, metadata, include behavior, or familiar household nouns part of the Practical Core. Public CI exercises the wrapper only with synthetic data and checks that source text and quantities are withheld.

## Current household dogfood checkpoint

LOAM has now crossed a second practical boundary beyond the first stateless quantity shadow.

The current household-facing slice includes:

- correction-aware practical balances with explicit `QuantityBasis`;
- replaceable balance selection that does not treat basis presence as hidden Account classification;
- an explicit correction-root basis cut for occurrences already reflected in a basis observation;
- a read-only recorded-day view over an external canonical journal;
- a separate scheduled-day view using explicit completion / retirement evidence and a known-through horizon;
- a terminal composition that shows recorded and scheduled answers for the same selected day without introducing a canonical Home or Day model.

The external household source remains read-only pressure. Its Account, Plan, recurrence, Series, and report vocabulary are not automatically imported into LOAM Core.

During the current dual-dogfood period, the HRA canonical household source remains the authority for household truth while LOAM remains the reconstruction experiment and comparison target.

See [`HOUSEHOLD_CHECKPOINT.md`](HOUSEHOLD_CHECKPOINT.md) for the compact current checkpoint after Observation 104 and Applications 010–014.

## Current map

Observations 001–061 build the neutral physical core and the bounded persistence/publication protocols around Event, Effect, Locus, Measure, exact Quantity, Correction, Resolution, and explicit relation admission.

Observations 062–065 apply anonymized household pressure without forcing familiar product nouns back into that core. Plan realization, Series membership, and refund provenance become observable as explicit relations rather than properties recoverable from endpoint shape alone.

Observations 066–071 apply external accounting pressure and then close with a Practical Core audit. Valuation, acquisition basis, disposal provenance, policy-selected attribution, retained historical attribution, policy provenance, and historical policy definition remain distinct when the question can observe them, but the checkpoint earns no new Practical Core, Persistence, CLI, or wire-format primitive.

Observations 072–084 establish the first private real-data shadow boundary, run-local identity for identity-renaming-invariant queries, and the return of context-relative sufficiency in formal-result and privacy-safe observation work.

The integrated [`OBSERVATION_MAP.md`](OBSERVATION_MAP.md) currently records that history through Observation 084 in detail.

Observations 085–104 and Applications 010–014 then apply direct household dogfood pressure to query-relative basis evidence, balance selection, practical-core compression, replaceable balance configuration, basis-origin double counting, and read-only household day views. The current compact checkpoint for that later arc is [`HOUSEHOLD_CHECKPOINT.md`](HOUSEHOLD_CHECKPOINT.md).

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
