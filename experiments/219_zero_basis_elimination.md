# Observation 219 — can zero-only QuantityBasis be eliminated after historical reconstruction?

Status: **QUALIFIED REAL-DATA FACTORIZATION (CANDIDATE A: RETIRE CURRENT HOUSEHOLD QuantityBasis)**

Research starting point: LOAM `b95e2b418365b7960b0087a1b9329b52578f16b5`  
Dogfood data starting point: `loam-data` `188319456d96fa24ac0af7b251ff612800ab6522`

## Question

LOAM introduced `QuantityBasis` for an important reason:

```text
an exact quantity already present when the selected application image begins
```

is not itself an Event/change.

That remains a valid distinction in general. But the current household image has changed shape after historical reconstruction. The retained historical Event world now includes opening entries and the current `loam-data/basis.loam` contains only five exact-zero rows:

```text
BASIS   hpb-f03c35726ecef0bd2a75f55924a16c59   cash         jpy  0
BASIS   hpb-6fd930c873f75aa46b895927e0f1a04c   paypay       jpy  0
BASIS   hpb-e6f335b5e4b7c469fb0c01edfe39f475   smbc         jpy  0
BASIS   hpb-2bcac2e31accbde5dc38be20db060e7d   yucho        jpy  0
BASIS   hpb-66457c1f2ca809c70115b0dd7339aebb   all-country  jpy  0
```

The question is now practical:

> In the current real `loam-data` household image, can the five exact-zero QuantityBasis facts be replaced by one explicit finite zero-origin domain while preserving all practical balance answers and fail-closed behavior?

## Existing law that must survive

Production deliberately distinguishes:

```text
missing basis != exact zero basis
```

So this experiment must not replace missing basis with implicit global zero.

The smaller candidate, if any, must preserve a finite explicit domain:

```text
D : finite set of Locus × Measure coordinates

c in D
  -> application-start quantity is known exactly zero

c not in D
  -> no zero-origin claim (basisMissing / refusal)
```

## Inventory of dependent evidence

Current `loam-data` was inspected for any dependencies:

1. `basis-corrections.loam`: ABSENT. Production interprets absent as empty (`ofCorrections? []`).
2. `basis-cut.tsv`: ABSENT. Production interprets absent as empty (`some []`).
3. Search for the five stable `QuantityBasisId` values (`hpb-f03c35726ecef0bd2a75f55924a16c59`, `hpb-6fd930c873f75aa46b895927e0f1a04c`, `hpb-e6f335b5e4b7c469fb0c01edfe39f475`, `hpb-2bcac2e31accbde5dc38be20db060e7d`, `hpb-66457c1f2ca809c70115b0dd7339aebb`):
   - Only observable in `basis.loam` itself.
   - Zero occurrences in `loam` repository (core, application, persistence, TUI, CLI, tests, workflows).
   - Zero occurrences in `loam-data` outside `basis.loam`.

Conclusion: **The five stable basis IDs are not observable anywhere in LOAM behavior or data relationships.**

## Practical balance parity on current household image

Using production `Loam.BalanceReview.loadSnapshot` over the selected Movement manifest generation in `loam-data` (`movement-authority/CURRENT` manifest 2) and comparing against candidate `ZeroOriginDomain` evaluation using correction-aware Event quantity projection (`Loam.Application.inspectQuantity`):

| Coordinate | Production A (`BalanceReview`) | Candidate B (`ZeroOriginDomain`) | Parity |
| :--- | :--- | :--- | :--- |
| `cash / jpy` | 909 | 909 | **EXACT EQUALITY** |
| `paypay / jpy` | 728 | 728 | **EXACT EQUALITY** |
| `smbc / jpy` | 81575 | 81575 | **EXACT EQUALITY** |
| `yucho / jpy` | 5000 | 5000 | **EXACT EQUALITY** |
| `all-country / jpy` | 5600 | 5600 | **EXACT EQUALITY** |

Arithmetic parity holds at 100% precision across all five coordinates.

## Synthetic and negative controls in Lean

`experiments/219_zero_basis_elimination.lean` defines the scratch candidate:

```lean
structure ZeroOriginDomain where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup
  deriving Repr, DecidableEq

def inspectWithZeroOriginDomain
    (domain : ZeroOriginDomain)
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (coordinate : EffectCoordinate) : CurrentQuantityAnswer :=
  if domain.contains coordinate then
    liftInspection <|
      inspectQuantity events eventCorrections coordinate.locus coordinate.measure
  else
    .basisMissing
```

The probe verifies:

1. **Exact Parity**: On all 5 household coordinates (`cash`, `paypay`, `smbc`, `yucho`, `all-country`), the candidate answer exactly equals production `inspectCurrentQuantityWithBasisCorrections` with zero bases.
2. **Negative Control 1 (Domain Removal)**: Removing `cash` from `ZeroOriginDomain` results in `.basisMissing`, NOT `.current 0`.
3. **Negative Control 2 (Unrelated Coordinate)**: Coordinates with recorded Event activity outside the domain (e.g. `food / jpy`, `unknown / jpy`) evaluate to `.basisMissing`. Recorded Event activity alone does not earn an admitted balance.
4. **Negative Control 3 (Nonzero Basis)**: A synthetic nonzero basis (e.g. `cash` starting at 100) produces `1009`, which strictly differs from the candidate Event-only answer (`909`). Nonzero starting quantities cannot be eliminated into zero-origin domain.
5. **Negative Control 4 (Malformed / Duplicate Domain)**: `ZeroOriginDomain.ofCoordinates? [cashJpy, cashJpy] = none`. Duplicate entries fail closed at construction.

All controls compile and pass with Lean native decision procedures.

## Accounting and opening-history inspection

Inspection of the selected Movement manifest events in `loam-data`:

- `smbc`: Reconstructed history begins on 2026-04-04 with event `e0186` (+9843 jpy) balanced against `equity:opening-balances` (-9843 jpy), description "Opening Balance".
- `paypay`: Reconstructed history begins on 2026-04-04 with event `e0219` (+192 jpy) balanced against `equity:opening-balances` (-192 jpy), description "Opening Balance".
- `yucho`: Contains opening adjustment event `e0532` (+16 jpy) on 2026-06-07 balanced against `equity:opening-balances` (-16 jpy), description "ゆうちょ残高調整", alongside inter-account transfers from `smbc`.
- `all-country`: History starts from zero on 2026-05-18 with event `e0188` (investment purchase transfer of 1000 jpy from `smbc`). It genuinely originated at zero prior to the first transaction.
- `cash`: Earliest recorded event is earned income `e0414` (+3000 jpy) on 2026-07-20.

Because the HRA reconstruction absorbed opening balances directly into the Event stream (via `equity:opening-balances` or initial transfers), `basis.loam` had its quantities set to zero for all five coordinates.

**Distinction: Arithmetic parity vs. Coverage evidence:**
The five rows in `basis.loam` carry **no quantity information**. Their actual production function is strictly serving as a **finite coordinate whitelist** (coverage domain). The candidate `ZeroOriginDomain` preserves this exact coverage domain without retaining five redundant zero integers or unused stable UUIDs.

## Conclusion: Candidate A — RETIRE CURRENT HOUSEHOLD QuantityBasis

All practical conditions are satisfied:
1. All 5 selected basis quantities are exact zero.
2. No basis corrections or cuts exist or depend on the stable basis IDs.
3. The five stable basis IDs are completely unobserved elsewhere.
4. Exact practical balance parity holds across all 5 coordinates.
5. Fail-closed negative controls prove that missing coordinates do not become zero.
6. The historical provenance shows that opening quantities are already held in reconstructed Events.

Current five zero basis facts carry no quantity information beyond explicit zero-origin domain coverage.

## Proposed smallest production boundary

When the final cutover is implemented in production:

```lean
/-- Explicit finite set of coordinates known to originate at exact zero. -/
structure ZeroOriginDomain where
  coordinates : List EffectCoordinate
  nodup : coordinates.Nodup
```

Persistence representation can be a simple coordinate list file (e.g. `zero-origin-domain.tsv` or retaining `balance-view.tsv` / explicit domain file).

**Non-goals:**
- Do NOT introduce a generic `Origin`, `Account`, `Ledger`, global chronology, or new framework.
- Do NOT infer zero-origin from `balance-view.tsv` or AccountingRole without explicit domain admission.
