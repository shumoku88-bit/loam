# LOAM Observation Map

This document is a checkpoint after Observations 001–066.

It is not a final ontology, schema, or roadmap. It records what the current observations have earned, what remains derived or overlay-like, what the practical Lean core currently carries, and what LOAM has deliberately not promoted into domain meaning.

## 1. The arc so far

### 001–017 — before household nouns

The first observations begin without Account, Transaction, Budget, Envelope, Month, or Report and ask what survives when finite resources are distributed through time and purpose.

The main pressure is whether familiar household nouns carry independent information or can be recovered as views over smaller relations.

Notable outcomes include:

- availability can be derived in the bounded consumptive world;
- live envelope-like holdings can be a projection of purpose placement and derived availability;
- commitment needs information beyond live holdings;
- vocabulary itself changes what history must remain distinguishable.

### 018–029 — memory, provenance, correction, and resolution

The second arc asks how much history must remain when later questions can target, explain, correct, or resolve earlier facts.

The recurring separation is:

```text
what happened
!=
how the current view interprets it
```

Append-only parentage, explicit identity, correction, resolution, conflict, and provenance pressure appear here. Compression remains vocabulary-relative: information may be forgotten only when no retained future question can distinguish the worlds it separates.

### 030–039 — generic events, coordinates, and time geometry

The third arc removes more nominal household structure.

A bounded generic event can carry selected household distinctions without primitive stored event-kind names. `Account` does not yet return as an irreducible domain object, but a distinguishable `Locus` coordinate becomes necessary once future questions ask where quantity resides.

A separate `Measure` coordinate becomes necessary when quantities that must not be collapsed coexist.

Time also separates into more than one observable coordinate. In particular:

```text
valid time
!=
learned time
```

and retrospective knowledge is naturally queried as a two-dimensional view:

```text
view(valid time, knowledge time)
```

### 040–051 — revision structure, overlays, and asynchronous evidence

The fourth arc pressures explanation edges, conflict recurrence, revision graphs, frontier settlement, coverage, selection, backing eligibility, accounting role, asynchronous settlement, and reconciliation evidence.

A repeated result is that many familiar classifications are not properties of physical quantity placement itself. They remain independent overlays unless richer facts later earn a derivation.

In particular:

```text
where quantity is
!=
what accounting role that locus plays
```

Selection and backing eligibility likewise remain outside the physical holdings core in the observations that test them.

### 052–061 — from observation to practical protocol

The fifth arc turns directly toward the practical Lean core and persistence boundary.

It first separates effect identity from coordinate aggregation:

```text
Effect identity
!=
Locus × Measure coordinate
```

Then it separates physical storage order from history, compares unified and split canonical fact topologies, observes publication boundaries, relation collection identity, derived referential admission, and raw relation-memory append admission.

The final three observations use protocol-specific tools:

- Observation 059 uses SPIN to check split-stream Correction publication/acquisition interleavings.
- Observation 060 uses TLA+ / Apalache to check crash/restart/retry behavior for the same candidate Correction protocol.
- Observation 061 uses SPIN to ask whether a multi-parent Resolution over an already-visible stable frontier needs a stronger publication order.

The candidate ordering earned for the bounded Correction case is:

```text
writer: Correction -> Event
reader: Event -> Correction
```

with fail-closed semantic admission hiding an early Correction until its referenced replacement Event is available.

Observation 061 then finds that multiple already-visible parent references do not add another publication edge. For a stable existing conflict frontier, the same narrower ordering shape is sufficient:

```text
writer: Resolution -> Event
reader: Event -> Resolution
```

This result is intentionally conditional on the non-replacement endpoints already being visible and stable. It does not cover concurrent Correction publication that changes the frontier while a Resolution is published or acquired.

Observation 060 does not earn autonomous recovery, concurrent-writer semantics, fsync guarantees, or a manifest/generation protocol. Observation 061 does not turn a moving three-stream frontier into a solved problem.

### 062 — real-ledger pressure without restoring Account

Observation 062 turns back from protocol machinery and applies anonymized structural pressure from a private household ledger supplied by the repository owner.

The public model copies no private descriptions, dates, identities, or quantities. It keeps only eight recurring shapes:

- holding-to-holding transfer;
- ordinary expense;
- split expense;
- income;
- liability-funded expense;
- liability repayment;
- expense refund / reimbursement;
- opening balance against equity.

