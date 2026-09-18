# Raw / Admitted Distinction Integrity Audit — LOAM Lean 4 Production Code

**Date**: 2026-09-18
**Scope**: Production code only — falsification-first, examining whether forged values reach canonical state
**Auditor**: Leanstral
**Repository**: shumoku88-bit/loam

> **Current-status note — 2026-09-19**
>
> This audit remains useful as falsification evidence, but its original type
> inventory predates later hardening and read-image promotion.
>
> - `LocusAdmissionVocabulary` is now proof-carrying with
>   `nodup : approved.Nodup`; it is not a raw Category-C collection.
> - `AdmittedActualImage` is now the production Actual read image and carries
>   proof fields tying `currentEvents` and `currentValidities` to retained
>   evidence. Full normalized admission still happens at its constructor path.
> - `AdmittedRelationUnit`, `AdmittedRelationDischarge`, and
>   `MovementAdmission.Admitted` remain public plain structures, but repository
>   reachability finds no production constructor bypass around their admission
>   functions. Canonical Actual publication is re-admitted before authority
>   switch.
>
> Therefore "plain/forgeable Lean structure" alone is not classified as a
> production semantic gap. The relevant question is whether a forged value can
> cross a trusted production boundary without re-admission.

---

## Audit Methodology

This audit distinguishes between:

### A. Proof-carrying representation
The Lean type itself carries the invariant via a proof field.

### B. Constructor-restricted representation
The type has no proof field, but external code cannot call the constructor directly — only smart constructors or admission functions.

### C. Convention-only admitted representation
The type accepts any value. Correctness depends entirely on calling convention (e.g., "always call `admitRelationUnit?` before using").

**Level 1 (not a gap)**: Raw type is constructible but intended as raw provenance.
**Level 2 (boundary gap)**: Forged value bypasses an admission boundary.
**Level 3 (production semantic gap)**: Forged value reaches canonical persistence or user-visible output.

---

## Type Inventory

### Raw Types (no invariants, no proof fields)

| Type | Location | Classification |
|------|----------|----------------|
| `RelationUnit` | `Core/OpenRelation.lean:66-73` | **C** — raw provenance |
| `RelationDischarge` | `Core/OpenRelation.lean:93-97` | **C** — raw provenance |
| `LocusAdmissionVocabulary` | `Core/LocusAdmission.lean` | **C** — raw provenance |
| `ActualEvidence` | `ActualEvidence.lean:23-32` | **C** — aggregate of raw types |

### Admitted Types (with source Effect resolved)

| Type | Location | Classification |
|------|----------|----------------|
| `AdmittedRelationUnit` | `Application/OpenRelationFrontier.lean:33-35` | **C** — but construction requires `admitRelationUnit?` |
| `AdmittedRelationDischarge` | `Application/RelationDischargeFrontier.lean:29-32` | **C** — but construction requires admission function |

### Memory Types (Nodup-invariant via Prop field)

| Type | Location | Classification |
|------|----------|----------------|
| `EventMemory` | `Core/EventMemory.lean:18-20` | **A** — Prop field `idNodup` |
| `ActualValidityMemory` | `Core/ActualValidity.lean:33-35` | **A** — Prop field `eventNodup` |
| `CapacityMemory` | `Core/CapacityMemory.lean:22-24` | **A** — Prop field `idNodup` |
| `ScheduledMemory` | `Core/ScheduledMemory.lean:17-19` | **A** — Prop field `idNodup` |
| `CapacityEffectiveMemory` | `Core/CapacityEffective.lean:32-34` | **A** — Prop field `movementNodup` |
| `EventCorrectionMemory` | `Core/EventCorrectionMemory.lean:18-21` | **A** — Prop field `idNodup` |
| `ActualReversalMemory` | `Core/ActualReversal.lean:61-64` | **A** — Prop fields `targetNodup`, `reversalNodup` |
| `ActualValidityHistory` | `Core/ActualValidityHistory.lean:87-92` | **A** — Prop fields `factRefNodup`, `correctionIdNodup` |

### Authority Types

