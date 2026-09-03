# Observation 145 — Can a destructive authority cut avoid every mixed readable false answer?

## Question

Observation 129 qualified auxiliary-first publication when every candidate relation referred to a fresh `EventId`. Before `EventMemory` publication those facts were inert.

The historical Actual authority cut is stronger. It replaces existing `EventMemory`, `ActualValidity`, and `QuantityBasis` images, adds descriptions and a source snapshot, and retires two old relation files:

```text
Old: E0 / V0 / absent-D / B0 / C0 / K0 / absent-S
New: E1 / V1 / D1       / B1 / absent-C / absent-K / S1
```

Here `absent-C` and `absent-K` mean physical **ABSENT**, not an encoded empty file. Persistence readers may project a missing optional relation as an empty relation, but restart verification must retain the physical distinction.

The question is therefore:

> Can the replacement be ordered so a crash may make an answer unavailable, but can never make a mixed generation return a plausible wrong answer?

## Boundary and tool choice

This is a one-time protocol model, not a publisher implementation.

Lean 4 is sufficient because the publication sequence is fixed and finite, while the important refusals must be checked against existing production functions. Unlike Observation 129, no scheduler or concurrent-writer interleaving is being introduced: the future operation will hold the existing `Loam.WriterOwnership.withOwnership` lock for its complete lifetime. TLA+ would duplicate the finite phase enumeration without adding a distinct answer.

No production type, persistence function, CLI, lock, transaction layer, or canonical file changes in this observation.

## Negative result: old relation retirement is not inert

`early_retirement_not_inert` uses `Loam.Application.BasisCut.inspectCurrentQuantityWithBasisCut?` directly with public synthetic data:

```text
old basis = 10
old Event = +5
K0 says the old Event is already reflected by the old basis
```

With K0, production semantics excludes the reflected Event and returns `10`. If `basis-cut.tsv` is retired while E0/B0 remain, missing-file persistence semantics supplies an empty cut and the same reader returns `15`.

Thus:

```text
retire old relation before EventMemory authority commit
    !=
inert auxiliary-first publication
```

This is not merely an availability loss. It is a changed, readable quantity answer. No private household coordinate or value appears in the specimen.

## Production fail-closed seams

### V1 with E0

`precommit_new_validity_fails_closed` calls production `consumptionAtRecorded?`. Its E0 Event has no coordinate in V1, so the monadic fold returns `none` before routing or quantity can produce an answer.

Production-reader audit:

- `ConsumptionInspection.consumptionAtRecorded?` returns `none`; `remainingAtRecorded?` propagates that `none`.
- Correction-frontier Consumption first selects an Event frontier and then delegates to the same all-Events-validity requirement.
- `ReviewCli` renders a missing coordinate as the explicit text `date unknown`; it does not substitute a V1 date or another date for E0.
- validity-aware mutation entrances are writers and are excluded while the authority-cut operation owns the existing writer lock.

No production reader was found that assigns V1 evidence to an E0 Event by position, date, or fallback identity.

### C0 with E1

`postcommit_old_correction_fails_closed` calls production `inspectQuantity`. The old correction target and replacement are both absent from E1, so the result is `missingCorrectionEndpoint`, not an effective current quantity.

The correction-aware Consumption boundary likewise requires an admitted closed correction frontier before evaluating validity. Effective/current quantity CLIs convert these refusal constructors to unavailable/error output rather than printing partial rows.

### K0 with E1/B1

`postcommit_old_cut_fails_closed` calls production `BasisCut.inspectCurrentQuantityWithBasisCut?`. A non-empty K0 must pass `BasisCut.admissible`, which requires both its Event root in E1 and its basis root in B1. Neither old root exists, so the result is `none`.

`DailyQuantityCli` collects the complete view before printing rows and converts this result to `basisCutInvalid`; it cannot print a partial mixed current view.

### D1 with E0

`EventDescriptionMemory.findText?` is keyed only by exact `EventId`. D1 has no E0 key, so it cannot attach candidate text to an old Event. The current review CLI does not consume descriptions. The snapshot is archive evidence and is not a canonical query input, as qualified by Observation 135.

## Qualified publication order

The safe sequence is:

