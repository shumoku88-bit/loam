import Init.Data.List.Perm
import Std.Data.HashMap
import Std.Data.HashMap.Lemmas

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
Build a transient hash index for a finite keyed list.

`hashKeyOf` is representation mechanics only: it may project a semantic key such
as `EventId` onto a hashable token such as `String`. The list remains the
canonical representation and the resulting map carries no independent authority.
The recursive tail-first construction preserves the same first-match semantics
as `findBy?` when `hashKeyOf` is injective.
-/
def hashIndexBy
    {Item Key HashKey : Type}
    [BEq HashKey] [Hashable HashKey]
    (keyOf : Item → Key)
    (hashKeyOf : Key → HashKey) :
    List Item → Std.HashMap HashKey Item
  | [] => {}
  | item :: rest =>
      (hashIndexBy keyOf hashKeyOf rest).insert
        (hashKeyOf (keyOf item)) item

/--
Transient hash lookup is extensionally identical to canonical list lookup when
the hash-key projection is injective.
-/
theorem hashIndexBy_get?_eq_findBy?
    {Item Key HashKey : Type}
    [DecidableEq Key]
    [BEq HashKey] [Hashable HashKey] [LawfulBEq HashKey] [LawfulHashable HashKey]
    (keyOf : Item → Key)
    (hashKeyOf : Key → HashKey)
    (hashKeyInjective : Function.Injective hashKeyOf)
    (items : List Item)
    (key : Key) :
    (hashIndexBy keyOf hashKeyOf items).get? (hashKeyOf key) =
      findBy? keyOf items key := by
  induction items with
  | nil =>
      simp [hashIndexBy, findBy?]
  | cons item rest ih =>
      simp only [hashIndexBy, findBy?]
      rw [Std.HashMap.get?_insert]
      by_cases hKey : keyOf item = key
      · subst hKey
        simp
      · have hHash : hashKeyOf (keyOf item) ≠ hashKeyOf key := by
          intro h
          exact hKey (hashKeyInjective h)
        simpa [hHash, hKey] using ih

/--
Appending one item whose projected key is fresh preserves unique-key evidence.

This is representation mechanics only: callers still own the semantic meaning
of the key and the proof that the proposed key is fresh.
-/
theorem appendFresh_nodup
    {Item Key : Type}
    (keyOf : Item → Key)
    (items : List Item)
    (item : Item)
    (hNodup : (items.map keyOf).Nodup)
    (hFresh : keyOf item ∉ items.map keyOf) :
    ((items ++ [item]).map keyOf).Nodup := by
  rw [List.map_append]
  apply List.nodup_append.mpr
  constructor
  · exact hNodup
  constructor
  · simp
  · intro existing hExisting appended hAppended
    simp only [List.map_singleton, List.mem_singleton] at hAppended
    subst appended
    intro hEqual
    apply hFresh
    rw [← hEqual]
    exact hExisting

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
