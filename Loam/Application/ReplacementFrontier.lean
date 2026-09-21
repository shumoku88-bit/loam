import Loam.Core.HashNodup
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas
import Std.Data.HashSet
import Std.Data.HashSet.Lemmas

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

/-- Successful hash-backed endpoint uniqueness proof. -/
structure EndpointUniqueWitness {Id : Type} (edges : List (Edge Id)) where
  marker : Unit := ()
  sourceNodup : (edges.map Edge.source).Nodup
  successorNodup : (edges.map Edge.successor).Nodup

/--
Admit endpoint uniqueness using hash-backed duplicate checks on sources and successors.
Returns `some witness` with formal `List.Nodup` proofs if unique, `none` otherwise.
-/
def endpointUniqueWitnessBy?
    {Id Key : Type}
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edges : List (Edge Id)) : Option (EndpointUniqueWitness edges) := do
  let srcW ← Loam.Core.hashNodupBy? keyOf keyInjective (edges.map Edge.source)
  let succW ← Loam.Core.hashNodupBy? keyOf keyInjective (edges.map Edge.successor)
  some { marker := (), sourceNodup := srcW.proof, successorNodup := succW.proof }

private def buildSuccMap {Id Key : Type} [BEq Key] [Hashable Key]
    (keyOf : Id → Key) : List (Edge Id) → Std.HashMap Key Id
  | [] => {}
  | edge :: rest => (buildSuccMap keyOf rest).insert (keyOf edge.source) edge.successor

private theorem buildSuccMap_step
    {Id Key : Type}
    [DecidableEq Id]
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edge : Edge Id)
    (rest : List (Edge Id))
    (id : Id) :
    (buildSuccMap keyOf (edge :: rest)).get? (keyOf id) =
      if edge.source = id then some edge.successor
      else (buildSuccMap keyOf rest).get? (keyOf id) := by
  simp only [buildSuccMap]
  rw [Std.HashMap.get?_insert]
  split
  · rename_i hEq
    have hKeyEq : keyOf edge.source = keyOf id := eq_of_beq hEq
    have hIdEq : edge.source = id := keyInjective hKeyEq
    simp [hIdEq]
  · rename_i hNe
    have hIdNe : ¬(edge.source = id) := by
      intro hEq
      subst hEq
      simp at hNe
    simp [hIdNe]

private theorem buildSuccMap_get?_eq_next?
    {Id Key : Type}
    [DecidableEq Id]
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edges : List (Edge Id))
    (id : Id) :
    (buildSuccMap keyOf edges).get? (keyOf id) = next? edges id := by
  induction edges with
  | nil => simp [buildSuccMap, next?]
  | cons edge rest ih =>
      rw [buildSuccMap_step keyOf keyInjective edge rest id]
      simp only [next?]
      split
      · rfl
      · rw [ih]

private structure IndexedDone (Id Key : Type) [BEq Key] [Hashable Key] where
  list : List Id
  keys : Std.HashSet Key

private def emptyDone {Id Key : Type} [BEq Key] [Hashable Key] : IndexedDone Id Key :=
  { list := [], keys := {} }

private def insertDone {Id Key : Type} [BEq Key] [Hashable Key]
    (keyOf : Id → Key) (id : Id) (d : IndexedDone Id Key) : IndexedDone Id Key :=
  { list := id :: d.list, keys := d.keys.insert (keyOf id) }

private def DoneInv {Id Key : Type} [BEq Key] [Hashable Key]
    (keyOf : Id → Key) (d : IndexedDone Id Key) : Prop :=
  ∀ id, d.keys.contains (keyOf id) = true ↔ id ∈ d.list

private theorem emptyDone_inv {Id Key : Type} [BEq Key] [Hashable Key] (keyOf : Id → Key) :
    DoneInv keyOf (emptyDone (Id := Id) (Key := Key)) := by
  intro id
  simp [emptyDone, Std.HashSet.contains_empty]

private theorem insertDone_inv {Id Key : Type}
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key) (keyInjective : Function.Injective keyOf)
    (x : Id) (d : IndexedDone Id Key)
    (hInv : DoneInv keyOf d) :
    DoneInv keyOf (insertDone keyOf x d) := by
  intro id
  simp only [insertDone]
  rw [Std.HashSet.contains_insert]
  simp only [Bool.or_eq_true, beq_iff_eq]
  constructor
  · intro h
    cases h with
    | inl hEq =>
        have : x = id := keyInjective hEq
        subst this
        apply List.mem_cons_self
    | inr hMem =>
        have : id ∈ d.list := (hInv id).mp hMem
        apply List.mem_cons_of_mem x this
  · intro h
    cases h with
    | head =>
        left
        rfl
    | tail _ hTail =>
        right
        exact (hInv id).mpr hTail

