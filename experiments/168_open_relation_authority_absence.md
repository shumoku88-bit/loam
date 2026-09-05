# Observation 168: Does burden determine an open relation, and what does missing relation evidence mean?

Status: bounded Alloy observation following Observation 167's separation of missing burden evidence from explicit burden evidence.

Observation 168 is based directly on current `main`. Open Observations 163–167 are semantic antecedents, not code dependencies.

## Question

Observations 163–166 exposed three different axes:

```text
physical movement
burden allocation
directional open relation + discharge provenance
```

Observation 167 then showed that, for burden evidence:

```text
0 current facts -> unknown
1 current fact  -> known
2+ current facts -> unresolved
```

The next ambiguity is whether an open relation can be treated more cheaply.

Two tempting rules are:

```text
Outside bears this quantity
    -> Outside owes Household
```

and:

```text
no open-relation evidence
    -> no open relation exists
```

Observation 168 asks whether either rule is justified.

## Observation-local model

The model keeps one exact quantity `Unit` anchored to an existing Effect-shaped source coordinate. Burden meaning and open-relation evidence are separate.

Open-relation interpretation has two observation-only forms:

```text
NoRelation
DirectedRelation(debtor, creditor)
```

`NoRelation` is not proposed as a production fact type. It is only a marker that lets the model distinguish:

```text
unknown
```

from:

```text
known-none
```

A future practical representation of known-none could instead be a completeness marker, admission contract, closed-world scope, writer guarantee, or another smaller form.

Relation evidence is append-only:

```text
RelationFact
RelationCorrection(target -> replacement)
```

with an acyclic correction graph. Arrival/storage order carries no authority.

## Probe 1: outside burden does not determine a receivable

Two worlds retain the same source Unit and the same outside burden.

One explicitly knows:

```text
NoRelation
```

The other explicitly knows:

```text
Outside -> Household
```

Expected: **SAT**.

So burden allocation answers who economically bears the quantity. It does not by itself answer whether a debt remains open between parties.

## Probe 2: missing relation evidence supports none and some

Two worlds retain the same source and burden and have no relation evidence.

One latent completion has no relation. The other has an outside-to-household relation.

Expected: **SAT**.

Therefore:

```text
no relation evidence
!=
known zero relation
```

for incomplete historical evidence.

## Probe 3: explicit known-none differs from absence

Two worlds both have latent `NoRelation` meaning.

One has no relation evidence. The other has one explicit current fact whose meaning is `NoRelation`.

Expected: **SAT**.

This separates epistemic state from domain state:

```text
unknown
!=
known-none
```

## Probe 4: household burden can coexist with a payable

A household-borne quantity may still carry:

```text
Household -> CardIssuer
```

as in a deferred card purchase.

Expected: **SAT**.

So the independence runs in both directions:

```text
Outside burden -/-> receivable
Household burden -/-> no obligation
```

## Probe 5: relation correction need not change burden or source movement

An initially recorded `NoRelation` interpretation is corrected append-only to:

```text
Friend -> Household
```

while retaining the same Unit, source Effect, and burden allocation.

Expected: **SAT**.

Thus a mistaken relation interpretation does not imply a mistaken physical Event or mistaken burden allocation.

## Probe 6: sibling relation corrections remain conflict

One base interpretation receives two sibling corrections:

```text
                 Outside -> Household
                /
NoRelation
                \
                 Household -> Outside
```

Expected: **SAT**.

No storage-order or later-arrival winner is introduced.

## Deliberately too-strong assertions

### Absence means no relation

```text
no current relation fact
-> semantic relation = NoRelation
```

Expected counterexample: **SAT**.

### Outside burden implies receivable

```text
Outside burden
-> Outside -> Household
```

Expected counterexample: **SAT**.

## Expected retained laws

### One current relation fact determines meaning

Expected counterexample: **UNSAT**.

### Relation correction preserves the source anchor

The target and replacement interpretations concern the same quantity Unit, hence the same Effect anchor.

Expected counterexample: **UNSAT**.

## Candidate boundary

If the matrix holds:

```text
burden evidence
    independent from
open-relation evidence
```

and relation evidence has at least four observable states:

```text
0 current relation facts
    -> unknown

1 current fact = known-none
    -> explicitly no open relation

1 current fact = directed edge
    -> known debtor/creditor relation

2+ current facts
    -> unresolved candidates
```

This means `outstanding = 0` is not generally derivable from historical absence of relation evidence.

Once a directional relation is admitted, Observation 165's discharge correspondence may still derive outstanding without storing an `OutstandingBalance`.

## What this does not earn

Observation 168 does **not** earn:

- a production `NoRelation` fact;
- a production `RelationFact` / `RelationCorrection` family;
- a universal `Relation` framework;
- automatic receivable creation from outside burden;
- automatic payable creation from household burden;
- closed-world interpretation of historical data;
- a Party registry;
- stored payable / receivable / outstanding balances;
- automatic matching or discharge;
- persistence, CLI, TUI, or canonical-data migration.

## Practical implication if qualified

A future writer may be allowed to publish both burden and relation evidence together when the human operation supplies both meanings. That convenience would be writer evidence, not a Core theorem connecting the two axes.

Likewise, a future import/backfill process may establish a completeness boundary after which absent relation facts can safely mean none, but such a cutover would need explicit authority. It cannot be inferred from old physical movement records alone.
