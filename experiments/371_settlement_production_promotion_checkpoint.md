# Observation 371 — settlement production promotion checkpoint

Status: **PROMOTION CHECKPOINT — semantic and Application boundary selected; persistence topology deliberately deferred**

Baseline stack:

```text
#1402  Observation 369 — finality correction identity
#1403  Observation 370 — composed direct/net conservation
head   8d8be63647d970f4443833bf98fc0a572993af9d
```

## Trigger

Observations 359–370 progressively separated the settlement problem instead of
widening an existing accounting abstraction until it happened to fit.

The retained pressures are:

```text
O359  delayed securities require trade/source provenance and later exact Effect settlement
O360  OpenRelation must remain source-bounded; cross-Measure settlement is a different authority
O361  direct correspondence needs exact attributed Quantity and dual conservation
O362  correspondence correction reuses ReplacementFrontier and earns row-version identity
O363  partial attribution is valid; complete allocation is a workflow-specific publication promise
O364  commitment Quantity remains positive magnitude; debtor/creditor carries direction
      buy and sell use one family; settlement may retain exact net cash without owning fee/tax decomposition
O365  opposite-direction netting cannot be represented as permissive direct correspondence
O366  zero-net completion needs no synthetic physical Effect
O367  netting correction belongs to member rows; aggregate net amount remains derived
O368  explicit finality may require an as-finalized publication distinct from current-restated evidence
O369  correcting finality evidence itself earns publication version identity
O370  direct and net settlement need one composed conservation boundary
```

The research now has repeated independent pressure from:

- foreign-card settlement;
- delayed securities settlement;
- buy-side and sell-side cash settlement;
- partial multi-Event settlement;
- one-Effect-to-many-commitment attribution;
- opposite-direction netting;
- zero-net settlement;
- append-only correspondence/member correction;
- historical finality.

The next question is no longer whether a settlement family is semantically
distinct.

It is:

> What is the smallest production boundary that preserves all repeatedly earned
> laws without making securities-market machinery mandatory for ordinary
> household accounting?

## Promotion judgment

A reusable settlement family is now **promotion-ready at the semantic and
Application layers**.

Persistence and writers are **not** promoted in this checkpoint.

That split is deliberate.

The current normalized Actual wire is strongly TX-oriented, while settlement has
now qualified:

- commitments whose source and later physical settlement are different Events;
- netting contexts that may refer to several gross commitments;
- zero-net completion with no physical Effect;
- optional finality publications that may preserve older member versions.

Forcing those facts into the first convenient TX-local encoding would choose
physical topology before semantic ownership is settled.

Therefore this checkpoint selects the production vocabulary and admission
boundary first, then requires a separate persistence-topology checkpoint before
changing `actual.loam`.

## 1. Preserve OpenRelation exactly as it is

Do **not** broaden `RelationUnit`.

Its present contract remains valuable:

```text
relation Measure = source Effect Measure
relation quantity <= |source Effect quantity|
```

Cross-Measure settlement deliberately has a different source of authority.

Examples:

```text
foreign card
  source purchase: 30 USD
  settlement commitment: 4700 JPY

security trade
  source trade: 3 shares
  settlement commitment: 1000 JPY
```

Trying to absorb those into OpenRelation would either break its source-bounded
law or create two semantic modes inside one nominal type.

Settlement remains additive beside OpenRelation.

## 2. Smallest production Core/domain vocabulary

The first production semantic module should be family-specific, conceptually:

```text
Loam/Core/Settlement.lean
```

It should contain raw provenance, not admission proofs or persistence behavior.

### 2.1 Settlement commitment

```text
SettlementCommitmentId
  opaque stable identity

SettlementCommitment
  id
  sourceEvent
  sourceEffect
  debtor
  creditor
  settlement Measure
  exact Quantity
```

Admission later requires:

- source Event / Effect resolves;
- exactly one endpoint is Household and the other is ExternalParty for the
  currently qualified personal-accounting boundary;
- Quantity is positive;
- settlement Measure and Quantity are independent semantic evidence and are not
  bounded by the source Effect's Measure or magnitude.

Direction belongs to debtor / creditor.

Quantity remains an unsigned-by-semantics positive magnitude at admission even
though raw `Quantity` remains the existing signed Core scalar.

No `SettlementCommitmentRevision` is promoted here.