private def memoWalkIndexed {Id Key : Type} [BEq Key] [Hashable Key]
    (keyOf : Id → Key)
    (succMap : Std.HashMap Key Id) :
    Nat → Id → IndexedDone Id Key → Option (IndexedDone Id Key)
  | 0, _, _ => none
  | fuel + 1, current, done =>
      if done.keys.contains (keyOf current) then
        some done
      else
        match succMap.get? (keyOf current) with
        | none => some (insertDone keyOf current done)
        | some next =>
            match memoWalkIndexed keyOf succMap fuel next done with
            | none => none
            | some done' => some (insertDone keyOf current done')

private theorem memoWalkIndexed_eq_memoWalk
    {Id Key : Type}
    [DecidableEq Id]
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edges : List (Edge Id))
    (fuel : Nat)
    (current : Id)
    (done : IndexedDone Id Key)
    (hInv : DoneInv keyOf done) :
    match memoWalkIndexed keyOf (buildSuccMap keyOf edges) fuel current done with
    | none => memoWalk edges fuel current done.list = none
    | some done' =>
        memoWalk edges fuel current done.list = some done'.list ∧ DoneInv keyOf done' := by
  induction fuel generalizing current done with
  | zero =>
      simp [memoWalkIndexed, memoWalk]
  | succ fuel ih =>
      by_cases hContains : done.keys.contains (keyOf current) = true
      · have hMem : current ∈ done.list := (hInv current).mp hContains
        simp [memoWalkIndexed, memoWalk, hContains, hMem, hInv]
      · have hNotContains : done.keys.contains (keyOf current) = false := by
          cases hC : done.keys.contains (keyOf current)
          · rfl
          · contradiction
        have hNotMem : current ∉ done.list := by
          intro hMem
          have := (hInv current).mpr hMem
          rw [this] at hNotContains
          contradiction
        have hNextEq := buildSuccMap_get?_eq_next? keyOf keyInjective edges current
        cases hNext : next? edges current with
        | none =>
            have hInv' := insertDone_inv keyOf keyInjective current done hInv
            simp only [memoWalkIndexed, memoWalk, hNotContains, hNotMem, hNext]
            change match match (buildSuccMap keyOf edges).get? (keyOf current) with
              | none => some (insertDone keyOf current done)
              | some next => _ with
              | none => _ | some done' => _
            rw [hNextEq, hNext]
            exact ⟨rfl, hInv'⟩
        | some next =>
            have ih' := ih next done hInv
            simp only [memoWalkIndexed, memoWalk, hNotContains, hNotMem, hNext]
            change match match (buildSuccMap keyOf edges).get? (keyOf current) with
              | none => _
              | some next => match memoWalkIndexed keyOf (buildSuccMap keyOf edges) fuel next done with
                | none => none
                | some done' => some (insertDone keyOf current done') with
              | none => _ | some done' => _
            rw [hNextEq, hNext]
            cases hWalk : memoWalkIndexed keyOf (buildSuccMap keyOf edges) fuel next done with
            | none =>
                simp only [hWalk] at ih'
                simp [hWalk, ih']
            | some done' =>
                simp only [hWalk] at ih'
                have hInv' := insertDone_inv keyOf keyInjective current done' ih'.2
                simp [hWalk, ih'.1, insertDone]
                exact hInv'

private def memoScanIndexed {Id Key : Type} [BEq Key] [Hashable Key]
    (keyOf : Id → Key)
    (succMap : Std.HashMap Key Id)
    (fuel : Nat) :
    List Id → IndexedDone Id Key → Option (IndexedDone Id Key)
  | [], done => some done
  | source :: rest, done =>
      if done.keys.contains (keyOf source) then
        memoScanIndexed keyOf succMap fuel rest done
      else
        match memoWalkIndexed keyOf succMap fuel source done with
        | none => none
        | some done' => memoScanIndexed keyOf succMap fuel rest done'

private theorem memoScanIndexed_eq_memoScan
    {Id Key : Type}
    [DecidableEq Id]
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edges : List (Edge Id))
    (fuel : Nat)
    (sources : List Id)
    (done : IndexedDone Id Key)
    (hInv : DoneInv keyOf done) :
    match memoScanIndexed keyOf (buildSuccMap keyOf edges) fuel sources done with
    | none => memoScan edges fuel sources done.list = none
    | some done' =>
        memoScan edges fuel sources done.list = some done'.list ∧ DoneInv keyOf done' := by
  induction sources generalizing done with
  | nil =>
      simp [memoScanIndexed, memoScan, hInv]
  | cons source rest ih =>
      by_cases hContains : done.keys.contains (keyOf source) = true
      · have hMem : source ∈ done.list := (hInv source).mp hContains
        simp [memoScanIndexed, memoScan, hContains, hMem]
        exact ih done hInv
      · have hNotContains : done.keys.contains (keyOf source) = false := by
          cases hC : done.keys.contains (keyOf source)
          · rfl
          · contradiction
        have hNotMem : source ∉ done.list := by
          intro hMem
          have := (hInv source).mpr hMem
          rw [this] at hNotContains
          contradiction
        have hWalk := memoWalkIndexed_eq_memoWalk keyOf keyInjective edges fuel source done hInv
        simp only [memoScanIndexed, memoScan, hNotContains, hNotMem]
        cases hWalkRes : memoWalkIndexed keyOf (buildSuccMap keyOf edges) fuel source done with
        | none =>
            simp only [hWalkRes] at hWalk
            simp [hWalk]
        | some done' =>
            simp only [hWalkRes] at hWalk
            simp only [hWalk.1]
            exact ih done' hWalk.2

private theorem memoScanIndexed_isSome_eq_memoScan_isSome
    {Id Key : Type}
    [DecidableEq Id]
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edges : List (Edge Id))
    (fuel : Nat)
    (sources : List Id) :
    (memoScanIndexed keyOf (buildSuccMap keyOf edges) fuel sources emptyDone).isSome =
      (memoScan edges fuel sources []).isSome := by
  have hScan := memoScanIndexed_eq_memoScan keyOf keyInjective edges fuel sources emptyDone (emptyDone_inv keyOf)
  have hEmpty : (emptyDone (Id := Id) (Key := Key)).list = [] := rfl
  rw [hEmpty] at hScan
  cases hRes : memoScanIndexed keyOf (buildSuccMap keyOf edges) fuel sources emptyDone with
  | none =>
      simp only [hRes] at hScan
      simp [Option.isSome, hScan]
  | some done' =>
      simp only [hRes] at hScan
      simp [Option.isSome, hScan.1]

