# LOAM Observation Map

This document is a checkpoint after Observations 001–063.

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

Observation 063 does not choose whether the relation is physically stored on the Plan side, Event side, or as a separate relation record. Under the current one-to-one vocabulary those are representation choices. It also does not yet earn split/merged realization, Series, recurrence, or a practical Plan type.

## 2. Earned structure

The following structures currently carry distinctions that at least one retained question can observe.

### Stable identity

- Event identity
- Effect identity
- Locus identity
- Measure identity
- per-kind Correction identity
- per-kind Resolution identity
- Plan identity in the bounded expectation/realization vocabulary of Observation 063

Identity is not inferred from list position, physical storage order, display names, aggregate coordinates, or matching expected/actual content.

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

Observation 063 likewise does not enlarge the physical Event coordinate set. Planning information remains outside the Actual physical core in the bounded experiment.

### Explicit revision relations

Correction and Resolution remain explicit raw relation facts rather than edits that erase earlier facts.

Their referenced Events may be absent from the current Event memory. Raw memory can still retain the relation fact while derived referential admission fails closed.

### Explicit correspondence when provenance distinguishes identical content

Observation 063 finds that the mapping from Plan identity to Actual Event identity cannot be reconstructed from Plan/Event content or from the completed-Plan set. When future questions ask which Actual fulfilled which expectation, the correspondence itself must survive in some representation.

This does not yet imply that realization needs its own identity-bearing fact type.

### More than one time coordinate when the question requires it

The observation layer has earned a distinction between validity and knowledge time for retrospective questions. This does not imply that every practical-core fact must immediately carry both timestamps.

Observation 063 additionally demonstrates that expected time and Actual time need not be equal merely because a Plan and Event are linked.

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
- valuation / rate relations
- selection policy
- backing eligibility
- recipient assignment
- other application-facing classifications

Observation 062 supplies a real-data-shaped witness that AccountingRole remains semantically active while AccountName and nominal EventKind remain observationally inert for the selected bookkeeping-shape vocabulary.

Observation 063 supplies a separate real-data-shaped witness that plannedness and completion provenance are not properties of Actual Event content alone.

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

Observations 062 and 063 add no Account object, nominal EventKind, Plan type, realization type, import layer, or new persistence format to the practical core. They are evidence about what current real-data-shaped questions do and do not force.

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

Observations 062 and 063 do not alter persistence at all. In particular, Observation 063 does not earn a Plan store or a realization stream merely because explicit realization is semantically observable.

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
- Series / recurrence semantics
- issue metadata semantics merely because such annotations appear in source data
- compaction semantics

These are not rejected forever. They are simply not earned yet.

## 8. Tool roles after sixty-three observations

LOAM's method is now easier to state from evidence rather than intention.

### Alloy

Use when the question is primarily structural:

- can two worlds share one retained structure but differ in a future answer?
- is one relation independent of another?
- does removing a field collapse distinctions?
- can a familiar household noun remain a projection?
- do anonymized real-data shapes fit the existing structural vocabulary without adding a new primitive?
- can identity linkage be reconstructed from the endpoint records it connects?

Observations 062 and 063 are examples of the last two cases.

### J

Use when array shape, projection, quotienting, or information loss is the clearest form of the question.

J is not a mandatory second implementation of every Alloy observation.

### Lean 4

Use when a discovered law is worth preserving generally or when the practical typed core needs to embody an earned distinction.

Lean is both a proof environment and the current practical-core language.

### TLA+ / TLC

Use when the distinction depends on state transitions, temporal knowledge, operation order, or reachable intermediate states.

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

The resulting picture is now:

```text
Actual physical facts
        |
        +---- AccountingRole / other readings

Expectation facts
        |
        +---- explicit realization linkage ----> Actual Event identity
```

This is a useful stopping point before adding any Plan implementation. The new semantic information has been observed, but no practical storage pressure has yet earned a Plan store, realization stream, or generic relation abstraction.

The strongest next pressure is no longer "should Plan be an Event field?" Under one-to-one cardinality that is mostly a representation choice. A genuinely new question would relax the cardinality or add lifecycle behavior:

```text
one Plan -> several Actual Events
several Plans -> one Actual Event
partial realization
supersession / cancellation
Series / recurrence
```

If concrete workflows require those shapes, Observation 064 can ask whether realization itself needs identity, quantities, or temporal lifecycle. Otherwise LOAM can stop here without manufacturing another abstraction.
