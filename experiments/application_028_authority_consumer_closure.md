# Application 028 — Authority consumer closure

## Question

Application 027 found that the smallest safe sidecar -> manifest deployment boundary is a quiescent single-version cut. That leaves one practical question before production migration can be judged:

> How many executable entry points actually need to become manifest-aware in the new steady-state epoch, and how many can simply be quiesced or retired at cutover?

This application observes the executable and CLI dependency closure. It does not redesign persistence again.

## Freshness and stack

The observation is stacked on Application 027 / PR #405 head `4eff99190bd3779c42edca2d4a09ecb22b7e3229`.

At observation start actual `main` is `4f60ea18f3b1e69cb52c94511e796d53a5d16cf2`.

Application 027 is open and mergeable with exact-head push and pull-request workflows successful.

## Existing role boundary

Application 017 already separated CLI source by steady-state role. Application 028 applies that boundary to the current declared executables instead of counting every repository tool as a migration blocker.

The current `lakefile.lean` declares fourteen executables:

```text
primary practical               5
secondary steady-state          3
shadow / research               4
one-time historical             2
                               --
total                           14
```

The ordinary `tools/loam` menu independently fixes the same five primary practical binaries:

```text
loam
loamMovement
loamCapacity
loamDailyQuantity
loamOpenScheduled
```

## Probe

`application_028_authority_consumer_closure.py` parses the executable roots from `lakefile.lean`, follows local Lean imports transitively, and inspects only CLI-layer call sites for persistence loads and saves.

This matters because merely importing a persistence implementation does not make an executable a writer. For example, `loamJournalExport` reads canonical evidence but writes only a derived non-authoritative journal.

## Qualified result

The exact-head source probe reports:

```text
Application 028 authority consumer closure PASS
declared_executables=14
primary_practical_executables=5
secondary_steady_state_executables=3
nonsteady_executables=6
steady_state_executables=8
steady_state_authority_consumers=8
steady_state_authority_writers=6
steady_state_read_only_consumers=2
quiesce_or_retire_at_cutover=6

unique_steady_state_cli_modules=17
direct_persistence_consumer_cli_modules=17
direct_persistence_writer_cli_modules=10
direct_persistence_read_only_cli_modules=7
steady_state_persistence_modules=14
```

So the executable deployment frontier is exactly:

```text
8 retained steady-state roots
  6 writer-capable
  2 read-only

6 non-steady-state roots
  quiesce or retire at the epoch cut
```

The retained writer-capable roots are:

```text
loam
loamMovement
loamCapacity
loamDailyQuantity
loamOpenScheduled
loamActualRouting
```

The retained read-only canonical consumers are:

```text
loamBudgetWindow
loamJournalExport
```

The source-level implementation surface is broader than the eight executable roots. The eight retained roots close over seventeen CLI modules, and all seventeen directly call persistence. Ten are writer call-site modules and seven are read-only call-site modules:

```text
writer call-site modules
  Loam/Cli.lean
  Loam/Cli/ActualRoutingCli.lean
  Loam/Cli/ActualValidityCorrectionCli.lean
  Loam/Cli/CapacityCli.lean
  Loam/Cli/CorrectionCli.lean
  Loam/Cli/DailyQuantityCli.lean
  Loam/Cli/MovementCli.lean
  Loam/Cli/QuantityBasisCorrectionCli.lean
  Loam/Cli/ScheduledCli.lean
  Loam/Cli/ScheduledLifecycleCli.lean

read-only call-site modules
  Loam/Cli/BudgetWindowCli.lean
  Loam/Cli/CorrectionIntegrityCli.lean
  Loam/Cli/EffectiveCli.lean
  Loam/Cli/JournalExportCli.lean
  Loam/Cli/OpenScheduledCli.lean
  Loam/Cli/ReviewCli.lean
  Loam/Cli/ScheduledBalanceCli.lean
```

The retained closure reaches fourteen persistence implementation modules.

## Main finding

The top-level compatibility problem is smaller than the repository suggests: only eight of fourteen declared executables must survive into the new steady-state authority epoch if the existing primary/secondary product boundary is retained. The other six do not justify permanent dual-version compatibility merely by existing in the repository.

But the opposite reassuring story is also false. Manifest-awareness cannot be implemented honestly by changing eight `main` functions. Every CLI module in the retained steady-state closure currently talks directly to persistence, so the physical authority seam is distributed across seventeen CLI modules.

That distribution is useful pressure rather than a reason to abandon the manifest topology. Applications 020-027 already showed that the new physical authority law is shared:

```text
capture/select one generation
  -> typed family reads

prepare changed immutable family images
  -> one authority selection change
```

Application 028 therefore suggests a narrower implementation seam: centralize **physical authority access**, not household meaning. Read-only modules should not each learn manifest parsing, digest validation, fallback rules, or epoch policy. Writer modules should not each reimplement generation publication. Existing typed family decoders and semantic admission boundaries remain separate.

This is not yet permission to create a generic repository framework. A shared authority-access layer is earned only if a scratch implementation can replace the seven retained read-only persistence call-site modules' physical selection logic without erasing their distinct evidence policies.

## Interpretation boundary

A root classified `quiesce/retire` may still read old canonical data today. The classification means only that it is not required to remain live across the production epoch cut.

Likewise, a read-only executable still needs manifest-aware authority selection if it remains live after the cut. Read-only does not mean migration-neutral; Application 027 already showed that a stale sidecar reader can return a plausible but obsolete household world.

The `17` direct CLI consumers are also not seventeen semantic authorities. They are seventeen current physical call sites into independently typed evidence families. The desired compression is to share physical selection mechanics while keeping those meanings explicit.

## Smallest next gate

Before production migration, build one scratch generation-scoped read boundary and route the seven retained read-only CLI call-site shapes through it. Measure whether:

```text
7 distributed physical read selections
  -> 1 shared generation capture / validation mechanism
     + meaning-specific typed reads
```

reduces code and failure-state surface without changing any projection answer or missing-evidence policy.

Writer migration can remain a separate gate, already informed by Applications 021-024.

## Boundary

No production source, persistence format, canonical path, executable behavior, migration contract, deployment mechanism, or household data changes. This application only maps the smallest retained authority-consumer closure that a later production migration would have to cover.