All eight shapes coexist in one bounded Alloy model using only:

```text
Event
Effect
Locus
signed Quantity
AccountingRole
```

Observed:

```text
representative real-ledger shapes                         SAT
same semantic core, different AccountName / EventKind    SAT
role-only change can change recognized shape             SAT
Effect core alone determines selected shapes             SAT counterexample
Effect core + AccountingRole determines selected shapes  UNSAT counterexample
nominal presentation changes selected shapes              UNSAT counterexample
```

So the real-data pressure does not reverse Observations 031 or 049. It strengthens their practical relevance:

```text
Account as domain object
    still not forced by the selected vocabulary

AccountingRole
    still independent of signed placement
```

This is an expressibility and observability result, not an import-format decision. Observation 062 deliberately does not decide whether a ledger posting maps one-to-one to a practical LOAM Effect.

### 063 — Plan realization needs explicit identity linkage

Observation 063 applies the next anonymized pressure from real household records: expected Plan facts later connect to Actual Events, but expected and Actual records need not be identical in time or quantity.

The model keeps Plan identity, Event identity, a small expected/actual content vocabulary, and one explicit partial matching:

```text
Plan
  + expected Time / Amount / Shape

Event
  + actual Time / Amount / Shape

realizes : Plan -> lone Event
```

Observed:

```text
realization can link non-identical records        SAT
same records can yield different completion       SAT
same completed set can hide different provenance  SAT
same Actual can be planned or unplanned            SAT
exact content matching can be ambiguous            SAT
Plan/Event records determine completion            SAT counterexample
completion summary determines realization          SAT counterexample
explicit relation determines selected answers      UNSAT counterexample
```

The bounded separation is therefore:

```text
Plan record
    +
Actual Event record

        does not determine

which Event realizes which Plan
```

The realization linkage carries observable information of its own. Even exact time/amount/Shape matching is insufficient when identity-distinct Events occupy the same observable coordinates.

Observation 063 does not choose whether the relation is physically stored on the Plan side, Event side, or as a separate relation record. Under the current one-to-one vocabulary those are representation choices. It also does not yet earn split/merged realization, Series membership, recurrence generation, or a practical Plan type.

### 064 — recurring Plan content does not determine Series membership

Before extending realization cardinality, Observation 064 checks the current canonical household records for concrete split or merged realization pressure. None is present yet: the visible Plan-linked Actual records still use one Plan identity per Actual record.

Rather than manufacturing many-to-many realization, the observation follows a structure that is already explicit in the source: recurring Plans are grouped into Series and carry recurrence classifications such as monthly, cycle, and once.

The public model retains only anonymized structure:

```text
Plan identity
  + expected Time / Amount / Shape
  + Recurrence kind

seriesOf : Plan -> one Series
```

Observed:

```text
representative Series pressure                     SAT
same Plan records, different grouping              SAT
same Series, changing expected amount              SAT
same recurrence + Shape, different Series          SAT
Plan records determine Series grouping             SAT counterexample
same recurrence + Shape forces same Series         SAT counterexample
Series membership requires fixed amount            SAT counterexample
explicit membership determines peer answers        UNSAT counterexample
```

The bounded separation is therefore:

```text
Plan content
    !=
recurrence kind
    !=
Series membership
```

A recurring thread can continue across changed expected quantities, while distinct recurring threads can share recurrence kind and broad structural Shape. Which Plan identities belong to the same thread is observable grouping information of its own.

Observation 064 does not earn a first-class practical `Series` object or a recurrence engine. A Plan-side series identifier, standalone membership relation, or another information-equivalent encoding could preserve the same observed distinction.

### 065 — refund provenance is not quantity reversal or Correction

Observation 065 follows another structure already present in ordinary household records: a later return-like Event can offset quantity from an earlier expense-like Event, while a future question may still ask which earlier Event the return belongs to.

The public model keeps only anonymized structure:

```text
Expense Event identity
  + Time
  + signed Quantity

Return Event identity
  + Time
  + signed Quantity

refundOf : Return -> lone Expense
```

The model deliberately does not require equal magnitudes. Full versus partial offset is separate from the provenance question.

Observed:

