# LOAM Structural Falsification Atlas

Status: **catalogue-first meta-falsification program**
Seed date: 2026-09-06
Baseline main when seeded: `7c3e8d5087a50f43ec2c523744c592eb5a791da6`

Current Work / Finding state after the completed cross-reference is owned by `LOAM_STRUCTURAL_FALSIFICATION_PROGRESS.md`.
The state columns and initial recommendation in this file are seed metadata only.

This document complements the domain-facing `LOAM_FALSIFICATION_ATLAS.md` and `LOAM_FALSIFICATION_ATLAS_WAVE2.md`.

The F001-F200 corpus asks whether externally real or structurally plausible worlds require distinctions that LOAM's current canonical evidence cannot represent.

This atlas attacks a different surface:

> Can LOAM's own claims about minimality, representation independence, composition, formal qualification, and crash-safe authority be falsified even when no new accounting product case is introduced?

It is intentionally a sibling corpus rather than F201-F212. The `S` namespace keeps structural/meta pressure separate from the current F001-F200 progress authority and counts.

No entry is a feature request. No entry earns a production primitive merely by existing.

## Why a separate structural corpus exists

The ordinary falsification criterion is:

```text
same current canonical evidence
but
one legitimate household/accounting query must return different answers
```

That criterion is strong for detecting **missing information**.

It is not, by itself, sufficient to test all of the following:

```text
retained information may still be redundant
representation details may leak into answers
individually qualified seams may fail when composed
pairwise-safe interactions may fail in larger combinations
bounded formal checks may be vacuous or scope-sensitive
a formal abstraction and production implementation may diverge
separately crash-safe writers may compose into an unsafe partial world
```

The structural corpus exists to attack those claims directly.

## Structural falsification modes

### Minimality

Try to delete, merge, quotient, or reconstruct a retained distinction while holding the selected legitimate query set fixed.

A primitive or distinction has not earned structural necessity merely because it currently exists in Core.

### Invariance

Construct two representations intended to denote the same household world and ask whether selected legitimate queries remain equal.

If answers differ only because of encoding shape, ordering, naming, or harmless decomposition, representation has leaked into semantics.

### Composition

Combine already-qualified local seams while keeping each individual seam within its established boundary.

If the composition creates a new ambiguous answer, second authority, or invalid frontier, local qualification was not sufficient for that combined query.

### Verification-of-verification

Attack the formal experiment itself: witness existence, bounded scope, vacuity, mutation sensitivity, and the correspondence between the experiment and the production semantics it is claimed to inform.

### Recovery composition

Attack partial publication across more than one semantic authority.

A writer can be locally crash-safe while the product of several independently safe writers still admits a household world that no reader can interpret consistently.

## State model

Structural research has independent Work and Finding axes.

```text
Work
  CATALOGUED | REVIEWED | READY | OBSERVING | DONE | DEFERRED | OUTSIDE

Finding
  UNTESTED | SURVIVED | COUNTEREXAMPLE | REDUNDANT
```

Interpretation:

- `CATALOGUED / UNTESTED`: collected but not yet cross-referenced against existing LOAM evidence.
- `REVIEWED / UNTESTED`: existing observations were checked, but no direct structural answer was found.
- `READY / UNTESTED`: selected for one small formal observation.
- `DONE / SURVIVED`: the tested structural law survived the explicit bounded or proved question.
- `DONE / COUNTEREXAMPLE`: a claimed minimality/invariance/composition/refinement property failed.
- `DONE / REDUNDANT`: an existing observation already answers the same structural question.

There is intentionally no Runtime axis here. A structural counterexample may justify a research-model correction, stronger qualification, deletion, or later practical change, but production work is still governed by normal dogfood and design gates.

## Structural catalogue

