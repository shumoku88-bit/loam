import Loam.Core
import Loam.Application
import Loam.Persistence.TextEscape
import Loam.Core.ActualEvidence
import Loam.Authority.ActualAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Migration.HouseholdImageDryRun
import Loam.Migration.HouseholdImageInstall
import Loam.Persistence.NormalizedActualPersistence
import Loam.Persistence.HouseholdImagePersistence
import Loam.Application.MovementWorldAdapter
import Loam.MovementWorldLoader
import Loam.Application.PtaMigration

/-!
# LOAM Lean umbrella

`Loam.Core` is the neutral practical implementation entry point.
`Loam.Application` contains executable query-shaped operations that consume the
Core directly without growing a parallel household domain model.

This root is intentionally the **product library surface**. It does not import
the broad live research-regression umbrella. The three Lean build surfaces are:

- `Loam`: product/runtime library aggregation (`lake build` / `lake build Loam`);
- `Loam.DurableProofs`: small long-lived theorem surface with stronger checking;
- `Loam.Observations`: broader selected live research witnesses.

Durable proofs and research witnesses remain separately qualified in CI so an
ordinary product build does not acquire historical research dependencies merely
for repository-wide regression coverage. Persistence and CLI remain separate
runtime boundaries.
-/
