# Semantic audit SA-007 — Application projection fanout

Status: **AUDIT VERDICT COMPLETE — implementation intentionally deferred**

Parent ledger: `docs/research/SEMANTIC_AUDIT_LEDGER.md`

Audit checkpoint: `5654a4e3919272296d1c04cd07ed9af71f461e20`

This record asks whether the current `Loam/Application` surface contains too many independently named concepts, or whether most files own genuinely different household questions while only a smaller mechanical core is duplicated beneath them.

The target is not minimum file count. Derived projections are expected in Application. The audit target is duplicated law, algorithm provenance accidentally exposed as semantics, and intermediate projections that have no independent household question.

## 1. Physical and entry-point inventory

Current `Loam/Application` contains 18 Lean modules.

`Loam/Application.lean` imports fourteen current package-facing application modules. Four sit outside that barrel for concrete reasons:

```text
CorrectionFrontier          internal domain adapter
ReplacementFrontier         internal shared graph mechanic
ScheduledBalanceInspection  specialized application capability used directly by CLI/tests
ScheduledBalanceHypothetical specialized read-only hypothetical capability used directly by CLI/tests
```

Therefore `18 modules` is not evidence of eighteen public concepts and the four barrel-external files are not dead surface by that fact alone.

## 2. Current module census

| Module | Main question / law | Information status | Audit decision |
| --- | --- | --- | --- |
| `QuantityInspection` | what correction-aware quantity can be safely exposed? | derived query | `KEEP_QUERY`, result-vocabulary compression candidate |
| `ZeroOriginQuantity` | is this quantity answer justified by explicit zero-origin coverage? | epistemic gate over derived query | `KEEP` |
| `CapacityInspection` | entitlement and current Capacity source admission | derived from Capacity evidence | `KEEP` |
| `ConsumptionInspection` | routed Actual consumption and Remaining | derived query | `KEEP_QUERY`, `SHARE_MECHANICS` candidate |
| `ActualRoutingInspection` | compose ordinary Actual validity with explicit initial-or-dated routing | typed adapter | `KEEP_WRAPPER`, `SHARE_MECHANICS` candidate |
| `CapacityWindowInspection` | temporal window selection for Capacity / Actual | derived query | `KEEP_QUERY`, contains candidate shared fold |
| `CurrentCoverageInspection` | current Entitlement / Consumption / Remaining / Commitment / Headroom composition | derived query | `KEEP_QUERY`, arithmetic-factor candidate |
| `CorrectionFrontier` | Event-correction semantic adapter over replacement-frontier mechanics | domain adapter | `KEEP_WRAPPER`; existing factoring already qualified |
| `ReplacementFrontier` | finite partial-injective replacement graph mechanics | shared mathematics | `KEEP` |
| `ActualValidityFrontier` | current validity facts from append-only validity history | domain adapter | `KEEP_WRAPPER` |
| `ScheduledInspection` | current-open Scheduled lifecycle frontier | derived lifecycle query | `KEEP` |
| `ScheduledOpenWorldInspection` | explicit due evidence vs unknown absence | epistemic query | `KEEP` |
| `ScheduledBalanceInspection` | signed Scheduled effects on selected balance coordinates | specialized derived query | `KEEP` |
| `ScheduledBalanceHypothetical` | baseline vs one typed read-only Scheduled suppression | hypothetical derived query | `KEEP` |
| `ScheduledCommitmentInspection` | current Scheduled pressure partition and Headroom composition | derived query | `KEEP`; internally well-factored |
| `AttentionInspection` | current Attention lifecycle | derived query | `KEEP` |
| `OpenRelationFrontier` | safe current relation frontier and source-local relation state | derived semantic admission | `KEEP_EXPLICIT` |
| `RelationDischargeFrontier` | activated discharge admission and outstanding quantity | derived semantic admission | `KEEP_EXPLICIT` |

No current Application module is classified as dead or semantically unjustified merely from this pass.

## 3. Prior formal evidence that must be reused

### ReplacementFrontier

PR #496 / Observation 218 already qualified one shared finite partial-injection mechanic with Lean proofs and deliberately retained domain-specific adapters.

The earlier decision was asymmetric on purpose: Event Correction reused structural admission while retaining its small domain frontier helper; ActualValidity reused structural admission plus generic frontier filtering; other families kept their own extra laws.

Therefore `CorrectionFrontier` having a small target/frontier helper is not new evidence for another graph framework. Reopen it only if a measured net simplification appears.

### OpenRelation is intentionally outside ReplacementFrontier

PR #496 explicitly excluded OpenRelation because its revision relation has:

```text
replacement : Option RelationUnitId
```

where `none` means explicit retraction, not merely missing successor data.

