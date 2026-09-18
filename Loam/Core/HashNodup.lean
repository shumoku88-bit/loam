import Std.Data.HashSet.Lemmas

namespace Loam.Core

set_option autoImplicit false

/--
Internal result used to admit list uniqueness with a hash-backed membership index.

The HashSet is only a runtime acceleration structure. The returned authority is
still the ordinary `List.Nodup` proof consumed by Core structures.
-/
private structure HashNodupBuild
    {Item Key : Type}
    [BEq Key] [Hashable Key]
    (keyOf : Item → Key)
    (items : List Item) where
  seen : Std.HashSet Key
  nodup : items.Nodup
  seen_iff : ∀ key, key ∈ seen ↔ key ∈ items.map keyOf

private def buildHashNodup?
    {Item Key : Type}
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Item → Key) :
    (items : List Item) → Option (HashNodupBuild keyOf items)
  | [] =>
      some {
        seen := {}
        nodup := by simp
        seen_iff := by intro key; simp
      }
  | item :: rest => do
      let built ← buildHashNodup? keyOf rest
      if hContains : built.seen.contains (keyOf item) then
        none
      else
        have hContainsFalse : built.seen.contains (keyOf item) = false := by
          simpa using hContains
        have hFreshSeen : keyOf item ∉ built.seen :=
          Std.HashSet.contains_eq_false_iff_not_mem.mp hContainsFalse
        have hFreshKeys : keyOf item ∉ rest.map keyOf := by
          intro hMem
          exact hFreshSeen ((built.seen_iff (keyOf item)).2 hMem)
        have hFresh : item ∉ rest := by
          intro hMem
          apply hFreshKeys
          exact List.mem_map.mpr ⟨item, hMem, rfl⟩
        some {
          seen := built.seen.insert (keyOf item)
          nodup := List.nodup_cons.mpr ⟨hFresh, built.nodup⟩
          seen_iff := by
            intro key
            rw [Std.HashSet.mem_insert]
            rw [built.seen_iff]
            simp only [List.map_cons, List.mem_cons, beq_iff_eq]
            constructor
            · intro h
              exact h.elim (fun hEq => Or.inl hEq.symm) Or.inr
            · intro h
              exact h.elim (fun hEq => Or.inl hEq.symm) Or.inr
        }

/-- Successful hash-backed duplicate admission carrying the existing proof proposition. -/
structure HashNodupWitness {Item : Type} (items : List Item) where
  marker : Unit := ()
  proof : items.Nodup

/--
Admit list uniqueness using a HashSet-backed duplicate check while returning the
same `List.Nodup` proposition used by existing Core structures.

The key projection must be injective so the accelerated check has exactly the
same acceptance boundary as direct equality on `Item`.
-/
def hashNodupBy?
    {Item Key : Type}
    [BEq Key] [Hashable Key] [LawfulBEq Key] [LawfulHashable Key]
    (keyOf : Item → Key)
    (_keyInjective : Function.Injective keyOf)
    (items : List Item) : Option (HashNodupWitness items) := do
  let built ← buildHashNodup? keyOf items
  some { proof := built.nodup }

end Loam.Core
