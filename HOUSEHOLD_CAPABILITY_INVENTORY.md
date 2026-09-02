# LOAM household capability inventory

Status: working inventory before the next compression observations

This document lists household capabilities that are already useful in HRA / h-kernel and asks which of them LOAM should reconstruct. It is deliberately a capability inventory, not a type or source-format migration plan.

The rule is:

> Bring the household question and user capability first. Do not automatically bring HRA / h-kernel nouns, source files, or internal ownership graph with it.

LOAM should continue to ask whether the capability can be obtained from smaller retained facts, explicit relations, query-local policy, and projections before earning a new primitive.

## Current comparison baseline

HRA and h-kernel already provide a broad daily-use household surface: Actual recording / reversal, Plan lifecycle, Envelope capacity and Backing, Issue lifecycle, temporal observation, reports, and interactive TUI operations. h-kernel's current editor interaction includes `Actual -> record / reverse`, `Plan -> complete / advance / edit`, `Issue -> maintain / realize`, `Entitlement -> transfer`, `Account -> add`, and classification of unrouted Expense activity. HRA publishes the same household through Home / Actual / Plan / Issue / Report / Entitlement / Account surfaces and an eleven-section report book.

LOAM already has a smaller practical slice:

- balanced Movement as the sole daily recording entrance;
- generic Event / Effect / Locus / Measure / exact Quantity;
- append-only Event correction;
- explicit starting QuantityBasis and correction;
- basis-cut evidence for occurrences already reflected in a basis;
- replaceable balance-view coordinates;
- current quantity / balance projections;
- live hints from previously observed Loci;
- read-only recorded-day and scheduled-day projections over an external household source;
- terminal composition of recorded and scheduled answers for one selected day;
- privacy-safe quantity shadow / parity work.

The remaining work is therefore not "copy HRA". It is to close the practical capability gap while preserving the smaller model where it survives contact with real use.

## Capability inventory

