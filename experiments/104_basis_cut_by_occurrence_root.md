# Observation 104: Can a quantity basis cut follow correction by occurrence root?

## Question

Application 008 introduced `QuantityBasis` because an observed starting quantity is not itself an Event/change. Application 009 then made basis correction append-only, but deliberately left rebasing, historical import before the application origin, and basis valid/learned time outside its boundary.

Private dogfood has now exposed that missing seam in the smallest possible way:

```text
basis quantity
+ every effective Event quantity
```

can double-count an occurrence that was already reflected in the basis observation and was only recorded into LOAM afterward.

The question is not yet whether LOAM needs a Date, global Event order, or a general temporal model. It is narrower:

> What is the smallest explicit evidence that one basis already reflects one remembered occurrence, even if that occurrence is corrected again later?

## Existing evidence

Several earlier results constrain the answer.

- Observation 053 says Event-memory representation order is not semantic history.
- Stable `EventId` exists independently of coordinates and list position.
- `EventCorrection` preserves both target and replacement and repeated correction may form an admitted finite path.
- Application 009 explicitly did not model historical import before the application origin.

Therefore a file-position cut, Git chronology, or implicit "everything before this row" rule would import semantics that LOAM has repeatedly refused.

## Two candidates

### Candidate A: terminal Event identity

A tempting representation is:

```text
basis already reflects terminal Event pre-v2
```

This works only while `pre-v2` remains the terminal interpretation. If a later correction extends the same occurrence:

```text
pre-v1 -> pre-v2 -> pre-v3
```

the remembered terminal becomes stale and `pre-v3` leaks back into the post-basis quantity unless the cut is rewritten.

That couples basis applicability to the current correction frontier.

### Candidate B: correction-root occurrence identity

A smaller stable statement is:

```text
basis already reflects the occurrence rooted at pre-v1
```

The root does not claim time or ordering. It names only the retained occurrence/correction component already folded into the basis observation.

At query time LOAM may resolve that root through the currently admitted correction path:

```text
cut root pre-v1
       ↓
current correction terminal pre-v3
       ↓
exclude that terminal from post-basis Event quantity
```

A later correction changes the effective interpretation of the old occurrence but does not require rewriting which occurrence the basis already contained.

## Lean probe

`104_basis_cut_by_occurrence_root.lean` uses only synthetic values and existing production Event / EventCorrection / correction-frontier machinery.

The specimen has:

```text
basis quantity = 100

pre-basis occurrence
  pre-v1 -> pre-v2 -> pre-v3

post-basis occurrence
  later = -7
```

The exact quantities carried by the successive corrected interpretations differ deliberately. This checks that the basis cut is about occurrence coverage, not about freezing one replacement value.

The probe establishes:

- a terminal-id cut gives `93` while `pre-v2` is terminal;
- after extending the same correction path to `pre-v3`, the unchanged terminal-id cut gives the wrong `84`;
- one root cut `[pre-v1]` gives `93` both before and after that correction extension;
- reversing correction-memory representation order leaves the root-cut answer unchanged;
- an interior replacement is rejected rather than silently accepted as an occurrence root.

## Finding candidate

For the current forward dogfood pressure, the smallest promising cut is not chronology and not the current correction terminal:

```text
QuantityBasis
  + finite set of already-reflected occurrence roots
```

The root set answers only:

> Which retained occurrences are already inside this basis observation?

It does not answer when those occurrences happened.

That keeps the candidate compatible with LOAM's existing separation:

```text
storage order != history
correction != destructive rewrite
basis state != Event change
```

## Important limit

This observation does **not** solve arbitrary historical import.

If a new Event representing an older real-world occurrence is imported after the basis and that occurrence is not named by the cut, it will still be treated as post-basis activity. Supporting arbitrary backfill may therefore require valid-time evidence, source-owned ordering, an explicit import boundary, or another stronger retained relation.

The current candidate is deliberately only as strong as the actual dogfood requirement: a finite number of remembered occurrences are known to have already been reflected in an observed basis.

## Compactness impact

The candidate does not require:

- Account or accounting period machinery;
- global Event chronology;
- Date/Time fields in Core Event;
- Git history as semantic authority;
- rewriting a basis whenever an old occurrence is corrected again;
- a second quantity arithmetic implementation.

The application can potentially remain:

```text
Basis
+ already-reflected occurrence roots
+ existing Correction frontier
+ existing quantity fold
```

Whether that cut belongs inside `QuantityBasis`, beside it as a small relation, or only in an application/import boundary is intentionally left for a later practical step.

## Non-goals

Observation 104 does not introduce production `BasisCut`, persistence, CLI/TUI editing, valid time, learned time, Account types, or private household values.

It also does not claim that occurrence-root cuts are sufficient for every future historical query. It only tests the smallest evidence exposed by the present dogfood mismatch.

## Tool choice

Lean is sufficient because the question is a finite correction-path and exact-quantity composition question over already-qualified production structures. No new concurrent or temporal protocol is claimed, so TLA+ is not earned yet.

## Practical Core impact

None.