The research has earned stable commitment identity, but has **not** separately
qualified correction semantics for a mis-recorded commitment itself.

### 2.2 Direct physical correspondence

```text
SettlementCorrespondenceId
  version-capable retained row identity

SettlementEffectCorrespondence
  id
  target SettlementCommitmentId
  later EventId
  later EffectKey
  exact attributed Quantity

SettlementCorrespondenceRevision
  target SettlementCorrespondenceId
  replacement SettlementCorrespondenceId
```

The row ID is included from the first production vocabulary because O362 showed
that old and corrected rows may have the same semantic coordinate:

```text
target + Event + EffectKey
```

while differing in Quantity.

The revision is one-to-one supersession only.

No deletion, multi-parent merge, or settlement-specific mutation engine is
promoted.

Generic `ReplacementFrontier` owns the structural mechanics.

### 2.3 Net settlement context

```text
SettlementNettingContextId
  stable identity for one netting / settlement occasion

NetSettlementOutcome
  zero
  | physical EventId EffectKey

SettlementNettingContext
  id
  settlement Measure
  outcome
```

A dedicated context identity is retained at this checkpoint.

O367 proves that target commitment identity alone cannot distinguish separate
settlement occasions. The exact future wire coordinate may later map a context to
a statement, batch, settlement cycle, or other retained occurrence, but this
checkpoint does not collapse that semantic identity into EventId merely to fit
the present TX-oriented persistence grammar.

For nonzero netting, the exact physical Effect is explicit.

For exact cancellation:

```text
outcome = zero
```

and no synthetic zero-quantity Effect is required.

### 2.4 Netting member rows

```text
SettlementNettingMemberId
  version-capable retained row identity

SettlementNettingMember
  id
  context SettlementNettingContextId
  target SettlementCommitmentId
  exact contributed Quantity

SettlementNettingMemberRevision
  target SettlementNettingMemberId
  replacement SettlementNettingMemberId
```

O367 independently earned both:

- stable context identity;
- member-version identity under correction.

Again, generic `ReplacementFrontier` supplies revision mechanics.

There is no aggregate `NettingVersionId`.

The net amount is derived from the current member frontier.

## 3. One Application admission boundary owns settlement composition

The family should not expose separately admitted direct and netting answers as
though they were globally safe.

The production Application boundary should conceptually be:

```text
AdmittedSettlementImage
```

built from:

```text
EventMemory
SettlementCommitments
SettlementEffectCorrespondences
SettlementCorrespondenceRevisions
SettlementNettingContexts
SettlementNettingMembers
SettlementNettingMemberRevisions
```

The image owns the current frontiers and the composed laws.

### 3.1 Commitment admission

For every admitted commitment:

- source Event / Effect resolves;
- endpoints satisfy the currently qualified Household/external direction;
- Quantity > 0;
- settlement Measure is retained independently from the source Effect.

### 3.2 Direct correspondence admission

For every current direct correspondence:

- target commitment resolves;
- later Event / keyed Effect resolves;
- Quantity > 0;
- physical Effect Measure = commitment settlement Measure;
- physical Effect sign agrees with debtor / creditor direction;
- attributed Quantity <= commitment Quantity;
- aggregate direct use of one physical Effect <= its magnitude.

### 3.3 Netting admission

For every current netting member:

- context resolves;
- target commitment resolves;
- Quantity > 0;
- Quantity <= target commitment Quantity;
- commitment Measure = context settlement Measure.

For each context, derive signed member contribution from debtor / creditor
direction.

Then:

```text
signed total = 0
  -> outcome must be zero
  -> no physical Effect required

signed total != 0
  -> outcome must be physical Event/Effect
  -> physical Measure = context Measure
  -> physical Quantity = signed total exactly
```

### 3.4 Cross-mode target conservation

O370 adds the production-critical composed law.

For every commitment:

```text
sum(current direct correspondence Quantity)
+
sum(current netting-member Quantity across every context)
<= commitment Quantity
```

This is the authority behind exact current outstanding:

```text
outstanding
  = commitment Quantity
    - direct current attributed total
    - netting current attributed total
```

No separate outstanding state is persisted.

### 3.5 Cross-mode physical conservation

A nonzero netting context explains the exact whole physical Effect selected as
its outcome.

Therefore:

