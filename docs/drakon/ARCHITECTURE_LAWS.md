# LOAM Architecture Laws

Status: macro audit gate for structural changes

These laws are not a promise that LOAM will never change. They are the questions a local simplification must survive before it is treated as an architectural improvement.

The aim is a small household/accounting kernel that works for the current household while remaining usable as a basis for other frontends, locales, Measures, and personal extensions.

## 1. Retain minimal independent evidence

Canonical state should contain facts that must be remembered independently. If an answer can be reconstructed from retained evidence and selected policy, prefer a projection over another durable field or file.

A smaller file is not automatically better. The test is whether independently meaningful information survives.

## 2. Keep Measures neutral and separate

Neutral Core quantities carry an explicit `MeasureId`. Distinct Measures may coexist and must not be silently added or converted.

Current practical entrances may deliberately admit only selected Measures, such as JPY. That entrance policy must not become a global Event law merely because one household currently uses it.

LOAM is multi-Measure native, not a completed foreign-currency accounting system. A base-Measure answer across JPY, USD, commodities, points, or other Measures requires independently earned valuation evidence and policy.

## 3. Keep semantics presentation-neutral

Core and reusable application semantics must not depend on TUI, GUI, Web, AI, localization, or one interaction style.

Presentation may collect a semantic Draft or render a semantic answer. It does not define household truth.

## 4. Frontends do not own authority

High-level frontends should choose a household root and submit presentation-neutral commands or queries. They should not own canonical filenames, writer locking, durable identity allocation, serialization, recovery, or a second copy of canonical state.

A low-level diagnostic entrance may expose physical paths when that explicit physical control is its independent purpose.

## 5. Share mechanics, preserve semantic authority

Equal data shape or similar control flow can justify implementation reuse. It does not prove that two authorities, facts, or policies are one meaning.

Combine mechanics only when independent change and authority boundaries remain visible.

## 6. Unknown and incomplete remain explicit

Missing, unsupported, unresolved, incomplete, and unknown evidence must not silently become zero, empty, false, or irrelevant.

A numerically zero unresolved frontier is not the same as a complete answer.

## 7. Writes fail closed and operational facts survive representation change

Malformed, stale, unsupported, or partially staged writes must refuse without corrupting current authority.

Changing representation requires an explicit migration, reconstruction, or other qualified transition that preserves operational household meaning. Implementation cleanup does not make current household data disposable.

## 8. Derived answers remain projections

Reports, status labels, Remaining, Headroom, conventional statement sections, and similar answers stay derived when retained evidence already determines them.

Do not create canonical report state merely because a UI wants the answer frequently.

## 9. Promote primitives only after repeated independent pressure

A feature-specific need starts local. Consider a shared primitive only when multiple independent consumers or use-cases repeatedly require the same semantic operation or information boundary.

Two consumers are evidence, not an automatic promotion rule. Before promotion also ask whether the shared thing has the same meaning, the same authority, and an independent reason to exist without either caller.

A primitive belongs in Core only when its meaning is genuinely fundamental. Reuse alone may justify an Application or mechanism boundary instead.

## 10. Preserve future capability without speculative abstraction

Future GUI, AI, Web, foreign-currency, import, or plugin-like use is a reason not to bake current presentation accidents into Core.

It is not, by itself, a reason to create a generic framework, compatibility layer, or abstraction before a concrete second pressure exists.

## 11. Keep locale concerns at the edge

Language, labels, display formatting, minor-unit presentation, region-specific household categories, tax conventions, and similar locale policy should remain outside neutral Core unless a more general independent semantic distinction has been demonstrated.

A Japanese household should be first-class without making LOAM Japan-bound.

## 12. Extend by addition, not by distortion

New capabilities should normally arrive as an adapter, projection, policy, evidence family, or explicitly earned semantic relation.

Do not weaken or reinterpret an existing law merely to make a new feature fit. If the new answer depends on genuinely new independent information, add that information explicitly.

## Core-promotion gate

Before moving a concept inward, ask:

```text
Is this required by only one feature?
    -> keep it local

Do two or more independent uses need the same thing?
    -> shared-boundary candidate

Is the commonality semantic, not merely equal shape?
    -> if no, share mechanics only

Does it have an independent reason to exist without either caller?
    -> if no, keep it outside Core

Would promotion preserve Measure neutrality, authority separation,
unknown/completeness semantics, and presentation neutrality?
    -> only then consider Core
```

This is intentionally conservative. Core is not a warehouse for useful features; it is where repeatedly discovered common laws may eventually earn a stable name.

## Refactor verdict

A local refactor should be rejected or redesigned when its simplification depends on any of the following:

- collapsing distinct Measures or inserting an implicit valuation;
- moving frontend concerns into semantic Core;
- letting a frontend own persistence or authority;
- merging equal-shaped but independently authoritative evidence;
- collapsing unknown/incomplete evidence into a convenient value;
- retaining a derivable answer as new canonical state;
- promoting one feature's helper into Core without independent pressure;
- adding speculative abstraction solely for hypothetical consumers;
- baking one locale into neutral household semantics;
- changing operational representation without a qualified continuity path;
- distorting an existing law instead of adding the new independent information.

Passing this gate does not prove a change correct. It means the local improvement has not obviously purchased simplicity by spending LOAM's macro capabilities.