| Type | Location | Classification |
|------|----------|----------------|
| `ActualAuthority.World` | `ActualAuthority.lean:73-80` | **C** — aggregates `EventMemory`, raw `RelationUnit`, raw `RelationDischarge` |

---

## Finding 1: `AdmittedRelationUnit` — Forgeable but Protected

### Classification: **T2** — Convention Gap (No Bypass to Production)

### Source locations
- `Core/OpenRelation.lean:66-73` — `RelationUnit` definition
- `Application/OpenRelationFrontier.lean:33-35` — `AdmittedRelationUnit` definition
- `Application/OpenRelationFrontier.lean:108-118` — `admitRelationUnit?` admission function

### Claimed invariant

`AdmittedRelationUnit` claims to represent a relation unit whose source Effect has resolved and whose current semantic shape has passed admission.

### Actual invariant

`AdmittedRelationUnit` has **no proof fields**. It is a plain structure:

```lean
structure AdmittedRelationUnit where
  relation : RelationUnit
  source : Effect
```

Any caller can forge:

```lean
def forged : AdmittedRelationUnit := {
  relation := {
    id := ⟨"rel-1"⟩
    sourceEvent := ⟨"nonexistent-event"⟩
    sourceEffect := ⟨"nonexistent-effect"⟩
    debtor := .household
    creditor := .external ⟨"party-1"⟩
    quantity := Quantity.ofQuanta 100
  }
  source := {
    key := none
    locus := ⟨"any-locus"⟩
    amount := SomeAmount.ofQuantity ⟨"jpy"⟩ (Quantity.ofQuanta 500)
  }
}
```

This compiles and creates an `AdmittedRelationUnit` with:
- Non-existent source Event and Effect
- Arbitrary quantity (100 vs source 500 — violates admission rule)

### Boundary trace

```text
forged AdmittedRelationUnit
  -> ANY production consumer (relation frontier, discharge frontier, query)
```

### Bypass

**Forged value CAN be constructed.** However, we must check if any production consumer actually uses `AdmittedRelationUnit` values.

### Production reachability

`AdmittedRelationUnit` is used in:
1. `RelationSourceState.knownPositive` — used by `currentRelationState?` (Application layer)
2. `AdmittedRelationDischarge.target` — used by `admittedRelationDischargesFor?` (Application layer)

Both are **Application-layer functions**, not persistence or authority boundaries.

### False-positive risk

**LOW.** The `admitRelationUnit?` function exists and is used in the canonical path. Forged values would need to be explicitly constructed by a malicious Lean caller and passed to Application functions. The Application functions (`currentRelationState?`, `admittedRelationDischargesFor?`) perform their own validation.

### Confirmed containment

The `admitRelationUnit?` function is called by:
- `admitAll?` (OpenRelationFrontier.lean:143-149)
- `admittedRelationFrontier?` (OpenRelationFrontier.lean:255-261)
- `admittedRelationSourceFrontier?` (OpenRelationFrontier.lean:273-286)
- `admitActualEvidence?` (NormalizedActualPersistence.lean:102-108)

All canonical paths go through `admitRelationUnit?`.

---

## Finding 2: `ActualEvidence` — Forgeable Aggregate

### Classification: **T2** — Convention Gap (No Bypass to Canonical Persistence)

### Source locations
- `ActualEvidence.lean:23-32` — `ActualEvidence` definition
- `Persistence/NormalizedActualPersistence.lean:281-343` — `decodeNormalizedActual?` construction path
- `Persistence/NormalizedActualPersistence.lean:54-130` — `admitActualEvidence?` validation

### Claimed invariant

`ActualEvidence` is described as "persistence-neutral aggregate of admitted Actual evidence." The name suggests all contained values are admitted.

### Actual invariant

`ActualEvidence` is a plain structure with no proof fields. It contains `relations : List RelationUnit` and `discharges : List RelationDischarge`, both raw types.

### Forged construction

