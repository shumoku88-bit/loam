# AccountingRole / ActualRouting obligation DAG — G2-008

Status: **Generation-2 audit evidence — QUALIFIED**

Primary instruments: **DRAKONview + obligation DAG**.

G2-008 places `AccountingRoleReview` and `ActualRoutingReview` beside each other at the same semantic scale. Both read retained AccountingRole evidence, but they answer different questions and own different control topology.

## 1. AccountingRoleReview stays thin

`AccountingRoleReview.loadInitialCandidates` loads the canonical evidence needed for one question:

```text
Which currently admitted Loci are still eligible for a first AccountingRole assignment?
```

The read boundary does not reimplement that admission rule. It delegates directly to:

```text
AccountingRolePublisher.eligibleInitialLoci
```

which owns the same conditions used by publication:

- current Locus admission;
- no existing AccountingRole;
- no retained Actual use;
- no retained Scheduled use.

The DRAKON path is therefore mostly evidence loading followed by one semantic delegation. Adding a read-specific candidate engine or generic role-query abstraction would duplicate the publication rule.

Verdict: **KEEP**.

## 2. ActualRoutingReview has one role-classification root

The routing administration snapshot starts from one current admitted-Locus list and retained AccountingRole evidence.

Before G2-008, the same `approved` list was traversed three times:

```text
approved.filterMap roleOf? == Expense
approved.filterMap roleOf? == known non-Expense
approved.filter    roleOf? == None
```

The three outputs are not independent questions. For each admitted Locus, retained role evidence has exactly one of these observable outcomes:

```text
roleOf?(locus)
      |
      +-- Expense -----------------> default routing row
      |
      +-- known non-Expense -------> optional routing row
      |
      +-- None --------------------> unresolved-role diagnostic
```

The production factorization therefore uses one private `partitionApproved` traversal. `roleOf?` is evaluated once per admitted Locus and the Locus enters exactly one of the three surfaces.

For known roles, `history.statusAt locus observedAt` is still calculated only for the row actually emitted. The factorization does not broaden routing obligations and does not infer role from sign, spelling, route presence, or Purpose.

Verdict: **SIMPLIFY QUALIFIED**.

## 3. Order is part of the observable projection

The old three filters preserved the current Locus-admission order inside each result list. A one-pass implementation must preserve that property.

`partitionApproved` therefore uses an order-preserving right fold. Qualification pins:

```text
Expense rows:
coffee, shipping

known non-Expense rows:
cash, yucho, pension, debt

unresolved:
mystery
```

The test does not merely compare set membership. It checks that the new partition retains the existing presentation order.

## 4. Independent side evidence must not become partition leaves

Two other fields in `ActualRoutingReview.Snapshot` remain deliberately outside the role-classification DAG.

### Historical-only routing subjects

```text
routing-history subjects
minus
current Locus admission
```

answers whether retained route history references a Locus that is not currently admitted. This depends on routing-history provenance and current policy, not on the current AccountingRole decision.

### Purpose candidates

Purpose candidates are derived from retained Capacity rows. They are available choices for routing administration, not classifications of admitted Loci.

The complete read shape is therefore:

```text
                     current admitted Loci
                              |
                              v
                        roleOf? ONCE
                       /      |      \
                      /       |       \
               Expense   known other   unknown
                  |            |           |
             default rows  optional rows  unresolved

routing history + admission ----------------> historical-only routes
Capacity -----------------------------------> Purpose candidates
```

A generic `RoutingReviewContext`, larger multi-authority partition, or shared AccountingRole/ActualRouting report abstraction would combine unrelated reasons for existence.

Verdict: **KEEP SEPARATE**.

## 5. No cross-authority atomicity claim

`ActualRoutingReview` composes current Locus admission, AccountingRole, ActualRouting, and Capacity authorities. G2-008 does not claim these files form one atomic publication generation. The review remains an administration projection over independently retained authorities.

The simplification is only about repeated evaluation of one already-loaded AccountingRole map over one already-loaded admitted-Locus list.

## 6. Qualification result

PR #924 qualified the factorization with all relevant workflows green:

- Compression Audit;
- Selected Lean Observations;
- Production TUI.

Production TUI specifically passed the routing-facing steps:

- shared Actual Purpose routing administration boundary build;
- current Expense Locus routing audit;
- Actual Purpose routing administration interaction.

The downstream Budget Window, Stock-Flow, Transactions-Flow, conditional Liquidity, Reports, Cycle Budget, and Scheduled routing checks also remained green.

Final verdict:

```text
AccountingRoleReview: KEEP
ActualRouting role partition: SIMPLIFY QUALIFIED
historical/Purpose side evidence: KEEP SEPARATE
```
