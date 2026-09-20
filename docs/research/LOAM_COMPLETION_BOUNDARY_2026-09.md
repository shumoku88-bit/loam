# LOAM completion boundary — 2026-09-20

Status: **design checkpoint**

Baseline:

```text
main: af3f198b343de2e9d8d8c9f19a503a71c24386cc
```

## Question

LOAM now has a stable operational authority, ordinary recording, correction and
lifecycle paths, multiple Measure recording, scheduled evidence, reports,
machine-readable proposal transport, and conservative Plain Text Accounting
projections.

The remaining design question is no longer:

> What other household features can be added?

It is:

> What must still belong to LOAM itself before the system can be considered
> complete enough to use, maintain lightly, or leave dormant?

## Completion rule

LOAM is complete enough for ordinary household use when all four of these
properties hold:

```text
retain household facts safely
        +
answer current household questions from admitted evidence
        +
accept new facts through qualified write boundaries
        +
leave through conservative external projections
```

Completion does **not** require LOAM to own every presentation, report, chart,
importer, financial calculation, or future user interface.

The desired shape is:

```text
                    +-> TUI
                    |
canonical LOAM -----+-> semantic Reviews -> reports
authority            |
                    +-> AI reader / proposal surfaces
                    |
                    +-> PTA / Beancount / other disposable projections
```

The center is durable. The edges may be replaced.

## 1. Canonical household authority — COMPLETE

Operational household meaning remains in LOAM authority and its explicit
supporting evidence.

Current answers are reconstructed through qualified correction, validity,
replacement, lifecycle, relation, and review boundaries. Projection output does
not write back into authority.

No additional generic database, cache, report store, or frontend-owned state is
required for completion.

Reopen this area only when a real household fact cannot be represented or
reconstructed without retaining a new kind of evidence.

## 2. Ordinary recording and correction — COMPLETE

The practical Movement entrance now supports one arbitrary exact Measure per
movement, with `jpy` as the default.

Examples:

```text
paypay      -2470 jpy
books       +2470 jpy
```

and:

```text
usd-wallet    -25 usd
food          +25 usd
```

use the same production law.

Correction preserves the selected Measure and currentness remains owned by the
existing correction frontier.

Do not introduce TransactionKind, Currency, Purchase, Transfer, or Income as
new retained primitives merely because they are familiar product vocabulary.

## 3. Reports and UI — EXTERNALIZATION PREFERRED

LOAM should keep reports whose answer depends on LOAM-specific evidence or
qualified semantics.

It should not reproduce mature presentation systems merely to keep all viewing
inside one executable.

The design preference is:

```text
LOAM-specific semantic question
    -> LOAM Review / report

ordinary accounting presentation
    -> conservative projection
    -> PTA / Beancount / Fava / another replaceable viewer
```

A report becoming convenient does not make its representation authoritative.

Future web, GUI, or alternate TUI work is therefore optional presentation work,
not a completion requirement.

## 4. AI boundary — SEMANTICALLY COMPLETE, PRODUCT SURFACE OPTIONAL

The existing write direction already has the important boundary:

```text
external observation
  -> frontend / AI interpretation
  -> LOAM-MOVEMENT-PROPOSAL
  -> parse
  -> current-world review
  -> human-visible proposal
  -> explicit acceptance
  -> HouseholdCommand
  -> authoritative re-read
  -> publication or refusal
```

This is enough semantic structure for an AI writer.

The reader direction should reuse existing query-specific Review boundaries.
Do not create an AI-specific shadow household model or a generic
`HouseholdQuery` umbrella merely to make model integration look uniform.

A future MCP, local agent, or web adapter is therefore an interface project, not
new accounting semantics.

## 5. Portability and retirement — COMPLETE AS A ONE-WAY ESCAPE CONTRACT

A durable household program needs a safe ending.

LOAM's escape contract is deliberately asymmetric:

```text
LOAM authority
    |
    +-> PTA / Ledger / hledger-shaped projection
    |
    +-> Beancount / Fava projection
    |
    +-> future conservative exporters
```

These outputs may be lossy with respect to richer LOAM provenance, but they must
preserve the accounting facts they claim to represent and refuse unsupported
semantics rather than invent them.

This means a future user does not need to keep maintaining LOAM merely to retain
access to ordinary accounting history.

A bidirectional importer or perfect round trip is **not** required for this
property.

The survival requirement is weaker and more useful:

> If LOAM becomes inconvenient or unmaintainable, ordinary household accounting
> can be exported in a documented, independently usable form without converting
> the exported file into a second authority while LOAM is still in use.

## 6. Operational failure and recovery — COMPLETE ENOUGH

Fail-closed startup diagnosis already distinguishes an unreadable authority from
an empty household state and keeps the exact technical reason visible.

LOAM should prefer:

```text
cannot verify
    -> stop
    -> diagnose
    -> restore / migrate through a qualified path
```

over automatic repair that manufactures household meaning.

More recovery automation is optional unless a concrete failure mode repeatedly
makes safe recovery impractical.

## 7. The one remaining semantic frontier: cross-Measure exchange

This is the main known household operation that ordinary Movement intentionally
does not yet represent.

For example:

```text
gave       15000 jpy
received     100 usd
```

must not be admitted merely because the two legs belong to one real-world
exchange. Unlike Measures do not cancel arithmetically.

A production exchange boundary must answer, without smuggling valuation into
quantity:

- which exact quantity left;
- which exact quantity arrived;
- which retained fact says those legs belong to one exchange;
- when the exchange occurred or settled;
- whether a separate fee exists;
- whether any rate is observed, derived, quoted, or absent;
- whether later valuation uses independent evidence.

The exchange observation must not silently become:

- a timeless market FX rate;
- current valuation;
- acquisition basis;
- tax basis;
- realised gain / loss;
- an excuse to weaken per-Measure balance for every ordinary Event.

### Design options still open

There are two credible families and neither should be selected without real use
pressure.

#### A. Dedicated exchange evidence

Retain a separate Exchange / Conversion observation whose legs are exact
Measure quantities, then extend the relevant quantity/accounting projections to
consume that evidence explicitly.

Advantages:

- states the real cross-Measure fact directly;
- no synthetic clearing balance;
- rate can remain optional / derived.

Cost:

- creates a new retained evidence family;
- quantity and accounting Reviews must explicitly learn how it contributes.

#### B. Linked ordinary movements plus qualified bridge semantics

Keep each physical leg inside the existing single-Measure Movement world and add
explicit evidence that selected bridge effects form one exchange.

Advantages:

- maximally reuses existing Movement publication and persistence.

Cost:

- bridge effects / loci can pollute balances or accounting projections unless
  their semantics are made explicit;
- a clearing account workaround is unsafe if it is introduced only to satisfy
  the balance checker.

### Current decision

**Do not implement either yet.**

The first real exchange should be used as the qualification specimen. The
smallest design that can faithfully record that specimen without corrupting
existing reports should win.

This is a deferred semantic frontier, not evidence that LOAM is incomplete for
current ordinary household use.

## 8. Decimal display is not a Core blocker

Exact Quantity currently stores integral quanta.

If a future Measure needs a presentation such as:

```text
10025 quanta -> 100.25 USD
```

a scale / display convention may be added at the presentation boundary.

Do not put decimal formatting or currency metadata into Event / Effect merely
because a UI wants familiar notation.

## 9. Things completion explicitly does not require

Do not keep development alive merely to add:

- more dashboards;
- a second report engine duplicating Fava;
- automatic FX market feeds;
- investment portfolio accounting;
- tax accounting;
- every possible external importer;
- bidirectional PTA synchronization;
- a generic plugin framework;
- an AI-specific duplicate semantic model;
- automatic repair of malformed authority;
- support for every accounting application before anyone needs it.

Each may become legitimate under future pressure. None is a present completion
obligation.

## 10. Dormant-mode maintenance contract

A completed LOAM should tolerate periods where no feature development occurs.

During such periods the useful maintenance loop is small:

```text
use it
  |
  +-> household fact cannot be represented?
  |      -> semantic design work
  |
  +-> current workflow is awkward?
  |      -> UI / adapter work
  |
  +-> external projection loses required meaning?
  |      -> exporter obligation
  |
  +-> dependency / toolchain breaks?
         -> compatibility maintenance

otherwise
  -> do nothing
```

"Nothing to change" is a valid successful state.

## Completion verdict

For the currently exercised household scope, LOAM can reasonably be treated as
**feature-complete enough to enter dormant maintenance** once the active
Beancount / Fava projection experiment is either merged or deliberately closed.

The known semantic frontier is cross-Measure exchange. It should remain a named
deferred boundary until actual use supplies a concrete specimen.

Everything else should be reopened from observed pressure rather than from an
abstract desire for completeness.