```text
representative refund pressure                              SAT
same Event records, different refund provenance             SAT
same net quantity, different refund provenance              SAT
matching source coordinates remain ambiguous                SAT
same Return can be refund-linked or unlinked                SAT
Event records determine refund provenance                   SAT counterexample
net quantity determines refund provenance                   SAT counterexample
explicit refund relation determines selected answers        UNSAT counterexample
Correction-style projection preserves source occurrence     SAT counterexample
```

The bounded separation is therefore:

```text
Event records
    +
net quantity

        does not determine

refund provenance
```

and the practical semantic boundary is:

```text
refund / reimbursement
    !=
Correction
```

A later refund can offset quantity without saying that the earlier expense was mistaken, replaced, or did not occur. Treating the refund relation like Correction-style supersession loses the selected occurrence answer for the source Event.

Observation 065 does not earn a first-class practical `Refund` object, relation identity, allocation lifecycle, or persistence stream. It only earns the distinction that source-specific refund provenance cannot be reconstructed from physical Event records or aggregate quantity when that provenance remains observable.

### 066 — acquisition basis is not historical valuation

Observation 066 begins an external-accounting-pressure arc. It does not import a conventional Lot or CostBasis object. Instead it takes a narrower pressure seen in existing accounting systems: acquisition-specific cost information and later valuation can remain separately observable.

The bounded model keeps one acquisition identity, two time coordinates, complete valuation answers, and a separate acquisition-basis answer:

```text
valuationAt : Time -> ComparisonValue

acquisitionBasis : Acquisition -> ComparisonValue
```

Observed:

```text
acquisition-time valuation / basis / current valuation differ  SAT
same complete valuation history, different basis                SAT
same basis + acquisition-time valuation, different current      SAT
same acquisition-time valuation, different basis                SAT
basis may differ from acquisition-time valuation                SAT
valuation history determines basis                              SAT counterexample
basis equals historical valuation                               SAT counterexample
basis determines current valuation                              SAT counterexample
explicit basis + valuation determines selected answers          UNSAT counterexample
```

The bounded separation is therefore:

```text
historical valuation relation
    !=
acquisition basis
    !=
current valuation relation
```

Observation 034 had already shown that historical and current valuation can differ across time. Observation 066 adds a different distinction: even at the acquisition coordinate, a historical valuation answer does not generally determine acquisition provenance.

This sharpens the practical meaning of `Rate` without changing it. A neutral `Rate` remains useful as an exact Measure-to-Measure relation, but it should not silently stand in for acquisition basis merely because it applies at the acquisition time.

Observation 066 does not earn a practical `CostBasis` or `Lot` type, disposal selection method, gain calculation, tax rule, basis persistence stream, or identity-bearing basis fact.

## 2. Earned structure

The following structures currently carry distinctions that at least one retained question can observe.

### Stable identity

- Event identity
- Effect identity
- Locus identity
- Measure identity
- per-kind Correction identity
- per-kind Resolution identity
- Plan identity in the bounded expectation/realization vocabulary of Observations 063–064

Identity is not inferred from list position, physical storage order, display names, aggregate coordinates, matching expected/actual content, recurrence classification, opposite-signed quantity, or net balance.

Observation 065 uses Event identity to distinguish otherwise matching refund-source candidates. It does not yet earn a separate identity for refund linkage itself.

Observation 066 introduces one experiment-local acquisition identity only to ask whether basis belongs to that acquisition rather than to valuation history. It does not yet earn a new practical identity type.

### Quantitative coordinates

The practical physical shape is centered on exact signed quantity effects with explicit coordinates:

```text
Event
  -> Effect
       -> Locus
       -> Measure
       -> Quantity
```

Coordinate totals are projections over effects, not effect identity.

Observation 062 adds no new primitive coordinate. Representative bookkeeping-shaped Events can still be expressed with the existing Event / Effect / Locus structure plus independent AccountingRole.

Observations 063 and 064 likewise do not enlarge the physical Event coordinate set. Planning and recurring-thread information remain outside the Actual physical core in the bounded experiments.

Observation 065 adds no quantity coordinate either. Even retaining the physical Event records and their net quantity does not recover which earlier Event a later return is meant to explain.

Observation 066 also adds no physical quantity coordinate. Acquisition basis and valuation remain comparison/provenance information outside the signed physical placement geometry in the bounded model.

