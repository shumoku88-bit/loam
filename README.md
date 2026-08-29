# loam

A small laboratory for asking what structures appear before we decide what a household system is supposed to be.

The project begins with a deliberately narrow question:

> If finite resources are distributed through time and purpose without assuming accounts, transactions, budgets, or envelopes, what structures appear on their own?

## Method

Use the smallest set of tools that can answer the current question.

The default core is:

- **Alloy** explores possible structures and counterexamples.
- **J** observes structures as arrays and exposes projection, loss, and shape.
- **Lean 4** proves observed laws generally when they become worth keeping.

Two additional tools remain available, but are not part of the default path:

- **TLA+** is introduced only when a question depends essentially on temporal behavior or operation order and the core cannot expose the distinction clearly enough.
- **miniKanren** is introduced only when a question needs genuinely relational or backwards search that the core cannot provide clearly enough.

Before adding either optional tool to a new observation, state what the core cannot answer and what distinct kind of result the extra tool is expected to produce.

Past observations that used TLA+ or miniKanren remain part of the evidence. They show cases where those tools had a distinct role; they do not create a permanent dependency.

Using every tool is not a goal. If two tools answer the same question in the same way, prefer the smaller combination.

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
