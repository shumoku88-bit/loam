import Loam.Core.FiniteKeyed
import Loam.Application.RelationDischargeFrontier
import Loam.Application.OpenRelationFrontier
import Loam.Persistence.VersionedRows
import Loam.ScheduledOccurrenceConstruction
import Loam.Observations.Observation043
import Loam.Observations.Observation044

/-!
# Durable Lean proof surface

This module owns no new semantics and proves no new theorem.

It is the intentionally small CI selection surface for Lean results that are
expected to remain long-lived evidence rather than observation-local executable
witnesses.

Selection currently requires one of these reasons:

* direct correspondence between a production acceleration and canonical
  semantics;
* a shared persistence law retained after a proof-first migration;
* a production simplification whose removed runtime decision is justified by a
  retained theorem;
* an unbounded theorem or counterexample that permanently qualifies the scope of
  a bounded formal-method result.

The broader `Loam.Observations` umbrella remains a live research-regression
surface and may contain `native_decide` witnesses. It is deliberately not
treated as this kernel-oriented durable surface.
-/
