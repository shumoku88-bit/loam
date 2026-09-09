# Verification boundary checkpoint

## Scope

This checkpoint closes the focused verification sequence established by Observations
161–168 and completed by production correspondence Observations 237–238. It records
what LOAM has mechanically demonstrated, what remains a human trust boundary, and
which verification mechanisms are not justified as mandatory product infrastructure.

## Established evidence

### Reviewed proposition alignment

Observation 161 introduced a reviewed Lean `Prop` as an explicit statement contract.
Observation 162 field-tested that pattern against existing Observation 159 proofs
without rewriting their mathematics.

This gives a mechanical edge from a reviewed Lean proposition to theorem compatibility
and then to Lean kernel acceptance.

It does **not** establish that human intent is identical to the reviewed Lean
proposition.

### Shared-definition drift remains a semantic hole

Observation 163 demonstrated a coupled drift case where a weaker shared definition and
a correspondingly changed contract still align mechanically even though the intended
vector meaning has changed.

Therefore proposition inhabitation alone does not independently pin the semantics of
declarations shared by both the implementation and the contract.

### Independent statement surface

Observation 164 moved the reviewed statement surface outside LOAM implementation
vocabulary and expressed the relevant observable claim using only concrete integer
equalities.

The independent surface accepted the intended Observation 159 witness and rejected the
weaker total-only drift demonstrated by Observation 163.

The trusted statement surface itself still requires human review.

### Upstream Comparator qualification

Observation 165 established the positive case: upstream `leanprover/comparator`
accepted an exact Challenge/Solution statement pair with an empty permitted-axiom set
and replayed the solution through the Lean kernel.

Observation 166 established the negative statement case: Challenge and Solution each
compiled independently, but Comparator rejected a deliberately different target
theorem statement.

Observation 167 established the negative axiom-policy case: Challenge and Solution
exposed the same theorem statement, but Comparator rejected the Solution because
`Observation167.unpermitted_fact` was reachable from the proof while absent from
`permitted_axioms`.

Together these observations provide direct LOAM-local evidence for the Comparator
boundaries that matter here: statement equality and axiom restriction.

### Independent kernel diversity

Observation 168 added pinned Nanoda checking to the positive Comparator field trial.
The same exported Solution was accepted by both the Lean default kernel and Nanoda.

This establishes checker diversity for the tested proof environment. It does not prove
either checker bug-free, and it does not remove the Comparator/export layer from the
trusted pipeline.

The trial temporarily permits `propext` because the tested Comparator/Nanoda primitive
export path includes it even for proofs that do not directly depend on it. That
allowance is an integration boundary, not a LOAM semantic assumption.

### Production correspondence boundary

Observation 237 applied the verification question to the production Scheduled
open-world read boundary. It compared three approaches:

- a fully independent concrete statement can become vacuous with respect to production;
- a statement importing production vocabulary genuinely touches production but reopens coupled semantic drift;
- a tiny experiment-local neutral judgement plus an explicit total bridge can connect independent meaning to production while keeping the remaining trust edge visible.

The third approach survived the selected Scheduled pressure case. It did **not** make
the correspondence itself mechanical. The bridge remains a small human-reviewed edge.

Observation 238 then tested whether Comparator could remove that edge. Comparator
accepted an exact Challenge/Solution pair whose Solution deliberately did not import or
evaluate LOAM production code. This is a mechanical counterexample to treating
Comparator acceptance as evidence of production correspondence.

Therefore Comparator qualifies statement identity, axiom policy, and kernel replay. It
does not qualify that an implementation-independent theorem was actually derived from
LOAM production semantics.

## Current trust boundary

The strongest useful picture is now:

```text
human intent
    |
    | human review
    v
independent semantic statement
    |
    | small explicit correspondence bridge
    | human-reviewed mapping
    v
production implementation
    |
    | Lean proof
    v
Lean kernel
```

Where a separate statement-integrity boundary is materially useful, Comparator and an
independent checker may be added around the relevant proof artifact:

```text
independent Challenge
    |
    | Comparator
    | - statement equality
    | - permitted-axiom restriction
    v
Solution proof environment
    |
    +--> Lean default kernel
    |
    +--> Nanoda external kernel
```

These are complementary boundaries. The second does not replace the correspondence
bridge in the first.

Two non-mechanical edges are intentionally visible:

```text
human intent -> independent semantic statement
independent meaning -> production mapping
```

No verifier exercised here establishes either human-intent correspondence or the
semantic correctness of the production bridge. The design goal is therefore not to
pretend those edges disappear, but to keep them small, explicit, stable, and
reviewable.

## Sandbox boundary

Observations 165–168 and the Comparator counterexample use Comparator's
`fake-landrun.sh` development shim. Their successful runs qualify statement comparison,
axiom checking, kernel replay, and tested checker integration in LOAM's trusted
repository CI, but **not** hostile-solution build sandboxing.

Real landrun/systemd sandbox qualification is a separate problem and should only be
added if LOAM begins accepting proof artifacts that must be treated as adversarial.

## Product decision at this checkpoint

Do not make Comparator, Nanoda, a generic statement-contract framework, a generic
correspondence ontology, or a production-adapter framework mandatory across LOAM.

The evidence supports a narrower policy:

- keep ordinary Lean proofs and production code simple by default;
- use an independent trusted statement surface when semantic statement drift is a material risk;
- expose any necessary independent-semantics/production mapping as a small reviewable bridge rather than hiding it in shared vocabulary;
- use Comparator only when exact statement identity or explicit axiom policy materially improves evidence;
- add an independent kernel only when checker diversity justifies its build and maintenance cost;
- keep human review explicitly responsible for intent-to-statement and statement-to-production correspondence;
- do not build a LOAM-specific Comparator clone or proof-usage checker merely to chase away the remaining trust edge.

The central design principle is:

```text
formal verification can reduce trust,
but it cannot erase semantic correspondence.

make the remaining trust edge
small
explicit
stable
reviewable
```

## Stop condition

The production-correspondence question is closed by Observations 237–238. Do not repeat
it by relabeling an independent Challenge as `production-backed`, importing LOAM
production vocabulary into the trusted Challenge, or accumulating additional verifiers.

Further verification work should be triggered by a concrete uncovered risk. Examples
that would count as new pressure are:

1. hostile proof submissions that genuinely require sandbox qualification;
2. an upstream change that makes removal of the temporary `propext` allowance useful;
3. a production semantic change that creates a new correspondence risk not covered by the qualified small-bridge model.

Until such pressure exists, this verification sequence is closed. The qualified
research checkpoints, fixtures, successful historical CI, and Git history retain the
evidence without requiring every experimental verifier lane to remain live forever.