Observation 175 used Alloy to qualify:

```text
retraction != known-none
```

and to show that retracting one of several current relation units need not eliminate the others. The later relation promotion checkpoint preserved that distinction.

Decision: do **not** widen `ReplacementFrontier` merely to absorb OpenRelation revision mechanics.

### ScheduledCommitment already contains the right kind of proof

`ScheduledCommitmentInspection` shares selected-coordinate enumeration and pressure classification between aggregate answers and actionable rows, then proves their quantities agree.

Its large source size therefore does not currently indicate several independent engines. It is a positive example of one strong projection with internal factoring and a Lean consistency theorem.

## 4. Strong candidate A — one fail-closed Actual-consumption fold

Repository search finds the same essential fold in three Application modules:

```text
ConsumptionInspection
ActualRoutingInspection
CapacityWindowInspection
```

The invariant is:

```text
for every selected Event
  require ActualValidity for EventId
  apply an Event × validOn -> Quantity projector
  add exact quanta
if any required validity is missing
  return none
```

`CapacityWindowInspection` already contains the most general current form as its private `consumptionAtRecordedWhere?`, parameterized by:

```text
selected : Time -> Bool
project  : Event -> Time -> Quantity
```

The ordinary and initial-aware non-windowed functions are syntactic specializations of the same law with an always-selected predicate and different projectors.

### Proposed compression boundary

Share only the fail-closed fold. Keep local:

- ordinary vs `RoutingEffective` routing semantics;
- current/window predicates;
- Purpose/Measure selection;
- correction-frontier selection;
- public household function names.

Do not introduce a generic `Inspection` or projection framework.

### Formal gate

Before implementation, use Lean to prove the existing public functions are observationally equal to specializations of the proposed shared fold, including the missing-validity refusal behavior.

This is the strongest current SA-007 `SHARE_MECHANICS` candidate.

## 5. Strong candidate B — QuantityInspection success provenance may be semantic echo

Current `QuantityInspectionAnswer` distinguishes successful answers as:

```text
recorded quantity
singleCorrectionEffective quantity
frontierEffective quantity
```

but current consumers provide evidence that this successful-mode distinction may not be independent information.

### Consumer evidence

`ZeroOriginQuantity` maps all three successful constructors to the same:

```text
current quantity
```

`EffectiveCli` first branches on the number of retained Corrections to choose presentation mode, then calls `inspectQuantity` and checks that the returned success constructor agrees with the mode it already knows.

`ShadowQuantityCli` calls `inspectQuantity` with an explicitly empty Correction memory and therefore already knows the result, when successful, must be the recorded path.

No current consumer found in this audit needs the successful constructor to learn information not already derivable from the supplied correction evidence.

### Important non-compression

The **internal algorithms must not be merged merely because the successful result vocabulary may compress**.

In particular:

- zero Correction uses recorded quantity;
- one Correction preserves the previously qualified single-correction projection, including its current self-relation behavior;
- multiple Corrections require the admitted correction frontier and may refuse branching/merging/cycles/open references.

Those calculation/admission distinctions remain real.

### Candidate compressed result

A possible future answer shape is conceptually:

```text
quantity Quantity
missingCorrectionEndpoint
frontierRequired
```

with presentation provenance derived from the already-supplied Correction evidence when needed.

This is only a hypothesis, not an authorized API change.

### Formal gate

The historical Application 001 Alloy model cannot directly qualify this current compression because it predates the later multi-correction `frontierEffective` success path.

Create a current Lean observational-equivalence proof before implementation. The proof should cover every current constructor, including current multi-correction frontier success/refusal, and the observations used by `ZeroOriginQuantity`, `EffectiveCli`, and `ShadowQuantityCli`.

Status: `COMPRESS_RESULT` candidate, medium API churn, high conceptual value.

## 6. Candidate C — CurrentCoverage arithmetic is duplicated after routing-specific Consumption

`currentCoverageAtCorrectionFrontier?` and `currentCoverageAtCorrectionFrontierEffectiveRouting?` differ in how Actual Consumption is obtained.

After that point both repeat the same law:

```text
Commitment  := current Scheduled managed pressure
Entitlement := current effective Capacity
Remaining   := Entitlement - Consumption
Headroom    := Remaining - managed Commitment
```

and build the same `CurrentCoverageView` fields.

Production review currently uses the `RoutingEffective` variant; the ordinary-routing variant remains exercised as a lower-level qualified capability.

Decision: retain both public composition boundaries for now, but factor the shared current-coverage arithmetic if a small helper produces a net reduction.

A further copy of `Remaining - managed Commitment = Headroom` exists in `ScheduledCommitmentInspection.headroomAtCorrectionFrontier?`. Do not create a household arithmetic framework merely to remove one subtraction; first test the smallest pure helper boundary.