### Explicit revision relations

Correction and Resolution remain explicit raw relation facts rather than edits that erase earlier facts.

Their referenced Events may be absent from the current Event memory. Raw memory can still retain the relation fact while derived referential admission fails closed.

Observation 065 sharpens the boundary around Correction: an offsetting later Event is not thereby a Correction. Refund linkage preserves the source as an occurrence rather than replacing its effective interpretation.

### Explicit correspondence when provenance distinguishes identical content

Observation 063 finds that the mapping from Plan identity to Actual Event identity cannot be reconstructed from Plan/Event content or from the completed-Plan set. When future questions ask which Actual fulfilled which expectation, the correspondence itself must survive in some representation.

This does not yet imply that realization needs its own identity-bearing fact type.

### Explicit recurring-thread grouping when peer identity matters

Observation 064 finds that recurrence kind and Plan content do not determine which Plan identities belong to the same recurring thread. When future questions ask which expectations are peers in one Series, the membership distinction must survive in some representation.

This does not yet imply that Series must be a first-class stored object or that membership needs its own identity-bearing fact.

### Explicit refund provenance when source identity matters

Observation 065 finds that Event records, opposite-signed quantity, and net quantity do not determine which earlier Event a return belongs to. When future questions ask which occurrence was refunded or reimbursed, the source linkage must survive in some representation.

This does not yet imply a first-class Refund fact, identity-bearing refund relation, or general refund-allocation model.

### Explicit acquisition basis when acquisition provenance matters

Observation 066 finds that even complete valuation history does not determine the selected basis answer for an acquisition identity. When future questions distinguish how an acquisition was carried from how the same holding is valued, that acquisition-specific information must survive in some representation.

This does not yet imply a practical CostBasis type, a Lot identity, or one mandatory basis representation.

### More than one time coordinate when the question requires it

The observation layer has earned a distinction between validity and knowledge time for retrospective questions. This does not imply that every practical-core fact must immediately carry both timestamps.

Observation 063 additionally demonstrates that expected time and Actual time need not be equal merely because a Plan and Event are linked.

Observation 066 is deliberately not another time-coordinate result. It shows that two meanings can remain distinct even when they refer to the same acquisition coordinate.

## 3. Derived views

The following have appeared as derivable views rather than automatically deserving primary stored identity.

- live envelope-like holdings
- availability in the bounded consumptive model
- total balance
- balance by Locus / Measure
- transfer-like shape
- role-aware bookkeeping shapes such as expense, income, liability repayment, refund, and opening balance in the bounded Observation 062 vocabulary
- completed Plan membership from explicit realization linkage
- realized Actual Event membership from explicit realization linkage
- expected/actual amount, time, and Shape mismatch views from realization linkage
- same-Series peer sets from explicit Series membership
- refunded-source Event membership from explicit refund linkage
- refund-linked Return membership from explicit refund linkage
- historical valuation answers from retained valuation observations
- current valuation answer from the selected current relation
- current tips of a revision graph
- correction-aware effective views
- referentially admitted relation views
- report-like readings over physical facts plus overlays

A derived view may later earn stored operational support for performance or publication, but that would not by itself make the stored representation canonical domain meaning.

## 4. Overlays

These relations have evidence of semantic independence from the neutral physical core, or are intentionally kept outside it pending stronger pressure.

- Purpose / intentional assignment
- AccountingRole
- Plan realization linkage in the bounded Observation 063 vocabulary
- Series membership in the bounded Observation 064 vocabulary
- refund / reimbursement source linkage in the bounded Observation 065 vocabulary
- valuation / rate relations
- acquisition-basis relation in the bounded Observation 066 vocabulary
- selection policy
- backing eligibility
- recipient assignment
- other application-facing classifications

Observation 062 supplies a real-data-shaped witness that AccountingRole remains semantically active while AccountName and nominal EventKind remain observationally inert for the selected bookkeeping-shape vocabulary.

Observation 063 supplies a separate real-data-shaped witness that plannedness and completion provenance are not properties of Actual Event content alone.

Observation 064 adds that recurrence classification and Plan content do not determine recurring-thread membership.

Observation 065 adds that numerical offset and net quantity do not determine refund-source provenance, and that this source linkage has different semantics from Correction-style supersession.

