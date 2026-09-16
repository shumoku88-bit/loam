# CSA-007: Cross-CSA vocabulary compression audit

Status: **CLOSED CANDIDATE**

Baseline main: `754693e8e3f111efed0c19b41ab30ae8418eb7e4`

Scope: synthesize CSA-001 through CSA-006 and re-audit LOAM's internal generic-looking concepts after their machine-checked correspondence with standard computer-science vocabulary.

## Governing question

The question is not:

> Which LOAM modules can be replaced by CSLib?

It is:

> Which distinctions are generic mathematics that LOAM no longer needs to explain as inventions of its own, and which retained distinctions still belong to LOAM's executable or household semantics?

The governing rule remains:

> CSLib correspondence should be a theorem, not an architecture.

A successful correspondence may compress explanation without deleting a production type, function, or module.

## Executive verdict

**No current production generic layer is justified for deletion merely because a standard correspondence was found.**

CSA-001 through CSA-006 instead separate four standard semantic coordinates from the stronger policies or evidence retained by LOAM:

| LOAM boundary | Standard coordinate | Correspondence result | Retained LOAM reason | Verdict |
| --- | --- | --- | --- | --- |
| `ReplacementFrontier.acyclic` | finite right-unique relation / `Relation.TransGen` acyclicity | exact under source determinism + finite domain coverage | executable bounded checker; closed endpoints; one-to-one replacement policy; frontier projection | **KEEP REPRESENTATION, USE STANDARD MEANING** |
| `MovementAdmission.admit?` | deterministic partial labelled transition system | success is a transition, refusal is absence of transition, fixed label traces are deterministic | household world, Locus policy, identity allocation, relation/discharge admission, canonicalization | **KEEP DOMAIN BOUNDARY, USE LTS VOCABULARY** |
| `firstUnusedNumberedToken` | `HasFresh`-style finite-set freshness | returned token is outside the original finite namespace | deterministic first `stem ++ Nat` policy and caller-owned namespace choice | **KEEP POLICY, USE FRESHNESS CONTRACT** |
| `BalancedMovement.changes` | finite-support integer function (`FinFun`-shaped denotation) | `VectorEquivalent` iff extensional denotation equality | retained presentation/evidence, `MeasureId`, `Quantity`, caller coordinate type | **KEEP EVIDENCE, USE FINITE-VECTOR MEANING** |
| `movementTotalQuanta` | augmentation from finite integer vector to `Int` | vector equality preserves total; append maps to addition; equal total does not recover vector | practical exact total and retained balance proof | **KEEP OBSERVER, USE AUGMENTATION MEANING** |

The important compression is therefore conceptual:

```text
LOAM representation / executable policy
                |
                | correspondence theorem
                v
       standard semantic coordinate
```

not:

```text
LOAM module -> replace with library type
```

## CSA-001 / CSA-002: ReplacementFrontier

CSA-001 established the false-friend boundary. On an arbitrary edge list, the executable `acyclic` checker is not the same thing as acyclicity of the represented binary relation, because duplicate sources can hide an edge from the first-successor lookup. Production admission already rejects that malformed shape.

CSA-002 then proved the stronger and more useful statement: for a finite right-unique relation, with a finite source list covering the partial function domain, the bounded whole-domain start-return detector agrees with standard transitive-closure acyclicity. **Successor injectivity is not required for this correspondence.**

This removes one explanatory burden from LOAM:

- cycle refusal is ordinary relation acyclicity once the edge list represents a partial function;
- successor uniqueness remains an independent LOAM replacement policy, not a mathematical premise needed to justify cycle detection.

### Production consequence

`endpointUnique` should remain unchanged. Its successor-Nodup half expresses the intended one-to-one supersession shape and refuses merges.

The production rationale was updated by CSA-007 because it still said successor injectivity was needed by the cycle-detector argument. That premise was historical residue from Observation 218's narrower path-local algorithm comparison.

No executable code changes.

## CSA-003: MovementAdmission

CSA-003 showed that the existing pure boundary

```text
World -> Draft -> Except String Admitted
```

already has the standard shape of a deterministic partial labelled transition system when successful admission is interpreted as

```text
World --Draft--> World
```

and refusal is interpreted as **no transition**.

The useful generic facts are standard:

- one-step determinism;
- fixed-label finite-trace determinism;
- one-step invariants compose to finite traces.

The retained meaning is not generic:

