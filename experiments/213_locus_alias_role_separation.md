# Observation 213 — Locus identity, alias, AccountingRole, and Purpose separation

Status: **PROBE — real household dogfood hinge**

## Trigger

Production `loamTui` dogfood exposed a concrete input inconsistency.

A normal household record could be entered as:

```text
paypay -> coffee
```

but the current approved vocabulary required:

```text
paypay -> expenses:タバコ
```

rather than the human input `タバコ`.

This was not a synthetic UI concern. The production publisher correctly refused
`タバコ` because new writes are closed over the explicit Observation-212 admission
vocabulary. The friction came from the spelling of the approved identity itself.

## Current household evidence

The current selected Movement history still contains HRA/hledger-shaped source
vocabulary, including families such as:

```text
expenses:...
income:...
liabilities:...
equity:...
```

while current holding/operational identities include flat tokens such as:

```text
cash
paypay
smbc
yucho
all-country
coffee
pension
support
debt-friend-k
```

This asymmetry is already tracked as `loam-data` debt DD-002, "HRA-derived Locus
vocabulary in admitted history". DD-002 explicitly leaves open whether retained
source-shaped names are stable identities, aliases, historical-only source
vocabulary, or a mixture.

The current new-write admission vocabulary already supplies one useful
separation. Historical `income:*`, `liabilities:*`, and `equity:*` tokens remain
readable in admitted Event history but are not generally approved as the current
operational spellings for new writes. Current operational tokens instead include
flat identities such as `pension`, `support`, and `debt-friend-k`.

The remaining visible friction is concentrated in approved source-shaped expense
identities such as:

```text
expenses:タバコ
expenses:食費
expenses:交通
expenses:食費:ストック
expenses:缶コーヒー
expenses:学習
expenses:書籍
expenses:送料
expenses:お菓子
```

There is also already an explicit independent `ActualRouting` relation for the
historical expense family, for example:

```text
expenses:タバコ       -> タバコ
expenses:食費         -> 食費
expenses:交通         -> 一般生活
expenses:AIサブスク   -> 固定費予定
```

Therefore the `expenses:` spelling is not required merely to recover the current
Purpose-routing answer.

A superseded pre-cutover experiment had directly rewritten a small dataset:

```text
缶コーヒー -> coffee
タバコ     -> tobacco
オルカン積立 -> all-country
```

The later destructive historical cutover intentionally did not generalize that
representation decision. DD-002 retained the broader source vocabulary as
observation pressure instead.

## Prior LOAM results

Observation 031:

```text
Account identity != Locus coordinate
```

Observation 049:

```text
where quantity is != AccountingRole
```

Observation 062 showed that representative bookkeeping shapes can be recognized
from signed Effects plus independent AccountingRole without restoring a
conventional Account object or making nominal account names semantic.

Observation 208 explicitly did **not** earn colon-separated Locus naming semantics
or a permanent production five-role account taxonomy.

Observation 212 then earned only the current new-write admission set. Its Core
implementation deliberately contains no account/category/routing/display/alias
meaning and listed friendly display aliases as unresolved production pressure.

The Ledger/hledger reconstruction map likewise classifies account aliases / display
rewrites as primarily surface/additive policy while warning that semantic identity
rewriting must remain provenance-safe.

## Question

Can the current dogfood pressure be handled by separating four planes:

```text
stable canonical Locus identity
human display/input alias
AccountingRole
Purpose routing
```

without making colon prefixes semantic and without rewriting historical Event
identity merely to make the TUI pleasant?

A second practical question matters for writes:

> When a human alias is accepted as input, what is the smallest condition that
> lets it safely select one currently writable Locus?

## Observation-local model

The Alloy model retains opaque `Locus` identity and adds three independent
relations in each world:

```text
aliasTarget : Alias -> set Locus
role        : Locus -> lone AccountingRole
purpose     : Locus -> lone Purpose
```

plus the already-earned operational policy:

```text
approved : set Locus
```

`AccountingRole` and `Purpose` are observation vocabulary only. This probe does
not propose production enums or persistence formats.

Safe alias resolution is defined only as:

```text
currently approved targets of alias = exactly one Locus
```

The alias relation is allowed to contain more than one raw target so ambiguity can
be attacked directly. An unapproved historical target cannot become writable merely
because a friendly alias points at it.

## C-seeking attacks

### 1. Friendly alias requires historical rewrite

Keep the historical Locus identity retained and approved. Add the friendly alias
`TobaccoLabel` and ask whether it can resolve the existing historical identity.

Expected: **SAT witness**.

If so, friendly input/display does not by itself force Event-history rewriting.

### 2. Same semantics require the same aliases

Hold admission, AccountingRole, and Purpose fixed while changing alias relations.

Expected: **SAT witness** with different aliases.

This would show that presentation spelling is not identical to the selected
semantic planes.

### 3. Alias determines AccountingRole

Hold alias and admission fixed while varying only AccountingRole.

Expected: **SAT counterexample** to the stronger assertion.

So `expenses:` or a friendly word such as `タバコ` must not itself be treated as
proof of Expense role.

### 4. Alias determines Purpose routing

Hold alias and admission fixed while varying only Purpose.

Expected: **SAT counterexample**.

This protects the already-explicit `ActualRouting` plane from being folded back
into Locus spelling.

### 5. Ambiguous friendly aliases cannot occur

Allow two currently approved Loci to share one alias.

Expected: **SAT witness**.

Therefore a write surface must not assume every friendly label is globally unique.

### 6. Unique approved alias target determines resolution

Fix one alias to exactly one currently approved target.

Expected check: **UNSAT counterexample**.

This is the positive sufficiency result for the narrow input-selection question.

### 7. Ambiguous alias resolves anyway

Expected check: **UNSAT counterexample**. An ambiguous approved target set has no
selected Locus under this candidate.

### 8. Alias can bypass new-write admission

Expected check: **UNSAT counterexample**. Resolution always lands inside the
current approved vocabulary.

## Candidate interpretation if the matrix survives

The narrow candidate is:

```text
retained Event history keeps stable Locus identity

human input/display
    -> alias candidate relation
    + current LocusAdmission
    -> zero / one / ambiguous approved targets

one target
    -> canonical draft may use that existing LocusId

zero or ambiguous targets
    -> refuse / ask the human

AccountingRole and Purpose
    remain independent relations/projections
```

This would support a TUI interaction such as:

```text
TO: タバコ
Candidate: expenses:タバコ
```

without claiming either that `タバコ` *is* the canonical identity or that its
spelling proves Expense semantics.

## Production boundary

Even a successful result does **not** immediately authorize:

- bulk renaming canonical household Event history;
- deleting HRA-shaped historical Loci;
- inventing a permanent production AccountingRole enum;
- treating `expenses:` / `income:` / `assets:` / `liabilities:` as semantic syntax;
- making alias matching fuzzy or typo-correcting automatically;
- allowing aliases to bypass current `LocusAdmission`;
- choosing whether alias evidence belongs in Core, Application configuration, or
  presentation-only state;
- choosing English versus Japanese canonical Locus spelling;
- changing `ActualRouting` semantics;
- merging distinct historical identities merely because their display labels look
  similar.

The next production decision, only if this probe survives, should be narrower:

> Can a small explicit alias/display vocabulary improve completion and Record input
> while preserving current canonical Locus identity and publication-time admission?

That should be dogfooded before DD-002 is resolved by any destructive data rewrite.
