# Semantic audit SA-009 — Publisher / Authority / Review protocol echo

Status: **AUDIT COMPLETE — explicit protocols retained; narrow residual mechanics identified**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `e348d585518740b07510bc7f65e874f19e1baa75`

This audit asks whether the large root-level Publisher / Authority / Review
surface reflects duplicated implementation law or independently necessary
publication, recovery, and read boundaries.

The governing rule is operational rather than nominal:

```text
same types or similarly named functions do not imply one protocol;
shared crash residue, retry behavior, ownership order, and authority transition
are required before publication mechanics may be merged.
```

This audit reuses the Phase 3 M5/M9 verdict rather than reopening a generic
transaction or authority framework from scratch.

## 1. Existing negative controls remain valid

Phase 3 already rejected:

```text
NO generic transaction / Publisher<T> framework
NO generic authority / complete-image framework
NO generic missing-storage policy abstraction
```

That conclusion still matches current production.

`WriterOwnership` remains the correctly shared physical exclusion primitive.
`SiblingStage` remains the correctly shared ordinary complete-text replacement
primitive. `MovementManifestAuthority`, Scheduled lifecycle persistence,
Capacity authority, and the remaining publishers own stronger or different
protocols above those small mechanics.

## 2. Movement publication and recovery — KEEP SEPARATE

`MovementPublisher` performs:

```text
lock Movement CURRENT
-> re-read selected world
-> MovementAdmission.admit?
-> optional presentation preview
-> publish one new manifest-selected world
```

Its successful operation creates new household evidence.

`MovementRecoveryPublisher` instead performs:

```text
lock the same Movement CURRENT
-> validate one caller-selected retained recovery digest
-> switch authority to that exact retained generation
```

Recovery reconstructs no facts and runs no Movement admission. Sharing a lock
anchor does not make these one semantic operation.

Verdict: **KEEP SEPARATE**.

## 3. ActualValidity publication — KEEP SEPARATE

`ActualValidityPublisher` re-reads Movement plus EventCorrection evidence under
the Movement ownership anchor and may perform a genuine no-op when the supplied
date is already current.

When a change is required it mutates only ActualValidity evidence in a new
Movement generation and publishes that world through `publishWorld?`.

Its crash residue is therefore ordinary prepared/object residue hidden behind
Movement manifest publication; there is no separately visible relation-first
side authority.

Verdict: **KEEP SEPARATE**.

## 4. Correction publication — KEEP EXPLICIT relation-first protocol

`CorrectionPublisher` has materially different transition behavior:

```text
lock Movement CURRENT
-> re-read Movement / Correction / Reversal evidence
-> admit one replacement Event + correction relation
-> prepare Movement generation off-authority
-> publish Correction side relation first when new
-> commit prepared Movement CURRENT second
```

Interruption between the last two steps intentionally leaves a retained dangling
Correction relation whose replacement Event is still absent from selected
Movement. A retry detects that pending relation, reuses its replacement identity,
and completes the Movement publication. Competing pending relations are refused;
no last-write-wins rule exists.

That resumable residue is independent semantic/recovery behavior and must remain
visible in this publisher.

Verdict: **KEEP EXPLICIT**. A generic publisher callback skeleton would hide the
very transition law that makes retry safe.

## 5. Actual Reversal — KEEP EXPLICIT relation-first protocol

`ActualReversalPublisher` also publishes relation-first, but it is not the same
operation as Correction.

It additionally owns Scheduled lifecycle before Movement CURRENT, verifies that
the target is independent of Scheduled completion / relation-discharge meaning,
constructs an exact inverse Event, and uses deterministic reversal Event identity.

Its retained dangling reversal relation is inert until the inverse Event appears,
and retry reuses that exact relation. Reversal preserves both physical Events;
Correction changes the interpretation frontier.

Verdict: **KEEP EXPLICIT**. Similar relation-first topology does not erase the
different admission and semantic residue.

## 6. Scheduled operations — KEEP operation authority boundaries

The Scheduled publishers share one lifecycle image but have different transition
laws:

- Creation adds one independent occurrence and no terminal relation.
- Replacement adds a successor occurrence and one Scheduled -> Scheduled terminal
  relation in the same lifecycle image, then checks the source closes and the
  successor becomes current-open.
- Completion publishes a Scheduled -> Actual terminal relation first and Movement
  Event second. The retained relation is inert if interrupted and can be resumed.
- Cancellation publishes only retirement meaning and explicitly refuses an
  interrupted completion rather than competing with it.

PR #730 already removed the strongest safe Creation/Replacement implementation
echo by sharing only fresh occurrence construction. No evidence now supports
merging the publishers themselves.

Verdict: **KEEP operation-specific publishers**.

## 7. Capacity publication — KEEP authority protocol, inspect internal duplicate tail

Capacity has its own two-family fail-closed topology:

```text
CapacityEffective first
-> CapacityMovement second
```

If the second write fails, the effective entry is inert because the named
movement does not exist; later writes reject incomplete evidence and require
explicit recovery.

Both binary `publish` and multi-coordinate `publishBalanced` currently repeat a
large portion of this same protocol:

```text
load Capacity authority image
require effective evidence completeness
allocate fresh CapacityMovementId
construct / append movement
append CapacityEffective
save effective first
save movements second
```

