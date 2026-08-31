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

## Current map

Observations 001–060 form the first completed arc from pre-household structure discovery to a practical split-stream persistence protocol. Observation 061 extends that protocol result to a multi-parent Resolution over an already-visible stable conflict frontier. Observation 062 then applies anonymized real-ledger pressure and finds that representative bookkeeping shapes still fit `Event + Effect + Locus + AccountingRole` without forcing a conventional Account object or nominal EventKind back into the neutral core. Observation 063 finds that Plan and Actual Event records do not determine their realization correspondence: explicit identity linkage carries observable completion provenance even when time, amount, and shape match. Observation 064 keeps the one-to-one realization boundary because current records do not yet contradict it, then observes that recurring Plan content and recurrence kind still do not determine Series membership: the grouping of Plan identities into one recurring thread carries independent information. Observation 065 applies another real-ledger pressure to refunds and reimbursements: Event records and net quantity still do not determine which earlier Event a return belongs to, and refund linkage is not semantically interchangeable with Correction-style supersession because the original expense remains an occurrence. Observation 066 begins an external-accounting-pressure arc without importing external product nouns: even complete historical valuation relations do not determine acquisition basis, and acquisition-time valuation, acquisition provenance, and current valuation remain observably distinct. Observation 067 then applies disposal pressure to multiple acquisition-specific Effects and finds that aggregate holding does not determine which acquisition supplied disposed quantity; even the source identity set can lose information unless the quantity consumed from each source is retained. Observation 068 separates that quantity-bearing relation from a configurable selector: unchanged physical facts can admit several valid allocations, a deterministic policy can choose one attribution, and an independently retained source relation can still agree or disagree unless explicit conformance connects the two. Observation 069 then moves that distinction through time with TLA+: after an attribution is retained under one policy, a later current-policy change can change the current-policy view while the retained historical attribution stays fixed, so today's policy cannot safely reconstruct yesterday's retained attribution. No additional `Lot` identity, disposal-policy implementation, or policy-version persistence is earned yet. See [`OBSERVATION_MAP.md`](OBSERVATION_MAP.md) for the current inventory of earned structure, derived views, overlays, protocol findings, and deliberately unearned concepts.

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
