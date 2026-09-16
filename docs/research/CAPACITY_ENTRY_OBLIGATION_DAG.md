# G2-013 — Capacity entry obligation DAG

Status: **Generation-2 audit evidence — FIX QUALIFIED + KEEP existing shared tail**

Primary instruments: **DRAKONview + production-bound obligation DAG + persistence trace + focused runtime regression**.

## Question

`CapacityPublisher` has two production entrances into one shared publication tail:

- binary `Draft` via `publish`;
- multi-coordinate `BalancedDraft` via `publishBalanced`.

Earlier compression already earned the shared tail. Generation 2 asks whether the two admission paths still carry equivalent obligations before they enter that tail.

## Existing shared publication tail

Both entrances eventually call `publishAdmittedMovement`.

That tail owns:

```text
fresh CapacityMovementId
        |
        v
construct balanced JPY CapacityMovement
        |
        v
append movement + effective evidence in memory
        |
        v
publish effective evidence FIRST
        |
        v
publish Capacity movement authority SECOND
```

The effective-first order is deliberate. If the movement authority write fails after effective publication, the effective row is inert because no matching movement is authoritative. Subsequent writers detect incomplete evidence and require explicit recovery.

Because the second write can fail, every representation-level condition required by `CapacityPersistence.encodeCapacityMemory?` must be discharged before the shared tail starts publishing.

## Same-scale entrance obligations

### Binary Draft

Before G2-013 the binary entrance checked:

```text
B1 effective date is real
B2 quanta > 0
B3 source != destination
B4 source has sufficient current entitlement
```

It then converted the draft to exactly two signed changes and entered the shared tail.

For `q > 0` and `source != destination`, the converted two-change movement automatically has:

- non-empty changes;
- non-zero quantities;
- distinct coordinates;
- exact zero total.

Those are therefore derived from B2/B3 plus construction.

However one persistence obligation was not derived:

```text
B5 every Purpose endpoint token is persistable
```

### BalancedDraft

The multi-coordinate entrance already checks:

```text
M1 effective date is real
M2 changes non-empty
M3 every quantity non-zero
M4 coordinates unique
M5 every Purpose coordinate token is persistable
M6 exact zero total
M7 no Purpose entitlement becomes negative
```

Only M5 is also an independent obligation of the binary entrance that was not already enforced there.

## Persistence hazard

`CapacityPersistence.encodeCapacityChangeRow?` refuses a `.purpose` coordinate whose token fails `Persistence.validToken`.

Before G2-013 this source path was possible:

```text
binary Draft
  source = .unallocated
  destination = .purpose invalidToken
  quanta > 0
        |
        v
validateDraft succeeds
        |
        v
unallocated source admission succeeds
        |
        v
publishAdmittedMovement
        |
        +--> saveEffective? succeeds
        |
        v
saveMovements?
        |
        v
encodeCapacityMemory? rejects invalid Purpose token
        |
        v
movement authority not written
but effective evidence already retained
        |
        v
next writer sees incomplete evidence
and requires explicit recovery
```

This is not merely a malformed external file case. Source inspection shows that the production writer itself could create the recover-required state from a directly constructed binary Draft.

## Minimal shared obligation

The qualified repair adds one local predicate:

```text
coordinatePersistable : CapacityCoordinate -> Bool

unallocated    -> true
purpose token  -> Persistence.validToken token
```

Both entrance validators now use it:

```text
BalancedDraft M5
Binary Draft   B5
```

No new Core vocabulary is introduced. No Purpose registry is introduced. Token syntax remains owned by `Persistence.TokenSyntax`; the publisher only asks whether the coordinate it is about to persist satisfies that existing representation rule.

## Why not route binary validation through all BalancedDraft validation?

The binary entrance owns useful operation-specific diagnostics and stronger construction facts:

- positive transfer amount;
- source and destination must differ;
- named-source entitlement admission.

Blindly replacing binary validation with `validateBalancedDraft draft.toBalancedDraft` would either duplicate checks, alter refusal vocabulary/order, or obscure which balanced-shape obligations are already mathematical consequences of the binary constructor.

Generation 2 therefore shares only the independent M5/B5 obligation and keeps the two entrances otherwise distinct.

## Regression obligation

The focused production test constructs a binary Draft with:

```text
source      = unallocated
destination = purpose ""   -- non-persistable token
quanta      = 1
```

The writer must refuse before publication. After refusal, both retained families must still have exactly the same cardinality as before the attempt:

```text
Capacity movements  unchanged
Effective entries   unchanged
```

This directly pins the dangerous boundary, not merely the returned error.

## Obligation DAG

```text
                     shared representation obligation
                     Purpose coordinate persistable
                              |
              +---------------+---------------+
              |                               |
              v                               v
         binary Draft                    BalancedDraft
              |                               |
 date / positive q /                    date / nonempty /
 distinct endpoints                    nonzero / unique /
              |                        exact balance
 source entitlement                          |
              |                        per-Purpose >= 0
              +---------------+---------------+
                              |
                              v
                    publishAdmittedMovement
                              |
                       effective FIRST
                              |
                       movement SECOND
```

Every obligation above the join must be discharged before the first persistence write.

## Historical cross-check

First-generation compression already did the right structural work:

- #736 shared the admitted publication tail instead of duplicating identity/allocation/persistence mechanics;
- #737 closed the corresponding Capacity semantic-compression candidate;
- later work made fresh identity allocation total without changing the two-entry semantics.

G2-013 does not reopen that abstraction. It finds one missing entrance precondition exposed only when the two paths are drawn at the same scale against the effective-first persistence order.

## Qualification

Production/audit head `1be67d1d83ddec7c9e27027cb3b6d222ba1786a9` qualified green before this final documentation-only status update:

- Shared Capacity Publisher run `35049242155`: **SUCCESS**
  - Capacity publisher/review build: SUCCESS
  - focused runtime publication test, including non-persistable binary Purpose refusal and unchanged retained-family counts: SUCCESS
- Compression Audit run `35049242147`: **SUCCESS**
- Selected Lean Observations run `35049242115`: **SUCCESS**
- Production TUI run `35049242109`: **SUCCESS**
  - all 62 substantive build/test steps passed;
  - Capacity publisher build, transfer, rebalance, review, Current Coverage, and Capacity workspace all passed.

The production change therefore closes the writer-created incomplete-evidence path without disturbing the existing Capacity semantic surface.

## Verdict

```text
shared admitted publication tail             KEEP
binary positive / distinct-endpoint checks   KEEP LOCAL
balanced multi-coordinate shape checks       KEEP LOCAL
coordinate persistence predicate             SHARE LOCALLY
binary missing persistence gate              FIX QUALIFIED
new Capacity abstraction                     DO NOT ADD
```

**G2-013: FIX QUALIFIED + KEEP existing shared tail.**