- `World` is deliberately a bundle of independently meaningful household evidence and current Locus admission policy;
- `Draft` carries Movement-specific Effects, date, description, relations, discharges, and total;
- `admit?` owns current identity allocation and relation/discharge admission;
- raw drafts may differ while canonicalizing to the same semantic draft.

Therefore CSA-003 explicitly did **not** earn:

- a monolithic household state machine;
- a synthetic refusal/error state;
- a canonical-label quotient type;
- a generic transition framework in production.

The later `MovementDraftReview.check` boundary strengthens this conclusion rather than changing it. It asks the read-only question "does a transition currently exist for this draft?" and discards the hypothetical target. That is a domain-facing use of the existing admission relation, not evidence for another generic state-machine layer.

## CSA-004: FreshNumberedToken

CSA-004 proved directly for the current total production allocator:

```text
firstUnusedNumberedToken stem used index not-in used
```

This is the essential finite-namespace law described by `HasFresh`-style vocabulary.

LOAM retains a stronger implementation policy:

- candidate shape is `stem ++ Nat`;
- enumeration begins at a caller-selected index;
- the first available candidate is selected deterministically.

Those properties are operationally useful for readable practical identities and reproducible behavior. Replacing the function with an arbitrary generic `fresh` operation would **weaken** the contract rather than compress it.

Current callers also retain namespace policy locally. Movement, ActualValidity, Attention, Correction, Scheduled, and Capacity each decide which existing tokens collide; the helper does not become a global identity authority.

Verdict: the custom *proof story* can be described as freshness, but the custom deterministic allocator stays.

## CSA-005 / CSA-006: BalancedMovement

CSA-005 proved that every finite `List (MovementChange Coordinate)` has a finite-support integer-function denotation. Observation 159's `VectorEquivalent` is exactly extensional equality of that denotation, and `BalancedMovement.quantityAt` factors through it.

The retained list remains meaningful evidence. Distinct list shapes can denote the same vector, and production code may still observe presentation order, individual changes, or source evidence.

CSA-006 then proved that `movementTotalQuanta` factors through this vector meaning:

```text
same finite vector -> same movementTotalQuanta
```

and that concatenation is additive:

```text
movementTotalQuanta (left ++ right)
  = movementTotalQuanta left + movementTotalQuanta right
```

Observation 163 supplies the strictness counterexample:

```text
same total -/-> same finite vector
```

Thus the clean semantic stack is:

```text
retained MovementChange list
        |
        | denotation
        v
finite-support integer vector
        |
        | augmentation
        v
       Int
        |
        | = 0
        v
balanced boundary
```

This earns the compact reading:

> List is evidence. Finite vector is meaning. Total is an observation of that meaning.

It does **not** earn replacing `BalancedMovement` with a `FinFun` carrier. The production value still owns `MeasureId`, LOAM `Quantity`, caller-chosen coordinate meaning, retained change evidence, and a proof that the admitted presentation is balanced.

## Existing generic-looking seeds after CSA-007

### `Core/FiniteKeyed.lean` - KEEP INTERNAL

`FiniteKeyed` has no useful direct CSLib replacement identified by CSA-001 through CSA-006.

Its contract is already narrow:

- caller supplies the key projection;
- caller supplies unique-key evidence;
- helper owns lookup mechanics;
- helper proves lookup is invariant under permutation;
- helper assigns no chronology, authority, priority, or winner semantics.

It is shared across multiple semantic memory families. Replacing those unique-key list representations with a generic finite-function carrier would change representation and proof obligations without removing household meaning.

Verdict: **already compressed at the correct internal level**.

### `Persistence/VersionedRows.lean` - KEEP UTILITY

This owns only exact outer line framing:

```text
version header + encoded rows + required trailing newline
```

It does not own typed row grammar, schema, semantic admission, migration, or authority meaning.

No standard semantic correspondence found in CSA-001 through CSA-006 changes this boundary.

Verdict: **small physical utility, not a semantic abstraction problem**.

### `Persistence/SiblingStage.lean` - KEEP UTILITY

This owns only:

```text
write sibling stage -> rename over target
```

and explicitly refuses to claim transaction, lock, recovery, or durability semantics.

Verdict: **small physical utility, not a generic transaction framework seed**.

### `Core/HistoricalRouting.lean` - KEEP LOAM-LOCAL