```lean
def forgedEvidence : ActualEvidence := {
  events := { events := [], idNodup := by simp }
  validity := {
    facts := []
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp
  }
  descriptions := EventDescriptionMemory.empty
  merchants := EventMerchantEvidenceMemory.empty
  corrections := { corrections := [], idNodup := by simp }
  reversals := ActualReversalMemory.empty
  relations := [{  -- invalid: debtor=creditor, non-existent source
    id := ⟨"rel-1"⟩
    sourceEvent := ⟨"nonexistent"⟩
    sourceEffect := ⟨"ef-1"⟩
    debtor := .household
    creditor := .household
    quantity := Quantity.ofQuanta (-5)
  }]
  discharges := [{  -- invalid: self-discharge
    event := ⟨"ev-1"⟩
    target := ⟨"rel-1"⟩
    quantity := Quantity.ofQuanta 10
  }]
}
```

This compiles without error.

### Boundary trace

```text
forged ActualEvidence
  -> admitActualEvidence? (validation)
    -> CORRECTLY REJECTED (lines 92-108: relation checks, lines 111-130: discharge checks)

forged ActualEvidence
  -> DIRECT PASS to encodeNormalizedActual? (bypassing admitActualEvidence?)
    -> encodeNormalizedActual? calls admitActualEvidence? at line 350
    -> CORRECTLY REJECTED

forged ActualEvidence
  -> ActualAuthority.publishActual? (bypassing encodeNormalizedActual?)
    -> encodeNormalizedActual? called internally at ActualAuthority.lean:79
    -> CORRECTLY REJECTED
```

### Production reachability

**CANNOT REACH canonical persistence or user-visible output.**

All canonical paths that produce canonical state go through one of:
1. `decodeNormalizedActual?` → `admitActualEvidence?` — rejects forged evidence
2. `encodeNormalizedActual?` → `admitActualEvidence?` — rejects forged evidence (line 350)
3. `ActualAuthority.publishActual?` → `encodeNormalizedActual?` → `admitActualEvidence?` — rejects forged evidence

### False-positive risk

**LOW.** The `admitActualEvidence?` function performs thorough validation (7 checks, lines 54-130). Any `ActualEvidence` that bypasses this function cannot reach canonical state through canonical paths.

### Confirmed containment

```text
decodeNormalizedActual?
  ├── Event.ofEffects? (per-event validation)
  ├── EventMemory.ofEvents? (identity uniqueness)
  ├── ActualValidityHistory.ofParts? (factRef uniqueness)
  ├── admitActualEvidence? (CROSS-CUTTING VALIDATION)
  │     ├── correctionFrontierMemory? (reference closure, acyclicity)
  │     ├── admittedActualValidityMemory? (single current date per Event)
  │     ├── relation checks (existence, endpoints, quantity bounds, frontier)
  │     ├── discharge checks (uniqueness, positivity, self-discharge, quantity bounds)
  │     └── REJECTS forged evidence
  └── Returns Option ActualEvidence (caller must check)

encodeNormalizedActual?
  └── admitActualEvidence? (ALWAYS CALLED at line 350)
  └── REJECTS forged evidence
```

---

## Finding 3: `RelationUnit` Source Reference — Not Type-Enforced

### Classification: **T2** — Convention Gap

### Source locations
- `Core/OpenRelation.lean:66-73` — `RelationUnit` definition
- `Application/OpenRelationFrontier.lean:108-118` — `admitRelationUnit?` source check
- `Persistence/NormalizedActualPersistence.lean:92-108` — `admitActualEvidence?` source check

### Claimed invariant

`RelationUnit.sourceEvent` and `RelationUnit.sourceEffect` are assumed to reference existing Events/Effects.

### Actual invariant

No invariant. `RelationUnit` is a raw structure.

### Forged construction

```lean
def orphanRelation : RelationUnit :=
  { id := ⟨"rel-orphan"⟩
    sourceEvent := ⟨"nonexistent-event"⟩
    sourceEffect := ⟨"nonexistent-effect"⟩
    debtor := .external ⟨"party-1"⟩
    creditor := .household
    quantity := Quantity.ofQuanta 100
  }
```

This compiles fine.