| ID | Structural pressure | Claim under attack | Smallest first witness | Likely first instrument | Work | Finding |
|---|---|---|---|---|---|---|
| S001 | delete one retained distinction and reconstruct it from the rest | every retained primitive/distinction still earns its place | two models agree on all retained evidence except the candidate is removed/reconstructed; selected query differs or remains equal | Alloy or Lean, depending claim | CATALOGUED | UNTESTED |
| S002 | merge or quotient two currently distinct identities/coordinates | current identity granularity is not finer than necessary | collapse two identities while preserving all quantities and selected provenance; ask whether any legitimate query is lost | Alloy | CATALOGUED | UNTESTED |
| S003 | split one occurrence/effect into several pieces or merge several pieces into one equivalent decomposition | selected household answers depend on meaning, not arbitrary decomposition shape | equal aggregate world under split vs merged representation | J or Alloy | CATALOGUED | UNTESTED |
| S004 | permute effect/history row order or consistently rename opaque identities | ordering and accidental names are not semantic authority | same relation/history under permutation or alpha-renaming | Lean, J, or executable property test | CATALOGUED | UNTESTED |
| S005 | add an observationally neutral zero-net or reconstructible extension | harmless representational extension cannot perturb unrelated projections | base world vs base world plus neutral pair / conservative fact extension | Alloy, J, or Lean | CATALOGUED | UNTESTED |
| S006 | compose two independently qualified seams | local qualification survives a concrete one- or two-hop semantic composition | choose two nearby existing observations and combine only their already-earned distinctions | Alloy or Lean | CATALOGUED | UNTESTED |
| S007 | construct a three-way interaction whose every pair is admissible | pairwise safety is sufficient for the selected combined query | A+B, B+C, A+C each valid; A+B+C yields ambiguity or conflict | Alloy | CATALOGUED | UNTESTED |
| S008 | lengthen a finite history/chain after the small witness works | bounded topology or frontier law does not secretly depend on tiny path length | same law at chain lengths 1, 2, 3, then scope escalation / induction candidate | Alloy first, Lean if law emerges | CATALOGUED | UNTESTED |
| S009 | vary the admissible query set while holding the world model fixed | "minimal" is always stated relative to an explicit legitimate query inventory | one evidence boundary is sufficient for query set Q1 but insufficient for Q2 | documentation + Alloy information test | CATALOGUED | UNTESTED |
| S010 | mutate or weaken the formal model and attempt to make the checker notice | an UNSAT counterexample or proof result is non-vacuous and sensitive to the intended law | witness-existence check, premise removal, assertion mutation, scope escalation | Alloy/TLC plus mutation specimen | CATALOGUED | UNTESTED |
| S011 | compare a qualified formal abstraction with the corresponding Lean/Core/Application semantics | the production representation preserves the exact observations the formal model qualified | paired abstract/production states mapped into the same selected query | Lean plus finite cross-check, Alloy/J where useful | CATALOGUED | UNTESTED |
| S012 | interrupt publication across two semantic authorities at every meaningful boundary | local writer safety composes into global fail-closed recovery | authority A published / B missing, B published / A missing, stale mixed generations, interrupted retry | TLA+, SPIN, or focused executable recovery test | CATALOGUED | UNTESTED |

## S001 — retained-primitive deletion

This is the reverse direction of the ordinary falsification atlas.

The ordinary corpus asks:

```text
is current evidence too small?
```

S001 asks:

```text
is current evidence still larger than necessary?
```

Procedure:

1. choose exactly one retained primitive, relation, coordinate, or independently stored distinction;
2. remove it from the candidate model or replace it with a reconstruction from the remaining evidence;
3. keep an explicit selected query set fixed;
4. seek two worlds that become observationally collapsed after removal while a selected query should differ;
5. if no such witness appears, do not immediately delete production state; escalate the question or prove reconstruction where worthwhile.

This directly operationalizes the standing rule that every retained primitive must earn its place.

## S002 — quotient / identity-granularity pressure

Deletion is not the only way a model can be too large.

