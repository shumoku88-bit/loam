import Init.Data.List.Perm

namespace Loam.Core.FiniteKeyed

set_option autoImplicit false

/-!
# Finite keyed-list mechanics

This module owns only representation mechanics shared by several semantic
memories. It does not define a generic household Memory type, retained authority,
or winner semantics.

A caller supplies the semantic key projection and its existing `Nodup` evidence.
-/

/-- Find the represented item carrying one selected key. -/
def findBy? {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key) : List Item → Key → Option Item
  | [], _ => none
  | item :: rest, key =>
      if keyOf item = key then
        some item
      else
        findBy? keyOf rest key

/--
Unique-key lookup is invariant under permutation of the represented list.

The caller supplies the semantic key and the existing uniqueness proof; this
helper assigns no chronological, causal, priority, lifecycle, or authority
meaning to list position.
-/
theorem findBy?_perm
    {Item Key : Type} [DecidableEq Key]
    (keyOf : Item → Key)
    {left right : List Item}
    (hPerm : left.Perm right)
    (hNodup : (left.map keyOf).Nodup)
    (key : Key) :
    findBy? keyOf left key = findBy? keyOf right key := by
  induction hPerm with
  | nil =>
      rfl
  | cons item hPerm ih =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      by_cases h : keyOf item = key
      · simp [findBy?, h]
      · simp [findBy?, h, ih hNodup.2]
  | swap x y rest =>
      simp only [List.map_cons, List.nodup_cons] at hNodup
      have hyx : keyOf y ≠ keyOf x := by
        intro hEqual
        apply hNodup.1
        simp [hEqual]
      by_cases hy : keyOf y = key
      · have hx : keyOf x ≠ key := by
          intro hx
          exact hyx (hy.trans hx.symm)
        simp [findBy?, hy, hx]
      · by_cases hx : keyOf x = key
        · simp [findBy?, hy, hx]
        · simp [findBy?, hy, hx]
  | trans hLeft hRight ihLeft ihRight =>
      have hMiddleNodup := (hLeft.map keyOf).nodup hNodup
      exact (ihLeft hNodup).trans (ihRight hMiddleNodup)

end Loam.Core.FiniteKeyed
