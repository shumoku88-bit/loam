# Application 029 — Generation-scoped physical read boundary

## Question

Application 028 found seven retained steady-state CLI modules whose role is read-only at the canonical persistence boundary. This application asks:

> Can those seven read shapes share one generation capture / object-resolution mechanism while preserving each caller's own missing-evidence and projection policy?

The target is not a generic repository framework. Only physical authority selection is shared.

## Freshness and stack

This observation is stacked on Application 028 / PR #406 head `c42fddab413b8f976acf1f9731ce96e135c3dbc2`.

At observation start actual `main` is `2954ed1cb83e569f81bec5023cf619eec6bb0df1` (`experiment: separate spending description from decision role (#407)`), unrelated to the publication stack.

Application 028 is open and mergeable, with exact-head Application 028 workflows successful.

## Current read-only call-site closure

The seven modules are:

```text
Loam/Cli/BudgetWindowCli.lean
Loam/Cli/CorrectionIntegrityCli.lean
Loam/Cli/EffectiveCli.lean
Loam/Cli/JournalExportCli.lean
Loam/Cli/OpenScheduledCli.lean
Loam/Cli/ReviewCli.lean
Loam/Cli/ScheduledBalanceCli.lean
```

The exact source probe finds across those seven modules:

```text
qualified Loam.Persistence.load...? calls   26
pathExists policy checks                    16
```

These are call-site counts, not source-size claims. They show that physical file selection and physical absence decisions are currently distributed through the read-only CLI surface.

The callers also do not assign the same meaning to physical absence. For example:

- BudgetWindow requires several families while EventCorrection is optional;
- JournalExport requires Event but treats correction, validity, and description evidence according to their existing local policies;
- Review requires Event while several adjacent evidence families may be absent/empty;
- Effective treats absent Event as an empty recorded world;
- Scheduled views treat absent Scheduled/lifecycle/Event storage as empty;
- CorrectionIntegrity can answer `no corrections` without requiring Event when correction evidence is absent.

Therefore `missing -> empty` or `missing -> error` cannot become one global storage rule without changing behavior.

## Scratch boundary

The scratch mechanism adds one operational generation snapshot:

```text
read CURRENT once
  -> parse family presence/reference metadata once
  -> hold captured manifest
  -> resolve only the families requested by this view
  -> verify each requested object's digest
  -> meaning-specific decoder/admission boundary
```

A `GenerationSnapshot` never re-reads `CURRENT`. If authority advances while a view is in progress, every family read in that view continues from the captured generation.

The scratch manifest makes physical family presence explicit with `PRESENT` or `ABSENT`. This is operational metadata, not a household fact. The reason for observing it explicitly is that the seven existing callers already distinguish physical absence in different ways; silently materializing every absent family as one generic empty object could change those caller-visible policies.

The physical reader returns presence plus verified bytes. The seven small adapters still decide which families are required and which absence means an empty local evidence set.

## Qualified result

The executable probe passes with:

```text
Application 029 generation-scoped read boundary PASS
read_only_callsite_modules=7
current_qualified_persistence_load_calls=26
current_path_exists_policy_checks=16
shared_generation_capture_mechanisms=1
shared_family_object_resolvers=1
meaning_specific_adapters=7
generation_captures_for_seven_views=7
cross_generation_mixed_reads=0
requested_corruption_fail_closed=1
unrequested_corruption_blocked_unrelated_view=0
missing_policy_cases_preserved=6
manifest_family_presence_is_explicit=1
scratch_shared_reader_lines=33
scratch_shared_reader_bytes=1162
scratch_meaning_adapter_lines=59
scratch_meaning_adapter_bytes=2029
```

The source metrics are intentionally narrow. The scratch physical reader plus seven adapters are 92 lines / 3191 bytes, but that is not compared as a replacement for the full seven production CLI modules because those modules also contain presentation and semantic projection work that must remain.

The stronger result is topological: seven callers can share one generation capture and one family-object resolver while keeping seven explicit evidence-policy adapters.

## Generation coherence

The probe captures generation G0, reads Event, atomically publishes G1 by replacing `CURRENT`, and then reads ActualValidity through the old captured snapshot. Both reads still resolve to G0. A newly captured snapshot sees G1.

So one view cannot become a plausible hybrid such as:

```text
Event from G0
ActualValidity from G1
```

merely because another writer publishes between its family reads.

## Failure locality

A selected ActualRouting object is deliberately corrupted. BudgetWindow, which requests ActualRouting, fails closed. Effective, which does not request ActualRouting, still reads its own requested families successfully.

This preserves an important property of the current sidecar readers: corruption in an unrelated evidence family does not automatically make every household view unavailable. The shared boundary therefore validates the captured manifest structure once, then validates each requested object when that family is actually read.

This is a narrower claim than saying the entire selected generation is globally healthy.

## Missing-evidence result

The empty-generation fixture makes every family explicitly absent and exercises six representative caller decisions:

```text
CorrectionIntegrity  absent corrections -> no corrections
Effective            absent Event       -> no recorded world
OpenScheduled        absent inputs      -> empty inputs
Review               absent Event       -> refusal
JournalExport         absent Event       -> refusal
BudgetWindow          absent required    -> refusal
```

All six behave according to the adapter's meaning-specific policy.

This exposes a real pressure on a future production manifest: **family absence itself may need to be represented explicitly** if migration must preserve current observable behavior. Treating every absent sidecar as a generic encoded empty family would collapse distinctions that existing callers currently make.

That does not yet select a production manifest format. It only shows that physical generation selection and semantic absence policy can be separated cleanly:

```text
shared physical layer
  tells the truth about PRESENT / ABSENT

meaning-specific caller
  decides required / empty / conditional behavior
```

## Interpretation

Application 028's distributed read surface does not require seven manifest parsers or seven digest-verification implementations. The physical part compresses naturally to one captured-generation mechanism.

At the same time, the experiment rejects a stronger generic abstraction. The shared layer does not decide that missing means empty, does not choose application projections, and does not decode every family into one universal state object. Those decisions remain with the typed family and caller that owns their meaning.

This is consistent with the existing `share mechanics without erasing meaning` rule.

## Boundary

No production source, canonical persistence path, manifest format, CLI behavior, typed decoder, household projection, migration contract, writer path, or household data changes. `PRESENT` / `ABSENT` remains a scratch pressure on the future operational manifest shape, not a production format decision.

This application also does not re-prove every Scheduled/Capacity/Correction production decoder through the scratch manifest. Application 025 already established one complete production-typed Movement round trip; a later production-facing read pilot should keep this physical boundary and add typed decoders without widening its authority.
