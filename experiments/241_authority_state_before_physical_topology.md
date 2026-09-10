# Observation 241 — Authority state before physical topology

## Question

Current LOAM sometimes uses physical presence to carry an authority-state
distinction. The concrete pressure is `actual-reversals.loam`:

```text
explicit complete empty Reversal authority
    -> Correction can establish reversal independence

missing Reversal authority
    -> Correction refuses
```

The observable distinction is real. The open question is whether the distinction
belongs to a **dedicated file** or to the decoded semantic/authority state.

## Why this matters for canonical re-minimization

A file can accumulate architectural gravity:

```text
file
  -> parser / codec
  -> loader
  -> publisher
  -> tests
  -> workflow
  -> apparent domain boundary
```

That chain does not prove that the original file boundary was an independently
observable household distinction.

Before minimizing physical topology, LOAM therefore needs a factorization:

```text
retained meaning
    -> authority availability / explicit emptiness
    -> physical representation
```

## Small Lean result

`Loam/Observations/Observation241.lean` records three deliberately small laws.

### 1. Explicit empty is not unavailable

For a Correction-like observable:

```text
available []  -> admitted
unavailable   -> refused
```

The two authority states are observably distinct. Any semantic compression that
identifies them is invalid for the selected operation vocabulary.

### 2. Topology does not own the distinction

The same decoded authority state is placed in two representative physical
layouts:

```text
separateFile
bundledSection
```

When decoded authority state is preserved, changing only that topology does not
change the selected observable.

This is a factorization statement, not a migration result.

### 3. Unavailability must survive topology changes too

A bundled representation is not permission to reinterpret unavailable evidence
as an explicit empty relation. Both known-empty and unavailable states must be
preserved through any later physical rewrite.

## What this observation does not prove

Observation 241 does **not** prove that `actual-reversals.loam` should be deleted
or bundled today.

A physical boundary may still be earned by properties outside this tiny selected
observable, including:

- atomic publication;
- crash-prefix closure;
- stale-writer rejection;
- corruption/failure blast radius;
- independent update lifecycle;
- recovery or reconstruction behavior.

Those properties belong to the later physical-topology phase of #693.

## Design consequence for the audit

Do not ask:

> Does this file exist for a reason?

Ask two separate questions:

```text
1. Which semantic / authority distinction does the current operation vocabulary
   require?

2. What is the smallest physical representation that preserves that distinction
   and all independently required publication/failure properties?
```

A dedicated file is one candidate answer to question 2. It is not evidence for
question 1.

## Next pressure

Continue the retained-family witness table before proposing file changes.

The next high-leverage static witnesses are:

1. `ZeroOriginCoverage`: same Events, current answer vs `coverageMissing`;
2. `CapacityEffective`: same Capacity movements, different windowed answer;
3. Scheduled terminal evidence: same occurrences, different open-world answer;
4. `AccountingRole`: same Scheduled/routing state, pressure vs non-pressure vs
   unresolved eligibility.

After those semantic witnesses are fixed, return to physical topology and test
whether current files are merely one encoding of the earned authority states or
whether each boundary protects an additional operational law.
