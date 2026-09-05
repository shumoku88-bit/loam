# Verification boundary checkpoint

## Scope

This checkpoint closes the focused verification sequence established by Observations 161–168. It records what LOAM has mechanically demonstrated, what remains a human trust boundary, and which verification mechanisms are not yet justified as mandatory product infrastructure.

## Established evidence

### Reviewed proposition alignment

Observation 161 introduced a reviewed Lean `Prop` as an explicit statement contract. Observation 162 field-tested that pattern against existing Observation 159 proofs without rewriting their mathematics.

This gives a mechanical edge from a reviewed Lean proposition to theorem compatibility and then to Lean kernel acceptance.

It does **not** establish that human intent is identical to the reviewed Lean proposition.

### Shared-definition drift remains a semantic hole

Observation 163 demonstrated a coupled drift case where a weaker shared definition and a correspondingly changed contract still align mechanically even though the intended vector meaning has changed.

Therefore proposition inhabitation alone does not independently pin the semantics of declarations shared by both the implementation and the contract.

### Independent statement surface

Observation 164 moved the reviewed statement surface outside LOAM implementation vocabulary and expressed the relevant observable claim using only concrete integer equalities.

The independent surface accepted the intended Observation 159 witness and rejected the weaker total-only drift demonstrated by Observation 163.

The trusted statement surface itself still requires human review.

### Upstream Comparator qualification

Observation 165 established the positive case: upstream `leanprover/comparator` accepted an exact Challenge/Solution statement pair with an empty permitted-axiom set and replayed the solution through the Lean kernel.

Observation 166 established the negative statement case: Challenge and Solution each compiled independently, but Comparator rejected a deliberately different target theorem statement.

Observation 167 established the negative axiom-policy case: Challenge and Solution exposed the same theorem statement, but Comparator rejected the Solution because `Observation167.unpermitted_fact` was reachable from the proof while absent from `permitted_axioms`.

Together these observations provide direct LOAM-local evidence for the two Comparator boundaries that matter here: statement equality and axiom restriction.

### Independent kernel diversity

Observation 168 added pinned Nanoda checking to the positive Comparator field trial. The same exported Solution was accepted by both the Lean default kernel and Nanoda.

This establishes checker diversity for the tested proof environment. It does not prove either checker bug-free, and it does not remove the Comparator/export layer from the trusted pipeline.

The trial temporarily permits `propext` because the current Comparator/Nanoda primitive export path includes it even for proofs that do not directly depend on it. That allowance is an integration boundary, not a new LOAM semantic assumption.

## Current trust boundary

The strongest mechanically exercised path is now:

```text
human intent
    |
    | human review
    v
independent Challenge.lean statement
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

The remaining non-mechanical edge is intentionally visible:

```text
human intent -> trusted Challenge.lean
```

No tool in this sequence establishes that the trusted formal statement captures what a human meant.

## Sandbox boundary

Observations 165–168 deliberately use Comparator's `fake-landrun.sh` development shim. Their successful runs therefore qualify statement comparison, axiom checking, kernel replay, and Nanoda integration in LOAM's trusted repository CI, but **not** hostile-solution build sandboxing.

Real landrun/systemd sandbox qualification is a separate problem and should only be added if LOAM begins accepting proof artifacts that must be treated as adversarial.

## Product decision at this checkpoint

Do not make Comparator, Nanoda, or a generic statement-contract framework mandatory across all LOAM code merely because these experiments succeeded.

The evidence supports a narrower policy:

- keep ordinary Lean proofs and existing Observation workflows simple by default;
- use an independent trusted statement surface when semantic statement drift is a material risk;
- use Comparator when exact statement identity and explicit axiom policy materially improve reviewability;
- add Nanoda when checker diversity is worth its build and maintenance cost;
- keep human review explicitly responsible for intent-to-statement correspondence;
- do not build a LOAM-specific Comparator clone.

## Next pressure

Further verification work should be triggered by a concrete uncovered risk rather than by verifier accumulation.

The most meaningful remaining candidates are:

1. real hostile-solution sandbox qualification if LOAM ever consumes untrusted proof submissions;
2. removal of the temporary `propext` allowance after the upstream Comparator/Nanoda issue is fixed;
3. applying the independent Challenge + Comparator boundary to a genuinely production-relevant LOAM semantic claim rather than another synthetic verifier fixture.

Until one of those pressures becomes concrete, the 161–168 verification sequence is sufficient as an experimental checkpoint.