### Boundary trace

```text
orphanRelation
  -> ParsedTx.relations (NormalizedActualPersistence.lean:298)
  -> ActualEvidence.relations (NormalizedActualPersistence.lean:339)
  -> admitActualEvidence? (NormalizedActualPersistence.lean:92-108)
    -> evidence.events.findById? relation.sourceEvent
    -> returns none
    -> CORRECTLY REJECTED (line 93)
```

### Production reachability

**CANNOT REACH canonical persistence.** The `admitActualEvidence?` function rejects orphan relations at line 93.

### False-positive risk

**LOW.** The canonical path validates source existence.

---

## Finding 4: `RelationDischarge` Target Reference — Not Type-Enforced

### Classification: **T2** — Convention Gap

### Source locations
- `Core/OpenRelation.lean:93-97` — `RelationDischarge` definition
- `Application/RelationDischargeFrontier.lean:112-127` — `admitRelationDischargeForTarget?` validation
- `Persistence/NormalizedActualPersistence.lean:115-130` — `admitActualEvidence?` discharge checks

### Claimed invariant

`RelationDischarge.target` references a valid `RelationUnit`.

### Actual invariant

No invariant. `RelationDischarge` is a raw structure.

### Forged construction

```lean
def orphanDischarge : RelationDischarge :=
  { event := ⟨"ev-1"⟩
    target := ⟨"nonexistent-relation"⟩
    quantity := Quantity.ofQuanta 50
  }
```

This compiles fine.

### Boundary trace

```text
orphanDischarge
  -> ParsedTx.discharges (NormalizedActualPersistence.lean:241-251)
  -> ActualEvidence.discharges (NormalizedActualPersistence.lean:339)
  -> admitActualEvidence? (NormalizedActualPersistence.lean:115-130)
    -> evidence.relations.find? fun r => r.id = discharge.target
    -> returns none
    -> discharge event exists check passes (line 119)
    -> CORRECTLY REJECTED at line 127-128 (admittedRelationDischargesFor? returns none)
```

### Production reachability

**CANNOT REACH canonical persistence.** The `admitActualEvidence?` function rejects orphan discharges.

### False-positive risk

**LOW.** The canonical path validates target existence.

---

## Finding 5: `ActualValidityHistory` — Duplicate FactRef Rejected by Type System

### Classification: **T1** — Raw Type Gap (No Production Bypass)

### Source locations
- `Core/ActualValidityHistory.lean:87-92` — structure definition with `factRefNodup`
- `Core/ActualValidityHistory.lean:99-114` — `ofParts?` enforcement

### Claimed invariant

`factRefNodup` ensures no duplicate fact references.

### Actual invariant

`factRefNodup : (facts.map ActualValidityFact.ref).Nodup` is a **Prop field**. In Lean, you cannot provide a false proof. Attempting:

```lean
def duplicateFacts : ActualValidityHistory String :=
  { facts := [.base ⟨"ev-1"⟩ "2024-01-01", .base ⟨"ev-1"⟩ "2024-01-02"]
    factRefNodup := by simp  -- FAILS: [.root ev-1, .root ev-1] is not Nodup
    corrections := []
    correctionIdNodup := by simp
  }
```

This **does not compile** because `by simp` cannot prove a false statement.

### Boundary trace

```text
N/A — type system prevents invalid construction
```

### Production reachability

**N/A — type system prevents construction of invalid values.**

### False-positive risk

**FALSE POSITIVE.** The type system itself enforces this invariant. No production bypass possible.

---

## Finding 6: `ActualAuthority.World` — Contains Raw Types

### Classification: **T2** — Convention Gap

### Source locations
- `ActualAuthority.lean:73-80` — `World` structure definition
- `ActualAuthority.lean:117-130` — `loadSelectedWorld?` function

### Claimed invariant

`World` represents the authoritative current state of Actual evidence.

### Actual invariant

`World` contains raw `relations : List RelationUnit` and `discharges : List RelationDischarge`:

```lean
structure World where
  events : EventMemory
  validity : ActualValidityHistory String
  descriptions : EventDescriptionMemory
  relations : List RelationUnit          -- RAW
  discharges : List RelationDischarge    -- RAW
  locusAdmission : LocusAdmissionVocabulary
```

### Forged construction

```lean
def forgedWorld : ActualAuthority.World := {
  events := { events := [], idNodup := by simp }
  validity := {
    facts := []
    factRefNodup := by simp
    corrections := []
    correctionIdNodup := by simp
  }
  descriptions := EventDescriptionMemory.empty
  relations := [{  -- invalid relations
    id := ⟨"rel-1"⟩
    sourceEvent := ⟨"nonexistent"⟩
    sourceEffect := ⟨"ef-1"⟩
    debtor := .household
    creditor := .household
    quantity := Quantity.ofQuanta (-5)
  }]
  discharges := []
  locusAdmission := LocusAdmissionVocabulary.empty
}
```

This compiles fine.

### Boundary trace

```text
forgedWorld
  -> ActualAuthority.loadSelectedWorld? (ActualAuthority.lean:117-130)
    -> loads from actual.loam via decodeNormalizedActual?
    -> CORRECTLY REJECTED by admitActualEvidence?

forgedWorld
  -> DIRECT PASS to publishActual? (bypassing load)
    -> encodeNormalizedActual? called
    -> admitActualEvidence? called at line 350
    -> CORRECTLY REJECTED
```

### Production reachability

**CANNOT REACH canonical persistence.** All canonical paths that read or write `World` go through `decodeNormalizedActual?` → `admitActualEvidence?` or `encodeNormalizedActual?` → `admitActualEvidence?`.

### False-positive risk

**LOW.** The `loadSelectedWorld?` function loads from `actual.loam` which is always validated. Direct construction of `World` bypasses the load path but cannot reach canonical persistence.

---

## Finding 7: `Event.ofEffects?` — Anonymous Effect Bypass

### Classification: **T1** — Raw Type Gap (Intentional Design)

### Source locations
- `Core/Event.lean:81-85` — `Event.ofEffects?` with `keyNodup` check
- `Persistence/NormalizedActualPersistence.lean:201-203` — parser uses `ofAnonymousQuantity`

### Claimed invariant

Events enforce that retained `EffectKey`s are unique.

### Actual invariant

Anonymous Effects (`key := none`) bypass the `keyNodup` check entirely. Multiple anonymous Effects can coexist at the same coordinate.

### Forged construction

```lean
def eventWithDuplicateAnonymous : Event :=
  let effects := [
    Effect.ofAnonymousQuantity ⟨"loc-1"⟩ ⟨"meas-1"⟩ (Quantity.ofQuanta 100),
    Effect.ofAnonymousQuantity ⟨"loc-1"⟩ ⟨"meas-1"⟩ (Quantity.ofQuanta 200)
  ]
  Event.ofEffects? ⟨"ev-1"⟩ effects  -- SUCCEEDS — anonymous Effects don't conflict
```

This compiles and succeeds. The theorems `ofEffects?_sameCoordinate_anonymous_two` and `quantityAt_sameCoordinate_anonymous_two` explicitly confirm this behavior.

### Boundary trace

```text
N/A — intentional design per Observation 106
```

### Production reachability

**Canonical path allows it.** This is a confirmed design choice, not a bug.

### False-positive risk

**FALSE POSITIVE.** The design intentionally allows multiple anonymous Effects at the same coordinate. The theorems confirm this.

---

## Finding 8: `LocusAdmissionVocabulary` — Procedural Admission

### Classification: **T2** — Convention Gap

### Source locations
- `Core/LocusAdmission.lean` — `LocusAdmissionVocabulary` definition
- `AccountingRolePublisher.lean:54-64` — `propose?` function checks `locusAdmission.allows`

### Claimed invariant

`LocusAdmissionVocabulary` represents the currently approved Locus vocabulary.

### Actual invariant

No invariant. `LocusAdmissionVocabulary` has `approved : List LocusId` with no constraints.

### Forged construction