/--
Indexed cycle admission for finite one-to-one replacement relations.
Accelerates endpoint uniqueness check, successor lookup, and done-set membership
via hash indexing with an injective key projection `keyOf`, while preserving exact
equivalence to `acyclic edges` for all edge relations (including malformed ones).
-/
def acyclicIndexedBy
    {Id Key : Type}
    [DecidableEq Id]
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edges : List (Edge Id)) : Bool :=
  match endpointUniqueWitnessBy? keyOf keyInjective edges with
  | some _ =>
      let succMap := buildSuccMap keyOf edges
      let sources := edges.map Edge.source
      (memoScanIndexed keyOf succMap (edges.length + 1) sources emptyDone).isSome
  | none =>
      acyclicStartReturn edges

/--
Universal semantic equivalence theorem: `acyclicIndexedBy` produces the exact same
boolean result as `acyclic` for every list of edges, both well-formed and malformed.
-/
theorem acyclicIndexedBy_eq_acyclic
    {Id Key : Type}
    [DecidableEq Id]
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Id → Key)
    (keyInjective : Function.Injective keyOf)
    (edges : List (Edge Id)) :
    acyclicIndexedBy keyOf keyInjective edges = acyclic edges := by
  simp only [acyclicIndexedBy, acyclic]
  cases hWit : endpointUniqueWitnessBy? keyOf keyInjective edges with
  | some wit =>
      have hEp : endpointUnique edges = true := by
        exact decide_eq_true ⟨wit.sourceNodup, wit.successorNodup⟩
      simp [hEp, acyclicGlobalDone]
      exact memoScanIndexed_isSome_eq_memoScan_isSome keyOf keyInjective edges (edges.length + 1) (edges.map Edge.source)
  | none =>
      have hEp : endpointUnique edges = false := by
        cases hEpBool : endpointUnique edges with
        | false => rfl
        | true =>
            have hEpTrue := of_decide_eq_true hEpBool
            obtain ⟨wSrc, hwSrc⟩ := Loam.Core.hashNodupBy?_of_nodup keyOf keyInjective (edges.map Edge.source) hEpTrue.1
            obtain ⟨wSucc, hwSucc⟩ := Loam.Core.hashNodupBy?_of_nodup keyOf keyInjective (edges.map Edge.successor) hEpTrue.2
            have hSome : endpointUniqueWitnessBy? keyOf keyInjective edges = some { marker := (), sourceNodup := wSrc.proof, successorNodup := wSucc.proof } := by
              simp [endpointUniqueWitnessBy?, hwSrc, hwSucc]
            rw [hSome] at hWit
            contradiction
      simp [hEp]


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
