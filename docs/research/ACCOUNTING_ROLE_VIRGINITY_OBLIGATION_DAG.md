# G2-015 — Initial AccountingRole virginity obligation DAG

Status: **Generation-2 audit evidence — FIX QUALIFIED**

Primary instruments: **DRAKONview + production-bound obligation DAG + ownership-order inspection + direct regression**.

## Question

`AccountingRolePublisher` deliberately has no role-change history. Its only qualified mutation is one first role assignment for a Locus that is still semantically virgin: the assignment must not retroactively classify quantity evidence already retained under that Locus.

The original publication boundary therefore refused a Locus already used by:

```text
Actual Event evidence
Scheduled occurrence evidence
```

Generation 2 asks whether those two quantity families still exhaust the retained facts that can make a Locus non-virgin.

## Existing boundary

Before G2-015, first-assignment admission was:

```text
currently admitted Locus
        |
        v
no AccountingRole yet
        |
        v
absent from retained Actual Effects
        |
        v
absent from retained Scheduled movements
        |
        v
first AccountingRole assignment allowed
```

The candidate review delegates to the same `eligibleInitialLoci` predicate, so presentation and publication shared the same omission.

Publication re-read its guards under the ownership order:

```text
Scheduled -> Actual -> AccountingRole
```

## New retained quantity family

`CurrentQuantityAnchor` was added later as an independent application-level evidence family for exact current quantities observed together at one reconciliation boundary.

One assertion retains:

```text
Locus x Measure -> exact current Quantity
```

without requiring that the Locus occur in an Actual Event or Scheduled occurrence.

The existing `Loam/Tests/CurrentQuantityAnchor.lean` fixture already demonstrates that shape: `cash / jpy = 25` is retained by a current anchor even though the selected Event fixture contains only the `debt` Locus. `RoleBalanceReview` then consumes the anchored cash quantity successfully.

Therefore:

```text
absent from Actual
AND absent from Scheduled
```

no longer implies:

```text
no retained quantity evidence for this Locus
```

## Counterexample to the old virginity test

A production-representable state can have:

```text
Locus "anchor-used" is currently admitted
AccountingRole("anchor-used") is unresolved
Actual contains no "anchor-used" Effect
Scheduled contains no "anchor-used" movement change
CurrentQuantityAnchor contains:
    anchor-used / jpy = 750
```

Under the pre-G2-015 predicate every old guard succeeds, so an initial role could be attached after the quantity assertion already existed.

That is exactly the retroactive-classification shape the virgin-only publisher was designed to avoid. No new role-history semantics have been earned to make that mutation meaningful.

## Minimal semantic repair

Extend the existing pure admission question by one independent retained family:

```text
currentAnchorUsesLocus(anchor, locus)
    = any anchor assertion whose coordinate.locus = locus
```

The qualified candidate becomes:

```text
V1  Locus is currently admitted
V2  AccountingRole is unresolved
V3  Locus absent from Actual Effects
V4  Locus absent from Scheduled movement changes
V5  Locus absent from CurrentQuantityAnchor assertions
```

Only V5 is new.

`eligibleInitialLoci` and `propose?` consume the same anchor evidence, so UI candidate discovery and publication admission remain one semantic decision rather than parallel copies.

## Ownership obligation

Checking the anchor without locking it would leave a race:

```text
role writer reads empty anchor
        |
        +---- concurrent reconciliation publishes anchor-used quantity
        |
        v
role writer publishes AccountingRole
```

The anchor writer already owns:

```text
Actual -> CurrentQuantityAnchor
```

The AccountingRole writer already owns:

```text
Scheduled -> Actual -> AccountingRole
```

The smallest compatible extension is:

```text
Scheduled
   |
   v
Actual
   |
   v
CurrentQuantityAnchor
   |
   v
AccountingRole
```

This preserves both existing relative orders. No new lock coordinator or authority family is required.

Missing anchor storage means no retained anchor evidence and is treated as the existing empty evidence value. Malformed existing anchor storage fails closed.

## Why Locus admission is still not added to the lock chain

The selected Locus must be admitted, but current Locus admission publication is add-only. The production operation cannot revoke an already observed positive permission while the role publication is in progress.

A concurrent new admission can only make an earlier read conservatively stale in the refusing direction; publication can be retried. G2-015 therefore does not widen ownership merely because the policy is another input.

## Stop point

This result does **not** earn general AccountingRole history or a generic "all quantity evidence" registry.

- Existing Actual and Scheduled guards stay local and explicit.
- CurrentQuantityAnchor is added because it is a demonstrated independent retained quantity family that falsifies the old implication.
- Opening support is not separately promoted into this guard by G2-015. A valid opening witness is tied to an Event containing its supported coordinate, so the existing Actual-use guard already covers the ordinary valid case.
- Zero-origin coverage states a historical support condition, not an independently asserted nonzero current quantity, and is not added merely for symmetry.
- No `AccountingRoleAuthority` abstraction is introduced. This audit concerns semantic virginity and one compatible ownership extension, not filename centralization.

## Regression obligations

The focused AccountingRole publisher test pins all of the following:

```text
fresh admitted Locus
    -> remains eligible and publishable

anchor-only Locus
    -> absent from candidate set
    -> pure propose? refuses
    -> production publishInitialRole refuses
    -> AccountingRole map unchanged for that Locus
    -> CurrentQuantityAnchor image unchanged
```

Existing Actual-used, Scheduled-used, duplicate-role, non-admitted and authority-isolation checks remain in place.

## Obligation DAG

```text
                         initial AccountingRole
                               virginity
                                  |
          +-----------------------+-----------------------+
          |                       |                       |
          v                       v                       v
   identity/policy           retained quantity        role state
          |                       |                       |
 admitted Locus          +--------+--------+          unresolved
                         |        |        |
                         v        v        v
                      Actual  Scheduled  Anchor
                         |        |        |
                         +--------+--------+
                                  |
                         all absent for Locus
                                  |
                                  v
                       first assignment allowed
```

The write-side ownership chain closes the same three mutable quantity observations before the role image is replaced.

## Qualification

Production/audit head `8b21af79e3561c47e6e7041b62b0e3b137558fd4` qualified green before this documentation-only verdict update.

- Production TUI run `35050561948`: **SUCCESS**, all 62 substantive build/test steps.
  - shared initial AccountingRole publisher build: SUCCESS
  - virgin-Locus initial AccountingRole publication, including anchor-only refusal: SUCCESS
  - AccountingRole administration interaction: SUCCESS
  - downstream Balance, Capacity, routing, Reports, CycleBudget and Scheduled routing surfaces: SUCCESS
- Compression Audit run `35050561967`: **SUCCESS**.
- Selected Lean Observations run `35050562012`: **SUCCESS**.

Repository search also found no production writer that reverses the new ownership relation: CurrentQuantityAnchor publication owns `Actual -> Anchor`, and the AccountingRole map has one production publisher.

## Qualified verdict

```text
virgin-only AccountingRole boundary          KEEP
Actual-use guard                             KEEP
Scheduled-use guard                          KEEP
CurrentQuantityAnchor-use guard              ADD / FIX QUALIFIED
candidate/publication semantic sharing       KEEP
lock order                                   EXTEND COMPATIBLY / QUALIFIED
role history                                 DO NOT ADD
new AccountingRole authority abstraction     DO NOT ADD
```

**G2-015: FIX QUALIFIED — CurrentQuantityAnchor joins AccountingRole virginity; KEEP virgin-only role boundary.**
