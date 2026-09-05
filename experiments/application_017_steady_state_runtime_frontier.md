# Application 017: Steady-state runtime frontier

## Pressure

Application 016 found that obvious safe helper duplication is real but too small
to explain LOAM's current runtime size. The next question is therefore not:

```text
which repeated lines can be shared?
```

It is:

```text
which production-facing source belongs to indefinite household operation,
and which source exists only for migration, research, or qualification?
```

This is a source-role observation, not a deletion proposal. An operation may be
rare and still belong to steady state. Correction, recovery, lifecycle closure,
and integrity inspection remain steady-state concerns whenever the corresponding
household situation can arise again after bootstrap.

The source snapshot is `main` at:

```text
3491a1511ed8b069d8638e76a74ebbb9fbc594e5
```

This observation is stacked after Application 016 only so its source-boundary
finding is recorded first. No private household data is read or changed.

## Three different notions of size

LOAM currently has at least three useful size questions:

1. **repository / full qualification surface** — everything retained so past
   observations, tests, migrations, and research instruments remain reproducible;
2. **steady-state practical runtime surface** — code whose meaning can still be
   required indefinitely while operating the household system;
3. **primary interactive surface** — the subset currently built and exposed by
   the ordinary `tools/loam` menu path.

These are not interchangeable.

`Loam.lean` deliberately imports `Loam.Observations` alongside Core and
Application so a full `lake build` preserves the historical proof suite, while
its own comment says practical code may depend only on the layer it actually
needs. Repository qualification size is therefore intentionally larger than a
practical runtime dependency surface.

## Primary practical CLI closure

The no-argument `tools/loam` path prepares exactly five executables:

```text
loam
loamMovement
loamCapacity
loamDailyQuantity
loamOpenScheduled
```

The same wrapper exposes the ordinary household menu around recording, review,
balances, correction, starting quantities, capacity, and Scheduled activity.

Within `Loam/Cli*` only, the direct CLI-module closure of those five executables
is:

```text
Loam/Cli.lean
Loam/Cli/MovementCli.lean
Loam/Cli/CapacityCli.lean
Loam/Cli/DailyQuantityCli.lean
Loam/Cli/OpenScheduledCli.lean
Loam/Cli/ReviewCli.lean
Loam/Cli/CorrectionCli.lean
Loam/Cli/ActualValidityCorrectionCli.lean
Loam/Cli/EffectiveCli.lean
Loam/Cli/CorrectionIntegrityCli.lean
Loam/Cli/QuantityBasisCorrectionCli.lean
Loam/Cli/ScheduledCli.lean
Loam/Cli/ScheduledLifecycleCli.lean
Loam/Cli/ScheduledBalanceCli.lean
```

Their Git blob sizes total:

```text
209,151 bytes
about 204.2 KiB
about 67.9% of the 308,002-byte Loam/Cli* source set
```

This is deliberately **not** called a complete Lean dependency closure or a
compiled binary size. It measures only the current CLI source directly enclosed
by the five primary practical executables.

The result matters because it prevents an easy but false explanation: current
CLI bulk is not mostly abandoned tooling. Most of the CLI source belongs to the
present practical path.

## Secondary steady-state practical surfaces

Three standalone executable modules are not part of the five-binary menu build,
but their meaning remains useful after bootstrap:

```text
ActualRoutingCli.lean     4,941 bytes
BudgetWindowCli.lean     10,109 bytes
JournalExportCli.lean     8,044 bytes
                         -----------
                          23,094 bytes
                          about 22.6 KiB
                          about 7.5% of Loam/Cli*
```

They are not grouped merely because they are executables.

`ActualRoutingCli` publishes retained routing evidence under writer ownership.
`BudgetWindowCli` reads canonical evidence and projects entitlement, routed
Actual consumption, and remaining quantity without storing Period or Remaining
state. `JournalExportCli` regenerates a human-readable journal from canonical
Event correction, ActualValidity, and EventDescription evidence and explicitly
marks the output as a projection rather than authority.

These are steady-state capabilities even if they are not currently first-class
menu actions. Invocation frequency is not the criterion; whether the household
meaning can recur indefinitely is.

## One-time historical admission machinery

The historical CLI pair occupies:

```text
HistoricalPrepareCli.lean   33,465 bytes
HistoricalPublishCli.lean    1,453 bytes
                            -----------
                             34,918 bytes
                             about 34.1 KiB
                             about 11.3% of Loam/Cli*
```

Their contracts are explicitly transitional. `HistoricalPrepareCli` describes
itself as the dry-run qualification boundary for **one-time Historical Actual
authority admission**. `HistoricalPublishCli` is the corresponding approved
publication entrance.

