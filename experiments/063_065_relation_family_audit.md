# Observations 063–065 relation-family audit

## Purpose

Observations 063–065 each exposed information that endpoint records do not reconstruct:

```text
Plan + Actual records
    -/-> realization correspondence

Plan content + recurrence
    -/-> Series membership

Event records + net quantity
    -/-> refund provenance
```

After private dogfood pressure for Series membership and refund provenance, these three observations now look similar enough to invite a generic `Relation` abstraction.

This audit asks the opposite question first:

> What actually remains common after the domain names are stripped away, and which differences would a universal relation object erase too early?

The goal is a checkpoint, not a new Observation. No new model is needed unless the comparison exposes a new structural law.

## Shared information boundary

The strongest common statement currently supported by all three observations is informational:

```text
retained endpoint / content facts
    -/->
selected correspondence or membership
```

Equivalently, two worlds may retain the same endpoint identities and endpoint content while differing in which correspondence or grouping is selected. Later questions can observe that difference.

This is real structure, but it is a weak common denominator. It says that relational information may need to survive independently of endpoint content. It does not yet say that all such information should share one representation, identity law, cardinality, lifecycle, admission rule, or persistence stream.

A useful descriptive phrase is:

> relation-family resemblance

That phrase is descriptive only. It is not a Practical Core type or ontology.

## The differences are currently semantic

| Dimension | Observation 063 — realization | Observation 064 — Series | Observation 065 — refund provenance |
| --- | --- | --- | --- |
| Structural role | selected correspondence | membership / grouping | provenance correspondence |
| Bounded shape | `Plan -> lone Event` | `Plan -> one Series` inside the experiment | `Return -> lone Expense` |
| What may collect many members | not earned yet; split / merged realization remains open | one Series can have many Plans | not earned yet; multi-source / multi-refund remains open |
| Main later questions | completion, plannedness, expected-vs-Actual mismatch, realization provenance | same-thread peers / grouping | which source occurrence a return belongs to |
| Relationship to time | connects expectation and Actual occurrence; no lifecycle/order law earned | membership itself has no earned causal direction | current pressure is a later return explaining an earlier source occurrence |
| Effect on occurrence | does not make Actual intrinsicly planned without the relation | grouping does not alter Plan occurrence | source expense remains an occurrence after refund |
| Missing explicit relation | do not infer realization from matching content | missing membership remains unassigned here; do not infer from recurrence/content | do not infer provenance from reverse quantity or candidate shape |
| Relation identity | not earned | membership-edge identity not earned; first-class Series object also not earned | not earned |
| Persistence | not earned | not earned | not earned |

The bounded cardinalities in the original models are specimen boundaries, not universal laws. In particular, Observation 063 explicitly leaves split / merged realization open, Observation 064 does not claim every Plan always belongs to one Series, and Observation 065 leaves multi-source reimbursement open.

The family resemblance is therefore **informational, not yet operational**.

## Why current `RelationAdmission` does not generalize these observations

The Practical Core already contains `Loam.Core.RelationAdmission`, but its name should not be read as a generic relation superclass.

Its present responsibility is deliberately narrow:

```text
EventCorrection / EventResolution raw fact
    +
current EventMemory
    ->
fail-closed referentially admitted view
```

It checks whether every explicitly referenced Event is present. It does not define generic relation semantics, storage, time, authority, priority, currentness, or lifecycle.

Observations 056 and 058 likewise concern relation kinds that had already become practical fact collections:

- per-kind Correction / Resolution identity uniqueness prevents duplicate-identity ambiguity and storage-order tie-breaking;
- raw relation-memory append remains separate from derived referential admission so physical arrival order does not decide which canonical raw facts survive.

Those are useful laws for the practical Correction / Resolution collections that earned them. They are not automatically laws for every relation-shaped overlay discovered later.

Applying them immediately to 063–065 would silently assume facts not yet earned:

- that realization, Series membership, and refund provenance are practical relation facts rather than application overlays;
- that each needs its own stable relation identity;
- that each needs canonical raw memory;
- that a common endpoint-admission policy exists;
- that Plan or Series endpoints belong in the Practical Core;
- that relation append / reload is already a required operation.

Even refund provenance, whose endpoints can be represented as Events in the experiment, has not earned practical relation identity, persistence, correction history, or a current-view projection analogous to Correction.

## The Observation 042 threshold

Observation 042 provides a useful precedent for when genericization is justified.

There, household and explanation names were removed from repeated revision examples and a nontrivial law survived in a domain-independent vocabulary:

```text
frontier(later) = {new revision}
    iff
new revision parents the whole prior frontier
```

That common structure was more than visual similarity. The same law survived after the motivating domain labels disappeared, which justified preserving the generic structure and then attempting unbounded Lean proof.

The same move does not yet succeed for 063–065.

After removing `Plan`, `Series`, `Actual`, `Return`, and `Expense`, the robust common statement is currently only:

```text
some selected relation can vary
while endpoint records remain fixed
```

That is an information-separation observation, not yet a shared operational law comparable to the frontier-settlement equivalence.

So the current genericization threshold is not met.

## What is not earned

This audit does not earn any of the following:

```text
Relation
RelationId
RelationMemory
Source / Target endpoint roles
universal edge cardinality
universal membership encoding
universal provenance graph
universal relation correction / lifecycle
universal absence semantics
generic relation persistence
```

It also does not move `Plan`, `Series`, or `Refund` into the Practical Core and does not unify refund provenance with Correction.

A generic `link(source, target)` application API would be premature for the same reason: it would erase the fact that realization, grouping, correction, resolution, and refund provenance answer different questions.

## When to reconsider genericization

A common relation abstraction becomes worth reconsidering when concrete work earns stronger overlap. Useful triggers include:

1. **Repeated practical law** — two or more relation kinds become practical, persisted facts and independently require the same identity, admission, append, or lookup law.
2. **Domain-name removal** — the names can be stripped away and a nontrivial shared law survives, in the style of Observation 042.
3. **Application pressure** — a real operation needs one common relation interface, and keeping separate typed paths creates duplicated semantic risk rather than merely duplicated syntax.
4. **Relation history pressure** — concrete lifecycle or correction behavior shows that relation facts themselves need stable identity and retained revision history.

Until one of those pressures appears, separate typed meanings are cheaper than a universal abstraction because they preserve the distinctions already observed.

## Consequence for a future application layer

This checkpoint supports a deliberately typed application boundary:

```text
human vocabulary
    ->
typed application action / overlay
    ->
neutral LOAM facts plus explicit typed evidence
```

An eventual household-facing Ada layer therefore does not need a universal relation API before its first useful operation. It can translate one human action at a time and introduce only the relation meaning that the operation actually needs.

For example, a first recording entrance can publish neutral Event / Effect facts without also inventing Series, refund, realization, or generic relation machinery. If a later action explicitly completes a Plan or records refund provenance, that application operation can carry its own typed evidence while the common Core remains small.

This makes the current absence of a generic relation framework intentional rather than unfinished plumbing.

## Checkpoint

The current terrain is:

```text
063 realization       \
064 Series membership  > relation-family resemblance
065 refund provenance /

shared:
  explicit relational information can survive independently of endpoint content

not shared yet:
  one operational law
  one cardinality
  one lifecycle
  one identity rule
  one admission rule
  one persistence stream
```

Therefore:

```text
Observation 085:          not introduced
Practical Core additions: 0
Persistence additions:    0
CLI additions:            0
wire-format additions:    0
```

The next useful step can be application pressure rather than another abstraction pass. A small human-facing entrance can now test which of these explicit relation meanings is actually needed in use.