- no current direct correspondence may simultaneously consume that Effect;
- two current netting contexts may not simultaneously claim the same physical
  Effect anchor under the currently qualified model.

A zero-net context consumes semantic commitment quantity but no physical Effect.

This conservation is owned by the composed Application image rather than by
either raw row family.

## 4. Correction mechanics remain generic

Do not create:

```text
SettlementCorrectionEngine
NettingMutation
AllocationMutation
FinalityMutation
```

The qualified row-shaped corrections reuse:

```text
Loam.Application.ReplacementFrontier
```

Family-specific revision rows supply semantic authority.

The generic frontier supplies only:

- reference closure;
- endpoint uniqueness;
- acyclicity;
- sibling-conflict refusal;
- current frontier selection.

This preserves the standing rule:

> share mechanics, preserve semantic authority.

## 5. What enters the first production promotion

### Promote now at semantic/Application level

```text
SettlementCommitmentId
SettlementCommitment

SettlementCorrespondenceId
SettlementEffectCorrespondence
SettlementCorrespondenceRevision

SettlementNettingContextId
NetSettlementOutcome
SettlementNettingContext

SettlementNettingMemberId
SettlementNettingMember
SettlementNettingMemberRevision

AdmittedSettlementImage
  + local admission
  + ReplacementFrontier reuse
  + cross-mode target conservation
  + cross-mode physical conservation
  + derived outstanding
```

These pieces are required to support the already-observed card/securities
workflows without semantic backtracking.

### Do not promote in the first base slice

```text
CompleteAllocationPublication
FinalizedSettlementPublication
FinalityPublicationVersionId
```

Those meanings are qualified, but they are workflow-specific extensions.

The base settlement family must remain useful without requiring institutional
allocation or legal-finality concepts.

## 6. Qualified optional extensions

### 6.1 Complete allocation publication

O363 found real workflows where a set of allocation rows is published as one
complete statement:

```text
sum(member quantities) = selected physical Effect magnitude
```

This is **not** a universal settlement law.

It should be added only when a LOAM workflow explicitly promises complete
allocation publication.

### 6.2 Finalized settlement publication

O368–O369 qualify an optional historical layer for workflows with a genuine
final/acknowledged/irrevocable boundary.

Conceptually:

```text
FinalizedSettlementPublication
  version identity if correction is promised
  NettingContext
  exact member-version identities
  exact physical Effect anchor
```

Its purpose is to distinguish:

```text
current-restated
  what current corrected evidence implies now

as-finalized
  what exact composition and physical settlement were finalized then
```

This extension must not be inferred automatically for an ordinary household
payment.

## 7. Persistence judgment

Settlement belongs semantically beside retained Actual evidence because:

- commitments reference retained source Events / Effects;
- direct correspondences reference retained physical Events / Effects;
- admission needs same-generation Event closure;
- unrelated Actual publishers must eventually preserve settlement evidence.

However this checkpoint intentionally does **not** yet widen
`ActualEvidence` or `actual.loam`.

Reason:

The existing normalized wire is TX-oriented.

The qualified settlement model contains context-level evidence that should not
be forced into a TX merely for storage convenience, especially:

- cross-Event commitment/settlement relationships;
- netting contexts spanning multiple commitments;
- zero-net outcomes with no physical Effect;
- future optional finality publications referencing historical member versions.

The next persistence checkpoint must compare at least:

1. additive global settlement rows/blocks inside the same `actual.loam`
   generation;
2. a context-owning Event representation where semantically justified;
3. a separate settlement stream only if atomic co-publication and closure can be
   preserved without creating a second authority problem.

The current preference is to preserve one Actual authority generation, but the
wire shape must be earned rather than selected for parser convenience.

Do **not** invent a zero cash Effect or a fake owning Event merely to preserve
the current parser shape.

## 8. Fee, tax, and investment decomposition remain outside settlement

Settlement may retain the exact net amount due.

It does not own the reason that amount differs from gross consideration.

Keep outside the base settlement family:

```text
principal
commission
tax
accrued interest
other fee
cost basis
realised gain
lot selection
corporate action semantics
```

Those facts may contribute to the commitment amount through their own
investment/accounting authorities.

This prevents a payment mechanism from becoming an investment ontology.

## 9. FX remains orthogonal

Cross-Measure commitment support is required now.

FX valuation is not.

The base family may represent:

```text
source 30 USD
settlement commitment 4700 JPY
```

without claiming:

- exchange rate authority;
- valuation gain/loss;
- base-currency reporting law;
- tax valuation;
- historical FX pricing.

Those remain separate evidence/projection questions.

## 10. First implementation sequence after this checkpoint

### Slice A — raw production vocabulary

Add `Loam/Core/Settlement.lean` with only the promoted raw types and import it
from `Loam/Core.lean`.

No persistence or UI.

### Slice B — Application frontier / admission

Add one settlement Application module that:

- constructs correspondence and member current frontiers;
- resolves all Event / Effect / commitment / context references;
- enforces local laws;
- enforces O370 cross-mode conservation;
- exposes exact outstanding from the admitted image.

No canonical writer.

### Slice C — production-shaped qualification

Pin at least:

- foreign-card cross-Measure settlement;
- delayed security settlement;
- partial multi-Event direct settlement;
- one physical Effect split across several same-direction commitments;
- buy cash debit;
- sell cash credit;
- opposite-direction netting;
- zero-net settlement;
- direct + net legitimate mixed settlement;
- cross-mode target double-use refusal;
- cross-mode physical Effect double-use refusal;
- correspondence correction;
- netting-member correction;
- conflicting replacement refusal.

### Slice D — persistence-topology checkpoint

Only after the in-memory production boundary is stable, select the canonical
wire topology and preservation obligations.

### Slice E — retained persistence + independent publisher

Add retained settlement evidence to Actual authority and one narrow publisher.

The first writer should publish explicit user/AI-confirmed settlement evidence.
Do not add automatic matching as canonical authority.

### Slice F — read/query surfaces

Expose:

- commitment amount;
- settled amount;
- outstanding amount;
- provenance;
- direct vs net settlement explanation.

TUI can remain small. Complex inspection may be supplied through AI/reporting.

### Slice G — optional extensions only when a workflow asks for them

- complete allocation publication;
- finality publication;
- finality-evidence correction.

## 11. Explicit non-goals

Do not add in the base promotion:

```text
generic Settlement supertype
generic Transaction supertype
generic EffectRef Core wrapper
universal Group / Batch primitive
universal Finality primitive
broadening RelationUnit
signed semantic commitment Quantity
synthetic zero cash Effects
automatic amount/date matching
FX valuation engine
tax jurisdiction rules
lot accounting
short-sale lifecycle
corporate actions
close-out/default netting
cross-counterparty legal netting
stored outstanding balances
stored aggregate net amounts
mandatory finality for household payments
mandatory allocation publication
```

## 12. Why this is a useful fork boundary

A future implementation can build much richer credit-card, brokerage, securities,
reimbursement, or clearing workflows above this family without changing neutral
Event / Effect Core or weakening OpenRelation.

The base preserves four distinctions that are easy to lose in an ordinary
ledger-centric implementation:

```text
semantic obligation != physical cash movement

direct settlement != net settlement

current-restated evidence != historically finalized evidence

shared structural mechanics != shared semantic authority
```

That is the useful extensibility promise of this checkpoint.

It does not claim LOAM already implements an institutional settlement engine.

It claims the production seam is now narrow enough that richer settlement
systems can be built additively rather than by reopening the accounting core.

## Stop condition

After the first in-memory production settlement family and composed admission are
qualified, stop semantic expansion.

Do not continue adding brokerage-specific concepts merely because they exist.

The next work after Slice C should be persistence topology and one practical
household/card/securities entrance.

New semantic layers must again earn themselves from a concrete unsupported
workflow.

## Promotion decision

**PROMOTE:**

```text
base settlement vocabulary
direct correspondence correction identity
netting context/member vocabulary
netting member correction identity
composed settlement admission/conservation
derived outstanding
```

**QUALIFIED BUT OPTIONAL:**

```text
complete allocation publication
as-finalized settlement publication
finality-publication correction identity
```

**KEEP OUT OF BASE / RESEARCH OR DOMAIN-SPECIFIC:**

```text
FX valuation
fee/tax decomposition
investment basis/lots
legal close-out netting
cross-counterparty netting
automatic matching
jurisdiction-specific finality
corporate actions
short lifecycle semantics
```

**DO NOT PROMOTE TO NEUTRAL CORE:**

```text
universal Settlement
universal Group
universal Finality
broadened OpenRelation
```
