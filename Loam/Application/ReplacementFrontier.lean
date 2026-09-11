namespace Loam.Application.ReplacementFrontier

set_option autoImplicit false

/-!
# Replacement-frontier structural mechanics

This module owns only the finite one-to-one supersession mechanics shared by
several independently meaningful household domains. Domain meaning stays in the
adapters; the common structure is a finite partial successor map with unique
sources/successors, closed represented endpoints, cycle refusal, and frontier
filtering outside the source domain.

## Cycle-detector rationale

Current production uses the bounded start-return detector in `acyclic`. Earlier
production families used both a seen-set traversal and a start-return traversal.
Observation 218 established an important qualification boundary: those two
algorithms are not path-locally equivalent on arbitrary deterministic graphs,
but their whole-domain admission decisions coincide for the finite partial-
injective maps admitted here. Injectivity matters; it is supplied by
`endpointUnique` together with the finite represented edge set.

That result justified standardizing current production on one small
start-return implementation rather than maintaining two cycle engines. The
large theorem-heavy migration proof is historical evidence, not a second live
runtime contract. Exact proof source remains recoverable in Git history.

Do not generalize this helper merely to absorb relation shapes that violate
these premises. In particular, revision models with explicit retraction or
non-injective/multi-parent structure require their own semantics.
-/

/-- One generic supersession edge. Domain meaning stays in the adapter. -/
structure Edge (Id : Type) where
  source : Id
  successor : Id

def endpointUnique {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  decide ((edges.map Edge.source).Nodup ∧ (edges.map Edge.successor).Nodup)

def referencesClosed {Id : Type}
    (present : Id → Bool) (edges : List (Edge Id)) : Bool :=
  edges.all fun edge => present edge.source && present edge.successor

private def next? {Id : Type} [DecidableEq Id] :
    List (Edge Id) → Id → Option Id
  | [], _ => none
  | edge :: rest, id =>
      if edge.source = id then some edge.successor else next? rest id

private def returnsToStartWithin {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (start : Id) : Nat → Id → Bool
  | 0, _ => false
  | fuel + 1, current =>
      match next? edges current with
      | none => false
      | some next =>
          if next = start then true
          else returnsToStartWithin edges start fuel next

/-- No represented source returns to itself within the finite edge-count bound. -/
def acyclic {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  !(edges.any fun edge =>
    returnsToStartWithin edges edge.source edges.length edge.source)

def structurallyAdmissible {Id : Type} [DecidableEq Id]
    (present : Id → Bool) (edges : List (Edge Id)) : Bool :=
  endpointUnique edges && referencesClosed present edges && acyclic edges

/-- A singleton self-loop is always a cycle, regardless of endpoint presence. -/
@[simp] theorem structurallyAdmissible_singleton_self
    {Id : Type} [DecidableEq Id]
    (present : Id → Bool) (id : Id) :
    structurallyAdmissible present [{ source := id, successor := id }] = false := by
  simp [structurallyAdmissible, endpointUnique, referencesClosed, acyclic,
    returnsToStartWithin, next?]

/-- One distinct closed edge is a valid finite replacement frontier. -/
@[simp] theorem structurallyAdmissible_singleton_distinct
    {Id : Type} [DecidableEq Id]
    (present : Id → Bool)
    (source successor : Id)
    (hSource : present source = true)
    (hSuccessor : present successor = true)
    (hDistinct : source ≠ successor) :
    structurallyAdmissible present [{ source := source, successor := successor }] = true := by
  have hReverse : successor ≠ source := Ne.symm hDistinct
  simp [structurallyAdmissible, endpointUnique, referencesClosed, acyclic,
    returnsToStartWithin, next?, hSource, hSuccessor, hReverse]

def isSuperseded {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) (id : Id) : Bool :=
  edges.any fun edge => decide (edge.source = id)

/-- Keep exactly the retained items outside the supersession domain. -/
def frontier {Id Item : Type} [DecidableEq Id]
    (idOf : Item → Id) (items : List Item) (edges : List (Edge Id)) : List Item :=
  items.filter fun item => !(isSuperseded edges (idOf item))

end Loam.Application.ReplacementFrontier