```text
0. hold existing WriterOwnership for the entire operation

1. verify exact approved PREPARED
   - approval manifest input
   - unchanged source
   - unchanged destination base
   - candidate fingerprints

2. atomically replace individual auxiliary files, in this fixed order
   V1 ActualValidity
   D1 EventDescription
   B1 QuantityBasis
   S1 source snapshot

3. atomically replace EventMemory with E1
   - Historical Actual authority commit point

4. retire C0 corrections.loam to physical ABSENT

5. retire K0 basis-cut.tsv to physical ABSENT

6. verify the exact complete new generation and every fingerprint

7. publish Admission Receipt LAST

8. retire PREPARED

9. release writer ownership
```

Each individual present-file replacement may use the existing stage-and-rename persistence mechanism. This result does not earn a generic multi-file transaction layer.

ScheduledMemory and balance-view are byte-identical between base and candidate. A publisher should verify fingerprint equality and **not rewrite them**, avoiding unnecessary write and crash surfaces.

## Why corrections retire before BasisCut

Both post-commit orders refuse wrong answers:

- If K0 remains, its missing E1/B1 roots make the basis-cut current reader fail closed regardless of whether C0 has already retired.
- If K0 retires first, C0 still makes correction-aware readers fail closed because its endpoints are absent from E1.

The protocol fixes **C0 then K0** because K0 remains a final fail-closed guard while correction retirement occurs. Retiring K0 is then the single step that enables the complete E1/B1 current quantity. This gives the smaller availability transition and matches the modeled phases; there is no safety benefit from the reverse order.

## ReaderOutcome and reachable phases

The Lean model classifies the exact stream tuple, independently of receipt and PREPARED cleanup:

```text
oldCorrect
failClosed
newCorrect
falseReadable
```

The reachable outcomes are:

| Phase | Outcome |
|---|---|
| initial E0/V0/B0/C0/K0 | `oldCorrect` |
| V1 only | `failClosed` |
| D1, B1, or S1 partial publication after V1 | `failClosed` |
| immediately before E1 | `failClosed` |
| immediately after E1 with C0/K0 | `failClosed` |
| C0 retired, K0 retained | `failClosed` |
| C0 and K0 retired | `newCorrect` |
| final verification / Receipt / PREPARED cleanup | `newCorrect` |

`reachable_state_never_false_readable` proves the outcome is not `falseReadable` for every `PublicationPhase`. Unknown tuples are deliberately mapped to `falseReadable`; they are not silently included in the permitted set.

## Restart planner

Observation 129 Case 4 is not reused. E1 alone is only the authority commit point, not completion evidence.

The planner distinguishes:

```text
ResumePreCommitPublication
ResumePostCommitRetirement
RecoverReceiptOnly
CleanupLeftoverPrepared
Complete
FailClosedInconsistent
```

The crash cases qualify as follows:

1. before publication: `ResumePreCommitPublication`
2. after V1: `ResumePreCommitPublication`
3. during D1/B1/S1 publication: `ResumePreCommitPublication`
4. immediately before E1: `ResumePreCommitPublication`
5. immediately after E1: `ResumePostCommitRetirement`
6. after C0 retirement: `ResumePostCommitRetirement`
7. after C0 and K0 retirement, before verification: `ResumePostCommitRetirement`
8. after exact final verification, before Receipt: `RecoverReceiptOnly`
9. after Receipt, before PREPARED cleanup: `CleanupLeftoverPrepared`
10. any unknown/mixed shape: `FailClosedInconsistent`

`RecoverReceiptOnly` requires all of E1/V1/D1/B1/ABSENT-C/ABSENT-K/S1 plus successful final verification. `postcommit_restart_resumes_retirement` specifically proves that the immediate post-E1 state is not receipt-only recovery.

A present Receipt with a non-final or unverified state is also inconsistent. `receipt_requires_full_new_generation` proves that every protocol-reachable Receipt state has the full verified new generation and both old relation streams physically absent.

## Lean laws

`Loam/Observations/Observation145.lean` proves:

1. `early_retirement_not_inert`
2. `precommit_candidate_state_never_false_readable`
3. `postcommit_old_correction_fails_closed`
4. `postcommit_old_cut_fails_closed`
5. `final_generation_correct`
6. `postcommit_restart_resumes_retirement`
7. `receipt_requires_full_new_generation`
8. `unknown_mixed_state_fails_closed`

It additionally proves the production validity refusal, all requested crash plans, and no `falseReadable` outcome across every reachable phase.

## Qualification

```text
Production additions:       0
Actual source writes:       0
Actual destination writes:  0
Publisher implementation:   deferred
New lock/transaction layer: 0
PREPARED approval value:    not embedded in code or docs
```

The existing sealed real PREPARED remains an untouched rehearsal artifact. Its approval value is not authority-transfer approval and is not copied into this public observation.
