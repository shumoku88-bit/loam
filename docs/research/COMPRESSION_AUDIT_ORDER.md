# Compression audit order

The original six-phase compression audit tracked by Issue #535 is complete and remains historical evidence.

Its phase order was:

1. reproduce the production source surface;
2. inventory independently retained semantic meaning;
3. audit repeated mechanics across histories, frontiers, publishers, persistence, and writer protocols;
4. retire dead production surface;
5. compress research and CI history;
6. compare before/after complexity.

Current structural-compression work continues in:

`docs/research/SEMANTIC_AUDIT_LEDGER.md`

That ledger is the active navigation surface for:

- the current production checkpoint;
- completed semantic/structural reductions;
- audit verdicts that should not be repeatedly reopened without new evidence;
- the ordered queue of remaining subtraction candidates;
- the proof/counterexample/transition-model gate required before implementation.

Before starting any listed item, re-check actual remote `main`, open PRs, current callers, canonical/wire impact, and exact-head CI scope. Do not skip to a broader abstraction merely because a smaller candidate appears tedious.