Observation 066 adds that acquisition basis is not determined by valuation history, even when the valuation answer at the acquisition coordinate is retained.

An overlay is not "less real." It means its meaning is not determined by the underlying physical placement and quantity relations currently retained.

## 5. Practical Lean core

The practical core now contains small typed pieces including:

- `Quantity`
- `Measure`
- `Effect`
- `Event`
- `EventMemory`
- `EventCorrection`
- `EventCorrectionMemory`
- `EventResolution`
- `EventResolutionMemory`
- correction-aware quantity projections
- relation admission
- `Rate`
- `Allocation`
- `RecipientAssignment`

Correction and Resolution have separate semantic module boundaries. Their memory implementations remain deliberately concrete rather than being generalized behind one premature relation-memory abstraction.

Observations 062–066 add no Account object, nominal EventKind, Plan type, realization type, Series type, Refund type, CostBasis type, Lot type, recurrence engine, import layer, or new persistence format to the practical core. They are evidence about what current real-data-shaped and external-pressure questions do and do not force.

Observation 066 does not change `Rate`. The current practical `Rate` already deliberately avoids claiming that a Measure relation is a price, valuation authority, or time-stable fact. The new observation only adds evidence that a rate-like valuation relation should not be reused implicitly as acquisition provenance.

The implementation policy remains conservative:

```text
observation
  -> identify one earned distinction or law
  -> add only the minimum practical representation needed
```

The practical core is not intended to mirror every experimental vocabulary term.

## 6. Persistence boundary

The current practical persistence work has crossed an important boundary without introducing one global ordered history.

Event memory and raw Correction memory can be persisted as separate versioned streams. The logical canonical basis is the admitted facts and their explicit identity relations, while physical storage topology is a separate operational choice.

The current observations therefore distinguish:

```text
logical canonical facts
!=
physical storage topology
!=
derived projections
```

Separate atomic file replacement is not sufficient by itself when multiple streams form one semantic read/write protocol. Writer and reader order are part of the protocol.

Observation 061 earns a stable-frontier ordering shape for Resolution, but practical Resolution persistence has not yet been added merely by analogy. A moving frontier would coordinate Event, Correction, and Resolution streams and remains a separate question.

Observations 062–066 do not alter persistence at all. In particular, semantic observability of realization, Series membership, refund provenance, or acquisition basis does not by itself earn a Plan store, realization stream, Series stream, refund stream, basis stream, lot store, or recurrence store.

## 7. Deliberately unearned concepts

LOAM should not silently promote the following into domain law without a new observation that requires them.

- one global FactId shared by all fact kinds
- one globally ordered canonical history
- chronology from list or file position
- priority or authority from arrival order
- a conventional Account object as the physical primitive
- a stored nominal EventKind hierarchy for bookkeeping roles
- a stored Envelope balance as the live-holdings source of truth
- one mandatory transaction/event nominal sum type for household roles
- eager referential rejection as a raw relation-memory rule
- autonomous recovery metadata
- concurrent-writer locking semantics
- fsync or power-loss durability guarantees
- a manifest or generation selector
- general Resolution persistence parity beyond the stable-frontier case observed in 061
- one-to-one ledger-posting-to-LOAM-Effect import semantics
- a Practical Core `Plan` type merely because planning appears in source data
- first-class realization identity, correction, or persistence
- one Plan realized by several Events or several Plans realized by one Event
- a Practical Core `Series` object merely because Series membership is observable
- recurrence generation, next-occurrence prediction, or Series lifecycle semantics
- a Practical Core `Refund` type merely because refund provenance is observable
- first-class refund-link identity, correction, or persistence
- generalized one-to-many or many-to-many refund allocation and lifecycle semantics
- a Practical Core `CostBasis` or `Lot` type merely because acquisition basis is observable
- first-class basis identity, correction, authority, or persistence
- FIFO, LIFO, average-cost, specific-identification, or any other lot-selection policy
- realized/unrealized gain semantics derived merely from valuation and basis separation
- tax-specific basis rules
- issue metadata semantics merely because such annotations appear in source data
- compaction semantics

These are not rejected forever. They are simply not earned yet.

## 8. Tool roles after sixty-six observations

LOAM's method is now easier to state from evidence rather than intention.

### Alloy

Use when the question is primarily structural:

