# CSLib Semantic Correspondence Audit 001

Status: **SHADOW PROBE — NO CSLib DEPENDENCY**

Baseline LOAM main: `79e301ca27e36d700fbfae43be77004a0818058d`

## Question

Can CSLib 0.1.0 serve as an external semantic coordinate system for LOAM's
existing generic mathematics without forcing LOAM to adopt CSLib as architecture
or dependency?

This first probe targets:

```text
Loam.Application.ReplacementFrontier.acyclic
```

and CSLib's standard relation-level acyclicity meaning.

## External semantic coordinate

CSLib 0.1.0 defines relation acyclicity as irreflexivity of the transitive
closure of a binary relation:

```text
Acyclic(r) := Irrefl(TransGen(r))
```

Lean 4 itself already provides `Relation.TransGen` and `Std.Irrefl`. The probe
therefore uses that exact semantic right-hand side without importing CSLib or
Mathlib.

The edge list is observed as the ordinary binary relation:

```text
edgeRel edges source successor
    iff
some retained Edge has exactly that source and successor
```

No production type or persistence format changes.

## Result 1 — straightforward admitted shapes agree

For a finite path:

```text
0 -> 1 -> 2
```

both views are acyclic. The shadow Lean proof derives strict `Nat` increase for
each represented edge and lifts it through `Relation.TransGen`.

For a singleton self-loop:

```text
0 -> 0
```

both views reject the graph.

This confirms that the CSLib vocabulary is describing the intended mathematical
property rather than merely sharing a name.

## Result 2 — unconditional equivalence is false

The probe deliberately tests an edge list outside production admission:

```text
0 -> 1
0 -> 0
```

The represented binary relation contains a self-loop, so the standard
`Irrefl(TransGen(edgeRel))` property is false.

`ReplacementFrontier.acyclic`, however, follows the first matching successor for
a source. It therefore follows `0 -> 1`, reaches no successor for `1`, and returns
`true` for this malformed duplicate-source list.

This is not a production bug because:

```text
endpointUnique duplicateSourceBlindSpot = false
```

and `structurallyAdmissible` requires endpoint uniqueness before admitting the
shape.

The counterexample is useful because it exposes an assumption that would be easy
to lose in a vocabulary-only comparison.

## Correspondence classification

| LOAM concept | Standard / CSLib concept | Classification |
| --- | --- | --- |
| `Edge` list | finite representation of a binary relation | REFINEMENT |
| `acyclic : List Edge -> Bool` | `Irrefl (TransGen r)` | REFINEMENT |
| arbitrary-edge unconditional equivalence | standard acyclicity | FALSE |
| admitted finite partial-map equivalence | standard acyclicity | OPEN / STRONG CANDIDATE |
| `endpointUnique` | functional + injective finite relation shape | LOAM EXECUTABLE PREMISE |

## Candidate theorem

The production-aligned next theorem is:

```text
endpointUnique edges = true
  ->
(ReplacementFrontier.acyclic edges = true
  <->
 Std.Irrefl (Relation.TransGen (edgeRel edges)))
```

The probe intentionally does not yet claim that successor uniqueness is minimal.
A narrower theorem may need only source uniqueness because the executable
`next?` requires the represented relation to be functional, while injectivity is
used by the broader replacement-frontier admission shape for independent reasons.

That distinction should be proved rather than guessed.

## Architectural verdict

**KEEP CSLib AS AN EXTERNAL SEMANTIC COORDINATE, NOT AS LOAM ARCHITECTURE.**

This probe adds no CSLib dependency and no new production vocabulary. Its value
is diagnostic:

- a standard definition gives a precise target meaning;
- comparison exposes hidden premises in the executable representation;
- LOAM domain adapters remain responsible for independently meaningful household
  laws;
- only a correspondence theorem, if earned, should connect the two views.

The result follows the existing LOAM rule:

```text
share algebra and mechanics
preserve semantic authority
```

and mirrors Observation 218's earlier decision not to introduce a universal
graph ontology merely because several domains share finite replacement-frontier
mechanics.

## Next step

Prove or falsify the production-aligned candidate theorem generally in Lean,
starting with the weaker hypothesis question:

```text
Is source uniqueness alone sufficient for
  executable acyclic = standard relation acyclic?
```

If yes, retain that as the minimal correspondence premise. If not, identify the
smallest additional premise with a counterexample before considering any
production theorem or CSLib dependency.
