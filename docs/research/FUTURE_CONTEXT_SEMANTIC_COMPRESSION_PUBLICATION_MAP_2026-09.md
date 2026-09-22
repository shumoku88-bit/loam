# Future-context semantic compression — publication map

Status: **RESEARCH SYNTHESIS / CANDIDATE CLAIM MAP**

Baseline:

    34da08dc72cc20484e0e20f8571fc633ee259f1b
    experiment: qualify future-context distinction outside accounting (#1155)

This note does not claim a new mathematical theorem and does not claim that LOAM has established a publication result. It records the strongest statement that the current proved observations appear to support, separates that statement from familiar mathematics, and identifies what still has to be shown before any paper claim is defensible.

## 1. Candidate research question

The strongest current question is not:

> Can accounting be represented by signed quantities?

Nor is it:

> Can immutable events be replayed after correction?

Both questions have substantial prior art.

The narrower LOAM question is:

> When may a retained evidence state be replaced by a smaller semantic summary without losing distinctions that become observable after allowed future operations?

The key pressure is that equality under current observations can be too coarse. A summary can answer every selected question correctly now and still be insufficient after the same admitted future operation is applied to two states that the summary collapsed.

## 2. Generic vocabulary

### Definition D1 — retained state

Let S be the state/evidence space.

In LOAM this need not mean only EventMemory. A state may contain retained Events together with correction or other semantic relations.

### Definition D2 — selected question vocabulary

Let Q be questions, A answers, and:

    answer : S -> Q -> A
    V      : Q -> Prop

where V selects the questions currently in scope.

This is the Observation-029 / Observation-191 boundary.

### Definition D3 — current observational equivalence

    x ~0 y
    iff
    for every q selected by V,
    answer x q = answer y q

This equivalence is relative to the selected question vocabulary. It is not identity of retained evidence.

### Definition D4 — allowed operation semantics

Let:

    step : S -> O -> S

be a deterministic transition for one allowed operation. A finite continuation is a list of operations.

No claim is made that all LOAM authorities, writers, routing rules, temporal relations, or human decisions form one global transition algebra.

### Definition D5 — future-context equivalence

    x ~F y
    iff
    for every finite continuation c
    and every selected q,
    answer (run step x c) q
      =
    answer (run step y c) q

This is exactly Observation192.FutureEquivalent.

### Definition D6 — current sufficient summary

For:

    encode : S -> M

a current summary is sufficient when selected current answers can be decoded from encode s alone.

Observation 029 already owns this shape.

### Definition D7 — future-sufficient summary

A summary is future-sufficient when one decoder can recover every selected answer after every finite allowed continuation from the summary alone.

This is exactly Observation192.FutureSufficient.

### Definition D8 — semantic result

The answer type may itself expose semantic availability, for example Option A or Except Refusal A.

Therefore definedness/refusal can be observable without inventing a second quotient theory. Observation 195 demonstrates the Option case.

## 3. Generic proved results already present

### T1 — observational equivalence is an equivalence relation

Observation 191 proves reflexivity, symmetry, and transitivity of indistinguishability induced by a selected observation family.

This is familiar quotient mathematics, not a novelty claim.

### T2 — closure equals quotient factorization for the all-endomap model

Observation 191 proves:

    target in Closure(A)
    iff
    target is constant on the equivalence classes induced by A

Equivalently, the target observation factors through the observational quotient.

Important limitation: the exact equivalence depends on the observation model quantifying over all retained-evidence endomaps. Production correction, routing, time, publication, and human policy are not thereby arbitrary endomaps.

### T3 — future-context equivalence refines current equivalence

Observation 192 proves:

    x ~F y  ->  x ~0 y

The converse does not hold in general.

### T4 — future-context equivalence is step-stable

Observation 192 proves that x ~F y implies step x o ~F step y o for the same next operation o.

This is the right-congruence pressure absent from plain current observational equivalence.

### T5 — greatest sound step-stable relation

Observation 192 proves that every relation that is both sound for the selected current observations and stable under every allowed next operation is contained in FutureEquivalent.

Thus FutureEquivalent is the greatest relation, by inclusion, satisfying those two obligations.

This is a Nerode-style / behavioural-equivalence result, not a claim of a new general theorem.

### T6 — future equivalence is ordinary observational equivalence over contexts

Observation 192 proves that future equivalence is ordinary observational equivalence after lifting the question space to:

    finite continuation x terminal question

Therefore the Observation-191 quotient/factorization machinery applies without a second quotient construction.

### T7 — future-sufficient summaries may collapse only future-equivalent states

Observation 192 proves:

    FutureSufficient encode
    and
    encode x = encode y
        ->
    x ~F y

This is the current strongest generic **necessary condition for safe semantic compression**.

Its contrapositive is the practical criterion:

    x not~F y
    and
    encode x = encode y
        ->
    encode is not future-sufficient

### T8 — exact semantic result determines availability, not conversely

Observation 195 proves that semantic availability factors through exact Option results, while availability alone is strictly coarser than exact successful result values.

So exact result determines availability, but not conversely.

## 4. Concrete LOAM witnesses

### W1 — synthetic future distinction

Observation 192 contains the minimal synthetic witness: same visible value now, different retained hidden value, same future reveal operation, different later visible value.

This establishes strictness of current versus future-context equivalence without accounting semantics. Its weakness is that reveal is deliberately synthetic.

### W2 — production Correction semantics

Observation 193 replaces the synthetic operation with existing LOAM semantics: EventMemory, EventCorrectionMemory, EventCorrectionMemory.add?, and CorrectionFrontier quantity observation.

Two states have the same current quantity answer but diverge after the same future Correction.

It proves that a current-quantity-only summary is not future-sufficient once Correction publication is in the allowed operation vocabulary.

### W3 — future definedness, not only future value

Observation 194 strengthens the result.

The two worlds have identical EventMemory, the same current CorrectionFrontier answer some 10, and different retained Correction topology.

After the same future Correction:

    left  -> none
    right -> some 0

The distinction is therefore not merely a different quantity. One world loses semantic admissibility because the retained relation topology becomes cyclic.

This establishes, for the selected Correction vocabulary:

    same retained Event evidence
    + same current selected answer
        does not imply
    same future semantic availability

### W4 — non-accounting scalar scientific witness

PR #1155 adds Loam/Examples/ScientificFutureContext.lean.

The example deliberately removes Account and AccountingRole, debit/credit vocabulary, transfer and source/destination movement, and balancedness/conservation laws.

Each Event contains one positive scalar observation.

The two worlds retain identical Event evidence and both currently answer some 17. They differ only in Correction topology. The same future Correction produces:

    left  -> none
    right -> some 9

Lean proves both not FutureEquivalent left right and that the current-scalar-only summary is not FutureSufficient.

This is evidence that the selected future-context phenomenon is not caused by double-entry, balancing, transfer, or household accounting vocabulary.

Important limitation: this witness changes domain but still reuses LOAM's Correction relation and CorrectionFrontier semantics. PR #1157 supplies a separate document-provenance operation family that removes that remaining dependency.

### W5 — independent document-provenance transition family

PR #1157 adds Loam/Examples/DocumentProvenanceFutureContext.lean.

This witness starts from the independently earned boundary in PR #1150 that
derived-from and EventCorrection have different meanings. It uses:

    quantity-free retained document Events
    + example-local DocumentDerivation edges
    + publication of one derived-from edge
    + an exactly-two-step provenance question

There is no AccountingRole, Quantity, BalancedMovement, EventCorrection, or
CorrectionFrontier.

Two states retain identical documents and answer the selected current provenance
question equally. They differ only in one retained derivation edge. Publishing
the same future B -> D derivation then yields:

    left:  A -> B -> D   => true
    right: C -> B -> D   => false

Lean proves that the two states are not FutureEquivalent and that a summary
retaining only the current selected provenance answer is not FutureSufficient.

This satisfies the current Gate B requirement for an independently earned
non-Correction transition family. It remains a bounded example-local provenance
semantics, not a claim that two-step reachability is the correct general
provenance model.

## 5. Nearby structures that should not be confused with the central claim

### BalancedMovement / free-Abelian projection

Observation 159 shows that additive coordinate observations admit a free-Abelian-style quotient, and BalancedMovement occupies a zero-augmentation boundary.

This is useful mathematical infrastructure, but it is not the strongest publication claim. The underlying algebra is familiar, and LOAM itself retains presentation-rich evidence rather than replacing canonical evidence with the additive quotient.

### Accounting projection factorization

Observation 242 uses Alloy to distinguish RoleFlow from RoleBalance + support and to show, in the bounded selected model, that familiar accounting views can be derived from these coordinate-preserving families.

This is relevant domain evidence, but its positive sufficiency results are bounded Alloy results, not yet generic Lean theorems.

### Ledger denotation

Observations 250-253 connect selected LOAM movement projections to a Ledger/Pacioli-shaped boundary and prove a compatible mediated projection commutes.

This demonstrates recoverability of an accounting interpretation without making accounting role intrinsic to Core evidence.

It should not be presented as a replacement for, or novelty over, the existing Lean formalization in ledger/ledger-semantics.

### Non-household Core probes

PR #1150 shows that low-level Event/Locus/Measure vocabulary can represent physical inventory movement, an unbalanced scalar scientific observation, and quantity-free document identities/descriptions.

The document-provenance probe also identifies a genuine boundary: derived-from cannot safely be substituted with EventCorrection because derivation and supersession have different meanings.

That negative boundary is evidence against claiming that the current Core is a universal ontology.

## 6. Candidate paper-level claim

The strongest statement currently supported is deliberately narrower than a novel-mathematics claim:

> In a retained-evidence system with selected observations and allowed future operations, current observational equivalence is not in general a sound basis for destructive semantic compression. Any summary that claims to preserve all selected future-context answers must collapse only states that are future-context equivalent. In LOAM, existing Lean proofs instantiate this criterion with correction-aware, fail-closed semantics, and concrete witnesses show the insufficiency of current-value summaries in both household accounting and a non-accounting scalar-observation domain.

The generic mathematical part is familiar in shape. The potentially publishable contribution, if literature review supports it, is the **combination and field-tested use** of retained evidence, observation-relative quotient, allowed future operations, fail-closed semantic definedness, and machine-checked compression counterexamples as a design criterion for deciding what evidence a long-lived information system may safely discard.

## 7. What must NOT be claimed

Current evidence does not establish that:

1. FutureEquivalent is a new mathematical construction;
2. LOAM has a globally minimal canonical state;
3. full history must always be retained;
4. every LOAM operation belongs to one deterministic transition system;
5. Correction is representative of every future semantic relation;
6. the scientific example establishes domain-independent universality;
7. Option is the final semantic-result vocabulary;
8. bounded RoleFlow / RoleBalance findings are universal accounting theorems;
9. LOAM supersedes existing accounting, provenance, event-sourcing, automata, or coalgebraic semantics.

## 8. External comparison boundary

Any publication draft should explicitly compare against at least the following.

### Myhill-Nerode / right congruence

The all-future-context shape is intentionally Nerode-like. LOAM should claim an application boundary, not invention of future-context indistinguishability.

### Coalgebraic behavioural equivalence

Behavioural equivalence and bisimulation provide a broader state-based comparison vocabulary. A literature pass is required before claiming that LOAM's retained-evidence / question-vocabulary formulation supplies a distinct technical contribution.

### Event sourcing / retroactive events

Event sourcing already retains event history for replay, temporal queries, and retroactive correction. The LOAM question is narrower: whether a proposed summary is sufficient for a declared future operation/question vocabulary.

Reference target: Martin Fowler, Event Sourcing and Retroactive Event, 2005.

### Database provenance

Provenance semirings and related provenance work study how query answers depend on retained input evidence. LOAM must distinguish its transition-sensitive future-context question from ordinary query provenance rather than merely renaming provenance.

Reference target: Todd J. Green, Gregory Karvounarakis, Val Tannen, Provenance Semirings, PODS 2007.

### Formal accounting semantics

ledger/ledger-semantics already gives a substantial Lean 4 denotational semantics for double-entry Ledger and an executable oracle. A LOAM publication should not compete on formalized double entry in Lean; its stronger candidate is the evidence-retention / future-context boundary around interpretation and correction.

## 9. Evidence map

    Observation029
      current vocabulary-relative sufficiency
            |
            v
    Observation191
      observational quotient
      closure <-> factorization
            |
            v
    Observation192
      future contexts
      step stability
      greatest sound stable relation
      FutureSufficient necessary condition
            |
            +------------------+
            |                  |
            v                  v
    Observation193        Observation194
    real Correction       future definedness
    value distinction     none vs some
            |                  |
            +---------+--------+
                      |
                      v
    Observation195
    semantic result / availability order
                      |
                      v
    PR #1155
    non-accounting scalar witness
    same phenomenon without accounting,
    movement, or balance semantics

Accounting and interpretation evidence remains adjacent rather than foundational:

    Observation159       additive quotient boundary
    Observation242       RoleFlow / RoleBalance bounded factorization
    Observation250       LOAM -> Ledger-shaped denotation
    Observation253       compatible mediated view commutes
    PR #1150             non-household Core limits and reuse

## 10. Next research gates

### Gate A — literature comparison

Before drafting a paper, determine whether an existing framework already states the exact retained-summary criterion in essentially the same information-system setting.

The important search is not for the words event sourcing or bisimulation alone. It is for work combining persistent evidence, selectable observation vocabulary, future update operations, safe state/history compression, and partial/fail-closed observations.

### Gate B — independent transition domain

Status: **SATISFIED BY PR #1157 for the current research threshold.**

PR #1157 uses the independently earned DocumentDerivation boundary from PR #1150
and an operation family that publishes derivation evidence rather than
Correction/supersession evidence.

This does not prove universality. It does remove the narrower concern that every
future-context witness depended on Correction topology. A later third domain
should be added only if literature comparison or a real product/research pressure
shows that another transition shape would distinguish competing explanations.

### Gate C — one reusable cross-domain theorem

Do not add a new generic framework merely to rename FutureSufficient.

A new theorem or abstraction is earned only if a second real domain needs the same proof pattern and the current Observation-192 vocabulary causes duplicated proof obligations.

### Gate D — accounting theorem strength

If accounting remains a major case study, identify which Observation-242 positive bounded results deserve promotion from Alloy exploration to unbounded Lean statements.

### Gate E — executable correspondence

For any paper claim that refers to production LOAM rather than only observation models, record exactly which production types/functions instantiate the generic definitions and which correspondence theorems make that connection explicit.

## 11. Current stop condition

Do not rewrite Core around automata, coalgebras, quotient types, free Abelian groups, or a publication-specific generic framework.

The current result is stronger when presented as an observed design law with explicit boundaries:

    current equality is cheap
    future-context equality is stronger
    compression must preserve the distinctions the future vocabulary can expose
    retained evidence may therefore be richer than today's answers

The next work should prioritize literature comparison and executable correspondence. The independently earned non-Correction transition gate is now met by PR #1157; additional domains should be added only when they answer a specific unresolved question.