| Capability needed in ordinary use | HRA / h-kernel surface | LOAM today | Compression question before implementation | Priority |
|---|---|---|---|---|
| Record what happened | Actual / multi-posting transaction | Balanced Movement | Already compressed: purchase, transfer, income-shaped flow and split payment are one Movement. Keep testing whether any ordinary occurrence cannot fit this entrance. | established |
| Undo / correct what happened without rewriting history | reversal / typed Actual relation | EventCorrection | Already compressed. Observe effective-day consequences before adding more correction taxonomy. | established |
| Know current holdings | Account Balances / Cycle Accounts | QuantityBasis + Event effects + corrections + basis cut + balance view | Keep Locus neutral. Do not earn Account merely to render balances. Ask which role/classification questions actually require more than a replaceable view relation. | established |
| Record what is expected in the future | Plan | read-only Scheduled evidence in shadow adapter only | Can "scheduled occurrence" remain identity + day + neutral effects + lifecycle relations, without a Core Plan type? | next |
| Complete an expectation as something that actually happened | Plan completion / Actual relation | read-only completion evidence only | What is the minimum explicit relation between scheduled identity and Movement identity? Must completion preserve expected quantity separately from actual quantity? | next |
| Edit, postpone, retire, or advance an expectation | Plan lifecycle / successor | not practical | Can edit/retire/successor be append-only relations over scheduled identities rather than mutable Plan state? Which lifecycle distinctions change user answers? | next |
| Generate recurring expectations | recurrence / Series / successor generation | deliberately absent | Is recurrence canonical fact, a generator policy, or merely a way to create future scheduled identities? Test bounded worlds before earning Series. | later after scheduled lifecycle |
| See overdue / upcoming obligations | Planned Payments / calendar | selected-day scheduled shadow only | Can overdue/upcoming be a pure projection of schedule coordinate + lifecycle evidence + known-through horizon? | next |
| Navigate household time | Home calendar, Observed_Through, Selected_Day | selected day + known-through exist in shadow work | Keep knowledge horizon distinct from presentation focus. Ask whether cycle/month are query coordinates and policy rather than Core fields. | next |
| Define a household cycle | Cycle policy / Cycle Accounts / pace | absent | Is one anchor/boundary policy sufficient for all cycle-relative projections? Avoid a stored Cycle object if intervals can be derived. | next |
| Observe month-relative history | Monthly Accounts / reports | absent | Can month remain a query interval over dated evidence rather than a retained Month entity? | later |
| See recent / per-Locus history | Recent Journal / Actual workspace | review over EventMemory, no rich dated history | What minimum temporal evidence is required for useful history without making EventMemory order chronological? | next |
| Classify a Locus for a particular household question | Account type, Expense routing, current display selection | balance view only | Prefer explicit role / routing relations scoped to the question. Test whether one universal Account classification is actually needed. | next with envelope/report work |
| Give spending capacity to a purpose | Envelope Entitlement | absent | Can entitlement itself be expressed as neutral value movement in a distinct capacity coordinate, or does it earn a dedicated fact family? Compare both in Alloy. | high |
| Reallocate spending capacity | Entitlement transfer | absent | If entitlement is movement-shaped, do grant / reallocation / release emerge from endpoint relations instead of operation kinds? | high |
| Observe consumption of capacity | Envelope Consumption | absent | Can consumption be projected from ordinary Movement + explicit routing, with no duplicate "spent" fact? | high |
| Reserve capacity for future obligations | Envelope Commitment | absent | Can commitment be derived entirely from open scheduled occurrences + routing? Keep it projection-only if possible. | high |
| Know remaining and truly free envelope capacity | Remaining / Headroom | absent | `Remaining = entitlement - consumption - fulfillment`; `Headroom = Remaining - Commitment` is already a projection pattern in HRA/h-kernel. Test what retained evidence is minimally sufficient in LOAM. | high |
| Use envelopes for savings / investment / non-expense goals | Fulfillment routing | absent | Does intent belong to a relation from scheduled identity to purpose, rather than destination-Locus inference? | after scheduled + envelope |
| Know whether envelope promises are actually funded | Backing pools / under-backed evidence | absent | Backing is orthogonal to capacity. Test whether two small routing relations plus current holdings and commitments are sufficient, without an Account/Envelope object graph. | after basic envelope |
| Reallocate an overrun | Entitlement transfer / Envelope TUI | absent | User operation should be "move capacity from here to there". Determine whether this can reuse the same movement interaction while retaining a separate semantic coordinate. | high dogfood |
| Show spending pace through the current cycle | Cycle Spending Pace / Daily Target scope | absent | Derive pace from explicit eligible holdings, selected obligations, cycle interval, and exact remainder. Do not infer permission from Backing surplus. | after cycle + schedule |
| Keep attention items that are not yet financial facts | Issue | absent | Can an attention item be a small identity + text/status/due coordinate with explicit relations to scheduled/actual evidence, without importing a broad Issue ontology? | high after schedule |
| Due date: known / none / undecided | Issue temporal state | absent | Preserve the three-way distinction only if it changes presentation or behavior. Do not collapse unknown and no-date. | issue observation |
| Turn an attention item into actual evidence | Issue realization | absent | What is the minimum explicit relation from attention identity to Movement identity? Avoid reconstructing relation from memo/text. | issue observation |
| Track refund / subscription / want / budget-shortage concerns | Issue workflows | absent | Are these different Issue kinds, tags, relations, or merely user-facing views over facts? Add only distinctions that alter operations. | later dogfood |
| Balance Sheet | report | current balance view only | Which Locus-role relations are the minimum needed to partition holdings into the requested statement? Do not import the whole Account taxonomy in advance. | later |
| Profit & Loss | report | absent | Can flow classification be explicit query-scoped routing over Movement effects? Determine whether Income/Expense roles are needed as durable history. | later |
| Daily Flow | report | recorded-day projection exists | Extend from external shadow to LOAM-owned dated evidence only when the date meaning is earned. Keep sparse activity-day projection if useful. | later |
| Monthly Accounts | report | absent | Projection over dated effects + selected Loci; Month need not be primitive. | later |
| Envelope Budget health view | report | absent | Compose independently owned capacity and Backing observations. Do not store a duplicate report state. | after envelope |
| Planned Payments | report | scheduled-day only | Projection over open scheduled evidence with overdue/upcoming states. | after schedule |
| Open Issues | report | absent | Projection over open attention evidence. | after issue |
| One useful home screen | calendar-first Home | terminal menu + shadow day composition | Home should compose existing observations, not own a new household model. | after next semantic slices |
| Fast keyboard interaction | Brick TUI / HRA TUI | line menu + live hint | Grow terminal primitives only from repeated friction: Tab accept, picker, focus, list navigation, partial redraw. | continuous |
| Mouse / scroll / large report navigation | HRA/h-kernel TUI | absent | Presentation capability only. Keep it outside domain semantics. | later UI |
| Exact multi-Commodity arithmetic | Money / Balance | Measure + exact Quantity | Preserve distinct measures and forbid implicit conversion. Only add valuation evidence when a concrete question needs it. | established / continue |
| Market valuation / acquisition / disposal provenance | accounting observations | observed formally in LOAM experiments, not practical UI | Keep separate from native quantities. Bring back only when investment dogfood needs it. | deferred |
| Safe publication under concurrent/stale source changes | named writer preparation/publication | writer ownership and append-oriented persistence slices | Preserve stale rejection, admission-before-publication, and post-write verification as capabilities. Do not copy the eight-source filesystem architecture wholesale. | continuous |
| Read-only AI household consultation | h-kernel concierge | absent | This is a delivery surface, not a Core primitive. Revisit after stable household observations exist. | deferred |