Observation 135 already separates four authorities:

```text
canonical query authority
immutable provenance archive
migration recovery aid
future semantic promotion source
```

and states that ordinary household queries observe canonical state rather than
the archive package. Observation 170 likewise calls the historical publisher
explicit one-time authority-cutover machinery rather than a permanent import
framework.

If the two historical CLI files are counted together with their top-level
`HistoricalPrepare`, `HistoricalPublisher`, and SHA-256 support modules, the
source footprint is about:

```text
96,126 bytes
about 93.9 KiB
```

That number demonstrates a meaningful transitional footprint, but it does **not**
earn deletion now. Removal would require a separate checkpoint showing that:

- canonical historical admission has actually completed for the intended data;
- retained snapshot + receipt remain sufficient for the provenance promises LOAM
  still makes;
- post-commit recovery/verification no longer requires the preparation or
  publication implementation to stay live;
- future deliberate re-admission is not a supported steady-state operation.

Application 017 therefore classifies this machinery outside steady state without
pretending that classification alone authorizes removal.

## Shadow and research adapters

The four Shadow CLI modules occupy:

```text
ShadowAuditCli.lean          5,935 bytes
ShadowDayCli.lean            7,769 bytes
ShadowQuantityCli.lean      11,684 bytes
ShadowScheduledDayCli.lean  15,451 bytes
                           -----------
                            40,839 bytes
                            about 39.9 KiB
                            about 13.3% of Loam/Cli*
```

Their source contracts are observational. The shadow scanners/adapters retain
structural or run-local evidence, and Observation 170 confirms that the
shadow/query family does not publish canonical EventMemory; run-local identities
are discarded on exit.

These tools may remain valuable research instruments. That is different from
being part of the household steady-state runtime contract. Keeping an instrument
in the repository need not make it part of the product chassis.

## Exact CLI role partition

For the current `Loam/Cli*` source set:

```text
primary practical closure       209,151 bytes   67.9%
secondary steady-state practical 23,094 bytes    7.5%
one-time historical CLI          34,918 bytes   11.3%
shadow / research CLI             40,839 bytes   13.3%
                                -----------      -----
total                            308,002 bytes  100.0%
```

Two useful cuts follow:

```text
not in the current primary menu closure
  98,851 bytes
  about 96.5 KiB
  about 32.1%

historical + shadow/research CLI only
  75,757 bytes
  about 74.0 KiB
  about 24.6%
```

So the earlier roughly-301-KiB CLI figure did overstate the **primary menu CLI
shell** by about one third. But the opposite comforting story is also false:
removing historical and shadow machinery would not make the current practical
CLI tiny. Roughly two thirds of the present CLI source is already in the primary
practical closure, before counting its non-CLI dependencies.

## Steady-state frontier produced by the observation

The source-role rule is:

```text
can this household meaning arise again indefinitely after bootstrap?
  yes -> steady-state candidate
  no  -> transitional / research candidate
```

with two guards:

```text
rare != transitional
repository-retained != runtime-required
```

Correction and recovery are rare but steady-state. A historical one-time importer
may be large and repository-retained while remaining transitional. A shadow
adapter may be worth keeping forever as an experiment without becoming runtime
authority.

## What this does and does not earn

Application 017 earns a more honest answer to the code-size question:

- the repository is intentionally larger than the steady-state runtime surface;
- roughly one quarter of current CLI source is clearly historical or shadow
  instrumentation rather than steady-state household operation;
- another small slice is secondary but genuine steady-state capability;
- most current CLI source still belongs to live practical behavior, so large
  reductions cannot be obtained merely by relabeling old tools.

It does **not** earn deletion, relocation, a new package split, a second build
system, or a generic runtime framework.

A future destructive cleanup should start only when a concrete transitional path
has satisfied its retirement conditions. Until then, source-role classification
is enough.

## Next pressure

If further compression is desired, the next informative question is inside the
roughly 204-KiB primary practical CLI closure:

```text
how much source is presentation/input,
how much is projection,
how much is admission/recovery protocol,
and which of those costs can be derived or deleted without hiding authority?
```

That would be a protocol-cost observation, not another broad inventory.

## Qualification

No additional formal instrument is needed. This observation changes no household
law, canonical fact, persistence format, writer path, executable behavior, or
private data.

Qualification consists of:

- current `lakefile.lean` executable inventory;
- current `tools/loam` primary-build and menu surface;
- exact Git blob sizes for `Loam/Cli*`;
- direct CLI import closure for the five primary executables;
- source contracts for historical and Shadow paths;
- consistency with Observation 135's archive/query-authority boundary and
  Observation 170's mutation-surface audit;
- no production deletion or refactor in this PR.
