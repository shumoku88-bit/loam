# Observation 251 — LOAM to REA interpretation boundary

Status: **QUALIFIED by Alloy 6.2.0 / Sat4j**

LOAM baseline:

```text
shumoku88-bit/loam
main: 4eb77b6e7f47c9198261f07f4af0c525dcedcd83
Observation 250 / PR #919 merged
```

Exact pre-qualification branch head:

```text
52f32c2d9e4df08ff556b136481a96f59293451c
```

GitHub Actions qualification:

```text
workflow: Observation 251
run:      34982479969
job:      104426031177
result:   SUCCESS
solver:   Alloy 6.2.0 / Sat4j
```

Observed matrix:

```text
reaInterpretationExists                           SAT
sameLoamEvidenceDifferentAgent                   SAT
sameLoamEvidenceDifferentResource                SAT
sameLoamEvidenceDifferentDuality                 SAT
LoamEvidenceDeterminesREAInterpretation          SAT counterexample
LoamPlusResourceDeterminesAgent                  SAT counterexample
LoamPlusResourceAndAgentDeterminesDuality        SAT counterexample
FullExplicitOverlayDeterminesSelectedQueries     UNSAT counterexample
```

## External semantic reference

REA is used here in its standard Resource–Event–Agent sense: a semantic schema for event-level economic reality rather than a ledger-account capture model. The American Accounting Association describes REA as a semantic schema for elementary business transactions and notes that debit/credit/account judgements can be deferred to derived views. The 2022 AAA monograph summary likewise describes REA as an accounting and economic ontology that questions pervasive ledger-account structures.

This observation does **not** formalize the complete REA ontology or ISO/IEC 15944-4. It selects only three REA-shaped distinctions needed for a derivability test:

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

Observation 251 probes the other edge:

```text
LOAM retained evidence
    -> ?
REA economic interpretation
```

The result is that a useful REA interpretation can exist, but the selected interpretation is **not forced** by current neutral LOAM evidence.

## Fixed LOAM evidence

The Alloy model keeps one neutral LOAM-shaped event/effect presentation fixed across all candidate worlds:

```text
Payment
  CashLocus   JPY  -100
  GoodsLocus  JPY  +100
```

The identities intentionally carry no built-in Resource meaning, Agent or ownership meaning, buyer/seller role, exchange or duality relation, debit/credit meaning, or Account meaning.

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

## Qualified boundaries

### O251-1 — Agent participation is not derivable

`sameLoamEvidenceDifferentAgent` is SAT while Resource interpretation and duality are held fixed.

Therefore current neutral Event/Effect/Locus/Measure/Quantity evidence does not determine the selected participating Agent set.

### O251-2 — Resource interpretation is not derivable

`sameLoamEvidenceDifferentResource` is SAT while Agent participation and duality are held fixed.

Therefore a `LocusId` does not intrinsically determine REA Resource identity.

### O251-3 — Event duality is not derivable

`sameLoamEvidenceDifferentDuality` is SAT while Resource and Agent interpretation are held fixed.

Therefore current Event/effect evidence does not by itself determine which economic event is the selected reciprocal side of an exchange.

### O251-4 — the three selected planes are staged independent evidence

All three deliberately too-strong derivability assertions have counterexamples:

```text
LoamEvidenceDeterminesREAInterpretation          SAT counterexample
LoamPlusResourceDeterminesAgent                  SAT counterexample
LoamPlusResourceAndAgentDeterminesDuality        SAT counterexample
```

So the bounded result is:

```text
neutral LOAM evidence
    -/-> unique Resource interpretation
    -/-> unique Agent participation
    -/-> unique Event duality

LOAM + Resource interpretation
    -/-> Agent participation

LOAM + Resource + Agent interpretation
    -/-> Event duality
```

### O251-5 — explicit overlay is sufficient for the selected queries

`FullExplicitOverlayDeterminesSelectedQueries` has no counterexample in the exact bounded scope.

That is the positive control: once the selected Resource, Agent, and duality relations themselves are explicit, the corresponding selected queries agree.

## Finding

The qualified connection is not:

```text
LOAM retained evidence alone
    -> unique REA world
```

It is:

```text
LOAM retained evidence
+ independent economic interpretation evidence
    -> REA view
```

A SAT collision therefore does **not** mean LOAM is incompatible with REA. It identifies the information boundary of the connection.

## Connection triangle after Observation 251

```text
                    LOAM retained evidence
                    /                  \
                   /                    \
   + interpretation evidence            \ additive denotation
                 /                        \
                v                          v
              REA                   Ledger/Pacioli balance
```

Observation 250 qualified the right edge. Observation 251 now qualifies the left edge as interpretation-dependent rather than uniquely derivable.

The next research question is whether, for the overlap where an REA interpretation is supplied, an REA-mediated accounting projection and the direct Observation-250 Ledger projection commute.

## What is deliberately not claimed

Observation 251 does not establish or reject complete REA conformance; commitments, contracts, policies, value chains, workflows, complete stock-flow or participation cardinality laws, external/internal Agent taxonomy, ownership or custody semantics, or production Resource/Agent persistence.

It also does not claim that every LOAM Event should have an REA interpretation and does not yet prove an REA-to-Ledger commuting theorem.

## Stop condition

Do not add `Resource`, `Agent`, `EconomicEvent`, `Duality`, exchange, buyer/seller, or ownership vocabulary to production LOAM merely because this observation finds them non-derivable.

A production distinction is earned only when a real household or interoperability question requires retaining it rather than supplying it as query-time interpretation.
