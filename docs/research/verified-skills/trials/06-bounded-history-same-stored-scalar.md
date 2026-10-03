# Trial 06 — Bounded history versus same stored scalar

Status: **paired trial complete / result: SAME / final CurrentQuantityAnchor skill evaluation**

Pinned repository revision:

```text
c376a6566f1ffe9af39d85c3afa79a71b27f35ec
```

## Sealed task

Audit a coordinate with:

```text
CurrentQuantityAnchor
  reflected roots = [E0]
  retained assertion = -100

BoundedHistorySupport
  active for the same coordinate
```

After the anchor observation, a new stable Event `E1` contributes `-20`, so the
ordinary correction-aware current quantity may differ from the old retained
assertion.

The household then freshly observes `-100`, numerically equal to the old stored
assertion, and attempts ordinary CurrentQuantityAnchor publication.

The task asks whether bounded historical support compares the new observation
against the old stored scalar or against the correction-aware current answer, and
what authority / repair / publication semantics follow.

The baseline and skill arm were launched from separately sealed branch prompts
before either result was disclosed to the shared evaluator. Both reported
**CLEAN** isolation.

## Candidate skill

`docs/research/verified-skills/current-quantity-anchor.md`

## Shared conclusion

Both arms independently reached the same decisive result.

The old retained anchor assertion is not itself the current answer. Its
`reflectedRoots = [E0]` cut means later stable root `E1` remains in the
correction-aware delta frontier.

Therefore immediately before the fresh observation:

```text
stored assertion  = -100
unreflected E1    =  -20
current quantity  = -120
```

`BoundedHistorySupport` stores only:

```text
coordinate
startDay
```

and claims that all real quantity changes from that calendar-day boundary onward
are represented by dated, correction-aware Actual evidence. It does not store a
current quantity, opening quantity, anchor identity, reconciliation identity,
correction graph, or report state.

The CurrentQuantityAnchor publication guard therefore compares:

```text
fresh observed scalar
        versus
CurrentQuantityAnchor.inspectQuantity(...)
```

not the fresh scalar versus the old retained assertion.

For this trial:

```text
fresh observation = -100
current answer     = -120
```

so publication is refused while bounded historical support remains active.

Numerical equality between the fresh observation and the old stored assertion has
no special authority.

If the fresh observation is instead `-120`, the bounded-history guard passes.
The ordinary anchor update then moves the coordinate to a fresh reconciliation
group carrying the current stable-root cut, conceptually:

```text
reflected roots = [E0, E1, ...current roots]
assertion       = -120
```

No anchor revision history or historical observation record is created.

## Repair semantics

Both arms independently identified the same authority-specific repair choices.

If retained Actual is wrong, repair Actual through its ordinary correction path.
If the historical completeness claim is no longer justified, remove the
coordinate's bounded historical support before reconciling and, if justified
later, add a new support start separately.

A subtle existing UX/documentation edge was also found by both arms:
the CurrentQuantityAnchor publisher error text says to "move/remove the historical
start", but moving `startDay` alone does not unblock a current-quantity mismatch.
The guard checks whether bounded support exists for the coordinate; it does not
use `startDay` to decide current scalar agreement.

Therefore a mismatch is resolved by making the correction-aware current answer
agree, or by removing bounded support during reconciliation. Silent anchor
rebasing is not a repair path.

After bounded support is explicitly removed, a later successful exact observation
creates only current exact anchor support. It does not recreate historical
completeness, zero-origin completeness, opening support, or anchor history.

## Publication topology

Both arms reconstructed the same publication order:

```text
acquire Actual ownership
  -> acquire CurrentQuantityAnchor ownership
    -> acquire CurrentQuantityPresence ownership
      -> acquire BoundedHistorySupport ownership

load authorities
  -> validateBoundedHistoryReobservation
  -> proposeUpdate?
  -> refinePresenceForExact?
  -> write refined presence if needed
  -> write anchor
```

The bounded-history guard therefore runs before anchor replacement, presence
refinement, or any file write.

The explicit ownership interval makes the Actual, retained anchor, and bounded
history images coherent for this admission check. No generic multi-authority
transaction layer is earned by this seam.

Per-file replacement remains sibling-stage + rename. The broader Presence ->
Anchor write sequence deliberately prefers temporary support loss over
contradictory overlapping support if the second write fails.

## Concrete falsifiers

Both arms converged on the same useful falsifiers.

The implementation is wrong if any of these hold:

1. `-100 @ [E0]`, later `E1 = -20`, bounded support active, and a fresh
   observation `-100` is accepted.
2. The same fixture refuses a fresh observation `-120`.
3. A refused bounded-history mismatch mutates Anchor or Presence before returning
   the refusal.
4. Removing bounded support alone causes anchor evidence to become historical
   completeness.
5. Malformed bounded support is treated as empty and publication continues.

These distinguish retained scalar equality from correction-aware current
authority directly.

## Qualification conclusion

Both arms selected the same smallest missing direct qualification.

Existing executable evidence already covers the two component laws:

- `Loam/Tests/CurrentQuantityAnchor.lean` verifies that later unreflected Event
  evidence changes the correction-aware current quantity derived from an older
  anchor.