Historical routing contains generic ingredients such as an ordered time coordinate, finite evidence, and permutation-independent latest-visible selection. Its public result, however, is specifically LOAM's three-way household distinction:

```text
managed PurposeId / explicitly unmanaged / unrouted
```

The distinction between `unmanaged` and `unrouted` is semantic evidence, not generic ordered-map machinery.

Extracting a generic temporal-map framework would currently move code while weakening ownership clarity.

Verdict: **DOMAIN-SPECIFIC**.

### `Sha256.lean` - WATCH ONLY

SHA-256 is generic by subject matter, but genericity alone is not an extraction criterion. It remains an internal implementation with a narrow current production use.

Verdict: **KEEP / extraction gate not earned by CSA work**.

## What actually disappeared in this audit

No production type or function disappeared. Several independent *explanations* did:

1. LOAM no longer needs a bespoke mathematical story for replacement acyclicity. It is standard relation acyclicity under the representation premise.
2. LOAM no longer needs to invent a generic transition-composition vocabulary for Movement admission. LTS vocabulary already names it.
3. LOAM no longer needs to treat finite-namespace freshness as a mysterious property of numbered identity allocation. It is a standard freshness contract plus a stronger deterministic policy.
4. LOAM no longer needs to describe `BalancedMovement` list equivalence and total as unrelated ad-hoc operations. They are finite-vector denotation followed by augmentation.

This is semantic compression even though LOC is almost unchanged.

## What must not disappear

The following distinctions remain independently meaningful and should not be erased merely because their mechanics have standard names:

- successor uniqueness / no-merge replacement policy;
- closed represented replacement endpoints;
- domain-specific frontier adapters;
- Movement current-world and Locus-policy admission;
- Movement identity namespace policy;
- raw retained Movement change evidence;
- explicit Measure and Quantity meaning;
- managed / unmanaged / unrouted historical routing;
- fail-closed persistence framing and caller-specific stronger staging protocols.

## Dependency verdict

CSA-001 through CSA-006 do **not** justify adding CSLib or Mathlib to LOAM production.

The correspondence work repeatedly needed only a small semantic coordinate while production retained stronger executable or domain-specific behavior. A dependency becomes worth reconsidering only if LOAM begins repeatedly reimplementing substantial generic theorem composition in live production proofs, rather than merely proving occasional correspondence at an audit boundary.

Current verdict:

```text
CSLib = external semantic coordinate system
not    production architecture dependency
```

## Compression DAG

```text
ReplacementFrontier edge list
  -> right-unique partial relation
  -> standard acyclicity
  -> executable bounded decision
  + LOAM no-merge / closure / frontier policy

MovementAdmission Draft + World
  -> partial deterministic labelled transition
  -> generic trace composition
  + LOAM admission / identity / policy semantics

finite used token list
  -> freshness obligation
  -> deterministic first numbered token
  + caller-owned identity namespace

MovementChange list
  -> finite-support integer vector
  -> augmentation Int
  -> zero fibre / balanced boundary
  + retained evidence / Measure / Quantity
```

The repeated architecture is now clear:

```text
standard meaning
      ^
      | theorem
      |
LOAM executable/domain representation
```

This is the preferred direction. The reverse direction, forcing production into a standard library carrier merely because a correspondence exists, remains unearned.

## Final decision table

| Boundary | Delete | Replace with CSLib | Extract now | Keep | Action from CSA-007 |
| --- | ---: | ---: | ---: | ---: | --- |
| ReplacementFrontier | no | no | no | yes | correct stale injectivity rationale |
| MovementAdmission | no | no | no | yes | vocabulary only |
| FreshNumberedToken | no | no | no | yes | vocabulary only |
| BalancedMovement | no | no | no | yes | vocabulary only |
| FiniteKeyed | no | no | no | yes | stop |
| HistoricalRouting | no | no | no | yes | stop |
| VersionedRows | no | no | no | yes | stop |
| SiblingStage | no | no | no | yes | stop |
| Sha256 | no | no | not yet | yes | watch |

## Closure

CSA-007 finds **no hidden generic framework that should now be deleted from production**.

The cross-audit instead validates a stronger compression rule:

> Use standard computer-science vocabulary to remove unnecessary explanatory concepts; keep LOAM representations only where they still own executable policy, retained evidence, or household semantics.

The one concrete correction is the `ReplacementFrontier` rationale: successor injectivity remains a replacement-domain policy but is no longer claimed as a premise required for standard acyclicity correspondence.