- can two worlds share one retained structure but differ in a future answer?
- is one relation independent of another?
- does removing a field collapse distinctions?
- can a familiar household noun remain a projection?
- do anonymized real-data shapes fit the existing structural vocabulary without adding a new primitive?
- can identity linkage be reconstructed from the endpoint records it connects?
- can recurring-thread membership be reconstructed from Plan content and recurrence classification?
- can aggregate quantity reconstruct a source-specific real-world provenance relation?
- can one semantic relation be reconstructed from another even when both refer to the same time coordinate?

Observations 062–066 are examples of the last five cases.

### J

Use when array shape, projection, quotienting, or information loss is the clearest form of the question.

J is not a mandatory second implementation of every Alloy observation.

### Lean 4

Use when a discovered law is worth preserving generally or when the practical typed core needs to embody an earned distinction.

Lean is both a proof environment and the current practical-core language.

### TLA+ / TLC

Use when the distinction depends on state transitions, temporal knowledge, operation order, or reachable intermediate states.

Observation 034 already used TLA+ to separate historical, current, and future relation viewpoints. Observation 066 therefore stays with Alloy because its new distinction is semantic rather than temporal: historical valuation and acquisition basis can differ at the same coordinate.

### Apalache

Use selectively with TLA+ when symbolic checking or inductive-invariant obligations add a distinct answer, as in Observation 060.

### SPIN / Promela

Use when explicit process interleavings and protocol order are the pressure point, as in Observations 059 and 061.

### miniKanren

Use when genuinely relational or backwards search adds something the other tools do not express as directly.

The rule remains:

> Using every tool is not a goal. A tool must earn its place in the question.

## 9. Current checkpoint

After Observation 060 and the first raw Correction-memory persistence step, LOAM had completed one full development loop:

```text
question
  -> structural observation
  -> counterexample or law
  -> protocol observation when needed
  -> practical Lean boundary
  -> persistence
```

Observation 061 extended that loop just far enough to test the next relation kind without mechanically copying the Correction protocol.

Observation 062 then brought anonymized shapes from ordinary household records back to the earlier structural questions. The result did not force Account or EventKind back into the core, and it confirmed that AccountingRole remains the independent relation needed for the selected bookkeeping-shaped readings.

Observation 063 follows the same real-data-pressure strategy one layer outward. It finds that expectation and actuality can remain separate facts, but their correspondence is not recoverable from endpoint content. Stable completion provenance therefore needs explicit identity linkage even when matching coordinates look sufficient.

Observation 064 deliberately refuses the tempting next abstraction when the source does not require it: current records do not yet force many-to-many realization. Instead it follows the recurring structure that is already present and finds that Series membership itself cannot be reconstructed from recurrence kind or Plan content.

Observation 065 follows another source-shaped relation rather than inventing a new mechanism. It finds that quantity can be offset while the source occurrence remains historically true, so refund provenance is neither reconstructable from net quantity nor interchangeable with Correction semantics.

Observation 066 then opens the external-pressure arc with a distinction already needed by mature accounting systems, but translates it back into LOAM's vocabulary rather than importing their ontology. Complete valuation history still does not determine acquisition basis. A relation answering "what value is observed at this coordinate?" and information answering "how was this acquisition carried?" remain independent.

The resulting bounded picture is now:

```text
Actual physical facts
        |
        +---- AccountingRole / other readings
        |
        +---- refund-source linkage when provenance is asked
        |
        +---- acquisition-basis information when provenance is asked

Expectation facts
        |
        +---- explicit realization linkage ----> Actual Event identity
        |
        +---- explicit recurring-thread membership

Valuation observations
        |
        +---- historical/current valuation views
        |
        x---- do not reconstruct acquisition basis
```

This is still not a universal ontology. It is an inventory of distinctions that concrete questions and external pressure have forced so far.

It is also still a good stopping point before adding Plan, Series, Refund, CostBasis, or Lot implementation. The semantic distinctions are visible, but no practical storage pressure has yet earned those objects, their streams, or a generic relation abstraction.

The strongest next external-pressure question is now narrower than "implement lots":

```text
If two acquisitions of the same Measure have different basis provenance,
can aggregate holdings still answer which acquired quantity was disposed?
```

That can test whether Effect/acquisition identity already carries enough provenance before any Lot object is allowed into the practical core.
