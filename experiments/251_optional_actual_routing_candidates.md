# Observation 251 — Optional non-Expense Actual routing candidates

Status: **ACTIVE PROBE — production semantics unchanged**

Baseline:

```text
Observation 250 head
cfa9390b5575376ca3d22b021d3483cb209d3659
```

## Question

Observation 250 showed that an ordinary Purpose plus signed Event-valid Actual routing already models current-cycle savings/investment contribution without a new Purpose kind.

The practical TUI seam is narrower: `ActualRoutingPublisher` accepts any Locus, but `ActualRoutingReview` and its administration surface intentionally enumerate only explicit Expense Loci.

Can non-Expense Loci be made deliberately routable without turning every Asset/Income/Liability into a required routing obligation?

## Candidate boundary

Use two read-only candidate projections over the same current Locus admission, AccountingRole and Actual-routing evidence:

```text
default candidates
  = admitted Loci with AccountingRole.expense

optional candidates
  = admitted Loci with a known non-Expense AccountingRole
```

Unknown-role Loci remain a separate audit frontier. Historical routes whose Locus is no longer admitted remain historical-only. Optional unrouted rows do **not** contribute to the default unrouted warning count.

This preserves the existing Expense administration contract while making deliberate Asset/Income/Liability routing reachable from a separate user action.

## Why this is not RoutingRequired

An optional Asset such as `yucho` being unrouted is not itself an error. The household may never intend that Asset to participate in a Purpose projection.

The user action selecting the optional row supplies the practical routing intent. No retained `RoutingRequired`, `PurposeKind`, savings flag, sign rule, or account-name inference is introduced.

## Effective coordinate

Historical meaning remains explicit. A selected optional row can produce the already-existing `ActualRoutingPublisher.Draft` with either:

```text
initial
```

or an explicit dated coordinate such as:

```text
2026-08-17
```

The TUI must not silently backdate a route. Existing CLI/Publisher semantics already support both forms; a production TUI graduation should expose the same choice rather than fixing all new routes to today.

## Witness cases

The executable probe checks:

- default rows remain Expense-only;
- optional rows contain admitted known Asset/Income/Liability coordinates;
- an unrouted optional Asset is visible but does not increase the default warning count;
- an existing managed Asset route is visible in optional administration;
- unknown AccountingRole remains separately unresolved;
- historical-only non-admitted routes do not become current optional candidates;
- a savings Asset can form an explicit dated managed draft;
- an investment Asset can form an explicit initial managed draft.

## Deliberate omissions

- no production Review/TUI change yet
- no new Core type or Purpose taxonomy
- no canonical-data mutation
- no retained optional-selection state
- no automatic Asset routing
- no rule that optional unrouted rows are blockers
- no retroactive routing inference

## Graduation gate

If this probe qualifies, the smallest production change is:

1. preserve the existing Expense list and its unrouted audit;
2. add a separate `Other admitted loci` picker for known non-Expense roles;
3. display AccountingRole beside those optional rows;
4. let the user explicitly choose `initial` or a valid `YYYY-MM-DD` effective coordinate;
5. delegate unchanged to `ActualRoutingPublisher` / `HouseholdCommand.routeActual`.

No general Answerability framework or Purpose kind follows from this UI improvement.
