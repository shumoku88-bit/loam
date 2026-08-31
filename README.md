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

Using every tool is not a goal. If two tools answer the same question in the same way, prefer the smaller combination.

## Local practical CLI

LOAM's practical Lean boundary is selected by the repository's `lean-toolchain`. Install Lean through `elan`, make sure `lake` is on `PATH`, then run the wrapper from the repository root:

```text
./tools/loam
```

The first human-facing dogfood entrance currently under observation is:

```text
./tools/loam spend MEMORY_FILE
```

It asks only where payment came from and the positive JPY amount. Lower-level Event and EventMemory commands remain available for inspecting the neutral practical representation.

A separate stateless shadow entrance can read one journal snapshot without changing it or creating LOAM persistence:

```text
./tools/loam shadow-quantity CANONICAL_ROOT/actual.journal
```

This entrance assigns fresh EventId / EffectKey values only for the lifetime of the process and uses them solely for the identity-renaming-invariant `EventMemory.quantityAtRecorded` projection established by Observation 078. It does not create a sidecar, retain a source mapping, or claim cross-run identity continuity. Header context, metadata, and include directives are counted as explicitly unprojected information rather than silently absorbed into the Practical Core.

The command prints source locus tokens and exact quantity results, so real canonical runs are local/private dogfood and their output should not be copied into public CI, issues, or pull requests.

A private whole-file dogfood run has now crossed this boundary successfully. Its non-zero locus × measure quantity projection matched the native h-kernel accounting projection for the same canonical snapshot. This is a quantity-projection checkpoint only: descriptive header context, metadata, include semantics, persistent imported identity, correction attachment, and other continuity-sensitive questions remain outside the result.

## Current map

Observations 001–061 build the neutral physical core and the bounded persistence/publication protocols around Event, Effect, Locus, Measure, exact Quantity, Correction, Resolution, and explicit relation admission.

Observations 062–065 apply anonymized household pressure without forcing familiar product nouns back into that core. Plan realization, Series membership, and refund provenance become observable as explicit relations rather than properties recoverable from endpoint shape alone.

Observations 066–071 apply external accounting pressure and then close with a Practical Core audit. Valuation, acquisition basis, disposal provenance, policy-selected attribution, retained historical attribution, policy provenance, and historical policy definition remain distinct when the question can observe them, but the checkpoint earns no new Practical Core, Persistence, CLI, or wire-format primitive.

Observations 072–078 begin a separate post-checkpoint real-data-shadow arc. They separate human descriptive context from physical quantity placement, distinguish Event-level and Effect-level context attachment, expose missing imported occurrence identity, require retained continuity rather than content/position-derived identity, reject permanent auxiliary identity stores as a default, keep reconciliation one-shot and fail closed, and finally prove that fresh run-local identity is safe for read-only queries whose retained answer is invariant under identity renaming.

That last law now has an operational entrance: `shadow-quantity` can project a private canonical journal through the existing Practical Core with no source mutation, no sidecar, and no LOAM persistence. The first whole-file private run reached native non-zero quantity parity with h-kernel. This does not promote the unprojected source context or identity questions into Core semantics.

See [`OBSERVATION_MAP.md`](OBSERVATION_MAP.md) for the integrated checkpoint of earned structure, deliberate non-commitments, and the current dogfood boundary.

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