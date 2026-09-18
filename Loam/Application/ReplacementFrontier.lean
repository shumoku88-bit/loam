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

Production originally used a bounded whole-domain start-return traversal. That
algorithm was semantically sound, but repeated a known suffix from every
represented source. Observation 273 isolated that repeated-work pressure and
showed a list-only global-done traversal can reuse already-qualified suffixes
without adding a `Hashable` requirement.

Observation 274 then proved the general promotion obligation: for every finite
replacement relation admitted by `endpointUnique`, the fuel-bounded global-done
decision is exactly the bounded start-return decision. The proof reuses the
finite partial-injection argument historically qualified by Observation 218.

Current production therefore uses global-done after endpoint uniqueness is
known. The public standalone `acyclic` function retains the old start-return
fallback when endpoint uniqueness itself is false, preserving its historical
executable answer outside the qualified replacement domain. Ordinary
`structurallyAdmissible` rejects that malformed shape before cycle admission
and does not pay for the fallback.

The complete frontier remains intentionally list-based; this change removes the
repeated suffix walk rather than claiming every admission facet is linear.

Do not generalize this helper merely to absorb relation shapes that violate the
retained replacement premises. In particular, revision models with explicit
retraction or multi-parent structure require their own semantics.
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

/-! Historical bounded start-return baseline, retained only as malformed fallback. -/

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

private def acyclicStartReturn {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  !(edges.any fun edge =>
    returnsToStartWithin edges edge.source edges.length edge.source)

/-! Qualified global-done traversal. -/

private def memoWalk {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) :
    Nat → Id → List Id → Option (List Id)
  | 0, _, _ => none
  | fuel + 1, current, done =>
      if current ∈ done then
        some done
      else
        match next? edges current with
        | none => some (current :: done)
        | some next =>
            match memoWalk edges fuel next done with
            | none => none
            | some done' => some (current :: done')

private def memoScan {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id))
    (fuel : Nat) :
    List Id → List Id → Option (List Id)
  | [], done => some done
  | source :: rest, done =>
      if source ∈ done then
        memoScan edges fuel rest done
      else
        match memoWalk edges fuel source done with
        | none => none
        | some done' => memoScan edges fuel rest done'

private def acyclicGlobalDone {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  (memoScan
    edges
    (edges.length + 1)
    (edges.map Edge.source)
    []).isSome

/--
No represented source participates in a replacement cycle.

For the admitted one-to-one replacement domain this uses the Observation 274
qualified global-done traversal. A standalone call on a non-unique edge relation
falls back to the historical bounded start-return decision, so this public helper
does not silently broaden its semantics outside the replacement contract.
-/
def acyclic {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) : Bool :=
  if endpointUnique edges then
    acyclicGlobalDone edges
  else
    acyclicStartReturn edges

def structurallyAdmissible {Id : Type} [DecidableEq Id]
    (present : Id → Bool) (edges : List (Edge Id)) : Bool :=
  endpointUnique edges &&
    referencesClosed present edges &&
    acyclicGlobalDone edges

/-- A singleton self-loop is always a cycle, regardless of endpoint presence. -/
@[simp] theorem structurallyAdmissible_singleton_self
    {Id : Type} [DecidableEq Id]
    (present : Id → Bool) (id : Id) :
    structurallyAdmissible present [{ source := id, successor := id }] = false := by
  simp [structurallyAdmissible, endpointUnique, referencesClosed,
    acyclicGlobalDone, memoScan, memoWalk, next?]

def isSuperseded {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) (id : Id) : Bool :=
  edges.any fun edge => decide (edge.source = id)

/-- Keep exactly the retained items outside the supersession domain. -/
def frontier {Id Item : Type} [DecidableEq Id]
    (idOf : Item → Id) (items : List Item) (edges : List (Edge Id)) : List Item :=
  items.filter fun item => !(isSuperseded edges (idOf item))

end Loam.Application.ReplacementFrontier
