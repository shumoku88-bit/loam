namespace Loam.Application.ReplacementFrontier

set_option autoImplicit false

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

def isSuperseded {Id : Type} [DecidableEq Id]
    (edges : List (Edge Id)) (id : Id) : Bool :=
  edges.any fun edge => decide (edge.source = id)

/-- Keep exactly the retained items outside the supersession domain. -/
def frontier {Id Item : Type} [DecidableEq Id]
    (idOf : Item → Id) (items : List Item) (edges : List (Edge Id)) : List Item :=
  items.filter fun item => !(isSuperseded edges (idOf item))

end Loam.Application.ReplacementFrontier