However their preconditions are not yet proven observationally equivalent after
normalizing a binary Draft into a BalancedDraft. In particular, token validation,
source-entitlement refusal, and operation-specific error surfaces must be checked
before any factoring.

Verdict: **KEEP protocol; PROOF-FIRST INTERNAL FACTOR candidate**. Do not route one
public entrance through the other until accepted/refused worlds are proven the
same or intentionally changed.

## 8. Authority modules — KEEP local topology boundaries

The current Authority modules do not form one repository abstraction.

`MovementManifestAuthority` owns content-addressed immutable family objects plus
one `CURRENT` manifest switch and recovery generations.

`CapacityAuthority` hides the current physical pairing of CapacityMovement and
CapacityEffective behind one path handle, while retaining separate semantic
families and both optional/required load contracts.

`LocusAdmissionAuthority` hides one policy value currently embedded in the
Movement world and performs a policy-local read/modify/write under Movement
ownership.

These are different reasons for an Authority boundary: atomic world selection,
physical companion hiding, and policy-placement hiding.

Verdict: **KEEP local authorities; NO generic Authority<T>**.

## 9. Review modules — KEEP household question boundaries

The current Review surface is broad because it answers different household
questions and composes different evidence sets:

```text
ActualReview
BalanceReview
CapacityReview
ScheduledReview
AttentionReview
ActualRoutingReview
BudgetWindowReview
CurrentCoverageReview
StockFlowReview
TransactionsFlowReview
ConditionalBalancePathReview
CycleBudgetReview
```

Several Reviews re-read common evidence, but they do not independently re-invent
one shared semantic engine. Their derived laws live primarily in Application or
other lower review boundaries, while Review owns evidence loading, one coherent
snapshot, and surface-neutral answer vocabulary.

A generic Review loader would immediately need configurable required/optional
sources, different missing-storage meanings, distinct refusal wording, and
question-specific projection callbacks. That would recreate the rejected generic
repository/transaction shape on the read side.

Verdict: **KEEP Review boundaries**. Share only a family-specific loader when all
consumers already assign that family the same absence/admission meaning.

## 10. Residual candidate A — EventCorrection absent-as-empty loading

One concrete mechanical echo survives across Publishers, Reviews, and CLI
adapters.

Current production repeatedly implements:

```text
if correction file exists
  decode EventCorrectionMemory
else
  return explicit empty EventCorrectionMemory
```

This is visible in at least:

- `CorrectionPublisher`;
- `ActualValidityPublisher`;
- `ActualReversalPublisher`;
- `BalanceReview`;
- `BudgetWindowReview`;
- `CurrentCoverageReview`;
- ActualReview / several CLI read adapters.

This does **not** justify generic `loadOrEmpty` policy. It is one already-selected
EventCorrection-family contract: absence of the optional Correction side stream
means there is no retained correction evidence yet, while malformed existing
bytes still fail closed.

The narrow candidate is therefore:

```text
Persistence.loadEventCorrectionMemoryOrEmpty?
  missing   -> some explicit empty memory
  valid     -> some decoded memory
  malformed -> none
```

Boundary-specific error strings remain local. The raw
`loadEventCorrectionMemory?` remains available and unchanged for callers that
know a file must exist.

Verdict: **IMPLEMENTATION_READY mechanical candidate**, provided exact tests lock
the three outcomes above and final consumer/source delta is net-negative.

This is a persistence-family helper, not publisher protocol unification. Lean or
TLA+ is unnecessary because no semantic state transition is being changed; a
focused persistence regression plus exact-head consumer CI is the smaller
instrument.

## 11. Residual candidate B — Capacity binary/balanced publication tail

The duplicated Capacity publication tail is a plausible later compression, but
it is not yet implementation-ready.

Formal/regression gate:

1. characterize `Draft.toBalancedDraft` accepted worlds;
2. prove or counterexample-search binary `canMoveCapacityFrom` refusal against
   the BalancedDraft per-Purpose non-negative check;
3. compare Purpose-token validation;
4. preserve binary vs balanced public error wording where it has product value;
5. keep effective-first crash residue and recovery behavior unchanged.

Use Lean for pure admission/arithmetic equivalence, and transition reasoning only
if factoring would alter write order or failure points.

Verdict: **UNDER_REVIEW / PROOF-FIRST** after candidate A.

## 12. Rejected consolidation

Current evidence rejects:

```text
NO universal Publisher<T>
NO generic transaction callback framework
NO generic Authority<T>
NO generic Review<T>
NO generic missing-storage policy
NO merging relation-first Correction and Reversal protocols
NO merging Scheduled completion/replacement/creation/cancellation operations
NO treating shared WriterOwnership as evidence of shared semantic transaction
```

## 13. SA-009 verdict

SA-009 is **AUDIT COMPLETE** at the broad protocol level.

The large Publisher / Authority / Review surface is not one hidden generic
architecture waiting to be extracted. The important protocol distinctions are
real and are mostly driven by different crash residue, retry admission,
ownership order, atomicity set, and household question.

The remaining compression work is deliberately smaller:

```text
A. share EventCorrection absent-as-empty family loading
B. then proof-check the duplicated Capacity publication tail
```

If A stops being net-negative after consumer adapters, record `KEEP` and move on.
If B cannot establish admission equivalence without changing public behavior,
record `KEEP` rather than introducing a more general publisher abstraction.