Two identities may both be needed while the boundary between them is still finer than any legitimate query can observe.

Candidate collapses include only those grounded in current LOAM semantics, for example:

```text
identity A and B -> one equivalence class
coordinate x and y -> one quotient coordinate
several source-distinguished observations -> one candidate authority class
```

The goal is not to discover a universal quotient. It is to ask whether a specific current separation is actually observable.

## S003 — split / merge representation invariance

A representation can accidentally make arbitrary decomposition observable.

First specimens should stay intentionally small:

```text
World A
  one quantity-bearing structure of q

World B
  two structures q1 + q2 where q1 + q2 = q
```

Then classify queries into:

```text
must remain equal
may legitimately differ because provenance/identity itself is queried
```

The second category prevents "invariance" from erasing distinctions that LOAM has already earned.

## S004 — permutation and alpha-renaming

This attacks accidental dependence on serialization order, list order, insertion order, or the literal spelling of opaque identifiers.

A passing result should be stronger than "current examples happen to sort the same way". The selected answer should be invariant under the explicitly allowed permutation or renaming action.

Where a historical order is itself semantic evidence, that order must be excluded from the transformation rather than silently normalized away.

## S005 — neutral extension

Application 006 already gives evidence for conservative fact extension, but S005 asks for a reusable structural pressure category rather than assuming every future extension is conservative.

Candidate mutations include:

```text
zero-net quantity pair
additional evidence ignored by a selected old projection
new unrelated coordinate
reconstructible derived row
```

A counterexample may reveal hidden global coupling or a projection that is accidentally reading more authority than intended.

## S006 — local composition

`AGENTS.md` already requires one- or two-hop semantic-neighbor checks after practical changes.

S006 turns that discipline into an explicit falsification family.

The important rule is to compose **already earned meanings**, not invent a large speculative scenario.

Examples of useful shapes include:

```text
replacement + routing
shared burden + refund provenance
rights + later settlement
bitemporal correction + valuation selection
partial discharge + correction
```

The exact pair should be selected from current repository pressure, not from this illustrative list.

## S007 — pairwise-safe, triple-unsafe

Pairwise composition can still miss higher-order constraints.

A minimal counterexample shape is:

```text
A + B   admissible
B + C   admissible
A + C   admissible
A + B + C   ambiguous / contradictory / double-authoritative
```

This case should be used sparingly because it can grow state space quickly. Promote it only when two-hop checks repeatedly leave a concrete three-way seam.

## S008 — history length and scope escalation

A one-step or two-step frontier law may fail only after a longer chain.

Candidate subjects include replacement, correction, continuation, relation discharge, routing history, temporal authority, or any future finite-history mechanism.

A useful progression is:

```text
small SAT witness exists
assertion checked at scope n
same assertion checked at n+1 / n+2
if law appears structural rather than accidental, consider Lean proof
```

Do not mistake repeated bounded success for a proof.

## S009 — query admissibility

Minimality is meaningless without a declared observation/query boundary.

If every imaginable predicate is legitimate, almost no compression is possible.
If only current balance is legitimate, almost all provenance can disappear.

For each future minimality claim, identify the query family that gives the claim meaning.

A first query inventory may include categories such as:

```text
physical quantity / balance
historical as-known answer
future commitment / availability
operation rights
burden / obligation / outstanding relation
provenance / identity
recognition / valuation
recovery / current-open frontier
```

This is not a promise to support every category in production. It is a way to make the phrase "smallest coherent design" falsifiable rather than rhetorical.

## S010 — verification-of-verification

A green formal check can be misleading when:

```text
the witness world is impossible under the premises
the assertion is weaker than the prose claim
the scope is too small to admit the bad topology
a premise accidentally bakes in the desired conclusion
```

For important observations, the smallest useful robustness bundle is:

