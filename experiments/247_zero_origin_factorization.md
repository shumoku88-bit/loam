# Experiment 247: zero-origin factorization

Status: **research lab; no production or loam-data migration authorized**

Tracking: #700

## Question

Current `loam-data` retains explicit zero-origin coverage for five coordinates. Earlier work already removed the older five explicit zero quantity-basis rows, but the remaining representation still needs a minimality check.

Can the five coordinate facts be replaced by one smaller statement such as:

> an application-origin boundary was established

without losing any intended coverage answer?

## Model

The model separates:

```text
DirectWorld
  covered : set Coordinate

FactoredWorld
  origin : lone Origin
  trackedFromOrigin : set Coordinate
```

with the derived factored answer:

```text
coverage = trackedFromOrigin   when origin evidence exists
coverage = none                otherwise
```

This factorization is intentionally conservative. It asks what information survives, not how many lines a file uses.

## Intended conclusions

### 1. An explicit origin fact can participate in a reconstruction

For every direct coverage set, a factored representation exists with explicit origin evidence and the same tracked coordinate set.

So the current representation can be factored into:

```text
origin evidence
+
which coordinates that evidence covers
```

### 2. The origin fact alone is insufficient

Two worlds can share the same explicit origin evidence while differing in which coordinates are tracked from that origin. Their coverage answers differ.

Therefore this proposed compression is invalid:

```text
five covered coordinates
    -> one application-origin fact
```

unless some additional retained fact already determines the coordinate set.

## Concrete current-data dependency audit

The current `loam-data` sets are:

```text
ZeroOriginCoverage
  cash
  paypay
  smbc
  yucho
  all-country

balance-view selection
  cash
  paypay
  smbc
  yucho
  all-country

cycle-funding selection
  cash
  paypay
  smbc

AccountingRole = ASSET
  cash
  paypay
  smbc
  yucho
  all-country
  point
```

The current LocusAdmission vocabulary is much wider still and contains both holdings and non-holding loci.

So the obvious candidate dependencies already separate:

```text
ZeroOriginCoverage != CycleFunding
ZeroOriginCoverage != all AccountingRole=ASSET
ZeroOriginCoverage != LocusAdmission
```

`balance-view.tsv` happens to be extensionally equal to ZeroOriginCoverage today, but production deliberately consumes them as independent inputs. `BalanceReview.project` accepts both `coverage` and selected `coordinates`; selection asks which balances to display, while coverage decides whether each selected coordinate is answerable. Missing coverage for a selected coordinate is an error rather than a new zero fact.

Therefore current equality with `balance-view.tsv` is accidental state equality, not a justified functional dependency:

```text
balance-view selection = current coverage set
    does not imply
balance-view selection -> zero-origin evidence
```

This eliminates the most obvious duplicate-state candidates without inventing a new observation.

## What remains open

The remaining question is narrower and historical:

> Was there one independently observed reconstruction/cutover fact that established zero-origin completeness for exactly these five coordinates as a group?

If stronger retained evidence establishes both:

```text
one origin boundary
+
exactly which coordinates that boundary covers
```

then the syntax or authority shape can change. But if the second component still has to name the same five coordinates, semantic information has not been reduced.

## Stop rule

Do not claim compression from replacing five rows with one header plus five names. That changes syntax, not semantic information content.

A production deletion is earned only if the covered coordinate set itself is derivable from other retained evidence while preserving the distinction between:

- known complete from zero;
- present but not covered from zero;
- unknown/unanswerable balance origin.
