# LOAM Semantic Blueprint

Status: **experimental long-horizon coordination surface**

Baseline when introduced: 730a393e41d0250905ee532d7ce2b606ef8247c8

This document is a small, shared semantic map for long-running AI-assisted
development. Its job is to make semantic drift visible across many branches,
pull requests, models, and work sessions.

It is **not** a new persistence authority, proof artifact, or replacement for
the source documents and qualified code boundaries it points to. If a detailed
owner below disagrees with this summary, resolve the discrepancy explicitly:
either repair the implementation, repair this blueprint, or change the intended
semantics through a reviewed decision.

The blueprint should stay small enough to reread before a non-trivial semantic
change.

## Why this exists

A compiling change can still move a system away from its intended meaning. In a
long AI-assisted development, local changes can gradually:

- add assumptions that make a question easier;
- weaken a result while keeping the same name;
- create a second semantic authority;
- turn a projection into retained state;
- collapse two meanings because their representations look alike;
- replace unknown evidence with an invented default;
- bypass an admission, correction, or lifecycle frontier.

LOAM already uses deterministic / previously-earned / residual obligation
scaffolding for local questions. This blueprint supplies the outer loop:

~~~text
semantic blueprint
      |
      v
local question
      |
      v
D / P / R obligation scaffold
      |
      v
implementation + qualification
      |
      v
review against blueprint
      |
      +---- intended semantic change ----> update blueprint explicitly
      |
      +---- accidental drift ------------> repair before merge
~~~

## North-star commitments

These are intentionally broader than individual theorems. Each item names the
meaning that should remain stable while implementations change.

### B1 — One operational household authority

LOAM is the current day-to-day household authority. Current loam-data,
manifests, and configuration carry household meaning.

Implementation shapes may change freely when qualified. A persisted
representation that carries operational meaning changes only through an
explicit migration, reconstruction, or other qualified transition.

Do not silently invent, discard, or rewrite household facts.

Primary owner:
[HOUSEHOLD_OPERATING_MODE.md](HOUSEHOLD_OPERATING_MODE.md).

### B2 — Minimal retained evidence before familiar product nouns

LOAM does not begin by assuming Account, Transaction, Budget, Envelope, Month,
or Report as canonical primitives.

The practical core prefers small retained evidence such as Event, Effect, Locus,
Measure, exact Quantity, correction/lifecycle evidence, and explicit relations.
A familiar household noun becomes canonical only when an independently
observable household answer cannot be reconstructed without retaining it.

Primary owners:
[README.md](../README.md) and [DESIGN_PHILOSOPHY.md](../DESIGN_PHILOSOPHY.md).

### B3 — Ordinary movement publication preserves balance without a transaction kind

The ordinary movement entrance admits equal FROM and TO totals before publishing
one Event. The retained Core fact is the resulting signed Effects; purchase,
transfer, income, and similar labels are not required transaction kinds in the
recording core.

A new entrance must not weaken this boundary merely to make publication easier.

Primary owner:
the current movement / Actual authority section of [README.md](../README.md).

### B4 — Current answers are projections over retained provenance

Corrections, replacements, validity changes, and related lifecycle evidence do
not become permission to erase provenance casually. Current answers are
derived through qualified frontiers or admitted read images over retained
evidence.

Where a value is only admission-produced rather than proof-carrying, its safety
still belongs to the qualified construction path. Do not treat a type name such
as "Admitted" as stronger evidence than its actual representation provides.

Primary supporting evidence:
[ADMITTED_TYPE_INTEGRITY_AUDIT_2026-09-19.md](research/ADMITTED_TYPE_INTEGRITY_AUDIT_2026-09-19.md).

### B5 — Unknown is not zero, missing is not false, and refusal is an answer

A balance or quantity question that requires origin completeness does not obtain
that completeness from activity, naming, or presentation configuration.
Explicit zero-origin coverage or another qualified basis must support the
answer.

Likewise, missing historical evidence is not permission to manufacture a value.
When evidence is insufficient, fail closed or expose the uncertainty.

Primary owners:
the quantity / zero-origin section of [README.md](../README.md) and
[HOUSEHOLD_OPERATING_MODE.md](HOUSEHOLD_OPERATING_MODE.md).

### B6 — Projection does not acquire authority by becoming convenient

Reports, serializers, UI summaries, comparison surfaces, exported journals, and
other read models remain projections unless explicitly promoted through a
separate semantic decision.

