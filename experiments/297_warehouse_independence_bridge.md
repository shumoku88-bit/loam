# Observation 297 — warehouse independence versus future sufficiency

Status: **LEAN-CHECKED LITERATURE BRIDGE**

## Question

How exactly does LOAM `FutureSufficient` relate to classical database view
complements and query/update-independent data warehouses?

## Literature boundary

### Bancilhon and Spyratos, 1981

`Update Semantics of Relational Views` defines a complementary view so that a
view together with its complement contains enough information to recompute the
database. In their formulation, if `f` is the user view and `g` its complement,
the product `f × g` is lossless: database states are in one-to-one
correspondence with `(f(s), g(s))` representations.

The same paper connects complements to view-update translation under **constant
complement**: a translated view update changes the user-visible view while the
chosen complement remains invariant.

Reference:

- François Bancilhon and Nicolas Spyratos, `Update Semantics of Relational
  Views`, ACM Transactions on Database Systems 6(4), 1981, pp. 557-575.
  DOI: 10.1145/319628.319634.

### Laurent, Lechtenbörger, Spyratos, and Vossen, 2001

`Monotonic Complements for Independent Data Warehouses` makes the query/update
split particularly explicit.

For a source database state `d`, warehouse mapping `V`, source query `q`, and
source update `u`:

- query independence requires a warehouse query `q̄` with
  `q(d) = q̄(V(d))`;
- update independence requires a warehouse update `ū` with
  `V(u(d)) = ū(V(d))`, computable using the reported source update and current
  warehouse state without querying the source.

The paper studies independence relative to arbitrary selected sets of queries
and updates, and uses auxiliary/complementary views to obtain it.

Reference:

- Dominique Laurent, Jens Lechtenbörger, Nicolas Spyratos, Gottfried Vossen,
  `Monotonic Complements for Independent Data Warehouses`, The VLDB Journal
  10(4), 2001, pp. 295-315. DOI: 10.1007/s007780100055.

### Ranzato and Tapparo, 2007

Strong preservation in abstract interpretation supplies a broader neighbouring
theory: an abstraction strongly preserves a language when concrete and abstract
models agree on all formulas in that language. Minimal strongly preserving
abstractions are characterized through completeness/refinement machinery.

Reference:

- Francesco Ranzato and Francesco Tapparo, `Generalized Strong Preservation by
  Abstract Interpretation`, Journal of Logic and Computation 17(1), 2007,
  pp. 157-197. arXiv:cs/0401016.

## LOAM correspondence

Observation 297 gives the following generic translation.

Let:

    State      source / retained-evidence state
    Operation  allowed source operation
    Question   selected observation
    encode     retained summary / warehouse representation

and retain the existing LOAM notions:

    SufficientFor
    FutureSufficient

### Current query independence

`Observation029.SufficientFor answer vocabulary encode` says exactly that one
decoder can answer every selected current question from `encode state` alone.

This is the direct generic analogue of query independence for the selected
question vocabulary.

### Exact update independence

Observation 297 defines:

    UpdateIndependent step encode

to mean that there exists:

    summaryStep : Summary -> Operation -> Summary

such that:

    summaryStep (encode state) operation
      =
    encode (step state operation)

for every state and operation.

This is the generic commuting-square form of warehouse update independence.

### Main implication

Lean proves:

    current query sufficiency
    + exact local summary update independence
        ->
    FutureSufficient

under arbitrary deterministic state transitions and arbitrary selected question
vocabularies.

The proof first lifts one-step summary maintenance to any finite continuation,
then applies the current query decoder to the resulting summary.

Thus the classical query/update-independent warehouse obligations are a
**sufficient condition** for LOAM future sufficiency.

## Why the notions are not identical

Observation 297 also proves strict separation.

A summary can be `FutureSufficient` while no deterministic local summary update
can reproduce its exact future encoding.

The witness retains:

    visible : Bool
    junk    : Bool

and uses a `promote` operation that sets `visible = true` while preserving
`junk`.

The summary is:

    (visible, if visible then junk else false)

When `visible = false`, the two different `junk` states collapse to the same
summary. After `promote`, their encodings differ because the representation
chooses to expose `junk`.

Nevertheless, selected answers depend only on `visible`, so the original
summary plus the operation continuation still answers every selected future
question.

Lean therefore proves:

    FutureSufficient
    and
    not UpdateIndependent

for the same encoder.

Interpretation: **future answerability does not require exact future-summary
reproduction**.

## View complement is stronger again

Observation 297 defines a constructive `ReconstructingComplement` boundary:

    recover (view state, complement state) = state

and proves that such exact source reconstruction implies `FutureSufficient` for
every selected future vocabulary.

But the strictness witness also proves a future-sufficient encoder need not be
injective. Therefore it need not reconstruct exact retained source state.

The relationship is therefore:

    exact source reconstruction by view + complement
                  |
                  v
    current query sufficiency + exact summary maintenance
                  |
                  v
    selected future-answer sufficiency

The arrows are implications. Observation 297 supplies a generic counterexample
to the reverse implication from the bottom to exact summary maintenance, and
also shows that the bottom condition does not require an injective encoding.

## Consequence for the LOAM research question

The database literature already contains the central intuition that information
missing from a current view may need to be retained for later queries or
updates, and that auxiliary/complementary information can be minimized relative
to selected operations.

LOAM should therefore not claim invention of future-sensitive information
retention.

The narrower remaining question is operational and proof-directed:

> Given a real append-only/revisable evidence system and a proposed destructive
> compression, can the implementation produce a machine-checked preservation
> certificate or a concrete future-context counterexample for the declared
> operation/question vocabulary?

LOAM's existing Observations 192-195, scientific witness, document-provenance
witness, and this bridge suggest a path toward such a verifier.

## Stop condition

Do not replace `FutureSufficient` with database-style update independence.

Exact local summary maintenance is a useful stronger obligation when the summary
itself must evolve autonomously, but Observation 297 shows that it is not
necessary merely to preserve selected future answers.

Likewise, do not require exact source reconstruction unless the product actually
needs a classical lossless complement.
