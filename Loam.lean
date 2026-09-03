import Loam.Core
import Loam.Application
import Loam.Observations
import Loam.Persistence.EventDescriptionPersistence

/-!
# LOAM Lean umbrella

`Loam.Core` is the neutral practical implementation entry point.
`Loam.Application` contains executable query-shaped operations that consume the
Core directly without growing a parallel household domain model.
`Loam.Observations` preserves the historical proof suite.

Keeping all three here retains the existing full `lake build` qualification
while allowing practical code to depend on only the layer it actually needs.
Persistence and CLI remain separate runtime boundaries.
-/
