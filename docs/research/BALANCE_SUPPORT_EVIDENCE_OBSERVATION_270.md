# Observation 270 — Balance Support Evidence boundary

Status: **BOUNDED EXPERIMENT — DO NOT PROMOTE YET**

Baseline: `5b853ef06d11ed7f7aff0aff5bf5c6048700ddf9`

## Question

After Capacity persistence was recompressed, the next authority-DAG candidate was
the current-balance support trio:

```text
ZeroOriginCoverage
OpeningSupport
CurrentQuantityAnchor
```

These are independent retained authorities, but `RoleBalanceReview` requires their
supported coordinates to be non-overlapping.

The question is whether LOAM should introduce a persistence-neutral proof-carrying
aggregate that admits that cross-authority invariant once.

## Observation-local candidate

`Observation270.SupportEvidence` carries:

```text
zeroOrigin
opening
currentAnchor
+
proof that the three support families do not overlap
```

`SupportEvidence.ofParts?` rejects all three pairwise conflict shapes:

- ZeroOriginCoverage × OpeningSupport;
- ZeroOriginCoverage × CurrentQuantityAnchor;
- OpeningSupport × CurrentQuantityAnchor.

A successfully admitted value therefore carries the separation invariant without
a downstream caller re-running the overlap scan.

## What the aggregate does not prove

The experiment deliberately excludes world-relative obligations.

### OpeningSupport

An opening witness remains usable only if its referenced Event survives on the
current correction frontier and contains the supported coordinate.

That cannot be proved from the three support authorities alone.

### CurrentQuantityAnchor

An anchor remains usable only if its reflected roots are valid stable roots in the
current Actual correction world.

That likewise cannot be proved from the support authorities alone.

Therefore:

```text
cross-family separation      static / aggregate-local
opening witness validity     Actual-world relative
anchor reflected-root cut    Actual-world relative
```

A single broad `BalanceContext` would erase this distinction and is rejected.

## Production reachability audit

Current production overlap checks have two different owners:

1. `CurrentQuantityAnchorPublisher.propose?`
   - checks proposed new anchor assertions against existing ZeroOriginCoverage and
     OpeningSupport;
   - this is publication admission and cannot be removed by a read-side aggregate.

2. `RoleBalanceReview.project`
   - checks the three already-retained support families before routing current
     balance coordinates;
   - this is currently the only production consumer that would directly benefit
     from the proposed proof-carrying aggregate.

No second production read consumer currently repeats the same complete
three-family separation admission.

## Result

The type shape is sound and useful as a demonstration of Lean's proof-carrying
value style, but production promotion is not yet earned.

Promoting it now would replace one local `validateSupportSeparation` boundary with:

- one new public semantic type;
- one constructor/admission API;
- accessors and imports;
- a new concept every caller must understand.

That is not a net simplification while only one production read boundary consumes
the full invariant.

## Promotion trigger

Revisit when at least one of these becomes true:

1. a second production read boundary independently needs the same complete
   three-family separation invariant;
2. RoleBalance is split into multiple downstream stages that would otherwise
   revalidate the same support bundle;
3. another proof obligation can be discharged once by the same exact static
   aggregate without importing Actual-world semantics.

Do not promote merely because the type can be written.

## Verdict

```text
semantic independence of three authorities        KEEP
physical persistence separation                    KEEP
proof-carrying aggregate shape                     VALID
production aggregate today                         DO NOT ADD
RoleBalance local separation check                 KEEP
Anchor publisher overlap admission                 KEEP
Opening witness Actual-world validation            KEEP
Anchor reflected-root Actual-world validation      KEEP
generic BalanceContext                             REJECT
```

Observation 270 therefore records a useful negative result:

> LOAM can encode the separation invariant as a proof-carrying value, but current
> production topology does not yet repeat that obligation enough to justify a new
> semantic aggregate.
