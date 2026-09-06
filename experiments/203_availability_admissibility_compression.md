# Observation 203 — Can reservation and movement rights collapse into one flat future-use envelope?

Status: **OBSERVING / UNTESTED**

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

For example, the selected wallet might expose how much can currently be spent, sent, or withdrawn.

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

## Attacks

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

If SAT, a flat operational envelope cannot distinguish temporary encumbrance from policy/right restriction.

### Zero holding masks future rights

With held quantity zero, permitted and prohibited operations both currently expose usable quantity zero.

If SAT, operation rights are not recoverable from current usable quantity because rights may matter to later incoming quantity.

### Blocked operations mask reservation

If all selected operations are already prohibited, different reservation evidence can also collapse to the same all-zero envelope.

If SAT, temporary reservation is not recoverable from the flat envelope either.

## Positive boundary

The model also checks that the original independent dimensions are sufficient for the selected future-use view:

```text
same held
+ same reserved
+ same allowed
  -> same operation-wise usable quantity
```

Expected UNSAT counterexample.

## Expected interpretation

If the collision witnesses are SAT and the positive sufficiency check is UNSAT, then the narrow result is:

```text
one scalar operation -> usable quantity envelope
  is too small to replace
  reservation evidence + operation-right evidence
```

That would **not** prove that LOAM needs separate production `Hold` and `Capability` concepts.

A single tagged carrier might still share mechanics, but if it retains both reservation provenance and permission provenance it has not reduced the two independent information dimensions. It would be packaging, not semantic compression.

The likely architectural reading would remain B-level conservative-extension pressure, with a stronger warning:

```text
share mechanics if useful
but do not erase meaning merely to obtain one noun
```

## Boundary

Research only.

No Core/Application/Persistence/CLI/TUI/canonical-data change.

No production `Hold`, `WalletKind`, `Capability`, `Restriction`, `AvailableBalance`, or account-state family is introduced.

The experiment does not claim global wallet equivalence, product-specific payment rules, settlement timing, authorization capture behavior, overdraft/credit semantics, or future inbound-quantity policy.