1. demonstrate at least one representative witness for the intended model region;
2. show the counterexample appears when the target law is deliberately weakened or negated where practical;
3. remove or mutate a critical premise and confirm the checker reacts;
4. increase the relevant finite scope when path length or cardinality could matter;
5. record explicitly which result is bounded and which law, if any, is later proved in Lean.

This is not a demand to mutation-test every tiny Alloy file. Apply it where a result is being used as strong architectural evidence.

## S011 — formal abstraction to production refinement

A successful Alloy/TLA+ observation and a successful Lean implementation can still describe subtly different systems.

S011 asks for the smallest correspondence needed to justify a production claim.

The target is not a giant verified compiler or full refinement framework.

A useful specimen is:

```text
formal state A  -> production state A'
formal state B  -> production state B'

selected formal observation differs/equal as qualified
therefore
selected production query must differ/equal in the same way
```

Only observations that materially constrain production need this bridge.
Experiment-local vocabulary that never enters production does not automatically create S011 work.

## S012 — cross-authority partial publication

WriterOwnership and individual recovery protocols can each be correct while a multi-authority operation still leaves an unsafe combined snapshot.

Candidate crash worlds include:

```text
A new, B old
A old, B new
A relation published, endpoint evidence missing
new generation contents durable, CURRENT not advanced
CURRENT advanced, dependent auxiliary authority stale
retry sees a mixture produced by the interrupted attempt and later work
```

The expected default is fail-closed when a reader cannot justify one coherent household answer.

Do not introduce distributed-transaction machinery pre-emptively. First seek the concrete counterexample and identify whether publication ordering, generation authority, reconstruction, or an explicit relation is actually missing.

## Cross-reference policy

Before promoting any S-item to `READY`:

1. search existing Observation / Application / practical evidence for an information-equivalent result;
2. distinguish a general standing rule from direct evidence that the structural question has actually been tested;
3. record `REDUNDANT` when an existing result directly answers the selected question;
4. otherwise keep the item `REVIEWED / UNTESTED` until a small witness can be stated;
5. prefer one structural representative per independent seam.

The existence of `AGENTS.md` rules such as primitive minimality and local composition does not itself close S001 or S006. Policy says what LOAM intends to do; a structural observation asks whether the intended property actually survives a selected model.

## Selection rule

After the first cross-reference review, rank unresolved structural specimens by:

```text
C  contact with current practical LOAM
   0 remote methodological concern
   3 directly touches an active semantic/practical boundary

D  destructive power
   0 mostly documentation hygiene
   3 could falsify a central minimality / authority / invariance claim

W  witness smallness
   0 large framework required
   3 tiny bounded or executable witness

N  novelty after cross-reference
   0 already nearly answered
   3 clearly unqualified
```

Do not automatically interrupt the domain Falsification READY queue.
A structural specimen should jump ahead only when current practical work exposes that exact seam or when it undermines the reliability of evidence being used to continue the current queue.

## Completed review gate

The initial S001-S012 cross-reference is complete.

Current authority:

```text
LOAM_STRUCTURAL_FALSIFICATION_PROGRESS.md
```

Review result at the first checkpoint:

```text
DONE / REDUNDANT       9
READY / UNTESTED       2
REVIEWED / UNTESTED    1
```

The first structural near queue is:

```text
S003  split / merge representation invariance
S008  history length / bounded-topology pressure
```

S007 remains reviewed watchlist pressure until a concrete three-way seam appears.

## Boundary

This document introduces:

```text
no production type
no persistence stream
no runtime authority
no CLI/TUI surface
no canonical household data
no generic equivalence/refinement framework
no requirement to prove every Observation in multiple tools
```

Its only job is to make LOAM's own structural claims easier to attack.

The intended rhythm is:

```text
domain falsification asks whether reality needs more information
structural falsification asks whether LOAM keeps too much, leaks representation, composes badly, or overstates its evidence

both feed the same goal:
smallest coherent design that survives real household use
```