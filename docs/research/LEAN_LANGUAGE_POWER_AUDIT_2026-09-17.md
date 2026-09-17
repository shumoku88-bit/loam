# LOAM Lean Language Power Audit — 2026-09-17

## Status

Completed against production `main` after the audit implementation series through:

```text
b9c4ae9d41fcf401e8042bcaf01ed4cd432c42a3
refactor(capacity): carry fresh identity across retained evidence (#1035)
```

The audit began from `6bbf3222059a8e3f16ce0b3e04560d232c7dddde` and inspected representative Core, Application, Publisher, Persistence, Review, TUI, test, observation, obligation-DAG, and evidence-atlas paths.

The question was not whether LOAM could use more sophisticated Lean types. The question was:

> Where can a fact that another language would repeatedly validate at runtime, defend with an impossible branch, or re-test by example be stated once as a type, theorem, or proof-carrying value and then removed downstream?

The inverse question was equally important:

> Where would theoremization merely replace a small runtime boundary with a larger proof API, damage useful failure distinctions, or move IO / parsing / persistence concerns into the wrong layer?

## Classification

The census uses these classes:

- **A — TYPE**: the invariant is carried by the value/type itself.
- **B — THEOREM**: the invariant is established by a reusable proof over ordinary values.
- **C — RUNTIME**: the condition is intentionally decided at a runtime/application boundary.
- **D — TEST**: the obligation is best kept as executable qualification, usually because it crosses IO, codecs, filesystems, terminal interaction, or other effects.
- **E — UNGUARDED**: a meaningful invariant has no adequate owner yet.

`KEEP` means that moving the obligation upward into a type/theorem was considered and rejected for this audit.

## Executive result

LOAM already uses Lean's language power substantially. The strongest areas were present before this audit:

1. Core memories carry structural uniqueness as proof fields instead of asking every reader to validate raw lists.
2. `BalancedMovement` carries exact balance as evidence.
3. `Amount measure` indexes values by measure while `SomeAmount` contains the genuinely dynamic boundary.
4. TUI Kernel/Runtime contains refinement theorems relating dense/compiled/dirty-row implementations to simpler specifications.
5. Several semantic laws, including permutation independence and Scheduled positive-side existence, already remove dependence on representation order or duplicated decisions.
6. Fresh numbered identity allocation had already been made total by shrinking a finite namespace rather than using fuel plus `Option` exhaustion.

The main unevenness was at **Publisher seams**. Several publishers received values whose Core structures or allocators already established the relevant invariant, then reintroduced the same fact as a lookup, full-list `Nodup` admission, or defensive `Option` failure.

The audit therefore did not produce a new Lean architecture. It mostly completed proof flow that was already latent in the design.

Nine production PRs were merged as direct audit work: #1026, #1027, #1028, #1029, #1030, #1031, #1032, #1034, and #1035. One promotion, #1033, was deliberately closed without merge. The older rejected Movement prototype #872 was also used as negative evidence.

## Lean Power Census

