# Observation 251 — LOAM to REA interpretation boundary

Status: **EXPERIMENT — Alloy qualification pending**

LOAM baseline:

```text
shumoku88-bit/loam
main: 4eb77b6e7f47c9198261f07f4af0c525dcedcd83
Observation 250 / PR #919 merged
```

## External semantic reference

REA is used here in its standard Resource–Event–Agent sense: a semantic schema for event-level economic reality rather than a ledger-account capture model. The American Accounting Association describes REA as a semantic schema for elementary business transactions and notes that debit/credit/account judgements can be deferred to derived views. The 2022 AAA monograph summary likewise describes REA as an accounting and economic ontology that questions pervasive ledger-account structures.

This observation does **not** claim to formalize the complete REA ontology or ISO/IEC 15944-4. It selects only three REA-shaped distinctions needed for a derivability test:

```text
Resource interpretation
Agent participation
Event duality
```

## Question

Does current neutral LOAM evidence uniquely determine those selected REA distinctions?

Observation 250 established the first connection edge:

```text
LOAM BalancedMovement
    -> Ledger/Pacioli-shaped additive balance observation
```

without adding Account, Commodity, debit/credit, or transaction-kind vocabulary to LOAM Core.

Observation 251 now probes the other edge:

```text
LOAM retained evidence
    -> ?
REA economic interpretation
```

The intended test is not whether a useful REA projection can exist. It is whether that projection is **forced** by current LOAM evidence or requires additional independent interpretation evidence.

## Fixed LOAM evidence

The Alloy model keeps one neutral LOAM-shaped event/effect presentation fixed across all candidate worlds:

```text
Payment
  CashLocus   JPY  -100
  GoodsLocus  JPY  +100
```

The identities intentionally carry no built-in:

- Resource meaning;
- Agent or ownership meaning;
- buyer/seller role;
- exchange or duality relation;
- debit/credit meaning;
- Account meaning.

This mirrors current LOAM boundaries: Event identity does not encode event kind or accounting role; Locus identity does not encode Account, ownership, custody, or accounting role semantics; Measure identity does not intrinsically mean currency or commodity.

## REA shadow overlay

The bounded model adds three interpretation relations over that unchanged evidence:

```text
resourceOf  : Locus -> lone Resource
participant : Event -> set Agent
duality     : Event -> lone Event
```

These are observation-local *shadow* relations, not proposed production Core nouns.

The candidate well-formedness condition is deliberately small:

- every observed Locus has one Resource interpretation;
- `Payment` has at least one participating Agent;
- `Payment` has exactly one distinct selected duality partner.

This is enough to ask distinguishability questions without pretending to reproduce the complete REA exchange ontology.

## Refutation matrix

The model asks for three concrete collisions.

### O251-1 — same LOAM evidence, different Agent

Hold Resource interpretation and duality fixed while changing only `Payment` Agent participation.

Expected:

```text
sameLoamEvidenceDifferentAgent = SAT
```

If SAT, Agent participation is not derivable from current neutral Event/Effect/Locus/Measure/Quantity evidence.

### O251-2 — same LOAM evidence, different Resource

Hold Agent participation and duality fixed while assigning a different REA Resource to `CashLocus`.

Expected:

```text
sameLoamEvidenceDifferentResource = SAT
```

If SAT, a `LocusId` does not intrinsically determine REA Resource identity.

### O251-3 — same LOAM evidence, different duality

Hold Resource and Agent interpretation fixed while changing the selected reciprocal economic event for `Payment`.

Expected:

```text
sameLoamEvidenceDifferentDuality = SAT
```

If SAT, Event/effect evidence does not by itself determine exchange duality.

## Deliberately too-strong claims

The model then checks increasingly strong derivability claims.

```text
LoamEvidenceDeterminesREAInterpretation
LoamPlusResourceDeterminesAgent
LoamPlusResourceAndAgentDeterminesDuality
```

All three are expected to have SAT counterexamples.

That would establish a staged boundary:

```text
neutral LOAM evidence
    -/-> Resource interpretation
    -/-> Agent participation
    -/-> Event duality

LOAM + Resource interpretation
    -/-> Agent participation

LOAM + Resource + Agent interpretation
    -/-> Event duality
```

The final positive control is:

```text
FullExplicitOverlayDeterminesSelectedQueries
```

Expected result: **UNSAT counterexample**. Once the selected interpretation relations themselves are explicit, the selected REA queries must agree.

## Why a SAT result would be useful

A counterexample does not mean LOAM is incompatible with REA.

It means the connection has the shape:

```text
LOAM retained evidence
+ independent economic interpretation evidence
    -> REA view
```

rather than:

```text
LOAM retained evidence alone
    -> unique REA world
```

That distinction is important for the proposed connection triangle. It would make REA a semantic interpretation/projection over LOAM evidence where needed, while Observation 250 already shows that one additive Ledger balance view can be obtained without first imposing those REA distinctions.

## Connection triangle after qualification

If the expected matrix is qualified, the current picture becomes:

```text
                    LOAM retained evidence
                    /                  \
                   /                    \
   + interpretation evidence            \ additive denotation
                 /                        \
                v                          v
              REA                   Ledger/Pacioli balance
```

The next question would then be whether an REA-mediated accounting projection and the direct Observation-250 Ledger projection commute for the overlap where both are defined.

## What is deliberately not claimed

Observation 251 does not establish or reject:

- complete REA conformance;
- REA commitments, contracts, policies, value chains, or workflows;
- complete stock-flow or participation cardinality laws;
- external versus internal Agent taxonomy;
- ownership or custody semantics;
- production Resource or Agent persistence;
- any change to LOAM Core;
- any claim that every LOAM Event should have an REA interpretation;
- the later REA-to-Ledger commuting theorem.

## Stop condition

Do not add `Resource`, `Agent`, `EconomicEvent`, `Duality`, exchange, buyer/seller, or ownership vocabulary to production LOAM merely because this observation finds them non-derivable.

A production distinction is earned only when a real household or interoperability question requires retaining it rather than supplying it as query-time interpretation.
