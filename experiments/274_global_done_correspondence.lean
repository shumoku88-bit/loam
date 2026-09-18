import experiments.cslib_semantic_correspondence_002
import Lean.Elab.Tactic.Omega

namespace Loam.Experiments.Observation274GlobalDoneCorrespondence

set_option autoImplicit false

open Loam.Application.ReplacementFrontier
open Loam.Experiments.CSLibSemanticCorrespondence002

/-!
# Observation 274 — global-done replacement correspondence

Observation 273 established a concrete traversal-cost improvement for a
list-only global-done cycle detector. This experiment asks the promotion
question: can the optimized detector be related to the same standard
`Relation.TransGen` acyclicity semantics already used by CSA-002?

The proof stays outside production until the general correspondence is closed.
-/

#check shadowAcyclic_iff_standardAcyclic_of_rightUnique

end Loam.Experiments.Observation274GlobalDoneCorrespondence