- `Loam/Tests/BoundedHistorySupport.lean` verifies that bounded support permits
  a matching current observation, refuses a differing current observation, and
  allows differing reconciliation after explicit support removal.
- historical review tests and existing Alloy work separately qualify
  correction-aware backward reconstruction and the fact that endpoint equality
  is not historical completeness.

What is not directly pinned by one focused executable fixture is the exact
composition:

```text
old stored assertion = -100
later unreflected delta = -20
derived current = -120
fresh observation = old stored assertion = -100
bounded support active
=> refuse
```

Both arms therefore judged that one focused executable regression would be
justified if this seam is to be fixed directly in the test suite.

Neither arm found a need for a new Lean theorem, Alloy model, TLA+ model,
historical quantity cache, generic support framework, anchor revision graph, or
generic transaction layer.

No implementation change was performed during either audit.

## Baseline path

The clean baseline inspected ordinary repository guidance first, then the exact
current-quantity owner, bounded-history owner, publication boundary, persistence,
historical review, focused tests, and existing Alloy evidence.

It also noticed that an older CurrentQuantityAnchor research DAG no longer
describes the full current Presence / BoundedHistory locking topology and
correctly preferred pinned production source for the present boundary.

Recorded materially wrong analytical path / backtracking:

```text
0
```

The baseline independently found:

- the `-120` current quantity;
- comparison against correction-aware current rather than old stored scalar;
- refusal of fresh `-100`;
- acceptance of fresh `-120`;
- the same repair semantics;
- the same error-text nuance;
- the same focused executable regression;
- no need for new formal machinery.

## Skill-arm path

The clean skill arm followed the candidate procedure through the narrow semantic
owners, correction-aware retained evidence, the bounded-history neighbor,
publication/persistence ordering, concrete falsifiers, and smallest
qualification.

Recorded materially wrong analytical path / backtracking:

```text
0
```

The procedure made the stored-`-100` versus derived-`-120` distinction
explicit early and kept displayed/input scalars from becoming accidental second
authority.

However, the baseline independently reached the same semantic answer, the same
repair boundary, the same topology conclusion, and the same qualification
recommendation without candidate skill access.

The skill arm encountered one non-material research-reference mismatch and
discarded it immediately rather than using it as evidence. This did not require a
material analytical reversal.

## Paired result

```text
Result: SAME
```

There is no material difference that earns a promotion win.

Both clean arms:

- selected the same semantic owners;
- derived `-120` from the old anchor plus later Actual delta;
- compared fresh observation against correction-aware current;
- refused `-100` and accepted `-120` under bounded support;
- preserved the same authority and repair boundaries;
- reconstructed the same publication ordering;
- found the same error-text nuance;
- selected the same focused executable regression;
- rejected unnecessary new formal machinery;
- reported zero materially wrong analytical backtracks.

## Experimental accounting

```text
Trial: 06
Date: 2026-10-03
Repository revision: c376a6566f1ffe9af39d85c3afa79a71b27f35ec
Task: BoundedHistorySupport active while fresh observation equals old stored
      anchor scalar but differs from correction-aware current quantity
Skill: CurrentQuantityAnchor change audit
Baseline outcome: CLEAN; correct scoped semantics; 0 material backtracks;
                  selected one focused executable regression as the smallest
                  additional direct qualification
Skill outcome: CLEAN; correct scoped semantics; 0 material backtracks;
               selected the same focused executable regression and authority
               boundary
Material difference: SAME
Regression observed: None
Skill mutation: None
Protocol mutation: None
Disposition: Trialed
Promotion evidence: 0 wins counted from Trial 06
```

## Final CurrentQuantityAnchor skill evaluation

Trial 06 closes the planned promotion experiment for this candidate.

Counted evidence is:

```text
Trial 03   clean paired   BETTER    1 win
Trial 04   contaminated   UNSCORED  0 wins
Trial 05   clean paired   SAME      0 wins
Trial 06   clean paired   SAME      0 wins
```

Promotion-rule accounting:

```text
comparable scored trials           3   SATISFIED
clean held-out sibling trials      2   SATISFIED
material improvements              1   NOT SATISFIED (requires >= 2)
serious semantic regressions       0   SATISFIED
improvement beyond more checks     yes for Trial 03
skill smaller than routed evidence yes
```

Therefore the skill is **not Qualified**.

It is also not retired: one clean paired trial showed a material routing
improvement, no scored trial showed a semantic regression, and the procedure
remains a small useful checklist.

Final disposition:

```text
Lifecycle: Trialed
Evaluation: CLOSED
Promotion wins: 1
Scored regressions: 0
Further promotion trials: not planned
```

The evidence supports a narrower conclusion:

> The CurrentQuantityAnchor skill is non-disruptive and can improve routing on
> some tasks, but this experiment did not show a repeatable material advantage
> over ordinary LOAM repository evidence.

Reopen the evaluation only if repository ownership changes materially, a new
concrete failure exposes a missing reusable skill step, or a substantially
different evaluation protocol creates a new question worth measuring.
