# Obligation Scaffold Method

Status: **adopted LOAM audit method**

LOAM uses obligation scaffolding to reduce a broad semantic question before
adding proofs, tests, abstractions, or AI-generated reasoning.

The method is inspired by translation-validation work that first constructs
deterministic proof scaffolds and leaves only residual proof obligations for
expensive reasoning. LOAM adopts the **work-allocation principle**, not an
external runtime or library dependency.

## Default rule

For a non-trivial semantic feature, correction, audit, or proof request:

```text
question
   |
   v
obligation DAG
   |
   +--> D  deterministic
   |
   +--> P  previously earned
   |
   +--> R  residual
```

Do not begin by asking an AI or proof assistant to solve the whole question.

First make the obligations explicit and classify each node.

## D — deterministic

An obligation is **D** when repository-local evidence can close it without new
semantic invention.

Typical evidence includes:

- direct computation;
- finite enumeration;
- parser / decoder admission;
- type construction;
- source reachability;
- writer / reader inventory;
- import and call-graph ownership;
- exact derivation from an already-retained value;
- executable witness or bounded counterexample search where the bound is the
  intended question.

A D node should record the evidence that closes it. It should not be converted
into a new theorem merely because Lean can express one.

## P — previously earned

An obligation is **P** when an existing qualified semantic boundary already owns
the property.

Examples include:

- a theorem already proved in Lean;
- a proof-carrying type;
- an admitted read image;
- a previously qualified publisher;
- a lifecycle frontier whose meaning is being reused rather than redefined;
- a prior observation whose law is intentionally part of the current production
  boundary.

A P node must name the boundary being reused.

Do not re-prove a P node locally unless the new consumer exposes a concrete gap,
projection drift, or independent trust boundary.

## R — residual

An obligation is **R** only after D and P have been exhausted.

Residual questions are then classified again:

```text
R
├─ proof
├─ policy
├─ empirical
└─ unknown
```

### R / proof

A genuinely new invariant remains. This is where Lean, Alloy, TLA+, SPIN, or
another earned formal tool may be appropriate.

Prefer the smallest proof that closes the residual obligation. Promote a fact
into a proof-carrying type when carrying it removes repeated checks, prevents
projection drift, or protects more than one meaningful consumer.

### R / policy

The remaining question depends on what LOAM is intended to mean.

Examples:

- month-level versus exact-date coverage;
- whether an advisory match should ask, suppress, or merely display;
- which explicit user choice a TUI should default to.

A policy residual is not a failed proof. Do not invent extra semantics merely to
make it provable.

### R / empirical

The remaining question is about cost, usability, performance, or observed
behavior. Measure it instead of proving a surrogate property.

### R / unknown

If the residual cannot yet be classified, keep it explicit. Do not hide it
inside a generic abstraction or a broad AI prompt.

## AI work allocation

AI reasoning is downstream of the scaffold.

```text
all apparent obligations
        |
        v
D and P removed
        |
        v
small residual set
        |
        +--> proof    -> AI + formal tool + kernel/checker
        +--> policy   -> explicit design decision
        +--> empirical-> measurement
        +--> unknown  -> focused investigation
```

The goal is not to make AI solve more proofs.

The goal is to make AI reason only where repository structure, existing proofs,
and deterministic checks cannot already answer the question.

## When to use the method

Use an obligation scaffold when at least one of these is true:

- a new feature crosses an existing semantic boundary;
- a writer or authority path changes;
- a new read model could accidentally acquire authority;
- several proof obligations appear at once;
- an audit question is broad enough that reopening the whole subsystem would be
  wasteful;
- a proposed proof-carrying type would propagate through multiple modules;
- a new abstraction is being justified primarily by fear of a semantic gap;
- AI is about to be asked to reason over a large part of the repository.

Small local refactors, obvious presentation changes, and routine fixture updates
do not require a ceremony document merely to satisfy the method.

## Expected audit shape

A useful scaffold normally records:

1. the root semantic question;
2. the obligation DAG;
3. D nodes and their deterministic closing evidence;
4. P nodes and the qualified boundary each reuses;
5. remaining R nodes and their subtype;
6. the smallest justified production change, if any;
7. an explicit stop point describing what the result does **not** justify.

The scaffold may live in an existing audit document. A new file is not required
when the classification fits naturally into current evidence.

## Promotion rule

Do not promote a local observation into more production structure merely because
it is true.

A new theorem, proof field, type index, runtime check, persisted field, or
abstraction should earn its cost by doing at least one concrete job:

- remove repeated validation;
- prevent an actual constructor or authority bypass;
- prevent projection drift;
- collapse duplicated state;
- protect multiple consumers;
- expose a counterexample that current production can otherwise admit;
- simplify a real downstream path.

If D or P already closes the obligation, additional proof surface is usually a
cost rather than a safety gain.

## Relationship to existing LOAM practice

This method formalizes a pattern already present in LOAM's Generation-2 audits:
retain only necessary distinctions, derive what can be derived, and separate only
independent reasons to change.

The Scheduled cycle-fill audit first demonstrated the pattern by reducing a
broad post-G2 question to one existing-plan-awareness residual. The Scheduled
Coverage audit then applied the explicit D / P / R classification and found only
presentation-policy residuals.

Those are precedents, not special cases. D / P / R is now the default
classification vocabulary for future non-trivial obligation DAGs.

## Tool independence

This method does not require Trivet, AXLE, or another external proof
orchestrator.

It may later be automated, but the semantic ownership remains:

```text
repository evidence
    -> deterministic scaffold
    -> residual obligations
    -> appropriate tool or human decision
    -> ordinary LOAM qualification
```

No external AI result becomes production authority merely by participating in
the scaffold.
