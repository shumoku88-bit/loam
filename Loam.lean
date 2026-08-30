import Loam.Core
import Loam.Observations

/-!
# LOAM Lean umbrella

`Loam.Core` is the practical implementation entry point.
`Loam.Observations` preserves the historical proof suite.

Keeping both here retains the existing full `lake build` qualification while
allowing practical code to depend only on the core.
-/