## Proposed compression chapters

The inventory suggests a dependency order based on questions, not familiar domain nouns.

### Chapter A: scheduled occurrence and lifecycle

Questions:

1. What minimal facts distinguish a future expectation from a Movement that already happened?
2. Is `scheduled identity + day + effects` sufficient before lifecycle evidence?
3. Which of completion, retirement, reschedule, successor, recurrence must be distinct relations?
4. Can overdue / upcoming / selected-day / planned-payments all be projections over the same small evidence?
5. Can actual completion reference a Movement without changing or replacing the scheduled fact?

Use Alloy first for bounded alternative structures and counterexamples. Use Lean only after a small law has earned general proof value.

### Chapter B: household time coordinates

Questions:

1. Can selected day, observed-through horizon, cycle interval, and month interval remain query coordinates rather than Event fields?
2. Which historical questions truly require a date attached to LOAM-owned evidence?
3. Can one explicit occurrence-date relation preserve Core Event timelessness?
4. Does correction change recorded date, effective date, neither, or require separate coordinates?

Alloy should compare candidate coordinate models before practical persistence changes.

### Chapter C: capacity / Envelope without importing Budget

Questions:

1. Can entitlement use the same generic Event/Effect shape on a distinct capacity coordinate, or does that conflate dimensions that later queries must distinguish?
2. Can grant, reallocation, and release be projections from endpoints rather than stored operation kinds?
3. Can consumption be derived from ordinary Movement plus routing?
4. Can commitment be derived from open scheduled evidence plus routing?
5. Are Remaining and Headroom always projections?
6. What minimal stable purpose identity and routing history are required so current configuration never rewrites the past?
7. Can Backing be added orthogonally through small pool-routing relations rather than an Account/Envelope graph?

This chapter should use Alloy heavily before any new canonical fact family is admitted.

### Chapter D: attention / Issue as relations around facts

Questions:

1. What information exists even when no Movement or scheduled occurrence exists yet?
2. Which due states are observationally distinct?
3. Can realization / planning / withdrawal be explicit relations to existing identities?
4. Are issue "kinds" needed, or can views and relations cover the current household cases?

Start from actual HRA/h-kernel Issue dogfood examples, but do not import their current relation vocabulary by default.

### Chapter E: statements and household views

Questions:

1. Which reports require durable classification, and which only need replaceable query configuration?
2. Can Balance Sheet and P&L be obtained from explicit Locus-role history without turning Locus into Account?
3. Can Daily / Monthly / Cycle reports share small temporal projections rather than one Report domain?
4. Can Home remain terminal composition over independent answers?

Reports should earn facts only when the requested answer cannot be reconstructed safely from existing evidence.

### Chapter F: interaction layer

Only after the underlying answers exist:

- completion acceptance / picker;
- visible-object operations instead of identity recall;
- calendar focus;
- keyboard navigation;
- mouse and scrolling;
- report navigation.

A generic Brick clone is not a prerequisite. Extract terminal primitives only after LOAM repeats the same interaction law enough times to justify them.

## What not to copy into LOAM by default

These are implementation or source-shape choices in HRA / h-kernel, not automatically LOAM capabilities:

- the eight-file canonical Household topology;
- Account / Transaction / Plan / Envelope / Issue as mandatory Core types;
- AccountType enum as the universal interpretation of every Locus;
- separate spend / income / transfer verbs;
- Budget as an intermediate state;
- a generic repository/session/framework layer;
- a universal relation graph or event framework;
- HRA's package decomposition or h-kernel's module decomposition;
- report sections as stored canonical facts;
- current presentation labels as historical authority;
- compatibility aliases for retired representations.

## Working rule for the next observations

For each row marked `next` or `high`:

```text
useful household question
  -> smallest source evidence that can answer it
  -> at least two candidate representations
  -> Alloy counterexample search
  -> choose the smaller representation only if it preserves the answer
  -> practical Lean adapter / projection
  -> synthetic qualification
  -> private real-data dogfood
  -> only then consider a new canonical fact family or UI surface
```

The first proposed chapter is **scheduled occurrence and lifecycle**, because it unlocks upcoming / overdue obligations, completion, commitment, cycle pace, calendar usefulness, and later Issue relations without requiring Envelope or Issue to be designed first.
