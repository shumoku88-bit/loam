# Experiment 247: zero-origin factorization

Status: **research lab; no production or loam-data migration authorized**

Tracking: #700

## Question

Current `loam-data` retains explicit zero-origin coverage for five coordinates. Earlier work already removed the older five explicit zero quantity-basis rows, but the remaining representation still needs a minimality check.

Can the five coordinate facts be replaced by one smaller statement such as:

> an application-origin boundary was established

without losing any intended coverage answer?

## Model result being tested

The model separates:

```text
DirectWorld
  covered : set Coordinate

FactoredWorld
  originEstablished : Bool
  trackedFromOrigin : set Coordinate
```

with the derived factored answer:

```text
coverage = trackedFromOrigin   when originEstablished
coverage = none                otherwise
```

This factorization is intentionally conservative. It asks what information survives, not how many lines a file uses.

## Expected conclusions

### 1. An explicit origin fact can participate in a reconstruction

For every direct coverage set, a factored representation exists with an explicit established origin and the same tracked coordinate set.

So the current representation can be *factored* into:

```text
origin evidence
+
which coordinates that evidence covers
```

### 2. The origin flag alone is insufficient

Two worlds can share the same explicit origin-established fact while differing in which coordinates are tracked from that origin. Their coverage answers differ.

Therefore this proposed compression is invalid:

```text
five covered coordinates
    -> one Boolean application-origin fact
```

unless some additional retained fact already determines the coordinate set.

### 3. The next real question is dependency, not encoding

The useful follow-up is:

> Is `trackedFromOrigin` independently selected household evidence, or is it already exactly determined by another retained relation/configuration such as an admitted holding universe?

If another independently earned retained set determines the same five coordinates, ZeroOriginCoverage may be derivable and removable as duplicate state.

If not, the coordinate set still carries independent information even if its file syntax is simplified.

## Stop rule

Do not claim compression from replacing five rows with one header plus five names. That changes syntax, not semantic information content.

A production deletion is earned only if the covered coordinate set itself is derivable from other retained evidence while preserving the distinction between:

- known complete from zero;
- present but not covered from zero;
- unknown/unanswerable balance origin.