An exporter may reject inputs it cannot represent conservatively. It must not
silently infer roles, valuation, balancing quantities, historical dates, or
other semantics merely to satisfy a target format.

Generated external representations are disposable unless a later reviewed
decision explicitly gives them authority.

Primary owners:
[HOUSEHOLD_OBSERVATION_V1.md](HOUSEHOLD_OBSERVATION_V1.md),
[DESIGN_PHILOSOPHY.md](../DESIGN_PHILOSOPHY.md), and the qualified exporter's
own boundary documentation when present.

### B7 — Share mechanics without erasing semantic partitions

Isomorphic storage or identical algorithms justify shared mechanics, not
automatic ontology merging.

Before collapsing two semantic families, ask whether two household worlds can
agree on the proposed merged representation while requiring different answers.
If yes, keep the distinction.

Before retaining duplicated implementation, ask whether the same structural law
is being independently reimplemented. If yes, extract the smallest useful
mechanism.

Primary owners:
[DESIGN_PHILOSOPHY.md](../DESIGN_PHILOSOPHY.md) and the semantic census /
compression evidence under [research/](research/).

### B8 — Formal methods and AI are evidence-producing instruments

Lean, Alloy, J, TLA+, Apalache, SPIN, miniKanren, tests, diagrams, and AI
reasoning are selected for the question they answer. Their presence is not a
goal and their output is not semantic authority merely because it is formal or
agent-generated.

A local theorem proves the proposition it states under its assumptions. A
passing compiler or CI run does not by itself establish that the chosen
statement still represents the intended household meaning.

Primary owners:
[README.md](../README.md),
[EVIDENCE_ATLAS.md](EVIDENCE_ATLAS.md), and
[OBLIGATION_SCAFFOLD_METHOD.md](OBLIGATION_SCAFFOLD_METHOD.md).

## Review card

For a non-trivial semantic pull request, review the diff against this card after
local tests / proofs pass:

1. **Authority:** Does this create a second source of truth or let a projection
   write back into authority?
2. **Assumptions:** Did an implementation become easier because a new assumption
   was added, evidence was dropped, or an unknown case disappeared?
3. **Conclusion:** Does an existing API, theorem, report, or status now answer a
   weaker question under the same name?
4. **Lifecycle:** Does the path bypass correction, replacement, validity,
   discharge, retirement, or another currentness frontier that previously owned
   the answer?
5. **Persistence:** Does operational data representation change without an
   explicit migration / reconstruction story?
6. **Projection:** Did derived presentation state become independently retained
   without a demonstrated need?
7. **Semantic partitions:** Were two meanings merged only because their data
   shape or mechanics matched?
8. **Externalization:** Does an export / adapter infer target semantics instead
   of refusing an unsupported case?
9. **Evidence:** Is a claim broader than the proof, model check, test, or
   observation that supports it?
10. **Blueprint:** If the intended meaning really changed, is that change named
    here and in the more detailed owner rather than hidden in code?

A yes is not automatically a defect. It is a request to classify the change:

~~~text
intended semantic change
    -> update the owner + blueprint and qualify the transition

accidental drift
    -> repair the implementation before merge

uncertain
    -> keep the obligation explicit and investigate
~~~

## Relationship to the Obligation Scaffold Method

The two surfaces answer different questions.

The blueprint asks:

> What meaning is this repository trying to preserve across time?

The obligation scaffold asks:

> For this concrete change, what still has to be shown?

Use the blueprint to choose the root semantic question and to review the result.
Use D / P / R classification to keep the local work small.

Do not duplicate a qualified local theorem, audit, or protocol inside this file.
Link to its owner instead.

## Check-growth rule

Do **not** turn every blueprint item into CI.

Promote a review finding into an automated check only when:

- the failure pattern has appeared concretely;
- a deterministic repository-local check can detect it;
- the check has a clear ownership boundary;
- expected false positives are low;
- keeping the check is cheaper than repeatedly rediscovering the failure.

A check that no longer protects a live failure mode may be retired. The
blueprint keeps the semantic reason visible even when a temporary verification
mechanism disappears.

## Maintenance rule

This file should change rarely.

Update it when a change alters one of the north-star commitments, not for every
new feature, report, theorem, or observation. Detailed findings should continue
to live in their narrowest semantic owner.

The desired fixed point is not "the blueprint never changes." It is:

~~~text
implementation changes frequently
evidence grows and is retired as needed
the intended meaning changes only explicitly
~~~
