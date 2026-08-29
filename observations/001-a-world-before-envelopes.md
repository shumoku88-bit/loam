# Observation 001 — A World Before Envelopes

## Question

If finite resource units are placed through time and purpose without assuming accounts, transactions, budgets, envelopes, months, or reports, does an envelope-like structure appear as something primitive, or only as a projection?

## Deliberate vocabulary

The first model admits only:

- `Time`
- `Purpose`
- persistent `Unit`
- placement of each Unit at one Purpose at each Time

`Unit` identity persists across the whole trace. Quantity is not primitive; it can be observed by counting Units.

## Deliberate absences

The model does not yet contain:

- Account
- Transaction
- Budget
- Envelope
- Month
- Report
- Income
- Expense
- balance arithmetic
- an operation named move or reallocate

A change of placement between adjacent Times is observable, but is not yet granted its own domain noun.

## Alloy lens

`model/001_resource_purpose.als` asks for a small world containing both:

- at least one Unit whose placement changes; and
- at least one Unit whose placement persists.

Because Units persist and every Unit has exactly one Purpose at every Time, conservation is represented structurally rather than by integer arithmetic.

The first assertion is intentionally modest: no Unit disappears from placement.

## J lens

`j/001_observe.ijs` begins with a deliberately lossy `Time × Purpose` count matrix.

This forgets Unit identity and keeps only quantity per Purpose. It observes:

- total quantity through time;
- adjacent changes;
- the range of each Purpose's quantity; and
- which Purpose totals remain numerically stable.

This mismatch is part of the experiment, not glue debt to fix immediately. Alloy can distinguish two worlds that J may project to the same matrix.

## First thing to look for

Do stable groups require persistent Unit identity, or is stable quantity at a Purpose enough for us to perceive an envelope-like structure?

If those notions diverge, "Envelope" may already be hiding multiple concepts that ordinary budgeting software stores under one noun.

## Not yet

Do not add TLA+, miniKanren, or Lean 4 until the observation produces a question that specifically needs temporal behavior, reverse relational search, or general proof.

Do not automate Alloy-to-J export yet. A tiny manually inspected bridge is preferable until we know which information should survive the projection.