```lean
def forgedVocabulary : LocusAdmissionVocabulary :=
  { approved := [⟨"unapproved-locus"⟩] }
```

This compiles fine. The `propose?` function would reject it, but the vocabulary itself is unconstrained.

### Boundary trace

```text
forgedVocabulary
  -> AccountingRolePublisher.propose? (AccountingRolePublisher.lean:82)
    -> locusAdmission.allows draft.locus
    -> checks if draft.locus is in approved list
    -> REJECTED (line 83)
```

### Production reachability

**CANNOT REACH canonical persistence.** The `propose?` function validates against the vocabulary. If the vocabulary is forged, the check may pass incorrectly, but the resulting `AccountingRoleMap` is still validated by `ofAssignments?`.

### False-positive risk

**LOW.** The `propose?` function performs the check. A forged vocabulary that incorrectly approves a Locus would allow an invalid role assignment, but:
1. The assignment is still validated by `AccountingRoleMap.ofAssignments?`
2. The assignment is checked against actual usage in `propose?` (lines 84-89)

---

## Finding 9: `CapacityEffectiveMemory` — Correctly Enforced

### Classification: **FALSE POSITIVE**

### Source locations
- `Core/CapacityEffective.lean:32-34` — structure with `movementNodup`
- `Persistence/CapacityEffectivePersistence.lean:59-63` — `decodeCapacityEffectiveMemory?` uses `ofEntries?`

### Verification

`ofEntries?` enforces `movementNodup`. The nodup proof is a Prop that cannot be falsified. Direct construction fails to compile.

### Confirmed containment

```text
decodeCapacityEffectiveMemory? -> ofEntries? -> enforces uniqueness
NODUP is Prop -> type system prevents invalid construction
```

---

## Finding 10: `RelationDischarge` — Discharge Self-Reference Check

### Classification: **T2** — Convention Gap

### Source locations
- `Core/OpenRelation.lean:93-97` — `RelationDischarge` definition
- `Application/RelationDischargeFrontier.lean:116-120` — `admitRelationDischargeForTarget?` checks `discharge.event = target.relation.sourceEvent`

### Gap

The `RelationDischarge` type itself does not prevent `discharge.event = target.relation.sourceEvent` (self-discharge). This check happens only in `admitRelationDischargeForTarget?`.

### Forged construction

```lean
def selfDischarge : RelationDischarge :=
  { event := ⟨"ev-1"⟩
    target := ⟨"rel-1"⟩
    quantity := Quantity.ofQuanta 50  -- but target relation's source is ev-1
  }
```

This compiles fine.

### Boundary trace

```text
selfDischarge
  -> ParsedTx.discharges
  -> ActualEvidence.discharges
  -> admitActualEvidence? (lines 115-130)
    -> evidence.relations.find? fun r => r.id = discharge.target
    -> finds relation
    -> admittedRelationDischargesFor? (line 127-128)
      -> admitRelationDischargeForTarget? (line 135)
        -> discharge.event = target.relation.sourceEvent
        -> REJECTED (line 120)
```

### Production reachability

**CANNOT REACH canonical persistence.** The `admitRelationDischargeForTarget?` function rejects self-discharges.

### False-positive risk

**LOW.** The canonical path validates against self-discharge.

---

## Finding 11: `RelationDischarge` — Aggregate Over-Discharge Check

### Classification: **T2** — Convention Gap

### Source locations
- `Core/OpenRelation.lean:93-97` — `RelationDischarge` definition
- `Application/RelationDischargeFrontier.lean:152-156` — `admittedForCurrentTarget?` checks `dischargeTotal admitted > target.relation.quantity.quanta`

### Gap

Individual `RelationDischarge` values can be valid in isolation, but their sum can exceed the target relation quantity. This check happens in `admittedForCurrentTarget?`, not in the type.

### Forged construction

```lean
def overDischarge : List RelationDischarge :=
  [ { event := ⟨"ev-1"⟩, target := ⟨"rel-1"⟩, quantity := Quantity.ofQuanta 30 }
  , { event := ⟨"ev-2"⟩, target := ⟨"rel-1"⟩, quantity := Quantity.ofQuanta 30 }  -- total 60 > target 50
  ]
```

