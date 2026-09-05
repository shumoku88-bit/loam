# Observation 187 — relational search over typed intervention candidates

Status: observation-only miniKanren experiment following Observations 185–186.

## Pressure

Observations 185–186 established a boundary for household what-if questions:

```text
canonical evidence
+ one typed hypothetical intervention
-> derived projection
```

The next question is different. A decision surface may know the desired outcome but not the intervention:

> Which small typed intervention bundles could satisfy an explicit relief threshold?

That is a backwards-search question. Writing one named scenario after another in Lean would qualify each scenario, but it would not itself search for the unknown candidate bundle.

## Why miniKanren returns

Observations 006–007 previously earned miniKanren for finite relational/backwards search. PR #231 later retired the runtime because no practical or later observation still needed it.

Observation 187 supplies a new concrete pressure for that same distinct role. The runtime is reintroduced only for this observation track, not as a production LOAM dependency.

Datalog is not introduced here. The present question is not primarily transitive fact lookup or explanation over a fixed relation graph; it asks for unknown combinations that satisfy a constraint. A later explanation/reachability question may earn a Datalog observation separately.

## Deliberately synthetic search space

No household amounts, private source data, current balances, or subscription identities are present in the public fixture.

The finite candidate vocabulary is:

```text
kind                   synthetic relief   protected?
suppress-scheduled             2              no
suppress-scheduled             3              no
reallocate-capacity            4              no
reduce-consumption             5              no
pause-contribution             6              no
liquidate-asset               10              yes
```

The first search is intentionally bounded to singleton or two-action bundles and a synthetic threshold of 10 units.

The intervention kind remains in every answer. Equal numeric relief therefore does not collapse different household meanings.

## Executable relation

`scheme/187_relational_intervention_search.rkt` defines:

```text
finite typed actions
<-> canonical-order bundle
<-> synthetic relief
<-> caller protection policy
<-> threshold feasibility
```

miniKanren chooses the unknown actions. Host arithmetic is used under `project` only after the finite action relation has grounded synthetic relief values. This experiment therefore does **not** claim a relational replacement for LOAM arithmetic.

The search has two modes:

- `allow-protected`: enumerate every feasible candidate bundle;
- `protect`: reject any bundle containing a caller-protected intervention.

Protection is input policy, not a universal claim that one intervention kind is morally preferable to another.

## Expected boundary

At synthetic threshold 10, the full finite search has eight feasible singleton/two-action bundles. Once protected candidates are excluded, two remain:

```text
reallocate-capacity 4 + pause-contribution 6 = 10
reduce-consumption 5 + pause-contribution 6 = 11
```

The result is candidate enumeration, not recommendation or optimization. There is no ranking, utility function, `best` answer, or canonical Scenario state.

## Authority boundary

The miniKanren result is not allowed to become a second household accounting engine.

For real household use the intended composition is:

```text
LOAM-derived current evidence
-> finite typed candidate vocabulary
-> miniKanren candidate search
-> replay each candidate through qualified LOAM Application projections
-> derived comparison for the client
```

A candidate that cannot be expressed and replayed through a qualified LOAM Application operation is not an authoritative household answer merely because miniKanren found it.

In particular, this observation does not implement multi-intervention production simulation, safe-to-spend, automatic Capacity transfer, recommendation, or asset-sale advice.

## What this can establish

If qualification succeeds, Observation 187 earns only the following claim:

> A finite typed intervention vocabulary can be searched backwards for candidate bundles while preserving intervention provenance and caller protection constraints, without making the search runtime canonical household authority.

It does not establish that miniKanren belongs in the steady-state product runtime. It may remain an optional search instrument invoked only when a genuine backwards-search question appears.

## Next pressure

The next useful gate is not a larger synthetic search grammar. It is one private dogfood composition in which a real decision target supplies candidate pressure while every returned candidate is still validated through existing or newly earned LOAM Application hypothetical operations.

If that composition requires multiple simultaneous interventions, earn the smallest multi-intervention Application projection first rather than teaching miniKanren to imitate LOAM's accounting semantics.
