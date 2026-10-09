import Std
import Lean.Elab.Tactic.Omega

namespace Loam.Tests.IncrementalDailyDelta

set_option autoImplicit false

/-!
A deliberately narrow delta law for an *already admitted and selected* list of
signed contributions. This is not a new Event/Correction/Actual reader.

Date, Measure, correction frontier, accounting-role selection, and unknown
evidence must have been resolved by the existing production authority first.
-/

structure Bucket where
  day : String
  measure : String
  deriving Repr, DecidableEq

structure Contribution where
  bucket : Bucket
  signedQuanta : Int
  deriving Repr, DecidableEq

/-- One signed contribution to a specific date/Measure bucket. -/
def contributionAt (bucket : Bucket) (row : Contribution) : Int :=
  if row.bucket = bucket then row.signedQuanta else 0

/-- Reference answer: recompute the bucket total from every admitted row. -/
def recompute (bucket : Bucket) (rows : List Contribution) : Int :=
  (rows.map (contributionAt bucket)).sum

/-- Optional read-side acceleration for one admitted append. -/
def afterAppend (bucket : Bucket) (oldTotal : Int) (added : Contribution) : Int :=
  oldTotal + contributionAt bucket added

/-- Replace exactly one selected row, without interpreting correction history. -/
def afterReplacement (bucket : Bucket) (oldTotal : Int)
    (removed added : Contribution) : Int :=
  oldTotal - contributionAt bucket removed + contributionAt bucket added

/-- An admitted append agrees with the independent full-list oracle. -/
theorem append_equivalence (bucket : Bucket)
    (rows : List Contribution) (added : Contribution) :
    afterAppend bucket (recompute bucket rows) added =
      recompute bucket (rows ++ [added]) := by
  simp [afterAppend, recompute, List.map_append, List.sum_append]

/--
For *any* prefix and suffix, replacing one already-selected row admits an exact
negative old contribution and positive new contribution. This includes changes
of date, Measure, sign, and quantity.
-/
theorem replacement_equivalence (bucket : Bucket)
    (beforeRows afterRows : List Contribution) (removed added : Contribution) :
    afterReplacement bucket
        (recompute bucket (beforeRows ++ removed :: afterRows)) removed added =
      recompute bucket (beforeRows ++ added :: afterRows) := by
  simp [afterReplacement, recompute, List.map_append, List.sum_append]
  omega

/-- A correction in two other buckets cannot change this bucket's total. -/
theorem unrelated_replacement (bucket : Bucket)
    (oldTotal : Int) (removed added : Contribution)
    (hRemoved : removed.bucket ≠ bucket)
    (hAdded : added.bucket ≠ bucket) :
    afterReplacement bucket oldTotal removed added = oldTotal := by
  simp [afterReplacement, contributionAt, hRemoved, hAdded]


/--
Conservative invalidation candidate for a replacement: no bucket outside
the old and new coordinates can change under the signed-delta law.
Duplicate keys are harmless (we do not claim a minimal deduplicated set).
-/
def affectedBuckets (removed added : Contribution) : List Bucket :=
  [removed.bucket, added.bucket]

theorem outside_affected_unchanged
    (bucket : Bucket) (oldTotal : Int) (removed added : Contribution)
    (hOutside : bucket ∉ affectedBuckets removed added) :
    afterReplacement bucket oldTotal removed added = oldTotal := by
  simp only [affectedBuckets, List.mem_cons, List.mem_singleton, not_or] at hOutside
  exact unrelated_replacement bucket oldTotal removed added
    hOutside.1.symm hOutside.2.symm

private def original : Contribution :=
  { bucket := { day := "2026-10-03", measure := "jpy" }, signedQuanta := 500 }

private def revised : Contribution :=
  { bucket := { day := "2026-10-05", measure := "jpy" }, signedQuanta := 800 }

example : recompute { day := "2026-10-03", measure := "jpy" } [original] = 500 := by
  decide

example :
    afterReplacement { day := "2026-10-03", measure := "jpy" }
        (recompute { day := "2026-10-03", measure := "jpy" } [original])
        original revised = 0 := by
  decide

example :
    afterReplacement { day := "2026-10-05", measure := "jpy" }
        (recompute { day := "2026-10-05", measure := "jpy" } [original])
        original revised = 800 := by
  decide

example : recompute { day := "2026-10-05", measure := "eur" } [original, revised] = 0 := by
  decide

end Loam.Tests.IncrementalDailyDelta

def main : IO Unit := pure ()
