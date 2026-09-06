# Observation 203 — Can reservation and movement rights collapse into one flat future-use envelope?

Status: **DONE / COUNTEREXAMPLE**

Concept-pressure source: **F001 + F033 compression probe**

## Question

Two already-qualified counterexamples sit next to each other:

```text
F001
  physical quantity + lifecycle evidence
    != temporary reservation / available quantity

F033
  physical quantity + broad allocation eligibility
    != operation-specific future movement rights
```

The September concept-pressure selection asks whether these two pressures can be compressed into one smaller information-equivalent boundary for selected future-use queries.

A tempting experiment-local candidate is a flat map:

```text
operation -> usable quantity
```

Observation 203 attacks that compression before any production noun is introduced.

## Joint model

The model retains only the two independent dimensions already witnessed by F001 and F033:

```text
held       exact physical quantity
reserved   temporarily encumbered quantity
allowed    operation-specific permission evidence
```

The selected future-use view is:

```text
usable(op)
  = held - reserved   when op is permitted
  = 0                 when op is prohibited
```

This is deliberately query-bounded. It is not a wallet implementation and does not claim that every real product uses one global reservation amount across all operations.

## Result

Dedicated Observation 203 Alloy CI completed SUCCESS on exact executable head:

```text
21ef8c27990541c85d7749250b8fe180f49a468c
```

workflow run:

```text
34008569484
```

The workflow requires the following result matrix and succeeded:

```text
reservationVsPolicyCollision                       SAT
zeroHoldingMasksRights                             SAT
blockedOperationsMaskReservation                   SAT
sameRightsDifferentReservationChangesEnvelope      SAT
sameReservationDifferentRightsChangesEnvelope      SAT
OperationalEnvelopeDeterminesRights                SAT counterexample
OperationalEnvelopeDeterminesReservation           SAT counterexample
OperationalEnvelopeDeterminesSelectedEvidence      SAT counterexample
ExplicitDimensionsDetermineEnvelope                UNSAT counterexample
```

### Reservation vs policy collision

Two worlds can have the same held quantity and the same flat usable envelope while differing completely in provenance:

```text
Left
  held = 10
  reserved = 10
  Spend / Send / Withdraw permitted

Right
  held = 10
  reserved = 0
  Spend / Send / Withdraw prohibited

both
  usable(Spend)    = 0
  usable(Send)     = 0
  usable(Withdraw) = 0
```

Therefore the flat envelope cannot distinguish temporary encumbrance from policy/right restriction.

### Zero holding masks future rights

With held quantity zero, permitted and prohibited operations both currently expose usable quantity zero.

Future movement rights therefore cannot be reconstructed from current usable quantity alone. Rights remain independently observable because they can matter to quantity that arrives later.

### Blocked operations mask reservation

If all selected operations are prohibited, different reservation states also collapse to the same all-zero operational envelope.

Temporary reservation evidence therefore cannot be reconstructed from the flat envelope either.

### Both original pressures survive jointly

With rights fixed, changing reservation changes the selected usable envelope.

With reservation fixed, changing operation rights changes the selected usable envelope.

The two dimensions therefore remain independently observable inside the same vocabulary.

### Positive sufficiency boundary

When held quantity, reservation evidence, and operation-right evidence are all equal, the selected operation-wise usable quantities are equal. Alloy found no counterexample in the selected scope.

## Qualification

The attempted scalar compression is falsified:

```text
operation -> usable quantity
```

is too small to replace:

```text
reservation provenance
+
operation-right provenance
```

for the selected future-use questions.

This does **not** prove that LOAM needs separate production `Hold` and `Capability` concepts.

A single tagged carrier may still share mechanics. But if it retains both reservation provenance and permission provenance, it has not reduced the two independent information dimensions. That is packaging, not semantic compression.

The architectural reading therefore remains B-level conservative-extension pressure rather than C-level Core-shape pressure:

```text
share mechanics if useful
but do not erase meaning merely to obtain one noun
```

No existing Event, Locus, Quantity, Capacity, Correction, or Scheduled meaning was shown to require redesign.

## Boundary

Research only.

No Core/Application/Persistence/CLI/TUI/canonical-data change.

No production `Hold`, `WalletKind`, `Capability`, `Restriction`, `AvailableBalance`, or account-state family is introduced.

The experiment does not claim global wallet equivalence, product-specific payment rules, settlement timing, authorization capture behavior, overdraft/credit semantics, or future inbound-quantity policy.
