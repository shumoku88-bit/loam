import Loam.Core
import Loam.Persistence
import Loam.Observations

/-!
# LOAM Lean umbrella

`Loam.Core` is the practical domain-core entry point.
`Loam.Persistence` is the runtime persistence boundary.
`Loam.Observations` preserves the historical proof suite.

Keeping all three here retains the existing full `lake build` qualification
without making persistence part of the domain core.
-/
