# loam

A small laboratory for asking what structures appear before we decide what a household system is supposed to be.

The project begins with a deliberately narrow question:

> If finite resources are distributed through time and purpose without assuming accounts, transactions, budgets, or envelopes, what structures appear on their own?

## Method

Tools are added only when a question needs them.

- **Alloy** explores possible structures and counterexamples.
- **J** observes many structures as arrays and looks for shape.
- **TLA+** is a candidate when correctness depends on temporal behavior or operation order.
- **miniKanren** is a candidate when useful questions become relational or need to run backwards.
- **Lean 4** is a candidate when an observed law becomes worth proving generally.

Using every tool is not a goal. A tool that never becomes necessary should remain absent.

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
