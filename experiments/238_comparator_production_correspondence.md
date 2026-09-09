# Observation 238 — Does Comparator establish production correspondence?

Status: **QUALIFIED — Comparator does not establish production correspondence**

Research baseline: LOAM `110725804c4141b969d8352cb0eb6b23b150e005`

Qualified experiment head before this documentation-only update:
`f2cc8072093ecd2a38c9f6c40e771cb62416b772`

Qualified CI:
- workflow: `Observation 238`
- run: `34370498905`
- job: `102530188449` (`comparator-counterexample`)
- result: **SUCCESS**

## Question

After Observation 237 reduced the independent-semantics/production boundary to a
small explicit bridge, can an independent Challenge plus Comparator mechanically
establish that an accepted Solution genuinely uses the production Scheduled
implementation?

## Counterexample

The trusted Challenge deliberately contains no LOAM vocabulary. Its reviewed
observable is represented by the concrete code `0 = unknown` and states that the
selected absence case yields code `0`.

The Solution has the exact same theorem name and statement, but deliberately does
**not** import LOAM, call `currentScheduledDayEvidenceWithReplacement`, or cross the
Observation 237 bridge. It proves the statement by `rfl`.

Upstream Comparator accepted this pair with an empty permitted-axiom set. The CI log
records all of the following:

- the trusted Challenge built and exported;
- the production-free Solution built and exported;
- Comparator compared the selected theorem;
- the Lean default kernel accepted the Solution;
- Comparator reported `Your solution is okay!`.

Therefore Comparator correctly established the selected statement/axiom/kernel
boundary while accepting a Solution that has no production correspondence at all.

The trial continues to use Comparator's `fake-landrun.sh` development shim. This
observation makes no adversarial sandboxing claim.

## Qualified conclusion

The counterexample survives mechanically:

```text
independent Challenge
        +
production-free Solution
        +
Comparator
        ↓
      accepted
```

So the stronger architecture proposed after Observation 237 is **not** qualified:

```text
independent Challenge
        +
production-backed Solution
        +
Comparator
        ↓
production correspondence   -- not mechanically established
```

The label `production-backed` is not forced by an implementation-independent theorem
statement. A production-free Solution can satisfy the same statement.

Comparator remains useful for the boundary it actually checks: selected statement
identity, permitted-axiom policy, and kernel acceptance. It must not be treated as a
production-correspondence checker.

Observation 237's small explicit correspondence bridge therefore remains the
qualified boundary. Human review is still responsible for the meaning of that bridge.
The trust edge was not removed by adding another verifier.

## Product consequence

Do not make Comparator a mandatory LOAM-wide verification layer on the theory that it
closes semantic correspondence. Use it only where independent statement identity,
axiom restriction, or kernel replay materially improves evidence.

For production correspondence, prefer the smaller architecture already qualified by
Observation 237:

```text
human intent
    ↓
independent semantics
    ↓
small explicit correspondence bridge  ← human review point
    ↓
production implementation
    ↓
Lean proof / kernel
```

## Stop condition

This question is closed unless a genuinely different mechanism is proposed that can
force implementation correspondence without importing production vocabulary into the
trusted statement or enlarging the trusted mechanism beyond the small bridge.

Do not respond by putting LOAM production vocabulary into the trusted Challenge,
adding a generic proof-usage checker, creating a new verification framework, or
adding Nanoda merely to repeat this result. Those moves either reopen coupled semantic
drift or add machinery without addressing the demonstrated correspondence gap.

The dedicated Observation 238 CI lane is research evidence, not a permanent product
obligation. After this qualified result is merged, it is eligible for Phase 5-style
graduation while the fixtures, this checkpoint, and Git history retain the evidence.
