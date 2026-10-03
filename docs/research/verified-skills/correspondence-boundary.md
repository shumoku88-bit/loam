# Skill: Correspondence boundary audit

Status: **Candidate**

## Trigger

Use this skill when a refactor, extraction, optimization, shared mechanism, or
new read/write path claims to preserve the meaning of an existing LOAM behavior.

Typical cases include indexed versus reference implementations, shared mechanics
across semantic families, publisher / reader pairs, and replacement of one
qualified path by another.

## Protected answer

Two implementations may share mechanics only when the correspondence being
claimed is explicit enough to preserve the household answer and its semantic
authority.

Passing the same examples is not sufficient when the implementations can diverge
on correction, unknown handling, identity, lifecycle, or recovery.

## Procedure

1. **State the correspondence claim.**
   Write `old/new`, `reference/indexed`, or `producer/consumer` and the exact
   observable that should agree.

2. **Classify the obligation.**
   Reuse the Obligation Scaffold: deterministic repository fact (D), previously
   qualified boundary (P), or residual question (R). Do not re-prove D/P work.

3. **Check semantic partitions before code shape.**
   Ask whether the two paths have the same authority meaning or merely the same
   representation / algorithm.

4. **Find a divergence witness.**
   Try the smallest world in which aggregates agree but provenance, relation,
   correction status, lifecycle state, identity, or unknown evidence differs.

5. **Trace one adjacent frontier.**
   Follow correction / lifecycle, persistence / recovery, or routing /
   classification only where it can invalidate the claimed correspondence.

6. **Choose the smallest verifier.**
   Use tests for concrete executable equivalence, Lean for a reusable general
   law, Alloy for bounded structural divergence, or another Workbench instrument
   only when it answers a distinct residual question.

7. **Review the conclusion wording.**
   Do not promote a narrow equivalence into "the systems are the same" or turn a
   successful optimization into new semantic authority.

## Falsifiers

Try relevant cases:

- same aggregate quantities, different retained relations or provenance;
- same storage shape, different authority meaning;
- same result before correction, different result after correction;
- same happy-path read, different failure / recovery behavior;
- same finite examples, different behavior outside the tested index or horizon;
- a new implementation agrees only because an unsupported case was removed or
  defaulted.

## Qualification evidence

A successful use should leave:

- one precisely stated correspondence;
- a test / proof / model result whose scope matches that claim;
- no erased semantic partition justified only by implementation similarity;
- no broader production claim than the evidence supports.

## Stop / retire conditions

Stop once the correspondence claim is narrow, qualified, and all adjacent
semantic ambiguity has been ruled out for the changed path.

Retire the skill if a future repository instrument subsumes this routing more
directly or if repeated trials show that it adds no value beyond the Obligation
Scaffold and ordinary local review.