Formal gate: Lean definitional/observational equality of both current public functions before and after factoring.

## 7. Cross-entry finding for SA-004 — CorrectionQuantity is even more likely misplaced Core projection

`Core/CorrectionQuantity.lean` retains no canonical information. Its `quantityAtEffective?` is a single-correction projection.

Repository search finds the actual function use in current product code in `Application/QuantityInspection.lean`.

`Cli/CorrectionIntegrityCli.lean` imports `Loam.Core.CorrectionQuantity`, but the file does not call `quantityAtEffective?`; it calls `EventCorrection.project?`. This is an over-broad/stale import, not evidence that the derived quantity projection is a genuine Core dependency.

`Loam/Core.lean` also exposes `CorrectionQuantity` through the practical Core umbrella.

This strengthens SA-004:

```text
semantic status: DERIVED
likely owner: Application quantity inspection
current Core public exposure: questionable
```

Do not implement the move yet. First combine SA-004 with SA-005 Core-surface review and a current import/CI graph.

## 8. Small mechanical candidate — keyed Effect lookup

`OpenRelationFrontier` and `Cli/Movement/RelationEntry` each implement the same recursive `EffectKey` lookup over `Event.effects`.

`Event` already carries `EffectKey` uniqueness and `FiniteKeyed.findBy?` owns the generic keyed-list lookup mechanic.

This is a real but low-priority duplication. Prefer direct reuse of the existing small mechanic over inventing another relation-specific helper.

A similar raw RelationUnit-id lookup appears across relation/discharge code, but the gain is small. Revisit only together with SA-001 finite-keyed mechanics.

## 9. Scheduled refusal vocabulary — defer to SA-008

`ScheduledInspection`, `ScheduledOpenWorldInspection`, and `ScheduledBalanceHypothetical` repeat the same lifecycle refusal constructors such as unknown completion/retirement/replacement endpoints, invalid replacement graph, and conflicting terminal evidence.

A shared typed refusal vocabulary may be possible, but many current Review/CLI/TUI consumers match these states directly. The adapter cost and user-facing error ownership must be measured before introducing another shared error type.

This is better evaluated under SA-008 Scheduled semantic amplification rather than folded into this general Application pass.

## 10. Rejected broad simplifications

Current evidence rejects or does not justify:

```text
NO generic Inspection<T> framework
NO universal Projection object
NO one generic Application result/error type
NO merging Scheduled current-open semantics with open-world absence semantics
NO merging OpenRelation revision with ReplacementFrontier
NO splitting ScheduledCommitment merely because it is the largest Application file
NO deleting barrel-external Scheduled balance modules merely because they are not in Application.lean
NO treating derived Application answers as bad state merely because they are not canonical
```

Application is precisely the layer where rich answers should be derived from a smaller retained evidence basis.

## 11. Main architectural result

The 18-file Application surface is not eighteen independent domain primitives.

It currently contains:

- household query boundaries;
- typed composition adapters;
- two internal structural mechanics/adapters;
- specialized read-only capabilities;
- several pure derived compositions.

The strongest remaining complexity is not a second household ontology. It is **mechanical and answer-vocabulary echo** inside otherwise legitimate projections.

The most promising subtraction sequence is therefore:

```text
1. prove/share one fail-closed Actual-consumption fold
2. test compression of QuantityInspection successful result provenance
3. factor CurrentCoverage arithmetic if net simpler
4. revisit CorrectionQuantity Core placement with SA-004/SA-005
5. only then consider tiny keyed-lookup cleanup
```

## 12. Formal-method plan

Use existing formal evidence where it already answers the question:

```text
ReplacementFrontier factorization    -> existing Lean qualification
OpenRelation retraction separation   -> existing Alloy qualification
ScheduledCommitment row/aggregate law -> existing Lean theorem
```

Use new Lean proofs for the genuinely new compression claims:

```text
shared consumption fold equivalence
QuantityInspection compressed-result observational equivalence
CurrentCoverage arithmetic-factor equivalence
```

No new Alloy model is currently needed for those three pure functional refactors. Alloy becomes appropriate again if a proposal tries to erase a semantic distinction or merge state spaces rather than share pure computation.

## 13. SA-007 verdict

SA-007 is now **audit-complete** at this checkpoint.

No production implementation is authorized by this file alone.

The audit does not support a large Application rewrite. It supports a few small, formally checkable subtractions while preserving the current household query vocabulary and fail-closed boundaries.

Next ledger step: SA-002 two-endpoint relation mechanics, then SA-003 temporal/effective evidence, before batching any implementation changes.