### Boundary trace

```text
overDischarge
  -> ActualEvidence.discharges
  -> admitActualEvidence? (lines 115-130)
    -> evidence.relations.find? fun r => r.id = discharge.target
    -> finds relation with quantity 50
    -> admittedRelationDischargesFor? (line 127-128)
      -> admittedForCurrentTarget? (line 180)
        -> dischargeTotal admitted (60) > target.relation.quantity.quanta (50)
        -> REJECTED (line 153)
```

### Production reachability

**CANNOT REACH canonical persistence.** The aggregate over-discharge check rejects invalid discharges.

### False-positive risk

**LOW.** The canonical path validates aggregate discharge.

---

## Critical Path Analysis

### Path: Raw Input → Canonical Persistence

```text
User Input / Text File
  │
  ▼
decodeNormalizedActual? (Persistence/NormalizedActualPersistence.lean:281-343)
  │
  ├── Event.ofEffects? (per-event)
  ├── EventMemory.ofEvents? (identity uniqueness)
  ├── ActualValidityHistory.ofParts? (factRef uniqueness)
  ├── EventDescriptionMemory.ofEntries?
  ├── EventMerchantEvidenceMemory.ofEntries?
  ├── EventCorrectionMemory.ofCorrections?
  ├── ActualReversalMemory.ofReversals?
  │
  ├── relations : List RelationUnit (raw)
  ├── discharges : List RelationDischarge (raw)
  │
  └── admitActualEvidence? (54-130)
        │
        ├── 1. correctionFrontierMemory? (reference closure, acyclicity)
        ├── 2. admittedActualValidityMemory? (single current date)
        ├── 3. Event existence checks
        ├── 4. Merchant reference checks
        ├── 5. Reversal checks (target exists, exact inverse, no chain)
        ├── 6. Relation checks (existence, endpoints, quantity, frontier)
        ├── 7. Discharge checks (uniqueness, positivity, self-discharge, aggregate bound)
        │
        └── Returns Option ActualEvidence
              │
              ▼
        encodeNormalizedActual? (349-415)
          │
          ├── admitActualEvidence? (line 350) ← REVALIDATION
          └── Returns Option String (encoded text)
                │
                ▼
        ActualAuthority.publishActual? (ActualAuthority.lean:96-97)
          │
          ├── encodeNormalizedActual?
          ├── staged re-read
          ├── decodeNormalizedActual? (re-validation)
          └── atomic rename
                │
                ▼
        actual.loam (canonical persistence)
```

**Key observation**: `admitActualEvidence?` is called **twice** — once during decode (line 343), and once during encode (line 350). This is a fail-closed double validation.

---

## Summary Classification

### T1 — Raw Type Gap (Intentional)

| Finding | Type | Rationale |
|---------|------|-----------|
| 7 | Event anonymous Effect bypass | Confirmed design choice per Observation 106 |
| 9 | CapacityEffectiveMemory | Prop-based invariant, type system prevents invalid construction |

### T2 — Convention Gap (Canonical Paths Closed)

| Finding | Type | Bypass Path Closed By |
|---------|------|----------------------|
| 1 | AdmittedRelationUnit forgeable | Application-layer consumers perform own validation |
| 2 | ActualEvidence forgeable | admitActualEvidence? (double validation: decode + encode) |
| 3 | RelationUnit orphan reference | admitActualEvidence? source existence check (line 93) |
| 4 | RelationDischarge orphan target | admitActualEvidence? target existence check (line 127) |
| 6 | World contains raw types | admitActualEvidence? (encode path line 350) |
| 8 | LocusAdmissionVocabulary procedural | propose? function checks against approved list |
| 10 | RelationDischarge self-reference | admitRelationDischargeForTarget? (line 120) |
| 11 | RelationDischarge over-discharge | admittedForCurrentTarget? (line 153) |

### T3/T4 — Not Found

No confirmed production bypass to canonical persistence or user-visible output.

---

