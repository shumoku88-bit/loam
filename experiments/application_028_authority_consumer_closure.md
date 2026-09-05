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

The current `lakefile.lean` declares fourteen executables. Their retained operational roles are treated as:

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

The probe distinguishes:

- executable role;
- whether its CLI closure reads canonical persistence;
- whether its CLI closure performs canonical persistence saves;
- unique steady-state CLI modules that directly touch persistence;
- unique persistence implementation modules below the retained steady-state executable closure.

## Expected boundary

The working hypothesis is intentionally small:

```text
14 declared executable roots

8 retained steady-state roots
  = 5 primary + 3 secondary

6 non-steady-state roots
  = 4 shadow/research + 2 historical
```

If all eight retained roots consume canonical authority, those eight must either become manifest-aware or be deliberately removed from the new epoch. The six non-steady-state roots do not need compatibility machinery merely to permit production cutover; they can remain stopped until separately adapted or retired.

Within the retained eight, the current source shape is expected to distinguish six writer-capable roots from two read-only roots:

```text
writer-capable
  loam
  loamMovement
  loamCapacity
  loamDailyQuantity
  loamOpenScheduled
  loamActualRouting

read-only canonical consumers
  loamBudgetWindow
  loamJournalExport
```

This is an executable deployment classification, not a claim that manifest support should be implemented eight times. Shared persistence readers/writers remain the preferred implementation seam when semantic authority stays explicit.

## Interpretation boundary

A root that is classified `quiesce/retire` may still read old canonical data today. The classification means only that it is not required to remain live across the production epoch cut.

Likewise, a read-only executable still needs manifest-aware authority selection if it remains live after the cut. Read-only does not mean migration-neutral; Application 027 already showed that a stale sidecar reader can return a plausible but obsolete household world.

## Boundary

No production source, persistence format, canonical path, executable behavior, migration contract, deployment mechanism, or household data changes. This application only maps the smallest retained authority-consumer closure that a later production migration would have to cover.