| # | Representative invariant / law | Class after audit | Audit disposition |
|---:|---|---|---|
| 1 | An `Event` retains each stable `EffectKey` at most once | A — TYPE | `Event.keyNodup` remains the invariant owner |
| 2 | Event quantity projection is independent of Effect representation order | B — THEOREM | `Event.quantityAt_perm`; no positional semantics should leak downstream |
| 3 | `EventMemory` retains unique `EventId`s | A — TYPE | `EventMemory.idNodup`; arbitrary loaded values still use fallible admission |
| 4 | Event lookup is invariant under memory permutation | B — THEOREM | `FiniteKeyed.findBy?_perm` / Event memory law |
| 5 | Recorded quantity projection is invariant under memory permutation | B — THEOREM | Representation order remains storage only |
| 6 | A `BalancedMovement` sums to exact zero | A — TYPE | Continue carrying the balanced value rather than rechecking totals |
| 7 | Same-measure arithmetic is typed by `Amount measure` | A — TYPE | Keep dependent measure index |
| 8 | Two existential `SomeAmount`s may have different measures | A + C — KEEP | Runtime equality/transport is the correct dynamic boundary |
| 9 | `ScheduledMemory` retains unique `ScheduledId`s | A — TYPE | Added proof-carrying fresh append for generated IDs |
| 10 | `CapacityMemory` retains unique `CapacityMovementId`s | A — TYPE | Added proof-carrying fresh append in #1035 |
| 11 | `AttentionMemory` retains unique `AttentionId`s | A — TYPE | Generated-ID append made total in #1026 |
| 12 | An Attention item has at most one closure fact | A — TYPE | Removed duplicate publisher precheck in #1032 |
| 13 | `EventCorrectionMemory` retains unique exact correction edges | A — TYPE | Keep separate from target-currentness / graph semantics |
| 14 | ActualValidity fact references are unique | A — TYPE | Fresh base-fact append used where proof cost amortizes (#1034) |
| 15 | ActualValidity correction edges are unique | A — TYPE | `addCorrection?` remains independently fallible |
| 16 | Event Merchant evidence contains at most one disposition per Event | A — TYPE | Removed redundant `findDisposition?` precheck in #1027 |
| 17 | Merchant evidence refers only to known Events | C — RUNTIME KEEP | Cross-family referential closure remains application admission |
| 18 | Nonempty, nonzero balanced Scheduled movement has a positive side | B — THEOREM | Existing theorem already removed duplicated runtime decision |
| 19 | Production numbered identity allocation terminates without fuel/exhaustion | B / TOTAL DEF | Existing finite-namespace allocator retained |
| 20 | `firstUnusedNumberedToken` returns a token outside the supplied namespace | B — THEOREM | Promoted from experiment to production in #1026 |
| 21 | TUI `Position` remains within bounds | A — TYPE | `Fin` is the correct owner |
| 22 | Pure Screen and DenseScreen cell observations correspond | B — THEOREM | Keep refinement proof |
| 23 | Applying the calculated diff yields the target screen | B — THEOREM | Keep pure correctness theorem |
| 24 | List and Array widget-cell lookups agree | B — THEOREM | Keep representation refinement theorem |
| 25 | Dense render implementation refines its pure specification | B — THEOREM | Keep theorem rather than example-only tests |
| 26 | Compiled widget lookup refines source widget semantics | B — THEOREM | Keep compile/refinement proof |
| 27 | Dirty-row patching preserves the intended screen result | B — THEOREM | Keep optimization correctness proof |
| 28 | Valid multi-coordinate Capacity publication carries exact balance | A + C | Promoted successful validation to `BalancedMovement` in #1028 |
| 29 | Persistence encode/decode and filesystem round trips | D — TEST KEEP | Effects/versioned text/IO remain executable qualification |
| 30 | Persisted/runtime token syntax is valid | C — RUNTIME KEEP | Keep validation at parser/persistence/write boundaries |

No representative high-value invariant ended the audit in class E. That does not mean LOAM has proved every property; it means the sampled production invariants all had an identifiable owner or an intentional runtime/test boundary.

## Production changes made during the audit

### #1026 — production freshness law and Attention total append

The numbered allocator freshness proof already existed in a CSLib correspondence experiment, while production still retained an impossible branch after generating an Attention identity.

The audit:

- promoted `firstUnusedNumberedToken_fresh` into production;
- made the experiment reference the production theorem rather than duplicate a long proof;
- added a proof-carrying `AttentionMemory.addFresh` entrance beside ordinary `add?`;
- kept `freshId : AttentionId` as an ordinary runtime API rather than returning a heavier subtype;
- removed the `fresh Attention identity was unexpectedly rejected` runtime corridor.

This established the preferred pattern: ordinary production values plus adjacent proofs, with the invariant owner consuming the proof.

### #1027 — Merchant duplicate admission

`EventMerchantEvidenceMemory.eventNodup` already owns one-disposition-per-Event. The publisher first performed `findDisposition?` and then called `add?`, deciding the same uniqueness twice.

The precheck was removed. Merchant token validation and target-Event existence remain runtime concerns because they are independent boundary/cross-family obligations.

### #1028 — carry `BalancedMovement` instead of rechecking balance

`validateBalancedDraft` checked the multi-coordinate Capacity draft, after which the publication tail checked nonempty/balance again and then called `BalancedMovement.ofChanges?` for another balance admission.

Validation now returns `BalancedMovement CapacityCoordinate` and the publication tail consumes it directly. `movementForBalancedDraft?` disappeared.

An attempted binary constructor proof was deliberately backed out. The binary path had only one balance admission, so adding proof/API machinery would not remove duplicated work.

### #1029 — Locus admission ownership

The publisher checked membership with `allows`, appended the Locus, and then called `ofLoci?`, which rechecked uniqueness. The membership precheck was removed and `LocusAdmissionVocabulary` became the single duplicate-admission owner.

Token syntax remains runtime validation.

### #1030 — AccountingRole ownership

The publisher called `roleOf?` for a Locus and then rebuilt the map through `ofAssignments?`, which checked the same one-role-per-Locus invariant again.

The admission lookup was removed. Locus admission and retained Actual/Scheduled/anchor usage remain independent cross-family runtime obligations.

### #1031 — Scheduled generated identity

The production numbered-token freshness theorem was carried through shared Scheduled construction.

The audit also extracted `FiniteKeyed.appendFresh_nodup`, because Attention and Scheduled required exactly the same keyed-list representation law. This is the correct level of generality: list/key mechanics are shared, while semantic memories remain separate.

`ScheduledMemory.addFresh` then removed generated-identity collision failure corridors from both Scheduled Creation and Scheduled Replacement.

Replacement-terminal admission remains fallible because endpoint ownership is a different invariant.

### #1032 — Attention closure ownership

`closeUnlocked` queried `findByAttention?` and then called closure-memory `add?`, repeating the same uniqueness decision.

The duplicate lookup was removed. Target Attention existence remains a separate runtime obligation.

### #1034 — Movement fresh identity across direct keyed evidence

Movement's allocator already reserved Event IDs mentioned by Events, ActualValidity facts, descriptions, relation sources, and discharges. The audit first attempted to carry that freshness through Event, Description, and ActualValidity append.

The Event portion was reverted. Making the Event produced by `Event.ofEffects?` carry the requested EventId proof through `admit?` introduced dependent proof plumbing that broke the existing CSLib theorem whose important property is that equal canonical drafts make `admit?` definitionally/equationally easy to rewrite.

The accepted version therefore totalizes only the two direct keyed families where the proof remains compositional:

- `EventDescriptionMemory.addFresh` removes description-wide duplicate admission;
- `ActualValidityHistory.addFreshFact` removes repeated structural fact admission for the generated base fact.

`EventMemory.add?` remains fallible. The reduced design restored the existing CSLib correspondence proof unchanged and passed the full qualification set.

This is an important audit rule: **do not improve one local proof story by making surrounding equational reasoning worse.**

### #1035 — Capacity identity across two retained families

Capacity is the cleaner version of the same idea. The same `CapacityMovementId` is the key in both movement authority and effective-coordinate evidence, so no heterogeneous-reference bridge is needed.

The audit:

- added `CapacityMemory.addFresh`;
- added `CapacityEffectiveMemory.addFresh`;
- named the combined allocator namespace once;
- proved the generated ID is outside that namespace;
- split that fact across the two retained families;
- removed both generated-identity `Option` corridors.

The result removes two whole-list `Nodup` admissions from every successful Capacity publication while keeping persistence, incomplete-evidence recovery, entitlement, date/token, and ownership checks at runtime.

## Negative evidence and rejected promotions

### #1033 — ActualValidity fresh revision append

This PR was closed without merge.

The target branch was theoretically unreachable: a fresh generated revision identity could prove the first `addFact?` admission succeeds. But the retained fact-reference vocabulary is heterogeneous (`root` and `revision`), and bridging the allocator's revision-token namespace into that structure grew to `+68 / -9` for one removed branch.

That failed the audit's cost rule. The Core entrance was later reintroduced in #1034, where one shared fresh Event identity paid for multiple downstream obligations.

This demonstrates that a theorem may be true and still be a bad production promotion.

### #872 — earlier Movement freshness prototype

The pre-audit prototype attempted to remove three Movement append failures and grew to roughly `+209 / -22`. It included String-token-to-EventId proof plumbing, heterogeneous ActualValidity reasoning, and proof-carrying handling of the Event returned from `Event.ofEffects?`.

It was correctly rejected at the time.

The later audit did not simply reverse that verdict. Shared production freshness laws and `FiniteKeyed.appendFresh_nodup` reduced the cost substantially, and #1034 intentionally accepted only the two parts that remained compositional. The problematic Event portion stayed rejected.

This is useful longitudinal evidence: better proof infrastructure can change the economics of an old idea, but the old idea should still be narrowed to the parts that now earn their weight.

## Runtime/test obligations deliberately retained

The following classes should not be targeted merely to increase theorem count.

### Persistence, codecs, filesystems, and terminal interaction

Versioned text decoding, malformed persisted tokens, encode/decode round trips, atomic/fail-closed publication behavior, filesystem errors, writer ownership, and TUI interaction remain runtime/test concerns.

For example, OpeningSupport and CurrentQuantityAnchor persistence round-trip tests exercise real representation boundaries. A theorem over an in-memory encoder/decoder pair would not replace the IO/version compatibility obligation those tests provide.

### Cross-family referential closure

Examples include Merchant evidence referring to an existing Event and other retained families whose raw Core memory intentionally permits temporarily dangling evidence. These are application/world obligations, not necessarily fields that should be forced into every Core value.

### Actual Reversal

Reversal target uniqueness and reversal-event uniqueness are distinct, and the raw Core model intentionally permits relation-first/dangling evidence so malformed or interrupted states can remain observable. Prechecks therefore encode meaningful refusal distinctions; collapsing them into a single total append would erase information.

### Scheduled terminal replacement

`replacementFor?` checks the source side, but `ScheduledTerminalMemory.add?` also protects replacement-target uniqueness. A generated replacement ScheduledId is fresh in `ScheduledMemory`, but raw terminal evidence may still contain a dangling replacement target not present in that memory. The final terminal admission is therefore genuinely fallible.

### Correction publication

`freshReplacementId` currently reserves retained Events, not every EventId-bearing family. Freshness in EventMemory alone does not prove the replacement ID is fresh in validity/description/correction worlds. Do not totalize those downstream appends without an independently earned cross-family invariant or allocator namespace change.

### Scheduled completion

The completion EventId is deterministic and Event absence is checked, but other retained families may contain independently malformed/dangling evidence. Event absence alone is not a proof of whole-world freshness.

### Dynamic existential measure boundaries

`SomeAmount` is deliberately dynamic. Its measure comparison/transport belongs at runtime before operations enter the indexed `Amount measure` world.

## Test audit result

The audit did not find a compelling class of existing tests that should simply be deleted because a theorem already subsumes them.

The TUI Kernel/Runtime already places many pure optimization-correctness claims in theorems rather than relying only on examples. Existing practical tests tend to exercise integration, persistence, command routing, terminal interaction, or writer behavior that the pure theorems do not replace.

The audit therefore removed runtime decisions and repeated admissions, but did not pursue test-count reduction as a goal in itself.

Future test deletion should require a stronger condition:

1. the test asserts only a pure universal law;
2. the same law is already machine-proved over the same domain;
3. the test is not also validating an adapter, parser, persistence format, executable wiring, or external effect.

## Design rules extracted from the audit

### 1. Ask whether an invariant already has an owner before adding a theorem

Merchant, Locus, AccountingRole, and Attention closure were improved without adding new sophisticated types. The publisher simply stopped deciding an invariant that the memory constructor already owns.

### 2. Prefer proof-carrying total entrances beside, not instead of, fallible runtime admission

`add?` remains valuable for arbitrary loaded/runtime values. `addFresh` is appropriate when a caller has already proved the key fresh. This preserves both external robustness and internal totality.

### 3. Keep runtime value APIs ordinary when possible

The successful Attention design kept `freshId : AttentionId` and placed a freshness theorem beside it. Returning nested subtypes merely to make one append total is usually too much production API surface.

### 4. Generalize representation mechanics, not semantic memories

`FiniteKeyed.appendFresh_nodup` was worth sharing because multiple memories needed exactly the same list/key theorem. The memories themselves remain semantically distinct.

### 5. A proof must amortize

#1033 failed because one removed branch required a large heterogeneous-reference bridge. #1035 succeeded because one simple freshness proof removed two whole-list admissions. Theorem truth is not the acceptance criterion; downstream complexity removed per unit of proof surface is.

### 6. Preserve equational/compositional reasoning

The rejected Event portion of #1034 made the implementation harder for an existing CSLib correspondence theorem to rewrite. A local totalization that damages broader semantic proofs is not an improvement.

### 7. Source LOC is not the only size metric

Proofs erase at runtime. A small increase in source proof text can be justified when it removes repeated whole-history scans, impossible failure corridors, or duplicated decisions from every successful publication. Conversely, source growth is not justified merely because the added code is a proof.

### 8. Do not infer cross-family freshness from one family

A fresh EventId in `EventMemory` is not automatically fresh in ActualValidity, descriptions, correction edges, reversal evidence, or terminal relations. Either the allocator must explicitly reserve those namespaces or the world type must independently carry the required closure law.

## Final assessment

The answer to the audit's original question is **yes, with an important qualification**.

LOAM already gets real production leverage from Lean 4:

- structural invariants are carried by values;
- dependent indexing removes invalid same-measure operations downstream;
- pure semantic/refinement laws replace classes of representation-order and optimization checks;
- total definitions eliminate fuel/exhaustion failure modes;
- proof-carrying values such as `BalancedMovement` remove repeated validation;
- generated-identity proofs can erase runtime admissions once the proof follows the same key vocabulary as the retained memory.

The audit also found that LOAM should **not** try to maximize the amount of proof text. Its strongest pattern is narrower:

> State an invariant once at the layer that naturally owns it, then let downstream code trust that evidence far enough to delete repeated decisions, scans, and impossible failure paths. Stop when proof transport becomes more complicated than the runtime distinction it would replace.

After this audit, the remaining obvious high-value opportunities are conditional rather than immediate. Correction, Scheduled completion, and similar writers would become candidates only if a future semantic change independently establishes whole-world freshness/closure. Persistence, IO, parser, token, and interaction boundaries should continue to be tested and validated at runtime.

The present architecture is therefore not “Lean everywhere.” It is increasingly **Lean where a proof can make downstream production machinery disappear**.