## Successful Semantic Containment Mechanisms

### 1. Double Validation (Decode + Encode)

```text
decodeNormalizedActual? → admitActualEvidence? → Returns Option ActualEvidence
encodeNormalizedActual? → admitActualEvidence? → Returns Option String
```

Every canonical path validates twice. Forged evidence is rejected at both points.

### 2. Prop-Based Invariants

Memory types use `Nodup` as a `Prop` field:
- `EventMemory.idNodup`
- `ActualValidityHistory.factRefNodup`
- `CapacityMemory.idNodup`
- `ScheduledMemory.idNodup`
- `CapacityEffectiveMemory.movementNodup`

Direct construction with duplicate keys **fails to compile**.

### 3. Admission Functions

- `admitRelationUnit?` — validates endpoints, positivity, source magnitude bound
- `admitRelationUnit?` — validates source Event/Effect existence
- `admitRelationUnit?` — validates relation frontier admission
- `admittedRelationDischargesFor?` — validates discharge existence, positivity, self-reference, aggregate bound
- `admitActualEvidence?` — 7 cross-cutting checks (corrections, validity, descriptions, merchants, reversals, relations, discharges)

### 4. Fail-Closed Persistence

`ActualAuthority.publishActual?`:
1. Encodes evidence to text
2. Stages text to `.loam-stage`
3. Re-reads and re-decodes staged text
4. Only then renames to `actual.loam`

If any step fails, the existing `actual.loam` is untouched.

---

## Final Assessment

### LOAM's Semantic Guarantee Architecture

| Layer | Mechanism | Examples |
|-------|-----------|----------|
| **Type System** | Prop fields enforce structural invariants | `EventMemory.idNodup`, `ActualValidityHistory.factRefNodup` |
| **Admission Functions** | Procedural validation of semantic properties | `admitRelationUnit?`, `admitActualEvidence?` |
| **Persistence Boundary** | Fail-closed decode/encode with double validation | `decodeNormalizedActual?`, `encodeNormalizedActual?` |
| **Authority** | Atomic publish with staged re-validation | `ActualAuthority.publishActual?` |
| **Application Layer** | Semantic projection with own validation | `currentRelationState?`, `admittedRelationDischargesFor?` |

### Raw → Admitted → Authority → Persistence Chain

```text
Raw Types (RelationUnit, RelationDischarge, LocusAdmissionVocabulary, ActualEvidence)
  │
  ▼
Admission Functions (admitRelationUnit?, admitActualEvidence?, relationFrontierAdmissible)
  │
  ▼
Admitted Types (AdmittedRelationUnit, AdmittedRelationDischarge) — but NO PROOF FIELDS
  │
  ▼
Application Projections (currentRelationState?, admittedRelationDischargesFor?)
  │  (perform own validation, reject forged admitted values)
  ▼
Persistence Boundary (decodeNormalizedActual? → admitActualEvidence? → encodeNormalizedActual? → admitActualEvidence?)
  │  (double validation, fail-closed)
  ▼
Authority (ActualAuthority.publishActual?)
  │  (staged publish with re-validation)
  ▼
Canonical Persistence (actual.loam)
```

### Key Finding

The **strongest containment** is at the **persistence boundary** (`decodeNormalizedActual?` and `encodeNormalizedActual?`), which performs double validation through `admitActualEvidence?`.

The **weakest link** is that `AdmittedRelationUnit` and `AdmittedRelationDischarge` have **no proof fields**. While the canonical paths go through admission functions, a forged `AdmittedRelationUnit` can be passed directly to Application functions that trust the admission.

However, those Application functions (`currentRelationState?`, `admittedRelationDischargesFor?`) perform their own validation, so even forged admitted values are caught.

### Verdict

**No confirmed production semantic gaps (T3/T4).**

All forged values are caught by:
1. Type system (Prop-based invariants)
2. Admission functions (procedural validation)
3. Double validation at persistence boundary
4. Atomic publish with staged re-validation

The raw/admitted distinction is **well-enforced at the persistence boundary**, even though the types themselves are permissive.
