import Loam.FreshNumberedToken

namespace Loam.Experiments.CSLibSemanticCorrespondence004

set_option autoImplicit false

/-!
CSA-004 asks whether LOAM's deterministic numbered-token allocator satisfies the
semantic contract exposed by CSLib `HasFresh`: given a finite represented
namespace, return an element outside that namespace.

The contract now belongs to production `Loam.firstUnusedNumberedToken_fresh`.
This experiment remains only as the correspondence witness to the external
vocabulary; it no longer duplicates the production proof.
-/

/-- LOAM's production freshness law is exactly the HasFresh-style obligation used here. -/
theorem firstUnusedNumberedToken_fresh
    (stem : String) (used : List String) (index : Nat) :
    Loam.firstUnusedNumberedToken stem used index ∉ used :=
  Loam.firstUnusedNumberedToken_fresh stem used index

/-- A concrete sanity witness for the deterministic first-available policy. -/
example :
    Loam.firstUnusedNumberedToken
        "record-" ["record-1", "record-2", "record-4"] 1 = "record-3" := by
  native_decide

end Loam.Experiments.CSLibSemanticCorrespondence004
