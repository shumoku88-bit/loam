# G2-020 — Current quantity anchor Locus-admission obligation DAG

Status: **Generation-2 audit evidence — FIX CANDIDATE**

Primary instruments: **DRAKONview + cross-generation policy audit + source reachability + regression qualification**.

## Question

`CurrentQuantityAnchor` was added after Observation 212 established one explicit `LocusAdmissionVocabulary` for deciding which `LocusId` values may appear in newly published quantity-bearing canonical evidence.

The anchor writer is itself a later quantity-bearing canonical writer, but before G2-020 its publication path did not read the current admission authority at all:

```text
human / CLI assertion
  Locus × Measure × Quantity
        |
        v
CurrentQuantityAnchorPublisher.propose?
        |
        +-- support overlap checks
        +-- correction-root cut
        +-- coordinate uniqueness
        |
        v
persist current-quantity-anchor.loam
```

A valid token was enough to create a new anchored coordinate.

The audit asks whether that freedom is independently meaningful observation semantics, or whether it bypasses the already-qualified new-write vocabulary.

## Earlier law that predates the writer

Observation 212 separated:

```text
historically referenced Loci
!=
Loci approved for new publication
```

and qualified the narrow policy:

> A new quantity-bearing canonical write may use this `LocusId`.

The practical safety pressure was precisely that a free-text typo must not silently create a second canonical identity.

The current `LocusCatalog` still documents `LocusAdmissionVocabulary` as the authority for Locus identities that may appear in a new quantity-bearing write. Display metadata may be broader so historical/read-only identities remain readable without re-admission.

CurrentQuantityAnchor arrived later through Observation 246 / PR #824 and therefore must be checked against that older publication law rather than assumed to inherit it automatically.

## Counterexample before G2-020

Suppose current admission contains:

```text
debt
cash
```

A reconciliation editor may accidentally type:

```text
detb
```

Before G2-020:

```text
validToken("detb")                    true
zero/opening support overlap           false
correction frontier                     admitted
coordinate uniqueness                   true
```

so the anchor is published successfully.

That is not presentation-only fallout. The new coordinate can subsequently:

- enter the RoleBalance coordinate universe;
- carry an exact current quantity;
- make `AccountingRolePublisher` treat the Locus as already quantity-bearing evidence under G2-015 virginity rules;
- persist as canonical reconciliation evidence.

The typo therefore crosses a semantic boundary that Observation 212 was created to prevent.

## Why this does not make current admission a read filter

The fix belongs only to **new publication**.

`CurrentQuantityAnchor.Evidence` remains structurally independent of current Locus admission. An older anchor may mention a Locus that is later removed from new-write permission and must remain readable just as historical Actual evidence remains readable.

So the required distinction is:

```text
retained anchor evidence
  -> readable regardless of current admission

new anchor publication
  -> every assertion Locus currently admitted
```

This preserves the historical/read-only boundary from Observation 212.

## Minimal production repair

`CurrentQuantityAnchorPublisher.propose?` now receives the current `LocusAdmissionVocabulary` and refuses when any assertion uses an unapproved Locus:

```text
assertions.all (fun assertion =>
  locusAdmission.allows assertion.coordinate.locus)
```

`publishUnderOwnership` re-reads the canonical authority with:

```text
LocusAdmissionAuthority.loadCurrent? root
```

before proposing the replacement anchor image.

No Core anchor type, persistence format, RoleBalance logic, correction-root arithmetic, TUI state model, or AccountingRole semantics changes.

## Why no Locus-policy lock is added

The current production mutation path for `LocusAdmissionVocabulary` is `LocusAdmissionPublisher.publishAdmission`, which is add-only.

Repository-wide caller inspection shows direct full-image `LocusAdmissionAuthority.publishCurrent?` use only in tests / fixtures, not a production policy replacement entrance.

Therefore during anchor publication a concurrent production policy change can only add permission:

```text
anchor reads before concurrent add
  -> may refuse conservatively
  -> retry can succeed

anchor reads after concurrent add
  -> may succeed
```

No currently reachable production writer can revoke a permission after the anchor observes it. Adding a Locus-policy writer lock today would therefore enlarge ownership topology without protecting a reachable success-then-revocation race.

If production revocation or whole-vocabulary replacement is later introduced, G2-020 ownership must be reopened.

## Why historical-only Loci are not auto-admitted

A historical/read-only Locus is intentionally distinct from current new-write permission. CurrentQuantityAnchor does not infer re-admission from:

- old Actual history;
- display metadata;
- AccountingRole assignment;
- existing old anchor evidence;
- token spelling.

If a historical Locus genuinely needs a new observed-current assertion, the household must first admit that identity explicitly. This keeps the policy decision visible rather than making reconciliation a hidden re-admission channel.

## Obligation DAG

```text
                     new anchor assertion
                            |
                            v
                  valid typed coordinate
                            |
                            v
              current LocusAdmissionVocabulary
                       /            \
                unapproved          approved
                    |                   |
                    v                   v
                 refuse        support-overlap checks
                                        |
                                        v
                              derive correction-root cut
                                        |
                                        v
                              Evidence.ofLists? uniqueness
                                        |
                                        v
                           replace current anchor image

retained old anchor
       |
       +---- does NOT consult current admission
       |
       v
 remains readable
```

## Stop point

G2-020 does **not** add:

- admission state inside `CurrentQuantityAnchor.Evidence`;
- a second known-Locus vocabulary;
- automatic admission from historical Actual;
- automatic admission from AccountingRole or display metadata;
- Locus-policy locking;
- anchor revision history;
- a generic quantity-writer framework.

The one missing obligation is the already-existing current new-write policy gate.

## Qualification target

The existing CurrentQuantityAnchor test should pin both directions:

```text
retained evidence may contain a historical/read-only Locus
new publisher proposal rejects that same unapproved Locus
```

Normal anchor composition must remain unchanged for admitted Loci, including:

- reflected-root cut derivation;
- correction stability;
- zero/opening overlap refusal;
- persistence roundtrip;
- RoleBalance composition;
- Production TUI / CLI publication.

If the direct anchor suite and broader triggered workflows stay green, record:

**G2-020: FIX QUALIFIED — new CurrentQuantityAnchor publication obeys current Locus admission; retained anchor evidence remains historically readable.**
